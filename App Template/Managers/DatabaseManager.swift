import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseFirestoreSwift
#endif

@MainActor
class DatabaseManager: NSObject, ObservableObject, UserStoring {
    static let shared = DatabaseManager()

    @Published var isLoading = false
    @Published var errorMessage: String?
    private let logger: Logging

#if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
#else
    private var inMemoryUsers: [String: User] = [:]
    private var inMemoryCollections: [String: [String: Data]] = [:]
#endif

    override init() {
        self.logger = AppLogger.shared
        super.init()
    }

    // MARK: - User Management

    func saveUser(_ user: User) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
#if canImport(FirebaseFirestore)
            try db.collection("users")
                .document(user.id)
                .setData(from: user, merge: true)
#else
            inMemoryUsers[user.id] = user
#endif
        } catch {
            errorMessage = "Failed to save user: \(error.localizedDescription)"
            logger.error("saveUser failed: \(error.localizedDescription)", category: "database")
            throw error
        }
    }

    func fetchUser(_ userId: String) async throws -> User? {
        isLoading = true
        defer { isLoading = false }

        do {
#if canImport(FirebaseFirestore)
            let document = try await db.collection("users")
                .document(userId)
                .getDocument()

            return try document.data(as: User.self)
#else
            return inMemoryUsers[userId]
#endif
        } catch {
            errorMessage = "Failed to fetch user: \(error.localizedDescription)"
            logger.error("fetchUser failed: \(error.localizedDescription)", category: "database")
            return nil
        }
    }

    func updateUserProfile(_ userId: String, displayName: String, profileImageURL: String?) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
#if canImport(FirebaseFirestore)
            try await db.collection("users")
                .document(userId)
                .updateData([
                    "displayName": displayName,
                    "profileImageURL": profileImageURL as Any
                ])
#else
            guard let existing = inMemoryUsers[userId] else { return }
            inMemoryUsers[userId] = User(
                id: existing.id,
                email: existing.email,
                displayName: displayName,
                profileImageURL: profileImageURL,
                createdAt: existing.createdAt,
                lastSignIn: existing.lastSignIn
            )
#endif
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            logger.error("updateUserProfile failed: \(error.localizedDescription)", category: "database")
            throw error
        }
    }

    // MARK: - Generic Data Storage

    func saveData<T: Encodable>(_ data: T, to collection: String, documentID: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
#if canImport(FirebaseFirestore)
            try db.collection(collection)
                .document(documentID)
                .setData(from: data, merge: true)
#else
            let encoded = try JSONEncoder().encode(data)
            var documents = inMemoryCollections[collection] ?? [:]
            documents[documentID] = encoded
            inMemoryCollections[collection] = documents
#endif
        } catch {
            errorMessage = "Failed to save data: \(error.localizedDescription)"
            logger.error("saveData failed: \(error.localizedDescription)", category: "database")
            throw error
        }
    }

    func fetchData<T: Decodable>(from collection: String, documentID: String, as type: T.Type) async throws -> T? {
        isLoading = true
        defer { isLoading = false }

        do {
#if canImport(FirebaseFirestore)
            let document = try await db.collection(collection)
                .document(documentID)
                .getDocument()

            return try document.data(as: T.self)
#else
            guard let encoded = inMemoryCollections[collection]?[documentID] else {
                return nil
            }
            return try JSONDecoder().decode(T.self, from: encoded)
#endif
        } catch {
            errorMessage = "Failed to fetch data: \(error.localizedDescription)"
            logger.error("fetchData failed: \(error.localizedDescription)", category: "database")
            return nil
        }
    }

    func deleteData(from collection: String, documentID: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
#if canImport(FirebaseFirestore)
            try await db.collection(collection)
                .document(documentID)
                .delete()
#else
            inMemoryCollections[collection]?[documentID] = nil
#endif
        } catch {
            errorMessage = "Failed to delete data: \(error.localizedDescription)"
            logger.error("deleteData failed: \(error.localizedDescription)", category: "database")
            throw error
        }
    }

    // MARK: - Query Methods

    func queryData<T: Decodable>(collection: String, whereField: String, isEqualTo value: Any, as type: T.Type) async throws -> [T] {
        isLoading = true
        defer { isLoading = false }

        do {
#if canImport(FirebaseFirestore)
            let snapshot = try await db.collection(collection)
                .whereField(whereField, isEqualTo: value)
                .getDocuments()

            return try snapshot.documents.compactMap { document in
                try document.data(as: T.self)
            }
#else
            guard let documents = inMemoryCollections[collection] else {
                return []
            }

            let decoder = JSONDecoder()
            return try documents.values.compactMap { encoded in
                let decoded = try decoder.decode(T.self, from: encoded)
                return matches(decoded, field: whereField, expectedValue: value) ? decoded : nil
            }
#endif
        } catch {
            errorMessage = "Failed to query data: \(error.localizedDescription)"
            logger.error("queryData failed: \(error.localizedDescription)", category: "database")
            throw error
        }
    }

    // MARK: - Batch Operations

    func batchWrite<T: Encodable>(_ items: [T], to collection: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
#if canImport(FirebaseFirestore)
            let batch = db.batch()

            for (index, item) in items.enumerated() {
                let docRef = db.collection(collection).document(String(index))
                try batch.setData(from: item, forDocument: docRef, merge: true)
            }

            try await batch.commit()
#else
            let encoder = JSONEncoder()
            var documents = inMemoryCollections[collection] ?? [:]

            for (index, item) in items.enumerated() {
                documents[String(index)] = try encoder.encode(item)
            }

            inMemoryCollections[collection] = documents
#endif
        } catch {
            errorMessage = "Batch write failed: \(error.localizedDescription)"
            logger.error("batchWrite failed: \(error.localizedDescription)", category: "database")
            throw error
        }
    }

#if !canImport(FirebaseFirestore)
    private func matches<T>(_ item: T, field: String, expectedValue: Any) -> Bool {
        let mirror = Mirror(reflecting: item)
        guard let child = mirror.children.first(where: { $0.label == field }) else {
            return false
        }

        return String(describing: child.value) == String(describing: expectedValue)
    }
#endif
}
