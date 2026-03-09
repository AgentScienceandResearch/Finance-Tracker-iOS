import SwiftUI

private enum FinanceTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case expenses = "Expenses"
    case recurring = "Recurring"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:
            return "chart.pie.fill"
        case .expenses:
            return "list.bullet"
        case .recurring:
            return "arrow.triangle.2.circlepath"
        case .settings:
            return "gearshape"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var financeManager: FinanceManager
    @EnvironmentObject private var financeAIManager: FinanceAIManager
    @Environment(\.analyticsTracker) private var analytics

    @State private var selectedTab: FinanceTab = .dashboard
    @State private var showAddExpense = false
    @State private var showAddRecurring = false
    @State private var showReceiptScanner = false
    @State private var showAIAssistant = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.93, green: 0.93, blue: 0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                activeTabView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer(minLength: 88)
            }

            FinanceBottomBar(selectedTab: $selectedTab)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(financeManager: financeManager)
        }
        .sheet(isPresented: $showAddRecurring) {
            AddRecurringExpenseSheet(financeManager: financeManager)
        }
        .sheet(isPresented: $showReceiptScanner) {
            ReceiptScannerSheet(financeManager: financeManager, aiManager: financeAIManager)
        }
        .sheet(isPresented: $showAIAssistant) {
            AIAssistantSheet(financeManager: financeManager, aiManager: financeAIManager)
        }
    }

    @ViewBuilder
    private var activeTabView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardTabView(
                financeManager: financeManager,
                openExpenses: {
                    selectedTab = .expenses
                },
                onAddExpense: {
                    analytics.track(event: AnalyticsEvent(name: "dashboard_add_expense_tapped"))
                    showAddExpense = true
                },
                onScanReceipt: {
                    analytics.track(event: AnalyticsEvent(name: "dashboard_scan_receipt_tapped"))
                    showReceiptScanner = true
                },
                onAskAI: {
                    analytics.track(event: AnalyticsEvent(name: "dashboard_ai_tapped"))
                    showAIAssistant = true
                }
            )
        case .expenses:
            ExpensesTabView(
                financeManager: financeManager,
                onAddExpense: { showAddExpense = true },
                onSmartAdd: { showReceiptScanner = true }
            )
        case .recurring:
            RecurringTabView(
                financeManager: financeManager,
                onAddRecurring: { showAddRecurring = true }
            )
        case .settings:
            FinanceSettingsTabView(
                financeManager: financeManager,
                onAskAI: { showAIAssistant = true }
            )
        }
    }
}

private struct DashboardTabView: View {
    @ObservedObject var financeManager: FinanceManager

    let openExpenses: () -> Void
    let onAddExpense: () -> Void
    let onScanReceipt: () -> Void
    let onAskAI: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Finance Tracker")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.top, 6)

                SummaryCard(
                    title: "This Month",
                    value: CurrencyFormatting.shared.string(for: financeManager.thisMonthTotal),
                    subtitle: nil
                )

                HStack(spacing: 12) {
                    SummaryCard(
                        title: "This Week",
                        value: CurrencyFormatting.shared.string(for: financeManager.thisWeekTotal),
                        subtitle: nil,
                        compact: true
                    )

                    SummaryCard(
                        title: "Recurring",
                        value: CurrencyFormatting.shared.string(for: financeManager.recurringMonthlyTotal),
                        subtitle: nil,
                        compact: true
                    )
                }

                Text("Quick Actions")
                    .font(.system(size: 38, weight: .bold))
                    .padding(.top, 4)

                HStack(spacing: 12) {
                    QuickActionButton(
                        icon: "plus.circle.fill",
                        title: "Add Expense",
                        action: onAddExpense
                    )

                    QuickActionButton(
                        icon: "doc.text.viewfinder",
                        title: "Scan Receipt",
                        action: onScanReceipt
                    )
                }

                Button(action: onAskAI) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Ask GPT For Insights")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack {
                    Text("Recent Expenses")
                        .font(.system(size: 38, weight: .bold))
                    Spacer()
                    Button("See All") {
                        openExpenses()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.5))
                }

                if financeManager.expenses.isEmpty {
                    EmptyStateCard(
                        icon: "receipt",
                        title: "No Expenses Yet",
                        message: "Add your first expense to start tracking"
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(financeManager.recentExpenses()) { expense in
                            ExpenseRow(expense: expense)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
    }
}

private struct ExpensesTabView: View {
    @ObservedObject var financeManager: FinanceManager

    let onAddExpense: () -> Void
    let onSmartAdd: () -> Void

    @State private var searchText = ""
    @State private var selectedCategory: ExpenseCategory?

    var filteredExpenses: [Expense] {
        financeManager.filteredExpenses(searchText: searchText, category: selectedCategory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Expenses")
                    .font(.system(size: 52, weight: .bold))
                Spacer()
                HStack(spacing: 10) {
                    CircleIconButton(icon: "plus") {
                        onAddExpense()
                    }

                    CircleIconButton(icon: "sparkles") {
                        onSmartAdd()
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.6))
                .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                TextField("Search expenses", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(
                        title: "All",
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )

                    ForEach(ExpenseCategory.allCases) { category in
                        CategoryChip(
                            title: category.rawValue,
                            isSelected: selectedCategory == category,
                            action: { selectedCategory = category }
                        )
                    }
                }
                .padding(.horizontal, 1)
            }

            if filteredExpenses.isEmpty {
                VStack(spacing: 16) {
                    EmptyStateCard(
                        icon: "receipt",
                        title: "No Expenses Yet",
                        message: "Tap the + button to add your first expense"
                    )

                    Button("Add Expense") {
                        onAddExpense()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredExpenses) { expense in
                            ExpenseRow(expense: expense)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        financeManager.deleteExpense(id: expense.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }
}

private struct RecurringTabView: View {
    @ObservedObject var financeManager: FinanceManager

    let onAddRecurring: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Recurring")
                        .font(.system(size: 52, weight: .bold))
                    Spacer()
                    CircleIconButton(icon: "plus") {
                        onAddRecurring()
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.6))
                    .clipShape(Circle())
                }

                SummaryCard(
                    title: "Monthly Recurring Total",
                    value: CurrencyFormatting.shared.string(for: financeManager.recurringMonthlyTotal),
                    subtitle: "\(financeManager.activeRecurringCount) active subscriptions"
                )

                Text("Upcoming")
                    .font(.system(size: 38, weight: .bold))

                if financeManager.upcomingRecurringExpenses.isEmpty {
                    EmptyStateCard(
                        icon: "calendar",
                        title: "No Upcoming Expenses",
                        message: "Add recurring expenses to see upcoming payments"
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(financeManager.upcomingRecurringExpenses) { recurringExpense in
                            RecurringExpenseRow(expense: recurringExpense)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        financeManager.deleteRecurringExpense(id: recurringExpense.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
    }
}

private struct FinanceSettingsTabView: View {
    @ObservedObject var financeManager: FinanceManager
    let onAskAI: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var showEditProfile = false

    var exportPayload: String {
        financeManager.exportJSON()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.system(size: 52, weight: .bold))
                    .padding(.top, 10)

                SettingsSectionCard {
                    SettingsRow(icon: "chart.pie.fill", title: "Budgets", trailingText: "Soon")
                    Divider()
                    SettingsRow(icon: "tag.fill", title: "Categories", trailingText: "\(ExpenseCategory.allCases.count)")
                }

                Text("Data")
                    .font(.system(size: 24, weight: .bold))

                SettingsSectionCard {
                    ShareLink(item: exportPayload, subject: Text("Finance Tracker Export"), message: Text("Finance Tracker JSON export")) {
                        SettingsRow(icon: "square.and.arrow.up", title: "Export Data", trailingText: nil)
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        SettingsRow(icon: "trash", title: "Clear All Data", trailingText: nil, isDestructive: true)
                    }
                }

                Text("AI")
                    .font(.system(size: 24, weight: .bold))

                SettingsSectionCard {
                    Button {
                        onAskAI()
                    } label: {
                        SettingsRow(icon: "sparkles", title: "Open AI Assistant", trailingText: nil)
                    }
                    Divider()
                    SettingsRow(
                        icon: "network",
                        title: "AI Server Endpoint",
                        trailingText: AppConfig.shared.apiURL.absoluteString,
                        isDestructive: false
                    )
                }

                Text("Profile")
                    .font(.system(size: 24, weight: .bold))

                SettingsSectionCard {
                    SettingsRow(icon: "person.fill", title: financeManager.currentProfile.displayName, trailingText: financeManager.currentProfile.email)
                    Divider()
                    Button("Edit Profile") {
                        showEditProfile = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                    .foregroundStyle(.black)
                }

                Text("About")
                    .font(.system(size: 24, weight: .bold))

                SettingsSectionCard {
                    SettingsRow(icon: "info.circle.fill", title: "Version", trailingText: "1.0.0")
                    Divider()
                    SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", trailingText: "Soon")
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
        .confirmationDialog("Clear all tracked data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Clear All Data", role: .destructive) {
                financeManager.clearAllData()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(financeManager: financeManager)
        }
    }
}

private struct FinanceBottomBar: View {
    @Binding var selectedTab: FinanceTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FinanceTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.black)
                    .background(
                        selectedTab == tab
                        ? Color.black.opacity(0.12)
                        : Color.clear
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.95))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String?
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            Text(title)
                .font(.system(size: compact ? 14 : 16, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.82))

            Text(value)
                .font(.system(size: compact ? 22 : 46, weight: .heavy))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 18 : 28)
        .padding(.horizontal, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 98)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 50, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.7))

            Text(title)
                .font(.system(size: 22, weight: .bold))

            Text(message)
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.black.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: expense.category))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.system(size: 16, weight: .semibold))
                Text(expense.category.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.65))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatting.shared.string(for: expense.amount))
                    .font(.system(size: 16, weight: .bold))
                Text(expense.date.formattedDate)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func icon(for category: ExpenseCategory) -> String {
        switch category {
        case .foodDining: return "fork.knife"
        case .transportation: return "car.fill"
        case .housing: return "house.fill"
        case .utilities: return "bolt.fill"
        case .entertainment: return "tv.fill"
        case .shopping: return "bag.fill"
        case .health: return "cross.case.fill"
        case .travel: return "airplane"
        case .education: return "book.fill"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .incomeOffset: return "arrow.down.circle.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

private struct RecurringExpenseRow: View {
    let expense: RecurringExpense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.system(size: 16, weight: .semibold))
                Text("\(expense.frequency.rawValue) • \(expense.nextDueDate.formattedDate)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.65))
            }

            Spacer()

            Text(CurrencyFormatting.shared.string(for: expense.amount))
                .font(.system(size: 16, weight: .bold))
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SettingsSectionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let trailingText: String?
    var isDestructive = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28)
            Text(title)
                .font(.system(size: 16, weight: .medium))
            Spacer()
            if let trailingText {
                Text(trailingText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.45))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.45))
            }
        }
        .foregroundStyle(isDestructive ? .red : .black)
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
    }
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .black)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(isSelected ? Color.black : Color.white.opacity(0.75))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct CircleIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.black)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct AddExpenseSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amount = ""
    @State private var category: ExpenseCategory = .foodDining
    @State private var date = Date()
    @State private var notes = ""
    @State private var inlineError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let inlineError {
                    Section {
                        Text(inlineError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveExpense()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func saveExpense() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            inlineError = "Please enter a title."
            return
        }

        guard let decimalAmount = DecimalParser.parse(amount), decimalAmount > 0 else {
            inlineError = "Please enter a valid amount."
            return
        }

        financeManager.addExpense(
            Expense(
                title: trimmedTitle,
                amount: decimalAmount,
                category: category,
                date: date,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            )
        )

        dismiss()
    }
}

private struct AddRecurringExpenseSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amount = ""
    @State private var category: ExpenseCategory = .subscriptions
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var nextDueDate = Date()
    @State private var notes = ""
    @State private var inlineError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Recurring Expense") {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(RecurrenceFrequency.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    DatePicker("Next Due Date", selection: $nextDueDate, displayedComponents: .date)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let inlineError {
                    Section {
                        Text(inlineError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Recurring")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveRecurringExpense()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func saveRecurringExpense() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            inlineError = "Please enter a title."
            return
        }

        guard let decimalAmount = DecimalParser.parse(amount), decimalAmount > 0 else {
            inlineError = "Please enter a valid amount."
            return
        }

        financeManager.addRecurringExpense(
            RecurringExpense(
                title: trimmedTitle,
                amount: decimalAmount,
                category: category,
                frequency: frequency,
                nextDueDate: nextDueDate,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
            )
        )

        dismiss()
    }
}

private struct ReceiptScannerSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @ObservedObject var aiManager: FinanceAIManager
    @Environment(\.dismiss) private var dismiss

    @State private var receiptText = ""
    @State private var draft: ReceiptDraft?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Paste receipt text and AI will create an expense draft.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $receiptText)
                    .frame(minHeight: 180)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.18), lineWidth: 1)
                    )

                if let draft {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Detected")
                            .font(.system(size: 15, weight: .bold))
                        Text("Merchant: \(draft.merchant)")
                        Text("Amount: \(CurrencyFormatting.shared.string(for: draft.amount))")
                        Text("Category: \(draft.category.rawValue)")
                        Text("Date: \(draft.purchaseDate.formattedDate)")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let error = aiManager.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Button("Parse") {
                        Task {
                            draft = await aiManager.parseReceipt(rawText: receiptText)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(aiManager.isLoading)

                    Button("Save Draft") {
                        if let draft {
                            financeManager.applyReceiptDraft(draft)
                            dismiss()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(draft == nil)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("Scan Receipt")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct AIAssistantSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @ObservedObject var aiManager: FinanceAIManager
    @Environment(\.dismiss) private var dismiss

    @State private var prompt = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(aiManager.messages) { message in
                            AIMessageBubble(message: message)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }

                if let error = aiManager.errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                }

                HStack(spacing: 8) {
                    TextField("Ask about spending, budget, or savings...", text: $prompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        let currentPrompt = prompt
                        prompt = ""
                        Task {
                            await aiManager.sendMessage(currentPrompt, financeManager: financeManager)
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiManager.isLoading)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .navigationTitle("GPT Assistant")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        aiManager.resetConversation()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct AIMessageBubble: View {
    let message: AIChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                Text(message.content)
                    .padding(10)
                    .background(Color.black.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer(minLength: 20)
            } else {
                Spacer(minLength: 20)
                Text(message.content)
                    .padding(10)
                    .foregroundStyle(.white)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .font(.system(size: 14, weight: .medium))
    }
}

private struct EditProfileSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var email: String
    @State private var errorMessage: String?

    init(financeManager: FinanceManager) {
        self.financeManager = financeManager
        _displayName = State(initialValue: financeManager.currentProfile.displayName)
        _email = State(initialValue: financeManager.currentProfile.email)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display Name", text: $displayName)
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func saveProfile() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Display name is required."
            return
        }

        guard trimmedEmail.isValidEmail else {
            errorMessage = "Please enter a valid email."
            return
        }

        financeManager.updateProfile(displayName: trimmedName, email: trimmedEmail)
        dismiss()
    }
}

private enum DecimalParser {
    static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "$", with: "")

        return Decimal(string: cleaned)
    }
}

#if DEBUG
#Preview {
    MainTabView()
        .environmentObject(FinanceManager.shared)
        .environmentObject(FinanceAIManager(service: OpenAIService.shared))
}
#endif
