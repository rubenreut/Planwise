//
//  UnifiedNavigationView.swift
//  Momentum
//
//  Main navigation container that adapts to different platforms
//

import SwiftUI

struct UnifiedNavigationView: View {
    @StateObject private var navigationState = NavigationState()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var keyboardVisibility = KeyboardVisibilityState()
    @Environment(\.dependencyContainer) private var dependencyContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @State private var showingAIAssistant = false
    @State private var showingSettings = false
    @State private var navigationRefreshID = UUID()
    @State private var showCustomActionMenu = false
    @State private var isNavbarCollapsed = false
    
    var body: some View {
        Group {
            switch DeviceType.current {
            case .iPhone:
                iPhoneNavigation
            case .iPad:
                iPadNavigation
            case .mac:
                macNavigation
            }
        }
        .environmentObject(navigationState)
        .environmentObject(subscriptionManager)
        .environmentObject(keyboardVisibility)
        .environment(\.keyboardVisibility, keyboardVisibility)
        .tint(Color.fromAccentString(selectedAccentColor))
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .trackViewAppearance("UnifiedNavigationView", additionalData: [
            "device": DeviceType.current == .iPhone ? "iPhone" : (DeviceType.current == .iPad ? "iPad" : "Mac"),
            "initial_destination": navigationState.selectedDestination.rawValue
        ])
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToDayView"))) { _ in
            navigationState.selectedDestination = .day
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToWeekView"))) { _ in
            navigationState.selectedDestination = .week
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowAIAssistant"))) { _ in
            showingAIAssistant = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowSettings"))) { _ in
            showingSettings = true
        }
        .sheet(isPresented: $showingAIAssistant, onDismiss: {
            // Refresh navigation ID to force NavigationStack recreation
            navigationRefreshID = UUID()
        }) {
            NavigationStack {
                AIChatView()
                    .navigationTitle("AI Assistant")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingAIAssistant = false
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingAIAssistant = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            // Refresh navigation ID to force NavigationStack recreation
            navigationRefreshID = UUID()
        }) {
            SettingsView()
                .presentationDetents([.large])
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowCustomActionMenu"))) { _ in
            print("🔵 ShowCustomActionMenu notification received")
            showCustomActionMenu = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CloseCustomActionMenu"))) { _ in
            print("🔴 CloseCustomActionMenu notification received")
            showCustomActionMenu = false
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TabBarCollapseChanged"))) { notification in
            if let userInfo = notification.userInfo,
               let collapsed = userInfo["isCollapsed"] as? Bool {
                isNavbarCollapsed = collapsed
            }
        }
        .overlay(
            ZStack {
                // Position the radial menu relative to FAB position
                if showCustomActionMenu {
                    if isNavbarCollapsed {
                        // When collapsed, FAB is in bottom right corner - vertical stack
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                RadialActionMenu(
                                    isShowing: $showCustomActionMenu,
                                    currentTab: navigationState.selectedDestination,
                                    isVertical: true  // Vertical stack for collapsed state
                                ) { item in
                                    handleActionMenuSelection(item)
                                }
                                // Exact same padding as FAB button in CustomTabBar
                                .padding(.trailing, 12 + 24) // FAB padding (12) + tab bar horizontal padding (24)
                            }
                        }
                        // Position above tab bar: tab bar height (65) + tab bar bottom padding (4) + small gap
                        .padding(.bottom, 65 + 4 + 10)
                        .zIndex(999)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showCustomActionMenu)
                    } else {
                        // When expanded, FAB is in center of navbar - radial menu
                        VStack {
                            Spacer()
                            RadialActionMenu(
                                isShowing: $showCustomActionMenu,
                                currentTab: navigationState.selectedDestination,
                                isVertical: false  // Radial/circular for expanded state
                            ) { item in
                                handleActionMenuSelection(item)
                            }
                            .frame(height: 120)
                            .padding(.bottom, 30) // Position above the centered FAB in navbar
                        }
                        .zIndex(999)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showCustomActionMenu)
                    }
                }
            }
        )
    }
    
    private func handleActionMenuSelection(_ item: ActionMenuItem) {
        switch item.id {
        case "task":
            NotificationCenter.default.post(name: Notification.Name("ShowAddTask"), object: nil)
        case "event":
            NotificationCenter.default.post(name: Notification.Name("ShowAddEvent"), object: nil)
        case "habit":
            NotificationCenter.default.post(name: Notification.Name("ShowAddHabit"), object: nil)
        case "goal":
            NotificationCenter.default.post(name: Notification.Name("ShowAddGoal"), object: nil)
        case "ai":
            showingAIAssistant = true
        case "settings":
            showingSettings = true
        default:
            break
        }
    }
    
    // MARK: - iPhone Navigation
    
    private var iPhoneNavigation: some View {
        ZStack {
            // Super light gray background to prevent white flash
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            // Main content area - back to original navigation
            NavigationStack {
                ZStack {
                    // Background for smooth transitions
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    navigationState.selectedDestination.view()
                        .navigationBarTitleDisplayMode(.automatic)
                        // Disabled swipe gestures to allow swipe-to-delete in lists
                        .navigationGestures(navigationState, enabled: false)
                        .transition(.identity)
                }
            }
            .id(navigationRefreshID) // Force NavigationStack refresh when sheets close
            .customTabBar(
                selectedTab: $navigationState.selectedDestination,
                tabs: NavigationDestination.allCases.filter { $0.showsInTabBar },
                style: .ultraThin
            )
            .onChange(of: navigationState.selectedDestination) { _, _ in
                NavigationFeedback.selection()
            }
            .overlay(alignment: .top) {
                // Offline banner
                OfflineBanner()
                    .padding(.top, DesignSystem.Spacing.xxl)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
    }
    
    // MARK: - iPad Navigation (Using same tab bar as iPhone)
    
    private var iPadNavigation: some View {
        ZStack {
            // Super light gray background to prevent white flash
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            // Main content area - same as iPhone
            NavigationStack {
                ZStack {
                    // Background for smooth transitions
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    navigationState.selectedDestination.view()
                        .navigationBarTitleDisplayMode(.automatic)
                        .navigationBarHidden(true) // Hide nav bar on iPad
                        // Disabled swipe gestures to allow swipe-to-delete in lists
                        .navigationGestures(navigationState, enabled: false)
                        .transition(.identity)
                }
            }
            .id(navigationRefreshID) // Force NavigationStack refresh when sheets close
            .customTabBar(
                selectedTab: $navigationState.selectedDestination,
                tabs: NavigationDestination.allCases.filter { $0.showsInTabBar },
                style: .ultraThin
            )
            .onChange(of: navigationState.selectedDestination) { _, _ in
                NavigationFeedback.selection()
            }
            .overlay(alignment: .top) {
                // Offline banner
                OfflineBanner()
                    .padding(.top, DesignSystem.Spacing.xxl)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
    }
    
    // MARK: - Mac Navigation
    
    private var macNavigation: some View {
        HStack(spacing: 0) {
            // Mac sidebar
            MacNavigationSidebar(navigationState: navigationState)
                .frame(width: 260)
                .background(
                    VisualEffectBlur(material: .sidebar)
                )
            
            Divider()
            
            // Main content
            NavigationStack {
                navigationState.selectedDestination.view()
                    .id(navigationState.selectedDestination)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
            }
            .overlay(alignment: .topTrailing) {
                // Offline banner for Mac
                OfflineBanner()
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.trailing, DesignSystem.Spacing.md)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: View {
    var material: Material
    var blendingMode: BlendMode = .normal
    
    enum Material {
        case sidebar
        case content
        case thin
        case thick
    }
    
    var body: some View {
        #if os(macOS)
        // Mac-specific blur implementation
        Color.clear
            .background(.regularMaterial)
        #else
        // iOS/iPadOS blur
        switch material {
        case .sidebar:
            Color(UIColor.secondarySystemBackground)
                .opacity(0.95)
        case .content:
            Color(UIColor.systemBackground)
                .opacity(0.98)
        case .thin:
            Color(UIColor.systemBackground)
                .opacity(0.8)
        case .thick:
            Color(UIColor.systemBackground)
                .opacity(0.99)
        }
        #endif
    }
}

// MARK: - Preview

#Preview("iPhone") {
    UnifiedNavigationView()
        .injectDependencies(DependencyContainer.shared)
}

#Preview("iPad") {
    UnifiedNavigationView()
        .injectDependencies(DependencyContainer.shared)
        // Use device picker at bottom of Canvas instead
}

#if targetEnvironment(macCatalyst)
#Preview("Mac") {
    UnifiedNavigationView()
        .injectDependencies(DependencyContainer.shared)
}
#endif