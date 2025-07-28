//
//  HierarchyComponents.swift
//  Momentum
//
//  Improved visual hierarchy components for better readability and information structure
//

import SwiftUI

// MARK: - Enhanced Filter Pill
struct EnhancedFilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                // Icon with proper size
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.IconSize.sm, weight: .medium))
                
                // Title with proper typography
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                
                // Count badge with improved visibility
                if count > 0 {
                    Text("\(count)")
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.bold)
                        .foregroundColor(badgeTextColor)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(badgeBackground)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(pillBackground)
            .foregroundColor(pillForegroundColor)
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: isSelected ? 0 : 1)
            )
            .clipShape(Capsule())
            .shadow(
                color: isSelected ? shadowColor : Color.clear,
                radius: isSelected ? 4 : 0,
                y: isSelected ? 2 : 0
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var pillBackground: some View {
        Group {
            if isSelected {
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.accent,
                        DesignSystem.Colors.accent.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(colorScheme == .dark ? UIColor.secondarySystemBackground : UIColor.tertiarySystemBackground)
            }
        }
    }
    
    private var pillForegroundColor: Color {
        isSelected ? .white : DesignSystem.Colors.primary
    }
    
    private var badgeBackground: some View {
        Group {
            if isSelected {
                Color.white.opacity(0.9)
            } else {
                DesignSystem.Colors.accent.opacity(0.15)
            }
        }
    }
    
    private var badgeTextColor: Color {
        if isSelected {
            return DesignSystem.Colors.accent
        } else {
            return DesignSystem.Colors.accent
        }
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    
    private var shadowColor: Color {
        DesignSystem.Colors.accent.opacity(0.3)
    }
}

// MARK: - Enhanced Section Header
struct EnhancedSectionHeader: View {
    let title: String
    let icon: String?
    let iconColor: Color
    let count: Int?
    let action: (() -> Void)?
    
    init(
        title: String,
        icon: String? = nil,
        iconColor: Color = DesignSystem.Colors.secondary,
        count: Int? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.count = count
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Icon with colored background
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.IconSize.sm, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(iconColor.opacity(0.15))
                    )
            }
            
            // Title
            Text(title)
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primary)
            
            // Count badge
            if let count = count {
                Text("\(count)")
                    .font(DesignSystem.Typography.caption1)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.tertiaryFill)
                    )
            }
            
            Spacer()
            
            // Action button
            if action != nil {
                Button(action: action!) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignSystem.IconSize.xs, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiary)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.secondaryBackground.opacity(0.5))
                .ignoresSafeArea(edges: .horizontal)
        )
    }
}

// MARK: - Priority Indicator
struct PriorityIndicator: View {
    let priority: TaskPriority
    let size: PriorityIndicatorSize
    
    enum PriorityIndicatorSize {
        case small, medium, large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority.icon)
                .font(.system(size: size.iconSize, weight: .bold))
            
            if size != .small {
                Text(priority.displayName)
                    .font(size == .large ? DesignSystem.Typography.caption1 : DesignSystem.Typography.caption2)
                    .fontWeight(.semibold)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, size.padding)
        .padding(.vertical, size.padding / 2)
        .background(
            Capsule()
                .fill(priority.color)
        )
        .shadow(color: priority.color.opacity(0.3), radius: 2, y: 1)
    }
}

// MARK: - Enhanced Task Card
struct EnhancedTaskCard: View {
    let task: Task
    let onTap: () -> Void
    
    @EnvironmentObject private var taskManager: TaskManager
    @State private var isCompleted: Bool = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main content
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Completion button
                    Button {
                        HapticFeedback.success.trigger()
                        toggleCompletion()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    isCompleted ? Color.green : Color.secondary.opacity(0.3),
                                    lineWidth: isCompleted ? 3 : 2
                                )
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(isCompleted ? Color.green.opacity(0.1) : Color.clear)
                                )
                            
                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.green)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Task content
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        // Title row
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Text(task.title ?? "Untitled Task")
                                .font(DesignSystem.Typography.body)
                                .fontWeight(task.priority == TaskPriority.high.rawValue ? .semibold : .regular)
                                .strikethrough(isCompleted)
                                .foregroundColor(isCompleted ? .secondary : .primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer(minLength: 0)
                            
                            // Priority indicator
                            if task.priority == TaskPriority.high.rawValue {
                                PriorityIndicator(
                                    priority: .high,
                                    size: .medium
                                )
                            }
                        }
                        
                        // Metadata row
                        HStack(spacing: DesignSystem.Spacing.md) {
                            // Due date with emphasis
                            if let dueDate = task.dueDate {
                                HStack(spacing: 4) {
                                    Image(systemName: isOverdue(task.dueDate) && !isCompleted ? "exclamationmark.circle.fill" : "calendar")
                                        .font(.system(size: 14, weight: .medium))
                                    Text(formatDueDate(dueDate))
                                        .font(DesignSystem.Typography.footnote)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(isOverdue(task.dueDate) && !isCompleted ? .red : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill((isOverdue(task.dueDate) && !isCompleted ? Color.red : Color.secondary).opacity(0.1))
                                )
                            }
                            
                            // Category badge
                            if let category = task.category, let categoryName = category.name {
                                HStack(spacing: 4) {
                                    Image(systemName: category.iconName ?? "folder.fill")
                                        .font(.system(size: 12))
                                    Text(categoryName)
                                        .font(DesignSystem.Typography.caption1)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: category.colorHex ?? "#007AFF").opacity(0.1))
                                )
                            }
                            
                            // Subtasks progress
                            if (task.subtasks?.count ?? 0) > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "checklist")
                                        .font(.system(size: 12))
                                    Text("\((task.subtasks as? Set<Task>)?.filter { $0.isCompleted }.count ?? 0)/\(task.subtasks?.count ?? 0)")
                                        .font(DesignSystem.Typography.caption1)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiary)
                }
                .padding(DesignSystem.Spacing.md)
                
                // Notes preview (if available)
                if let notes = task.notes, !notes.isEmpty, !isCompleted {
                    HStack {
                        Text(notes)
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.horizontal, DesignSystem.Spacing.md + 44 + DesignSystem.Spacing.md)
                            .padding(.bottom, DesignSystem.Spacing.md)
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.secondaryBackground)
                .shadow(
                    color: DesignSystem.Elevation.low.color,
                    radius: DesignSystem.Elevation.low.radius,
                    x: 0,
                    y: DesignSystem.Elevation.low.y
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(
                    task.priority == TaskPriority.high.rawValue ? 
                    TaskPriority.high.color.opacity(0.3) : 
                    Color.clear,
                    lineWidth: 1
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
        .onAppear {
            isCompleted = task.isCompleted
        }
        .onChange(of: task.isCompleted) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCompleted = newValue
            }
        }
    }
    
    private func toggleCompletion() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if isCompleted {
                isCompleted = false
                _ = taskManager.uncompleteTask(task)
            } else {
                isCompleted = true
                _ = taskManager.completeTask(task)
            }
        }
    }
    
    private func isOverdue(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        return date < Date() && !Calendar.current.isDateInToday(date)
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: now, to: date).day {
            if days > 0 && days < 7 {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return formatter.string(from: date)
            } else if days < 0 {
                if task.isCompleted {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    return formatter.string(from: date)
                }
                return "Overdue"
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Visual Separator
struct VisualSeparator: View {
    let style: SeparatorStyle
    
    enum SeparatorStyle {
        case light, medium, heavy
        
        var height: CGFloat {
            switch self {
            case .light: return 1
            case .medium: return 8
            case .heavy: return 12
            }
        }
        
        var color: Color {
            switch self {
            case .light: return DesignSystem.Colors.separator
            case .medium, .heavy: return DesignSystem.Colors.tertiaryBackground
            }
        }
    }
    
    init(style: SeparatorStyle = .medium) {
        self.style = style
    }
    
    var body: some View {
        Rectangle()
            .fill(style.color)
            .frame(height: style.height)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Info Badge
struct InfoBadge: View {
    let text: String
    let icon: String?
    let color: Color
    let style: BadgeStyle
    
    enum BadgeStyle {
        case filled, outlined, subtle
    }
    
    init(
        _ text: String,
        icon: String? = nil,
        color: Color = DesignSystem.Colors.accent,
        style: BadgeStyle = .subtle
    ) {
        self.text = text
        self.icon = icon
        self.color = color
        self.style = style
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
            }
            Text(text)
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.medium)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(background)
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: style == .outlined ? 1 : 0)
        )
        .clipShape(Capsule())
    }
    
    private var foregroundColor: Color {
        switch style {
        case .filled:
            return .white
        case .outlined, .subtle:
            return color
        }
    }
    
    private var background: some View {
        Group {
            switch style {
            case .filled:
                color
            case .outlined:
                Color.clear
            case .subtle:
                color.opacity(0.15)
            }
        }
    }
    
    private var borderColor: Color {
        style == .outlined ? color : Color.clear
    }
}

// MARK: - Extensions
extension TaskPriority {
    var icon: String {
        switch self {
        case .high: return "flag.fill"
        case .medium: return "flag"
        case .low: return "flag.slash"
        }
    }
    
    // displayName is already defined in TaskManager.swift
}