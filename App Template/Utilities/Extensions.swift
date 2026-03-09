import SwiftUI

// MARK: - View Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    func dismissKeyboardOnTapOutsideTextInput() -> some View {
        background(
            KeyboardDismissTapCapture()
                .allowsHitTesting(false)
        )
    }
}

// MARK: - Rounded Corner Shape
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Color Extensions
extension Color {
    static func fromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let rgb = Int(hex, radix: 16) ?? 0
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - String Extensions
extension String {
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    var isValidPassword: Bool {
        return self.count >= 8
    }
    
    func truncated(to length: Int) -> String {
        if self.count > length {
            return String(self.prefix(length)) + "..."
        }
        return self
    }
}

// MARK: - Date Extensions
extension Date {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    var timeAgo: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: now)
        
        if let year = components.year, year > 0 {
            return "\(year) year\(year > 1 ? "s" : "") ago"
        }
        if let month = components.month, month > 0 {
            return "\(month) month\(month > 1 ? "s" : "") ago"
        }
        if let day = components.day, day > 0 {
            return "\(day) day\(day > 1 ? "s" : "") ago"
        }
        if let hour = components.hour, hour > 0 {
            return "\(hour) hour\(hour > 1 ? "s" : "") ago"
        }
        if let minute = components.minute, minute > 0 {
            return "\(minute) minute\(minute > 1 ? "s" : "") ago"
        }
        return "Just now"
    }
}

// MARK: - Number Extensions
extension Double {
    var formatted: String {
        let number = NSNumber(value: self)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: number) ?? ""
    }
    
    var percentageFormatted: String {
        return String(format: "%.1f%%", self * 100)
    }
}

// MARK: - Array Extensions
extension Array where Element: Identifiable {
    mutating func toggle(_ item: Element) where Element: Equatable {
        if let index = firstIndex(of: item) {
            remove(at: index)
        } else {
            append(item)
        }
    }
}

// MARK: - Animation Extensions
extension Animation {
    static var customSpring: Animation {
        .spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)
    }
    
    static var smoothEmphasis: Animation {
        .easeInOut(duration: 0.3)
    }
}

// MARK: - Haptic Feedback Helper
final class HapticFeedback {
    static let shared = HapticFeedback()

    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        DispatchQueue.main.async {
            let generator: UIImpactFeedbackGenerator
            switch style {
            case .light, .soft, .rigid:
                generator = self.lightImpactGenerator
            case .heavy:
                generator = self.heavyImpactGenerator
            case .medium:
                generator = self.mediumImpactGenerator
            @unknown default:
                generator = self.mediumImpactGenerator
            }
            generator.prepare()
            generator.impactOccurred(intensity: 1.0)
        }
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        DispatchQueue.main.async {
            self.notificationGenerator.prepare()
            self.notificationGenerator.notificationOccurred(type)
        }
    }
}

// MARK: - Device Helpers
class DeviceInfo {
    static var isSmallDevice: Bool {
        UIScreen.main.bounds.height < 700
    }
    
    static var isSafeAreaBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?
            .safeAreaInsets.bottom ?? 0
    }
}

// MARK: - UserDefaults Helper
class AppStorage {
    static let shared = AppStorage()
    
    func set(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    func get(_ key: String) -> Any? {
        UserDefaults.standard.object(forKey: key)
    }
    
    func getString(_ key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }
    
    func getInt(_ key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }
    
    func getBool(_ key: String) -> Bool {
        UserDefaults.standard.bool(forKey: key)
    }
    
    func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    func clear() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }
}

// MARK: - Keyboard Dismiss Helpers
private struct KeyboardDismissTapCapture: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissCaptureView {
        KeyboardDismissCaptureView()
    }

    func updateUIView(_ uiView: KeyboardDismissCaptureView, context: Context) {}
}

private final class KeyboardDismissCaptureView: UIView, UIGestureRecognizerDelegate {
    private weak var installedWindow: UIWindow?

    private lazy var tapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard installedWindow !== window else { return }

        installedWindow?.removeGestureRecognizer(tapRecognizer)
        installedWindow = window
        installedWindow?.addGestureRecognizer(tapRecognizer)
    }

    deinit {
        installedWindow?.removeGestureRecognizer(tapRecognizer)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        installedWindow?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchedView = touch.view else { return true }
        return !touchedView.isWithinTextInput
    }
}

private extension UIView {
    var isWithinTextInput: Bool {
        var current: UIView? = self
        while let view = current {
            if view is UITextField || view is UITextView {
                return true
            }
            current = view.superview
        }
        return false
    }
}
