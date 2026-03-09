import SwiftUI
import AuthenticationServices

@MainActor
class AuthenticationManager: NSObject, ObservableObject, AuthenticationManaging {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userRepository: UserRepositorying
    private let logger: Logging
    private let analytics: AnalyticsTracking

    init(
        userRepository: UserRepositorying,
        logger: Logging,
        analytics: AnalyticsTracking
    ) {
        self.userRepository = userRepository
        self.logger = logger
        self.analytics = analytics
        super.init()
    }

    convenience init(userRepository: UserRepositorying) {
        self.init(
            userRepository: userRepository,
            logger: AppLogger.shared,
            analytics: NoOpAnalyticsTracker.shared
        )
    }

    convenience override init() {
        self.init(
            userRepository: UserRepository(userStore: DatabaseManager.shared),
            logger: AppLogger.shared,
            analytics: NoOpAnalyticsTracker.shared
        )
    }
    
    // MARK: - Authentication Methods
    
    func signInWithApple(credentials: ASAuthorizationAppleIDCredential) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let user = User(
                id: credentials.user,
                email: credentials.email ?? "user@example.com",
                displayName: "\(credentials.fullName?.givenName ?? "") \(credentials.fullName?.familyName ?? "")".trimmingCharacters(in: .whitespaces),
                profileImageURL: nil,
                createdAt: Date(),
                lastSignIn: Date()
            )
            
            try await userRepository.saveUser(user)
            currentUser = user
            isAuthenticated = true
            analytics.track(event: AnalyticsEvent(name: "auth_sign_in_apple_success"))
            logger.info("Signed in with Apple", category: "auth")
            
        } catch {
            errorMessage = "Failed to sign in: \(error.localizedDescription)"
            logger.error("Apple sign-in failed: \(error.localizedDescription)", category: "auth")
        }
    }
    
    func signInWithEmail(_ email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Validate input
            guard email.contains("@") else {
                errorMessage = "Invalid email format"
                return
            }
            
            // This would connect to your backend API
            let user = User(
                id: UUID().uuidString,
                email: email,
                displayName: email.components(separatedBy: "@").first ?? "User",
                profileImageURL: nil,
                createdAt: Date(),
                lastSignIn: Date()
            )
            
            try await userRepository.saveUser(user)
            currentUser = user
            isAuthenticated = true
            analytics.track(event: AnalyticsEvent(name: "auth_sign_in_email_success"))
            logger.info("Signed in with email: \(email)", category: "auth")
            
        } catch {
            errorMessage = "Sign in failed. Please try again."
            logger.error("Email sign-in failed: \(error.localizedDescription)", category: "auth")
        }
    }
    
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard email.contains("@") else {
                errorMessage = "Invalid email format"
                return
            }
            
            guard password.count >= 8 else {
                errorMessage = "Password must be at least 8 characters"
                return
            }
            
            let user = User(
                id: UUID().uuidString,
                email: email,
                displayName: displayName,
                profileImageURL: nil,
                createdAt: Date(),
                lastSignIn: Date()
            )
            
            try await userRepository.saveUser(user)
            currentUser = user
            isAuthenticated = true
            analytics.track(event: AnalyticsEvent(name: "auth_sign_up_success"))
            logger.info("Signed up new user: \(email)", category: "auth")
            
        } catch {
            errorMessage = "Sign up failed. Please try again."
            logger.error("Sign-up failed: \(error.localizedDescription)", category: "auth")
        }
    }
    
    func signOut() {
        logger.info("Signed out user", category: "auth")
        analytics.track(event: AnalyticsEvent(name: "auth_sign_out"))
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
    }
}
