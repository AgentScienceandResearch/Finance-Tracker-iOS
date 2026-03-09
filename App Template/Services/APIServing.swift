import Foundation

protocol APIServing: AnyObject {
    func request<T: Decodable>(
        url: URL,
        method: String,
        headers: [String: String]?,
        body: (any Encodable)?
    ) async throws -> T

    func saveToken(_ token: String)
    func getStoredToken() -> String?
    func clearToken()
}
