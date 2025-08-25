//
//  RadialActionMenu.swift
//  Momentum
//
//  Radial menu with icons that fan out around the action button
//

import SwiftUI

struct RadialActionMenu: View {
    @Binding var isShowing: Bool
    let currentTab: NavigationDestination?
    let isVertical: Bool // New parameter to control layout
    let onItemSelected: (ActionMenuItem) -> Void
    
    @State private var animateIcons = false
    @State private var selectedItem: ActionMenuItem?
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    var menuItems: [ActionMenuItem] {
        var items: [ActionMenuItem] = []
        
        // Add context-specific create option based on current tab
        switch currentTab {
        case .tasks:
            items.append(ActionMenuItem(id: "task", title: "Task", icon: "checkmark.circle.fill", color: Color.blue))
        case .day, .week:
            items.append(ActionMenuItem(id: "event", title: "Event", icon: "calendar.badge.plus", color: Color.purple))
        case .habits:
            items.append(ActionMenuItem(id: "habit", title: "Habit", icon: "repeat.circle.fill", color: Color.green))
        case .goals:
            items.append(ActionMenuItem(id: "goal", title: "Goal", icon: "target", color: Color.orange))
        default:
            // Show all create options if not on a specific tab
            items.append(ActionMenuItem(id: "task", title: "Task", icon: "checkmark.circle.fill", color: Color.blue))
            items.append(ActionMenuItem(id: "event", title: "Event", icon: "calendar.badge.plus", color: Color.purple))
            items.append(ActionMenuItem(id: "habit", title: "Habit", icon: "repeat.circle.fill", color: Color.green))
            items.append(ActionMenuItem(id: "goal", title: "Goal", icon: "target", color: Color.orange))
        }
        
        // Always show AI Chat and Settings
        items.append(ActionMenuItem(id: "ai", title: "AI", icon: "sparkles", color: Color.pink))
        items.append(ActionMenuItem(id: "settings", title: "Settings", icon: "gearshape.fill", color: Color.gray))
        
        return items
    }
    
    var body: some View {
        ZStack(alignment: isVertical ? .bottomTrailing : .center) {
            // Invisible tap area to close menu with fade animation
            if isShowing {
                Color.black.opacity(0.001) // Very subtle overlay
                    .contentShape(Rectangle())
                    .onTapGesture {
                        closeMenu()
                    }
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            }
            
            if isVertical {
                // Vertical stack layout for collapsed navbar - aligned to bottom
                VStack(spacing: 10) {
                    ForEach(Array(menuItems.enumerated().reversed()), id: \.element.id) { index, item in
                        VerticalMenuItem(
                            item: item,
                            index: menuItems.count - 1 - index,
                            isAnimated: animateIcons,
                            onTap: {
                                selectItem(item)
                            }
                        )
                        .scaleEffect(animateIcons ? 1 : 0.3)
                        .opacity(animateIcons ? 1 : 0)
                        .offset(y: animateIcons ? 0 : 20)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.7)
                            .delay(Double(menuItems.count - 1 - index) * 0.03),
                            value: animateIcons
                        )
                    }
                }
                .padding(.bottom, 15) // Spacing from FAB button
                // No horizontal padding - will be handled by container
            } else {
                // Radial layout for expanded navbar
                ForEach(Array(menuItems.enumerated()), id: \.element.id) { index, item in
                    RadialMenuItem(
                        item: item,
                        index: index,
                        totalItems: menuItems.count,
                        isAnimated: animateIcons,
                        onTap: {
                            selectItem(item)
                        }
                    )
                    .scaleEffect(animateIcons ? 1 : 0.3)
                    .opacity(animateIcons ? 1 : 0)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.7)
                        .delay(Double(index) * 0.03),
                        value: animateIcons
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.05)) {
                animateIcons = true
            }
        }
    }
    
    private func closeMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            animateIcons = false
        }
        
        NotificationCenter.default.post(name: Notification.Name("CloseCustomActionMenu"), object: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isShowing = false
        }
    }
    
    private func selectItem(_ item: ActionMenuItem) {
        HapticFeedback.selection.trigger()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            selectedItem = item
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            closeMenu()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onItemSelected(item)
            }
        }
    }
}

struct RadialMenuItem: View {
    let item: ActionMenuItem
    let index: Int
    let totalItems: Int
    let isAnimated: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    // Calculate position in arc
    private var angle: Double {
        // Spread items in a semi-circle above the button
        let startAngle = -150.0
        let endAngle = -30.0
        let angleRange = endAngle - startAngle
        
        if totalItems == 1 {
            return -90 // Single item goes straight up
        } else {
            let step = angleRange / Double(totalItems - 1)
            return startAngle + (Double(index) * step)
        }
    }
    
    private var position: CGPoint {
        let radius: CGFloat = 55  // Distance from button - less spread
        let angleInRadians = angle * .pi / 180
        return CGPoint(
            x: CGFloat(cos(angleInRadians)) * radius,
            y: CGFloat(sin(angleInRadians)) * radius
        )
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                item.color.opacity(0.9),
                                item.color.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 1, y: 1)
            }
            .scaleEffect(isPressed ? 0.9 : (isAnimated ? 1.0 : 0.3))
            .opacity(isAnimated ? 1.0 : 0)
            .offset(x: isAnimated ? position.x : 0, y: isAnimated ? position.y : 0)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.6)
                .delay(Double(index) * 0.03),
                value: isAnimated
            )
        }
        .buttonStyle(IconPressStyle(isPressed: $isPressed))
    }
}

struct VerticalMenuItem: View {
    let item: ActionMenuItem
    let index: Int
    let isAnimated: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle with smooth gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                item.color.opacity(isHovered ? 1 : 0.9),
                                item.color.opacity(isHovered ? 0.8 : 0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
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
                    .shadow(color: item.color.opacity(0.3), radius: 8, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                
                // Icon with better visibility
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
            }
            .scaleEffect(isPressed ? 0.85 : (isHovered ? 1.05 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(IconPressStyle(isPressed: $isPressed))
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct IconPressStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
                if newValue {
                    HapticFeedback.light.trigger()
                }
            }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            // Simulate action button position
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 56, height: 56)
                
                RadialActionMenu(
                    isShowing: .constant(true),
                    currentTab: .tasks,
                    isVertical: false
                ) { item in
                    print("Selected: \(item.title)")
                }
            }
            .padding(.bottom, 100)
        }
    }
}