//
//  NavigationSidebar.swift
//  Momentum
//
//  Unified sidebar component for iPad navigation
//

import SwiftUI

struct NavigationSidebar: View {
    @ObservedObject var navigationState: NavigationState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        List(selection: Binding<NavigationDestination?>($navigationState.selectedDestination)) {
            // App header
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: DesignSystem.IconSize.xl))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.adaptiveBlue, .adaptivePurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Momentum")
                            .font(.system(size: 20, weight: .bold))
                        Text("Stay productive")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            
            // Navigation sections
            ForEach(NavigationSection.allCases, id: \.self) { section in
                if section.showsHeader {
                    Section {
                        ForEach(section.destinations) { destination in
                            NavigationSidebarRow(
                                destination: destination,
                                isSelected: navigationState.selectedDestination == destination,
                                badge: badgeCount(for: destination)
                            ) {
                                navigationState.navigate(to: destination)
                            }
                        }
                    } header: {
                        Text(section.rawValue.uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                            .padding(.top, DesignSystem.Spacing.sm)
                    }
                    .listRowInsets(EdgeInsets(
                        top: DesignSystem.Spacing.xs,
                        leading: DesignSystem.Spacing.sm,
                        bottom: DesignSystem.Spacing.xs,
                        trailing: DesignSystem.Spacing.sm
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    // System section (no header)
                    ForEach(section.destinations) { destination in
                        NavigationSidebarRow(
                            destination: destination,
                            isSelected: navigationState.selectedDestination == destination
                        ) {
                            navigationState.navigate(to: destination)
                        }
                    }
                    .listRowInsets(EdgeInsets(
                        top: DesignSystem.Spacing.xs,
                        leading: DesignSystem.Spacing.sm,
                        bottom: DesignSystem.Spacing.xs,
                        trailing: DesignSystem.Spacing.sm
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            
            // Footer
            Spacer()
            
            UserProfileRow()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.secondarySystemBackground))
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

// MARK: - Navigation Sidebar Row

struct NavigationSidebarRow: View {
    let destination: NavigationDestination
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button {
            action()
            NavigationFeedback.selection()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Icon with background
                NavigationIcon(
                    icon: destination.icon,
                    color: destination.iconColor,
                    isSelected: isSelected,
                    isHovered: isHovered
                )
                
                // Title
                Text(destination.title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
                
                Spacer()
                
                // Premium indicator
                if destination.requiresPremium {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.adaptiveOrange)
                }
                
                // Badge if present
                if let badge = badge {
                    Text("\(badge)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, DesignSystem.Spacing.xxs / 2)
                        .background(Capsule().fill(destination.iconColor))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm + 2)
                    .fill(rowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm + 2)
                    .stroke(isSelected ? destination.iconColor.opacity(DesignSystem.Opacity.strong) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var rowBackground: Color {
        if isSelected {
            return destination.iconColor.opacity(DesignSystem.Opacity.light)
        } else if isHovered {
            return Color(UIColor.tertiarySystemFill)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Navigation Icon

struct NavigationIcon: View {
    let icon: String
    let color: Color
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(iconBackground)
                .frame(width: DesignSystem.IconSize.xl, height: DesignSystem.IconSize.xl)
            
            Image(systemName: icon)
                .font(.system(size: DesignSystem.IconSize.sm, weight: .medium))
                .foregroundColor(iconColor)
        }
    }
    
    private var iconBackground: Color {
        if isSelected {
            return color.opacity(DesignSystem.Opacity.medium)
        } else if isHovered {
            return color.opacity(DesignSystem.Opacity.light)
        } else {
            return Color.clear
        }
    }
    
    private var iconColor: Color {
        if isSelected {
            return color
        } else if isHovered {
            return color.opacity(0.8)
        } else {
            return Color(UIColor.secondaryLabel)
        }
    }
}

// MARK: - User Profile Row

struct UserProfileRow: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Settings button
                NavigationLink(destination: SettingsView()) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: DesignSystem.IconSize.sm))
                        Text("Settings")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(Color(UIColor.secondaryLabel))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // User avatar and info
                HStack(spacing: DesignSystem.Spacing.xs) {
                    UserAvatar(size: DesignSystem.IconSize.xl)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                        Text("User")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(UIColor.label))
                        
                        HStack(spacing: 2) {
                            Image(systemName: subscriptionManager.isPremium ? "crown.fill" : "person.fill")
                                .font(.system(size: 8))
                            Text(subscriptionManager.isPremium ? "Premium" : "Free Plan")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(subscriptionManager.isPremium ? .adaptiveOrange : Color(UIColor.secondaryLabel))
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
    }
}

// MARK: - User Avatar

struct UserAvatar: View {
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text("U")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}