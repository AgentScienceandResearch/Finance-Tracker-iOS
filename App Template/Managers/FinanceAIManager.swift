import Foundation

@MainActor
final class FinanceAIManager: ObservableObject {
    @Published private(set) var messages: [AIChatMessage]
    @Published var isLoading = false
    @Published var errorMessage: String?

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
        messages.append(AIChatMessage(role: .user, content: trimmedPrompt))
        analytics.track(event: AnalyticsEvent(name: "finance_ai_prompt_submitted"))

        isLoading = true
        defer { isLoading = false }

        let summary = buildFinanceSummary(financeManager: financeManager)

        do {
            let response: String
            if service.isConfigured {
                response = try await service.generateFinanceInsight(prompt: trimmedPrompt, financeSummary: summary)
            } else {
                response = localFallbackInsight(for: trimmedPrompt, financeManager: financeManager)
            }

            messages.append(AIChatMessage(role: .assistant, content: response))
        } catch {
            let fallback = localFallbackInsight(for: trimmedPrompt, financeManager: financeManager)
            messages.append(AIChatMessage(role: .assistant, content: fallback))
            errorMessage = error.localizedDescription
            logger.warning("AI response fallback used: \(error.localizedDescription)", category: "finance_ai")
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
            errorMessage = error.localizedDescription
            return localReceiptFallback(rawText: trimmedText)
        }
    }

    func resetConversation() {
        messages = [
            AIChatMessage(
                role: .assistant,
                content: "Session reset. Ask me about budgets, trends, or where to cut costs this month."
            )
        ]
    }

    private func buildFinanceSummary(financeManager: FinanceManager) -> String {
        let formatter = CurrencyFormatting.shared
        let monthTotal = formatter.string(for: financeManager.thisMonthTotal)
        let weekTotal = formatter.string(for: financeManager.thisWeekTotal)
        let recurringTotal = formatter.string(for: financeManager.recurringMonthlyTotal)
        let recent = financeManager.recentExpenses(limit: 5)

        let recentRows = recent.map {
            "- \($0.title): \(formatter.string(for: $0.amount)) on \($0.date.formattedDate) [\($0.category.rawValue)]"
        }

        let upcomingRows = financeManager.upcomingRecurringExpenses.prefix(5).map {
            "- \($0.title): \(formatter.string(for: $0.amount)) due \($0.nextDueDate.formattedDate) [\($0.frequency.rawValue)]"
        }

        return """
        This month total: \(monthTotal)
        This week total: \(weekTotal)
        Recurring monthly load: \(recurringTotal)
        Total tracked expenses: \(financeManager.expenses.count)
        Active recurring expenses: \(financeManager.activeRecurringCount)

        Recent expenses:
        \(recentRows.isEmpty ? "- none" : recentRows.joined(separator: "\n"))

        Upcoming recurring:
        \(upcomingRows.isEmpty ? "- none" : upcomingRows.joined(separator: "\n"))
        """
    }

    private func localFallbackInsight(for prompt: String, financeManager: FinanceManager) -> String {
        let formatter = CurrencyFormatting.shared
        let monthTotal = formatter.string(for: financeManager.thisMonthTotal)
        let weekTotal = formatter.string(for: financeManager.thisWeekTotal)
        let recurring = formatter.string(for: financeManager.recurringMonthlyTotal)

        return """
        Quick local insight:
        - This month: \(monthTotal)
        - This week: \(weekTotal)
        - Monthly recurring load: \(recurring)

        To unlock GPT-powered advice, set `API_URL` to your Railway server and configure `OPENAI_API_KEY` on Railway.
        Prompt received: "\(prompt)"
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
