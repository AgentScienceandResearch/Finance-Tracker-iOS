import SwiftUI

/// Advanced showcase of cutting-edge glassmorphism design patterns from modern apps like Grok
struct GlassmorphismShowcaseView: View {
    @State private var selectedCard: Int? = nil
    @State private var animateCards = false
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            ParticleBackgroundView()
            
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cutting-Edge Design")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Liquid glass & modern effects")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // MARK: - Example 1: Floating Glass Card
                        SectionHeaderView(
                            title: "Floating Cards",
                            subtitle: "With elevation & depth",
                            accentColor: .cyan
                        )
                        .padding(.horizontal, 24)
                        
                        FloatingGlassCard {
                            HStack(spacing: 16) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.cyan)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Premium Feature")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Unlock now to explore")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .padding(.horizontal, 24)
                        .scaleEffect(animateCards ? 1.0 : 0.95)
                        
                        // MARK: - Example 2: Hazy Overlay Card
                        SectionHeaderView(
                            title: "Hazy Overlays",
                            subtitle: "Half-revealed content",
                            accentColor: .purple
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        HazyOverlayCard(
                            background: {
                                Image(systemName: "globe.asia.australia")
                                    .font(.system(size: 100))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.cyan, .blue, .purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            },
                            content: {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.cyan)
                                            .frame(width: 8, height: 8)
                                        
                                        Text("New Discovery")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.cyan)
                                    }
                                    
                                    Text("\"The void isn't empty — it's listening. What are you ready to become?\"")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 12) {
                                        Button(action: {}) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "heart")
                                                    .font(.system(size: 12))
                                                Text("Like")
                                                    .font(.system(size: 12, weight: .semibold))
                                            }
                                            .foregroundStyle(.white)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(Color.white.opacity(0.15))
                                            .mask(RoundedRectangle(cornerRadius: 8))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "bookmark")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.cyan)
                                    }
                                }
                            }
                        )
                        .padding(.horizontal, 24)
                        
                        // MARK: - Example 3: Glowing Border Card
                        SectionHeaderView(
                            title: "Animated Glows",
                            subtitle: "Pulsing neon borders",
                            accentColor: .orange
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        GlowingBorderCard(glowColor: .orange) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.orange)
                                    
                                    Text("Lightning Fast")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                }
                                
                                Text("Experience ultra-responsive performance with optimized rendering")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.gray)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // MARK: - Example 4: Multiple Floating Cards
                        SectionHeaderView(
                            title: "Card Grid",
                            subtitle: "Multi-effect composition",
                            accentColor: .pink
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                FloatingGlassCard(glowColor: .cyan) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Image(systemName: "bolt.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.cyan)
                                        
                                        Text("Speed")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                
                                FloatingGlassCard(glowColor: .purple) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Image(systemName: "star.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.purple)
                                        
                                        Text("Premium")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            
                            HStack(spacing: 12) {
                                FloatingGlassCard(glowColor: .green) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Image(systemName: "lock.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.green)
                                        
                                        Text("Secure")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                
                                FloatingGlassCard(glowColor: .red) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Image(systemName: "flame.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.red)
                                        
                                        Text("Trending")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // MARK: - Example 5: Button Showcase
                        SectionHeaderView(
                            title: "Interactive Buttons",
                            subtitle: "Animated glass buttons",
                            accentColor: .cyan
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        VStack(spacing: 12) {
                            AnimatedGlassButton(
                                title: "Explore Features",
                                icon: "sparkles"
                            ) {}
                            
                            HStack(spacing: 12) {
                                FloatingGlassButton(title: "Save", icon: "bookmark.fill") {}
                                FloatingGlassButton(title: "Share", icon: "square.and.arrow.up") {}
                                FloatingGlassButton(title: "More", icon: "ellipsis") {}
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                animateCards = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    GlassmorphismShowcaseView()
}
