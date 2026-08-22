import XCTest

#if canImport(App_Template)
@testable import App_Template
#elseif canImport(TemplateApp)
@testable import TemplateApp
#elseif canImport(FinanceTrackerAI)
@testable import FinanceTrackerAI
#endif

#if canImport(App_Template) || canImport(TemplateApp) || canImport(FinanceTrackerAI)
@MainActor
final class FinanceManagerTests: XCTestCase {
    private var suiteName: String = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "FinanceManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testAddExpenseUpdatesThisMonthAndWeekTotals() {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)

        let now = Date()
        manager.addExpense(Expense(title: "Groceries", amount: 50, category: .foodDining, date: now))
        manager.addExpense(Expense(title: "Taxi", amount: 20, category: .transportation, date: now))

        XCTAssertEqual(manager.thisWeekTotal, Decimal(70))
        XCTAssertEqual(manager.thisMonthTotal, Decimal(70))
        XCTAssertEqual(manager.expenses.count, 2)
    }

    func testRecurringMonthlyTotalNormalizesByFrequency() {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)

        manager.addRecurringExpense(
            RecurringExpense(
                title: "Streaming",
                amount: 30,
                category: .subscriptions,
                frequency: .monthly,
                nextDueDate: Date()
            )
        )

        manager.addRecurringExpense(
            RecurringExpense(
                title: "Gym",
                amount: 10,
                category: .health,
                frequency: .weekly,
                nextDueDate: Date()
            )
        )

        XCTAssertGreaterThan(manager.recurringMonthlyTotal, Decimal(73))
        XCTAssertLessThan(manager.recurringMonthlyTotal, Decimal(74))
        XCTAssertEqual(manager.activeRecurringCount, 2)
    }

    func testFilteredExpensesSupportsCategoryAndSearch() {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)

        manager.addExpense(Expense(title: "Grocery Store", amount: 40, category: .foodDining, date: Date(), notes: "Weekly food"))
        manager.addExpense(Expense(title: "Uber Ride", amount: 18, category: .transportation, date: Date(), notes: "Airport"))

        let byCategory = manager.filteredExpenses(searchText: "", category: .foodDining)
        XCTAssertEqual(byCategory.count, 1)
        XCTAssertEqual(byCategory.first?.title, "Grocery Store")

        let bySearch = manager.filteredExpenses(searchText: "airport", category: nil)
        XCTAssertEqual(bySearch.count, 1)
        XCTAssertEqual(bySearch.first?.title, "Uber Ride")
    }

    func testStatePersistsAcrossInstancesAndCanExport() throws {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)
        manager.setMonthlyBudget(Decimal(500))
        manager.addExpense(Expense(title: "Coffee", amount: 5, category: .foodDining, date: Date()))

        let secondManager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)
        XCTAssertEqual(secondManager.expenses.count, 1)
        XCTAssertEqual(secondManager.monthlyBudget, Decimal(500))

        let json = secondManager.exportJSON()
        XCTAssertFalse(json.isEmpty)

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(FinanceExportSnapshot.self, from: data)
        XCTAssertEqual(snapshot.expenses.count, 1)
        XCTAssertEqual(snapshot.monthlyBudget, Decimal(500))
        XCTAssertEqual(snapshot.profile.id, secondManager.currentProfile.id)
    }

    func testBatchUpdatesPersistTheFinalCombinedState() {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)

        manager.performBatchUpdates {
            manager.setMonthlyBudget(Decimal(900))
            manager.addExpense(Expense(title: "Rent", amount: 700, category: .housing, date: Date()))
            manager.addExpense(Expense(title: "Paycheck", amount: 2_400, category: .income, date: Date()))
        }

        let reloaded = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)
        XCTAssertEqual(reloaded.monthlyBudget, Decimal(900))
        XCTAssertEqual(reloaded.expenses.count, 2)
        XCTAssertEqual(reloaded.thisMonthTotal, Decimal(700))
    }

    func testBudgetStatusAndUsageCalculations() {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)
        manager.setMonthlyBudget(Decimal(100))
        manager.addExpense(Expense(title: "Groceries", amount: 25, category: .foodDining, date: Date()))

        XCTAssertEqual(manager.remainingBudgetThisMonth, Decimal(75))
        XCTAssertNotNil(manager.monthlyBudgetUsageRatio)
        XCTAssertEqual(manager.budgetStatusText.contains("left this month"), true)
    }

    func testIncomeDoesNotInflateSpendingOrBudgetUsage() {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)
        manager.setMonthlyBudget(Decimal(500))
        manager.addExpense(Expense(title: "Groceries", amount: 75, category: .foodDining, date: Date()))
        manager.addExpense(Expense(title: "Paycheck", amount: 2_000, category: .income, date: Date()))

        XCTAssertEqual(manager.thisMonthTotal, Decimal(75))
        XCTAssertEqual(manager.thisWeekTotal, Decimal(75))
        XCTAssertEqual(manager.remainingBudgetThisMonth, Decimal(425))
        XCTAssertEqual(manager.topCategoriesThisMonth(limit: 10).map(\.category), [.foodDining])
    }

    func testProcessDueRecurringExpensesCreatesExpensesAndAdvancesDate() {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)
        let threeWeeksAgo = Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date()
        manager.addRecurringExpense(
            RecurringExpense(
                title: "Gym Membership",
                amount: 12,
                category: .health,
                frequency: .weekly,
                nextDueDate: threeWeeksAgo
            )
        )

        let previousCount = manager.expenses.count
        manager.processDueRecurringExpenses(referenceDate: Date())

        XCTAssertGreaterThan(manager.expenses.count, previousCount)
        XCTAssertTrue(manager.recurringExpenses.first?.nextDueDate ?? .distantPast > Date())
    }

    func testUpdateAndDeleteExpenseUseExactRecordID() {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)
        let coffee = Expense(title: "Coffee", amount: 5, category: .foodDining, date: Date(), notes: "Morning")
        let taxi = Expense(title: "Taxi", amount: 18, category: .transportation, date: Date())
        manager.addExpense(coffee)
        manager.addExpense(taxi)

        XCTAssertTrue(manager.updateExpense(
            id: coffee.id,
            title: "Team Coffee",
            amount: 9,
            category: .business,
            clearNotes: true
        ))
        XCTAssertEqual(manager.expenses.first(where: { $0.id == coffee.id })?.title, "Team Coffee")
        XCTAssertEqual(manager.expenses.first(where: { $0.id == coffee.id })?.amount, Decimal(9))
        XCTAssertEqual(manager.expenses.first(where: { $0.id == coffee.id })?.category, .business)
        XCTAssertNil(manager.expenses.first(where: { $0.id == coffee.id })?.notes)
        XCTAssertEqual(manager.expenses.first(where: { $0.id == taxi.id })?.title, "Taxi")

        XCTAssertTrue(manager.deleteExpense(id: coffee.id))
        XCTAssertFalse(manager.deleteExpense(id: coffee.id))
        XCTAssertEqual(manager.expenses.map(\.id), [taxi.id])
    }

    func testUpdatePauseAndDeleteRecurringExpense() {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)
        let recurring = RecurringExpense(
            title: "Streaming",
            amount: 15,
            category: .subscriptions,
            frequency: .monthly,
            nextDueDate: Date()
        )
        manager.addRecurringExpense(recurring)

        XCTAssertTrue(manager.updateRecurringExpense(
            id: recurring.id,
            amount: 20,
            frequency: .yearly,
            isActive: false
        ))
        let updated = manager.recurringExpenses.first
        XCTAssertEqual(updated?.amount, Decimal(20))
        XCTAssertEqual(updated?.frequency, .yearly)
        XCTAssertEqual(updated?.isActive, false)
        XCTAssertEqual(manager.activeRecurringCount, 0)

        XCTAssertTrue(manager.deleteRecurringExpense(id: recurring.id))
        XCTAssertFalse(manager.deleteRecurringExpense(id: recurring.id))
    }

    func testFinanceToolCallTargetsExistingTransaction() throws {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)
        let expense = Expense(title: "Groceries", amount: 42, category: .foodDining, date: Date())
        manager.addExpense(expense)

        let payload = """
        {
          "id": "tool-update",
          "type": "update_transaction",
          "input": {
            "transactionId": "\(expense.id.uuidString)",
            "amount": 50,
            "category": "Shopping"
          }
        }
        """
        let toolCall = try JSONDecoder().decode(FinanceAIToolCall.self, from: Data(payload.utf8))
        let action = try XCTUnwrap(PendingAIAction(toolCall: toolCall, financeManager: manager))

        guard case let .updateTransaction(id, currentTitle, _, amount, category, _, _, _) = action.kind else {
            return XCTFail("Expected update transaction action")
        }
        XCTAssertEqual(id, expense.id)
        XCTAssertEqual(currentTitle, "Groceries")
        XCTAssertEqual(amount, Decimal(50))
        XCTAssertEqual(category, .shopping)
    }

    func testPaywallWaitsUntilFirstSuccessfulAIUse() {
        let userID = "paywall-user"
        let now = Date(timeIntervalSince1970: 1_750_000_000)

        XCTAssertNil(PaywallAccessPolicy.modeAtLaunch(userID: userID, defaults: defaults, now: now))
        XCTAssertEqual(
            PaywallAccessPolicy.modeAfterSuccessfulAIUse(userID: userID, defaults: defaults, now: now),
            .initial
        )
        XCTAssertNil(
            PaywallAccessPolicy.modeAfterSuccessfulAIUse(
                userID: userID,
                defaults: defaults,
                now: now.addingTimeInterval(60)
            )
        )
    }

    func testPaywallBecomesHardAfterSevenDaysFromFirstAIUse() {
        let userID = "expired-paywall-user"
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        _ = PaywallAccessPolicy.modeAfterSuccessfulAIUse(userID: userID, defaults: defaults, now: now)
        let sevenDaysLater = now.addingTimeInterval(TimeInterval(7 * 24 * 60 * 60))

        XCTAssertEqual(
            PaywallAccessPolicy.modeAtLaunch(userID: userID, defaults: defaults, now: sevenDaysLater),
            .yearlyHard
        )
    }

    func testAppleSignInNonceUsesFirebaseSHA256Format() {
        XCTAssertEqual(
            AppleSignInNonce.hash("test"),
            "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        )
    }

    func testAppleSignInNonceIsSecurelyGeneratedAtRequestedLength() throws {
        let nonce = try XCTUnwrap(AppleSignInNonce.generate(length: 48))
        let allowedCharacters = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        XCTAssertEqual(nonce.count, 48)
        XCTAssertNil(nonce.unicodeScalars.first(where: { !allowedCharacters.contains($0) }))
    }

    func testAIWelcomeAppearsOnceForNewAccountsOnly() {
        XCTAssertFalse(AIWelcomePolicy.shouldPresent(userID: "existing-user", defaults: defaults))
        XCTAssertFalse(AIWelcomePolicy.shouldPresent(userID: "new-user", defaults: defaults))

        AIWelcomePolicy.markEligibleForNewAccount(userID: "new-user", defaults: defaults)

        XCTAssertTrue(AIWelcomePolicy.shouldPresent(userID: "new-user", defaults: defaults))
        XCTAssertFalse(AIWelcomePolicy.shouldPresent(userID: "existing-user", defaults: defaults))

        AIWelcomePolicy.markPresented(userID: "new-user", defaults: defaults)

        XCTAssertFalse(AIWelcomePolicy.shouldPresent(userID: "new-user", defaults: defaults))
    }
}
#endif
