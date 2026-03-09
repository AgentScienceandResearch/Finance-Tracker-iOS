import Foundation

final class CurrencyFormatting {
    static let shared = CurrencyFormatting()

    private let formatter: NumberFormatter

    private init() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = .current
        self.formatter = formatter
    }

    func string(for decimal: Decimal) -> String {
        formatter.string(from: decimal as NSDecimalNumber) ?? "$0.00"
    }
}
