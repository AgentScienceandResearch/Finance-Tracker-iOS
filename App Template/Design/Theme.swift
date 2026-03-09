import SwiftUI

// MARK: - Color Theme
struct AppTheme {
    static let ink = Color(red: 0.08, green: 0.09, blue: 0.12)
    static let secondaryInk = Color(red: 0.24, green: 0.26, blue: 0.30)
    static let whisper = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let accent = Color(red: 0.26, green: 0.76, blue: 0.67)
    static let accentSecondary = Color(red: 0.44, green: 0.67, blue: 0.96)
    static let accentTertiary = Color(red: 0.43, green: 0.55, blue: 0.98)

    static let success = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let warning = Color(red: 1.0, green: 0.7, blue: 0.2)
    static let error = Color(red: 1.0, green: 0.3, blue: 0.3)

    static let background = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.98, green: 0.99, blue: 1.0),
            Color(red: 0.92, green: 0.95, blue: 0.99),
            Color(red: 0.90, green: 0.93, blue: 0.98)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color.white.opacity(0.44),
            Color.white.opacity(0.14)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardStroke = LinearGradient(
        gradient: Gradient(colors: [
            Color.white.opacity(0.78),
            Color.white.opacity(0.18),
            Color.black.opacity(0.08)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let darkGlass = LinearGradient(
        gradient: Gradient(colors: [
            Color.black.opacity(0.76),
            Color.black.opacity(0.56)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let glassSpecular = LinearGradient(
        gradient: Gradient(colors: [
            Color.white.opacity(0.52),
            Color.white.opacity(0.18),
            Color.white.opacity(0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let glassSheen = LinearGradient(
        gradient: Gradient(colors: [
            Color.white.opacity(0),
            Color.white.opacity(0.28),
            Color.white.opacity(0)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    static let deepShadow = Color.black.opacity(0.14)
}

// MARK: - Typography
struct Typography {
    static let displayLarge = Font.system(size: 36, weight: .bold, design: .serif)
    static let displayMedium = Font.system(size: 30, weight: .bold, design: .serif)
    static let headlineLarge = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let headlineMedium = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let titleLarge = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    static let labelSmall = Font.system(size: 12, weight: .medium, design: .default)
}

// MARK: - Spacing
struct Spacing {
    static let xs = 4.0
    static let sm = 8.0
    static let md = 16.0
    static let lg = 24.0
    static let xl = 32.0
    static let xxl = 48.0
}

// MARK: - Corner Radius
struct Radius {
    static let xs = 8.0
    static let sm = 12.0
    static let md = 16.0
    static let lg = 20.0
    static let xl = 24.0
}
