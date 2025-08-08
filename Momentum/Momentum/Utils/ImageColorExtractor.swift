import UIKit
import SwiftUI

/// Utility for extracting dominant colors from images
class ImageColorExtractor {
    
    /// Extracts dominant colors from an image
    /// - Parameters:
    ///   - image: The image to analyze
    ///   - maxColors: Maximum number of colors to extract (default: 3)
    /// - Returns: Array of dominant colors sorted by prominence
    static func extractDominantColors(from image: UIImage, maxColors: Int = 3) -> [Color] {
        guard let cgImage = image.cgImage else { return [] }
        
        // Resize image for faster processing
        let targetSize = CGSize(width: 100, height: 100)
        guard let resizedImage = image.resized(to: targetSize) else { return [] }
        guard let pixelData = resizedImage.cgImage?.dataProvider?.data else { return [] }
        
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let width = Int(resizedImage.size.width)
        let height = Int(resizedImage.size.height)
        
        // Dictionary to store color frequencies
        var colorFrequencies: [UIColor: Int] = [:]
        
        // Sample pixels (skip some for performance)
        let step = 2 // Sample every 2nd pixel
        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                let pixelIndex = ((width * y) + x) * 4
                
                // Skip if index is out of bounds
                guard pixelIndex + 3 < CFDataGetLength(pixelData) else { continue }
                
                let r = CGFloat(data[pixelIndex]) / 255.0
                let g = CGFloat(data[pixelIndex + 1]) / 255.0
                let b = CGFloat(data[pixelIndex + 2]) / 255.0
                let a = CGFloat(data[pixelIndex + 3]) / 255.0
                
                // Skip transparent or nearly transparent pixels
                guard a > 0.5 else { continue }
                
                // Quantize colors to reduce variations
                let quantizedColor = UIColor(
                    red: round(r * 10) / 10,
                    green: round(g * 10) / 10,
                    blue: round(b * 10) / 10,
                    alpha: 1.0
                )
                
                colorFrequencies[quantizedColor, default: 0] += 1
            }
        }
        
        // Sort colors by frequency and take top colors
        let sortedColors = colorFrequencies
            .sorted { $0.value > $1.value }
            .prefix(maxColors)
            .map { Color($0.key) }
        
        // If we couldn't extract enough colors, add some defaults
        var finalColors = sortedColors
        if finalColors.count < maxColors {
            // Add muted versions of the primary color if available
            if let primaryColor = finalColors.first {
                while finalColors.count < maxColors {
                    let opacity = 0.7 - (Double(finalColors.count - 1) * 0.2)
                    finalColors.append(primaryColor.opacity(opacity))
                }
            } else {
                // Fallback to default colors
                finalColors = [
                    Color(red: 0.08, green: 0.15, blue: 0.35),
                    Color(red: 0.12, green: 0.25, blue: 0.55),
                    Color(red: 0.15, green: 0.30, blue: 0.60)
                ]
            }
        }
        
        return Array(finalColors)
    }
    
    /// Creates a gradient from the extracted colors suitable for the timeline background
    /// - Parameters:
    ///   - colors: The extracted colors
    ///   - baseOpacity: Base opacity for the gradient (default: 0.15)
    /// - Returns: A subtle gradient suitable for background use
    static func createTimelineGradient(from colors: [Color], baseOpacity: Double = 0.15) -> LinearGradient {
        guard !colors.isEmpty else {
            // Default gradient if no colors provided
            return LinearGradient(
                colors: [
                    Color.gray.opacity(0.05),
                    Color.gray.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        // Create subtle gradient colors
        let gradientColors: [Color]
        
        if colors.count == 1 {
            // Single color: create variations
            let baseColor = colors[0]
            gradientColors = [
                baseColor.opacity(baseOpacity * 0.5),
                baseColor.opacity(baseOpacity),
                baseColor.opacity(baseOpacity * 0.7)
            ]
        } else if colors.count == 2 {
            // Two colors: use both with variations
            gradientColors = [
                colors[0].opacity(baseOpacity * 0.6),
                colors[1].opacity(baseOpacity),
                colors[0].opacity(baseOpacity * 0.4)
            ]
        } else {
            // Three or more colors: use all
            gradientColors = colors.enumerated().map { index, color in
                let opacity = baseOpacity * (1.0 - Double(index) * 0.2)
                return color.opacity(max(opacity, baseOpacity * 0.3))
            }
        }
        
        return LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - UIImage Extension for Resizing

extension UIImage {
    /// Resizes the image to the specified size
    func resized(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Determine the scale factor that preserves aspect ratio
        let scaleFactor = min(widthRatio, heightRatio)
        
        // Compute the new image size that preserves aspect ratio
        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        // Draw and return the resized UIImage
        let renderer = UIGraphicsImageRenderer(size: scaledImageSize)
        
        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledImageSize))
        }
        
        return scaledImage
    }
}