import SwiftUI
import CoreData

struct TaskListViewPremium: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var taskManager: TaskManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @State private var selectedFilter = TaskFilter.all
    @State private var searchText = ""
    @State private var showingAddTask = false
    @State private var showingTaskDetail = false
    @State private var selectedTask: Task?
    @State private var hoveredTaskId: UUID? = nil
    @Environment(\.colorScheme) var colorScheme
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case upcoming = "Upcoming"
        case overdue = "Overdue"
        case unscheduled = "Unscheduled"
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .today: return "star.fill"
            case .upcoming: return "calendar"
            case .overdue: return "exclamationmark.triangle.fill"
            case .unscheduled: return "tray"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Premium background that adapts to color scheme
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGray6))
                    .ignoresSafeArea()
                
                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        Color.blue.opacity(colorScheme == .dark ? 0.03 : 0.02),
                        Color.clear,
                        Color.purple.opacity(colorScheme == .dark ? 0.02 : 0.01)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 0) {
                    // Custom header
                    customHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                    
                    // Filter section with metrics
                    filterSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    
                    // Task list
                    if filteredTasks.isEmpty {
                        emptyStateView
                    } else {
                        taskList
                    }
                }
                
                // Premium floating add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addTaskButton
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarHidden(DeviceType.isIPad ? false : true) // Show nav bar on iPad for sidebar toggle
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView()
        }
    }
    
    // MARK: - Components
    
    private var customHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tasks")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Text("\(taskManager.tasks.filter { !$0.isCompleted }.count) active")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Premium menu button
                Menu {
                    Button {
                        // Sort by priority
                    } label: {
                        Label("Priority", systemImage: "flag")
                    }
                    
                    Button {
                        // Sort by due date
                    } label: {
                        Label("Due Date", systemImage: "calendar")
                    }
                    
                    Button {
                        // Sort by created date
                    } label: {
                        Label("Created", systemImage: "clock")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 44, height: 44)
                        )
                }
            }
            
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                TextField("Search tasks...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .font(.system(size: 16))
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    PremiumFilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        count: taskCount(for: filter)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
    }
    
    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedTasks.keys.sorted(by: { $0.rawValue > $1.rawValue }), id: \.self) { priority in
                    if let tasks = groupedTasks[priority], !tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            // Premium section header
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(priorityColor(for: priority))
                                    .frame(width: 6, height: 6)
                                
                                Text(priority.displayName.uppercased())
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.2)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            
                            ForEach(tasks) { task in
                                PremiumTaskCard(
                                    task: task,
                                    isHovered: hoveredTaskId == task.id
                                ) {
                                    selectedTask = task
                                }
                                .padding(.horizontal, 24)
                                .onHover { isHovered in
                                    hoveredTaskId = isHovered ? task.id : nil
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteTask(task)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    if !task.isCompleted {
                                        Button {
                                            completeTask(task)
                                        } label: {
                                            Label("Complete", systemImage: "checkmark")
                                        }
                                    } else {
                                        Button {
                                            uncompleteTask(task)
                                        } label: {
                                            Label("Reopen", systemImage: "arrow.uturn.backward")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, priority == groupedTasks.keys.sorted(by: { $0.rawValue > $1.rawValue }).last ? 100 : 0)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.1),
                                Color.blue.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(emptyStateMessage)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if selectedFilter != .all {
                Button {
                    selectedFilter = .all
                } label: {
                    Text("Show All Tasks")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    private var addTaskButton: some View {
        Button {
            showingAddTask = true
        } label: {
            ZStack {
                // Gradient background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue,
                                Color.blue.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                // Glow effect
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                    .blur(radius: 20)
                    .opacity(0.3)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Computed Properties
    
    private var filteredTasks: [Task] {
        var tasks: [Task] = []
        
        switch selectedFilter {
        case .all:
            tasks = taskManager.tasks
        case .today:
            tasks = taskManager.tasks(for: Date())
        case .upcoming:
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            tasks = taskManager.tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= tomorrow
            }
        case .overdue:
            tasks = taskManager.overdueTasks()
        case .unscheduled:
            tasks = taskManager.unscheduledTasks()
        }
        
        if !searchText.isEmpty {
            tasks = tasks.filter { task in
                (task.title ?? "").localizedCaseInsensitiveContains(searchText) ||
                (task.notes ?? "").localizedCaseInsensitiveContains(searchText) ||
                task.tagsArray.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return tasks
    }
    
    private var groupedTasks: [TaskPriority: [Task]] {
        Dictionary(grouping: filteredTasks) { task in
            TaskPriority(rawValue: task.priority) ?? .medium
        }
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: return "checkmark.rectangle.stack"
        case .today: return "star"
        case .upcoming: return "calendar"
        case .overdue: return "exclamationmark.triangle"
        case .unscheduled: return "tray"
        }
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "No Tasks Yet"
        case .today: return "No Tasks Today"
        case .upcoming: return "No Upcoming Tasks"
        case .overdue: return "No Overdue Tasks"
        case .unscheduled: return "No Unscheduled Tasks"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all: return "Create your first task to get started"
        case .today: return "You're all caught up for today!"
        case .upcoming: return "No tasks scheduled for the future"
        case .overdue: return "Great! You have no overdue tasks"
        case .unscheduled: return "All your tasks have been scheduled"
        }
    }
    
    // MARK: - Helper Methods
    
    private func taskCount(for filter: TaskFilter) -> Int {
        switch filter {
        case .all:
            return taskManager.tasks.count
        case .today:
            return taskManager.tasks(for: Date()).count
        case .upcoming:
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            return taskManager.tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= tomorrow
            }.count
        case .overdue:
            return taskManager.overdueTasks().count
        case .unscheduled:
            return taskManager.unscheduledTasks().count
        }
    }
    
    private func priorityIcon(for priority: TaskPriority) -> String {
        switch priority {
        case .high: return "flag.fill"
        case .medium: return "flag"
        case .low: return "flag.slash"
        }
    }
    
    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .high: return Color(hex: "#FF5757")
        case .medium: return Color(hex: "#FFB657")
        case .low: return Color(hex: "#65D565")
        }
    }
    
    private func completeTask(_ task: Task) {
        withAnimation {
            _ = taskManager.completeTask(task)
        }
    }
    
    private func uncompleteTask(_ task: Task) {
        withAnimation {
            _ = taskManager.uncompleteTask(task)
        }
    }
    
    private func deleteTask(_ task: Task) {
        withAnimation {
            _ = taskManager.deleteTask(task)
        }
    }
}

// MARK: - Premium Task Card

struct PremiumTaskCard: View {
    let task: Task
    let isHovered: Bool
    let onTap: () -> Void
    
    @EnvironmentObject private var taskManager: TaskManager
    @State private var isCompleted: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    private var priorityColor: Color {
        switch task.priorityEnum {
        case .high: return Color(hex: "#FF5757")
        case .medium: return Color(hex: "#FFB657")
        case .low: return Color(hex: "#65D565")
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Modern checkbox with larger tap area
            Button {
                toggleCompletion()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCompleted ? priorityColor : Color.gray.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    
                    if isCompleted {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(priorityColor)
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44) // Larger tap target
                .contentShape(Rectangle()) // Make entire frame tappable
            }
            .buttonStyle(PlainButtonStyle())
            
            // Task content
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title ?? "Untitled Task")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isCompleted ? .secondary : (colorScheme == .dark ? .white : .black))
                    .strikethrough(isCompleted, color: .secondary)
                    .lineLimit(2)
                
                // Metadata
                HStack(spacing: 16) {
                    if let dueDate = task.dueDate {
                        HStack(spacing: 6) {
                            Image(systemName: task.isOverdue && !isCompleted ? "clock.badge.exclamationmark" : "clock")
                                .font(.system(size: 12))
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(task.isOverdue && !isCompleted ? Color(hex: "#FF5757") : .secondary)
                    }
                    
                    if task.hasSubtasks {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 12))
                            Text("\(task.completedSubtaskCount)/\(task.totalSubtaskCount)")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let category = task.category {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: category.colorHex ?? "#007AFF"))
                                .frame(width: 8, height: 8)
                            Text(category.name ?? "")
                                .font(.system(size: 13))
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Priority indicator
            if task.priority == TaskPriority.high.rawValue {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14))
                    .foregroundColor(priorityColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(isHovered ? 0.2 : 0.15),
                                    Color.gray.opacity(isHovered ? 0.15 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: isHovered ? 12 : 8, x: 0, y: isHovered ? 6 : 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
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
    
    private func toggleCompletion() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if isCompleted {
            withAnimation(.easeInOut(duration: 0.3)) {
                isCompleted = false
            }
            _ = taskManager.uncompleteTask(task)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                isCompleted = true
            }
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

// MARK: - Premium Filter Chip

struct PremiumFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)))
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)),
                                lineWidth: 0.5
                            )
                    )
            )
            .foregroundColor(isSelected ? .white : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    TaskListViewPremium()
        .environmentObject(TaskManager.shared)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}