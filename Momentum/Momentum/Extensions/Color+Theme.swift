import SwiftUI

// MARK: - App Theme Colors
// Simple, practical color system with automatic dark mode support

extension Color {
    // MARK: - Brand Colors
    struct Brand {
        static let primary = Color.blue
        static let secondary = Color.indigo
        static let accent = Color.purple
    }
    
    // MARK: - Semantic Colors
    
    // Background colors - using iOS system colors for automatic dark mode
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    static let groupedBackground = Color(UIColor.systemGroupedBackground)
    static let secondaryGroupedBackground = Color(UIColor.secondarySystemGroupedBackground)
    
    // Text colors - using iOS system colors for proper contrast
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    static let quaternaryLabel = Color(UIColor.quaternaryLabel)
    static let placeholderText = Color(UIColor.placeholderText)
    
    // UI Element colors
    static let separator = Color(UIColor.separator)
    static let opaqueSeparator = Color(UIColor.opaqueSeparator)
    static let link = Color(UIColor.link)
    static let fill = Color(UIColor.systemFill)
    static let secondaryFill = Color(UIColor.secondarySystemFill)
    static let tertiaryFill = Color(UIColor.tertiarySystemFill)
    static let quaternaryFill = Color(UIColor.quaternarySystemFill)
    
    // System colors with automatic dark mode adaptation
    static let systemBlue = Color(UIColor.systemBlue)
    static let systemGreen = Color(UIColor.systemGreen)
    static let systemIndigo = Color(UIColor.systemIndigo)
    static let systemOrange = Color(UIColor.systemOrange)
    static let systemPink = Color(UIColor.systemPink)
    static let systemPurple = Color(UIColor.systemPurple)
    static let systemRed = Color(UIColor.systemRed)
    static let systemTeal = Color(UIColor.systemTeal)
    static let systemYellow = Color(UIColor.systemYellow)
    
    // Gray scale - using iOS system grays
    static let systemGray = Color(UIColor.systemGray)
    static let systemGray2 = Color(UIColor.systemGray2)
    static let systemGray3 = Color(UIColor.systemGray3)
    static let systemGray4 = Color(UIColor.systemGray4)
    static let systemGray5 = Color(UIColor.systemGray5)
    static let systemGray6 = Color(UIColor.systemGray6)
    
    // MARK: - App-Specific Colors
    
    // Card backgrounds
    static let cardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.secondarySystemBackground
            : UIColor.systemBackground
    })
    
    // Chat bubble colors
    static let userBubble = systemBlue
    static let aiBubble = secondaryBackground
    
    // Status colors
    static let success = systemGreen
    static let warning = systemOrange
    static let error = systemRed
    static let info = systemBlue
    
    // MARK: - Shadow Colors
    static let shadow = Color.black.opacity(0.1)
    static let darkShadow = Color.black.opacity(0.2)
    static let lightShadow = Color.black.opacity(0.05)
}

// MARK: - Practical Color Utilities

extension Color {
    /// Adjust opacity based on current color scheme
    func adaptiveOpacity(_ light: Double, dark: Double) -> some View {
        self.opacity(UITraitCollection.current.userInterfaceStyle == .dark ? dark : light)
    }
    
    /// Mix two colors together
    func mixed(with color: Color, amount: Double = 0.5) -> Color {
        let amount = min(1, max(0, amount))
        
        let c1 = UIColor(self)
        let c2 = UIColor(color)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return Color(
            red: Double(r1 + (r2 - r1) * CGFloat(amount)),
            green: Double(g1 + (g2 - g1) * CGFloat(amount)),
            blue: Double(b1 + (b2 - b1) * CGFloat(amount)),
            opacity: Double(a1 + (a2 - a1) * CGFloat(amount))
        )
    }
    
    /// Convert color to hex string
    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "#%06x", rgb)
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply standard card styling
    func cardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .background(Color.cardBackground)
            .cornerRadius(cornerRadius)
            .shadow(color: .shadow, radius: 2, x: 0, y: 1)
    }
    
    /// Apply elevated card styling (with more prominent shadow)
    func elevatedCardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .background(Color.cardBackground)
            .cornerRadius(cornerRadius)
            .shadow(color: .darkShadow, radius: 8, x: 0, y: 4)
    }
    
    /// Apply subtle background
    func subtleBackground() -> some View {
        self.background(Color.secondaryBackground.opacity(0.5))
    }
}

// MARK: - Gradient Utilities

extension LinearGradient {
    /// Create a simple two-color gradient
    static func simple(_ from: Color, _ to: Color, angle: Double = 45) -> LinearGradient {
        let radians = angle * .pi / 180
        let x = cos(radians)
        let y = sin(radians)
        
        return LinearGradient(
            colors: [from, to],
            startPoint: UnitPoint(x: 0.5 - x/2, y: 0.5 - y/2),
            endPoint: UnitPoint(x: 0.5 + x/2, y: 0.5 + y/2)
        )
    }
    
    /// Create a subtle background gradient
    static func subtleBackground(in colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return simple(.black, .systemGray6, angle: -45)
        } else {
            return simple(.systemGray6, .white, angle: -45)
        }
    }
    
    /// Create a brand gradient
    static let brand = simple(.Brand.primary, .Brand.accent)
}