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
    @Environment(\.dependencyContainer) private var dependencyContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
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
        .tint(.adaptiveBlue)
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .trackViewAppearance("UnifiedNavigationView", additionalData: [
            "device": DeviceType.current == .iPhone ? "iPhone" : (DeviceType.current == .iPad ? "iPad" : "Mac"),
            "initial_destination": navigationState.selectedDestination.rawValue
        ])
    }
    
    // MARK: - iPhone Navigation
    
    private var iPhoneNavigation: some View {
        ZStack {
            // Main content with tab bar
            TabView(selection: $navigationState.selectedDestination) {
                ForEach(NavigationDestination.allCases.filter { $0.showsInTabBar }) { destination in
                    NavigationStack {
                        destination.view()
                            .navigationBarTitleDisplayMode(.automatic)
                            .navigationGestures(navigationState, enabled: true)
                    }
                    .tabItem {
                        Label(destination.title, systemImage: destination.icon)
                            .accessibilityLabel(destination.title)
                            .accessibilityHint("Navigate to \(destination.title)")
                    }
                    .tag(destination)
                }
            }
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
    
    // MARK: - iPad Navigation
    
    private var iPadNavigation: some View {
        NavigationSplitView(columnVisibility: $navigationState.columnVisibility) {
            // Sidebar
            NavigationSidebar(navigationState: navigationState)
                .navigationSplitViewColumnWidth(
                    min: 280,
                    ideal: 320,
                    max: 400
                )
        } detail: {
            // Detail view
            NavigationStack {
                navigationState.selectedDestination.view()
                    .id(navigationState.selectedDestination)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                navigationState.toggleSidebar()
                            } label: {
                                Image(systemName: navigationState.columnVisibility == .all ? "sidebar.left" : "sidebar.right")
                                    .font(.system(size: 17))
                                    .foregroundColor(.adaptiveBlue)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .accessibilityLabel("Toggle Sidebar")
                            .accessibilityHint(navigationState.columnVisibility == .all ? "Hide sidebar" : "Show sidebar")
                        }
                    }
            }
            .overlay(alignment: .top) {
                // Offline banner
                OfflineBanner()
                    .padding(.top, DesignSystem.Spacing.sm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .navigationSplitViewStyle(.balanced)
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
                    .background(Color.adaptiveBackground)
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
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch) (4th generation)"))
}

#if targetEnvironment(macCatalyst)
#Preview("Mac") {
    UnifiedNavigationView()
        .injectDependencies(DependencyContainer.shared)
}
#endif