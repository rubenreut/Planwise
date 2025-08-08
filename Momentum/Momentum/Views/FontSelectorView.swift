import SwiftUI

struct FontSelectorView: View {
    @AppStorage("selectedFontFamily") private var selectedFont = FontChoice.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var showingPreview = true
    
    var body: some View {
        NavigationView {
            List {
                // Preview Section
                Section {
                    VStack(spacing: 16) {
                        Text("The quick brown fox jumps over the lazy dog")
                            .font(FontChoice(rawValue: selectedFont)?.font(size: 24, weight: .bold) ?? .system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Text("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                            .font(FontChoice(rawValue: selectedFont)?.font(size: 14) ?? .system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("abcdefghijklmnopqrstuvwxyz")
                            .font(FontChoice(rawValue: selectedFont)?.font(size: 14) ?? .system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("1234567890")
                            .font(FontChoice(rawValue: selectedFont)?.font(size: 14) ?? .system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Preview")
                }
                
                // Font Options
                Section {
                    ForEach(FontChoice.allCases, id: \.rawValue) { font in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(font.displayName)
                                    .font(font.font(size: 18, weight: .medium))
                                
                                Text("The quick brown fox")
                                    .font(font.font(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedFont == font.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 22))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFont = font.rawValue
                            }
                            
                            // Haptic feedback
                            HapticFeedback.selection.trigger()
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Available Fonts")
                } footer: {
                    Text("Choose a font that suits your reading preference. The selected font will be used throughout the app.")
                }
                
                // Font Size Adjustment (Future feature)
                Section {
                    HStack {
                        Text("Font Size Adjustment")
                        Spacer()
                        Text("Coming Soon")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                } header: {
                    Text("Advanced Options")
                }
            }
            .navigationTitle("Font Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Font Preview Card
struct FontPreviewCard: View {
    let font: FontChoice
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(font.displayName)
                .font(font.font(size: 20, weight: .semibold))
            
            Text("The quick brown fox jumps over the lazy dog")
                .font(font.font(size: 16))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack(spacing: 16) {
                Text("Aa")
                    .font(font.font(size: 28, weight: .light))
                
                Text("Aa")
                    .font(font.font(size: 28, weight: .regular))
                
                Text("Aa")
                    .font(font.font(size: 28, weight: .semibold))
                
                Text("Aa")
                    .font(font.font(size: 28, weight: .bold))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
    }
}

#Preview {
    FontSelectorView()
}