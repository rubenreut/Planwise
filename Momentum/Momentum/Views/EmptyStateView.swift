//
//  EmptyStateView.swift
//  Momentum
//
//  Simple, clean empty state view
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                        .scaledIcon()
                    .scaledFont(size: 48, weight: .thin)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.footnote)
                        .fontWeight(.medium)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Keep the config stuff for backwards compatibility but make it simple
struct EmptyStateConfig {
    let illustration: AnyView
    let title: String
    let subtitle: String
    let tip: String?
    let accentColor: Color
    let actions: [EmptyStateAction]
    let showParticles: Bool
    
    init(
        illustration: AnyView = AnyView(EmptyView()),
        title: String,
        subtitle: String,
        tip: String? = nil,
        accentColor: Color = .secondary,
        actions: [EmptyStateAction] = [],
        showParticles: Bool = false
    ) {
        self.illustration = illustration
        self.title = title
        self.subtitle = subtitle
        self.tip = tip
        self.accentColor = accentColor
        self.actions = actions
        self.showParticles = showParticles
    }
}

struct EmptyStateAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let isPrimary: Bool
    let handler: () -> Void
    
    init(
        title: String,
        icon: String? = nil,
        isPrimary: Bool = true,
        handler: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isPrimary = isPrimary
        self.handler = handler
    }
}

// Extension for backward compatibility
extension EmptyStateView {
    init(config: EmptyStateConfig) {
        self.init(
            title: config.title,
            subtitle: config.subtitle,
            icon: nil,
            actionTitle: config.actions.first?.title,
            action: config.actions.first?.handler
        )
    }
}

// Simple preset configs
extension EmptyStateConfig {
    static func noTasks(_ action: @escaping () -> Void) -> EmptyStateConfig {
        EmptyStateConfig(
            title: "No tasks",
            subtitle: "Tap + to create one",
            actions: [EmptyStateAction(title: "Add Task", handler: action)]
        )
    }
    
    static func noSearchResults(query: String) -> EmptyStateConfig {
        EmptyStateConfig(
            title: "No results",
            subtitle: "Try a different search"
        )
    }
    
    static func noTasksToday(showAll: @escaping () -> Void, addTask: @escaping () -> Void) -> EmptyStateConfig {
        EmptyStateConfig(
            title: "No tasks today",
            subtitle: "You're all clear",
            actions: [EmptyStateAction(title: "View All", handler: showAll)]
        )
    }
    
    static var chatWelcome: EmptyStateConfig {
        EmptyStateConfig(
            title: "Ask me anything",
            subtitle: "I can help with tasks, events, and planning"
        )
    }
    
    static func noGoals(_ action: @escaping () -> Void) -> EmptyStateConfig {
        EmptyStateConfig(
            title: "No goals",
            subtitle: "Set a goal to track progress",
            actions: [EmptyStateAction(title: "Add Goal", handler: action)]
        )
    }
    
    static func noHabits(_ action: @escaping () -> Void) -> EmptyStateConfig {
        EmptyStateConfig(
            title: "No habits",
            subtitle: "Start building good habits",
            actions: [EmptyStateAction(title: "Add Habit", handler: action)]
        )
    }
    
    static func noHabitsForDate(date: Date, _ action: @escaping () -> Void) -> EmptyStateConfig {
        EmptyStateConfig(
            title: "No habits for this day",
            subtitle: "Nothing scheduled",
            actions: [EmptyStateAction(title: "Add Habit", handler: action)]
        )
    }
    
    static func noActiveGoals(action: @escaping () -> Void, viewCompleted: @escaping () -> Void) -> EmptyStateConfig {
        EmptyStateConfig(
            title: "No Active Goals",
            subtitle: "All your goals have been completed or you haven't set any yet",
            actions: [
                EmptyStateAction(title: "Add Goal", handler: action),
                EmptyStateAction(title: "View Completed", icon: "checkmark.circle", isPrimary: false, handler: viewCompleted)
            ]
        )
    }
}

// Remove all the illustration views
struct TaskIllustration: View {
    var body: some View { EmptyView() }
}

struct CalendarIllustration: View {
    var body: some View { EmptyView() }
}

struct ScheduleIllustration: View {
    var body: some View { EmptyView() }
}

struct CelebrationIllustration: View {
    var body: some View { EmptyView() }
}

struct GoalIllustration: View {
    var body: some View { EmptyView() }
}

struct HabitIllustration: View {
    var body: some View { EmptyView() }
}

struct SearchIllustration: View {
    var body: some View { EmptyView() }
}

struct NotificationIllustration: View {
    var body: some View { EmptyView() }
}

#Preview {
    EmptyStateView(
        title: "No events",
        subtitle: "Your calendar is empty",
        icon: "calendar",
        actionTitle: "Add Event",
        action: { print("Add tapped") }
    )
}