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
    @State private var extractedColors: (primary: Color, secondary: Color)? = nil
    
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
            ZStack(alignment: .top) {
                // Background - either custom image or gradient
                if let headerData = SettingsView.loadHeaderImage() {
                    ZStack {
                        // Simple image display
                        GeometryReader { imageGeo in
                            Image(uiImage: headerData.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: imageGeo.size.width)
                                .offset(y: CGFloat(UserDefaults.standard.double(forKey: "headerImageVerticalOffset")))
                        }
                        .frame(height: 280) // Same as DayView
                        .clipped()
                        
                        // Dark overlay
                        Color.black.opacity(0.3)
                            .frame(height: 280)
                    }
                    .frame(height: 280)
                    .ignoresSafeArea()
                } else {
                    // Default blue gradient background - extended beyond visible area
                    ExtendedGradientBackground(
                        colors: [
                            Color(red: 0.05, green: 0.1, blue: 0.25),
                            Color(red: 0.08, green: 0.15, blue: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom,
                        extendFactor: 3.0
                    )
                }
                
                VStack(spacing: 0) {
                    // Header content - EXACTLY like DayView
                    TaskHeaderView(
                        selectedFilter: $selectedFilter,
                        taskCount: taskCount
                    )
                    
                    // Spacer to push white content down  
                    Spacer().frame(height: 0)
                    
                    // White content container with rounded corners
                    ZStack {
                        // Gradient background that extends beyond safe area
                        if let colors = extractedColors {
                            ExtendedGradientBackground(
                                colors: [
                                    colors.primary.opacity(0.8),
                                    colors.primary.opacity(0.6),
                                    colors.secondary.opacity(0.4),
                                    colors.primary.opacity(0.2),
                                    colors.secondary.opacity(0.1),
                                    Color(UIColor.systemBackground).opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom,
                                extendFactor: 3.0
                            )
                            .blur(radius: 2)
                            .allowsHitTesting(false) // Critical: don't block touches
                        }
                        
                        VStack(spacing: 0) {
                            // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search tasks...", text: $searchText)
                                .textFieldStyle(.plain)
                                .bodyLarge()
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemFill))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                        
                        // Task list with view state management
                        Group {
                        switch viewState {
                        case .loading:
                            // Skip loading view for instant display
                            EmptyView()
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
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: -2)
                    .ignoresSafeArea(edges: .bottom)
                    .zIndex(1)
                }
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addTaskButton
                            .padding(.trailing, DesignSystem.Spacing.lg)
                            .padding(.bottom, 82)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadTasks()
        }
        .onAppear {
            // Load extracted colors from header image
            self.extractedColors = UserDefaults.standard.getExtractedColors()
            
            // If no colors saved but we have an image, extract them
            if extractedColors == nil, let headerData = SettingsView.loadHeaderImage() {
                let colors = ColorExtractor.extractColors(from: headerData.image)
                UserDefaults.standard.setExtractedColors(colors)
                self.extractedColors = (colors.primary, colors.secondary)
            }
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
        .fullScreenCover(isPresented: $showingAddTask) {
            AnimatedAddTaskView(isPresented: $showingAddTask)
                .background(ClearBackground())
        }
    }
    
    // MARK: - Components
    
    private var taskList: some View {
        List {
            ForEach(groupedTasks.keys.sorted(), id: \.self) { priority in
                if let tasks = groupedTasks[priority], !tasks.isEmpty {
                    Section {
                        ForEach(tasks) { task in
                            EnhancedTaskCard(task: task) {
                                selectedTask = task
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTask(task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear) 
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        HStack {
                            Image(systemName: priorityIcon(for: priority))
                                .foregroundColor(priorityColor(for: priority))
                                .font(.system(size: 14))
                            Text("\(priority.displayName) Priority")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(tasks.count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .textCase(nil)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    }
                }
            }
            
            // Add bottom padding for floating button
            Color.clear
                .frame(height: 100)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
        
        // Filter out subtasks - only show top-level tasks
        tasks = tasks.filter { task in
            task.parentTask == nil
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
        
        // Load tasks immediately without delay
        await MainActor.run {
            let tasks = self.filteredTasks
            if tasks.isEmpty && searchText.isEmpty {
                viewState = .empty
            } else {
                viewState = .loaded(tasks)
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