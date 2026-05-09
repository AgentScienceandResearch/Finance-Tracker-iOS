import Foundation
#if canImport(FirebaseCore)
import FirebaseCore

/// Call FirebaseApp.configure() exactly once, at app launch.
/// Wrapped in a canImport guard so the file compiles even when
/// Firebase is not yet resolved by SPM (e.g. first checkout).
enum FirebaseBootstrap {
    static func configure() {
        FirebaseApp.configure()
    }
}
#else
enum FirebaseBootstrap {
    static func configure() { /* Firebase not available */ }
}
#endif
