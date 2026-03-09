import XCTest

#if canImport(App_Template)
@testable import App_Template
#elseif canImport(TemplateApp)
@testable import TemplateApp
#endif

#if canImport(App_Template) || canImport(TemplateApp)
@MainActor
final class DatabaseManagerTests: XCTestCase {
    private struct TestRecord: Codable, Equatable {
        let id: String
        let title: String
        let category: String
    }

    func testSaveAndFetchUserRoundTrip() async throws {
        let manager = DatabaseManager.shared
        let userID = "test-user-\(UUID().uuidString)"
        let user = User(
            id: userID,
            email: "user@example.com",
            displayName: "Dakota",
            profileImageURL: nil,
            createdAt: Date(),
            lastSignIn: Date()
        )

        try await manager.saveUser(user)
        let fetched = try await manager.fetchUser(userID)

        XCTAssertEqual(fetched?.id, userID)
        XCTAssertEqual(fetched?.email, user.email)
    }

    func testSaveFetchAndDeleteGenericData() async throws {
        let manager = DatabaseManager.shared
        let collection = "records_\(UUID().uuidString)"
        let record = TestRecord(id: "1", title: "Alpha", category: "demo")

        try await manager.saveData(record, to: collection, documentID: record.id)
        let fetched: TestRecord? = try await manager.fetchData(from: collection, documentID: record.id, as: TestRecord.self)
        XCTAssertEqual(fetched, record)

        try await manager.deleteData(from: collection, documentID: record.id)
        let afterDelete: TestRecord? = try await manager.fetchData(from: collection, documentID: record.id, as: TestRecord.self)
        XCTAssertNil(afterDelete)
    }

    func testQueryDataFiltersByField() async throws {
        let manager = DatabaseManager.shared
        let collection = "query_records_\(UUID().uuidString)"

        let first = TestRecord(id: "1", title: "One", category: "a")
        let second = TestRecord(id: "2", title: "Two", category: "b")
        let third = TestRecord(id: "3", title: "Three", category: "a")

        try await manager.saveData(first, to: collection, documentID: first.id)
        try await manager.saveData(second, to: collection, documentID: second.id)
        try await manager.saveData(third, to: collection, documentID: third.id)

        let filtered: [TestRecord] = try await manager.queryData(
            collection: collection,
            whereField: "category",
            isEqualTo: "a",
            as: TestRecord.self
        )

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.category == "a" })
    }
}
#endif
