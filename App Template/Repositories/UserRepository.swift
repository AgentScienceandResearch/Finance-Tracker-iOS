import Foundation

@MainActor
protocol UserRepositorying: AnyObject {
    func saveUser(_ user: User) async throws
    func fetchUser(_ userId: String) async throws -> User?
}

@MainActor
final class UserRepository: UserRepositorying {
    private let userStore: UserStoring

    init(userStore: UserStoring) {
        self.userStore = userStore
    }

    func saveUser(_ user: User) async throws {
        try await userStore.saveUser(user)
    }

    func fetchUser(_ userId: String) async throws -> User? {
        try await userStore.fetchUser(userId)
    }
}
