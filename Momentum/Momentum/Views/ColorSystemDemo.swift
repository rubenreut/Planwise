import SwiftUI

// MARK: - Color System Demo View
// This view demonstrates the simplified color system and ensures dark mode works properly

struct ColorSystemDemo: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("Simplified Color System")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Brand Colors Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Brand Colors")
                        .font(.headline)
                        .foregroundColor(.label)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        ColorSwatch(color: .Brand.primary, name: "Primary")
                        ColorSwatch(color: .Brand.secondary, name: "Secondary")
                        ColorSwatch(color: .Brand.accent, name: "Accent")
                    }
                    .padding(.horizontal)
                }
                
                // System Colors Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Colors (Auto Dark Mode)")
                        .font(.headline)
                        .foregroundColor(.label)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                        ColorSwatch(color: .systemBlue, name: "Blue")
                        ColorSwatch(color: .systemGreen, name: "Green")
                        ColorSwatch(color: .systemOrange, name: "Orange")
                        ColorSwatch(color: .systemRed, name: "Red")
                        ColorSwatch(color: .systemPurple, name: "Purple")
                        ColorSwatch(color: .systemPink, name: "Pink")
                        ColorSwatch(color: .systemYellow, name: "Yellow")
                        ColorSwatch(color: .systemTeal, name: "Teal")
                        ColorSwatch(color: .systemIndigo, name: "Indigo")
                    }
                    .padding(.horizontal)
                }
                
                // Background Colors Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Background Colors")
                        .font(.headline)
                        .foregroundColor(.label)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        BackgroundSwatch(color: .background, name: "Background")
                        BackgroundSwatch(color: .secondaryBackground, name: "Secondary Background")
                        BackgroundSwatch(color: .tertiaryBackground, name: "Tertiary Background")
                        BackgroundSwatch(color: .groupedBackground, name: "Grouped Background")
                    }
                    .padding(.horizontal)
                }
                
                // Text Colors Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Text Colors")
                        .font(.headline)
                        .foregroundColor(.label)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Primary Label Text")
                            .foregroundColor(.label)
                        Text("Secondary Label Text")
                            .foregroundColor(.secondaryLabel)
                        Text("Tertiary Label Text")
                            .foregroundColor(.tertiaryLabel)
                        Text("Quaternary Label Text")
                            .foregroundColor(.quaternaryLabel)
                        Text("Placeholder Text")
                            .foregroundColor(.placeholderText)
                    }
                    .padding()
                    .background(Color.secondaryBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // UI Elements Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("UI Elements")
                        .font(.headline)
                        .foregroundColor(.label)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        // Separator example
                        HStack {
                            Text("Separator")
                                .foregroundColor(.secondaryLabel)
                            Color.separator
                                .frame(height: 1)
                        }
                        
                        // Fill colors
                        HStack(spacing: 8) {
                            FillSwatch(color: .fill, name: "Fill")
                            FillSwatch(color: .secondaryFill, name: "2nd Fill")
                            FillSwatch(color: .tertiaryFill, name: "3rd Fill")
                            FillSwatch(color: .quaternaryFill, name: "4th Fill")
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Card Styles Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Card Styles")
                        .font(.headline)
                        .foregroundColor(.label)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        // Standard card
                        Text("Standard Card Style")
                            .frame(maxWidth: .infinity)
                            .cardStyle()
                        
                        // Elevated card
                        Text("Elevated Card Style")
                            .frame(maxWidth: .infinity)
                            .elevatedCardStyle()
                    }
                    .padding(.horizontal)
                }
                
                // Chat Bubbles Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Chat Bubbles")
                        .font(.headline)
                        .foregroundColor(.label)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        // User bubble
                        Text("User Message")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.userBubble)
                            .cornerRadius(16)
                        
                        // AI bubble
                        Text("AI Message")
                            .foregroundColor(.label)
                            .padding()
                            .background(Color.aiBubble)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                }
                
                // Gradients Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Gradients")
                        .font(.headline)
                        .foregroundColor(.label)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        // Brand gradient
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient.brand)
                            .frame(height: 60)
                            .overlay(
                                Text("Brand Gradient")
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            )
                        
                        // Simple gradient
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient.simple(.systemBlue, .systemPurple))
                            .frame(height: 60)
                            .overlay(
                                Text("Simple Gradient")
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            )
                        
                        // Subtle background gradient
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient.subtleBackground(in: colorScheme))
                            .frame(height: 60)
                            .overlay(
                                Text("Subtle Background")
                                    .foregroundColor(.label)
                                    .fontWeight(.medium)
                            )
                    }
                    .padding(.horizontal)
                }
                
                // Status Colors Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Status Colors")
                        .font(.headline)
                        .foregroundColor(.label)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        StatusBadge(color: .success, icon: "checkmark.circle.fill", text: "Success")
                        StatusBadge(color: .warning, icon: "exclamationmark.triangle.fill", text: "Warning")
                        StatusBadge(color: .error, icon: "xmark.circle.fill", text: "Error")
                        StatusBadge(color: .info, icon: "info.circle.fill", text: "Info")
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 40)
            }
        }
        .background(Color.background)
    }
}

// MARK: - Helper Views

struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .frame(height: 60)
                .overlay(
                    Text(color.hexString)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                        .padding(4),
                    alignment: .bottomTrailing
                )
            
            Text(name)
                .font(.caption)
                .foregroundColor(.secondaryLabel)
        }
    }
}

struct BackgroundSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(.label)
            Spacer()
            Text("Sample")
                .foregroundColor(.secondaryLabel)
        }
        .padding()
        .background(color)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.separator, lineWidth: 1)
        )
    }
}

struct FillSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
            
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondaryLabel)
        }
    }
}

struct StatusBadge: View {
    let color: Color
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondaryLabel)
        }
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    ColorSystemDemo()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ColorSystemDemo()
        .preferredColorScheme(.dark)
}