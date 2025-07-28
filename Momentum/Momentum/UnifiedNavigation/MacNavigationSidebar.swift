//
//  MacNavigationSidebar.swift
//  Momentum
//
//  Mac-specific navigation sidebar with native styling
//

import SwiftUI

struct MacNavigationSidebar: View {
    @ObservedObject var navigationState: NavigationState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            MacSidebarHeader()
                .padding(.bottom, DesignSystem.Spacing.md)
            
            // Navigation sections
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Schedule section
                    VStack(spacing: DesignSystem.Spacing.xxs / 2) {
                        ForEach(NavigationSection.schedule.destinations) { destination in
                            MacNavigationButton(
                                destination: destination,
                                isSelected: navigationState.selectedDestination == destination
                            ) {
                                navigationState.navigate(to: destination)
                            }
                        }
                    }
                    
                    // Productivity section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                        MacSectionHeader("PRODUCTIVITY")
                        
                        ForEach(NavigationSection.productivity.destinations) { destination in
                            MacNavigationButton(
                                destination: destination,
                                isSelected: navigationState.selectedDestination == destination,
                                badge: badgeCount(for: destination)
                            ) {
                                navigationState.navigate(to: destination)
                            }
                        }
                    }
                    
                    // Assistant section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                        MacSectionHeader("ASSISTANT")
                        
                        ForEach(NavigationSection.ai.destinations) { destination in
                            MacNavigationButton(
                                destination: destination,
                                isSelected: navigationState.selectedDestination == destination,
                                showsPremiumBadge: destination.requiresPremium
                            ) {
                                navigationState.navigate(to: destination)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
            }
            
            Spacer()
            
            // Bottom section
            MacSidebarFooter(navigationState: navigationState)
        }
    }
    
    private func badgeCount(for destination: NavigationDestination) -> Int? {
        switch destination {
        case .tasks:
            return navigationState.pendingTaskCount > 0 ? navigationState.pendingTaskCount : nil
        case .habits:
            return navigationState.todayHabitCount > 0 ? navigationState.todayHabitCount : nil
        default:
            return nil
        }
    }
}

// MARK: - Mac Sidebar Header

struct MacSidebarHeader: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: DesignSystem.IconSize.xl + 4))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                Text("Momentum")
                    .font(.system(size: 18, weight: .bold))
                Text("Productivity Suite")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.lg)
    }
}

// MARK: - Mac Section Header

struct MacSectionHeader: View {
    let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xxs)
    }
}

// MARK: - Mac Navigation Button

struct MacNavigationButton: View {
    let destination: NavigationDestination
    let isSelected: Bool
    var badge: Int? = nil
    var showsPremiumBadge: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button {
            action()
            NavigationFeedback.selection()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: destination.icon)
                    .font(.system(size: DesignSystem.IconSize.sm))
                    .foregroundColor(iconColor)
                    .frame(width: DesignSystem.IconSize.lg)
                    .symbolRenderingMode(.hierarchical)
                
                Text(destination.title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundColor(textColor)
                
                Spacer()
                
                if showsPremiumBadge {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.adaptiveOrange)
                        .opacity(isSelected ? 1 : 0.7)
                }
                
                if let badge = badge {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .white : destination.iconColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? destination.iconColor : destination.iconColor.opacity(0.2))
                        )
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(buttonBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var iconColor: Color {
        if isSelected {
            return .white
        } else if isHovered {
            return destination.iconColor
        } else {
            return .secondary
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isHovered {
            return .primary
        } else {
            return .primary
        }
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
            .fill(backgroundFill)
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovered {
            return Color(white: 0.5, opacity: 0.1)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Mac Sidebar Footer

struct MacSidebarFooter: View {
    @ObservedObject var navigationState: NavigationState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            // Settings button
            MacNavigationButton(
                destination: .settings,
                isSelected: navigationState.selectedDestination == .settings
            ) {
                navigationState.navigate(to: .settings)
            }
            
            // User info
            HStack(spacing: DesignSystem.Spacing.sm) {
                UserAvatar(size: 32)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("User")
                        .font(.system(size: 13, weight: .medium))
                    
                    HStack(spacing: 3) {
                        Image(systemName: subscriptionManager.isPremium ? "crown.fill" : "person.fill")
                            .font(.system(size: 9))
                        Text(subscriptionManager.isPremium ? "Premium" : "Free")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(subscriptionManager.isPremium ? .adaptiveOrange : .secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
    }
}