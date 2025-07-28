import SwiftUI
import CoreData


struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var taskManager: TaskManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @State private var selectedFilter = TaskFilter.all
    @State private var searchText = ""
    @State private var showingAddTask = false
    @State private var showingTaskDetail = false
    @State private var selectedTask: Task?
    @State private var viewState: ViewState<[Task]> = .loading
    @State private var isRefreshing = false
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case upcoming = "Upcoming"
        case overdue = "Overdue"
        case unscheduled = "Unscheduled"
        
        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .today: return "star"
            case .upcoming: return "calendar"
            case .overdue: return "exclamationmark.circle"
            case .unscheduled: return "tray"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.softBackground
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 0) {
                    // Filter pills
                    filterPills
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    
                    // Task list with view state management
                    Group {
                        switch viewState {
                        case .loading:
                            LoadingView(style: .skeleton(.taskList))
                        case .loaded(let tasks):
                            if tasks.isEmpty {
                                emptyStateView
                            } else {
                                taskList
                                    .refreshable {
                                        await refreshTasks()
                                    }
                            }
                        case .error(let error):
                            ErrorView(
                                error: error,
                                retry: {
                                    _Concurrency.Task {
                                        await loadTasks()
                                    }
                                }
                            )
                        case .empty:
                            emptyStateView
                        }
                    }
                    .transition(.opacity)
                }
                .navigationTitle("Tasks")
                .navigationBarTitleDisplayMode(DeviceType.isMac ? .large : .large)
                .searchable(text: $searchText, prompt: "Search tasks...")
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addTaskButton
                            .padding(.trailing, DesignSystem.Adaptive.value(iPhone: DesignSystem.Spacing.lg - 4, iPad: DesignSystem.Spacing.xl - 2, mac: DesignSystem.Spacing.xl - 2))
                            .padding(.bottom, DesignSystem.Adaptive.value(iPhone: DesignSystem.Spacing.lg - 4, iPad: DesignSystem.Spacing.xl - 2, mac: DesignSystem.Spacing.xl - 2))
                    }
                }
            }
        }
        .task {
            await loadTasks()
        }
        .onChange(of: selectedFilter) { _, _ in
            _Concurrency.Task {
                await loadTasks()
            }
        }
        .onChange(of: searchText) { _, _ in
            _Concurrency.Task {
                await loadTasks()
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.regularMaterial)
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.regularMaterial)
        }
    }
    
    // MARK: - Components
    
    
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    EnhancedFilterPill(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        count: taskCount(for: filter)
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
    
    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groupedTasks.keys.sorted(), id: \.self) { priority in
                    if let tasks = groupedTasks[priority], !tasks.isEmpty {
                        VStack(spacing: 0) {
                            // Visual separator between sections
                            if priority != groupedTasks.keys.sorted().first {
                                VisualSeparator(style: .medium)
                            }
                            
                            // Section header with improved visibility
                            EnhancedSectionHeader(
                                title: "\(priority.displayName) Priority",
                                icon: priorityIcon(for: priority),
                                iconColor: priorityColor(for: priority),
                                count: tasks.count
                            )
                            
                            // Tasks with proper spacing
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(tasks) { task in
                                    EnhancedTaskCard(task: task) {
                                        selectedTask = task
                                    }
                                    .padding(.horizontal)
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
                            .padding(.vertical, DesignSystem.Spacing.md)
                        }
                        .padding(.bottom, priority == groupedTasks.keys.sorted().last ? DesignSystem.Spacing.xxxl + DesignSystem.Spacing.xl + 4 : 0)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        Group {
            if !searchText.isEmpty {
                EmptyStateView(config: .noSearchResults(query: searchText))
            } else {
                emptyStateForFilter
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateForFilter: some View {
        switch selectedFilter {
        case .all:
            EmptyStateView(config: .noTasks {
                showingAddTask = true
            })
        case .today:
            todayEmptyState
        case .upcoming:
            upcomingEmptyState
        case .overdue:
            overdueEmptyState
        case .unscheduled:
            unscheduledEmptyState
        }
    }
    
    @ViewBuilder
    private var todayEmptyState: some View {
        if taskManager.tasks.isEmpty {
            EmptyStateView(config: .noTasks {
                showingAddTask = true
            })
        } else {
            EmptyStateView(config: .noTasksToday(
                showAll: { selectedFilter = .all },
                addTask: { showingAddTask = true }
            ))
        }
    }
    
    private var upcomingEmptyState: some View {
        EmptyStateView(
            title: "No upcoming tasks",
            subtitle: "Nothing scheduled yet",
            icon: "calendar",
            actionTitle: "Add Task",
            action: { showingAddTask = true }
        )
    }
    
    private var overdueEmptyState: some View {
        EmptyStateView(
            title: "No overdue tasks",
            subtitle: "You're all caught up",
            icon: "checkmark.circle"
        )
    }
    
    private var unscheduledEmptyState: some View {
        EmptyStateView(
            title: "All tasks scheduled",
            subtitle: "Everything has a date",
            icon: "calendar.badge.checkmark"
        )
    }
    
    private var addTaskButton: some View {
        FloatingActionButton(
            icon: "plus",
            accessibilityLabel: "Add new task"
        ) {
            showingAddTask = true
        }
        .accessibilityHint("Opens task creation view")
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
        
        // Apply search filter
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
        priority.color
    }
    
    private func completeTask(_ task: Task) {
        _ = taskManager.completeTask(task)
    }
    
    private func uncompleteTask(_ task: Task) {
        _ = taskManager.uncompleteTask(task)
    }
    
    private func deleteTask(_ task: Task) {
        _ = taskManager.deleteTask(task)
    }
    
    private func refreshTasks() async {
        isRefreshing = true
        
        // Give haptic feedback
        HapticFeedback.light.trigger()
        
        // Force Core Data to refresh
        await MainActor.run {
            taskManager.objectWillChange.send()
        }
        
        // Small delay to show refresh animation
        try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await loadTasks()
        isRefreshing = false
    }
    
    private func loadTasks() async {
        guard !isRefreshing else { return }
        
        await MainActor.run {
            viewState = .loading
        }
        
        // Simulate async loading
        do {
            try await _Concurrency.Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds for better UX
            
            await MainActor.run {
                let tasks = self.filteredTasks
                if tasks.isEmpty && searchText.isEmpty {
                    viewState = .empty
                } else {
                    viewState = .loaded(tasks)
                }
            }
        } catch {
            await MainActor.run {
                viewState = .error(error)
            }
        }
    }
}

// MARK: - Supporting Views

// MARK: - Preview

#Preview {
    TaskListView()
        .environmentObject(TaskManager.shared)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}