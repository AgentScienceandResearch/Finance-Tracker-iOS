import Foundation

/// Identifies this install and its App Store subscription to the AI server, which
/// grants unlimited AI to subscribers and a small monthly allowance to everyone else.
final class AIAccessCredentials: @unchecked Sendable {
    static let shared = AIAccessCredentials()

    private static let deviceIDKey = "ai.deviceID"

    private let lock = NSLock()
    private var storedTransactionJWS: String?
    private var storedFreeRemaining: Int?
    private var storedDeviceID: String?

    /// Apple-signed JWS of the active subscription transaction, or nil on the free plan.
    var transactionJWS: String? {
        get { lock.withLock { storedTransactionJWS } }
        set { lock.withLock { storedTransactionJWS = newValue } }
    }

    /// Free AI messages left this month, as last reported by the server.
    var freeMessagesRemaining: Int? {
        get { lock.withLock { storedFreeRemaining } }
        set { lock.withLock { storedFreeRemaining = newValue } }
    }

    /// Stable per-install identifier. Kept in the Keychain so reinstalling the app
    /// does not reset the free allowance.
    var deviceID: String {
        lock.withLock {
            if let storedDeviceID { return storedDeviceID }
            let id = KeychainService.load(for: Self.deviceIDKey) ?? {
                let fresh = UUID().uuidString.lowercased()
                KeychainService.save(fresh, for: Self.deviceIDKey)
                return fresh
            }()
            storedDeviceID = id
            return id
        }
    }

    func authorize(_ request: inout URLRequest) {
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        if let transactionJWS {
            request.setValue(transactionJWS, forHTTPHeaderField: "X-App-Store-Transaction")
        }
    }

    func record(_ response: HTTPURLResponse) {
        switch response.value(forHTTPHeaderField: "X-AI-Plan") {
        case "pro":
            freeMessagesRemaining = nil
        case "free":
            if let remaining = response.value(forHTTPHeaderField: "X-AI-Free-Remaining").flatMap(Int.init) {
                freeMessagesRemaining = remaining
            }
        default:
            break
        }
    }
}
