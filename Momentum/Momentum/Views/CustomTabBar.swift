//
//  CustomTabBar.swift
//  Momentum
//
//  Custom tab bar with enhanced design and animations
//

import SwiftUI
import Combine

struct CustomTabBar: View {
    @Binding var selectedTab: NavigationDestination
    let tabs: [NavigationDestination]
    
    @State private var selectedRect: CGRect = .zero
    @State private var isAnimating = false
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                        HapticFeedback.light.trigger()
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            TabBarBackground()
        )
        .overlay(alignment: .top) {
            // Top separator
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Tab Bar Item
struct TabBarItem: View {
    let tab: NavigationDestination
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Icon with animation
                ZStack {
                    // Background circle for selected state
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.fromAccentString(selectedAccentColor).opacity(0.15))
                            .frame(width: 56, height: 32)
                            .matchedGeometryEffect(id: "background", in: namespace)
                    }
                    
                    Image(systemName: isSelected ? tab.filledIcon : tab.icon)
                        .font(.system(size: 24))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(isSelected ? Color.fromAccentString(selectedAccentColor) : .gray)
                        .scaleEffect(isPressed ? 0.85 : (isSelected ? 1.1 : 1.0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
                
                // Label
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Color.fromAccentString(selectedAccentColor) : .gray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Tab Bar Background
struct TabBarBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Base blur
            Rectangle()
                .fill(.ultraThinMaterial)
            
            // Gradient overlay
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.3),
                    Color.white.opacity(0)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .allowsHitTesting(false)
        }
        .background(
            // Subtle shadow
            Color.black.opacity(0.1)
                .blur(radius: 10)
                .offset(y: -5)
        )
    }
}

// MARK: - Floating Tab Bar Style
struct FloatingTabBar: View {
    @Binding var selectedTab: NavigationDestination
    let tabs: [NavigationDestination]
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                FloatingTabItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                        HapticFeedback.light.trigger()
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md)
    }
}

// MARK: - Floating Tab Item
struct FloatingTabItem: View {
    let tab: NavigationDestination
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? tab.filledIcon : tab.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .gray)
                
                if isSelected {
                    Text(tab.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, isSelected ? 16 : 12)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.fromAccentString(selectedAccentColor))
                            .matchedGeometryEffect(id: "floatingBackground", in: namespace)
                    }
                }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Premium Tab Bar
struct PremiumTabBar: View {
    @Binding var selectedTab: NavigationDestination
    let tabs: [NavigationDestination]
    
    @State private var animatedTab: NavigationDestination?
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                PremiumTabItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: animation,
                    animatedTab: $animatedTab
                ) {
                    selectedTab = tab
                    HapticFeedback.light.trigger()
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            ZStack {
                // Ultra-thin material background
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
                
                // Very subtle gradient overlay
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Minimal border for definition
                Capsule()
                    .stroke(
                        Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.md - 25)
    }
}

// MARK: - Premium Tab Item
struct PremiumTabItem: View {
    let tab: NavigationDestination
    let isSelected: Bool
    let namespace: Namespace.ID
    @Binding var animatedTab: NavigationDestination?
    let action: () -> Void
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    private var isAnimating: Bool {
        animatedTab == tab
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.filledIcon : tab.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? Color.fromAccentString(selectedAccentColor) : .secondary.opacity(0.7))
                    .frame(height: 24)
                
                Text(tab.title)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color.fromAccentString(selectedAccentColor) : .secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Ultra Thin Tab Bar
struct UltraThinTabBar: View {
    @Binding var selectedTab: NavigationDestination
    let tabs: [NavigationDestination]
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                UltraThinTabItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                        HapticFeedback.light.trigger()
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            // Proper frosted glass blur effect
            ZStack {
                // Base blur layer
                Capsule()
                    .fill(.thinMaterial)
                
                // Additional tint for better opacity
                Capsule()
                    .fill(Color(UIColor.systemBackground).opacity(0.3))
            }
        )
        .overlay(
            // Subtle border for definition
            Capsule()
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}

// MARK: - Ultra Thin Tab Item
struct UltraThinTabItem: View {
    let tab: NavigationDestination
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: isSelected ? tab.filledIcon : tab.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? Color.fromAccentString(selectedAccentColor) : .secondary.opacity(0.75))
                    .frame(height: 24)
                
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color.fromAccentString(selectedAccentColor) : .secondary.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.fromAccentString(selectedAccentColor).opacity(0.15))
                            .matchedGeometryEffect(id: "ultraThinBackground", in: namespace)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tab Bar Container Modifier
struct CustomTabBarModifier: ViewModifier {
    @Binding var selectedTab: NavigationDestination
    let tabs: [NavigationDestination]
    let style: TabBarStyle
    @Environment(\.keyboardVisibility) private var keyboardVisibility
    @State private var isKeyboardVisible = false
    
    enum TabBarStyle {
        case standard
        case floating
        case premium
        case ultraThin
    }
    
    func body(content: Content) -> some View {
        let _ = print("🟡 CustomTabBar - keyboard visible: \(isKeyboardVisible)")
        return content
            .safeAreaInset(edge: .bottom) {
                if !isKeyboardVisible {
                    Group {
                        switch style {
                        case .standard:
                            CustomTabBar(selectedTab: $selectedTab, tabs: tabs)
                        case .floating:
                            FloatingTabBar(selectedTab: $selectedTab, tabs: tabs)
                        case .premium:
                            PremiumTabBar(selectedTab: $selectedTab, tabs: tabs)
                        case .ultraThin:
                            UltraThinTabBar(selectedTab: $selectedTab, tabs: tabs)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.25), value: isKeyboardVisible)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                print("🟢 CustomTabBar received keyboard will show")
                withAnimation(.easeOut(duration: 0.25)) {
                    isKeyboardVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                print("🔴 CustomTabBar received keyboard will hide")
                withAnimation(.easeIn(duration: 0.25)) {
                    isKeyboardVisible = false
                }
            }
    }
}

extension View {
    func customTabBar(
        selectedTab: Binding<NavigationDestination>,
        tabs: [NavigationDestination],
        style: CustomTabBarModifier.TabBarStyle = .premium
    ) -> some View {
        self.modifier(CustomTabBarModifier(
            selectedTab: selectedTab,
            tabs: tabs,
            style: style
        ))
    }
}

// MARK: - Preview
#Preview("Standard") {
    VStack {
        Spacer()
        CustomTabBar(
            selectedTab: .constant(.day),
            tabs: NavigationDestination.allCases.filter { $0.showsInTabBar }
        )
    }
}

#Preview("Floating") {
    VStack {
        Spacer()
        FloatingTabBar(
            selectedTab: .constant(.tasks),
            tabs: NavigationDestination.allCases.filter { $0.showsInTabBar }
        )
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Premium") {
    VStack {
        Spacer()
        PremiumTabBar(
            selectedTab: .constant(.assistant),
            tabs: NavigationDestination.allCases.filter { $0.showsInTabBar }
        )
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Ultra Thin") {
    VStack {
        Spacer()
        UltraThinTabBar(
            selectedTab: .constant(.day),
            tabs: NavigationDestination.allCases.filter { $0.showsInTabBar }
        )
    }
    .background(Color.gray.opacity(0.1))
}