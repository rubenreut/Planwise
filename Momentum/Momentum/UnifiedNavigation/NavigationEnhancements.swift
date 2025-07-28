//
//  NavigationEnhancements.swift
//  Momentum
//
//  Additional navigation enhancements and utilities
//

import SwiftUI

// MARK: - Navigation Badge

struct NavigationBadge: View {
    let count: Int
    let color: Color
    
    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(color)
                )
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Navigation Indicator

struct NavigationIndicator: View {
    let isActive: Bool
    let color: Color
    let position: Edge
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: position == .leading || position == .trailing ? 3 : nil,
                   height: position == .top || position == .bottom ? 3 : nil)
            .opacity(isActive ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
    }
}

// MARK: - Adaptive Navigation Title

struct AdaptiveNavigationTitle: View {
    let destination: NavigationDestination
    let style: TitleStyle
    
    enum TitleStyle {
        case inline
        case large
        case automatic
    }
    
    var body: some View {
        switch style {
        case .inline:
            Text(destination.title)
                .font(.system(size: 17, weight: .semibold))
        case .large:
            Text(destination.title)
                .font(.largeTitle)
                .bold()
        case .automatic:
            Text(destination.title)
                .font(DeviceType.isIPad ? .largeTitle : .title2)
                .fontWeight(DeviceType.isIPad ? .bold : .semibold)
        }
    }
}

// MARK: - Navigation Search Bar

struct NavigationSearchBar: View {
    @Binding var searchText: String
    let placeholder: String
    let onSearchSubmit: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: DesignSystem.IconSize.sm))
            
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit(onSearchSubmit)
                .focused($isFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: DesignSystem.IconSize.sm))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(Color(UIColor.tertiarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Navigation Context Menu

struct NavigationContextMenu: ViewModifier {
    let destination: NavigationDestination
    @EnvironmentObject var navigationState: NavigationState
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    navigationState.navigate(to: destination)
                } label: {
                    Label("Open \(destination.title)", systemImage: destination.icon)
                }
                
                if destination.requiresPremium {
                    Button {
                        // Open premium upgrade
                    } label: {
                        Label("Upgrade to Premium", systemImage: "crown.fill")
                    }
                }
                
                Divider()
                
                Button {
                    // Share functionality
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
    }
}

// MARK: - Navigation Accessibility

struct NavigationAccessibility: ViewModifier {
    let destination: NavigationDestination
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(destination.title) tab")
            .accessibilityHint(isSelected ? "Currently selected" : "Double tap to navigate to \(destination.title)")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityValue(destination.section.rawValue)
    }
}

// MARK: - View Extensions

extension View {
    func navigationBadge(_ count: Int, color: Color = .red) -> some View {
        overlay(alignment: .topTrailing) {
            NavigationBadge(count: count, color: color)
                .offset(x: 8, y: -8)
        }
    }
    
    func navigationIndicator(isActive: Bool, color: Color = .accentColor, position: Edge = .leading) -> some View {
        overlay(alignment: position.alignment) {
            NavigationIndicator(isActive: isActive, color: color, position: position)
        }
    }
    
    func navigationContextMenu(for destination: NavigationDestination) -> some View {
        modifier(NavigationContextMenu(destination: destination))
    }
    
    func navigationAccessibility(for destination: NavigationDestination, isSelected: Bool) -> some View {
        modifier(NavigationAccessibility(destination: destination, isSelected: isSelected))
    }
}

private extension Edge {
    var alignment: Alignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}

// MARK: - Navigation Breadcrumb

struct NavigationBreadcrumb: View {
    let path: [NavigationDestination]
    let onTap: (NavigationDestination) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Array(path.enumerated()), id: \.offset) { index, destination in
                    Button {
                        onTap(destination)
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xxs) {
                            Image(systemName: destination.icon)
                                .font(.system(size: DesignSystem.IconSize.xs))
                            
                            Text(destination.title)
                                .font(.caption)
                        }
                        .foregroundColor(index == path.count - 1 ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    if index < path.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: DesignSystem.IconSize.xs))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
    }
}