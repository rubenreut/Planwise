//
//  TasksWidget.swift
//  MomentumWidget
//
//  Interactive tasks widget with quick actions
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry
struct TasksEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskItem]
    let configuration: ConfigurationAppIntent
}

struct TaskItem: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let priority: String
    let isCompleted: Bool
    let isOverdue: Bool
}

// MARK: - Tasks Widget
struct TasksWidget: Widget {
    let kind: String = "TasksWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: TasksProvider()) { entry in
            TasksWidgetView(entry: entry)
                .containerBackground(Color(UIColor.systemBackground), for: .widget)
        }
        .configurationDisplayName("Tasks")
        .description("View and manage your tasks")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Timeline Provider
struct TasksProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(date: Date(), tasks: sampleTasks, configuration: ConfigurationAppIntent())
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> TasksEntry {
        let tasks = await fetchTasks(limit: context.family.taskLimit)
        return TasksEntry(date: Date(), tasks: tasks, configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<TasksEntry> {
        let tasks = await fetchTasks(limit: context.family.taskLimit)
        let entry = TasksEntry(date: Date(), tasks: tasks, configuration: configuration)
        
        // Update every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func fetchTasks(limit: Int) async -> [TaskItem] {
        // Fetch from Core Data
        let context = WidgetPersistenceController.shared.container.viewContext
        let request = Task.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Task.priority, ascending: false),
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true)
        ]
        request.fetchLimit = limit
        
        do {
            let tasks = try context.fetch(request)
            return tasks.map { task in
                TaskItem(
                    id: task.objectID.uriRepresentation().absoluteString,
                    title: task.title ?? "Untitled",
                    dueDate: task.dueDate,
                    priority: task.priorityString ?? "medium",
                    isCompleted: task.isCompleted,
                    isOverdue: task.isOverdue
                )
            }
        } catch {
            return []
        }
    }
    
    private var sampleTasks: [TaskItem] {
        [
            TaskItem(id: "1", title: "Review project proposal", dueDate: Date(), priority: "high", isCompleted: false, isOverdue: false),
            TaskItem(id: "2", title: "Call dentist", dueDate: nil, priority: "medium", isCompleted: false, isOverdue: false),
            TaskItem(id: "3", title: "Buy groceries", dueDate: Date().addingTimeInterval(3600), priority: "low", isCompleted: false, isOverdue: false)
        ]
    }
}

// MARK: - Widget Views
struct TasksWidgetView: View {
    let entry: TasksEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallTasksView(tasks: entry.tasks)
        case .systemMedium:
            MediumTasksView(tasks: entry.tasks)
        case .systemLarge:
            LargeTasksView(tasks: entry.tasks)
        case .systemExtraLarge:
            ExtraLargeTasksView(tasks: entry.tasks)
        default:
            EmptyView()
        }
    }
}

struct SmallTasksView: View {
    let tasks: [TaskItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("Tasks")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if tasks.isEmpty {
                Spacer()
                Text("No tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(tasks.prefix(3)) { task in
                    TaskRowCompact(task: task)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct MediumTasksView: View {
    let tasks: [TaskItem]
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - Stats
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checklist")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Tasks")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(tasks.count)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Quick add button
                Link(destination: .addTask) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Task")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Right side - Task list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tasks.prefix(4)) { task in
                    TaskRowCompact(task: task)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

struct LargeTasksView: View {
    let tasks: [TaskItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Tasks")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Link(destination: .addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // Task list with interactive buttons
            VStack(spacing: 12) {
                ForEach(tasks.prefix(6)) { task in
                    TaskRowInteractive(task: task)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ExtraLargeTasksView: View {
    let tasks: [TaskItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .font(.title)
                    .foregroundColor(.blue)
                Text("Tasks")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Link(destination: .addTask) {
                    Label("Add Task", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
            
            // Two column layout
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(tasks.prefix(10)) { task in
                    TaskRowInteractive(task: task)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Task Row Views
struct TaskRowCompact: View {
    let task: TaskItem
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: priorityIcon)
                .font(.caption)
                .foregroundColor(priorityColor)
            
            Text(task.title)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let dueDate = task.dueDate {
                Text(dueDateText(dueDate))
                    .font(.caption2)
                    .foregroundColor(task.isOverdue ? .red : .secondary)
            }
        }
    }
    
    private var priorityIcon: String {
        switch task.priority {
        case "high": return "flag.fill"
        case "medium": return "flag"
        default: return "flag.slash"
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case "high": return .red
        case "medium": return .orange
        default: return .gray
        }
    }
    
    private func dueDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

struct TaskRowInteractive: View {
    let task: TaskItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Complete button
            Button(intent: CompleteTaskIntent(taskId: task.id)) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .strikethrough(task.isCompleted)
                
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(dueDateText(dueDate))
                            .font(.caption)
                    }
                    .foregroundColor(task.isOverdue && !task.isCompleted ? .red : .secondary)
                }
            }
            
            Spacer()
            
            // Priority indicator
            Image(systemName: priorityIcon)
                .font(.caption)
                .foregroundColor(priorityColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var priorityIcon: String {
        switch task.priority {
        case "high": return "flag.fill"
        case "medium": return "flag"
        default: return "flag.slash"
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case "high": return .red
        case "medium": return .orange
        default: return .gray
        }
    }
    
    private func dueDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - App Intents
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    
    @Parameter(title: "Task ID")
    var taskId: String
    
    init() {}
    
    init(taskId: String) {
        self.taskId = taskId
    }
    
    func perform() async throws -> some IntentResult {
        // Update task in Core Data
        let context = WidgetPersistenceController.shared.container.viewContext
        
        guard let url = URL(string: taskId),
              let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url),
              let task = try? context.existingObject(with: objectID) as? Task else {
            return .result()
        }
        
        task.isCompleted = true
        task.completedAt = Date()
        
        try? context.save()
        
        return .result()
    }
}

// MARK: - Widget Family Extensions
extension WidgetFamily {
    var taskLimit: Int {
        switch self {
        case .systemSmall: return 3
        case .systemMedium: return 4
        case .systemLarge: return 6
        case .systemExtraLarge: return 10
        default: return 3
        }
    }
}