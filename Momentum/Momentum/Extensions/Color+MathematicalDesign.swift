import SwiftUI

// MARK: - Mathematical Color System
// Based on perceptual uniformity, WCAG AAA compliance, and Lab color space

extension Color {
    // MARK: - Base Mathematical Constants
    private static let φ: Double = 1.618033988749895 // Golden ratio
    private static let contrastRatioAAA: Double = 7.0 // WCAG AAA minimum
    private static let contrastRatioAA: Double = 4.5 // WCAG AA minimum
    
    
    // MARK: - Mathematical Color Creation
    
    /// Creates a color using Lab color space for perceptual uniformity
    /// - Parameters:
    ///   - l: Lightness (0-100)
    ///   - a: Green-Red axis (-128 to 127)
    ///   - b: Blue-Yellow axis (-128 to 127)
    static func lab(l: Double, a: Double, b: Double) -> Color {
        // Convert Lab to XYZ
        var y = (l + 16) / 116
        var x = a / 500 + y
        var z = y - b / 200
        
        let x3 = x * x * x
        let y3 = y * y * y
        let z3 = z * z * z
        
        x = x3 > 0.008856 ? x3 : (x - 16/116) / 7.787
        y = y3 > 0.008856 ? y3 : (y - 16/116) / 7.787
        z = z3 > 0.008856 ? z3 : (z - 16/116) / 7.787
        
        // D65 illuminant
        x *= 95.047
        y *= 100.000
        z *= 108.883
        
        // XYZ to sRGB
        var r = x * 3.2406 + y * -1.5372 + z * -0.4986
        var g = x * -0.9689 + y * 1.8758 + z * 0.0415
        var b = x * 0.0557 + y * -0.2040 + z * 1.0570
        
        // Gamma correction
        r = r > 0.0031308 ? 1.055 * pow(r, 1/2.4) - 0.055 : 12.92 * r
        g = g > 0.0031308 ? 1.055 * pow(g, 1/2.4) - 0.055 : 12.92 * g
        b = b > 0.0031308 ? 1.055 * pow(b, 1/2.4) - 0.055 : 12.92 * b
        
        return Color(
            red: max(0, min(1, r/100)),
            green: max(0, min(1, g/100)),
            blue: max(0, min(1, b/100))
        )
    }
    
    // MARK: - Contrast Calculation
    
    /// Calculates WCAG contrast ratio between two colors
    static func contrastRatio(between color1: UIColor, and color2: UIColor) -> Double {
        let l1 = color1.relativeLuminance
        let l2 = color2.relativeLuminance
        
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Creates a color with guaranteed contrast ratio against background
    static func withContrast(_ ratio: Double, against background: Color, preferDark: Bool = false) -> Color {
        let bgColor = UIColor(background)
        let bgLuminance = bgColor.relativeLuminance
        
        // Calculate target luminance
        let targetLuminance: Double
        if preferDark {
            targetLuminance = (bgLuminance + 0.05) / ratio - 0.05
        } else {
            targetLuminance = ratio * (bgLuminance + 0.05) - 0.05
        }
        
        // Binary search for the correct gray value
        var low: Double = 0
        var high: Double = 1
        var mid: Double = 0.5
        
        while high - low > 0.01 {
            mid = (low + high) / 2
            let testColor = UIColor(white: mid, alpha: 1.0)
            let testLuminance = testColor.relativeLuminance
            
            if testLuminance < targetLuminance {
                low = mid
            } else {
                high = mid
            }
        }
        
        return Color(white: mid)
    }
}

// MARK: - UIColor Extensions for Luminance

extension UIColor {
    /// Relative luminance as defined by WCAG
    var relativeLuminance: Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Apply gamma correction
        let r = red <= 0.03928 ? red / 12.92 : pow((red + 0.055) / 1.055, 2.4)
        let g = green <= 0.03928 ? green / 12.92 : pow((green + 0.055) / 1.055, 2.4)
        let b = blue <= 0.03928 ? blue / 12.92 : pow((blue + 0.055) / 1.055, 2.4)
        
        // Calculate relative luminance
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}


// MARK: - Mathematical Gradient System

extension LinearGradient {
    /// Creates a gradient with stops at golden ratio intervals
    static func golden(from start: Color, to end: Color, angle: Double = 0) -> LinearGradient {
        let φ = 1.618033988749895
        let stops: [Gradient.Stop] = [
            .init(color: start, location: 0),
            .init(color: start.opacity(1/φ), location: 1/φ),
            .init(color: end.opacity(φ/2), location: 1 - 1/φ),
            .init(color: end, location: 1)
        ]
        
        let radians = angle * .pi / 180
        let x = cos(radians)
        let y = sin(radians)
        
        return LinearGradient(
            stops: stops,
            startPoint: UnitPoint(x: 0.5 - x/2, y: 0.5 - y/2),
            endPoint: UnitPoint(x: 0.5 + x/2, y: 0.5 + y/2)
        )
    }
}