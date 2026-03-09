import XCTest

#if canImport(App_Template)
@testable import App_Template
#elseif canImport(TemplateApp)
@testable import TemplateApp
#endif

#if canImport(App_Template) || canImport(TemplateApp)
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

    func testBudgetStatusAndUsageCalculations() {
        let manager = FinanceManager(userDefaults: defaults, remoteSyncEnabled: false)
        manager.setMonthlyBudget(Decimal(100))
        manager.addExpense(Expense(title: "Groceries", amount: 25, category: .foodDining, date: Date()))

        XCTAssertEqual(manager.remainingBudgetThisMonth, Decimal(75))
        XCTAssertNotNil(manager.monthlyBudgetUsageRatio)
        XCTAssertEqual(manager.budgetStatusText.contains("left this month"), true)
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
}
#endif
