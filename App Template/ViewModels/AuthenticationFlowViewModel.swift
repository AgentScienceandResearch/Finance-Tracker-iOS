import Foundation

@MainActor
final class AuthenticationFlowViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isSignUp = false
    @Published var displayName = ""
    @Published var isSubmitting = false
    @Published var inlineError: String?

    private let authManager: AuthenticationManaging

    init(authManager: AuthenticationManaging) {
        self.authManager = authManager
    }

    var canSubmit: Bool {
        guard email.contains("@"), password.count >= 8 else {
            return false
        }

        if isSignUp {
            return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return true
    }

    func toggleMode() {
        isSignUp.toggle()
        inlineError = nil
        authManager.errorMessage = nil
    }

    @discardableResult
    func submit() async -> Bool {
        guard canSubmit else {
            inlineError = isSignUp
                ? "Enter a valid email, 8+ character password, and display name."
                : "Enter a valid email and 8+ character password."
            return false
        }

        isSubmitting = true
        inlineError = nil
        defer { isSubmitting = false }

        if isSignUp {
            await authManager.signUp(
                email: email,
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else {
            await authManager.signInWithEmail(email, password: password)
        }

        inlineError = authManager.errorMessage
        return authManager.isAuthenticated
    }
}
