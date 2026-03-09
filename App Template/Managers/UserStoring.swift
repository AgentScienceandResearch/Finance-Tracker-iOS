import Foundation

@MainActor
protocol UserStoring: AnyObject {
    func saveUser(_ user: User) async throws
    func fetchUser(_ userId: String) async throws -> User?
}
