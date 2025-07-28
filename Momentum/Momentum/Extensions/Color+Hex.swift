import SwiftUI

// MARK: - Hex Color Support
// Simple hex color initialization for convenience

extension Color {
    /// Initialize a Color from a hex string
    /// Supports formats: "#RGB", "RGB", "#RRGGBB", "RRGGBB", "#AARRGGBB", "AARRGGBB"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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
        
        self.init(UIColor(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        ))
    }
    
    /// Mix this color with another color
    /// - Deprecated: Use mixed(with:amount:) from Color+Theme.swift
    @available(*, deprecated, renamed: "mixed", message: "Use mixed(with:amount:) from Color+Theme.swift")
    func mix(with color: Color, by amount: Double) -> Color {
        return self.mixed(with: color, amount: amount)
    }
}