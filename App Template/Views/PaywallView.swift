import SwiftUI

// MARK: - Mode

enum PaywallMode: Equatable {
    case initial     // New account: 7-day trial offer, X to get 7 days free
    case yearlyHard  // After 7 days: yearly only, "Not Now" → monthlyHard
    case monthlyHard // Final fallback: monthly, no dismissal
}

// MARK: - Design tokens

private enum PW {
    static let green    = Color(red: 0.18, green: 0.72, blue: 0.34)
    static let greenSub = Color(red: 0.18, green: 0.72, blue: 0.34).opacity(0.08)
    static let bg       = Color(red: 0.961, green: 0.961, blue: 0.973)
    static let card     = Color.white
    static let t1       = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let t2       = Color(red: 0.50, green: 0.50, blue: 0.56)
    static let t3       = Color(red: 0.72, green: 0.72, blue: 0.76)
    static let r: CGFloat = 16
}

// MARK: - View

struct PaywallView: View {
    @StateObject private var flow: PaywallFlowViewModel
    private let startMode: PaywallMode
    let onDismiss: (() -> Void)?

    @State private var activeMode: PaywallMode
    @State private var showingMonthlyFromInitial = false

    init(subscriptionManager: SubscriptionManager, mode: PaywallMode, onDismiss: (() -> Void)? = nil) {
        _flow = StateObject(wrappedValue: PaywallFlowViewModel(subscriptionManager: subscriptionManager))
        startMode = mode
        _activeMode = State(initialValue: mode)
        self.onDismiss = onDismiss
    }

    init(flow: PaywallFlowViewModel, mode: PaywallMode = .initial, onDismiss: (() -> Void)? = nil) {
        _flow = StateObject(wrappedValue: flow)
        startMode = mode
        _activeMode = State(initialValue: mode)
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            PW.bg.ignoresSafeArea()
            switch activeMode {
            case .initial:
                initialFlow
            case .yearlyHard:
                hardPaywall(
                    plan: yearlyPlan,
                    headline: "Your free period has ended",
                    subhead: "Subscribe to keep your finances on track.",
                    ctaLabel: trialCTALabel(for: yearlyPlan),
                    notNowLabel: "See monthly plan",
                    onNotNow: { activeMode = .monthlyHard }
                )
            case .monthlyHard:
                hardPaywall(
                    plan: monthlyPlan,
                    headline: "Continue with Finance Tracker AI",
                    subhead: "Subscribe monthly to keep tracking.",
                    ctaLabel: "Subscribe Monthly",
                    notNowLabel: nil,
                    onNotNow: nil
                )
            }
        }
        .task { await flow.loadPlans() }
        .dynamicTypeSize(.xSmall ... .accessibility3)
    }

    // MARK: - Initial flow (NavigationStack so "See monthly" can push)

    private var initialFlow: some View {
        NavigationStack {
            initialYearlyContent
                .navigationDestination(isPresented: $showingMonthlyFromInitial) {
                    initialMonthlyContent
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { xButton }
                }
        }
    }

    private var initialYearlyContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                logoHeader(
                    badge: "7 DAYS FREE",
                    headline: "Try Finance Tracker AI free",
                    subhead: "Every feature, zero charge until your trial ends."
                )

                planCard(plan: yearlyPlan, isSelected: true)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                ctaButton(
                    label: trialCTALabel(for: yearlyPlan),
                    isLoading: flow.isPurchasing,
                    action: { Task { _ = await flow.purchaseSelectedPlan(yearlyPlan) } }
                )
                .padding(.horizontal, 24)

                chargeNote(for: yearlyPlan)

                statusMessage

                restoreButton
                    .padding(.top, 4)

                Divider()
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                Button { showingMonthlyFromInitial = true } label: {
                    Text("See monthly plan")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PW.t2)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)

                legalFooter
                    .padding(.top, 20)
            }
            .padding(.bottom, 40)
        }
        .background(PW.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var initialMonthlyContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                logoHeader(
                    badge: nil,
                    headline: "Monthly plan",
                    subhead: "Full access, billed each month."
                )

                planCard(plan: monthlyPlan, isSelected: true)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                ctaButton(
                    label: "Subscribe Monthly",
                    isLoading: flow.isPurchasing,
                    action: { Task { _ = await flow.purchaseSelectedPlan(monthlyPlan) } }
                )
                .padding(.horizontal, 24)

                chargeNote(for: monthlyPlan)

                statusMessage

                restoreButton
                    .padding(.top, 4)

                Button { showingMonthlyFromInitial = false } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back to yearly — save 40%")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(PW.green)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)

                legalFooter
                    .padding(.top, 20)
            }
            .padding(.bottom, 40)
        }
        .background(PW.bg.ignoresSafeArea())
        .navigationTitle("Monthly Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { xButton }
        }
    }

    // MARK: - Hard paywall (yearly or monthly, no X)

    private func hardPaywall(
        plan: SubscriptionPlan?,
        headline: String,
        subhead: String,
        ctaLabel: String,
        notNowLabel: String?,
        onNotNow: (() -> Void)?
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                logoHeader(badge: nil, headline: headline, subhead: subhead)

                if let plan {
                    planCard(plan: plan, isSelected: true)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    ctaButton(
                        label: ctaLabel,
                        isLoading: flow.isPurchasing,
                        action: { Task { _ = await flow.purchaseSelectedPlan(plan) } }
                    )
                    .padding(.horizontal, 24)

                    chargeNote(for: plan)
                } else {
                    loadingOrErrorState
                }

                statusMessage

                restoreButton
                    .padding(.top, 4)

                if let notNowLabel, let onNotNow {
                    Button(action: onNotNow) {
                        Text(notNowLabel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PW.t2)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                }

                legalFooter
                    .padding(.top, 20)
            }
            .padding(.bottom, 40)
        }
        .background(PW.bg.ignoresSafeArea())
    }

    // MARK: - Shared components

    private func logoHeader(badge: String?, headline: String, subhead: String) -> some View {
        VStack(spacing: 14) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: PW.green.opacity(0.22), radius: 12, x: 0, y: 6)
                .padding(.top, 48)

            if let badge {
                Text(badge)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(PW.green)
                    .clipShape(Capsule())
            }

            VStack(spacing: 6) {
                Text(headline)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(PW.t1)
                    .multilineTextAlignment(.center)

                Text(subhead)
                    .font(.system(size: 15))
                    .foregroundStyle(PW.t2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 28)
    }

    private func planCard(plan: SubscriptionPlan?, isSelected: Bool) -> some View {
        Group {
            if let plan {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(plan.billingPeriod.capitalized)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PW.t1)

                        if let trial = plan.trialDuration {
                            badge(text: "\(trial) free", color: PW.green)
                        }
                        if let savings = plan.savingsLabel {
                            badge(text: savings, color: Color(red: 0.2, green: 0.5, blue: 0.9))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(plan.displayPrice)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(PW.green)
                            if let perMonth = plan.pricePerMonth {
                                Text(perMonth)
                                    .font(.system(size: 12))
                                    .foregroundStyle(PW.t2)
                            }
                        }
                    }
                }
                .padding(18)
                .background(PW.card)
                .clipShape(RoundedRectangle(cornerRadius: PW.r, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PW.r, style: .continuous)
                        .strokeBorder(isSelected ? PW.green : PW.t3.opacity(0.3),
                                      lineWidth: isSelected ? 2 : 1)
                )
            } else {
                loadingOrErrorState
            }
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private func ctaButton(label: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(label)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(PW.green)
            .clipShape(RoundedRectangle(cornerRadius: PW.r, style: .continuous))
            .shadow(color: PW.green.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func chargeNote(for plan: SubscriptionPlan?) -> some View {
        Group {
            if let plan {
                let note: String = {
                    if let trial = plan.trialDuration {
                        return "Free for \(trial), then \(plan.displayPrice)/\(plan.billingPeriod). Cancel anytime."
                    }
                    return "\(plan.displayPrice)/\(plan.billingPeriod). Cancel anytime."
                }()
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(PW.t2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
            }
        }
    }

    private var statusMessage: some View {
        Group {
            if let msg = flow.statusMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
    }

    private var restoreButton: some View {
        Button { Task { await flow.restorePurchases() } } label: {
            Text("Restore Previous Purchase")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PW.green)
        }
        .buttonStyle(.plain)
    }

    private var xButton: some View {
        Button {
            onDismiss?()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PW.t2)
                .padding(8)
                .background(PW.t3.opacity(0.18))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var legalFooter: some View {
        VStack(spacing: 6) {
            Text("Cancel anytime in App Store Settings. Subscription auto-renews unless cancelled at least 24 hours before the end of the current period.")
                .font(.system(size: 11))
                .foregroundStyle(PW.t3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            HStack(spacing: 4) {
                Text("By subscribing you agree to our")
                Link("Privacy Policy", destination: URL(string: "https://github.com/AgentScienceandResearch/Finance-Tracker-iOS/blob/main/PRIVACY_POLICY.md")!)
                    .foregroundStyle(PW.green)
            }
            .font(.system(size: 11))
            .foregroundStyle(PW.t3)
        }
    }

    private var loadingOrErrorState: some View {
        VStack(spacing: 10) {
            if flow.isLoading {
                ProgressView().tint(PW.green)
                Text("Loading plans…")
                    .font(.system(size: 14))
                    .foregroundStyle(PW.t2)
            } else {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(PW.t3)
                Text(flow.loadError ?? "Couldn't load plans. Please try again.")
                    .font(.system(size: 14))
                    .foregroundStyle(PW.t2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    // MARK: - Helpers

    private var yearlyPlan: SubscriptionPlan? {
        flow.plans.first { $0.id == SubscriptionManager.yearlyProductID }
    }

    private var monthlyPlan: SubscriptionPlan? {
        flow.plans.first { $0.id == SubscriptionManager.monthlyProductID }
    }

    private func trialCTALabel(for plan: SubscriptionPlan?) -> String {
        if let trial = plan?.trialDuration { return "Start Free Trial — \(trial) free" }
        return "Subscribe Now"
    }
}

// MARK: - PaywallFlowViewModel extension

private extension PaywallFlowViewModel {
    @discardableResult
    func purchaseSelectedPlan(_ plan: SubscriptionPlan?) async -> Bool {
        guard let plan else { return false }
        selectPlan(plan.id)
        return await purchaseSelectedPlan()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Initial — Trial") {
    PaywallView(flow: PaywallPreviewFixtures.loadedFlow(), mode: .initial, onDismiss: {})
}
#Preview("Yearly Hard") {
    PaywallView(flow: PaywallPreviewFixtures.loadedFlow(), mode: .yearlyHard)
}
#Preview("Monthly Hard") {
    PaywallView(flow: PaywallPreviewFixtures.loadedFlow(), mode: .monthlyHard)
}
#Preview("Loading") {
    PaywallView(flow: PaywallPreviewFixtures.loadingFlow(), mode: .initial, onDismiss: {})
}
#endif
