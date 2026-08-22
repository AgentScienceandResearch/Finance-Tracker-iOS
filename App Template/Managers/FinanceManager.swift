import Foundation

@MainActor
final class FinanceManager: ObservableObject {
    static let shared = FinanceManager()

    @Published private(set) var currentProfile: User
    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var recurringExpenses: [RecurringExpense] = []
    @Published private(set) var monthlyBudget: Decimal?
    @Published private(set) var lastSuccessfulSyncAt: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Keys are user-scoped to prevent data leaking between accounts.
    private static let fallbackUserIDKey = "financeFallbackUserID"

    private var localStorageKey: String { "financeTrackerState.v1.\(currentUserID)" }
    private var profileStorageKey: String { "financeUserProfile.v1.\(currentUserID)" }

    // Set by AppEnvironment when Firebase auth resolves.
    private(set) var currentUserID: String = "anonymous"

    private let databaseManager: DatabaseManager
    private let userDefaults: UserDefaults
    private let logger: Logging
    private let calendar: Calendar
    private let remoteSyncEnabled: Bool
    private var isPerformingBatchUpdate = false

    init(
        databaseManager: DatabaseManager? = nil,
        userDefaults: UserDefaults = .standard,
        logger: Logging = AppLogger.shared,
        calendar: Calendar = .current,
        remoteSyncEnabled: Bool = true
    ) {
        self.databaseManager = databaseManager ?? .shared
        self.userDefaults = userDefaults
        self.logger = logger
        self.calendar = calendar
        self.remoteSyncEnabled = remoteSyncEnabled

        self.currentProfile = Self.loadOrCreateLocalProfile(userDefaults: userDefaults)
        loadLocalState()
        processDueRecurringExpenses()

        guard remoteSyncEnabled else {
            return
        }

        Task {
            await syncProfileFromRemote()
            await saveProfileToRemote()
            await syncFromRemote()
            processDueRecurringExpenses()
        }
    }

    var thisMonthTotal: Decimal {
        let now = Date()
        return expenses
            .filter { !$0.category.isIncome && calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var thisWeekTotal: Decimal {
        let now = Date()
        return expenses
            .filter { !$0.category.isIncome && calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var recurringMonthlyTotal: Decimal {
        recurringExpenses
            .filter { $0.isActive && !$0.category.isIncome }
            .reduce(Decimal.zero) { $0 + $1.normalizedMonthlyCost }
    }

    var activeRecurringCount: Int {
        recurringExpenses.filter(\.isActive).count
    }

    var remainingBudgetThisMonth: Decimal? {
        guard let monthlyBudget else {
            return nil
        }

        return monthlyBudget - thisMonthTotal
    }

    var monthlyBudgetUsageRatio: Double? {
        guard let monthlyBudget, monthlyBudget > 0 else {
            return nil
        }

        let monthTotal = NSDecimalNumber(decimal: thisMonthTotal).doubleValue
        let budget = NSDecimalNumber(decimal: monthlyBudget).doubleValue
        guard budget > 0 else { return nil }

        return monthTotal / budget
    }

    var budgetStatusText: String {
        guard let remainingBudgetThisMonth else {
            return "No monthly budget set"
        }

        let formatter = CurrencyFormatting.shared
        if remainingBudgetThisMonth >= 0 {
            return "\(formatter.string(for: remainingBudgetThisMonth)) left this month"
        }

        return "Over budget by \(formatter.string(for: abs(remainingBudgetThisMonth)))"
    }

    var syncStatusText: String {
        if let lastSuccessfulSyncAt {
            return "Last synced \(lastSuccessfulSyncAt.timeAgo)"
        }
        return remoteSyncEnabled ? "Sync pending" : "Cloud sync disabled"
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

    func topCategoriesThisMonth(limit: Int = 3) -> [(category: ExpenseCategory, total: Decimal)] {
        let now = Date()

        let grouped = Dictionary(grouping: expenses.filter {
            !$0.category.isIncome && calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }, by: \.category)

        return grouped
            .map { category, values in
                (category: category, total: values.reduce(Decimal.zero) { $0 + $1.amount })
            }
            .sorted { $0.total > $1.total }
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

        guard remoteSyncEnabled else {
            return
        }

        Task {
            await saveProfileToRemote()
            await syncFromRemote()
        }
    }

    func setMonthlyBudget(_ budget: Decimal?) {
        if let budget, budget <= 0 {
            monthlyBudget = nil
        } else {
            monthlyBudget = budget
        }

        persistState()
    }

    func addExpense(_ expense: Expense) {
        expenses.append(expense)
        persistState()
    }

    /// Coalesces a group of related mutations into one local and remote state
    /// write. This prevents an approved multi-action AI batch from racing
    /// several cloud snapshots against each other.
    func performBatchUpdates(_ updates: () -> Void) {
        guard !isPerformingBatchUpdate else {
            updates()
            return
        }

        isPerformingBatchUpdate = true
        defer {
            isPerformingBatchUpdate = false
            persistState()
        }
        updates()
    }

    @discardableResult
    func updateExpense(
        id: UUID,
        title: String? = nil,
        amount: Decimal? = nil,
        category: ExpenseCategory? = nil,
        date: Date? = nil,
        notes: String? = nil,
        clearNotes: Bool = false
    ) -> Bool {
        guard let index = expenses.firstIndex(where: { $0.id == id }) else { return false }

        if let title {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else { return false }
            expenses[index].title = trimmedTitle
        }
        if let amount {
            guard amount > 0 else { return false }
            expenses[index].amount = amount
        }
        if let category { expenses[index].category = category }
        if let date { expenses[index].date = date }
        if clearNotes {
            expenses[index].notes = nil
        } else if let notes {
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            expenses[index].notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        }

        persistState()
        return true
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

    @discardableResult
    func deleteExpense(id: UUID) -> Bool {
        let previousCount = expenses.count
        expenses.removeAll { $0.id == id }
        guard expenses.count != previousCount else { return false }
        persistState()
        return true
    }

    func addRecurringExpense(_ expense: RecurringExpense) {
        recurringExpenses.append(expense)
        persistState()
    }

    @discardableResult
    func updateRecurringExpense(
        id: UUID,
        title: String? = nil,
        amount: Decimal? = nil,
        category: ExpenseCategory? = nil,
        frequency: RecurrenceFrequency? = nil,
        nextDueDate: Date? = nil,
        isActive: Bool? = nil,
        notes: String? = nil,
        clearNotes: Bool = false
    ) -> Bool {
        guard let index = recurringExpenses.firstIndex(where: { $0.id == id }) else { return false }

        if let title {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else { return false }
            recurringExpenses[index].title = trimmedTitle
        }
        if let amount {
            guard amount > 0 else { return false }
            recurringExpenses[index].amount = amount
        }
        if let category { recurringExpenses[index].category = category }
        if let frequency { recurringExpenses[index].frequency = frequency }
        if let nextDueDate { recurringExpenses[index].nextDueDate = nextDueDate }
        if let isActive { recurringExpenses[index].isActive = isActive }
        if clearNotes {
            recurringExpenses[index].notes = nil
        } else if let notes {
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            recurringExpenses[index].notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        }

        persistState()
        return true
    }

    @discardableResult
    func deleteRecurringExpense(id: UUID) -> Bool {
        let previousCount = recurringExpenses.count
        recurringExpenses.removeAll { $0.id == id }
        guard recurringExpenses.count != previousCount else { return false }
        persistState()
        return true
    }

    @discardableResult
    func processDueRecurringExpenses(referenceDate: Date = Date()) -> Int {
        var updated = recurringExpenses
        var generatedExpenses: [Expense] = []

        // Don't back-fill more than 90 days to prevent runaway expense generation
        // if a recurring item's nextDueDate is far in the past.
        let earliestBackfill = calendar.date(byAdding: .day, value: -90, to: referenceDate) ?? referenceDate

        for index in updated.indices where updated[index].isActive {
            var recurring = updated[index]
            var nextDue = max(recurring.nextDueDate, earliestBackfill)

            while nextDue <= referenceDate {
                let generated = Expense(
                    title: recurring.title,
                    amount: recurring.amount,
                    category: recurring.category,
                    date: nextDue,
                    notes: recurring.notes == nil ? "Auto-added from recurring expense" : "\(recurring.notes!) (auto-added)"
                )
                generatedExpenses.append(generated)

                let advanced = nextDate(after: nextDue, frequency: recurring.frequency)
                guard advanced > nextDue else { break }
                nextDue = advanced
            }

            recurring.nextDueDate = nextDue
            updated[index] = recurring
        }

        guard !generatedExpenses.isEmpty || updated != recurringExpenses else {
            return 0
        }

        recurringExpenses = updated
        expenses.append(contentsOf: generatedExpenses)
        persistState()
        return generatedExpenses.count
    }

    func clearAllData() {
        expenses = []
        recurringExpenses = []
        monthlyBudget = nil
        persistState()
    }

    /// Called when a user signs in. Switches all local and remote data to that user's scope.
    func switchUser(to user: User) {
        guard currentUserID != user.id else { return }
        wipeMemory()
        currentUserID = user.id
        currentProfile = user
        loadLocalState()
        guard remoteSyncEnabled else { return }
        Task {
            await syncProfileFromRemote()
            await saveProfileToRemote()
            await syncFromRemote()
            processDueRecurringExpenses()
        }
    }

    /// Called on sign-out. Clears all in-memory data so the next user starts clean.
    func handleSignOut() {
        wipeMemory()
        currentUserID = "anonymous"
    }

    private func wipeMemory() {
        expenses = []
        recurringExpenses = []
        monthlyBudget = nil
        lastSuccessfulSyncAt = nil
        errorMessage = nil
    }

    func exportJSON() -> String {
        let snapshot = FinanceExportSnapshot(
            exportedAt: Date(),
            profile: currentProfile,
            monthlyBudget: monthlyBudget,
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
            monthlyBudget = state.monthlyBudget
            lastSuccessfulSyncAt = Date()
            persistLocalState()
        } catch {
            logger.warning("Remote finance sync failed: \(error.localizedDescription)", category: "finance")
        }
    }

    private func persistState() {
        guard !isPerformingBatchUpdate else { return }
        persistLocalState()

        guard remoteSyncEnabled else {
            return
        }

        let state = FinancePersistenceState(
            expenses: expenses,
            recurringExpenses: recurringExpenses,
            monthlyBudget: monthlyBudget,
            updatedAt: Date()
        )

        let collection = remoteCollectionName
        let documentID = remoteDocumentID

        Task {
            do {
                try await databaseManager.saveData(state, to: collection, documentID: documentID)
                lastSuccessfulSyncAt = Date()
            } catch {
                logger.error("Failed to persist finance state remotely: \(error.localizedDescription)", category: "finance")
                errorMessage = "Saved locally, but Firebase sync failed."
            }
        }
    }

    private func loadLocalState() {
        guard let data = userDefaults.data(forKey: localStorageKey) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let state = try decoder.decode(FinancePersistenceState.self, from: data)
            expenses = state.expenses
            recurringExpenses = state.recurringExpenses
            monthlyBudget = state.monthlyBudget
            lastSuccessfulSyncAt = state.updatedAt
        } catch {
            logger.error("Failed to decode local finance state: \(error.localizedDescription)", category: "finance")
            errorMessage = "We could not load saved finance data."
            expenses = []
            recurringExpenses = []
            monthlyBudget = nil
        }
    }

    private func persistLocalState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let state = FinancePersistenceState(
                expenses: expenses,
                recurringExpenses: recurringExpenses,
                monthlyBudget: monthlyBudget,
                updatedAt: lastSuccessfulSyncAt
            )
            let data = try encoder.encode(state)
            userDefaults.set(data, forKey: localStorageKey)
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
            userDefaults.set(data, forKey: profileStorageKey)
        } catch {
            logger.error("Failed to persist local profile: \(error.localizedDescription)", category: "finance")
        }
    }

    private func nextDate(after date: Date, frequency: RecurrenceFrequency) -> Date {
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }

    private static func loadOrCreateLocalProfile(userDefaults: UserDefaults) -> User {
        // This runs at init before any Firebase user is known (currentUserID = "anonymous").
        // switchUser(to:) will replace this profile as soon as auth resolves.
        let fallbackID: String
        if let existingID = userDefaults.string(forKey: Self.fallbackUserIDKey), !existingID.isEmpty {
            fallbackID = existingID
        } else {
            let generated = UUID().uuidString
            userDefaults.set(generated, forKey: Self.fallbackUserIDKey)
            fallbackID = generated
        }

        return User(
            id: fallbackID,
            email: "local.user@financetracker.app",
            displayName: "Local User",
            profileImageURL: nil,
            createdAt: Date(),
            lastSignIn: Date()
        )
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
    let monthlyBudget: Decimal?
    let updatedAt: Date?

    init(
        expenses: [Expense],
        recurringExpenses: [RecurringExpense],
        monthlyBudget: Decimal?,
        updatedAt: Date?
    ) {
        self.expenses = expenses
        self.recurringExpenses = recurringExpenses
        self.monthlyBudget = monthlyBudget
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case expenses
        case recurringExpenses
        case monthlyBudget
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.expenses = try container.decodeIfPresent([Expense].self, forKey: .expenses) ?? []
        self.recurringExpenses = try container.decodeIfPresent([RecurringExpense].self, forKey: .recurringExpenses) ?? []
        self.monthlyBudget = try container.decodeIfPresent(Decimal.self, forKey: .monthlyBudget)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}
