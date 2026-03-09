import Foundation

struct FinanceExportSnapshot: Codable, Equatable {
    let exportedAt: Date
    let profile: User
    let monthlyBudget: Decimal?
    let expenses: [Expense]
    let recurringExpenses: [RecurringExpense]
}
