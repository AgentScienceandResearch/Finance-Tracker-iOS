import SwiftUI
import AuthenticationServices

// MARK: - Design tokens (mirrors MainTabView's FT namespace)
private enum AT {
    static let green     = Color(red: 0.18, green: 0.72, blue: 0.34)
    static let greenMid  = Color(red: 0.18, green: 0.72, blue: 0.34).opacity(0.14)
    static let bg        = Color(red: 0.961, green: 0.961, blue: 0.973)
    static let card      = Color.white
    static let t1        = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let t2        = Color(red: 0.50, green: 0.50, blue: 0.56)
    static let t3        = Color(red: 0.72, green: 0.72, blue: 0.76)
    static let cardR: CGFloat = 20
    static let fieldR: CGFloat = 14
}

// MARK: - Root View

struct AuthenticationView: View {
    @StateObject private var flow: AuthenticationFlowViewModel
    private let authManager: AuthenticationManager

    @State private var appleError: String?
    @State private var isGoogleLoading = false

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        self._flow = StateObject(wrappedValue: AuthenticationFlowViewModel(authManager: authManager))
    }

    private var displayError: String? { flow.inlineError ?? appleError ?? authManager.errorMessage }

    var body: some View {
        ZStack {
            AT.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    formCard
                        .padding(.horizontal, 20)
                        .padding(.top, -28)
                    Spacer(minLength: 40)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [AT.green, AT.green.opacity(0.78)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 240)
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)

                VStack(spacing: 4) {
                    Text("Finance Tracker")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(.white)
                        .tracking(-0.4)
                    Text(flow.isSignUp ? "Create your account" : "Welcome back")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.80))
                }
            }
            .padding(.bottom, 44)
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 20) {

            // ── Error banner ──────────────────────────────────────
            if let err = displayError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(err)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AT.t1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AT.fieldR, style: .continuous))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Email ─────────────────────────────────────────────
            AuthField(label: "Email", icon: "envelope.fill", text: $flow.email) {
                TextField("", text: $flow.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            // ── Display name (sign-up only) ────────────────────────
            if flow.isSignUp {
                AuthField(label: "Display Name", icon: "person.fill", text: $flow.displayName) {
                    TextField("", text: $flow.displayName)
                        .textContentType(.name)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Password ──────────────────────────────────────────
            AuthField(label: "Password", icon: "lock.fill", text: $flow.password) {
                SecureField("", text: $flow.password)
                    .textContentType(flow.isSignUp ? .newPassword : .password)
            }

            // ── Primary button ────────────────────────────────────
            Button {
                Task { await flow.submit() }
            } label: {
                ZStack {
                    if flow.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(flow.isSignUp ? "Create Account" : "Sign In")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    flow.canSubmit
                        ? AT.green
                        : AT.green.opacity(0.45)
                )
                .clipShape(RoundedRectangle(cornerRadius: AT.fieldR, style: .continuous))
                .shadow(color: AT.green.opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .disabled(flow.isSubmitting || !flow.canSubmit)
            .buttonStyle(.plain)

            // ── Divider ───────────────────────────────────────────
            HStack(spacing: 12) {
                Rectangle().fill(AT.t3).frame(height: 1)
                Text("or continue with")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AT.t3)
                    .fixedSize()
                Rectangle().fill(AT.t3).frame(height: 1)
            }

            // ── Social sign-in ────────────────────────────────────
            VStack(spacing: 12) {
                GoogleSignInButton(isLoading: isGoogleLoading) {
                    Task {
                        isGoogleLoading = true
                        await authManager.signInWithGoogle()
                        isGoogleLoading = false
                    }
                }

                AppleSignInButton { result, rawNonce in
                    Task {
                        switch result {
                        case .success(let auth):
                            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else {
                                appleError = "Apple Sign In returned an invalid credential."
                                return
                            }
                            guard let rawNonce else {
                                appleError = "Apple Sign In could not create a secure request. Please try again."
                                return
                            }
                            await authManager.signInWithApple(credentials: cred, rawNonce: rawNonce)
                        case .failure(let err):
                            let authorizationError = err as? ASAuthorizationError
                            if authorizationError?.code != .canceled {
                                appleError = "Apple Sign In failed. Please try again."
                            }
                        }
                    }
                }
            }

            // ── Toggle sign-in / sign-up ──────────────────────────
            Button {
                withAnimation(.spring(response: 0.35)) {
                    appleError = nil
                    flow.toggleMode()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(flow.isSignUp ? "Already have an account?" : "Don't have an account?")
                        .font(.system(size: 14))
                        .foregroundStyle(AT.t2)
                    Text(flow.isSignUp ? "Sign In" : "Sign Up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AT.green)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(24)
        .background(AT.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        .animation(.spring(response: 0.35), value: flow.isSignUp)
        .animation(.spring(response: 0.35), value: displayError)
    }
}

// MARK: - Auth Field

private struct AuthField<Field: View>: View {
    let label: String
    let icon: String
    @Binding var text: String
    @ViewBuilder let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AT.t2)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AT.green)
                    .frame(width: 18)

                field
                    .font(.system(size: 15))
                    .foregroundStyle(AT.t1)
                    .tint(AT.green)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(AT.bg)
            .clipShape(RoundedRectangle(cornerRadius: AT.fieldR, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AT.fieldR, style: .continuous)
                    .strokeBorder(
                        text.isEmpty ? Color.clear : AT.green.opacity(0.35),
                        lineWidth: 1.5
                    )
            )
        }
    }
}

// MARK: - Google Sign In Button

private struct GoogleSignInButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else {
                    GoogleGLogo()
                        .frame(width: 20, height: 20)
                }

                Text(isLoading ? "Signing in…" : "Sign in with Google")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.20))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AT.fieldR, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AT.fieldR, style: .continuous)
                    .strokeBorder(Color(red: 0.78, green: 0.78, blue: 0.78), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// Minimal SVG-accurate Google "G" rendered in SwiftUI
private struct GoogleGLogo: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            let r = s / 2
            let cx = r
            let cy = r

            // Blue arc top-right
            drawArc(ctx: ctx, cx: cx, cy: cy, r: r,
                    from: -16, to: 90, color: Color(red: 0.26, green: 0.52, blue: 0.96))
            // Red arc top-left
            drawArc(ctx: ctx, cx: cx, cy: cy, r: r,
                    from: 90, to: 196, color: Color(red: 0.91, green: 0.26, blue: 0.21))
            // Yellow arc bottom-left
            drawArc(ctx: ctx, cx: cx, cy: cy, r: r,
                    from: 196, to: 280, color: Color(red: 0.99, green: 0.73, blue: 0.01))
            // Green arc bottom-right
            drawArc(ctx: ctx, cx: cx, cy: cy, r: r,
                    from: 280, to: 344, color: Color(red: 0.20, green: 0.66, blue: 0.33))

            // White cutout circle (inner ring)
            let inner = r * 0.58
            var hole = Path()
            hole.addEllipse(in: CGRect(x: cx - inner, y: cy - inner,
                                       width: inner * 2, height: inner * 2))
            ctx.fill(hole, with: .color(.white))

            // Blue horizontal bar (the crossbar of the G)
            let barH = r * 0.30
            let barY = cy - barH / 2
            let barX = cx
            var bar = Path()
            bar.addRoundedRect(
                in: CGRect(x: barX, y: barY, width: r * 0.95, height: barH),
                cornerSize: CGSize(width: barH / 2, height: barH / 2)
            )
            ctx.fill(bar, with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))
        }
    }

    private func drawArc(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat,
                         from: Double, to: Double, color: Color) {
        let thickness = r * 0.38
        var path = Path()
        path.addArc(center: CGPoint(x: cx, y: cy), radius: r - thickness / 2,
                    startAngle: .degrees(from), endAngle: .degrees(to), clockwise: false)
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
    }
}

// MARK: - Apple Sign In Button

private struct AppleSignInButton: View {
    let onCompletion: (Result<ASAuthorization, Error>, String?) -> Void
    @State private var currentNonce: String?

    var body: some View {
        SignInWithAppleButton(
            onRequest: { request in
                let nonce = AppleSignInNonce.generate()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                if let nonce {
                    request.nonce = AppleSignInNonce.hash(nonce)
                }
            },
            onCompletion: { result in
                let nonce = currentNonce
                currentNonce = nil
                onCompletion(result, nonce)
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: AT.fieldR, style: .continuous))
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Sign In") {
    AuthenticationView(authManager: AuthenticationManager())
}

#Preview("Sign Up") {
    let auth = AuthenticationManager()
    let view = AuthenticationView(authManager: auth)
    return view
}
#endif
