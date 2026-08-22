import Foundation

@MainActor
final class FinanceAIManager: ObservableObject {
    @Published private(set) var messages: [AIChatMessage]
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Typed actions proposed by the model. They are always review-only until the
    /// user explicitly applies the batch in the assistant sheet.
    @Published private(set) var pendingActions: [PendingAIAction] = []

    var pendingAction: PendingAIAction? { pendingActions.first }

    private let service: OpenAIServing
    private let logger: Logging
    private let analytics: AnalyticsTracking

    init(
        service: OpenAIServing,
        logger: Logging = AppLogger.shared,
        analytics: AnalyticsTracking = NoOpAnalyticsTracker.shared
    ) {
        self.service = service
        self.logger = logger
        self.analytics = analytics
        self.messages = [
            AIChatMessage(
                role: .assistant,
                content: "I can analyze your finances and help manage transactions, income, budgets, and recurring bills. Any change stays pending until you review and approve it."
            )
        ]
    }

    func sendMessage(_ prompt: String, financeManager: FinanceManager) async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        errorMessage = nil
        pendingActions = []
        let conversation = messages
            .suffix(16)
            .map { FinanceAIConversationTurn(role: $0.role.rawValue, content: $0.content) }
        messages.append(AIChatMessage(role: .user, content: trimmedPrompt))
        analytics.track(event: AnalyticsEvent(name: "finance_ai_prompt_submitted"))

        isLoading = true
        defer { isLoading = false }

        do {
            if service.isConfigured {
                let response = try await service.generateFinanceAssistantReply(
                    prompt: trimmedPrompt,
                    snapshot: buildFinanceSnapshot(financeManager: financeManager),
                    conversation: conversation
                )
                let actions = response.actions.compactMap {
                    PendingAIAction(toolCall: $0, financeManager: financeManager)
                }
                let message = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
                messages.append(AIChatMessage(
                    role: .assistant,
                    content: message.isEmpty
                        ? (actions.isEmpty ? "I couldn't prepare that request. Could you rephrase it?" : "I prepared the requested changes. Review them below before applying.")
                        : message
                ))
                pendingActions = actions
            } else {
                messages.append(AIChatMessage(
                    role: .assistant,
                    content: localFallbackInsight(for: trimmedPrompt, financeManager: financeManager)
                ))
            }
        } catch {
            let fallback = localFallbackInsight(for: trimmedPrompt, financeManager: financeManager)
            messages.append(AIChatMessage(role: .assistant, content: fallback))
            // The fallback message already tells the user AI is unavailable; never
            // surface raw API/network errors (e.g. HTTP 401) in the UI.
            errorMessage = nil
            logger.warning("AI response fallback used: \(error.localizedDescription)", category: "finance_ai")
        }

        // Keep the initial welcome message + last 39 to bound memory usage.
        if messages.count > 40 {
            let welcome = messages.first
            messages = Array(messages.suffix(39))
            if let welcome { messages.insert(welcome, at: 0) }
        }
    }

    func parseReceipt(rawText: String) async -> ReceiptDraft? {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            errorMessage = "Paste receipt text to continue."
            return nil
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if service.isConfigured {
                return try await service.parseReceipt(from: trimmedText)
            }

            return localReceiptFallback(rawText: trimmedText)
        } catch {
            logger.warning("Receipt parsing failed: \(error.localizedDescription)", category: "finance_ai")
            errorMessage = "Couldn't read that receipt automatically. Please review the details."
            return localReceiptFallback(rawText: trimmedText)
        }
    }

    func parseImage(imageBase64: String, mimeType: String) async -> [ReceiptDraft] {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        guard service.isConfigured else {
            errorMessage = "AI server not reachable. Check your connection."
            return []
        }

        do {
            return try await service.parseImage(imageBase64: imageBase64, mimeType: mimeType)
        } catch {
            logger.warning("Image parsing failed: \(error.localizedDescription)", category: "finance_ai")
            errorMessage = "Couldn't scan that image. Try again or add the expense manually."
            return []
        }
    }

    func getCategoryInsight(
        category: String,
        amount: Double,
        percentage: Double,
        monthlyTotal: Double,
        recentTransactions: String
    ) async -> String? {
        do {
            if service.isConfigured {
                return try await service.getCategoryInsight(
                    category: category,
                    amount: amount,
                    percentage: percentage,
                    monthlyTotal: monthlyTotal,
                    recentTransactions: recentTransactions
                )
            }
            return localCategoryInsight(category: category, amount: amount, percentage: percentage)
        } catch {
            return localCategoryInsight(category: category, amount: amount, percentage: percentage)
        }
    }

    func resetConversation() {
        pendingActions = []
        messages = [
            AIChatMessage(
                role: .assistant,
                content: "Session reset. I can analyze or manage transactions, budgets, and recurring bills whenever you're ready."
            )
        ]
    }

    // MARK: - Applying AI-proposed actions

    /// Applies the full reviewed batch. Tool calls are never executed before this
    /// method is invoked by the confirmation button in the UI.
    func applyPendingActions(financeManager: FinanceManager) {
        guard !pendingActions.isEmpty else { return }
        let actions = pendingActions
        pendingActions = []

        var confirmations: [String] = []
        var failures: [String] = []
        financeManager.performBatchUpdates {
            for action in actions {
                let result = apply(action, financeManager: financeManager)
                if result.succeeded {
                    confirmations.append(result.message)
                } else {
                    failures.append(result.message)
                }
            }
        }

        let message: String
        if failures.isEmpty {
            message = confirmations.count == 1
                ? (confirmations.first ?? "Change applied.")
                : "Applied \(confirmations.count) changes:\n" + confirmations.map { "• \($0)" }.joined(separator: "\n")
        } else {
            let applied = confirmations.isEmpty
                ? "No changes were applied."
                : "Applied:\n" + confirmations.map { "• \($0)" }.joined(separator: "\n")
            message = applied + "\nCouldn't apply:\n" + failures.map { "• \($0)" }.joined(separator: "\n")
        }

        messages.append(AIChatMessage(role: .assistant, content: message))
        analytics.track(event: AnalyticsEvent(
            name: "finance_ai_action_batch_applied",
            properties: ["applied_count": "\(confirmations.count)", "failed_count": "\(failures.count)"]
        ))
    }

    func dismissPendingActions() {
        pendingActions = []
    }

    private func apply(_ action: PendingAIAction, financeManager: FinanceManager) -> (succeeded: Bool, message: String) {
        let formatter = CurrencyFormatting.shared

        switch action.kind {
        case let .addTransaction(title, amount, category, date, notes):
            financeManager.addExpense(Expense(
                title: title,
                amount: amount,
                category: category,
                date: date,
                notes: notes
            ))
            let verb = category.isIncome ? "Logged income" : "Added"
            return (true, "\(verb) \(title) (\(formatter.string(for: amount))).")

        case let .updateTransaction(id, currentTitle, title, amount, category, date, notes, clearNotes):
            let updated = financeManager.updateExpense(
                id: id,
                title: title,
                amount: amount,
                category: category,
                date: date,
                notes: notes,
                clearNotes: clearNotes
            )
            return updated
                ? (true, "Updated \(title ?? currentTitle).")
                : (false, "\(currentTitle) changed or no longer exists.")

        case let .deleteTransaction(id, title):
            return financeManager.deleteExpense(id: id)
                ? (true, "Deleted \(title).")
                : (false, "\(title) no longer exists.")

        case let .setBudget(amount):
            financeManager.setMonthlyBudget(amount)
            return (true, "Set the monthly budget to \(formatter.string(for: amount)).")

        case .clearBudget:
            financeManager.setMonthlyBudget(nil)
            return (true, "Cleared the monthly budget.")

        case let .addRecurring(title, amount, category, frequency, nextDueDate, notes):
            financeManager.addRecurringExpense(RecurringExpense(
                title: title,
                amount: amount,
                category: category,
                frequency: frequency,
                nextDueDate: nextDueDate,
                notes: notes
            ))
            return (true, "Added recurring bill \(title) (\(formatter.string(for: amount)), \(frequency.rawValue.lowercased())).")

        case let .updateRecurring(id, currentTitle, title, amount, category, frequency, nextDueDate, notes, clearNotes):
            let updated = financeManager.updateRecurringExpense(
                id: id,
                title: title,
                amount: amount,
                category: category,
                frequency: frequency,
                nextDueDate: nextDueDate,
                notes: notes,
                clearNotes: clearNotes
            )
            return updated
                ? (true, "Updated recurring bill \(title ?? currentTitle).")
                : (false, "\(currentTitle) changed or no longer exists.")

        case let .setRecurringActive(id, title, isActive):
            let updated = financeManager.updateRecurringExpense(id: id, isActive: isActive)
            let verb = isActive ? "Resumed" : "Paused"
            return updated
                ? (true, "\(verb) \(title).")
                : (false, "\(title) changed or no longer exists.")

        case let .deleteRecurring(id, title):
            return financeManager.deleteRecurringExpense(id: id)
                ? (true, "Deleted recurring bill \(title).")
                : (false, "\(title) no longer exists.")

        case .postDueRecurring:
            let count = financeManager.processDueRecurringExpenses()
            return count == 0
                ? (true, "There were no due recurring bills to post.")
                : (true, "Posted \(count) due recurring \(count == 1 ? "transaction" : "transactions").")

        case let .clearAllData(transactionCount, recurringCount):
            financeManager.clearAllData()
            return (true, "Cleared \(transactionCount) transactions, \(recurringCount) recurring bills, and the monthly budget.")
        }
    }

    private func buildFinanceSnapshot(financeManager: FinanceManager) -> FinanceAISnapshot {
        FinanceAISnapshot(
            generatedAt: Date(),
            currencyCode: Locale.current.currency?.identifier ?? "USD",
            monthlyBudget: financeManager.monthlyBudget,
            spendingThisMonth: financeManager.thisMonthTotal,
            spendingThisWeek: financeManager.thisWeekTotal,
            recurringMonthlyTotal: financeManager.recurringMonthlyTotal,
            transactions: financeManager.expenses.sorted { $0.date > $1.date },
            recurringTransactions: financeManager.recurringExpenses.sorted { $0.nextDueDate < $1.nextDueDate }
        )
    }

    private func localCategoryInsight(category: String, amount: Double, percentage: Double) -> String {
        let amountStr = CurrencyFormatting.shared.string(for: Decimal(amount))
        return "You spent \(amountStr) on \(category) this month, which is \(Int(percentage * 100))% of total spending."
    }

    private func localFallbackInsight(for prompt: String, financeManager: FinanceManager) -> String {
        let formatter = CurrencyFormatting.shared
        let monthTotal = formatter.string(for: financeManager.thisMonthTotal)
        let weekTotal = formatter.string(for: financeManager.thisWeekTotal)
        let recurring = formatter.string(for: financeManager.recurringMonthlyTotal)

        return """
        Here's a quick summary from your records:
        • This month: \(monthTotal)
        • This week: \(weekTotal)
        • Monthly recurring: \(recurring)

        Personalized AI insights are temporarily unavailable. Please try again in a little while.
        """
    }

    private func localReceiptFallback(rawText: String) -> ReceiptDraft {
        let normalized = rawText.replacingOccurrences(of: ",", with: ".")
        let amount = detectAmount(in: normalized) ?? Decimal.zero
        let merchant = detectMerchant(in: normalized) ?? "Receipt Expense"
        let category = ExpenseCategory.from(freeform: normalized)

        return ReceiptDraft(
            merchant: merchant,
            amount: amount,
            category: category,
            purchaseDate: Date(),
            notes: "Parsed locally from receipt text"
        )
    }

    private func detectAmount(in text: String) -> Decimal? {
        let pattern = "([0-9]+(?:\\.[0-9]{1,2})?)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches.reversed() {
            guard let numberRange = Range(match.range(at: 1), in: text) else { continue }
            let candidate = String(text[numberRange])
            if let value = Decimal(string: candidate), value > 0 {
                return value
            }
        }

        return nil
    }

    private func detectMerchant(in text: String) -> String? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = lines.first else { return nil }
        return first.count > 45 ? String(first.prefix(45)) : first
    }

}

// MARK: - AI action types

struct PendingAIAction: Identifiable {
    let id = UUID()
    let kind: Kind

    enum Kind {
        case addTransaction(title: String, amount: Decimal, category: ExpenseCategory, date: Date, notes: String?)
        case updateTransaction(id: UUID, currentTitle: String, title: String?, amount: Decimal?, category: ExpenseCategory?, date: Date?, notes: String?, clearNotes: Bool)
        case deleteTransaction(id: UUID, title: String)
        case setBudget(amount: Decimal)
        case clearBudget
        case addRecurring(title: String, amount: Decimal, category: ExpenseCategory, frequency: RecurrenceFrequency, nextDueDate: Date, notes: String?)
        case updateRecurring(id: UUID, currentTitle: String, title: String?, amount: Decimal?, category: ExpenseCategory?, frequency: RecurrenceFrequency?, nextDueDate: Date?, notes: String?, clearNotes: Bool)
        case setRecurringActive(id: UUID, title: String, isActive: Bool)
        case deleteRecurring(id: UUID, title: String)
        case postDueRecurring
        case clearAllData(transactionCount: Int, recurringCount: Int)
    }

    @MainActor
    init?(toolCall: FinanceAIToolCall, financeManager: FinanceManager) {
        let input = toolCall.input

        func clean(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(160))
        }

        func category(_ value: String?) -> ExpenseCategory? {
            guard let value else { return nil }
            return ExpenseCategory.allCases.first {
                $0.rawValue.caseInsensitiveCompare(value) == .orderedSame
            }
        }

        func frequency(_ value: String?) -> RecurrenceFrequency? {
            guard let value else { return nil }
            return RecurrenceFrequency.allCases.first {
                $0.rawValue.caseInsensitiveCompare(value) == .orderedSame
            }
        }

        func date(_ value: String?) -> Date? {
            guard let value else { return nil }
            return Self.dateFormatter.date(from: value)
        }

        switch toolCall.type {
        case "add_transaction":
            guard let title = clean(input.title),
                  let amount = input.amount, amount > 0,
                  let category = category(input.category)
            else { return nil }
            kind = .addTransaction(
                title: title,
                amount: amount,
                category: category,
                date: date(input.date) ?? Date(),
                notes: clean(input.notes)
            )

        case "update_transaction":
            guard let rawID = input.transactionID,
                  let id = UUID(uuidString: rawID),
                  let existing = financeManager.expenses.first(where: { $0.id == id })
            else { return nil }
            let newCategory = input.category == nil ? nil : category(input.category)
            guard input.category == nil || newCategory != nil else { return nil }
            let newDate = input.date == nil ? nil : date(input.date)
            guard input.date == nil || newDate != nil else { return nil }
            let hasChange = clean(input.title) != nil || input.amount != nil || newCategory != nil ||
                newDate != nil || clean(input.notes) != nil || input.clearNotes == true
            guard hasChange, input.amount.map({ $0 > 0 }) ?? true else { return nil }
            kind = .updateTransaction(
                id: id,
                currentTitle: existing.title,
                title: clean(input.title),
                amount: input.amount,
                category: newCategory,
                date: newDate,
                notes: clean(input.notes),
                clearNotes: input.clearNotes == true
            )

        case "delete_transaction":
            guard let rawID = input.transactionID,
                  let id = UUID(uuidString: rawID),
                  let existing = financeManager.expenses.first(where: { $0.id == id })
            else { return nil }
            kind = .deleteTransaction(id: id, title: existing.title)

        case "set_monthly_budget":
            guard let amount = input.amount, amount > 0 else { return nil }
            kind = .setBudget(amount: amount)

        case "clear_monthly_budget":
            kind = .clearBudget

        case "add_recurring_transaction":
            guard let title = clean(input.title),
                  let amount = input.amount, amount > 0,
                  let category = category(input.category),
                  let frequency = frequency(input.frequency)
            else { return nil }
            kind = .addRecurring(
                title: title,
                amount: amount,
                category: category,
                frequency: frequency,
                nextDueDate: date(input.nextDueDate) ?? Self.defaultNextDueDate(for: frequency),
                notes: clean(input.notes)
            )

        case "update_recurring_transaction":
            guard let rawID = input.recurringID,
                  let id = UUID(uuidString: rawID),
                  let existing = financeManager.recurringExpenses.first(where: { $0.id == id })
            else { return nil }
            let newCategory = input.category == nil ? nil : category(input.category)
            let newFrequency = input.frequency == nil ? nil : frequency(input.frequency)
            let newDate = input.nextDueDate == nil ? nil : date(input.nextDueDate)
            guard (input.category == nil || newCategory != nil),
                  (input.frequency == nil || newFrequency != nil),
                  (input.nextDueDate == nil || newDate != nil),
                  input.amount.map({ $0 > 0 }) ?? true
            else { return nil }
            let hasChange = clean(input.title) != nil || input.amount != nil || newCategory != nil ||
                newFrequency != nil || newDate != nil || clean(input.notes) != nil || input.clearNotes == true
            guard hasChange else { return nil }
            kind = .updateRecurring(
                id: id,
                currentTitle: existing.title,
                title: clean(input.title),
                amount: input.amount,
                category: newCategory,
                frequency: newFrequency,
                nextDueDate: newDate,
                notes: clean(input.notes),
                clearNotes: input.clearNotes == true
            )

        case "set_recurring_active":
            guard let rawID = input.recurringID,
                  let id = UUID(uuidString: rawID),
                  let isActive = input.isActive,
                  let existing = financeManager.recurringExpenses.first(where: { $0.id == id })
            else { return nil }
            kind = .setRecurringActive(id: id, title: existing.title, isActive: isActive)

        case "delete_recurring_transaction":
            guard let rawID = input.recurringID,
                  let id = UUID(uuidString: rawID),
                  let existing = financeManager.recurringExpenses.first(where: { $0.id == id })
            else { return nil }
            kind = .deleteRecurring(id: id, title: existing.title)

        case "post_due_recurring_transactions":
            kind = .postDueRecurring

        case "clear_all_finance_data":
            kind = .clearAllData(
                transactionCount: financeManager.expenses.count,
                recurringCount: financeManager.recurringExpenses.count
            )

        default:
            return nil
        }
    }

    var title: String {
        switch kind {
        case let .addTransaction(_, _, category, _, _):
            return category.isIncome ? "Log income" : "Add transaction"
        case .updateTransaction: return "Update transaction"
        case .deleteTransaction: return "Delete transaction"
        case .setBudget: return "Set monthly budget"
        case .clearBudget: return "Clear budget"
        case .addRecurring: return "Add recurring bill"
        case .updateRecurring: return "Update recurring bill"
        case let .setRecurringActive(_, _, isActive): return isActive ? "Resume recurring bill" : "Pause recurring bill"
        case .deleteRecurring: return "Delete recurring bill"
        case .postDueRecurring: return "Post due recurring bills"
        case .clearAllData: return "Clear all finance data"
        }
    }

    var detail: String {
        let formatter = CurrencyFormatting.shared
        switch kind {
        case let .addTransaction(title, amount, category, date, _):
            return "\(title) · \(formatter.string(for: amount)) · \(category.rawValue) · \(date.formattedDate)"
        case let .updateTransaction(_, currentTitle, title, amount, category, date, notes, clearNotes):
            return Self.changeSummary(
                target: currentTitle,
                title: title,
                amount: amount,
                category: category,
                frequency: nil,
                date: date,
                notes: notes,
                clearNotes: clearNotes
            )
        case let .deleteTransaction(_, title):
            return title
        case let .setBudget(amount):
            return "\(formatter.string(for: amount)) / month"
        case .clearBudget:
            return "Remove the current monthly budget"
        case let .addRecurring(title, amount, category, frequency, nextDueDate, _):
            return "\(title) · \(formatter.string(for: amount)) · \(frequency.rawValue) · next \(nextDueDate.formattedDate) · \(category.rawValue)"
        case let .updateRecurring(_, currentTitle, title, amount, category, frequency, nextDueDate, notes, clearNotes):
            return Self.changeSummary(
                target: currentTitle,
                title: title,
                amount: amount,
                category: category,
                frequency: frequency,
                date: nextDueDate,
                notes: notes,
                clearNotes: clearNotes
            )
        case let .setRecurringActive(_, title, _), let .deleteRecurring(_, title):
            return title
        case .postDueRecurring:
            return "Create transactions for every recurring bill currently due"
        case let .clearAllData(transactionCount, recurringCount):
            return "Delete \(transactionCount) transactions, \(recurringCount) recurring bills, and the budget"
        }
    }

    var systemIcon: String {
        switch kind {
        case let .addTransaction(_, _, category, _, _):
            return category.isIncome ? "dollarsign.circle.fill" : "cart.fill"
        case .updateTransaction:       return "pencil"
        case .deleteTransaction:       return "trash.fill"
        case .setBudget, .clearBudget: return "chart.pie.fill"
        case .addRecurring, .updateRecurring, .setRecurringActive, .postDueRecurring:
            return "arrow.triangle.2.circlepath"
        case .deleteRecurring, .clearAllData:
            return "trash.fill"
        }
    }

    var isDestructive: Bool {
        switch kind {
        case .deleteTransaction, .deleteRecurring, .clearAllData:
            return true
        default:
            return false
        }
    }

    private static func changeSummary(
        target: String,
        title: String?,
        amount: Decimal?,
        category: ExpenseCategory?,
        frequency: RecurrenceFrequency?,
        date: Date?,
        notes: String?,
        clearNotes: Bool
    ) -> String {
        var changes: [String] = []
        if let title { changes.append("name to \(title)") }
        if let amount { changes.append("amount to \(CurrencyFormatting.shared.string(for: amount))") }
        if let category { changes.append("category to \(category.rawValue)") }
        if let frequency { changes.append("frequency to \(frequency.rawValue)") }
        if let date { changes.append("date to \(date.formattedDate)") }
        if let notes { changes.append("notes to \(notes)") }
        if clearNotes { changes.append("remove notes") }
        return "\(target) · " + changes.joined(separator: ", ")
    }

    private static func defaultNextDueDate(for frequency: RecurrenceFrequency) -> Date {
        let calendar = Calendar.current
        let now = Date()
        switch frequency {
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: now) ?? now
        case .biweekly: return calendar.date(byAdding: .day, value: 14, to: now) ?? now
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: now) ?? now
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: now) ?? now
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
