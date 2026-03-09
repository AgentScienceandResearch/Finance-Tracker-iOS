import Foundation

struct ReceiptDraft: Codable, Equatable {
    let merchant: String
    let amount: Decimal
    let category: ExpenseCategory
    let purchaseDate: Date
    let notes: String?

    init(
        merchant: String,
        amount: Decimal,
        category: ExpenseCategory,
        purchaseDate: Date = Date(),
        notes: String? = nil
    ) {
        self.merchant = merchant
        self.amount = amount
        self.category = category
        self.purchaseDate = purchaseDate
        self.notes = notes
    }
}
