//
//  DesignSystem.swift
//  Momentum
//
//  Unified design system for consistent UI across the app
//

import SwiftUI

// MARK: - Design System

struct DesignSystem {
    
    // MARK: - Spacing
    /// Consistent spacing scale based on 4pt grid
    struct Spacing {
        static let xxs: CGFloat = 2   // Micro spacing
        static let xs: CGFloat = 4    // Extra small
        static let sm: CGFloat = 8    // Small
        static let md: CGFloat = 16   // Medium (default)
        static let lg: CGFloat = 24   // Large
        static let xl: CGFloat = 32   // Extra large
        static let xxl: CGFloat = 48  // Extra extra large
        static let xxxl: CGFloat = 64 // Maximum spacing
    }
    
    // MARK: - Typography
    /// Semantic font sizes following iOS design guidelines
    struct Typography {
        // Display
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .semibold, design: .default)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        
        // Text
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        
        // Specialized
        static let buttonLabel = Font.system(size: 17, weight: .semibold, design: .default)
        static let tabLabel = Font.system(size: 10, weight: .medium, design: .default)
        static let navBarTitle = Font.system(size: 17, weight: .semibold, design: .default)
    }
    
    // MARK: - Colors
    /// Semantic color palette
    struct Colors {
        // Primary
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let tertiary = Color(UIColor.tertiaryLabel)
        static let quaternary = Color(UIColor.quaternaryLabel)
        
        // Backgrounds
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
        static let groupedBackground = Color(UIColor.systemGroupedBackground)
        static let secondaryGroupedBackground = Color(UIColor.secondarySystemGroupedBackground)
        
        // Fills
        static let fill = Color(UIColor.systemFill)
        static let secondaryFill = Color(UIColor.secondarySystemFill)
        static let tertiaryFill = Color(UIColor.tertiarySystemFill)
        static let quaternaryFill = Color(UIColor.quaternarySystemFill)
        
        // Semantic Colors
        static let accent = Color.accentColor
        static let success = Color(UIColor.systemGreen)
        static let warning = Color(UIColor.systemOrange)
        static let error = Color(UIColor.systemRed)
        static let info = Color(UIColor.systemBlue)
        
        // Grays
        static let gray = Color(UIColor.systemGray)
        static let gray2 = Color(UIColor.systemGray2)
        static let gray3 = Color(UIColor.systemGray3)
        static let gray4 = Color(UIColor.systemGray4)
        static let gray5 = Color(UIColor.systemGray5)
        static let gray6 = Color(UIColor.systemGray6)
        
        // Separators
        static let separator = Color(UIColor.separator)
        static let opaqueSeparator = Color(UIColor.opaqueSeparator)
    }
    
    // MARK: - Corner Radius
    /// Standard corner radius values
    struct CornerRadius {
        static let xs: CGFloat = 4    // Minimal rounding
        static let sm: CGFloat = 8    // Small elements, buttons
        static let md: CGFloat = 12   // Cards, containers
        static let lg: CGFloat = 16   // Large cards
        static let xl: CGFloat = 20   // Extra large containers
        static let full: CGFloat = 999 // Pills, circular elements
    }
    
    // MARK: - Icon Sizes
    /// Standard icon sizes matching Apple HIG
    struct IconSize {
        static let xs: CGFloat = 12   // Tiny icons
        static let sm: CGFloat = 16   // Small inline icons
        static let md: CGFloat = 20   // Default icons
        static let lg: CGFloat = 24   // Prominent icons
        static let xl: CGFloat = 28   // Large icons
        static let xxl: CGFloat = 32  // Feature icons
        static let xxxl: CGFloat = 40 // Hero icons
    }
    
    // MARK: - Touch Targets
    /// Minimum touch target sizes per Apple HIG
    struct TouchTarget {
        static let minimum: CGFloat = 44      // Minimum interactive size
        static let comfortable: CGFloat = 48  // Comfortable touch target
        static let large: CGFloat = 56        // Large touch target
    }
    
    // MARK: - Animation
    /// Standard animation timings
    struct Animation {
        static let instant = SwiftUI.Animation.easeInOut(duration: 0.1)
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.6)
        static let springSmooth = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.9)
    }
    
    // MARK: - Elevation (Shadows)
    /// Standard elevation/shadow system
    struct Elevation {
        static let none = Shadow(radius: 0, opacity: 0, y: 0)
        static let low = Shadow(radius: 2, opacity: 0.08, y: 1)
        static let medium = Shadow(radius: 4, opacity: 0.12, y: 2)
        static let high = Shadow(radius: 8, opacity: 0.16, y: 4)
        static let floating = Shadow(radius: 12, opacity: 0.20, y: 6)
        
        struct Shadow {
            let radius: CGFloat
            let opacity: Double
            let y: CGFloat
            let x: CGFloat = 0
            
            var color: Color {
                Color.black.opacity(opacity)
            }
        }
    }
    
    // MARK: - Shadow (Alias for compatibility)
    struct Shadow {
        static let xs = Elevation.none
        static let sm = Elevation.low
        static let md = Elevation.medium
        static let lg = Elevation.high
        static let xl = Elevation.floating
    }
    
    // MARK: - Opacity
    /// Standard opacity values
    struct Opacity {
        static let invisible: Double = 0.0
        static let barely: Double = 0.05
        static let subtle: Double = 0.10
        static let light: Double = 0.15
        static let medium: Double = 0.30
        static let strong: Double = 0.60
        static let heavy: Double = 0.80
        static let opaque: Double = 1.0
        
        // Semantic
        static let disabled: Double = 0.38
        static let pressed: Double = 0.80
        static let hover: Double = 0.90
    }
    
    // MARK: - Layout
    /// Standard layout values
    struct Layout {
        static let defaultPadding: CGFloat = Spacing.md
        static let listRowInsets = EdgeInsets(
            top: Spacing.sm,
            leading: Spacing.md,
            bottom: Spacing.sm,
            trailing: Spacing.md
        )
        static let cardInsets = EdgeInsets(
            top: Spacing.md,
            leading: Spacing.md,
            bottom: Spacing.md,
            trailing: Spacing.md
        )
    }
    
    // MARK: - Device Adaptive Values
    struct Adaptive {
        static var isIPad: Bool {
            UIDevice.current.userInterfaceIdiom == .pad
        }
        
        static var isMac: Bool {
            #if targetEnvironment(macCatalyst)
            return true
            #else
            return false
            #endif
        }
        
        static func value<T>(compact: T, regular: T) -> T {
            isIPad || isMac ? regular : compact
        }
        
        static func value<T>(iPhone: T, iPad: T, mac: T) -> T {
            #if targetEnvironment(macCatalyst)
            return mac
            #else
            if UIDevice.current.userInterfaceIdiom == .pad {
                return iPad
            } else {
                return iPhone
            }
            #endif
        }
        
        static func spacing(_ size: CGFloat) -> CGFloat {
            isIPad || isMac ? size * 1.2 : size
        }
    }
}

// MARK: - Standard Components

/// Standard card view with consistent styling
struct StandardCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignSystem.Layout.cardInsets)
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadow(
                color: DesignSystem.Elevation.low.color,
                radius: DesignSystem.Elevation.low.radius,
                x: DesignSystem.Elevation.low.x,
                y: DesignSystem.Elevation.low.y
            )
    }
}

/// Standard button style
struct StandardButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary, tertiary
    }
    
    let style: Style
    
    init(style: Style = .primary) {
        self.style = style
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.buttonLabel)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .frame(minHeight: DesignSystem.TouchTarget.minimum)
            .background(background)
            .cornerRadius(DesignSystem.CornerRadius.sm)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? DesignSystem.Opacity.pressed : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return DesignSystem.Colors.primary
        case .tertiary:
            return DesignSystem.Colors.accent
        }
    }
    
    private var background: some View {
        Group {
            switch style {
            case .primary:
                DesignSystem.Colors.accent
            case .secondary:
                DesignSystem.Colors.quaternaryFill
            case .tertiary:
                Color.clear
            }
        }
    }
}

/// Standard section header
struct StandardSectionHeader: View {
    let title: String
    let icon: String?
    
    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.IconSize.sm))
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            Text(title)
                .font(DesignSystem.Typography.footnote)
                .foregroundColor(DesignSystem.Colors.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

/// Standard floating action button
struct StandardFloatingButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.IconSize.lg, weight: .semibold))
                .foregroundColor(.white)
                .frame(
                    width: DesignSystem.TouchTarget.large,
                    height: DesignSystem.TouchTarget.large
                )
                .background(DesignSystem.Colors.accent)
                .clipShape(Circle())
                .shadow(
                    color: DesignSystem.Elevation.high.color,
                    radius: DesignSystem.Elevation.high.radius,
                    x: DesignSystem.Elevation.high.x,
                    y: DesignSystem.Elevation.high.y
                )
        }
    }
}

/// Standard empty state view
struct StandardEmptyState: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.IconSize.xxxl))
                .foregroundColor(DesignSystem.Colors.tertiary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text(description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: 320)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard card styling
    func standardCard() -> some View {
        self
            .padding(DesignSystem.Layout.cardInsets)
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadow(
                color: DesignSystem.Elevation.low.color,
                radius: DesignSystem.Elevation.low.radius,
                x: DesignSystem.Elevation.low.x,
                y: DesignSystem.Elevation.low.y
            )
    }
    
    /// Apply standard section spacing
    func standardSection() -> some View {
        self
            .padding(.horizontal, DesignSystem.Adaptive.spacing(DesignSystem.Spacing.md))
            .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    /// Apply standard elevation
    func elevation(_ level: DesignSystem.Elevation.Shadow) -> some View {
        self.shadow(
            color: level.color,
            radius: level.radius,
            x: level.x,
            y: level.y
        )
    }
    
    // adaptiveHorizontalPadding is already defined in DeviceUtilities.swift
}

// MARK: - Preview Helpers

#if DEBUG
struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Typography samples
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Typography").font(DesignSystem.Typography.title1)
                    Text("Large Title").font(DesignSystem.Typography.largeTitle)
                    Text("Title 1").font(DesignSystem.Typography.title1)
                    Text("Headline").font(DesignSystem.Typography.headline)
                    Text("Body").font(DesignSystem.Typography.body)
                    Text("Caption").font(DesignSystem.Typography.caption1)
                }
                
                // Color samples
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Colors").font(DesignSystem.Typography.title1)
                    HStack {
                        Circle().fill(DesignSystem.Colors.accent).frame(width: 40, height: 40)
                        Circle().fill(DesignSystem.Colors.success).frame(width: 40, height: 40)
                        Circle().fill(DesignSystem.Colors.warning).frame(width: 40, height: 40)
                        Circle().fill(DesignSystem.Colors.error).frame(width: 40, height: 40)
                    }
                }
                
                // Component samples
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Components").font(DesignSystem.Typography.title1)
                    
                    Button("Primary Button") {}
                        .buttonStyle(StandardButtonStyle(style: .primary))
                    
                    Button("Secondary Button") {}
                        .buttonStyle(StandardButtonStyle(style: .secondary))
                    
                    StandardCard {
                        Text("Standard Card")
                            .font(DesignSystem.Typography.headline)
                    }
                }
            }
            .padding()
        }
    }
}

struct DesignSystemPreview_Previews: PreviewProvider {
    static var previews: some View {
        DesignSystemPreview()
    }
}
#endif