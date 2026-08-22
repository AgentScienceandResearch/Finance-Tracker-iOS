import SwiftUI

enum AIWelcomePolicy {
    static func shouldPresent(userID: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: eligibilityKey(userID: userID))
            && !defaults.bool(forKey: completionKey(userID: userID))
    }

    static func markEligibleForNewAccount(userID: String, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: completionKey(userID: userID)) else { return }
        defaults.set(true, forKey: eligibilityKey(userID: userID))
    }

    static func markCompleted(userID: String, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: completionKey(userID: userID))
        defaults.removeObject(forKey: eligibilityKey(userID: userID))
    }

    private static func completionKey(userID: String) -> String {
        "aiWelcome.completed.\(userID)"
    }

    private static func eligibilityKey(userID: String) -> String {
        "aiWelcome.newAccountEligible.\(userID)"
    }
}

struct AIWelcomeView: View {
    let onTryAI: () -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var isAnimating = false

    private let features = [
        AIWelcomeFeature(
            icon: "bubble.left.and.text.bubble.right.fill",
            title: "Ask in your own words",
            detail: "Describe what you want done—no forms, menus, or finance jargon required."
        ),
        AIWelcomeFeature(
            icon: "wand.and.stars",
            title: "Handle the busywork",
            detail: "Create or edit transactions, budgets, income, and recurring bills across the app."
        ),
        AIWelcomeFeature(
            icon: "checkmark.shield.fill",
            title: "You stay in control",
            detail: "Finance AI prepares every change for your review and only applies what you approve."
        )
    ]

    var body: some View {
        ZStack {
            AIWelcomeTheme.background.ignoresSafeArea()

            backgroundGlow

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                        .padding(.top, 20)

                    VStack(spacing: 12) {
                        Text("MEET FINANCE AI")
                            .font(.caption.weight(.bold))
                            .tracking(1.8)
                            .foregroundStyle(AIWelcomeTheme.green)

                        Text("Your finances.\nOne conversation.")
                            .font(.largeTitle.weight(.heavy))
                            .tracking(-1.1)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)

                        Text("Turn everyday requests into real progress. Ask, review, and move your money forward.")
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.68))
                            .lineSpacing(4)
                            .padding(.horizontal, 10)
                    }
                    .padding(.top, 10)

                    exampleCard
                        .padding(.top, 28)

                    VStack(spacing: 12) {
                        ForEach(features) { feature in
                            AIWelcomeFeatureRow(feature: feature)
                        }
                    }
                    .padding(.top, 18)

                    Label("Nothing changes without your approval", systemImage: "lock.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.66))
                        .padding(.top, 22)
                        .padding(.bottom, 20)
                        .accessibilityLabel("Your finances stay protected. Nothing changes without your approval.")
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions
        }
        .onAppear {
            guard !accessibilityReduceMotion else { return }
            isAnimating = true
        }
        .preferredColorScheme(.dark)
    }

    private var backgroundGlow: some View {
        GeometryReader { proxy in
            Circle()
                .fill(AIWelcomeTheme.green.opacity(0.16))
                .frame(width: min(proxy.size.width * 1.25, 620))
                .blur(radius: 70)
                .offset(x: proxy.size.width * 0.35, y: -proxy.size.height * 0.12)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }

    private var hero: some View {
        ZStack {
            Circle()
                .stroke(AIWelcomeTheme.green.opacity(0.18), lineWidth: 1)
                .frame(width: 180, height: 180)
                .scaleEffect(isAnimating ? 1.06 : 0.96)

            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 1)
                .frame(width: 124, height: 124)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AIWelcomeTheme.green, AIWelcomeTheme.greenDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 86, height: 86)
                    .shadow(color: AIWelcomeTheme.green.opacity(0.42), radius: 28, y: 8)

                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AIWelcomeTheme.ink)
                    .scaleEffect(isAnimating ? 1.08 : 0.94)
            }

            AIWelcomeOrbitIcon(icon: "dollarsign.circle.fill")
                .offset(x: -82, y: -47)
            AIWelcomeOrbitIcon(icon: "chart.line.uptrend.xyaxis")
                .offset(x: 86, y: -34)
            AIWelcomeOrbitIcon(icon: "arrow.triangle.2.circlepath")
                .offset(x: 70, y: 65)
            AIWelcomeOrbitIcon(icon: "checkmark")
                .offset(x: -84, y: 58)
        }
        .frame(height: 196)
        .animation(
            accessibilityReduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Finance AI connects your transactions, trends, recurring bills, and approvals.")
    }

    private var exampleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AIWelcomeTheme.green)
                Text("TRY ASKING")
                    .font(.caption2.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.48))
            }

            Text("“Set my dining budget to $350 and pause my streaming bill.”")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    AIWelcomeResultChip(icon: "chart.pie.fill", text: "Budget ready")
                    AIWelcomeResultChip(icon: "pause.fill", text: "Bill paused")
                }

                VStack(alignment: .leading, spacing: 8) {
                    AIWelcomeResultChip(icon: "chart.pie.fill", text: "Budget ready")
                    AIWelcomeResultChip(icon: "pause.fill", text: "Bill paused")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onTryAI) {
                HStack(spacing: 9) {
                    Image(systemName: "sparkles")
                    Text("Try Finance AI")
                    Image(systemName: "arrow.right")
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(AIWelcomeTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .background(AIWelcomeTheme.green)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .shadow(color: AIWelcomeTheme.green.opacity(0.28), radius: 18, y: 8)
            }
            .buttonStyle(.plain)

            Button("Explore on my own", action: onContinue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private enum AIWelcomeTheme {
    static let green = Color(red: 0.25, green: 0.86, blue: 0.43)
    static let greenDeep = Color(red: 0.12, green: 0.63, blue: 0.29)
    static let background = Color(red: 0.035, green: 0.043, blue: 0.05)
    static let ink = Color(red: 0.025, green: 0.055, blue: 0.035)
}

private struct AIWelcomeFeature: Identifiable {
    let icon: String
    let title: String
    let detail: String

    var id: String { title }
}

private struct AIWelcomeFeatureRow: View {
    let feature: AIWelcomeFeature

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AIWelcomeTheme.green.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: feature.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AIWelcomeTheme.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AIWelcomeOrbitIcon: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white.opacity(0.82))
            .frame(width: 36, height: 36)
            .background(.white.opacity(0.10))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

private struct AIWelcomeResultChip: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(AIWelcomeTheme.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AIWelcomeTheme.green.opacity(0.10))
            .clipShape(Capsule())
    }
}

#if DEBUG
#Preview {
    AIWelcomeView(onTryAI: {}, onContinue: {})
}
#endif
