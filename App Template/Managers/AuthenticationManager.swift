import SwiftUI
import AuthenticationServices
import CryptoKit

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
    
    func signInWithGoogle() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let clientID = "925045680013-j3fvc6rl139nnrdfbrkk12c2npe3js65.apps.googleusercontent.com"
        let redirectScheme = "com.googleusercontent.apps.925045680013-j3fvc6rl139nnrdfbrkk12c2npe3js65"
        let redirectURI   = "\(redirectScheme):/oauth2redirect"

        let verifier  = makeCodeVerifier()
        let challenge = makeCodeChallenge(verifier)

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id",             value: clientID),
            .init(name: "redirect_uri",           value: redirectURI),
            .init(name: "response_type",          value: "code"),
            .init(name: "scope",                  value: "openid profile email"),
            .init(name: "code_challenge",         value: challenge),
            .init(name: "code_challenge_method",  value: "S256"),
        ]

        guard let authURL = comps.url else {
            errorMessage = "Could not build Google sign-in URL."
            return
        }

        do {
            let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: redirectScheme
                ) { url, error in
                    if let error { cont.resume(throwing: error) }
                    else if let url { cont.resume(returning: url) }
                    else { cont.resume(throwing: URLError(.cancelled)) }
                }
                session.prefersEphemeralWebBrowserSession = false
                session.presentationContextProvider = GoogleContextProvider.shared
                session.start()
            }

            guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value else {
                errorMessage = "Google sign-in: authorization code missing."
                return
            }

            let tokens   = try await exchangeGoogleCode(code, redirectURI: redirectURI, verifier: verifier, clientID: clientID)
            let userInfo = try decodeGoogleIDToken(tokens.idToken)

            let user = User(
                id: userInfo.sub,
                email: userInfo.email,
                displayName: userInfo.name ?? userInfo.email.components(separatedBy: "@").first ?? "User",
                profileImageURL: userInfo.picture,
                createdAt: Date(),
                lastSignIn: Date()
            )

            try await userRepository.saveUser(user)
            currentUser = user
            isAuthenticated = true
            analytics.track(event: AnalyticsEvent(name: "auth_sign_in_google_success"))
            logger.info("Signed in with Google: \(userInfo.email)", category: "auth")

        } catch {
            let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                         || (error as? URLError)?.code == .cancelled
            if !cancelled {
                errorMessage = "Google sign-in failed. Please try again."
                logger.error("Google sign-in failed: \(error.localizedDescription)", category: "auth")
            }
        }
    }

    func signOut() {
        logger.info("Signed out user", category: "auth")
        analytics.track(event: AnalyticsEvent(name: "auth_sign_out"))
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
    }

    // MARK: - Google OAuth helpers

    private func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeCodeChallenge(_ verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private struct GoogleTokens: Decodable {
        let idToken: String
        enum CodingKeys: String, CodingKey { case idToken = "id_token" }
    }

    private struct GoogleUserInfo {
        let sub: String
        let email: String
        let name: String?
        let picture: String?
    }

    private func exchangeGoogleCode(
        _ code: String, redirectURI: String, verifier: String, clientID: String
    ) async throws -> GoogleTokens {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params: [String: String] = [
            "code": code, "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) == true else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GoogleTokens.self, from: data)
    }

    private func decodeGoogleIDToken(_ idToken: String) throws -> GoogleUserInfo {
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else { throw URLError(.cannotDecodeContentData) }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub   = json["sub"]   as? String,
              let email = json["email"] as? String else {
            throw URLError(.cannotDecodeContentData)
        }
        return GoogleUserInfo(sub: sub, email: email,
                              name: json["name"] as? String,
                              picture: json["picture"] as? String)
    }
}

// MARK: - ASWebAuthenticationSession presentation context

private final class GoogleContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
