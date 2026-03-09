import Foundation

@MainActor
protocol AuthenticationManaging: AnyObject {
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get set }

    func signInWithEmail(_ email: String, password: String) async
    func signUp(email: String, password: String, displayName: String) async
    func signOut()
}
