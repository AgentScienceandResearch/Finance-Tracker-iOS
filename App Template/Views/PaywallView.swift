import SwiftUI

struct PaywallView: View {
    @StateObject private var flow: PaywallFlowViewModel
    private let shouldAutoLoad: Bool

    init(subscriptionManager: SubscriptionManager) {
        self._flow = StateObject(wrappedValue: PaywallFlowViewModel(subscriptionManager: subscriptionManager))
        self.shouldAutoLoad = true
    }

    init(flow: PaywallFlowViewModel, shouldAutoLoad: Bool = false) {
        self._flow = StateObject(wrappedValue: flow)
        self.shouldAutoLoad = shouldAutoLoad
    }

    var body: some View {
        ZStack {
            AnimatedGradientBackground()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unlock Premium")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Get unlimited access to all features")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)

                // Features List
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(
                            title: "Premium Features",
                            subtitle: "Everything you need",
                            accentColor: .cyan
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)

                        VStack(spacing: 12) {
                            FeatureRow(icon: "infinity", text: "Unlimited access")
                            FeatureRow(icon: "bolt.fill", text: "Priority support")
                            FeatureRow(icon: "star.fill", text: "Exclusive features")
                            FeatureRow(icon: "checkmark.circle.fill", text: "Ad-free experience")
                            FeatureRow(icon: "sparkles", text: "Premium content")
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)

                        // Subscription Options
                        SectionHeaderView(
                            title: "Choose Your Plan",
                            subtitle: "Cancel anytime",
                            accentColor: .purple
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 8)

                        if flow.plans.isEmpty {
                            VStack(spacing: 12) {
                                if flow.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.orange)
                                }

                                Text(flow.isLoading ? "Loading plans" : "Products not loading")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)

                                Text(flow.loadError ?? "Please try again later")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(flow.plans) { plan in
                                    SubscriptionPlanOptionCard(
                                        plan: plan,
                                        isSelected: flow.selectedPlanID == plan.id,
                                        onSelect: { flow.selectPlan(plan.id) }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        if let statusMessage = flow.statusMessage {
                            Text(statusMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 24)
                        }

                        // Purchase Button
                        if flow.selectedPlanID != nil {
                            GlassButton(
                                title: "Subscribe Now",
                                icon: "creditcard.fill",
                                action: {
                                    Task {
                                        _ = await flow.purchaseSelectedPlan()
                                    }
                                },
                                isLoading: flow.isPurchasing
                            )
                            .padding(24)
                        }

                        // Restore Button
                        Button(action: {
                            Task {
                                await flow.restorePurchases()
                            }
                        }) {
                            Text("Restore Previous Purchase")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundStyle(.cyan)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                        // Terms
                        VStack(spacing: 8) {
                            Text("Subscription Details")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.gray)

                            HStack(spacing: 4) {
                                Text("By subscribing, you agree to our")
                                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                                    .foregroundStyle(.cyan)
                                Text("and")
                                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                                    .foregroundStyle(.cyan)
                            }
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.gray)
                            .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .task {
            if shouldAutoLoad {
                await flow.loadPlans()
            }
        }
        .dynamicTypeSize(.xSmall ... .accessibility3)
    }
}

// MARK: - Subscription Option Card
struct SubscriptionPlanOptionCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.billingPeriod)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    if let pricePerMonth = plan.pricePerMonth {
                        Text(pricePerMonth)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.gray)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.displayPrice)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.cyan)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isSelected ? 0.15 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.cyan.opacity(isSelected ? 0.8 : 0.2),
                            Color.cyan.opacity(isSelected ? 0.4 : 0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.title), \(plan.displayPrice)")
        .accessibilityHint(isSelected ? "Selected plan" : "Double-tap to select this plan")
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(.white)

            Spacer()
        }
    }
}

#if DEBUG
#Preview("Paywall - Loaded") {
    PaywallView(flow: PaywallPreviewFixtures.loadedFlow())
}

#Preview("Paywall - Loading") {
    PaywallView(flow: PaywallPreviewFixtures.loadingFlow())
}

#Preview("Paywall - Error") {
    PaywallView(flow: PaywallPreviewFixtures.errorFlow())
}
#endif
