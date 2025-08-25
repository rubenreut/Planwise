//
//  CustomTabBar.swift
//  Momentum
//
//  Custom tab bar with enhanced design and animations
//

import SwiftUI
import Combine

// MARK: - Custom Shape for Tab Bar (No Indent)
struct IndentedTabBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 20
        
        // Simple rounded rectangle
        path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        
        return path
    }
}

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
                        .scaledFont(size: 24)
                        .scaledIcon()
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(isSelected ? Color.fromAccentString(selectedAccentColor) : .gray)
                        .scaleEffect(isPressed ? 0.85 : (isSelected ? 1.1 : 1.0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
                
                // Label
                Text(tab.title)
                    .scaledFont(size: 10, weight: isSelected ? .semibold : .medium)
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
                    .scaledFont(size: 20)
                    .scaledIcon()
                    .foregroundColor(isSelected ? .white : .gray)
                
                if isSelected {
                    Text(tab.title)
                        .scaledFont(size: 14, weight: .semibold)
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

// MARK: - Ultra Thin Tab Bar (Minimal Collapsible)
struct UltraThinTabBar: View {
    @Binding var selectedTab: NavigationDestination
    let tabs: [NavigationDestination]
    
    @Namespace private var animation
    @State private var isCollapsed = false
    @State private var dragOffset: CGFloat = 0
    
    // Publish collapse state for other views to respond
    static let collapsePublisher = NotificationCenter.default.publisher(for: Notification.Name("TabBarCollapseChanged"))
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main navbar - slides completely off screen when collapsed
            HStack(spacing: 0) {
                // Tab bar background and items
                ZStack {
                    // Background shape
                    IndentedTabBarShape()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            IndentedTabBarShape()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.15)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
                        .frame(height: 65)
                    
                    // Tab items
                    HStack(spacing: 0) {
                        // First two tabs
                        HStack(spacing: 4) {
                            ForEach(tabs.prefix(2)) { tab in
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
                        .frame(maxWidth: .infinity)
                        
                        // Space for FAB (it will be on top)
                        Spacer()
                            .frame(width: 80)
                        
                        // Last two tabs
                        HStack(spacing: 4) {
                            ForEach(tabs.suffix(2)) { tab in
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
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .frame(width: UIScreen.main.bounds.width - 48)
            }
            .offset(x: isCollapsed ? UIScreen.main.bounds.width : dragOffset) // Slide completely off screen or show drag preview
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: isCollapsed)
            
            // FAB button - always visible, moves to corner when collapsed
            NavBarFABButton()
                .offset(
                    x: isCollapsed ? -12 : -(UIScreen.main.bounds.width / 2 - 52), // Move to right edge or center
                    y: -10 // Move FAB 10 pixels higher total
                )
                .scaleEffect(isCollapsed ? 1.1 : 1.0)
                .shadow(
                    color: Color.black.opacity(isCollapsed ? 0.25 : 0.15),
                    radius: isCollapsed ? 15 : 8,
                    x: 0,
                    y: isCollapsed ? 6 : 3
                )
                .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.75, blendDuration: 0), value: isCollapsed)
                .gesture(
                    isCollapsed ?
                    DragGesture()
                        .onEnded { value in
                            // Swipe left on FAB to expand navbar
                            if value.translation.width < -30 {
                                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.8)) {
                                    isCollapsed = false
                                    NotificationCenter.default.post(
                                        name: Notification.Name("TabBarCollapseChanged"),
                                        object: nil,
                                        userInfo: ["isCollapsed": false]
                                    )
                                    HapticFeedback.medium.trigger()
                                }
                            }
                        }
                    : nil
                )
        }
        .frame(height: 65)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only respond to horizontal swipes when navbar is visible
                    if !isCollapsed && abs(value.translation.width) > abs(value.translation.height) * 0.5 {
                        // If swiping right, show drag preview
                        if value.translation.width > 0 {
                            dragOffset = min(value.translation.width * 0.8, 150)
                        }
                    }
                }
                .onEnded { value in
                    if !isCollapsed {
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        let threshold: CGFloat = UIScreen.main.bounds.width * 0.2
                        
                        // Collapsing - swipe right
                        if value.translation.width > threshold || velocity > 100 {
                            // Trigger collapse with smooth animation
                            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.8)) {
                                isCollapsed = true
                                dragOffset = 0
                                NotificationCenter.default.post(
                                    name: Notification.Name("TabBarCollapseChanged"),
                                    object: nil,
                                    userInfo: ["isCollapsed": true]
                                )
                                HapticFeedback.medium.trigger()
                            }
                        } else {
                            // Spring back if not enough drag
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
                }
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
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
            VStack(spacing: 3) {
                // Icon
                Image(systemName: isSelected ? tab.filledIcon : tab.icon)
                    .scaledFont(size: 20, weight: .regular)
                    .scaledIcon()
                    .foregroundColor(isSelected ? Color.fromAccentString(selectedAccentColor) : .gray)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .frame(height: 24)
                
                // Text label (minimal)
                Text(tab.title)
                    .scaledFont(size: 9, weight: isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? Color.fromAccentString(selectedAccentColor) : .gray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
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
    @State private var isNavbarCollapsed = false
    
    enum TabBarStyle {
        case standard
        case floating
        case premium
        case ultraThin
    }
    
    func body(content: Content) -> some View {
        let _ = print("🟡 CustomTabBar - keyboard visible: \(isKeyboardVisible)")
        return ZStack {
            // Main content - no safe area inset
            content
            
            // Tab bar overlay at bottom
            VStack {
                Spacer()
                
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
            .ignoresSafeArea(.all) // Ignore safe areas to go all the way to the bottom
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
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TabBarCollapseChanged"))) { notification in
                if let userInfo = notification.userInfo,
                   let collapsed = userInfo["isCollapsed"] as? Bool {
                    isNavbarCollapsed = collapsed
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

// MARK: - Button Style for Press Detection
struct PressedButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - NavBar FAB Button (just the button UI)
struct NavBarFABButton: View {
    @EnvironmentObject private var navigationState: NavigationState
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @State private var isPressed = false
    @State private var isMenuOpen = false
    
    var body: some View {
        Button {
            if isMenuOpen {
                // Close the menu
                NotificationCenter.default.post(name: Notification.Name("CloseCustomActionMenu"), object: nil)
                isMenuOpen = false
            } else {
                // Open the menu
                NotificationCenter.default.post(name: Notification.Name("ShowCustomActionMenu"), object: nil)
                isMenuOpen = true
            }
            HapticFeedback.light.trigger()
        } label: {
            ZStack {
                // Main button only - no outer ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.fromAccentString(selectedAccentColor),
                                Color.fromAccentString(selectedAccentColor).opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                
                // Plus icon that rotates to X when menu is open
                Image(systemName: "plus")
                    .scaledFont(size: 24, weight: .bold)
                    .scaledIcon()
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 1, y: 1)
                    .rotationEffect(.degrees(isMenuOpen ? 135 : 0))
                    .scaleEffect(isMenuOpen ? 0.8 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isMenuOpen)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PressedButtonStyle(isPressed: $isPressed))
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CloseCustomActionMenu"))) { _ in
            isMenuOpen = false
        }
    }
    
    private var createActionTitle: String {
        switch navigationState.selectedDestination {
        case .day, .week:
            return "Add Event"
        case .tasks:
            return "Add Task"
        case .habits:
            return "Add Habit"
        case .goals:
            return "Add Goal"
        default:
            return "Create"
        }
    }
    
    private var createActionIcon: String {
        switch navigationState.selectedDestination {
        case .day, .week:
            return "calendar.badge.plus"
        case .tasks:
            return "checklist"
        case .habits:
            return "star.fill"
        case .goals:
            return "target"
        default:
            return "plus.circle"
        }
    }
    
    private func handleCreateAction() {
        // Send notification based on current view
        switch navigationState.selectedDestination {
        case .day, .week:
            NotificationCenter.default.post(name: Notification.Name("ShowAddEvent"), object: nil)
        case .tasks:
            NotificationCenter.default.post(name: Notification.Name("ShowAddTask"), object: nil)
        case .habits:
            NotificationCenter.default.post(name: Notification.Name("ShowAddHabit"), object: nil)
        case .goals:
            NotificationCenter.default.post(name: Notification.Name("ShowAddGoal"), object: nil)
        default:
            break
        }
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