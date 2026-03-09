import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @StateObject private var flow: AuthenticationFlowViewModel
    private let appleSignInAction: ((ASAuthorizationAppleIDCredential) async -> Void)?
    @State private var appleErrorMessage: String?

    init(authManager: AuthenticationManager) {
        self._flow = StateObject(wrappedValue: AuthenticationFlowViewModel(authManager: authManager))
        self.appleSignInAction = { credentials in
            await authManager.signInWithApple(credentials: credentials)
        }
    }

    init(
        flow: AuthenticationFlowViewModel,
        appleSignInAction: ((ASAuthorizationAppleIDCredential) async -> Void)? = nil
    ) {
        self._flow = StateObject(wrappedValue: flow)
        self.appleSignInAction = appleSignInAction
    }

    private var displayError: String? {
        flow.inlineError ?? appleErrorMessage
    }

    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            ParticleBackgroundView()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    GradientText(
                        text: "Welcome",
                        gradient: LinearGradient(
                            gradient: Gradient(colors: [.cyan, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        font: .system(size: 32, weight: .bold, design: .rounded)
                    )

                    Text(flow.isSignUp ? "Create your account" : "Sign in to continue")
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 40)

                // Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundStyle(.white)

                            TextField("", text: $flow.email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .accessibilityLabel("Email")
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .foregroundStyle(.white)
                        }

                        // Display Name (Sign Up only)
                        if flow.isSignUp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name")
                                    .font(.system(size: 14, weight: .semibold, design: .default))
                                    .foregroundStyle(.white)

                                TextField("", text: $flow.displayName)
                                    .textContentType(.name)
                                    .accessibilityLabel("Display name")
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                    )
                                    .foregroundStyle(.white)
                            }
                        }

                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundStyle(.white)

                            SecureField("", text: $flow.password)
                                .textContentType(flow.isSignUp ? .newPassword : .password)
                                .accessibilityLabel("Password")
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .foregroundStyle(.white)
                        }

                        // Error Message
                        if let error = displayError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(error)
                                    .font(.system(size: 12, weight: .regular))
                            }
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }

                        // Sign In / Sign Up Button
                        GlassButton(
                            title: flow.isSignUp ? "Create Account" : "Sign In",
                            icon: flow.isSignUp ? "person.badge.plus" : "arrow.right",
                            action: {
                                Task {
                                    _ = await flow.submit()
                                }
                            },
                            isLoading: flow.isSubmitting
                        )
                        .disabled(flow.isSubmitting || !flow.canSubmit)

                        // Divider
                        HStack(spacing: 12) {
                            Divider()
                                .frame(height: 1)
                                .background(Color.white.opacity(0.2))
                            Text("OR")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.gray)
                            Divider()
                                .frame(height: 1)
                                .background(Color.white.opacity(0.2))
                        }
                        .padding(.vertical, 16)

                        // Sign in with Apple
                        SignInWithAppleButton(
                            onRequest: { _ in },
                            onCompletion: { result in
                                Task {
                                    switch result {
                                    case .success(let authorization):
                                        guard let credentials = authorization.credential as? ASAuthorizationAppleIDCredential,
                                              let appleSignInAction else {
                                            return
                                        }
                                        await appleSignInAction(credentials)
                                    case .failure(let error):
                                        appleErrorMessage = error.localizedDescription
                                    }
                                }
                            }
                        )
                        .frame(height: 50)
                        .signInWithAppleButtonStyle(.white)

                        // Toggle Sign Up / Sign In
                        HStack(spacing: 4) {
                            Text(flow.isSignUp ? "Already have an account?" : "Don't have an account?")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.gray)

                            Button(action: {
                                appleErrorMessage = nil
                                flow.toggleMode()
                            }) {
                                Text(flow.isSignUp ? "Sign In" : "Sign Up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
        .dynamicTypeSize(.xSmall ... .accessibility3)
    }
}

#if DEBUG
#Preview("Auth - Sign In") {
    AuthenticationView(flow: AuthenticationPreviewFixtures.signInFlow())
}

#Preview("Auth - Sign Up Error") {
    AuthenticationView(flow: AuthenticationPreviewFixtures.signUpErrorFlow())
}

#Preview("Auth - Submitting") {
    AuthenticationView(flow: AuthenticationPreviewFixtures.submittingFlow())
}
#endif
