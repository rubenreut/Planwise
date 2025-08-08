//
//  ColorExtraction.swift
//  Momentum
//
//  Extract dominant colors from images
//

import SwiftUI
import UIKit
import CoreImage

struct DominantColors {
    let primary: Color
    let secondary: Color
    let accent: Color
}

class ColorExtractor {
    static func extractColors(from image: UIImage) -> DominantColors {
        print("🎨 Starting color extraction...")
        
        // Get colors from bottom edge of image for smooth transition
        let bottomColors = extractBottomEdgeColors(from: image)
        
        return bottomColors
    }
    
    static func extractBottomEdgeColors(from image: UIImage) -> DominantColors {
        // Resize image for processing but keep aspect ratio
        let targetWidth: CGFloat = 200
        let scale = targetWidth / image.size.width
        let targetHeight = image.size.height * scale
        let size = CGSize(width: targetWidth, height: targetHeight)
        
        guard let resized = image.resize(to: size),
              let cgImage = resized.cgImage else {
            print("🎨 Failed to resize image, using defaults")
            return defaultColors()
        }
        
        // Convert to CIImage
        let ciImage = CIImage(cgImage: cgImage)
        
        // Extract from bottom 20% of image
        let bottomHeight = resized.size.height * 0.2
        let bottomY = resized.size.height - bottomHeight
        let bottomExtent = CIVector(x: 0, y: bottomY, z: resized.size.width, w: bottomHeight)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: bottomExtent
        ]),
        let outputImage = filter.outputImage else {
            print("🎨 Failed to create filter, using defaults")
            return defaultColors()
        }
        
        // Get the average color from bottom area
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        let bottomColor = Color(
            red: Double(bitmap[0]) / 255.0,
            green: Double(bitmap[1]) / 255.0,
            blue: Double(bitmap[2]) / 255.0
        )
        
        print("🎨 Bottom edge color: R:\(bitmap[0]) G:\(bitmap[1]) B:\(bitmap[2])")
        
        // Create gradient variations - primary is the actual bottom color
        let primary = bottomColor
        let secondary = adjustBrightness(of: bottomColor, by: -0.1) // Slightly darker
        let accent = adjustSaturation(of: bottomColor, by: 1.2)
        
        print("🎨 Extraction complete!")
        return DominantColors(primary: primary, secondary: secondary, accent: accent)
    }
    
    private static func defaultColors() -> DominantColors {
        return DominantColors(
            primary: Color(red: 0.08, green: 0.15, blue: 0.35),
            secondary: Color(red: 0.12, green: 0.25, blue: 0.55),
            accent: Color.blue
        )
    }
    
    private static func adjustBrightness(of color: Color, by factor: Double) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newBrightness = min(1.0, brightness + CGFloat(factor))
        return Color(UIColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: alpha))
    }
    
    private static func adjustSaturation(of color: Color, by factor: Double) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newSaturation = min(1.0, saturation * CGFloat(factor))
        return Color(UIColor(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha))
    }
}

extension UIImage {
    func resize(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        self.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// Store extracted colors in UserDefaults
extension UserDefaults {
    private enum ColorKeys {
        static let primaryR = "extractedPrimaryR"
        static let primaryG = "extractedPrimaryG"
        static let primaryB = "extractedPrimaryB"
        static let secondaryR = "extractedSecondaryR"
        static let secondaryG = "extractedSecondaryG"
        static let secondaryB = "extractedSecondaryB"
    }
    
    func setExtractedColors(_ colors: DominantColors) {
        let primaryComponents = UIColor(colors.primary).cgColor.components ?? [0, 0, 0]
        let secondaryComponents = UIColor(colors.secondary).cgColor.components ?? [0, 0, 0]
        
        set(Double(primaryComponents[0]), forKey: ColorKeys.primaryR)
        set(Double(primaryComponents[1]), forKey: ColorKeys.primaryG)
        set(Double(primaryComponents[2]), forKey: ColorKeys.primaryB)
        set(Double(secondaryComponents[0]), forKey: ColorKeys.secondaryR)
        set(Double(secondaryComponents[1]), forKey: ColorKeys.secondaryG)
        set(Double(secondaryComponents[2]), forKey: ColorKeys.secondaryB)
    }
    
    func getExtractedColors() -> (primary: Color, secondary: Color)? {
        let primaryR = double(forKey: ColorKeys.primaryR)
        let primaryG = double(forKey: ColorKeys.primaryG)
        let primaryB = double(forKey: ColorKeys.primaryB)
        let secondaryR = double(forKey: ColorKeys.secondaryR)
        let secondaryG = double(forKey: ColorKeys.secondaryG)
        let secondaryB = double(forKey: ColorKeys.secondaryB)
        
        // Check if we have valid colors stored
        if primaryR == 0 && primaryG == 0 && primaryB == 0 {
            return nil
        }
        
        return (
            primary: Color(red: primaryR, green: primaryG, blue: primaryB),
            secondary: Color(red: secondaryR, green: secondaryG, blue: secondaryB)
        )
    }
    
    func clearExtractedColors() {
        removeObject(forKey: ColorKeys.primaryR)
        removeObject(forKey: ColorKeys.primaryG)
        removeObject(forKey: ColorKeys.primaryB)
        removeObject(forKey: ColorKeys.secondaryR)
        removeObject(forKey: ColorKeys.secondaryG)
        removeObject(forKey: ColorKeys.secondaryB)
    }
}