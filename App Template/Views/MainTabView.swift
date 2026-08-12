import SwiftUI
import VisionKit
import UIKit
import StoreKit

// MARK: - Design Tokens

private enum FT {
    // Accent
    static let green      = Color(red: 0.18, green: 0.72, blue: 0.34)
    static let greenMid   = Color(red: 0.18, green: 0.72, blue: 0.34).opacity(0.16)
    static let greenSub   = Color(red: 0.18, green: 0.72, blue: 0.34).opacity(0.08)

    // Surfaces
    static let bg         = Color(red: 0.961, green: 0.961, blue: 0.973)
    static let card       = Color.white

    // Text
    static let t1         = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let t2         = Color(red: 0.50, green: 0.50, blue: 0.56)
    static let t3         = Color(red: 0.72, green: 0.72, blue: 0.76)

    // Shape
    static let cardR: CGFloat  = 28
    static let innerR: CGFloat = 18
    static let chipR: CGFloat  = 12
}

private struct FTCard: ViewModifier {
    var padding: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(FT.card)
            .clipShape(RoundedRectangle(cornerRadius: FT.cardR, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 4)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
}

private extension View {
    func ftCard(padding: CGFloat = 20) -> some View { modifier(FTCard(padding: padding)) }
}

// MARK: - Tab Model

private enum FinanceTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case expenses  = "Expenses"
    case recurring = "Recurring"
    case insights  = "Insights"
    case settings  = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .expenses:  return "list.bullet.rectangle.portrait"
        case .recurring: return "arrow.triangle.2.circlepath"
        case .insights:  return "chart.bar.xaxis"
        case .settings:  return "gearshape.fill"
        }
    }
}

// MARK: - Root View

struct MainTabView: View {
    @EnvironmentObject private var financeManager: FinanceManager
    @EnvironmentObject private var financeAIManager: FinanceAIManager
    @Environment(\.analyticsTracker) private var analytics
    @Environment(\.requestReview) private var requestReview

    @State private var selectedTab: FinanceTab = .dashboard
    @State private var showAddExpense    = false
    @State private var showAddIncome     = false
    @State private var showAddRecurring  = false
    @State private var showReceiptScanner = false
    @State private var showImport        = false
    @State private var showAIAssistant   = false

    var body: some View {
        ZStack(alignment: .bottom) {
            FT.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                activeTabView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer(minLength: 96)
            }

            PremiumTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet(financeManager: financeManager)
        }
        .sheet(isPresented: $showAddIncome) {
            AddExpenseSheet(financeManager: financeManager, initialCategory: .income)
        }
        .sheet(isPresented: $showAddRecurring) {
            AddRecurringExpenseSheet(financeManager: financeManager)
        }
        .sheet(isPresented: $showReceiptScanner) {
            ReceiptScannerSheet(financeManager: financeManager, aiManager: financeAIManager)
        }
        .sheet(isPresented: $showImport) {
            ImportExpenseSheet(financeManager: financeManager, aiManager: financeAIManager)
        }
        .sheet(isPresented: $showAIAssistant) {
            AIAssistantSheet(financeManager: financeManager, aiManager: financeAIManager)
        }
        .onAppear {
            financeManager.processDueRecurringExpenses()
            BillReminderManager.shared.reschedule(with: financeManager.upcomingRecurringExpenses)
            requestReviewIfAppropriate(expenseCount: financeManager.expenses.count)
        }
        .onChange(of: financeManager.expenses.count) { _, newCount in
            requestReviewIfAppropriate(expenseCount: newCount)
        }
    }

    // Apple-compliant: native requestReview only, fired once at a natural pause
    // after the user has logged a few expenses (a clear "got value" moment).
    private func requestReviewIfAppropriate(expenseCount: Int) {
        // UserDefaults directly rather than @AppStorage — this app defines its
        // own `AppStorage` type that shadows SwiftUI's property wrapper here.
        let reviewedKey = "review.requested"
        guard !UserDefaults.standard.bool(forKey: reviewedKey), expenseCount >= 5 else { return }
        UserDefaults.standard.set(true, forKey: reviewedKey)
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { requestReview() }
        }
    }

    @ViewBuilder
    private var activeTabView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardTabView(
                financeManager: financeManager,
                onViewAll:       { selectedTab = .expenses },
                onViewInsights:  { selectedTab = .insights },
                onAddExpense:    { analytics.track(event: AnalyticsEvent(name: "dash_add_expense")); showAddExpense = true },
                onScanReceipt:   { analytics.track(event: AnalyticsEvent(name: "dash_scan")); showReceiptScanner = true },
                onAddIncome:     { showAddIncome = true },
                onImport:        { analytics.track(event: AnalyticsEvent(name: "dash_import")); showImport = true },
                onAskAI:         { showAIAssistant = true }
            )
        case .expenses:
            ExpensesTabView(
                financeManager: financeManager,
                onAddExpense:  { showAddExpense = true },
                onScanReceipt: { showReceiptScanner = true },
                onAskAI:       { showAIAssistant = true }
            )
        case .recurring:
            RecurringTabView(
                financeManager: financeManager,
                onAddRecurring: { showAddRecurring = true }
            )
        case .insights:
            InsightsTabView(
                financeManager: financeManager,
                onAskAI: { showAIAssistant = true }
            )
        case .settings:
            FinanceSettingsTabView(
                financeManager: financeManager
            )
        }
    }
}

// MARK: - Premium Tab Bar

private struct PremiumTabBar: View {
    @Binding var selectedTab: FinanceTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FinanceTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                            .symbolEffect(.bounce, value: selectedTab == tab)
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selectedTab == tab ? FT.green : FT.t3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(FT.greenSub)
                                    .padding(.horizontal, 4)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 6)
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Dashboard

private struct DashboardTabView: View {
    @ObservedObject var financeManager: FinanceManager
    let onViewAll:      () -> Void
    let onViewInsights: () -> Void
    let onAddExpense:   () -> Void
    let onScanReceipt:  () -> Void
    let onAddIncome:    () -> Void
    let onImport:       () -> Void
    let onAskAI:        () -> Void

    private var firstName: String {
        financeManager.currentProfile.displayName
            .components(separatedBy: .whitespaces).first ?? "there"
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                GreetingHeader(
                    greeting: greeting, name: firstName,
                    onNotification: {},
                    onAI: onAskAI
                )

                HeroBalanceCard(financeManager: financeManager)

                AnalyticsRow(financeManager: financeManager)

                RecurringBillsCard(financeManager: financeManager)

                QuickActionsGrid(
                    onAddExpense:  onAddExpense,
                    onScanReceipt: onScanReceipt,
                    onAddIncome:   onAddIncome,
                    onImport:      onImport
                )

                SpendingAnalysisCard(onTap: onViewInsights, financeManager: financeManager)

                RecentTransactionsSection(
                    financeManager: financeManager,
                    onViewAll: onViewAll
                )

                AIInsightCard(financeManager: financeManager, onTap: onAskAI)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Greeting Header

private struct GreetingHeader: View {
    let greeting: String
    let name: String
    let onNotification: () -> Void
    let onAI: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(greeting), \(name) 👋")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FT.t2)
                Text("My Finance")
                    .font(.system(size: 42, weight: .heavy, design: .default))
                    .foregroundStyle(FT.t1)
                    .tracking(-0.5)
            }

            Spacer()

            HStack(spacing: 10) {
                IconPill(systemName: "bell.fill", badge: true, action: onNotification)
                IconPill(systemName: "sparkles", badge: false, action: onAI)
            }
        }
    }
}

private struct IconPill: View {
    let systemName: String
    let badge: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FT.t1)
                    .frame(width: 40, height: 40)
                    .background(FT.card)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)

                if badge {
                    Circle()
                        .fill(FT.green)
                        .frame(width: 8, height: 8)
                        .offset(x: 1, y: -1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hero Balance Card

private struct HeroBalanceCard: View {
    @ObservedObject var financeManager: FinanceManager

    private var spentDouble: Double {
        NSDecimalNumber(decimal: financeManager.thisMonthTotal).doubleValue
    }

    private var trendPct: Double {
        let cal = Calendar.current
        let now = Date()
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let lastMonthStart = cal.date(byAdding: .month, value: -1, to: monthStart) else { return 0 }

        let last = financeManager.expenses
            .filter { $0.date >= lastMonthStart && $0.date < monthStart && !$0.category.isIncome }
            .reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.amount).doubleValue }

        guard last > 0 else { return spentDouble > 0 ? 100 : 0 }
        return ((spentDouble - last) / last) * 100
    }

    // Daily cumulative spending for current month
    private var chartData: [Double] {
        let cal = Calendar.current
        let now = Date()
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else { return [0] }
        let dayOfMonth = max(1, cal.component(.day, from: now))
        var cum = 0.0
        return (0..<dayOfMonth).map { offset in
            let start = cal.date(byAdding: .day, value: offset, to: monthStart)!
            let end   = cal.date(byAdding: .day, value: 1, to: start)!
            let day = financeManager.expenses
                .filter { $0.date >= start && $0.date < end && !$0.category.isIncome }
                .reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.amount).doubleValue }
            cum += day
            return cum
        }
    }

    // spending DOWN = good (green), spending UP = bad (red) — same as banking apps
    private var trendUp: Bool { trendPct > 0 }
    private var trendZero: Bool { abs(trendPct) < 0.1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Text("Total Balance")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FT.t2)
                        Image(systemName: "eye")
                            .font(.system(size: 12))
                            .foregroundStyle(FT.t3)
                    }

                    Text(CurrencyFormatting.shared.string(for: financeManager.thisMonthTotal))
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundStyle(FT.t1)
                        .contentTransition(.numericText())

                    if !trendZero {
                        HStack(spacing: 3) {
                            Image(systemName: trendUp ? "arrow.up" : "arrow.down")
                                .font(.system(size: 11, weight: .bold))
                            Text(String(format: "%.1f%% vs last month", abs(trendPct)))
                                .font(.system(size: 12, weight: .medium))
                        }
                        // spending up = red (over-spending), spending down = green (saving more)
                        .foregroundStyle(trendUp ? Color(red: 0.9, green: 0.3, blue: 0.3) : FT.green)
                    }
                }

                Spacer()

                Button {
                } label: {
                    HStack(spacing: 4) {
                        Text("All Accounts")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(FT.t1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(FT.bg)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Chart
            SmoothChartView(dataPoints: chartData.isEmpty ? [0, 0] : chartData,
                            lineColor: FT.green,
                            showFill: true)
                .frame(height: 68)
                .padding(.top, 14)
                .padding(.horizontal, -4)
        }
        .ftCard(padding: 22)
    }
}

// MARK: - Smooth Chart

private struct SmoothChartView: View {
    let dataPoints: [Double]
    let lineColor: Color
    let showFill: Bool

    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let pts = normalized(dataPoints, size: geo.size)
            ZStack {
                if showFill, pts.count > 1 {
                    areaPath(pts, size: geo.size)
                        .fill(
                            LinearGradient(
                                colors: [lineColor.opacity(0.22), lineColor.opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
                if pts.count > 1 {
                    linePath(pts)
                        .trim(from: 0, to: progress)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                // Dot at end
                if let last = pts.last, progress > 0.95 {
                    Circle()
                        .fill(lineColor)
                        .frame(width: 8, height: 8)
                        .position(last)
                        .shadow(color: lineColor.opacity(0.4), radius: 4)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4)) { progress = 1 }
        }
    }

    private func normalized(_ values: [Double], size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let mn = values.min() ?? 0
        let mx = values.max() ?? 1
        let range = max(mx - mn, 1)
        let wStep = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            CGPoint(
                x: CGFloat(i) * wStep,
                y: size.height - (CGFloat(v - mn) / CGFloat(range)) * size.height * 0.8 - size.height * 0.05
            )
        }
    }

    private func linePath(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard pts.count > 1 else { return p }
        p.move(to: pts[0])
        for i in 1..<pts.count {
            let c1 = CGPoint(x: (pts[i-1].x + pts[i].x) / 2, y: pts[i-1].y)
            let c2 = CGPoint(x: (pts[i-1].x + pts[i].x) / 2, y: pts[i].y)
            p.addCurve(to: pts[i], control1: c1, control2: c2)
        }
        return p
    }

    private func areaPath(_ pts: [CGPoint], size: CGSize) -> Path {
        var p = linePath(pts)
        p.addLine(to: CGPoint(x: pts.last!.x, y: size.height))
        p.addLine(to: CGPoint(x: pts.first!.x, y: size.height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Mini Sparkline (for analytics cards)

private struct MiniSparklineView: View {
    let dataPoints: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let pts = normalized(dataPoints, size: geo.size)
            if pts.count > 1 {
                ZStack {
                    areaPath(pts, size: geo.size)
                        .fill(LinearGradient(colors: [color.opacity(0.2), color.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                    linePath(pts)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }
            }
        }
    }

    private func normalized(_ values: [Double], size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let mn = values.min() ?? 0; let mx = values.max() ?? 1
        let range = max(mx - mn, 1); let wStep = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * wStep,
                    y: size.height - (CGFloat(v - mn) / CGFloat(range)) * size.height * 0.85)
        }
    }

    private func linePath(_ pts: [CGPoint]) -> Path {
        var p = Path(); guard pts.count > 1 else { return p }
        p.move(to: pts[0])
        for i in 1..<pts.count {
            p.addCurve(to: pts[i],
                       control1: CGPoint(x: (pts[i-1].x + pts[i].x)/2, y: pts[i-1].y),
                       control2: CGPoint(x: (pts[i-1].x + pts[i].x)/2, y: pts[i].y))
        }
        return p
    }

    private func areaPath(_ pts: [CGPoint], size: CGSize) -> Path {
        var p = linePath(pts)
        p.addLine(to: CGPoint(x: pts.last!.x, y: size.height))
        p.addLine(to: CGPoint(x: pts.first!.x, y: size.height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Analytics Row

private struct AnalyticsRow: View {
    @ObservedObject var financeManager: FinanceManager

    private var weekData: [Double] {
        let cal = Calendar.current; let now = Date()
        return (0...6).map { offset -> Double in
            guard let day = cal.date(byAdding: .day, value: -(6 - offset), to: now) else { return 0 }
            let start = cal.startOfDay(for: day)
            let end   = cal.date(byAdding: .day, value: 1, to: start)!
            return financeManager.expenses
                .filter { $0.date >= start && $0.date < end && !$0.category.isIncome }
                .reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.amount).doubleValue }
        }
    }

    private var budgetRatio: Double { financeManager.monthlyBudgetUsageRatio ?? 0 }

    private var spendingTrendPct: Double {
        let cal = Calendar.current; let now = Date()
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let lastStart  = cal.date(byAdding: .month, value: -1, to: monthStart) else { return 0 }
        let last = financeManager.expenses
            .filter { $0.date >= lastStart && $0.date < monthStart && !$0.category.isIncome }
            .reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.amount).doubleValue }
        let current = NSDecimalNumber(decimal: financeManager.thisMonthTotal).doubleValue
        guard last > 0 else { return current > 0 ? 100 : 0 }
        return ((current - last) / last) * 100
    }

    var body: some View {
        HStack(spacing: 14) {
            // Spending card
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    (Text("Spending").font(.system(size: 12, weight: .semibold)).foregroundStyle(FT.t2)
                     + Text(" · ").font(.system(size: 12, weight: .regular)).foregroundStyle(FT.t3)
                     + Text("This Month").font(.system(size: 12, weight: .regular)).foregroundStyle(FT.t3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(FT.green.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FT.green)
                    }
                }

                Text(CurrencyFormatting.shared.string(for: financeManager.thisMonthTotal))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(FT.t1)
                    .contentTransition(.numericText())

                // Trend vs last month — spending DOWN is green (good)
                let trendColor = spendingTrendPct > 0
                    ? Color(red: 0.9, green: 0.3, blue: 0.3)
                    : FT.green
                if abs(spendingTrendPct) > 0.1 {
                    HStack(spacing: 3) {
                        Image(systemName: spendingTrendPct > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "%.1f%% vs last month", abs(spendingTrendPct)))
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(trendColor)
                }

                MiniSparklineView(dataPoints: weekData.isEmpty ? [0,0] : weekData,
                                  color: spendingTrendPct > 0 ? Color(red: 0.9, green: 0.3, blue: 0.3) : FT.green)
                    .frame(height: 36)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .ftCard()
            .frame(maxWidth: .infinity)

            // Budget card
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Budget Left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FT.t2)
                        if let budget = financeManager.monthlyBudget {
                            let pct = Int(min(budgetRatio * 100, 100))
                            Text("\(pct)% of \(CurrencyFormatting.shared.string(for: budget))")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(FT.t3)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else {
                            Text("No budget set")
                                .font(.system(size: 11))
                                .foregroundStyle(FT.t3)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    // Static pie chart icon (matches reference) instead of arc ring
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill((budgetRatio > 0.9 ? Color.red : FT.green).opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(budgetRatio > 0.9 ? Color.red : FT.green)
                    }
                }

                if let budget = financeManager.monthlyBudget {
                    let remaining = budget - financeManager.thisMonthTotal
                    Text(remaining >= 0
                         ? CurrencyFormatting.shared.string(for: remaining)
                         : "-\(CurrencyFormatting.shared.string(for: -remaining))")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(remaining >= 0 ? FT.t1 : Color.red)
                        .contentTransition(.numericText())
                } else {
                    Text("—")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(FT.t3)
                }

                Spacer(minLength: 0)

                // Progress bar
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(FT.bg).frame(height: 5)
                        Capsule()
                            .fill(budgetRatio > 0.9 ? Color.red : FT.green)
                            .frame(width: g.size.width * min(CGFloat(budgetRatio), 1), height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .ftCard()
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 0)
    }
}

// MARK: - Recurring Bills Card

private struct RecurringBillsCard: View {
    @ObservedObject var financeManager: FinanceManager

    private var topRecurring: [RecurringExpense] {
        Array(financeManager.recurringExpenses
            .filter { $0.isActive }
            .sorted { NSDecimalNumber(decimal: $0.amount).doubleValue > NSDecimalNumber(decimal: $1.amount).doubleValue }
            .prefix(5))
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recurring Bills")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FT.t2)
                Text(CurrencyFormatting.shared.string(for: financeManager.recurringMonthlyTotal))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(FT.t1)
                Text("\(financeManager.activeRecurringCount) active")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(FT.t3)
            }

            Spacer()

            if topRecurring.isEmpty {
                Text("None yet")
                    .font(.system(size: 12))
                    .foregroundStyle(FT.t3)
            } else {
                HStack(spacing: -10) {
                    ForEach(Array(topRecurring.prefix(3).enumerated()), id: \.offset) { idx, expense in
                        MerchantLogoView(merchant: expense.title, category: expense.category, size: 36)
                            .overlay(Circle().stroke(FT.card, lineWidth: 2))
                            .zIndex(Double(3 - idx))
                    }
                    if topRecurring.count > 3 {
                        ZStack {
                            Circle().fill(FT.bg)
                            Text("+\(topRecurring.count - 3)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(FT.t2)
                        }
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(FT.card, lineWidth: 2))
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FT.t3)
        }
        .ftCard()
    }
}

// MARK: - Recent Transactions

private struct RecentTransactionsSection: View {
    @ObservedObject var financeManager: FinanceManager
    let onViewAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Transactions")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FT.t1)
                Spacer()
                Button(action: onViewAll) {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(FT.green)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            let recent = financeManager.recentExpenses(limit: 5)
            if recent.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "receipt")
                        .font(.system(size: 32))
                        .foregroundStyle(FT.t3)
                    Text("No transactions yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FT.t2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { idx, expense in
                        TransactionRow(expense: expense)
                        if idx < recent.count - 1 {
                            Divider()
                                .padding(.leading, 72)
                                .padding(.trailing, 20)
                        }
                    }
                }
            }

            Spacer(minLength: 16)
        }
        .background(FT.card)
        .clipShape(RoundedRectangle(cornerRadius: FT.cardR, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 4)
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
}

private struct TransactionRow: View {
    let expense: Expense

    private var relativeDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(expense.date) { return "Today" }
        if cal.isDateInYesterday(expense.date) { return "Yesterday" }
        return expense.date.formattedDate
    }

    var body: some View {
        HStack(spacing: 14) {
            MerchantLogoView(merchant: expense.title, category: expense.category, size: 44)
                .padding(.leading, 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FT.t1)
                HStack(spacing: 5) {
                    Text(expense.category.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FT.t2)
                    Circle()
                        .fill(expense.category.color)
                        .frame(width: 5, height: 5)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(expense.category.isIncome
                     ? "+\(CurrencyFormatting.shared.string(for: expense.amount))"
                     : "-\(CurrencyFormatting.shared.string(for: expense.amount))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(expense.category.isIncome ? FT.green : FT.t1)
                Text(relativeDate)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(FT.t3)
            }
            .padding(.trailing, 20)
        }
        .padding(.vertical, 13)
    }
}

// MARK: - AI Insight Card

private struct AIInsightCard: View {
    @ObservedObject var financeManager: FinanceManager
    let onTap: () -> Void

    private var insightText: String {
        let top = financeManager.topCategoriesThisMonth(limit: 1).first
        if let ratio = financeManager.monthlyBudgetUsageRatio {
            if ratio > 0.9 {
                return "You've used \(Int(ratio * 100))% of your monthly budget. Consider reviewing discretionary spending. 💡"
            }
            if ratio < 0.5 {
                return "Great pace — you've only used \(Int(ratio * 100))% of your budget this month. Keep it up! 🎯"
            }
        }
        if let cat = top {
            return "Your top spend this month is \(cat.category.rawValue) at \(CurrencyFormatting.shared.string(for: cat.total)). Want to set a category budget? 💬"
        }
        return "Ask me anything about your spending, budgets, or savings goals. I'm here to help! ✨"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(FT.green.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FT.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Insight")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FT.green)
                    Text(insightText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FT.t1)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                ZStack {
                    Circle()
                        .fill(FT.green.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(FT.green)
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [FT.green.opacity(0.08), FT.green.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: FT.cardR, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FT.cardR, style: .continuous)
                    .strokeBorder(FT.green.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Spending Analysis Card

private struct SpendingAnalysisCard: View {
    let onTap: () -> Void
    @ObservedObject var financeManager: FinanceManager

    private var subtitle: String {
        let count = financeManager.topCategoriesThisMonth(limit: 10).count
        return count > 0 ? "\(count) categories this month" : "AI-powered breakdown"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(FT.green.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FT.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Spending Analysis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FT.t1)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FT.t2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FT.t3)
            }
        }
        .buttonStyle(.plain)
        .ftCard(padding: 18)
    }
}

// MARK: - Quick Actions Grid

private struct QuickActionsGrid: View {
    let onAddExpense:  () -> Void
    let onScanReceipt: () -> Void
    let onAddIncome:   () -> Void
    let onImport:      () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Actions")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FT.t1)

            HStack(spacing: 12) {
                DashQuickAction(icon: "plus.circle.fill",       title: "Add Expense",  color: FT.green,                                   action: onAddExpense)
                DashQuickAction(icon: "viewfinder",             title: "Scan Document", color: Color(red: 0.2, green: 0.5, blue: 0.9),     action: onScanReceipt)
                DashQuickAction(icon: "arrow.down.circle.fill", title: "Add Income",   color: Color(red: 0.6, green: 0.2, blue: 0.9),     action: onAddIncome)
                DashQuickAction(icon: "photo.badge.plus",       title: "Import",       color: Color(red: 0.9, green: 0.5, blue: 0.1),     action: onImport)
            }
        }
    }
}

private struct DashQuickAction: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FT.t2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(pressed ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.2)) { pressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3)) { pressed = false } }
        )
    }
}

// MARK: - Expenses Tab

private struct ExpensesTabView: View {
    @ObservedObject var financeManager: FinanceManager
    let onAddExpense:  () -> Void
    let onScanReceipt: () -> Void
    let onAskAI:       () -> Void

    @State private var searchText = ""
    @State private var selectedCategory: ExpenseCategory?

    var filteredExpenses: [Expense] {
        financeManager.filteredExpenses(searchText: searchText, category: selectedCategory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Expenses")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(FT.t1)
                    Text("\(filteredExpenses.count) transactions")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FT.t2)
                }
                Spacer()
                HStack(spacing: 8) {
                    SmallIconButton(icon: "camera.fill", color: FT.green, action: onScanReceipt)
                    SmallIconButton(icon: "sparkles",    color: FT.green, action: onAskAI)
                    SmallIconButton(icon: "plus",         color: FT.t1,   action: onAddExpense)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(FT.t3)
                    .font(.system(size: 15))
                TextField("Search transactions...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundStyle(FT.t1)
                    .tint(FT.green)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(FT.t3)
                    }
                }
            }
            .padding(12)
            .background(FT.card)
            .clipShape(RoundedRectangle(cornerRadius: FT.innerR, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", color: FT.green,
                               isSelected: selectedCategory == nil) { selectedCategory = nil }
                    ForEach(ExpenseCategory.allCases) { cat in
                        FilterChip(title: cat.rawValue, color: cat.color,
                                   isSelected: selectedCategory == cat) { selectedCategory = cat }
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.bottom, 12)

            // List
            if filteredExpenses.isEmpty {
                PremiumEmptyState(icon: "receipt", title: "No Expenses",
                                  message: "Tap + to add your first expense")
                    .padding(18)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredExpenses.enumerated()), id: \.element.id) { idx, expense in
                            TransactionRow(expense: expense)
                                .background(FT.card)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        financeManager.deleteExpense(id: expense.id)
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            if idx < filteredExpenses.count - 1 {
                                Divider().padding(.leading, 78)
                            }
                        }
                    }
                    .background(FT.card)
                    .clipShape(RoundedRectangle(cornerRadius: FT.cardR, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 4)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : FT.t2)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color : FT.card)
                .clipShape(Capsule())
                .shadow(color: isSelected ? color.opacity(0.3) : .black.opacity(0.04),
                        radius: isSelected ? 6 : 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct SmallIconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recurring Tab

private struct RecurringTabView: View {
    @ObservedObject var financeManager: FinanceManager
    let onAddRecurring: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recurring")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(FT.t1)
                        Text("\(financeManager.activeRecurringCount) active bills")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FT.t2)
                    }
                    Spacer()
                    Button(action: onAddRecurring) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(FT.green)
                            .clipShape(Circle())
                            .shadow(color: FT.green.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }

                // Summary card
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Total")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FT.t2)
                        Text(CurrencyFormatting.shared.string(for: financeManager.recurringMonthlyTotal))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(FT.t1)
                        Text("↳ \(CurrencyFormatting.shared.string(for: financeManager.recurringMonthlyTotal * 12))/year")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FT.t3)
                    }
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(FT.green.opacity(0.5))
                }
                .ftCard()

                // Bills list
                if financeManager.upcomingRecurringExpenses.isEmpty {
                    PremiumEmptyState(icon: "calendar.badge.clock",
                                     title: "No Recurring Bills",
                                     message: "Add your subscriptions and bills to track them automatically")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(financeManager.upcomingRecurringExpenses.enumerated()), id: \.element.id) { idx, expense in
                            RecurringRow(expense: expense)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        financeManager.deleteRecurringExpense(id: expense.id)
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            if idx < financeManager.upcomingRecurringExpenses.count - 1 {
                                Divider().padding(.leading, 78)
                            }
                        }
                    }
                    .background(FT.card)
                    .clipShape(RoundedRectangle(cornerRadius: FT.cardR, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }
}

private struct RecurringRow: View {
    let expense: RecurringExpense

    private var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expense.nextDueDate).day ?? 0
    }

    var body: some View {
        HStack(spacing: 14) {
            MerchantLogoView(merchant: expense.title, category: expense.category, size: 44)
                .padding(.leading, 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FT.t1)
                HStack(spacing: 5) {
                    Text(expense.frequency.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FT.t2)
                    Circle().fill(FT.t3).frame(width: 3, height: 3)
                    Text(daysUntil == 0 ? "Due today" :
                         daysUntil < 0  ? "Overdue"  :
                         "Due in \(daysUntil)d")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(daysUntil <= 3 ? Color(red: 0.9, green: 0.4, blue: 0.1) : FT.t3)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(CurrencyFormatting.shared.string(for: expense.amount))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(FT.t1)
                Text(expense.category.rawValue)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(expense.category.color)
            }
            .padding(.trailing, 20)
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Insights Tab

private struct InsightsTabView: View {
    @ObservedObject var financeManager: FinanceManager
    @EnvironmentObject private var financeAIManager: FinanceAIManager
    let onAskAI: () -> Void

    @State private var selectedCategoryIndex: Int? = nil
    @State private var categoryInsight: String? = nil
    @State private var isLoadingInsight = false

    private var spendingData: [(category: ExpenseCategory, total: Decimal, percentage: Double)] {
        let cats = financeManager.topCategoriesThisMonth(limit: 8)
        let grandTotal = cats.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.total).doubleValue }
        guard grandTotal > 0 else { return [] }
        return cats.map { item in
            let pct = NSDecimalNumber(decimal: item.total).doubleValue / grandTotal
            return (item.category, item.total, pct)
        }
    }

    private var selectedItem: (category: ExpenseCategory, total: Decimal, percentage: Double)? {
        guard let idx = selectedCategoryIndex, idx < spendingData.count else { return nil }
        return spendingData[idx]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Insights")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(FT.t1)
                    .padding(.top, 18)

                // Monthly overview
                VStack(alignment: .leading, spacing: 14) {
                    Text("This Month")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FT.t2)
                    HStack(spacing: 14) {
                        InsightMetric(label: "Spent",
                                      value: CurrencyFormatting.shared.string(for: financeManager.thisMonthTotal),
                                      color: FT.green)
                        Divider().frame(height: 36)
                        InsightMetric(label: "This Week",
                                      value: CurrencyFormatting.shared.string(for: financeManager.thisWeekTotal),
                                      color: Color(red: 0.2, green: 0.5, blue: 0.9))
                        Divider().frame(height: 36)
                        InsightMetric(label: "Recurring",
                                      value: CurrencyFormatting.shared.string(for: financeManager.recurringMonthlyTotal),
                                      color: Color(red: 0.6, green: 0.2, blue: 0.9))
                    }
                }
                .ftCard()

                // Pie chart card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Spending by Category")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FT.t2)
                        Spacer()
                        if selectedCategoryIndex != nil {
                            Button {
                                withAnimation(.spring()) { selectedCategoryIndex = nil }
                            } label: {
                                Text("Clear")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(FT.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if spendingData.isEmpty {
                        Text("Add expenses to see your breakdown")
                            .font(.system(size: 14))
                            .foregroundStyle(FT.t3)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 32)
                    } else {
                        ZStack {
                            SpendingPieChartView(slices: spendingData, selectedIndex: $selectedCategoryIndex)
                                .frame(height: 220)

                            VStack(spacing: 3) {
                                if let item = selectedItem {
                                    Text(item.category.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(item.category.color)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(maxWidth: 80)
                                    Text(CurrencyFormatting.shared.string(for: item.total))
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(FT.t1)
                                    Text("\(Int(item.percentage * 100))%")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(FT.t3)
                                } else {
                                    Text("Total")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(FT.t2)
                                    Text(CurrencyFormatting.shared.string(for: financeManager.thisMonthTotal))
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(FT.t1)
                                    Text("this month")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(FT.t3)
                                }
                            }
                            .animation(.spring(response: 0.35), value: selectedCategoryIndex)
                        }

                        // Legend grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(Array(spendingData.enumerated()), id: \.offset) { i, item in
                                Button {
                                    withAnimation(.spring(response: 0.35)) {
                                        selectedCategoryIndex = selectedCategoryIndex == i ? nil : i
                                    }
                                } label: {
                                    HStack(spacing: 7) {
                                        Circle()
                                            .fill(item.category.color)
                                            .frame(width: 9, height: 9)
                                        Text(item.category.rawValue)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(FT.t1)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                        Text("\(Int(item.percentage * 100))%")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(FT.t2)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedCategoryIndex == i
                                            ? item.category.color.opacity(0.12)
                                            : FT.bg
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .strokeBorder(
                                                selectedCategoryIndex == i ? item.category.color.opacity(0.4) : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("Tap a slice or label to get AI insight")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FT.t3)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .ftCard()

                // AI Category Insight card
                if let item = selectedItem {
                    CategoryInsightCard(
                        category: item.category,
                        amount: item.total,
                        percentage: item.percentage,
                        insight: $categoryInsight,
                        isLoading: $isLoadingInsight
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Budget health
                if financeManager.monthlyBudget != nil {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Budget Health")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FT.t2)
                        Text(financeManager.budgetStatusText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FT.t1)
                        if let ratio = financeManager.monthlyBudgetUsageRatio {
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(FT.bg).frame(height: 10)
                                    Capsule()
                                        .fill(ratio > 1 ? Color.red : FT.green)
                                        .frame(width: g.size.width * min(CGFloat(ratio), 1), height: 10)
                                }
                            }
                            .frame(height: 10)
                        }
                    }
                    .ftCard()
                }

                // Ask AI button
                Button(action: onAskAI) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Ask AI for personalized insights")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(FT.green)
                    .clipShape(RoundedRectangle(cornerRadius: FT.innerR, style: .continuous))
                    .shadow(color: FT.green.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .animation(.spring(response: 0.4), value: selectedCategoryIndex)
        .task(id: selectedCategoryIndex) {
            guard let idx = selectedCategoryIndex, idx < spendingData.count else {
                categoryInsight = nil
                isLoadingInsight = false
                return
            }
            let item = spendingData[idx]
            categoryInsight = nil
            isLoadingInsight = true

            let catExpenses = financeManager.expenses
                .filter { $0.category == item.category && !$0.category.isIncome }
                .sorted { $0.date > $1.date }
                .prefix(5)

            let recentTx = catExpenses.map {
                "\($0.title): \(CurrencyFormatting.shared.string(for: $0.amount))"
            }.joined(separator: ", ")

            let monthlyTotal = NSDecimalNumber(decimal: financeManager.thisMonthTotal).doubleValue

            categoryInsight = await financeAIManager.getCategoryInsight(
                category: item.category.rawValue,
                amount: NSDecimalNumber(decimal: item.total).doubleValue,
                percentage: item.percentage,
                monthlyTotal: monthlyTotal,
                recentTransactions: recentTx
            )
            isLoadingInsight = false
        }
    }
}

// MARK: - Spending Pie Chart

private struct SpendingPieChartView: View {
    let slices: [(category: ExpenseCategory, total: Decimal, percentage: Double)]
    @Binding var selectedIndex: Int?

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: size / 2)
            let outerR = size / 2 - 4
            let innerR = outerR * 0.52

            Canvas { ctx, _ in
                var startDeg = -90.0
                for (i, slice) in slices.enumerated() {
                    let endDeg = startDeg + slice.percentage * 360
                    let r: CGFloat = selectedIndex == i ? outerR + 10 : outerR
                    let alpha: Double = selectedIndex == nil || selectedIndex == i ? 1.0 : 0.38

                    var path = Path()
                    path.addArc(center: center, radius: r,
                                startAngle: .degrees(startDeg + 0.5),
                                endAngle: .degrees(endDeg - 0.5),
                                clockwise: false)
                    path.addArc(center: center, radius: innerR,
                                startAngle: .degrees(endDeg - 0.5),
                                endAngle: .degrees(startDeg + 0.5),
                                clockwise: true)
                    path.closeSubpath()

                    ctx.fill(path, with: .color(slice.category.color.opacity(alpha)))
                    startDeg = endDeg
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    let dx = value.location.x - center.x
                    let dy = value.location.y - center.y
                    let dist = sqrt(dx * dx + dy * dy)

                    guard dist > innerR else {
                        withAnimation(.spring(response: 0.35)) { selectedIndex = nil }
                        return
                    }

                    var angle = atan2(dy, dx) * 180 / .pi + 90
                    if angle < 0 { angle += 360 }

                    var cumDeg = 0.0
                    for (i, slice) in slices.enumerated() {
                        cumDeg += slice.percentage * 360
                        if angle <= cumDeg || i == slices.count - 1 {
                            withAnimation(.spring(response: 0.35)) {
                                selectedIndex = selectedIndex == i ? nil : i
                            }
                            return
                        }
                    }
                }
            )
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.7)
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }
}

// MARK: - Category Insight Card

private struct CategoryInsightCard: View {
    let category: ExpenseCategory
    let amount: Decimal
    let percentage: Double
    @Binding var insight: String?
    @Binding var isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: category.sfSymbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(category.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Insight · \(category.rawValue)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(category.color)
                    Text("\(CurrencyFormatting.shared.string(for: amount)) · \(Int(percentage * 100))% of spending")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FT.t3)
                }
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.75)
                        .tint(category.color)
                    Text("Analyzing \(category.rawValue) spending…")
                        .font(.system(size: 13))
                        .foregroundStyle(FT.t2)
                }
                .padding(.top, 2)
            } else if let text = insight {
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FT.t1)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [category.color.opacity(0.09), category.color.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: FT.cardR, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FT.cardR, style: .continuous)
                .strokeBorder(category.color.opacity(0.22), lineWidth: 1)
        )
        .animation(.spring(response: 0.35), value: isLoading)
        .animation(.spring(response: 0.35), value: insight)
    }
}

private struct InsightMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FT.t3)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(FT.t1)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Settings Tab

private struct FinanceSettingsTabView: View {
    @ObservedObject var financeManager: FinanceManager
    @ObservedObject private var billReminders = BillReminderManager.shared
    @EnvironmentObject private var authManager: AuthenticationManager

    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showEditProfile        = false
    @State private var showBudgetEditor       = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(FT.t1)
                    .padding(.top, 18)

                Text(financeManager.syncStatusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FT.t3)

                SettingsSection(label: "Budget & Categories") {
                    PremiumSettingsRow(icon: "chart.pie.fill", color: FT.green,
                                       title: "Monthly Budget",
                                       detail: financeManager.monthlyBudget.map { CurrencyFormatting.shared.string(for: $0) } ?? "Not set") {
                        showBudgetEditor = true
                    }
                    SettingsDivider()
                    PremiumSettingsRow(icon: "tag.fill", color: Color(red: 0.2, green: 0.5, blue: 0.9),
                                       title: "Categories",
                                       detail: "\(ExpenseCategory.allCases.count)") { }
                }

                SettingsSection(label: "Reminders") {
                    SettingsToggleRow(icon: "bell.badge.fill",
                                      color: Color(red: 0.95, green: 0.55, blue: 0.1),
                                      title: "Bill Reminders",
                                      detail: "A day before each bill is due",
                                      isOn: Binding(
                                        get: { billReminders.isEnabled },
                                        set: { wantsOn in
                                            if wantsOn {
                                                Task { await billReminders.enable(with: financeManager.upcomingRecurringExpenses) }
                                            } else {
                                                billReminders.disable()
                                            }
                                        }))
                }

                SettingsSection(label: "Data") {
                    ShareLink(item: financeManager.exportJSON(),
                              subject: Text("Finance Tracker Export"),
                              message: Text("Finance Tracker JSON export")) {
                        PremiumSettingsRowLabel(icon: "square.and.arrow.up",
                                               color: Color(red: 0.6, green: 0.2, blue: 0.9),
                                               title: "Export Data", detail: nil)
                    }
                    SettingsDivider()
                    PremiumSettingsRow(icon: "trash.fill", color: .red,
                                       title: "Clear All Data", detail: nil, isDestructive: true) {
                        showDeleteConfirmation = true
                    }
                }

                SettingsSection(label: "Profile") {
                    PremiumSettingsRow(icon: "person.fill", color: FT.green,
                                       title: financeManager.currentProfile.displayName,
                                       detail: financeManager.currentProfile.email) {
                        showEditProfile = true
                    }
                    SettingsDivider()
                    PremiumSettingsRow(icon: "rectangle.portrait.and.arrow.right", color: .red,
                                       title: "Sign Out", detail: nil, isDestructive: true) {
                        showSignOutConfirmation = true
                    }
                }

                SettingsSection(label: "About") {
                    PremiumSettingsRow(icon: "info.circle.fill", color: FT.t2,
                                       title: "Version", detail: appVersionString) { }
                    SettingsDivider()
                    Link(destination: URL(string: "https://github.com/AgentScienceandResearch/Finance-Tracker-iOS/issues")!) {
                        PremiumSettingsRowLabel(icon: "questionmark.circle.fill", color: FT.t2,
                                               title: "Help & Support", detail: nil)
                    }
                    SettingsDivider()
                    Link(destination: URL(string: "https://github.com/AgentScienceandResearch/Finance-Tracker-iOS/blob/main/PRIVACY_POLICY.md")!) {
                        PremiumSettingsRowLabel(icon: "hand.raised.fill", color: FT.t2,
                                               title: "Privacy Policy", detail: nil)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .confirmationDialog("Clear all tracked data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Clear All Data", role: .destructive) { financeManager.clearAllData() }
        }
        .confirmationDialog("Sign out of Finance Tracker?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { authManager.signOut() }
        }
        .sheet(isPresented: $showEditProfile)  { EditProfileSheet(financeManager: financeManager) }
        .sheet(isPresented: $showBudgetEditor) { BudgetEditorSheet(financeManager: financeManager) }
    }

    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }
}

private struct SettingsSection<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FT.t3)
                .padding(.leading, 4)

            VStack(spacing: 0) { content }
                .background(FT.card)
                .clipShape(RoundedRectangle(cornerRadius: FT.innerR, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 2)
        }
    }
}

private struct PremiumSettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String?
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PremiumSettingsRowLabel(icon: icon, color: color,
                                    title: title, detail: detail,
                                    isDestructive: isDestructive)
        }
        .buttonStyle(.plain)
    }
}

private struct PremiumSettingsRowLabel: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String?
    var isDestructive: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDestructive ? Color.red.opacity(0.12) : color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isDestructive ? .red : color)
            }

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isDestructive ? .red : FT.t1)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(FT.t3)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FT.t3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FT.t1)
                if let detail {
                    Text(detail)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(FT.t3)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(FT.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider().padding(.leading, 60)
    }
}

// MARK: - Shared: Premium Empty State

private struct PremiumEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(FT.t3)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(FT.t2)
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(FT.t3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .ftCard()
    }
}

// MARK: - Sheets: Add Expense

private struct AddExpenseSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @Environment(\.dismiss) private var dismiss
    var initialCategory: ExpenseCategory = .foodDining

    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var inlineError: String?
    @State private var category: ExpenseCategory

    init(financeManager: FinanceManager, initialCategory: ExpenseCategory = .foodDining) {
        self.financeManager = financeManager
        self.initialCategory = initialCategory
        _category = State(initialValue: initialCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { opt in Text(opt.rawValue).tag(opt) }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
                }
                if let inlineError {
                    Section { Text(inlineError).foregroundStyle(.red) }
                }
            }
            .navigationTitle(initialCategory.isIncome ? "Add Income" : "Add Expense")
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.fontWeight(.bold) }
            }
            .tint(FT.green)
        }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { inlineError = "Please enter a title."; return }
        guard let amt = DecimalParser.parse(amount), amt > 0 else { inlineError = "Please enter a valid amount."; return }
        financeManager.addExpense(Expense(title: t, amount: amt, category: category, date: date,
                                          notes: notes.isEmpty ? nil : notes))
        dismiss()
    }
}

// MARK: - Sheets: Add Recurring

private struct AddRecurringExpenseSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @Environment(\.dismiss) private var dismiss

    @State private var title        = ""
    @State private var amount       = ""
    @State private var category: ExpenseCategory = .subscriptions
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var nextDueDate  = Date()
    @State private var notes        = ""
    @State private var inlineError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Recurring Expense") {
                    TextField("Title", text: $title)

                    let suggestions = category.recurringTitleSuggestions
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { s in
                                    Button(s) { title = s }
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(title == s ? .white : category.color)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(title == s ? category.color : category.color.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { opt in Text(opt.rawValue).tag(opt) }
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(RecurrenceFrequency.allCases) { opt in Text(opt.rawValue).tag(opt) }
                    }
                    DatePicker("Next Due Date", selection: $nextDueDate, displayedComponents: .date)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
                }
                if let inlineError {
                    Section { Text(inlineError).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Add Recurring")
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.fontWeight(.bold) }
            }
            .tint(FT.green)
        }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { inlineError = "Please enter a title."; return }
        guard let amt = DecimalParser.parse(amount), amt > 0 else { inlineError = "Please enter a valid amount."; return }
        financeManager.addRecurringExpense(RecurringExpense(
            title: t, amount: amt, category: category,
            frequency: frequency, nextDueDate: nextDueDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes))
        dismiss()
    }
}

// MARK: - Document Camera (VisionKit wrapper)

private struct DocumentCameraView: UIViewControllerRepresentable {
    let onScan: (VNDocumentCameraScan) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentCameraView
        init(_ parent: DocumentCameraView) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.onScan(scan)
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onError(error)
        }
    }
}

// MARK: - Sheets: Scan Document

private struct ReceiptScannerSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @ObservedObject var aiManager: FinanceAIManager
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case scanning, extracting, review }
    @State private var phase: Phase = .scanning
    @State private var drafts: [ScannerDraft] = []

    var body: some View {
        switch phase {
        case .scanning:
            DocumentCameraView(
                onScan: { scan in
                    Task { await extract(scan: scan) }
                },
                onCancel: { dismiss() },
                onError: { _ in dismiss() }
            )
            .ignoresSafeArea()

        case .extracting:
            VStack(spacing: 20) {
                Spacer()
                ProgressView().scaleEffect(1.6).tint(FT.green)
                Text("Analyzing document…")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FT.t2)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FT.bg.ignoresSafeArea())

        case .review:
            NavigationStack {
                reviewView
                    .background(FT.bg.ignoresSafeArea())
                    .navigationTitle("Scan Document")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Rescan") { phase = .scanning }
                                .foregroundStyle(FT.t2)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save Selected") { saveSelected() }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(selectedCount > 0 ? FT.green : FT.t3)
                                .disabled(selectedCount == 0)
                        }
                    }
                    .tint(FT.green)
            }
        }
    }

    // MARK: - Review

    private var reviewView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if drafts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(FT.t3)
                        Text("No transactions found")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FT.t1)
                        Text("Try scanning again with better lighting or a flatter document.")
                            .font(.system(size: 13))
                            .foregroundStyle(FT.t2)
                            .multilineTextAlignment(.center)
                        Button("Scan Again") { phase = .scanning }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FT.green)
                            .padding(.top, 8)
                    }
                    .padding(40)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("\(drafts.count) transaction\(drafts.count == 1 ? "" : "s") found")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FT.t2)
                            Spacer()
                            Button(selectedCount == drafts.count ? "Deselect All" : "Select All") {
                                let all = selectedCount == drafts.count
                                for i in drafts.indices { drafts[i].selected = !all }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FT.green)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)

                        ForEach($drafts) { $item in
                            ScannerDraftRow(item: $item)
                                .padding(.horizontal, 18)
                                .padding(.bottom, 10)
                        }

                        Spacer(minLength: 24)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var selectedCount: Int { drafts.filter(\.selected).count }

    private func extract(scan: VNDocumentCameraScan) async {
        phase = .extracting
        guard let jpeg = scan.imageOfPage(at: 0).resizedForScan().jpegData(compressionQuality: 0.7) else {
            phase = .review
            return
        }
        let base64 = jpeg.base64EncodedString()
        let results = await aiManager.parseImage(imageBase64: base64, mimeType: "image/jpeg")
        drafts = results.map { ScannerDraft(draft: $0) }
        phase = .review
    }

    private func saveSelected() {
        for item in drafts where item.selected {
            financeManager.applyReceiptDraft(item.draft)
        }
        dismiss()
    }
}

private struct ScannerDraft: Identifiable {
    let id = UUID()
    let draft: ReceiptDraft
    var selected: Bool = true
}

private struct ScannerDraftRow: View {
    @Binding var item: ScannerDraft

    var body: some View {
        Button { item.selected.toggle() } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(item.selected ? FT.green : FT.t3.opacity(0.25))
                        .frame(width: 24, height: 24)
                    if item.selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                MerchantLogoView(merchant: item.draft.merchant, category: item.draft.category, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.draft.merchant)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FT.t1)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.draft.category.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(item.draft.category.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(item.draft.category.color.opacity(0.12))
                            .clipShape(Capsule())
                        Text(item.draft.purchaseDate.formattedDate)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FT.t3)
                    }
                }

                Spacer()

                Text(CurrencyFormatting.shared.string(for: item.draft.amount))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(item.draft.amount < 0 ? FT.green : FT.t1)
            }
            .padding(14)
            .background(FT.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(item.selected ? FT.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension UIImage {
    func resizedForScan(maxDimension: CGFloat = 1536) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - Sheets: AI Assistant

private struct AIAssistantSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @ObservedObject var aiManager: FinanceAIManager
    @Environment(\.dismiss) private var dismiss

    @State private var prompt = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(aiManager.messages) { msg in
                            AIBubble(message: msg)
                        }
                        if aiManager.isLoading {
                            TypingIndicator()
                                .padding(.leading, 16)
                        }
                    }
                    .padding(16)
                }

                if let err = aiManager.errorMessage {
                    Text(err).font(.system(size: 12)).foregroundStyle(.red)
                        .padding(.horizontal, 16)
                }

                HStack(spacing: 10) {
                    TextField("Ask about spending, budgets, savings…", text: $prompt, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(1...4)
                        .padding(12)
                        .background(FT.bg)
                        .clipShape(RoundedRectangle(cornerRadius: FT.innerR, style: .continuous))

                    Button {
                        let p = prompt; prompt = ""
                        Task { await aiManager.sendMessage(p, financeManager: financeManager) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(FT.green)
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiManager.isLoading)
                }
                .padding(16)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("AI Assistant")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { aiManager.resetConversation() }.foregroundStyle(FT.t2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .tint(FT.green)
        }
    }
}

private struct AIBubble: View {
    let message: AIChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                ZStack {
                    Circle().fill(FT.greenSub).frame(width: 28, height: 28)
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold)).foregroundStyle(FT.green)
                }
                Text(message.content)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(FT.t1)
                    .padding(12)
                    .background(FT.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .path(in: CGRect(origin: .zero, size: CGSize(width: 1000, height: 1000))))
                    .clipShape(BubbleShape(isUser: false))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                Text(message.content)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(FT.green)
                    .clipShape(BubbleShape(isUser: true))
                    .shadow(color: FT.green.opacity(0.3), radius: 6, x: 0, y: 2)
            }
        }
    }
}

private struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let _: CGFloat = 6 // tail offset (reserved)
        var p = Path()
        if isUser {
            p.addRoundedRect(in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height),
                             cornerSize: CGSize(width: r, height: r))
        } else {
            p.addRoundedRect(in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height),
                             cornerSize: CGSize(width: r, height: r))
        }
        return p
    }
}

private struct TypingIndicator: View {
    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(FT.t3)
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.3 : 0.9)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(FT.card)
        .clipShape(Capsule())
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// MARK: - Sheets: Budget Editor

private struct BudgetEditorSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @Environment(\.dismiss) private var dismiss

    @State private var budgetInput: String
    @State private var inlineError: String?

    init(financeManager: FinanceManager) {
        self.financeManager = financeManager
        _budgetInput = State(initialValue: financeManager.monthlyBudget
            .map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Budget") {
                    TextField("e.g. 3000", text: $budgetInput).keyboardType(.decimalPad)
                }
                if let inlineError {
                    Section { Text(inlineError).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.fontWeight(.bold) }
            }
            .tint(FT.green)
        }
    }

    private func save() {
        let t = budgetInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { financeManager.setMonthlyBudget(nil); dismiss(); return }
        guard let b = DecimalParser.parse(t), b > 0 else { inlineError = "Enter a valid amount."; return }
        financeManager.setMonthlyBudget(b); dismiss()
    }
}

// MARK: - Sheets: Edit Profile

private struct EditProfileSheet: View {
    @ObservedObject var financeManager: FinanceManager
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var email:       String
    @State private var errorMessage: String?

    init(financeManager: FinanceManager) {
        self.financeManager = financeManager
        _displayName = State(initialValue: financeManager.currentProfile.displayName)
        _email       = State(initialValue: financeManager.currentProfile.email)
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
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.fontWeight(.bold) }
            }
            .tint(FT.green)
        }
    }

    private func save() {
        let n = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { errorMessage = "Display name is required."; return }
        guard e.isValidEmail else { errorMessage = "Please enter a valid email."; return }
        financeManager.updateProfile(displayName: n, email: e)
        dismiss()
    }
}

// MARK: - Utilities

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
