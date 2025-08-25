import SwiftUI
import UIKit

// MARK: - UIColor Brightness Extensions
extension UIColor {
    func brightened(by percentage: CGFloat = 0.3) -> UIColor? {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Increase brightness but keep it under 1.0
            let newBrightness = min(brightness + percentage, 1.0)
            // Also reduce saturation slightly for a more pastel look in dark mode
            let newSaturation = max(saturation * 0.8, 0)
            return UIColor(hue: hue, saturation: newSaturation, brightness: newBrightness, alpha: alpha)
        } else {
            // Fallback for grayscale colors
            var white: CGFloat = 0
            var alpha: CGFloat = 0
            if self.getWhite(&white, alpha: &alpha) {
                let newWhite = min(white + percentage, 1.0)
                return UIColor(white: newWhite, alpha: alpha)
            }
        }
        return nil
    }
}

// MARK: - Dark Mode Color System (Deprecated - Use Color+Theme.swift)
// This file provides backward compatibility for existing code.
// For new code, use the simplified color system in Color+Theme.swift

@available(*, deprecated, renamed: "Color.label", message: "Use Color.label from Color+Theme.swift")
extension Color {
    
    // MARK: - Semantic Colors for Dark Mode (Backward Compatibility)
    
    /// Background colors - mapped to new system colors
    static var adaptiveBackground: Color {
        Color.background
    }
    
    static var adaptiveSecondaryBackground: Color {
        Color.secondaryBackground
    }
    
    static var adaptiveTertiaryBackground: Color {
        Color.tertiaryBackground
    }
    
    /// Card and elevated surface colors
    static var adaptiveCardBackground: Color {
        Color.cardBackground
    }
    
    /// Text colors - mapped to new system colors
    @available(*, deprecated, renamed: "Color.label", message: "Use Color.label from Color+Theme.swift")
    static var adaptivePrimaryText: Color {
        Color.label
    }
    
    @available(*, deprecated, renamed: "Color.secondaryLabel", message: "Use Color.secondaryLabel from Color+Theme.swift")
    static var adaptiveSecondaryText: Color {
        Color.secondaryLabel
    }
    
    @available(*, deprecated, renamed: "Color.tertiaryLabel", message: "Use Color.tertiaryLabel from Color+Theme.swift")
    static var adaptiveTertiaryText: Color {
        Color.tertiaryLabel
    }
    
    /// Border and separator colors
    static var adaptiveSeparator: Color {
        Color.separator
    }
    
    static var adaptiveBorder: Color {
        Color.separator.opacity(0.5)
    }
    
    // MARK: - Accent Colors for Dark Mode
    
    /// Accent colors - mapped to new system colors
    static var adaptiveBlue: Color {
        Color.systemBlue
    }
    
    static var adaptiveGreen: Color {
        Color.systemGreen
    }
    
    static var adaptiveOrange: Color {
        Color.systemOrange
    }
    
    static var adaptiveRed: Color {
        Color.systemRed
    }
    
    static var adaptivePurple: Color {
        Color.systemPurple
    }
    
    // MARK: - Shadow Colors
    
    static var adaptiveShadow: Color {
        Color.shadow
    }
    
    // MARK: - Chat Bubble Colors
    
    static var userBubbleBackground: Color {
        Color.userBubble
    }
    
    static var aiBubbleBackground: Color {
        Color.aiBubble
    }
    
    static var aiBubbleText: Color {
        Color.label
    }
}

// MARK: - View Extensions for Dark Mode (Deprecated)
@available(*, deprecated, message: "Use cardStyle() or elevatedCardStyle() from Color+Theme.swift")
extension View {
    /// Applies adaptive background with proper dark mode support
    func adaptiveBackground() -> some View {
        self.background(Color.background)
    }
    
    /// Applies card styling with dark mode support
    func adaptiveCard(padding: CGFloat = 16) -> some View {
        self.cardStyle(padding: padding)
    }
    
    /// Applies adaptive foreground color
    func adaptiveForeground(_ style: AdaptiveTextStyle = .primary) -> some View {
        self.foregroundColor(style.color)
    }
}

// MARK: - Text Style Enum
enum AdaptiveTextStyle {
    case primary
    case secondary
    case tertiary
    
    var color: Color {
        switch self {
        case .primary:
            return .label
        case .secondary:
            return .secondaryLabel
        case .tertiary:
            return .tertiaryLabel
        }
    }
}

// MARK: - Deprecated Color Conversion
@available(*, deprecated, renamed: "hexString", message: "Use hexString from Color+Theme.swift")
extension Color {
    func toHex() -> String {
        return self.hexString
    }
}

// MARK: - Deprecated Gradient Extensions
@available(*, deprecated, message: "Use LinearGradient.simple() from Color+Theme.swift")
extension LinearGradient {
    /// Creates an adaptive gradient that looks good in both light and dark modes
    static func adaptiveGradient(
        from startColor: Color,
        to endColor: Color,
        darkFrom darkStartColor: Color? = nil,
        darkTo darkEndColor: Color? = nil
    ) -> LinearGradient {
        // For backward compatibility, ignore dark mode specific colors
        // The new system colors already handle dark mode automatically
        return LinearGradient.simple(startColor, endColor)
    }
}