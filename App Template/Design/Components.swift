import SwiftUI

// MARK: - Advanced Liquid Glass Card
struct GlassCard<Content: View>: View {
    let content: Content
    var intensity: Double = 0.25
    var glowColor: Color = .cyan
    var glowIntensity: Double = 0.0

    init(
        intensity: Double = 0.25,
        glowColor: Color = .cyan,
        glowIntensity: Double = 0.0,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.intensity = intensity
        self.glowColor = glowColor
        self.glowIntensity = glowIntensity
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(intensity))
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            // Enhanced glowing border
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                glowColor.opacity(0.6 + glowIntensity),
                                glowColor.opacity(0.2 + glowIntensity),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            // Outer glow effect
            .shadow(color: glowColor.opacity(0.4 * glowIntensity), radius: 12, x: 0, y: 0)
            // Drop shadow
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Floating Glass Card with Elevation
struct FloatingGlassCard<Content: View>: View {
    let content: Content
    var elevation: CGFloat = 10
    var glowColor: Color = .cyan

    init(
        elevation: CGFloat = 10,
        glowColor: Color = .cyan,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.elevation = elevation
        self.glowColor = glowColor
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.08)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.5),
                                glowColor.opacity(0.3),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            // Multi-layer shadow for elevation
            .shadow(color: glowColor.opacity(0.3), radius: 15, x: 0, y: 5)
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: elevation)
            .shadow(color: Color.black.opacity(0.1), radius: 50, x: 0, y: elevation * 1.5)
    }
}

// MARK: - Hazy Overlay Card (Half-Revealed)
struct HazyOverlayCard<Background: View, Content: View>: View {
    @ViewBuilder let background: Background
    @ViewBuilder let content: Content
    var blurRadius: CGFloat = 15
    var overlayOpacity: Double = 0.75
    
    var body: some View {
        ZStack {
            // Blurred background
            background
                .blur(radius: blurRadius)
                .opacity(0.4)
            
            // Semi-transparent overlay
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(overlayOpacity),
                            Color.black.opacity(overlayOpacity * 0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Glass border
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.cyan.opacity(0.2),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
            
            // Content
            content
                .padding(20)
        }
        .frame(height: 200)
        .shadow(color: Color.black.opacity(0.3), radius: 25, x: 0, y: 15)
    }
}

// MARK: - Glowing Border Card
struct GlowingBorderCard<Content: View>: View {
    let content: Content
    var glowColor: Color = .cyan
    var glowRadius: CGFloat = 20
    @State private var glowIntensity: Double = 0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        glowColor: Color = .cyan,
        glowRadius: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.glowColor = glowColor
        self.glowRadius = glowRadius
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.15))
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                glowColor.opacity(glowIntensity),
                                glowColor.opacity(glowIntensity * 0.5),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: glowColor.opacity(glowIntensity * 0.8), radius: glowRadius, x: 0, y: 0)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .onAppear {
                if reduceMotion {
                    glowIntensity = 0.7
                } else {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        glowIntensity = 1.0
                    }
                }
            }
    }
}

// MARK: - Animated Background with Gradient
struct AnimatedGradientBackground: View {
    @State private var animateOrbA = false
    @State private var animateOrbB = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.background
                
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                AppTheme.accentSecondary.opacity(0.38),
                                AppTheme.accentSecondary.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 10,
                            endRadius: proxy.size.width * 0.58
                        )
                    )
                    .frame(width: proxy.size.width * 1.15, height: proxy.size.width * 1.15)
                    .offset(
                        x: animateOrbA ? proxy.size.width * 0.25 : -proxy.size.width * 0.3,
                        y: animateOrbA ? -proxy.size.height * 0.1 : -proxy.size.height * 0.3
                    )
                    .blur(radius: 18)
                
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                AppTheme.accent.opacity(0.34),
                                AppTheme.accent.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 10,
                            endRadius: proxy.size.width * 0.62
                        )
                    )
                    .frame(width: proxy.size.width * 1.25, height: proxy.size.width * 1.25)
                    .offset(
                        x: animateOrbB ? -proxy.size.width * 0.35 : proxy.size.width * 0.2,
                        y: animateOrbB ? proxy.size.height * 0.22 : proxy.size.height * 0.45
                    )
                    .blur(radius: 26)
                
                Rectangle()
                    .fill(Color.white.opacity(0.08))
            }
            .ignoresSafeArea()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    animateOrbA.toggle()
                }
                withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                    animateOrbB.toggle()
                }
            }
        }
    }
}

// MARK: - Frosted Glass Effect Button
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardGradient)
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        AppTheme.cardStroke,
                        lineWidth: 1.5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.glassSpecular.opacity(0.25))
                    .blendMode(.screen)
                    .padding(1)
            )
            .shadow(color: AppTheme.accentSecondary.opacity(0.12), radius: 14, x: 0, y: 6)
            .overlay(
                isLoading ? AnyView(
                    ProgressView()
                        .tint(.white)
                ) : AnyView(EmptyView())
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
    }
}

// MARK: - Animated Gradient Text
struct GradientText: View {
    let text: String
    let gradient: LinearGradient
    var font: Font = .system(size: 28, weight: .bold, design: .rounded)
    
    var body: some View {
        Text(text)
            .font(font)
            .overlay(gradient)
            .mask(Text(text).font(font))
    }
}

// MARK: - Floating Particle Background
struct ParticleBackgroundView: View {
    @State private var particles: [Particle] = []
    @State private var particleTimer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Canvas { context, size in
            for particle in particles {
                let path = Path(ellipseIn: CGRect(
                    x: particle.position.x,
                    y: particle.position.y,
                    width: particle.size,
                    height: particle.size
                ))
                context.fill(
                    path,
                    with: .color(Color.white.opacity(particle.opacity))
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            generateParticles()
            animateParticles()
        }
        .onDisappear {
            particleTimer?.invalidate()
            particleTimer = nil
        }
    }
    
    private func generateParticles() {
        particles = (0..<20).map { _ in
            Particle(
                position: CGPoint(x: CGFloat.random(in: 0...400), y: CGFloat.random(in: 0...800)),
                size: CGFloat.random(in: 1...4),
                opacity: Double.random(in: 0.1...0.3)
            )
        }
    }
    
    private func animateParticles() {
        particleTimer?.invalidate()
        particleTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear) {
                particles.indices.forEach { i in
                    particles[i].position.y -= 1
                    if particles[i].position.y < 0 {
                        particles[i].position = CGPoint(
                            x: CGFloat.random(in: 0...400),
                            y: 800
                        )
                    }
                }
            }
        }
    }
}

struct Particle {
    var position: CGPoint
    let size: CGFloat
    let opacity: Double
}

// MARK: - Section Header with Accent
struct SectionHeaderView: View {
    let title: String
    let subtitle: String?
    var accentColor: Color = .cyan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accentColor)
                    .frame(width: 4, height: 24)
                
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Blur Effect
struct BlurEffect: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Backdrop Blur Overlay
struct BackdropBlur<Content: View>: View {
    @ViewBuilder let content: Content
    var blurRadius: CGFloat = 10
    
    var body: some View {
        ZStack {
            BlurEffect(style: .systemChromeMaterialDark)
                .opacity(0.6)
            
            content
        }
    }
}

// MARK: - Animated Glass Button
struct AnimatedGlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading = false
    @State private var glowOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.26),
                                AppTheme.accentSecondary.opacity(0.14)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        AppTheme.cardStroke,
                        lineWidth: 1.5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.glassSpecular.opacity(0.24))
                    .blendMode(.screen)
                    .padding(1)
            )
            .shadow(color: AppTheme.accentSecondary.opacity(glowOpacity), radius: 14, x: 0, y: 0)
            .shadow(color: AppTheme.deepShadow.opacity(0.8), radius: 16, x: 0, y: 8)
            .overlay(
                isLoading ? AnyView(
                    ProgressView()
                        .tint(.white)
                ) : AnyView(EmptyView())
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
        .onAppear {
            if reduceMotion {
                glowOpacity = 0.25
            } else {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.58
                }
            }
        }
    }
}

// MARK: - Floating Glass Button
struct FloatingGlassButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .frame(width: 70, height: 70)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.12)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.5),
                                Color.cyan.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.cyan.opacity(0.4), radius: 15, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 12)
        }
    }
}

// MARK: - Liquid Glass Surface Modifier
struct LiquidGlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 20
    var baseOpacity: Double = 0.24
    var strokeWidth: CGFloat = 1.0
    var glowColor: Color = AppTheme.accentSecondary
    var glowStrength: Double = 0.08
    var showSheen: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sheenPhase: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(baseOpacity))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: strokeWidth)
            )
            .overlay {
                if showSheen {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppTheme.glassSheen.opacity(reduceMotion ? 0.14 : 0.32))
                            .frame(width: proxy.size.width * 0.52)
                            .blur(radius: 16)
                            .rotationEffect(.degrees(18))
                            .offset(x: proxy.size.width * sheenPhase)
                            .blendMode(.screen)
                            .mask(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            )
                            .allowsHitTesting(false)
                    }
                }
            }
            .shadow(color: AppTheme.deepShadow, radius: 22, x: 0, y: 12)
            .shadow(color: glowColor.opacity(glowStrength), radius: 24, x: 0, y: 10)
            .onAppear {
                guard showSheen else { return }
                if reduceMotion {
                    sheenPhase = 0.05
                } else {
                    sheenPhase = -1.2
                    withAnimation(.linear(duration: 4.4).repeatForever(autoreverses: false)) {
                        sheenPhase = 1.35
                    }
                }
            }
    }
}

// MARK: - Pressed Button Animation
struct GlassPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    var pressedOpacity: Double = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func glass(intensity: Double = 0.3) -> some View {
        modifier(GlassEffect(intensity: intensity))
    }
    
    func glassBackground() -> some View {
        background(
            ZStack {
                AnimatedGradientBackground()
                BlurEffect(style: .dark)
                    .opacity(0.2)
            }
            .ignoresSafeArea()
        )
    }
    
    func liquidGlossOverlay(
        _ show: Bool,
        glowColor: Color = .cyan,
        animation: Animation = .easeInOut(duration: 0.3)
    ) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            glowColor.opacity(show ? 0.8 : 0),
                            glowColor.opacity(show ? 0.4 : 0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .shadow(color: glowColor.opacity(show ? 0.6 : 0), radius: 15, x: 0, y: 0)
                .animation(animation, value: show)
        )
    }

    func liquidGlassSurface(
        cornerRadius: CGFloat = 20,
        baseOpacity: Double = 0.24,
        strokeWidth: CGFloat = 1.0,
        glowColor: Color = AppTheme.accentSecondary,
        glowStrength: Double = 0.08,
        showSheen: Bool = true
    ) -> some View {
        modifier(
            LiquidGlassSurface(
                cornerRadius: cornerRadius,
                baseOpacity: baseOpacity,
                strokeWidth: strokeWidth,
                glowColor: glowColor,
                glowStrength: glowStrength,
                showSheen: showSheen
            )
        )
    }
}

// MARK: - Glass Effect Modifier
struct GlassEffect: ViewModifier {
    var intensity: Double = 0.3
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(intensity))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.05))
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AnimatedGradientBackground()
        
        VStack(spacing: 20) {
            GradientText(
                text: "Premium",
                gradient: LinearGradient(
                    gradient: Gradient(colors: [.cyan, .blue, .purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            FloatingGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Liquid Glass Design")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Cutting-edge glassmorphism")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            
            HazyOverlayCard(
                background: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.cyan)
                },
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hazy Overlay Effect")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Modern & elegant")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                }
            )
            
            AnimatedGlassButton(title: "Get Started", icon: "play.fill") {
                print("Pressed")
            }
            
            Spacer()
        }
        .padding()
    }
}
