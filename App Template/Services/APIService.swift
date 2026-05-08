import Foundation

// MARK: - API Configuration
struct APIConfiguration {
    static let shared = APIConfiguration()

    // API Endpoints
    let baseURL = AppConfig.shared.apiURL.absoluteString
    let apiVersion = "v1"

    // Timeouts
    let requestTimeout: TimeInterval = 30
    let uploadTimeout: TimeInterval = 60

    // MARK: - Endpoints

    var authEndpoints: AuthEndpoints {
        AuthEndpoints(baseURL: baseURL)
    }

    var userEndpoints: UserEndpoints {
        UserEndpoints(baseURL: baseURL)
    }

    var subscriptionEndpoints: SubscriptionEndpoints {
        SubscriptionEndpoints(baseURL: baseURL)
    }
}

// MARK: - Auth Endpoints
struct AuthEndpoints {
    let baseURL: String

    var register: URL? { URL(string: "\(baseURL)/api/auth/register") }
    var login: URL? { URL(string: "\(baseURL)/api/auth/login") }
    var verify: URL? { URL(string: "\(baseURL)/api/auth/verify") }
    var refresh: URL? { URL(string: "\(baseURL)/api/auth/refresh") }
}

// MARK: - User Endpoints
struct UserEndpoints {
    let baseURL: String

    var profile: URL? { URL(string: "\(baseURL)/api/users/profile") }
    var stats: URL? { URL(string: "\(baseURL)/api/users/stats") }

    func updateProfile() -> URL? {
        URL(string: "\(baseURL)/api/users/profile")
    }
}

// MARK: - Subscription Endpoints
struct SubscriptionEndpoints {
    let baseURL: String

    var status: URL? { URL(string: "\(baseURL)/api/subscriptions/status") }
    var plans: URL? { URL(string: "\(baseURL)/api/subscriptions/plans/available") }
    var validateReceipt: URL? { URL(string: "\(baseURL)/api/subscriptions/validate-receipt") }

    func cancel(subscriptionId: String) -> URL? {
        URL(string: "\(baseURL)/api/subscriptions/\(subscriptionId)")
    }
}

// MARK: - API Service
class APIService: NSObject, ObservableObject, APIServing {
    static let shared = APIService()

    private let configuration = APIConfiguration.shared
    private let logger: Logging = AppLogger.shared

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Generic Request Method

    func request<T: Decodable>(
        url: URL,
        method: String = "GET",
        headers: [String: String]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> T {
        isLoading = true
        defer { isLoading = false }

        do {
            return try await performRequest(url: url, method: method, headers: headers, body: body)
        } catch APIError.unauthorized {
            if try await refreshTokens() {
                return try await performRequest(url: url, method: method, headers: headers, body: body)
            }
            clearToken()
            throw APIError.unauthorized
        }
    }

    private func performRequest<T: Decodable>(
        url: URL,
        method: String,
        headers: [String: String]?,
        body: (any Encodable)?
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        if let token = getStoredToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response for \(method) \(url.absoluteString)", category: "api")
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                logger.warning("Unauthorized response for \(url.absoluteString)", category: "api")
                throw APIError.unauthorized
            }
            logger.error("Server error \(httpResponse.statusCode) for \(url.absoluteString)", category: "api")
            throw APIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Decoding error for \(url.absoluteString): \(error.localizedDescription)", category: "api")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Token Management

    private enum KeychainKey {
        static let accessToken = "api.access_token"
        static let refreshToken = "api.refresh_token"
    }

    func saveToken(_ token: String) {
        KeychainService.save(token, for: KeychainKey.accessToken)
    }

    func saveRefreshToken(_ token: String) {
        KeychainService.save(token, for: KeychainKey.refreshToken)
    }

    func getStoredToken() -> String? {
        KeychainService.load(for: KeychainKey.accessToken)
    }

    func getStoredRefreshToken() -> String? {
        KeychainService.load(for: KeychainKey.refreshToken)
    }

    func clearToken() {
        KeychainService.delete(for: KeychainKey.accessToken)
        KeychainService.delete(for: KeychainKey.refreshToken)
    }

    @discardableResult
    private func refreshTokens() async throws -> Bool {
        guard let refreshToken = getStoredRefreshToken(),
              let url = URL(string: "\(configuration.baseURL)/api/auth/refresh")
        else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["refreshToken": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else { return false }

        struct RefreshResponse: Decodable {
            let token: String
            let refreshToken: String
        }

        guard let refreshed = try? JSONDecoder().decode(RefreshResponse.self, from: data) else {
            return false
        }

        saveToken(refreshed.token)
        saveRefreshToken(refreshed.refreshToken)
        return true
    }
}

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        self.encodeClosure = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case decodingError(Error)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - please sign in again"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let message):
            return message
        }
    }
}

// MARK: - Request Models
struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let displayName: String
}

struct ValidateReceiptRequest: Encodable {
    let receipt: String
    let productId: String
}

// MARK: - Response Models
struct AuthResponse: Codable {
    let user: UserResponse
    let token: String
    let refreshToken: String?
}

struct UserResponse: Codable {
    let id: String
    let email: String
    let displayName: String
    let isSubscribed: Bool?
}

struct SubscriptionStatusResponse: Codable {
    let isSubscribed: Bool
    let plan: String?
    let expiryDate: Date?
}
