import Foundation

@MainActor
final class FinanceAIManager: ObservableObject {
    @Published private(set) var messages: [AIChatMessage]
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// An action the AI has proposed (add expense/budget/recurring). The user must
    /// confirm it before it is applied — the AI never changes data on its own.
    @Published var pendingAction: PendingAIAction?

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
                content: "I can analyze your spending, suggest savings targets, and parse receipt text into expenses."
            )
        ]
    }

    func sendMessage(_ prompt: String, financeManager: FinanceManager) async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        errorMessage = nil
        pendingAction = nil
        messages.append(AIChatMessage(role: .user, content: trimmedPrompt))
        analytics.track(event: AnalyticsEvent(name: "finance_ai_prompt_submitted"))

        isLoading = true
        defer { isLoading = false }

        let summary = buildFinanceSummary(financeManager: financeManager) + "\n\n" + Self.actionInstructions

        do {
            let response: String
            if service.isConfigured {
                response = try await service.generateFinanceInsight(prompt: trimmedPrompt, financeSummary: summary)
            } else {
                response = localFallbackInsight(for: trimmedPrompt, financeManager: financeManager)
            }

            // The AI may append a machine-readable action to its reply; pull it out
            // so the chat shows only prose and the app can offer to apply it.
            let parsed = Self.extractAction(from: response)
            messages.append(AIChatMessage(role: .assistant, content: parsed.display))
            pendingAction = parsed.action
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
        pendingAction = nil
        messages = [
            AIChatMessage(
                role: .assistant,
                content: "Session reset. Ask me about budgets, trends, or where to cut costs this month."
            )
        ]
    }

    // MARK: - Applying AI-proposed actions

    /// Apply the pending action to the user's data (only after the user confirms),
    /// then confirm in the chat. The AI proposes; the user disposes.
    func applyPendingAction(financeManager: FinanceManager) {
        guard let action = pendingAction else { return }
        let f = CurrencyFormatting.shared
        let confirmation: String

        switch action.kind {
        case let .addExpense(title, amount, category):
            financeManager.addExpense(Expense(title: title, amount: amount, category: category))
            confirmation = "Added \(title) (\(f.string(for: amount))) to \(category.rawValue)."
        case let .addIncome(title, amount):
            financeManager.addExpense(Expense(title: title, amount: amount, category: .income))
            confirmation = "Logged income \(title) (\(f.string(for: amount)))."
        case let .setBudget(amount):
            financeManager.setMonthlyBudget(amount)
            confirmation = "Set your monthly budget to \(f.string(for: amount))."
        case .clearBudget:
            financeManager.setMonthlyBudget(nil)
            confirmation = "Cleared your monthly budget."
        case let .addRecurring(title, amount, category, frequency):
            financeManager.addRecurringExpense(
                RecurringExpense(title: title, amount: amount, category: category,
                                 frequency: frequency, nextDueDate: Self.nextDueDate(for: frequency))
            )
            confirmation = "Added recurring bill \(title) (\(f.string(for: amount)), \(frequency.rawValue))."
        }

        pendingAction = nil
        messages.append(AIChatMessage(role: .assistant, content: confirmation))
        analytics.track(event: AnalyticsEvent(name: "finance_ai_action_applied"))
    }

    func dismissPendingAction() {
        pendingAction = nil
    }

    private static func nextDueDate(for frequency: RecurrenceFrequency) -> Date {
        let cal = Calendar.current
        let now = Date()
        switch frequency {
        case .weekly:    return cal.date(byAdding: .day, value: 7, to: now) ?? now
        case .biweekly:  return cal.date(byAdding: .day, value: 14, to: now) ?? now
        case .monthly:   return cal.date(byAdding: .month, value: 1, to: now) ?? now
        case .quarterly: return cal.date(byAdding: .month, value: 3, to: now) ?? now
        case .yearly:    return cal.date(byAdding: .year, value: 1, to: now) ?? now
        }
    }

    private func buildFinanceSummary(financeManager: FinanceManager) -> String {
        let formatter = CurrencyFormatting.shared
        let monthTotal = formatter.string(for: financeManager.thisMonthTotal)
        let weekTotal = formatter.string(for: financeManager.thisWeekTotal)
        let recurringTotal = formatter.string(for: financeManager.recurringMonthlyTotal)

        let budgetLine: String = {
            guard let budget = financeManager.monthlyBudget else { return "Not set" }
            if let ratio = financeManager.monthlyBudgetUsageRatio {
                return "\(formatter.string(for: budget)) (\(Int((ratio * 100).rounded()))% used)"
            }
            return formatter.string(for: budget)
        }()

        let incomeTotal = financeManager.expenses
            .filter { $0.category == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }

        // Spending grouped by category (excludes income), highest first.
        let byCategory = Dictionary(grouping: financeManager.expenses.filter { $0.category != .income },
                                    by: { $0.category })
            .mapValues { $0.reduce(Decimal.zero) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }
            .prefix(8)
        let categoryRows = byCategory.map { "- \($0.key.rawValue): \(formatter.string(for: $0.value))" }

        let recentRows = financeManager.recentExpenses(limit: 8).map {
            "- \($0.title): \(formatter.string(for: $0.amount)) on \($0.date.formattedDate) [\($0.category.rawValue)]"
        }

        let activeRecurring = financeManager.recurringExpenses.filter { $0.isActive }
        let recurringRows = activeRecurring.prefix(12).map {
            "- \($0.title): \(formatter.string(for: $0.amount)) [\($0.frequency.rawValue)] next \($0.nextDueDate.formattedDate) [\($0.category.rawValue)]"
        }

        return """
        USER FINANCE SNAPSHOT (their real data across the app):
        Spending this month: \(monthTotal)
        Spending this week: \(weekTotal)
        Income logged (all time): \(formatter.string(for: incomeTotal))
        Monthly budget: \(budgetLine)
        Recurring monthly load: \(recurringTotal)
        Total tracked expenses: \(financeManager.expenses.count)
        Active recurring bills: \(financeManager.activeRecurringCount)

        Spending by category:
        \(categoryRows.isEmpty ? "- none yet" : categoryRows.joined(separator: "\n"))

        Recent expenses:
        \(recentRows.isEmpty ? "- none yet" : recentRows.joined(separator: "\n"))

        Active recurring bills:
        \(recurringRows.isEmpty ? "- none yet" : recurringRows.joined(separator: "\n"))
        """
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

    // MARK: - Action protocol

    /// Appended to the data snapshot so the model knows it can propose an action.
    /// The app parses any action out of the reply and asks the user to confirm it.
    static let actionInstructions: String = {
        let cats = ExpenseCategory.allCases.map(\.rawValue).joined(separator: ", ")
        return """
        ACTIONS — you can carry out ONE change to the user's data when they clearly ask for it (e.g. "add a $12 lunch", "set my budget to $2000", "add Netflix $15.99 monthly"). Rules:
        - Only when the user gives the needed details. NEVER invent an amount, title, or category the user did not provide.
        - Write your normal helpful reply first. Then, on a new line, append the marker below followed by ONE single-line JSON object. If no change was requested, omit the marker entirely.
        [[FINANCE_ACTION]]{"type":"add_expense","title":"Lunch","amount":12,"category":"Food & Dining"}
        Valid "type": add_expense, add_income, set_budget, clear_budget, add_recurring.
        Fields: title (string), amount (number, no currency symbol), category (one of: \(cats)), frequency (Weekly, Biweekly, Monthly, Quarterly, or Yearly — add_recurring only).
        """
    }()

    /// Split an AI reply into the prose to show and any action it proposed.
    static func extractAction(from text: String) -> (display: String, action: PendingAIAction?) {
        let marker = "[[FINANCE_ACTION]]"
        guard let range = text.range(of: marker) else {
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        let display = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = String(text[range.upperBound...])
        if let start = tail.firstIndex(of: "{"), let end = tail.lastIndex(of: "}"), start <= end,
           let data = String(tail[start...end]).data(using: .utf8),
           let raw = try? JSONDecoder().decode(RawAIAction.self, from: data),
           let action = raw.toPending() {
            return (display.isEmpty ? "Here's what I can do:" : display, action)
        }
        return (display.isEmpty ? "Sorry, I couldn't set that up. Could you rephrase?" : display, nil)
    }
}

// MARK: - AI action types

struct PendingAIAction: Identifiable {
    let id = UUID()
    let kind: Kind

    enum Kind {
        case addExpense(title: String, amount: Decimal, category: ExpenseCategory)
        case addIncome(title: String, amount: Decimal)
        case setBudget(amount: Decimal)
        case clearBudget
        case addRecurring(title: String, amount: Decimal, category: ExpenseCategory, frequency: RecurrenceFrequency)
    }

    var title: String {
        switch kind {
        case .addExpense:   return "Add expense"
        case .addIncome:    return "Log income"
        case .setBudget:    return "Set monthly budget"
        case .clearBudget:  return "Clear budget"
        case .addRecurring: return "Add recurring bill"
        }
    }

    var detail: String {
        let f = CurrencyFormatting.shared
        switch kind {
        case let .addExpense(title, amount, category):
            return "\(title) · \(f.string(for: amount)) · \(category.rawValue)"
        case let .addIncome(title, amount):
            return "\(title) · \(f.string(for: amount))"
        case let .setBudget(amount):
            return "\(f.string(for: amount)) / month"
        case .clearBudget:
            return "Remove the current monthly budget"
        case let .addRecurring(title, amount, category, frequency):
            return "\(title) · \(f.string(for: amount)) · \(frequency.rawValue) · \(category.rawValue)"
        }
    }

    var systemIcon: String {
        switch kind {
        case .addExpense:              return "cart.fill"
        case .addIncome:               return "dollarsign.circle.fill"
        case .setBudget, .clearBudget: return "chart.pie.fill"
        case .addRecurring:            return "arrow.triangle.2.circlepath"
        }
    }
}

private struct RawAIAction: Decodable {
    let type: String
    let title: String?
    let amount: Decimal?
    let category: String?
    let frequency: String?

    func toPending() -> PendingAIAction? {
        func resolvedCategory() -> ExpenseCategory {
            guard let category else { return .other }
            return ExpenseCategory(rawValue: category) ?? ExpenseCategory.from(freeform: category)
        }
        switch type.lowercased().replacingOccurrences(of: "-", with: "_") {
        case "add_expense":
            guard let title, let amount, amount > 0 else { return nil }
            return PendingAIAction(kind: .addExpense(title: title, amount: amount, category: resolvedCategory()))
        case "add_income":
            guard let title, let amount, amount > 0 else { return nil }
            return PendingAIAction(kind: .addIncome(title: title, amount: amount))
        case "set_budget":
            guard let amount, amount > 0 else { return nil }
            return PendingAIAction(kind: .setBudget(amount: amount))
        case "clear_budget":
            return PendingAIAction(kind: .clearBudget)
        case "add_recurring":
            guard let title, let amount, amount > 0 else { return nil }
            let freq = RecurrenceFrequency(rawValue: (frequency ?? "Monthly").capitalized) ?? .monthly
            return PendingAIAction(kind: .addRecurring(title: title, amount: amount, category: resolvedCategory(), frequency: freq))
        default:
            return nil
        }
    }
}
