import Foundation

@MainActor
final class FinanceManager: ObservableObject {
    static let shared = FinanceManager()

    @Published private(set) var currentProfile: User
    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var recurringExpenses: [RecurringExpense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private static let localStorageKey = "financeTrackerState.v1"
    private static let profileStorageKey = "financeUserProfile.v1"
    private static let fallbackUserIDKey = "financeFallbackUserID"

    private let databaseManager: DatabaseManager
    private let userDefaults: UserDefaults
    private let logger: Logging
    private let calendar: Calendar
    private let remoteSyncEnabled: Bool

    init(
        databaseManager: DatabaseManager = .shared,
        userDefaults: UserDefaults = .standard,
        logger: Logging = AppLogger.shared,
        calendar: Calendar = .current,
        remoteSyncEnabled: Bool = true
    ) {
        self.databaseManager = databaseManager
        self.userDefaults = userDefaults
        self.logger = logger
        self.calendar = calendar
        self.remoteSyncEnabled = remoteSyncEnabled

        self.currentProfile = Self.loadOrCreateLocalProfile(userDefaults: userDefaults)
        loadLocalState()

        if remoteSyncEnabled {
            Task {
                await syncProfileFromRemote()
                await saveProfileToRemote()
                await syncFromRemote()
            }
        }
    }

    var thisMonthTotal: Decimal {
        let now = Date()
        return expenses
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var thisWeekTotal: Decimal {
        let now = Date()
        return expenses
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var recurringMonthlyTotal: Decimal {
        recurringExpenses
            .filter(\.isActive)
            .reduce(Decimal.zero) { $0 + $1.normalizedMonthlyCost }
    }

    var activeRecurringCount: Int {
        recurringExpenses.filter(\.isActive).count
    }

    var upcomingRecurringExpenses: [RecurringExpense] {
        let now = Date()
        let horizon = calendar.date(byAdding: .day, value: 45, to: now) ?? now

        return recurringExpenses
            .filter { $0.isActive && $0.nextDueDate >= now && $0.nextDueDate <= horizon }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    func recentExpenses(limit: Int = 5) -> [Expense] {
        expenses
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    func filteredExpenses(searchText: String, category: ExpenseCategory?) -> [Expense] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return expenses
            .filter { expense in
                let categoryMatches = category == nil || expense.category == category
                guard !trimmedQuery.isEmpty else { return categoryMatches }

                let query = trimmedQuery.lowercased()
                let titleMatches = expense.title.lowercased().contains(query)
                let notesMatches = expense.notes?.lowercased().contains(query) ?? false
                return categoryMatches && (titleMatches || notesMatches)
            }
            .sorted { $0.date > $1.date }
    }

    func updateProfile(displayName: String, email: String) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedName.isEmpty, !normalizedEmail.isEmpty else {
            return
        }

        currentProfile = User(
            id: currentProfile.id,
            email: normalizedEmail,
            displayName: trimmedName,
            profileImageURL: currentProfile.profileImageURL,
            createdAt: currentProfile.createdAt,
            lastSignIn: Date()
        )

        persistLocalProfile()

        if remoteSyncEnabled {
            Task {
                await saveProfileToRemote()
                await syncFromRemote()
            }
        }
    }

    func addExpense(_ expense: Expense) {
        expenses.append(expense)
        persistState()
    }

    func applyReceiptDraft(_ draft: ReceiptDraft) {
        let expense = Expense(
            title: draft.merchant,
            amount: draft.amount,
            category: draft.category,
            date: draft.purchaseDate,
            notes: draft.notes
        )
        addExpense(expense)
    }

    func deleteExpense(id: UUID) {
        expenses.removeAll { $0.id == id }
        persistState()
    }

    func addRecurringExpense(_ expense: RecurringExpense) {
        recurringExpenses.append(expense)
        persistState()
    }

    func deleteRecurringExpense(id: UUID) {
        recurringExpenses.removeAll { $0.id == id }
        persistState()
    }

    func clearAllData() {
        expenses = []
        recurringExpenses = []
        persistState()
    }

    func exportJSON() -> String {
        let snapshot = FinanceExportSnapshot(
            exportedAt: Date(),
            expenses: expenses.sorted { $0.date > $1.date },
            recurringExpenses: recurringExpenses.sorted { $0.nextDueDate < $1.nextDueDate }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            logger.error("Failed to export finance data: \(error.localizedDescription)", category: "finance")
            return ""
        }
    }

    private func syncProfileFromRemote() async {
        do {
            if let remoteUser = try await databaseManager.fetchUser(currentProfile.id) {
                currentProfile = remoteUser
                persistLocalProfile()
            }
        } catch {
            logger.warning("Remote profile sync failed: \(error.localizedDescription)", category: "finance")
        }
    }

    private func saveProfileToRemote() async {
        do {
            try await databaseManager.saveUser(currentProfile)
        } catch {
            logger.warning("Failed to save profile to Firebase: \(error.localizedDescription)", category: "finance")
        }
    }

    private func syncFromRemote() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let state: FinancePersistenceState? = try await databaseManager.fetchData(
                from: remoteCollectionName,
                documentID: remoteDocumentID,
                as: FinancePersistenceState.self
            )

            guard let state else {
                return
            }

            expenses = state.expenses
            recurringExpenses = state.recurringExpenses
            persistLocalState()
        } catch {
            logger.warning("Remote finance sync failed: \(error.localizedDescription)", category: "finance")
        }
    }

    private func persistState() {
        persistLocalState()

        guard remoteSyncEnabled else {
            return
        }

        let state = FinancePersistenceState(expenses: expenses, recurringExpenses: recurringExpenses)
        let collection = remoteCollectionName
        let documentID = remoteDocumentID

        Task {
            do {
                try await databaseManager.saveData(state, to: collection, documentID: documentID)
            } catch {
                logger.error("Failed to persist finance state remotely: \(error.localizedDescription)", category: "finance")
                errorMessage = "Saved locally, but Firebase sync failed."
            }
        }
    }

    private func loadLocalState() {
        guard let data = userDefaults.data(forKey: Self.localStorageKey) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let state = try decoder.decode(FinancePersistenceState.self, from: data)
            expenses = state.expenses
            recurringExpenses = state.recurringExpenses
        } catch {
            logger.error("Failed to decode local finance state: \(error.localizedDescription)", category: "finance")
            errorMessage = "We could not load saved finance data."
            expenses = []
            recurringExpenses = []
        }
    }

    private func persistLocalState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let state = FinancePersistenceState(expenses: expenses, recurringExpenses: recurringExpenses)
            let data = try encoder.encode(state)
            userDefaults.set(data, forKey: Self.localStorageKey)
        } catch {
            logger.error("Failed to persist local finance state: \(error.localizedDescription)", category: "finance")
            errorMessage = "Unable to save your latest changes."
        }
    }

    private func persistLocalProfile() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(currentProfile)
            userDefaults.set(data, forKey: Self.profileStorageKey)
        } catch {
            logger.error("Failed to persist local profile: \(error.localizedDescription)", category: "finance")
        }
    }

    private static func loadOrCreateLocalProfile(userDefaults: UserDefaults) -> User {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = userDefaults.data(forKey: Self.profileStorageKey),
           let profile = try? decoder.decode(User.self, from: data) {
            return profile
        }

        let fallbackID: String
        if let existingID = userDefaults.string(forKey: Self.fallbackUserIDKey), !existingID.isEmpty {
            fallbackID = existingID
        } else {
            let generated = UUID().uuidString
            userDefaults.set(generated, forKey: Self.fallbackUserIDKey)
            fallbackID = generated
        }

        let profile = User(
            id: fallbackID,
            email: "local.user@financetracker.app",
            displayName: "Local User",
            profileImageURL: nil,
            createdAt: Date(),
            lastSignIn: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(profile) {
            userDefaults.set(data, forKey: Self.profileStorageKey)
        }

        return profile
    }

    private var remoteCollectionName: String {
        "finance_states"
    }

    private var remoteDocumentID: String {
        "user_\(currentProfile.id)"
    }
}

private struct FinancePersistenceState: Codable {
    let expenses: [Expense]
    let recurringExpenses: [RecurringExpense]
}
