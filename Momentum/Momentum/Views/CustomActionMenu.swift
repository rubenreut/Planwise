//
//  CustomActionMenu.swift
//  Momentum
//
//  Custom animated action menu to replace default iOS menu
//

import SwiftUI

struct CustomActionMenu: View {
    @Binding var isShowing: Bool
    let currentTab: NavigationDestination?
    let onItemSelected: (ActionMenuItem) -> Void
    
    @State private var animateItems = false
    @State private var animateBackground = false
    @State private var dragOffset: CGSize = .zero
    @State private var selectedItem: ActionMenuItem?
    
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @Namespace private var animation
    
    var menuItems: [ActionMenuItem] {
        var items: [ActionMenuItem] = []
        
        // Add context-specific create option based on current tab
        switch currentTab {
        case .tasks:
            items.append(ActionMenuItem(id: "task", title: "Add Task", icon: "checkmark.circle.fill", color: Color.blue))
        case .day, .week:
            items.append(ActionMenuItem(id: "event", title: "Add Event", icon: "calendar.badge.plus", color: Color.purple))
        case .habits:
            items.append(ActionMenuItem(id: "habit", title: "Add Habit", icon: "repeat.circle.fill", color: Color.green))
        case .goals:
            items.append(ActionMenuItem(id: "goal", title: "Add Goal", icon: "target", color: Color.orange))
        default:
            // Show all create options if not on a specific tab
            items.append(ActionMenuItem(id: "task", title: "Task", icon: "checkmark.circle", color: Color.blue))
            items.append(ActionMenuItem(id: "event", title: "Event", icon: "calendar", color: Color.purple))
            items.append(ActionMenuItem(id: "habit", title: "Habit", icon: "repeat", color: Color.green))
            items.append(ActionMenuItem(id: "goal", title: "Goal", icon: "target", color: Color.orange))
        }
        
        // Always show AI Chat and Settings
        items.append(ActionMenuItem(id: "ai", title: "AI Chat", icon: "sparkles", color: Color.pink))
        items.append(ActionMenuItem(id: "settings", title: "Settings", icon: "gearshape.fill", color: Color.gray))
        
        return items
    }
    
    var body: some View {
        let _ = print("🟢 CustomActionMenu rendering, isShowing: \(isShowing), animateBackground: \(animateBackground)")
        return ZStack {
            // Background overlay
            Color.black
                .opacity(animateBackground ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    closeMenu()
                }
                .allowsHitTesting(animateBackground)
            
            // Menu container
            VStack(spacing: 0) {
                Spacer()
                
                // Menu content
                VStack(spacing: 12) {
                        // Handle bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 5)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        
                        // Menu items grid - dynamic columns based on item count
                        LazyVGrid(columns: menuItems.count <= 3 ? 
                                 Array(repeating: GridItem(.flexible()), count: min(3, menuItems.count)) :
                                 [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], 
                                 spacing: 20) {
                            ForEach(Array(menuItems.enumerated()), id: \.element.id) { index, item in
                                MenuItemView(
                                    item: item,
                                    isSelected: selectedItem?.id == item.id,
                                    animationDelay: Double(index) * 0.05,
                                    animateItems: animateItems,
                                    namespace: animation
                                ) {
                                    selectItem(item)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 30, y: -10)
                    )
                    .offset(y: animateItems ? 0 : 300)
                    .offset(dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 100 {
                                    closeMenu()
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: animateItems)
        .onAppear {
            showMenu()
        }
    }
    
    private func showMenu() {
        print("🟡 showMenu called")
        withAnimation(.easeOut(duration: 0.2)) {
            animateBackground = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            animateItems = true
        }
    }
    
    private func closeMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            animateItems = false
            animateBackground = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isShowing = false
            selectedItem = nil
            dragOffset = .zero
        }
    }
    
    private func selectItem(_ item: ActionMenuItem) {
        // Haptic feedback
        HapticFeedback.selection.trigger()
        
        // Animate selection
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedItem = item
        }
        
        // Close menu and trigger action
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            closeMenu()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onItemSelected(item)
            }
        }
    }
}

struct MenuItemView: View {
    let item: ActionMenuItem
    let isSelected: Bool
    let animationDelay: Double
    let animateItems: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon container
                ZStack {
                    // Background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected ? 
                                    [item.color, item.color.opacity(0.7)] :
                                    [item.color.opacity(0.15), item.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected ? 
                                        item.color.opacity(0.5) :
                                        Color.white.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isSelected ? item.color.opacity(0.4) : Color.clear,
                            radius: 8,
                            y: 4
                        )
                    
                    // Icon
                    Image(systemName: item.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .white : item.color)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                
                // Label
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .opacity(0.9)
            }
            .opacity(animateItems ? 1 : 0)
            .scaleEffect(animateItems ? 1 : 0.5)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.7)
                .delay(animateItems ? animationDelay : 0),
                value: animateItems
            )
        }
        .buttonStyle(CustomMenuButtonStyle(isPressed: $isPressed))
    }
}

struct CustomMenuButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = newValue
                }
            }
    }
}

struct ActionMenuItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
}

// MARK: - Integration Helper
extension CustomActionMenu {
    static func present(from parent: Binding<Bool>, currentTab: NavigationDestination?, onItemSelected: @escaping (ActionMenuItem) -> Void) -> some View {
        CustomActionMenu(isShowing: parent, currentTab: currentTab, onItemSelected: onItemSelected)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showMenu = true
        
        var body: some View {
            ZStack {
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()
                
                VStack {
                    Button("Show Menu") {
                        showMenu = true
                    }
                    .padding()
                }
                
                CustomActionMenu(isShowing: $showMenu, currentTab: .tasks) { item in
                    print("Selected: \(item.title)")
                }
            }
        }
    }
    
    return PreviewWrapper()
}