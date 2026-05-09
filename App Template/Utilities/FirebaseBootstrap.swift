import Foundation
#if canImport(FirebaseCore)
import FirebaseCore

/// Call once at app launch. Safe to call even when GoogleService-Info.plist
/// is missing or incomplete — it will simply skip Firebase configuration and
/// DatabaseManager will fall back to in-memory storage automatically.
enum FirebaseBootstrap {
    static func configure() {
        // Prevent double-configure (e.g. SwiftUI previews calling App.init() twice)
        guard FirebaseApp.app() == nil else { return }

        // Use FirebaseOptions(contentsOfFile:) so we can nil-check before configuring.
        // FirebaseApp.configure() throws an NSException if GOOGLE_APP_ID is missing;
        // FirebaseOptions init returns nil for any invalid plist instead of crashing.
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path) else {
            // No valid plist — DatabaseManager will use in-memory fallback, no crash.
            return
        }

        FirebaseApp.configure(options: options)
    }
}
#else
enum FirebaseBootstrap {
    static func configure() { /* Firebase not available */ }
}
#endif
