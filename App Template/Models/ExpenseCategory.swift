import Foundation
import SwiftUI

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
    case medical = "Medical"
    case personalCare = "Personal Care"
    case fitness = "Fitness"
    case pets = "Pets"
    case giftsAndDonations = "Gifts & Donations"
    case insurance = "Insurance"
    case homeMaintenance = "Home Maintenance"
    case savings = "Savings"
    case business = "Business"
    case income = "Income"
    case other = "Other"

    var id: String { rawValue }

    var isIncome: Bool {
        self == .income || self == .incomeOffset
    }

    var icon: String {
        switch self {
        case .foodDining:        return "🍽️"
        case .transportation:    return "🚗"
        case .housing:           return "🏠"
        case .utilities:         return "💡"
        case .entertainment:     return "🎬"
        case .shopping:          return "🛍️"
        case .health:            return "💊"
        case .travel:            return "✈️"
        case .education:         return "📚"
        case .subscriptions:     return "📱"
        case .incomeOffset:      return "💵"
        case .medical:           return "🏥"
        case .personalCare:      return "💄"
        case .fitness:           return "🏋️"
        case .pets:              return "🐾"
        case .giftsAndDonations: return "🎁"
        case .insurance:         return "🛡️"
        case .homeMaintenance:   return "🔧"
        case .savings:           return "🏦"
        case .business:          return "💼"
        case .income:            return "💰"
        case .other:             return "📦"
        }
    }

    var color: Color {
        switch self {
        case .foodDining:        return Color(red: 1.0, green: 0.55, blue: 0.0)
        case .transportation:    return Color(red: 0.2, green: 0.5, blue: 0.9)
        case .housing:           return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .utilities:         return Color(red: 0.95, green: 0.75, blue: 0.1)
        case .entertainment:     return Color(red: 0.6, green: 0.2, blue: 0.9)
        case .shopping:          return Color(red: 0.9, green: 0.3, blue: 0.5)
        case .health:            return Color(red: 0.2, green: 0.75, blue: 0.4)
        case .travel:            return Color(red: 0.1, green: 0.75, blue: 0.85)
        case .education:         return Color(red: 0.35, green: 0.3, blue: 0.85)
        case .subscriptions:     return Color(red: 0.1, green: 0.6, blue: 0.7)
        case .incomeOffset:      return Color(red: 0.3, green: 0.8, blue: 0.5)
        case .medical:           return Color(red: 0.9, green: 0.2, blue: 0.2)
        case .personalCare:      return Color(red: 0.95, green: 0.5, blue: 0.7)
        case .fitness:           return Color(red: 0.95, green: 0.4, blue: 0.1)
        case .pets:              return Color(red: 0.7, green: 0.5, blue: 0.3)
        case .giftsAndDonations: return Color(red: 0.8, green: 0.3, blue: 0.75)
        case .insurance:         return Color(red: 0.4, green: 0.55, blue: 0.7)
        case .homeMaintenance:   return Color(red: 0.5, green: 0.35, blue: 0.2)
        case .savings:           return Color(red: 0.15, green: 0.65, blue: 0.35)
        case .business:          return Color(red: 0.15, green: 0.3, blue: 0.65)
        case .income:            return Color(red: 0.1, green: 0.7, blue: 0.3)
        case .other:             return Color(red: 0.55, green: 0.55, blue: 0.6)
        }
    }

    /// SF Symbol icon for use in SwiftUI Image views.
    var sfSymbol: String {
        switch self {
        case .foodDining:        return "fork.knife"
        case .transportation:    return "car.fill"
        case .housing:           return "house.fill"
        case .utilities:         return "bolt.fill"
        case .entertainment:     return "tv.fill"
        case .shopping:          return "bag.fill"
        case .health:            return "cross.case.fill"
        case .travel:            return "airplane"
        case .education:         return "book.fill"
        case .subscriptions:     return "arrow.triangle.2.circlepath"
        case .incomeOffset:      return "arrow.down.circle.fill"
        case .medical:           return "stethoscope"
        case .personalCare:      return "sparkles"
        case .fitness:           return "figure.run"
        case .pets:              return "pawprint.fill"
        case .giftsAndDonations: return "gift.fill"
        case .insurance:         return "shield.fill"
        case .homeMaintenance:   return "wrench.and.screwdriver.fill"
        case .savings:           return "banknote.fill"
        case .business:          return "briefcase.fill"
        case .income:            return "dollarsign.circle.fill"
        case .other:             return "square.grid.2x2.fill"
        }
    }

    /// Common name suggestions for recurring expenses in this category.
    var recurringTitleSuggestions: [String] {
        switch self {
        case .subscriptions:     return ["Netflix", "Spotify", "Apple TV+", "Disney+", "YouTube Premium", "Amazon Prime", "Hulu", "HBO Max"]
        case .housing:           return ["Rent", "Mortgage", "HOA Dues", "Storage Unit"]
        case .utilities:         return ["Electric Bill", "Water Bill", "Internet", "Phone Bill", "Gas Bill", "Trash Service"]
        case .fitness:           return ["Gym Membership", "Yoga Studio", "CrossFit", "Peloton"]
        case .insurance:         return ["Car Insurance", "Health Insurance", "Home Insurance", "Life Insurance", "Renters Insurance"]
        case .education:         return ["Tuition", "Online Course", "Student Loan", "Tutoring"]
        case .savings:           return ["Savings Transfer", "401k Contribution", "Emergency Fund", "Investment"]
        case .health:            return ["Prescription", "Vitamins", "Therapy"]
        case .medical:           return ["Doctor Visit", "Dental Checkup", "Eye Exam", "Medication"]
        case .transportation:    return ["Car Payment", "Metro Pass", "Bus Pass", "Parking Permit", "Toll Pass"]
        case .pets:              return ["Pet Food", "Vet Subscription", "Pet Insurance", "Dog Walking"]
        case .business:          return ["Software License", "Domain Renewal", "Cloud Hosting", "Accounting Service"]
        case .foodDining:        return ["Meal Kit Service", "Coffee Subscription", "Grocery Delivery"]
        case .personalCare:      return ["Salon Membership", "Skincare Subscription"]
        case .giftsAndDonations: return ["Charity Donation", "Monthly Giving", "Church Tithe"]
        case .homeMaintenance:   return ["Cleaning Service", "Lawn Care", "Security System", "Pest Control"]
        case .entertainment:     return ["Gaming Subscription", "Concert Pass", "Museum Membership"]
        case .shopping:          return ["Amazon Subscribe & Save", "Clothing Subscription"]
        case .travel:            return ["Travel Insurance", "Lounge Membership"]
        case .incomeOffset, .income, .other: return []
        }
    }

    static func from(freeform text: String) -> ExpenseCategory {
        let n = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if n.contains("food") || n.contains("restaurant") || n.contains("coffee") ||
           n.contains("grocery") || n.contains("dining") || n.contains("cafe") ||
           n.contains("lunch") || n.contains("dinner") || n.contains("breakfast") { return .foodDining }

        if n.contains("uber") || n.contains("lyft") || n.contains("taxi") ||
           n.contains("bus") || n.contains("train") || n.contains("metro") ||
           n.contains("fuel") || n.contains("gas station") || n.contains("parking") { return .transportation }

        if n.contains("rent") || n.contains("mortgage") || n.contains("lease") { return .housing }

        if n.contains("electric") || n.contains("water bill") || n.contains("internet") ||
           n.contains("phone bill") || n.contains("utility") { return .utilities }

        if n.contains("movie") || n.contains("concert") || n.contains("game") ||
           n.contains("stream") || n.contains("theatre") || n.contains("museum") { return .entertainment }

        if n.contains("amazon") || n.contains("mall") || n.contains("clothing") ||
           n.contains("shoes") || n.contains("apparel") { return .shopping }

        if n.contains("hospital") || n.contains("doctor") || n.contains("clinic") ||
           n.contains("surgery") || n.contains("dentist") || n.contains("prescription") ||
           n.contains("medical") || n.contains("urgent care") || n.contains("er ") ||
           n.contains("radiology") || n.contains("lab test") { return .medical }

        if n.contains("pharmacy") || n.contains("vitamin") || n.contains("supplement") ||
           n.contains("health food") { return .health }

        if n.contains("flight") || n.contains("hotel") || n.contains("airbnb") ||
           n.contains("vacation") || n.contains("resort") { return .travel }

        if n.contains("course") || n.contains("tuition") || n.contains("school") ||
           n.contains("university") || n.contains("textbook") { return .education }

        if n.contains("netflix") || n.contains("spotify") || n.contains("apple ") ||
           n.contains("subscription") || n.contains("membership fee") { return .subscriptions }

        if n.contains("gym") || n.contains("fitness") || n.contains("yoga") ||
           n.contains("pilates") || n.contains("crossfit") || n.contains("sport") { return .fitness }

        if n.contains("salon") || n.contains("barber") || n.contains("haircut") ||
           n.contains("spa") || n.contains("nail") || n.contains("cosmetic") ||
           n.contains("beauty") || n.contains("makeup") { return .personalCare }

        if n.contains("vet") || n.contains("pet") || n.contains("dog food") ||
           n.contains("cat food") || n.contains("grooming") { return .pets }

        if n.contains("donation") || n.contains("charity") || n.contains("gift") ||
           n.contains("birthday present") { return .giftsAndDonations }

        if n.contains("insurance") || n.contains("premium") || n.contains("deductible") { return .insurance }

        if n.contains("repair") || n.contains("plumber") || n.contains("electrician") ||
           n.contains("maintenance") || n.contains("appliance") || n.contains("cleaning service") { return .homeMaintenance }

        if n.contains("savings") || n.contains("transfer to savings") || n.contains("401k") ||
           n.contains("retirement") { return .savings }

        if n.contains("business") || n.contains("office") || n.contains("client") ||
           n.contains("invoice") || n.contains("freelance") { return .business }

        if n.contains("salary") || n.contains("paycheck") || n.contains("income") ||
           n.contains("deposit") || n.contains("revenue") { return .income }

        return .other
    }
}
