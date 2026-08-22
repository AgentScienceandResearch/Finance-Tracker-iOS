import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
class AuthenticationManager: NSObject, ObservableObject, AuthenticationManaging {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userRepository: UserRepositorying
    private let logger: Logging
    private let analytics: AnalyticsTracking
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init(
        userRepository: UserRepositorying,
        logger: Logging,
        analytics: AnalyticsTracking
    ) {
        self.userRepository = userRepository
        self.logger = logger
        self.analytics = analytics
        super.init()
        listenToAuthState()
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

    // MARK: - Firebase Auth state listener

    private func listenToAuthState() {
#if canImport(FirebaseAuth)
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            Task { @MainActor in
                if let firebaseUser {
                    let user = User(
                        id: firebaseUser.uid,
                        email: firebaseUser.email ?? "",
                        displayName: firebaseUser.displayName ?? firebaseUser.email?.components(separatedBy: "@").first ?? "User",
                        profileImageURL: firebaseUser.photoURL?.absoluteString,
                        createdAt: Date(),
                        lastSignIn: Date()
                    )
                    self.currentUser = user
                    self.isAuthenticated = true
                } else {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            }
        }
#endif
    }

    // MARK: - Email / Password

    func signInWithEmail(_ email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

#if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let uid = result.user.uid
            let user = User(
                id: uid,
                email: result.user.email ?? email,
                displayName: result.user.displayName ?? email.components(separatedBy: "@").first ?? "User",
                profileImageURL: result.user.photoURL?.absoluteString,
                createdAt: Date(),
                lastSignIn: Date()
            )
            try await userRepository.saveUser(user)
            currentUser = user
            isAuthenticated = true
            analytics.track(event: AnalyticsEvent(name: "auth_sign_in_email_success"))
            logger.info("Signed in with email: \(email)", category: "auth")
        } catch {
            errorMessage = firebaseAuthErrorMessage(error)
            logger.error("Email sign-in failed: \(error.localizedDescription)", category: "auth")
        }
#else
        errorMessage = "Firebase Auth not available."
#endif
    }

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        guard email.contains("@") else { errorMessage = "Invalid email format"; return }
        guard password.count >= 8 else { errorMessage = "Password must be at least 8 characters"; return }

#if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            AIWelcomePolicy.markEligibleForNewAccount(userID: result.user.uid)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            let user = User(
                id: result.user.uid,
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
            errorMessage = firebaseAuthErrorMessage(error)
            logger.error("Sign-up failed: \(error.localizedDescription)", category: "auth")
        }
#else
        errorMessage = "Firebase Auth not available."
#endif
    }

    // MARK: - Apple Sign In

    func signInWithApple(credentials: ASAuthorizationAppleIDCredential, rawNonce: String) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

#if canImport(FirebaseAuth)
        guard let tokenData = credentials.identityToken,
              let idTokenString = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "Apple Sign In failed: missing identity token."
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: credentials.fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: credential)
            if result.additionalUserInfo?.isNewUser == true {
                AIWelcomePolicy.markEligibleForNewAccount(userID: result.user.uid)
            }
            let displayName: String = {
                let given  = credentials.fullName?.givenName ?? ""
                let family = credentials.fullName?.familyName ?? ""
                let joined = "\(given) \(family)".trimmingCharacters(in: .whitespaces)
                return joined.isEmpty ? (result.user.displayName ?? result.user.email?.components(separatedBy: "@").first ?? "User") : joined
            }()

            let user = User(
                id: result.user.uid,
                email: result.user.email ?? credentials.email ?? "",
                displayName: displayName,
                profileImageURL: result.user.photoURL?.absoluteString,
                createdAt: Date(),
                lastSignIn: Date()
            )
            try await userRepository.saveUser(user)
            currentUser = user
            isAuthenticated = true
            analytics.track(event: AnalyticsEvent(name: "auth_sign_in_apple_success"))
            logger.info("Signed in with Apple uid=\(result.user.uid)", category: "auth")
        } catch {
            errorMessage = "Apple Sign In failed. Please try again."
            logger.error("Apple sign-in failed: \(error.localizedDescription)", category: "auth")
        }
#else
        errorMessage = "Firebase Auth not available."
#endif
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let clientID     = "925045680013-j3fvc6rl139nnrdfbrkk12c2npe3js65.apps.googleusercontent.com"
        let redirectScheme = "com.googleusercontent.apps.925045680013-j3fvc6rl139nnrdfbrkk12c2npe3js65"
        let redirectURI  = "\(redirectScheme):/oauth2redirect"

        let verifier  = makeCodeVerifier()
        let challenge = makeCodeChallenge(verifier)

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id",            value: clientID),
            .init(name: "redirect_uri",          value: redirectURI),
            .init(name: "response_type",         value: "code"),
            .init(name: "scope",                 value: "openid profile email"),
            .init(name: "code_challenge",        value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
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

            let tokens = try await exchangeGoogleCode(code, redirectURI: redirectURI, verifier: verifier, clientID: clientID)

#if canImport(FirebaseAuth)
            let firebaseCredential = GoogleAuthProvider.credential(
                withIDToken: tokens.idToken,
                accessToken: tokens.accessToken ?? ""
            )
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            if result.additionalUserInfo?.isNewUser == true {
                AIWelcomePolicy.markEligibleForNewAccount(userID: result.user.uid)
            }
            let userInfo = try decodeGoogleIDToken(tokens.idToken)

            let user = User(
                id: result.user.uid,
                email: result.user.email ?? userInfo.email,
                displayName: result.user.displayName ?? userInfo.name ?? userInfo.email.components(separatedBy: "@").first ?? "User",
                profileImageURL: result.user.photoURL?.absoluteString ?? userInfo.picture,
                createdAt: Date(),
                lastSignIn: Date()
            )
            try await userRepository.saveUser(user)
            currentUser = user
            isAuthenticated = true
            analytics.track(event: AnalyticsEvent(name: "auth_sign_in_google_success"))
            logger.info("Signed in with Google: \(userInfo.email)", category: "auth")
#else
            errorMessage = "Firebase Auth not available."
#endif

        } catch {
            let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                         || (error as? URLError)?.code == .cancelled
            if !cancelled {
                errorMessage = "Google sign-in failed. Please try again."
                logger.error("Google sign-in failed: \(error.localizedDescription)", category: "auth")
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        logger.info("Signed out user", category: "auth")
        analytics.track(event: AnalyticsEvent(name: "auth_sign_out"))
#if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
#endif
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
    }

    // MARK: - Helpers

    private func firebaseAuthErrorMessage(_ error: Error) -> String {
#if canImport(FirebaseAuth)
        switch (error as NSError).code {
        case AuthErrorCode.wrongPassword.rawValue:        return "Incorrect password."
        case AuthErrorCode.invalidEmail.rawValue:         return "Invalid email address."
        case AuthErrorCode.userNotFound.rawValue:         return "No account found. Try signing up."
        case AuthErrorCode.emailAlreadyInUse.rawValue:    return "Email already in use. Try signing in."
        case AuthErrorCode.weakPassword.rawValue:         return "Password is too weak."
        case AuthErrorCode.networkError.rawValue:         return "Network error. Check your connection."
        default:                                          return "Authentication failed. Please try again."
        }
#else
        return error.localizedDescription
#endif
    }

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
        let accessToken: String?
        enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
            case accessToken = "access_token"
        }
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

enum AppleSignInNonce {
    static func generate(length: Int = 32) -> String? {
        guard length > 0 else { return nil }
        var randomBytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes) == errSecSuccess else {
            return nil
        }

        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { characters[Int($0) % characters.count] })
    }

    static func hash(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
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
