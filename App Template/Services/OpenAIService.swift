import Foundation

protocol OpenAIServing: AnyObject {
    var isConfigured: Bool { get }

    func generateFinanceAssistantReply(
        prompt: String,
        snapshot: FinanceAISnapshot,
        conversation: [FinanceAIConversationTurn]
    ) async throws -> FinanceAIServiceResponse
    func parseReceipt(from rawText: String) async throws -> ReceiptDraft
    func parseImage(imageBase64: String, mimeType: String) async throws -> [ReceiptDraft]
    func getCategoryInsight(category: String, amount: Double, percentage: Double, monthlyTotal: Double, recentTransactions: String) async throws -> String
}

struct FinanceAISnapshot: Encodable {
    let generatedAt: Date
    let currencyCode: String
    let monthlyBudget: Decimal?
    let spendingThisMonth: Decimal
    let spendingThisWeek: Decimal
    let recurringMonthlyTotal: Decimal
    let transactions: [Expense]
    let recurringTransactions: [RecurringExpense]
}

struct FinanceAIConversationTurn: Encodable {
    let role: String
    let content: String
}

struct FinanceAIServiceResponse: Decodable {
    let message: String
    let actions: [FinanceAIToolCall]

    private enum CodingKeys: String, CodingKey {
        case message
        case actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
        actions = try container.decodeIfPresent([FinanceAIToolCall].self, forKey: .actions) ?? []
    }
}

struct FinanceAIToolCall: Decodable {
    let id: String
    let type: String
    let input: FinanceAIToolInput
}

struct FinanceAIToolInput: Decodable {
    let transactionID: String?
    let recurringID: String?
    let title: String?
    let amount: Decimal?
    let category: String?
    let date: String?
    let notes: String?
    let clearNotes: Bool?
    let frequency: String?
    let nextDueDate: String?
    let isActive: Bool?

    private enum CodingKeys: String, CodingKey {
        case transactionID = "transactionId"
        case recurringID = "recurringId"
        case title
        case amount
        case category
        case date
        case notes
        case clearNotes
        case frequency
        case nextDueDate
        case isActive
    }
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

    func generateFinanceAssistantReply(
        prompt: String,
        snapshot: FinanceAISnapshot,
        conversation: [FinanceAIConversationTurn]
    ) async throws -> FinanceAIServiceResponse {
        let endpoint = try makeEndpoint(path: "/api/finance/ai/assistant")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = FinanceAssistantRequest(
            prompt: prompt,
            snapshot: snapshot,
            conversation: conversation
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        return try await execute(request: request)
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

    func parseImage(imageBase64: String, mimeType: String) async throws -> [ReceiptDraft] {
        let endpoint = try makeEndpoint(path: "/api/finance/ai/parse-image")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ImageParseRequest(imageBase64: imageBase64, mimeType: mimeType)
        request.httpBody = try JSONEncoder().encode(payload)

        let response: ImageParseResponse = try await execute(request: request)
        let today = Date()
        return response.transactions.map { t in
            let category = ExpenseCategory(rawValue: t.category) ?? .from(freeform: t.category)
            let date = Self.isoDateFormatter.date(from: t.purchaseDate) ?? today
            return ReceiptDraft(
                merchant: t.merchant,
                amount: Decimal(t.amount),
                category: category,
                purchaseDate: date,
                notes: t.notes
            )
        }
    }

    func getCategoryInsight(category: String, amount: Double, percentage: Double, monthlyTotal: Double, recentTransactions: String) async throws -> String {
        let endpoint = try makeEndpoint(path: "/api/finance/ai/category-insight")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = CategoryInsightRequest(
            category: category,
            amount: amount,
            percentage: percentage,
            monthlyTotal: monthlyTotal,
            recentTransactions: recentTransactions
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let response: CategoryInsightResponse = try await execute(request: request)
        return response.insight
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

private struct ImageParseRequest: Encodable {
    let imageBase64: String
    let mimeType: String
}

private struct ImageTransaction: Decodable {
    let merchant: String
    let amount: Double
    let category: String
    let purchaseDate: String
    let notes: String?
}

private struct ImageParseResponse: Decodable {
    let transactions: [ImageTransaction]
}

private extension OpenAIService {
    static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

private struct CategoryInsightRequest: Encodable {
    let category: String
    let amount: Double
    let percentage: Double
    let monthlyTotal: Double
    let recentTransactions: String
}

private struct CategoryInsightResponse: Decodable {
    let insight: String
}

private struct FinanceAssistantRequest: Encodable {
    let prompt: String
    let snapshot: FinanceAISnapshot
    let conversation: [FinanceAIConversationTurn]
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
