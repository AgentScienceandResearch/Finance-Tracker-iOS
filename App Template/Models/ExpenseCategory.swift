import Foundation

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case foodDining = "Food & Dining"
    case transportation = "Transportation"
    case housing = "Housing"
    case utilities = "Utilities"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case health = "Health"
    case travel = "Travel"
    case education = "Education"
    case subscriptions = "Subscriptions"
    case incomeOffset = "Income Offset"
    case other = "Other"

    var id: String { rawValue }

    static func from(freeform text: String) -> ExpenseCategory {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("food") || normalized.contains("restaurant") || normalized.contains("coffee") || normalized.contains("grocery") {
            return .foodDining
        }
        if normalized.contains("uber") || normalized.contains("taxi") || normalized.contains("bus") || normalized.contains("train") || normalized.contains("fuel") || normalized.contains("gas") {
            return .transportation
        }
        if normalized.contains("rent") || normalized.contains("mortgage") {
            return .housing
        }
        if normalized.contains("electric") || normalized.contains("water") || normalized.contains("internet") || normalized.contains("phone") {
            return .utilities
        }
        if normalized.contains("movie") || normalized.contains("game") || normalized.contains("stream") {
            return .entertainment
        }
        if normalized.contains("shop") || normalized.contains("amazon") {
            return .shopping
        }
        if normalized.contains("pharmacy") || normalized.contains("clinic") || normalized.contains("health") {
            return .health
        }
        if normalized.contains("flight") || normalized.contains("hotel") {
            return .travel
        }
        if normalized.contains("course") || normalized.contains("book") || normalized.contains("tuition") {
            return .education
        }
        if normalized.contains("subscription") || normalized.contains("netflix") || normalized.contains("spotify") {
            return .subscriptions
        }
        return .other
    }
}
