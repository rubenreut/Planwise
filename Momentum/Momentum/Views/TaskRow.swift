import SwiftUI

struct TaskGlassCard: View {
    let task: Task
    let onTap: () -> Void
    
    @EnvironmentObject private var taskManager: TaskManager
    @State private var isCompleted: Bool = false
    
    private var priorityColor: Color {
        task.priorityEnum.color
    }
    
    private var categoryColor: Color {
        if let hex = task.category?.colorHex {
            return Color(hex: hex)
        }
        return .blue
    }
    
    var body: some View {
        GlassCard(cornerRadius: DesignSystem.CornerRadius.md, padding: 0) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Completion button - simple circle with larger tap area
                Button {
                    toggleCompletion()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: DesignSystem.IconSize.lg))
                        .foregroundColor(isCompleted ? .green : .gray)
                        .frame(width: DesignSystem.IconSize.xxl, height: DesignSystem.IconSize.xxl) // Larger tap target
                        .contentShape(Rectangle()) // Make entire frame tappable
                }
                .buttonStyle(PlainButtonStyle())
                
                // Task content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs - 2) {
                    // Title with priority indicator
                    HStack(spacing: DesignSystem.Spacing.xs - 2) {
                        Text(task.title ?? "Untitled Task")
                            .font(.body)
                            .fontWeight(task.priority == TaskPriority.high.rawValue ? .semibold : .regular)
                            .strikethrough(isCompleted)
                            .foregroundColor(isCompleted ? .secondary : .primary)
                            .lineLimit(2)
                        
                        if task.priority == TaskPriority.high.rawValue {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundColor(priorityColor)
                        }
                    }
                    
                    // Metadata row
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // Due date
                        if let dueDate = task.dueDate {
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Image(systemName: isOverdue(task.dueDate) && !isCompleted ? "exclamationmark.circle.fill" : "calendar")
                                    .font(.caption2)
                                Text(formatDueDate(dueDate))
                                    .font(.caption)
                            }
                            .foregroundColor(isOverdue(task.dueDate) && !isCompleted ? .red : .secondary)
                        }
                        
                        // Subtasks indicator
                        if (task.subtasks?.count ?? 0) > 0 {
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Image(systemName: "list.bullet.indent")
                                    .font(.caption2)
                                Text("\((task.subtasks as? Set<Task>)?.filter { $0.isCompleted }.count ?? 0)/\(task.subtasks?.count ?? 0)")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
        .onAppear {
            isCompleted = task.isCompleted
        }
        .onChange(of: task.isCompleted) { _, newValue in
            isCompleted = newValue
        }
    }
    
    private func isOverdue(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        return date < Date() && !Calendar.current.isDateInToday(date)
    }
    
    private func toggleCompletion() {
        if isCompleted {
            isCompleted = false
            _ = taskManager.uncompleteTask(task)
        } else {
            isCompleted = true
            _ = taskManager.completeTask(task)
        }
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

// Keep the original TaskRow for compatibility
struct TaskRow: View {
    let task: Task
    let onTap: () -> Void
    
    @EnvironmentObject private var taskManager: TaskManager
    @State private var isCompleted: Bool = false
    
    private var priorityColor: Color {
        task.priorityEnum.color
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Completion button
            Button {
                HapticFeedback.success.trigger()
                toggleCompletion()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(isCompleted ? Color.green : Color.secondary.opacity(DesignSystem.Opacity.disabled), lineWidth: 2)
                        .frame(width: DesignSystem.IconSize.lg, height: DesignSystem.IconSize.lg)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: DesignSystem.Spacing.sm, weight: .bold))
                            .foregroundColor(.green)
                            .transition(.identity)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Task content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                HStack {
                    Text(task.title ?? "Untitled Task")
                        .font(.body)
                        .fontWeight(task.priority == TaskPriority.high.rawValue ? .semibold : .regular)
                        .strikethrough(isCompleted)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                    
                    Spacer()
                    
                    // Priority indicator
                    if task.priority == TaskPriority.high.rawValue {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(priorityColor)
                    }
                }
                
                // Metadata row
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Due date
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: task.isOverdue && !isCompleted ? "exclamationmark.circle.fill" : "calendar")
                                .font(.caption2)
                            Text(formatDueDate(dueDate))
                                .font(.caption)
                        }
                        .foregroundColor(task.isOverdue && !isCompleted ? .red : .secondary)
                    }
                    
                    // Category
                    if let category = task.category {
                        HStack(spacing: 4) {
                            Image(systemName: category.iconName ?? "folder.fill")
                                .font(.caption2)
                            Text(category.name ?? "")
                                .font(.caption)
                        }
                        .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                    }
                    
                    // Tags
                    if !task.tagsArray.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.caption2)
                            Text(task.tagsArray.first ?? "")
                                .font(.caption)
                            if task.tagsArray.count > 1 {
                                Text("+\(task.tagsArray.count - 1)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    // Subtasks
                    if task.hasSubtasks {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet.indent")
                                .font(.caption2)
                            Text("\(task.completedSubtaskCount)/\(task.totalSubtaskCount)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Notes preview
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            // Chevron for details
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            isCompleted = task.isCompleted
        }
        .onChange(of: task.isCompleted) { _, newValue in
            isCompleted = newValue
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleCompletion() {
        if isCompleted {
            isCompleted = false
            _ = taskManager.uncompleteTask(task)
        } else {
            isCompleted = true
            _ = taskManager.completeTask(task)
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Tomorrow \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: now, to: date).day {
            if days > 0 && days < 7 {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE" // Day name
                return formatter.string(from: date)
            } else if days < 0 {
                // Don't show overdue for completed tasks
                if task.isCompleted {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    return formatter.string(from: date)
                }
                return "\(abs(days)) days overdue"
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    List {
        TaskRow(task: createSampleTask()) {
        }
    }
    .environmentObject(TaskManager.shared)
}

// Preview helper
private func createSampleTask() -> Task {
    let context = PersistenceController.preview.container.viewContext
    let task = Task(context: context)
    task.id = UUID()
    task.title = "Review presentation slides"
    task.notes = "Make sure to include Q4 metrics and update the roadmap section"
    task.priority = TaskPriority.high.rawValue
    task.dueDate = Date().addingTimeInterval(3600) // 1 hour from now
    task.isCompleted = false
    task.createdAt = Date()
    return task
}
