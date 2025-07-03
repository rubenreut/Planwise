import SwiftUI
import UIKit

struct PremiumHeaderView: View {
    let dateTitle: String
    let selectedDate: Date
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    let onToday: () -> Void
    let onSettings: () -> Void
    let onAddEvent: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var currentTime = Date()
    
    // Mathematical constants
    private let φ: CGFloat = 1.618033988749895
    private let baseUnit: CGFloat = 8
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Date navigation row
            HStack(spacing: 0) {
                // Previous day button
                Button(action: onPreviousDay) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(white: 0.4))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PremiumButtonStyle())
                
                Spacer()
                
                // Center date section
                VStack(spacing: 3) {
                    Text(dateTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(white: 0.09))
                    
                    HStack(spacing: 6) {
                        if Calendar.current.isDateInToday(selectedDate) {
                            Circle()
                                .fill(Color(red: 0, green: 0.478, blue: 1))
                                .frame(width: 4, height: 4)
                        }
                        
                        Text(timeString)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                    }
                }
                
                Spacer()
                
                // Next day button
                Button(action: onNextDay) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(white: 0.4))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PremiumButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .padding(.top, max(getSafeAreaTop() * 0.05, 8)) // 5% of safe area or minimum 8pts
        .background(
            // Simplified premium background
            Rectangle()
                .fill(.regularMaterial)
                .overlay(
                    Rectangle()
                        .fill(colorScheme == .dark ? 
                            Color.black.opacity(0.2) : 
                            Color.white.opacity(0.7)
                        )
                )
        )
        .overlay(
            // Simple bottom border
            Rectangle()
                .fill(Color(white: colorScheme == .dark ? 0.2 : 0.85))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
    
    private func getSafeAreaTop() -> CGFloat {
        // Get the safe area top inset
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.top
        }
        return 0
    }
}

// Premium button style with sophisticated interactions
struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

#Preview {
    VStack {
        PremiumHeaderView(
            dateTitle: "Monday, June 29",
            selectedDate: Date(),
            onPreviousDay: {},
            onNextDay: {},
            onToday: {},
            onSettings: {},
            onAddEvent: {}
        )
        
        Spacer()
    }
    .background(Color(UIColor.systemGroupedBackground))
}