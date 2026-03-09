import Foundation

protocol OpenAIServing: AnyObject {
    var isConfigured: Bool { get }

    func generateFinanceInsight(prompt: String, financeSummary: String) async throws -> String
    func parseReceipt(from rawText: String) async throws -> ReceiptDraft
}

final class OpenAIService: OpenAIServing {
    static let shared = OpenAIService()

    private let session: URLSession
    private let config: AppConfig
    private let logger: Logging

    init(
        session: URLSession = .shared,
        config: AppConfig = .shared,
        logger: Logging = AppLogger.shared
    ) {
        self.session = session
        self.config = config
        self.logger = logger
    }

    var isConfigured: Bool {
        config.apiURL.host != nil
    }

    func generateFinanceInsight(prompt: String, financeSummary: String) async throws -> String {
        let endpoint = try makeEndpoint(path: "/api/finance/ai/insights")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = InsightsRequest(prompt: prompt, financeSummary: financeSummary)
        request.httpBody = try JSONEncoder().encode(payload)

        let response: InsightsResponse = try await execute(request: request)
        return response.message
    }

    func parseReceipt(from rawText: String) async throws -> ReceiptDraft {
        let endpoint = try makeEndpoint(path: "/api/finance/ai/parse-receipt")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ReceiptParseRequest(rawText: rawText)
        request.httpBody = try JSONEncoder().encode(payload)

        let response: ReceiptParseResponse = try await execute(request: request)
        let category = ExpenseCategory(rawValue: response.category) ?? .from(freeform: response.category)
        let purchaseDate = response.purchaseDateDate ?? Date()

        return ReceiptDraft(
            merchant: response.merchant,
            amount: response.amount,
            category: category,
            purchaseDate: purchaseDate,
            notes: response.notes
        )
    }

    private func makeEndpoint(path: String) throws -> URL {
        let base = config.apiURL
        guard let endpoint = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw OpenAIServiceError.invalidRequest
        }
        return endpoint
    }

    private func execute<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "Server AI request failed with status \(httpResponse.statusCode)."
            logger.error("Server AI request failed: \(message)", category: "openai")
            throw OpenAIServiceError.requestFailed(message)
        }

        do {
            return try JSONDecoder.aiDecoder.decode(T.self, from: data)
        } catch {
            logger.error("Failed to decode AI server response: \(error.localizedDescription)", category: "openai")
            throw OpenAIServiceError.invalidStructuredResponse
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["error"] as? String else {
            return nil
        }

        return message
    }
}

private struct InsightsRequest: Encodable {
    let prompt: String
    let financeSummary: String
}

private struct InsightsResponse: Decodable {
    let message: String
}

private struct ReceiptParseRequest: Encodable {
    let rawText: String
}

private struct ReceiptParseResponse: Decodable {
    let merchant: String
    let amount: Decimal
    let category: String
    let purchaseDate: String
    let notes: String?

    var purchaseDateDate: Date? {
        Self.dateFormatter.date(from: purchaseDate)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum OpenAIServiceError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case requestFailed(String)
    case invalidStructuredResponse

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Unable to prepare the AI request."
        case .invalidResponse:
            return "Received an invalid response from the finance server."
        case .requestFailed(let message):
            return message
        case .invalidStructuredResponse:
            return "AI response could not be decoded."
        }
    }
}

private extension JSONDecoder {
    static var aiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
