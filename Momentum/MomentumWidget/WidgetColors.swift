import SwiftUI

// MARK: - Widget Color Extensions
// Simplified color system for widgets using iOS system colors

extension Color {
    // MARK: - System Colors (automatically support dark mode)
    
    // Background colors
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    static let groupedBackground = Color(UIColor.systemGroupedBackground)
    
    // Card background
    static let cardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.secondarySystemBackground
            : UIColor.systemBackground
    })
    
    // Text colors
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    static let quaternaryLabel = Color(UIColor.quaternaryLabel)
    
    // UI Element colors
    static let separator = Color(UIColor.separator)
    static let fill = Color(UIColor.systemFill)
    static let secondaryFill = Color(UIColor.secondarySystemFill)
    
    // System colors
    static let systemBlue = Color(UIColor.systemBlue)
    static let systemGreen = Color(UIColor.systemGreen)
    static let systemOrange = Color(UIColor.systemOrange)
    static let systemRed = Color(UIColor.systemRed)
    
    // MARK: - Backward Compatibility (Deprecated)
    
    @available(*, deprecated, renamed: "background")
    static var adaptiveBackground: Color { background }
    
    @available(*, deprecated, renamed: "secondaryBackground")
    static var adaptiveSecondaryBackground: Color { secondaryBackground }
    
    @available(*, deprecated, renamed: "tertiaryBackground")
    static var adaptiveTertiaryBackground: Color { tertiaryBackground }
    
    @available(*, deprecated, renamed: "cardBackground")
    static var adaptiveCardBackground: Color { cardBackground }
    
    @available(*, deprecated, renamed: "label")
    static var adaptiveLabel: Color { label }
    
    @available(*, deprecated, renamed: "secondaryLabel")
    static var adaptiveSecondaryLabel: Color { secondaryLabel }
    
    @available(*, deprecated, renamed: "label")
    static var adaptivePrimaryText: Color { label }
    
    @available(*, deprecated, renamed: "secondaryLabel")
    static var adaptiveSecondaryText: Color { secondaryLabel }
    
    @available(*, deprecated, renamed: "separator")
    static var adaptiveSeparator: Color { separator }
    
    @available(*, deprecated, renamed: "separator")
    static var adaptiveBorder: Color { separator.opacity(0.5) }
    
    @available(*, deprecated, renamed: "systemBlue")
    static var adaptiveBlue: Color { systemBlue }
    
    @available(*, deprecated, renamed: "systemGreen")
    static var adaptiveGreen: Color { systemGreen }
    
    // MARK: - Event Category Colors
    
    /// Get color for event category
    static func categoryColor(for hex: String?) -> Color {
        guard let hex = hex else {
            return Color.systemBlue
        }
        return Color.fromHex(hex)
    }
}

// MARK: - Hex Color Support
// Widget-specific implementation

extension Color {
    /// Create a Color from a hex string (Widget version)
    static func fromHex(_ hexString: String) -> Color {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        return Color(UIColor(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        ))
    }
}