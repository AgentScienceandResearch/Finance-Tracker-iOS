# Glassmorphism Design System

## Overview

This iOS app template features cutting-edge **glassmorphism** design patterns inspired by modern apps like Grok, Apple's latest interfaces, and web design trends. Glassmorphism combines frosted glass effects, transparency, backdrop blur, and soft shadows to create elegant, modern user interfaces.

## Core Components

### 1. Floating Glass Card
```swift
FloatingGlassCard {
    VStack(alignment: .leading, spacing: 8) {
        Text("Floating with elevation")
            .font(.headline)
            .foregroundStyle(.white)
    }
}
```

**Features:**
- Multi-layer shadows for realistic elevation
- Glowing border that adapts to color theme
- Smooth gradient overlay with transparency
- Responsive to light/dark mode

**Use Cases:**
- Feature showcases
- Premium content cards
- Important notifications
- User achievements

### 2. Hazy Overlay Card
```swift
HazyOverlayCard(
    background: { Image(systemName: "star.fill") },
    content: { Text("Half-revealed content") }
)
```

**Features:**
- Blurred background with content showing through
- Semi-transparent overlay for readability
- Glass border with gradient opacity
- Perfect for content teasing

**Use Cases:**
- Featured content previews
- Call-to-action overlays
- Instagram-style cards
- Discovery feed items

### 3. Glowing Border Card
```swift
GlowingBorderCard(glowColor: .cyan) {
    Text("Pulsing animated border")
}
```

**Features:**
- Animated pulsing glow effect
- Customizable glow colors
- Soft shadow with glow color
- Draws attention naturally

**Use Cases:**
- Active/highlighted states
- New content indicators
- Special promotions
- Interactive elements

### 4. Basic Glass Card
```swift
GlassCard {
    Text("Standard glassmorphic card")
}
```

**Features:**
- Frosted glass appearance
- Subtle gradients
- Layer glass border effect
- Drop shadow with depth

**Use Cases:**
- Standard content containers
- Settings sections
- Information displays
- General list items

## Advanced Components

### Animated Glass Button
```swift
AnimatedGlassButton(
    title: "Explore",
    icon: "sparkles"
) {
    // Action
}
```

**Features:**
- Automatic glow animation
- Glass morphism styling
- Progressive disclosure
- Smooth interactions

### Floating Glass Button
```swift
FloatingGlassButton(
    title: "Save",
    icon: "bookmark.fill"
) {
    // Action
}
```

**Features:**
- Compact circular design
- Multiple shadow layers
- Icon + label composition
- Perfect for floating action buttons

## Design Techniques

### 1. Backdrop Blur
```swift
BackdropBlur {
    content
}
```
Creates the illusion of depth by blurring content behind semi-transparent elements.

### 2. Layered Shadows
```
Shadow 1: Color glow (optional)
Shadow 2: Mid-range shadow (blur radius 20-30)
Shadow 3: Deep shadow (blur radius 50+)
```
Multiple shadow layers create realistic elevation.

### 3. Gradient Opacity
Borders and overlays use gradients that fade from opaque to transparent, creating natural edges.

### 4. Continuous Corner Radius
```swift
RoundedRectangle(cornerRadius: 24, style: .continuous)
```
Smooth, continuous corners feel more modern than `.circular` style.

## Color Theory

### Glow Colors
- **Cyan** (`Color(red: 0.4, green: 0.8, blue: 1.0)`) - Primary, energetic
- **Purple** - Premium, mysterious
- **Orange** - Warmth, action
- **Green** - Success, growth
- **Red** - Attention, energy
- **Pink** - Playful, creative

### Background Colors
```swift
LinearGradient(
    gradient: Gradient(colors: [
        Color(red: 0.12, green: 0.12, blue: 0.15),  // Deep black
        Color(red: 0.18, green: 0.16, blue: 0.22),  // Dark blue-black
        Color(red: 0.15, green: 0.15, blue: 0.18)   // Neutral black
    ]),
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

## Opacity Guidelines

| Element | Opacity Range | Use Case |
|---------|----------------|----------|
| Base Glass | 0.15 - 0.25 | Main card fill |
| Border (top) | 0.4 - 0.5 | Top accent |
| Border (fade) | 0.1 - 0.2 | Faded edges |
| Overlay | 0.6 - 0.8 | Semi-transparent content |
| Shadow (glow) | 0.3 - 0.6 | Colored glow |
| Shadow (depth) | 0.2 - 0.3 | Drop shadow |

## Animation Guidelines

### Glow Pulses
```swift
Animation: .easeInOut(duration: 2).repeatForever(autoreverses: true)
```
Smooth 2-second pulses feel natural and not jarring.

### Card Reveals
```swift
Animation: .easeInOut(duration: 0.3)
```
Fast reveals make interactions feel responsive.

### Entrance
```swift
.scaleEffect(animateCards ? 1.0 : 0.95)
.onAppear {
    withAnimation(.easeInOut(duration: 0.8)) {
        animateCards = true
    }
}
```
Scale from 95% to 100% for subtle entrance.

## Usage Examples

### Example 1: Settings Section
```swift
GlassCard {
    VStack(spacing: 12) {
        SettingRow(icon: "bell.fill", title: "Notifications")
        Divider().background(Color.white.opacity(0.1))
        SettingRow(icon: "moon.fill", title: "Dark Mode")
    }
}
```

### Example 2: Feature Showcase
```swift
FloatingGlassCard(glowColor: .cyan) {
    HStack(spacing: 16) {
        Image(systemName: "sparkles")
            .foregroundStyle(.cyan)
        
        VStack(alignment: .leading) {
            Text("Premium Feature")
                .font(.headline)
            Text("Unlock now")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        
        Spacer()
        Image(systemName: "chevron.right")
    }
}
```

### Example 3: Content Preview
```swift
HazyOverlayCard(
    background: {
        Image("featured-image")
            .resizable()
            .scaledToFill()
    },
    content: {
        VStack(alignment: .leading) {
            Text("New Article")
            Text("Read the full story")
                .font(.caption)
        }
    }
)
```

## Best Practices

### ✅ DO

1. **Use consistent corner radius** - Stick to 16-28pt for cohesion
2. **Layer shadows properly** - Multiple shadows create depth
3. **Animate subtly** - 0.3-0.8 second animations feel responsive
4. **Test on both light & dark** - Ensure readability in all conditions
5. **Use glow colors strategically** - Not every card needs a glow
6. **Provide visual hierarchy** - Use size and opacity to guide attention
7. **Keep text readable** - High contrast on semi-transparent backgrounds

### ❌ DON'T

1. **Overuse glow effects** - Too many glowing elements are distracting
2. **Make shadows too dark** - They should feel light and elegant
3. **Use opacity below 0.1** - Elements become invisible
4. **Mix too many colors** - Stick to 2-3 accent colors per screen
5. **Animate everything** - Reserve animation for important interactions
6. **Ignore accessibility** - Ensure sufficient color contrast
7. **Use on every element** - Glass cards work best for important content

## Performance Considerations

### Shadow Performance
- Limit shadow blur radius to ~30 pixels
- Use `.shadow()` modifier carefully on large lists
- Consider `.blur()` only when necessary

### Blur Performance
- `UIBlurEffect` is expensive - use sparingly
- Consider static gradient overlays instead of blur
- Test on older devices (iPhone 11 and earlier)

### Animation Performance
- Use `withAnimation()` for state changes
- Limit particle count to 20-30
- Profile with Xcode Instruments for UI frame rate

## Accessibility

### Color Contrast
- Ensure 4.5:1 contrast ratio for text on glass cards
- Test with accessibility tools
- Don't rely solely on colors to convey information

### Text Legibility
- Use bold weights for important text
- Increase font size on glass backgrounds
- Add text shadows if needed

### Motion
- Respect `prefersReducedMotion`
- Provide options to disable animations
- Keep animations under 1 second

## Customization

### Change Theme Colors
Edit `Design/Theme.swift`:
```swift
struct AppTheme {
    static let primary = Color(red: 0.2, green: 0.2, blue: 0.25)
    static let accent = Color(red: 0.4, green: 0.8, blue: 1.0)
    // Customize all colors here
}
```

### Adjust Blur Styles
Modify component parameters:
```swift
LiquidGlassOverlay(
    show: true,
    glowColor: .purple,
    animation: .easeInOut(duration: 0.5)
)
```

### Create Custom Cards
Extend the base glass card:
```swift
struct CustomGlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        FloatingGlassCard {
            HStack(spacing: 16) {
                // Your custom layout
                content
            }
        }
    }
}
```

## Inspiration Sources

- **Grok App** - Modern overlay cards, half-revealed content
- **Apple Music** - Backdrop blur, floating cards
- **Spotify** - Layered transparency, glowing accents
- **Instagram Reels** - Hazy overlays, content preview
- **Modern Web Design** - Glassmorphism trends on dribbble.com

## Testing Checklist

- [ ] Test on iPhone 12, 13, 14, 15
- [ ] Test on iOS 15, 16, 17
- [ ] Test with Dark Mode enabled/disabled
- [ ] Test with Larger Text enabled
- [ ] Test with Reduced Motion enabled
- [ ] Verify frame rate with Instruments
- [ ] Test on low-end devices
- [ ] Verify color contrast
- [ ] Test orientation changes
- [ ] Test notch/dynamic island compatibility

## Resources

- [WWDC: Designing with iOS 17](https://developer.apple.com/videos/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)
- [Glassmorphism.com](https://glassmorphism.com) - Web design reference

---

**Template Version:** 1.0.0  
**Last Updated:** March 2026  
**Status:** Production Ready
