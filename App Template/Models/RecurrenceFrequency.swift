import Foundation

enum RecurrenceFrequency: String, CaseIterable, Codable, Identifiable {
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .weekly:    return String(localized: "Weekly")
        case .biweekly:  return String(localized: "Biweekly")
        case .monthly:   return String(localized: "Monthly")
        case .quarterly: return String(localized: "Quarterly")
        case .yearly:    return String(localized: "Yearly")
        }
    }

    var monthlyMultiplier: Decimal {
        switch self {
        case .weekly:
            return Decimal(string: "4.3333") ?? 4.3333
        case .biweekly:
            return Decimal(string: "2.1667") ?? 2.1667
        case .monthly:
            return 1
        case .quarterly:
            return Decimal(string: "0.3333") ?? 0.3333
        case .yearly:
            return Decimal(string: "0.0833") ?? 0.0833
        }
    }
}
