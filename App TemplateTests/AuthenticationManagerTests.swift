import XCTest

#if canImport(App_Template)
@testable import App_Template
#elseif canImport(TemplateApp)
@testable import TemplateApp
#endif

#if canImport(App_Template) || canImport(TemplateApp)
@MainActor
final class AuthenticationManagerTests: XCTestCase {
    final class MockUserRepository: UserRepositorying {
        var savedUsers: [User] = []
        var nextSaveError: Error?

        func saveUser(_ user: User) async throws {
            if let nextSaveError {
                throw nextSaveError
            }
            savedUsers.append(user)
        }

        func fetchUser(_ userId: String) async throws -> User? {
            savedUsers.first(where: { $0.id == userId })
        }
    }

    enum StubError: Error {
        case saveFailed
    }

    func testSignInWithEmailRejectsInvalidEmail() async {
        let repository = MockUserRepository()
        let manager = AuthenticationManager(userRepository: repository)

        await manager.signInWithEmail("invalid-email", password: "password123")

        XCTAssertFalse(manager.isAuthenticated)
        XCTAssertEqual(manager.errorMessage, "Invalid email format")
        XCTAssertTrue(repository.savedUsers.isEmpty)
    }

    func testSignUpRejectsShortPassword() async {
        let repository = MockUserRepository()
        let manager = AuthenticationManager(userRepository: repository)

        await manager.signUp(email: "user@example.com", password: "123", displayName: "Dakota")

        XCTAssertFalse(manager.isAuthenticated)
        XCTAssertEqual(manager.errorMessage, "Password must be at least 8 characters")
        XCTAssertTrue(repository.savedUsers.isEmpty)
    }

    func testSignInWithEmailPersistsAndAuthenticatesUser() async {
        let repository = MockUserRepository()
        let manager = AuthenticationManager(userRepository: repository)

        await manager.signInWithEmail("orbit@example.com", password: "password123")

        XCTAssertTrue(manager.isAuthenticated)
        XCTAssertEqual(manager.currentUser?.email, "orbit@example.com")
        XCTAssertEqual(manager.currentUser?.displayName, "orbit")
        XCTAssertEqual(repository.savedUsers.count, 1)
    }

    func testSignUpHandlesUserStoreFailure() async {
        let repository = MockUserRepository()
        repository.nextSaveError = StubError.saveFailed
        let manager = AuthenticationManager(userRepository: repository)

        await manager.signUp(email: "user@example.com", password: "password123", displayName: "Dakota")

        XCTAssertFalse(manager.isAuthenticated)
        XCTAssertEqual(manager.errorMessage, "Sign up failed. Please try again.")
    }

    func testSignOutClearsSessionState() async {
        let repository = MockUserRepository()
        let manager = AuthenticationManager(userRepository: repository)
        await manager.signInWithEmail("clear@example.com", password: "password123")

        manager.signOut()

        XCTAssertFalse(manager.isAuthenticated)
        XCTAssertNil(manager.currentUser)
        XCTAssertNil(manager.errorMessage)
    }
}
#endif
