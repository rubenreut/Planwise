import SwiftUI

// MARK: - Glass Morphic View Modifier
struct GlassmorphicStyle: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base white layer for better contrast
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.85))
                    
                    // Blur effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.regularMaterial)
                        .opacity(0.9)
                }
            )
            .overlay(
                // Subtle border
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(DesignSystem.Opacity.disabled), lineWidth: 1)
            )
            .shadow(color: DesignSystem.Elevation.low.color, radius: shadowRadius * 0.5, x: 0, y: 2)
    }
}

// MARK: - Premium Glass Morphic Style
struct PremiumGlassmorphicStyle: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Dark glass base
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.premiumCardBackground)
                    
                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(DesignSystem.Opacity.subtle),
                                    Color.white.opacity(DesignSystem.Opacity.subtle / 2.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Blur layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(DesignSystem.Opacity.strong)
                }
            )
            .overlay(
                // Premium border with gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(DesignSystem.Opacity.light + 0.02),
                                Color.white.opacity(DesignSystem.Opacity.subtle)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(DesignSystem.Opacity.strong), radius: shadowRadius, x: 0, y: shadowRadius/2)
            .shadow(color: Color.premiumAccent.opacity(DesignSystem.Opacity.subtle), radius: shadowRadius * 2, x: 0, y: shadowRadius)
    }
}

// MARK: - Card Lifting Effect
struct CardLiftEffect: ViewModifier {
    @State private var isPressed = false
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .shadow(
                color: Color.black.opacity(isPressed ? DesignSystem.Opacity.subtle + 0.01 : DesignSystem.Elevation.low.opacity),
                radius: isPressed ? DesignSystem.Elevation.low.radius / 2 : DesignSystem.Elevation.low.radius * 0.75,
                x: 0,
                y: isPressed ? 2 : 4
            )
            .animation(DesignSystem.Animation.springBouncy, value: isPressed)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { isPressing in
                    isPressed = isPressing
                },
                perform: {}
            )
    }
}

// MARK: - Colored Icon Background
struct ColoredIconBackground: View {
    let color: Color
    let size: CGFloat
    let iconOpacity: Double
    
    init(color: Color, size: CGFloat = 60, iconOpacity: Double = 0.2) {
        self.color = color
        self.size = size
        self.iconOpacity = iconOpacity
    }
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(iconOpacity),
                        color.opacity(iconOpacity * 0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
    }
}

// MARK: - Glass Card Component
struct GlassCard<Content: View>: View {
    let content: () -> Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    init(
        cornerRadius: CGFloat = DesignSystem.CornerRadius.lg - 4,
        padding: CGFloat = DesignSystem.Spacing.md,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(padding)
            .glassmorphic(cornerRadius: cornerRadius)
            .cardLift(cornerRadius: cornerRadius)
    }
}

// MARK: - Section Header Style
struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - List Item Card
struct ListItemCard<Icon: View, Content: View>: View {
    let icon: () -> Icon
    let iconBackground: Color
    let content: () -> Content
    var action: (() -> Void)?
    
    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon with colored background
                ZStack {
                    ColoredIconBackground(color: iconBackground, size: 50)
                    icon()
                        .font(.system(size: DesignSystem.IconSize.lg))
                        .foregroundColor(iconBackground)
                }
                
                // Content
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary.opacity(DesignSystem.Opacity.disabled))
            }
            .padding(DesignSystem.Spacing.md)
            .glassmorphic(cornerRadius: DesignSystem.CornerRadius.md)
            .cardLift(cornerRadius: DesignSystem.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Premium Badge Style
struct PremiumBadgeStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs - 2)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(DesignSystem.Opacity.light))
                    .overlay(
                        Capsule()
                            .stroke(Color.blue.opacity(DesignSystem.Opacity.strong), lineWidth: 1)
                    )
            )
            .foregroundColor(.blue)
            .font(.caption)
            .fontWeight(.medium)
    }
}

// Note: FloatingActionButtonStyle has been moved to ButtonSystem.swift for consistency

// MARK: - Progress Ring with Glass Effect
struct GlassProgressRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    
    init(progress: Double, color: Color, size: CGFloat = 60, lineWidth: CGFloat = 8) {
        self.progress = progress
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(DesignSystem.Opacity.light), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(DesignSystem.Animation.spring, value: progress)
            
            // Center content
            VStack(spacing: DesignSystem.Spacing.xxs / 2) {
                Text("\(Int(progress * 100))")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text("%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func glassmorphic(cornerRadius: CGFloat = DesignSystem.CornerRadius.lg - 4, shadowRadius: CGFloat = DesignSystem.Elevation.medium.radius) -> some View {
        self.modifier(GlassmorphicStyle(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
    
    func premiumGlassmorphic(cornerRadius: CGFloat = DesignSystem.CornerRadius.md, shadowRadius: CGFloat = DesignSystem.Elevation.high.radius - 4) -> some View {
        self.modifier(PremiumGlassmorphicStyle(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
    
    func cardLift(cornerRadius: CGFloat = DesignSystem.CornerRadius.lg - 4) -> some View {
        self.modifier(CardLiftEffect(cornerRadius: cornerRadius))
    }
    
    func sectionHeader() -> some View {
        self.modifier(SectionHeaderStyle())
    }
    
    func premiumBadge() -> some View {
        self.modifier(PremiumBadgeStyle())
    }
}

// MARK: - Empty State View
struct GlassmorphicEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Icon with glass background
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(DesignSystem.Opacity.light))
                    .frame(width: DesignSystem.Spacing.xxxl + DesignSystem.Spacing.xl + 4, height: DesignSystem.Spacing.xxxl + DesignSystem.Spacing.xl + 4)
                
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.IconSize.xxl + 4))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.medium)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(FloatingActionButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.xl + DesignSystem.Spacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Premium UI Colors
extension Color {
    static let softBackground = Color(UIColor.systemGray6)
    static let glassShadow = Color.black.opacity(DesignSystem.Elevation.low.opacity)
    static let glassHighlight = Color.white.opacity(0.7)
    
    // Premium dark theme colors
    static let premiumBackground = Color(hex: "#0A0A0B")
    static let premiumCardBackground = Color(hex: "#141416")
    static let premiumGlassBackground = Color.white.opacity(DesignSystem.Opacity.subtle - 0.02)
    static let premiumBorder = Color.white.opacity(DesignSystem.Opacity.light - 0.02)
    static let premiumShadow = Color.black.opacity(DesignSystem.Opacity.disabled)
    static let premiumAccent = Color(hex: "#4C7BFF")
    static let premiumSecondaryText = Color(hex: "#8E8E93")
}