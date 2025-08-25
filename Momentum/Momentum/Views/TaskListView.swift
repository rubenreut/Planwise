import SwiftUI
import CoreData

struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
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
    @State private var showingCompletedTasks = false
    @State private var expandedCompletedFolder = false
    @State private var selectedCompletedFilter = CompletedTaskFilter.today
    
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
    
    enum CompletedTaskFilter: String, CaseIterable {
        case today = "Today"
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case all = "All Time"
        
        var dateRange: (start: Date?, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .today:
                let start = calendar.startOfDay(for: now)
                return (start, now)
            case .lastWeek:
                let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
                return (start, now)
            case .lastMonth:
                let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                return (start, now)
            case .all:
                return (nil, now)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Super light gray background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
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
                                Color(red: 0.08, green: 0.15, blue: 0.35),
                                Color(red: 0.12, green: 0.25, blue: 0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                            extendFactor: 2.0
                        )
                        .frame(height: 280)
                        .ignoresSafeArea()
                    }
                
                VStack(spacing: 0) {
                    GeometryReader { geometry in
                        ZStack(alignment: .top) {
                            // Place holder for maintaining structure
                            Color.clear
                            
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
                                    // Gradient background that extends beyond safe area - same as HabitsView
                                    gradientBackground
                                    
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
                        
                        // Completed Tasks Section
                        completedTasksSection
                        .padding(.horizontal, 20)
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
                                    .background(Color.clear)
                                    .refreshable {
                                        await refreshTasks()
                                    }
                            }
                        case .error(let error):
                            ErrorView(
                                error: error,
                                retry: {
                                    AsyncTask {
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
                    .clipShape(.rect(topLeadingRadius: 40, topTrailingRadius: 40))
                    .background(Color(UIColor.systemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: -2)
                    .ignoresSafeArea(edges: .bottom)
                    .zIndex(1)
                            }
                        }
                    }
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
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadTasks()
        }
        .onAppear {
            let useAutoGradient = UserDefaults.standard.bool(forKey: "useAutoGradient")
            
            if useAutoGradient {
                // Load extracted colors from header image
                self.extractedColors = UserDefaults.standard.getExtractedColors()
                
                // If no colors saved but we have an image, extract them
                if extractedColors == nil, let headerData = SettingsView.loadHeaderImage() {
                    let colors = ColorExtractor.extractColors(from: headerData.image)
                    UserDefaults.standard.setExtractedColors(colors)
                    self.extractedColors = (colors.primary, colors.secondary)
                }
            } else {
                // Use manual gradient color
                let customHex = UserDefaults.standard.string(forKey: "customGradientColorHex") ?? ""
                var baseColor: Color
                if !customHex.isEmpty {
                    baseColor = Color(hex: customHex)
                } else {
                    let manualColor = UserDefaults.standard.string(forKey: "manualGradientColor") ?? "blue"
                    baseColor = Color.fromAccentString(manualColor)
                }
                
                // In dark mode, brighten the colors for better visibility
                if colorScheme == .dark {
                    // Mix with white to brighten the color
                    let brightened = UIColor(baseColor).brightened(by: 0.3) ?? UIColor(baseColor)
                    baseColor = Color(brightened)
                }
                
                self.extractedColors = (baseColor, baseColor.opacity(0.7))
            }
        }
        .onChange(of: selectedFilter) { _, _ in
            AsyncTask {
                await loadTasks()
            }
        }
        .onChange(of: searchText) { _, _ in
            AsyncTask {
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
        .sheet(isPresented: $showingCompletedTasks) {
            CompletedTasksView()
        }
    }
    
    // MARK: - Components
    
    private var darkModeGradientColors: [Color] {
        guard let colors = extractedColors else { return [] }
        return [
            colors.primary.opacity(0.15),
            colors.primary.opacity(0.1),
            colors.secondary.opacity(0.08),
            colors.primary.opacity(0.05),
            colors.secondary.opacity(0.03),
            Color.white.opacity(0.01),
            Color.clear
        ]
    }
    
    private var lightModeGradientColors: [Color] {
        guard let colors = extractedColors else { return [] }
        return [
            colors.primary.opacity(0.8),
            colors.primary.opacity(0.6),
            colors.secondary.opacity(0.4),
            colors.primary.opacity(0.2),
            colors.secondary.opacity(0.1),
            Color.white.opacity(0.02),
            Color.clear
        ]
    }
    
    @ViewBuilder
    private var gradientBackground: some View {
        if extractedColors != nil {
            ExtendedGradientBackground(
                colors: colorScheme == .dark ? darkModeGradientColors : lightModeGradientColors,
                startPoint: .top,
                endPoint: .bottom,
                extendFactor: 3.0
            )
            .blur(radius: colorScheme == .dark ? 8 : 2)
            .blendMode(colorScheme == .dark ? .plusLighter : .normal)
        }
    }
    
    private var taskList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Show active tasks grouped by priority
                    ForEach(groupedTasks.keys.sorted(), id: \.self) { priority in
                        if let tasks = groupedTasks[priority], !tasks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                // Section header
                                HStack {
                                    Image(systemName: priorityIcon(for: priority))
                                        .foregroundColor(priorityColor(for: priority))
                                        .scaledFont(size: 14)
                                        .scaledIcon()
                                    Text("\(priority.displayName) Priority")
                                        .scaledFont(size: 13, weight: .semibold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(tasks.count)")
                                        .scaledFont(size: 12, weight: .medium)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                
                                // Tasks
                                ForEach(tasks) { task in
                                    EnhancedTaskCard(task: task) {
                                        selectedTask = task
                                    }
                                    .padding(.horizontal, 16)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteTask(task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Show today's completed tasks at the bottom if viewing Today filter
                    if selectedFilter == .today {
                        completedTodaySection
                    }
                
                // Add bottom padding for floating button
                Spacer()
                    .frame(height: 100)
            }
        }
    }
    
    
    private var completedTasksSection: some View {
        VStack(spacing: 0) {
            // Folder header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    expandedCompletedFolder.toggle()
                }
                HapticFeedback.light.trigger()
            } label: {
                HStack {
                    // Folder icon and title
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: expandedCompletedFolder ? "folder.fill" : "folder")
                                .foregroundColor(.green)
                                .font(.system(size: 18))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Completed Tasks")
                                .scaledFont(size: 16, weight: .semibold)
                                .foregroundColor(.primary)
                            
                            let count = getCompletedTasksCount()
                            Text("\(count) \(count == 1 ? "task" : "tasks") completed")
                                .scaledFont(size: 12, weight: .medium)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    // Chevron indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(expandedCompletedFolder ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.green.opacity(0.1), radius: 4, y: 2)
                )
            }
            
            // Expanded content
            if expandedCompletedFolder {
                VStack(spacing: 8) {
                    // Filter tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CompletedTaskFilter.allCases, id: \.self) { filter in
                                Button {
                                    withAnimation(.spring(response: 0.25)) {
                                        selectedCompletedFilter = filter
                                    }
                                } label: {
                                    Text(filter.rawValue)
                                        .scaledFont(size: 13, weight: .medium)
                                        .foregroundColor(selectedCompletedFilter == filter ? .white : .primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(selectedCompletedFilter == filter ? 
                                                    Color.green : Color(UIColor.tertiarySystemFill))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                    
                    // Completed tasks list
                    let completedTasks = getFilteredCompletedTasks()
                    if completedTasks.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                            Text("No completed tasks for \(selectedCompletedFilter.rawValue.lowercased())")
                                .scaledFont(size: 13)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(completedTasks.prefix(5)) { task in
                                CompletedTaskRow(task: task) {
                                    selectedTask = task
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            if completedTasks.count > 5 {
                                Button {
                                    showingCompletedTasks = true
                                } label: {
                                    HStack {
                                        Text("View all \(completedTasks.count) completed tasks")
                                            .scaledFont(size: 13, weight: .medium)
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundColor(.green)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
    }
    
    private func getCompletedTasksCount() -> Int {
        taskManager.tasks.filter { $0.isCompleted }.count
    }
    
    private func getFilteredCompletedTasks() -> [Task] {
        let dateRange = selectedCompletedFilter.dateRange
        var tasks = taskManager.tasks.filter { $0.isCompleted }
        
        if let startDate = dateRange.start {
            tasks = tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= startDate && completedAt <= dateRange.end
            }
        }
        
        return tasks.sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
    }
    
    private var completedTodaySection: some View {
        Group {
            let todayCompleted = taskManager.todayCompletedTasks()
            if !todayCompleted.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .scaledFont(size: 14)
                        Text("Completed Today")
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(todayCompleted.count)")
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .padding(.top, 16)
                    
                    ForEach(todayCompleted) { task in
                        EnhancedTaskCard(task: task) {
                            selectedTask = task
                        }
                        .padding(.horizontal, 16)
                        .opacity(0.7)
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
            tasks = taskManager.tasks.filter { !$0.isCompleted }
        case .today:
            tasks = taskManager.tasks(for: Date()).filter { !$0.isCompleted }
        case .upcoming:
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            tasks = taskManager.tasks.filter { task in
                guard !task.isCompleted, let dueDate = task.dueDate else { return false }
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
        try? await AsyncTask.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
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

struct CompletedTaskRow: View {
    let task: Task
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title ?? "Untitled")
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundColor(.primary)
                        .strikethrough()
                        .lineLimit(1)
                    
                    if let completedAt = task.completedAt {
                        Text("Completed \(formatCompletedTime(completedAt))")
                            .scaledFont(size: 11)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let priority = TaskPriority(rawValue: task.priority) {
                    Image(systemName: priority == .high ? "flag.fill" : priority == .medium ? "flag" : "flag.slash")
                        .font(.system(size: 11))
                        .foregroundColor(priority.color.opacity(0.7))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatCompletedTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "at \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview

#Preview {
    TaskListView()
        .environmentObject(TaskManager.shared)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}