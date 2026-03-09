import Foundation

struct RecurringExpense: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var amount: Decimal
    var category: ExpenseCategory
    var frequency: RecurrenceFrequency
    var nextDueDate: Date
    var isActive: Bool
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        category: ExpenseCategory,
        frequency: RecurrenceFrequency,
        nextDueDate: Date,
        isActive: Bool = true,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.frequency = frequency
        self.nextDueDate = nextDueDate
        self.isActive = isActive
        self.notes = notes
        self.createdAt = createdAt
    }

    var normalizedMonthlyCost: Decimal {
        amount * frequency.monthlyMultiplier
    }
}
