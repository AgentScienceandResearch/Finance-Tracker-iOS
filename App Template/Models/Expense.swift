import Foundation

struct Expense: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var amount: Decimal
    var category: ExpenseCategory
    var date: Date
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        category: ExpenseCategory,
        date: Date = Date(),
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
    }
}
