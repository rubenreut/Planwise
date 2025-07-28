//
//  TypographyModifiers.swift
//  Momentum
//
//  Typography modifiers for consistent text hierarchy throughout the app
//

import SwiftUI

// MARK: - Typography Style Modifiers
extension View {
    
    // MARK: Display Styles
    
    /// Extra large titles for main screens
    func displayLarge() -> some View {
        self
            .font(DesignSystem.Typography.largeTitle)
            .foregroundColor(DesignSystem.Colors.primary)
    }
    
    /// Large section titles
    func displayMedium() -> some View {
        self
            .font(DesignSystem.Typography.title1)
            .foregroundColor(DesignSystem.Colors.primary)
    }
    
    /// Medium section titles
    func displaySmall() -> some View {
        self
            .font(DesignSystem.Typography.title2)
            .foregroundColor(DesignSystem.Colors.primary)
    }
    
    // MARK: Heading Styles
    
    /// Primary headings
    func headingPrimary() -> some View {
        self
            .font(DesignSystem.Typography.headline)
            .fontWeight(.semibold)
            .foregroundColor(DesignSystem.Colors.primary)
    }
    
    /// Secondary headings
    func headingSecondary() -> some View {
        self
            .font(DesignSystem.Typography.subheadline)
            .fontWeight(.medium)
            .foregroundColor(DesignSystem.Colors.secondary)
    }
    
    /// Section headers with proper visual weight
    func sectionHeaderStyle() -> some View {
        self
            .font(DesignSystem.Typography.headline)
            .fontWeight(.bold)
            .foregroundColor(DesignSystem.Colors.primary)
            .textCase(.none)
    }
    
    // MARK: Body Styles
    
    /// Primary body text
    func bodyPrimary() -> some View {
        self
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.primary)
    }
    
    /// Secondary body text
    func bodySecondary() -> some View {
        self
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.secondary)
    }
    
    /// Emphasized body text
    func bodyEmphasized() -> some View {
        self
            .font(DesignSystem.Typography.body)
            .fontWeight(.semibold)
            .foregroundColor(DesignSystem.Colors.primary)
    }
    
    // MARK: Supporting Styles
    
    /// Callout text for important information
    func calloutStyle() -> some View {
        self
            .font(DesignSystem.Typography.callout)
            .foregroundColor(DesignSystem.Colors.primary)
    }
    
    /// Caption text for supplementary information
    func captionPrimary() -> some View {
        self
            .font(DesignSystem.Typography.caption1)
            .foregroundColor(DesignSystem.Colors.secondary)
    }
    
    /// Small caption text
    func captionSecondary() -> some View {
        self
            .font(DesignSystem.Typography.caption2)
            .foregroundColor(DesignSystem.Colors.tertiary)
    }
    
    /// Footnote text
    func footnoteStyle() -> some View {
        self
            .font(DesignSystem.Typography.footnote)
            .foregroundColor(DesignSystem.Colors.secondary)
    }
    
    // MARK: Interactive Styles
    
    /// Button text style
    func buttonTextStyle(size: ButtonSize = .medium) -> some View {
        self
            .font(size.font)
            .fontWeight(.semibold)
    }
    
    /// Link text style
    func linkStyle() -> some View {
        self
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.accent)
            .underline()
    }
    
    // MARK: Metadata Styles
    
    /// Timestamp style
    func timestampStyle() -> some View {
        self
            .font(DesignSystem.Typography.caption2)
            .foregroundColor(DesignSystem.Colors.tertiary)
            .monospacedDigit()
    }
    
    /// Badge text style
    func badgeTextStyle() -> some View {
        self
            .font(DesignSystem.Typography.caption1)
            .fontWeight(.bold)
    }
    
    /// Count/number style
    func countStyle() -> some View {
        self
            .font(DesignSystem.Typography.headline)
            .fontWeight(.bold)
            .monospacedDigit()
    }
    
    // MARK: State-based Styles
    
    /// Error text style
    func errorStyle() -> some View {
        self
            .font(DesignSystem.Typography.footnote)
            .foregroundColor(DesignSystem.Colors.error)
    }
    
    /// Success text style
    func successStyle() -> some View {
        self
            .font(DesignSystem.Typography.footnote)
            .foregroundColor(DesignSystem.Colors.success)
    }
    
    /// Warning text style
    func warningStyle() -> some View {
        self
            .font(DesignSystem.Typography.footnote)
            .foregroundColor(DesignSystem.Colors.warning)
    }
    
    /// Disabled text style
    func disabledStyle() -> some View {
        self
            .foregroundColor(DesignSystem.Colors.tertiary)
            .opacity(DesignSystem.Opacity.disabled)
    }
}

// MARK: - Text Hierarchy Component
struct TextHierarchy: View {
    let primary: String
    let secondary: String?
    let tertiary: String?
    let spacing: CGFloat
    
    init(
        primary: String,
        secondary: String? = nil,
        tertiary: String? = nil,
        spacing: CGFloat = DesignSystem.Spacing.xxs
    ) {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.spacing = spacing
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(primary)
                .headingPrimary()
            
            if let secondary = secondary {
                Text(secondary)
                    .bodySecondary()
            }
            
            if let tertiary = tertiary {
                Text(tertiary)
                    .captionPrimary()
            }
        }
    }
}

// MARK: - Label with Badge
struct LabelWithBadge: View {
    let text: String
    let badge: String?
    let badgeColor: Color
    
    init(
        text: String,
        badge: String? = nil,
        badgeColor: Color = DesignSystem.Colors.accent
    ) {
        self.text = text
        self.badge = badge
        self.badgeColor = badgeColor
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(text)
                .bodyPrimary()
            
            if let badge = badge {
                Text(badge)
                    .badgeTextStyle()
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(badgeColor)
                    )
            }
        }
    }
}

// MARK: - Metadata Row
struct MetadataRow: View {
    struct Item {
        let icon: String
        let text: String
        let color: Color?
        
        init(icon: String, text: String, color: Color? = nil) {
            self.icon = icon
            self.text = text
            self.color = color
        }
    }
    
    let items: [Item]
    let spacing: CGFloat
    
    init(items: [Item], spacing: CGFloat = DesignSystem.Spacing.md) {
        self.items = items
        self.spacing = spacing
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(items.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    Image(systemName: items[index].icon)
                        .font(.system(size: 12))
                    Text(items[index].text)
                        .captionPrimary()
                }
                .foregroundColor(items[index].color ?? DesignSystem.Colors.secondary)
            }
        }
    }
}