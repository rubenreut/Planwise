//
//  NavigationTransitions.swift
//  Momentum
//
//  Custom navigation transitions and animations
//

import SwiftUI

// MARK: - Navigation Transition Modifier

struct NavigationTransition: ViewModifier {
    let isActive: Bool
    let transition: TransitionType
    
    enum TransitionType {
        case slide
        case fade
        case scale
        case slideAndFade
        case hero
    }
    
    func body(content: Content) -> some View {
        content
            .transition(getTransition())
            .animation(getAnimation(), value: isActive)
    }
    
    private func getTransition() -> AnyTransition {
        switch transition {
        case .slide:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .fade:
            return .opacity
        case .scale:
            return .scale.combined(with: .opacity)
        case .slideAndFade:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .hero:
            return .asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 1.1).combined(with: .opacity)
            )
        }
    }
    
    private func getAnimation() -> Animation {
        switch transition {
        case .slide, .slideAndFade:
            return .spring(response: 0.35, dampingFraction: 0.85)
        case .fade:
            return .easeInOut(duration: 0.25)
        case .scale, .hero:
            return .spring(response: 0.3, dampingFraction: 0.8)
        }
    }
}

// MARK: - Tab Selection Transition

struct TabSelectionTransition: ViewModifier {
    let selectedTab: Int
    let tabIndex: Int
    
    func body(content: Content) -> some View {
        content
            .opacity(selectedTab == tabIndex ? 1 : 0)
            .scaleEffect(selectedTab == tabIndex ? 1 : 0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
    }
}

// MARK: - Sidebar Row Animation

struct SidebarRowAnimation: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isSelected ? 1.02 : (isHovered ? 1.01 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Page Transition

struct PageTransition: ViewModifier {
    @Binding var currentPage: NavigationDestination
    let page: NavigationDestination
    
    func body(content: Content) -> some View {
        content
            .opacity(currentPage == page ? 1 : 0)
            .offset(x: offsetX)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
    }
    
    private var offsetX: CGFloat {
        guard currentPage != page else { return 0 }
        
        let currentIndex = NavigationDestination.allCases.firstIndex(of: currentPage) ?? 0
        let pageIndex = NavigationDestination.allCases.firstIndex(of: page) ?? 0
        
        return CGFloat((pageIndex - currentIndex) * 50)
    }
}

// MARK: - Navigation Feedback

struct NavigationFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// MARK: - View Extensions

extension View {
    func navigationTransition(_ type: NavigationTransition.TransitionType, isActive: Bool) -> some View {
        modifier(NavigationTransition(isActive: isActive, transition: type))
    }
    
    func tabSelectionTransition(selectedTab: Int, tabIndex: Int) -> some View {
        modifier(TabSelectionTransition(selectedTab: selectedTab, tabIndex: tabIndex))
    }
    
    func sidebarRowAnimation(isSelected: Bool, isHovered: Bool) -> some View {
        modifier(SidebarRowAnimation(isSelected: isSelected, isHovered: isHovered))
    }
    
    func pageTransition(currentPage: Binding<NavigationDestination>, page: NavigationDestination) -> some View {
        modifier(PageTransition(currentPage: currentPage, page: page))
    }
}

// MARK: - Animated Navigation Container

struct AnimatedNavigationContainer<Content: View>: View {
    @Binding var selectedDestination: NavigationDestination
    let content: (NavigationDestination) -> Content
    
    var body: some View {
        ZStack {
            ForEach(NavigationDestination.allCases) { destination in
                content(destination)
                    .opacity(selectedDestination == destination ? 1 : 0)
                    .scaleEffect(selectedDestination == destination ? 1 : 0.95)
                    .blur(radius: selectedDestination == destination ? 0 : 2)
                    .allowsHitTesting(selectedDestination == destination)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedDestination)
    }
}

// MARK: - Navigation Gesture Handler

struct NavigationGestureHandler: ViewModifier {
    @ObservedObject var navigationState: NavigationState
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            handleSwipe(value)
                        }
                )
        } else {
            content
        }
    }
    
    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontalAmount = value.translation.width
        let verticalAmount = value.translation.height
        
        // Only handle horizontal swipes
        guard abs(horizontalAmount) > abs(verticalAmount) else { return }
        guard abs(horizontalAmount) > 50 else { return } // Minimum swipe distance
        
        if horizontalAmount > 0 {
            // Swipe right - go to previous
            navigateToPrevious()
        } else {
            // Swipe left - go to next
            navigateToNext()
        }
    }
    
    private func navigateToPrevious() {
        let currentIndex = NavigationDestination.allCases.firstIndex(of: navigationState.selectedDestination) ?? 0
        if currentIndex > 0 {
            let previousDestination = NavigationDestination.allCases[currentIndex - 1]
            if previousDestination.showsInTabBar {
                navigationState.navigate(to: previousDestination)
                NavigationFeedback.selection()
            }
        }
    }
    
    private func navigateToNext() {
        let currentIndex = NavigationDestination.allCases.firstIndex(of: navigationState.selectedDestination) ?? 0
        if currentIndex < NavigationDestination.allCases.count - 1 {
            let nextDestination = NavigationDestination.allCases[currentIndex + 1]
            if nextDestination.showsInTabBar {
                navigationState.navigate(to: nextDestination)
                NavigationFeedback.selection()
            }
        }
    }
}

extension View {
    func navigationGestures(_ navigationState: NavigationState, enabled: Bool = true) -> some View {
        modifier(NavigationGestureHandler(navigationState: navigationState, isEnabled: enabled))
    }
}