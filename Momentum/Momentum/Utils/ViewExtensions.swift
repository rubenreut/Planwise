//
//  ViewExtensions.swift
//  Momentum
//
//  Common view extensions and modifiers
//

import SwiftUI

// MARK: - Accent Color Extension

extension Color {
    /// Convert accent color string to SwiftUI Color
    static func fromAccentString(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "indigo": return .indigo
        case "custom":
            // Load custom color from hex
            let hexString = UserDefaults.standard.string(forKey: "customAccentColorHex") ?? ""
            if !hexString.isEmpty {
                return Color(hex: hexString)
            }
            return .blue
        default: return .blue // Default fallback
        }
    }
    
    /// Mix two colors together with a given ratio
    func mix(with color: Color, ratio: Double) -> Color {
        let clampedRatio = max(0, min(1, ratio))
        
        // Convert to UIColor to get components
        let uiColor1 = UIColor(self)
        let uiColor2 = UIColor(color)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        // Mix the colors
        let r = r1 * (1 - clampedRatio) + r2 * clampedRatio
        let g = g1 * (1 - clampedRatio) + g2 * clampedRatio
        let b = b1 * (1 - clampedRatio) + b2 * clampedRatio
        let a = a1 * (1 - clampedRatio) + a2 * clampedRatio
        
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Clear Background Helper

struct ClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Navigation Title Extension

extension View {
    /// Apply standard navigation title styling
    func standardNavigationTitle(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Async Task View Helper

struct AsyncTaskView<Content: View>: View {
    let action: () async -> Void
    @ViewBuilder let content: () -> Content
    
    @State private var task: _Concurrency.Task<Void, Never>?
    
    init(action: @escaping () async -> Void, @ViewBuilder content: @escaping () -> Content = { EmptyView() }) {
        self.action = action
        self.content = content
    }
    
    init(action: @escaping () async -> Void) where Content == EmptyView {
        self.init(action: action, content: { EmptyView() })
    }
    
    var body: some View {
        content()
            .onAppear {
                task = _Concurrency.Task {
                    await action()
                }
            }
            .onDisappear {
                task?.cancel()
            }
    }
}

// MARK: - Loading Overlay

extension View {
    func loadingOverlay(_ isLoading: Bool) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        )
                }
            }
        )
    }
}

// MARK: - Card Background

extension View {
    func cardBackground(cornerRadius: CGFloat = DesignSystem.CornerRadius.md) -> some View {
        self
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(cornerRadius)
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 2,
                x: 0,
                y: 1
            )
    }
}

// MARK: - Conditional Modifier

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Hide Keyboard

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Placeholder Modifier

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Navigation Link Style

struct ScaledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Safe Area Insets

extension View {
    var safeAreaInsets: UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return .zero
        }
        return window.safeAreaInsets
    }
}


// MARK: - Tap to Dismiss Keyboard

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}