//
//  ViewExtensions.swift
//  Momentum
//
//  Common view extensions and modifiers
//

import SwiftUI

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