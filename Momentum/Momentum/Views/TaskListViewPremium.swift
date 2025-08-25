import SwiftUI
import CoreData

struct TaskListViewPremium: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var taskManager: TaskManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @State private var showingAddTask = false
    @State private var showingTaskDetail = false
    @State private var selectedTask: Task?
    @State private var selectedDate = Date()
    @State private var dayOffset: Int = 0
    @Environment(\.colorScheme) var colorScheme
    @State private var extractedColors: (primary: Color, secondary: Color)? = nil
    
    
    var body: some View {
        ZStack {
            // Super light gray background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
                .transition(.identity)
            
            VStack(spacing: 0) {
                // Stack with blue header extending behind content
                ZStack(alignment: .top) {
                    // Background - either custom image or gradient
                    Group {
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
                            // Default blue gradient background
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.15, blue: 0.35),
                                    Color(red: 0.12, green: 0.25, blue: 0.55)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .ignoresSafeArea()
                        }
                    }
                    
                    VStack(spacing: 0) {
                        // Header content using PremiumHeaderView
                        PremiumHeaderView(
                            dateTitle: formatDateHeader(selectedDate),
                            selectedDate: selectedDate,
                            onPreviousDay: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dayOffset -= 1
                                    selectedDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
                                }
                            },
                            onNextDay: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dayOffset += 1
                                    selectedDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
                                }
                            },
                            onToday: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dayOffset = 0
                                    selectedDate = Date()
                                }
                            },
                            onSettings: {
                                // Settings not used in task view
                            },
                            onAddEvent: {
                                showingAddTask = true
                            },
                            onDateSelected: { date in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDate = date
                                    let calendar = Calendar.current
                                    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date)).day ?? 0
                                    dayOffset = days
                                }
                            }
                        )
                        
                        // Spacer to push white content down
                        Spacer().frame(height: 0)
                        
                        // White content container with rounded corners
                        ZStack {
                            // Gradient background that extends beyond safe area
                            Color(UIColor.systemBackground)
                                .ignoresSafeArea(.all)
                            
                            Group {
                                if let colors = extractedColors {
                                    let darkModeColors: [Color] = [
                                        colors.primary.opacity(0.15),
                                        colors.primary.opacity(0.1),
                                        colors.secondary.opacity(0.08),
                                        colors.primary.opacity(0.05),
                                        colors.secondary.opacity(0.03),
                                        Color.white.opacity(0.01),
                                        Color.clear
                                    ]
                                    
                                    let lightModeColors: [Color] = [
                                        colors.primary.opacity(0.8),
                                        colors.primary.opacity(0.6),
                                        colors.secondary.opacity(0.4),
                                        colors.primary.opacity(0.2),
                                        colors.secondary.opacity(0.1),
                                        Color.white.opacity(0.02),
                                        Color.clear
                                    ]
                                    
                                    ExtendedGradientBackground(
                                        colors: colorScheme == .dark ? darkModeColors : lightModeColors,
                                        startPoint: .top,
                                        endPoint: .bottom,
                                        extendFactor: 3.0
                                    )
                                    .blur(radius: colorScheme == .dark ? 8 : 2)
                                    .blendMode(colorScheme == .dark ? .plusLighter : .normal)
                                    .allowsHitTesting(false) // Don't block touches
                                }
                            }
                            
                            VStack(spacing: 0) {
                                // Task list content
                                if filteredTasks.isEmpty {
                                    emptyStateView
                                } else {
                                    taskList
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 40,
                                topTrailingRadius: 40
                            )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: -2)
                        .ignoresSafeArea(edges: .bottom)
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
                }
            }
        }
        .navigationBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowAddTask"))) { _ in
            showingAddTask = true
        }
        .onAppear {
            let useAutoGradient = UserDefaults.standard.bool(forKey: "useAutoGradient")
            
            if useAutoGradient {
                // Load extracted colors from header image
                self.extractedColors = UserDefaults.standard.getExtractedColors()
                print("🎨 TaskListView - Loaded extracted colors: \(extractedColors != nil ? "Found" : "None")")
                
                // If no colors saved but we have an image, extract them
                if extractedColors == nil, let headerData = SettingsView.loadHeaderImage() {
                    print("🎨 TaskListView - No saved colors, extracting from image...")
                    let colors = ColorExtractor.extractColors(from: headerData.image)
                    UserDefaults.standard.setExtractedColors(colors)
                    self.extractedColors = (colors.primary, colors.secondary)
                    print("🎨 TaskListView - Extracted colors - Primary: \(colors.primary), Secondary: \(colors.secondary)")
                }
            } else {
                // Use manual gradient color
                let customHex = UserDefaults.standard.string(forKey: "customGradientColorHex") ?? ""
                var baseColor: Color
                if !customHex.isEmpty {
                    baseColor = Color(hex: customHex) ?? Color.blue
                    print("🎨 TaskListView - Using custom gradient color: \(customHex)")
                } else {
                    let manualColor = UserDefaults.standard.string(forKey: "manualGradientColor") ?? "blue"
                    baseColor = Color.fromAccentString(manualColor)
                    print("🎨 TaskListView - Using manual gradient color: \(manualColor)")
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
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .fullScreenCover(isPresented: $showingAddTask) {
            AnimatedAddTaskView(isPresented: $showingAddTask)
                .background(ClearBackground())
                .edgesIgnoringSafeArea(.all)
        }
    }
    
    // MARK: - Components
    
    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                // Add top padding
                Color.clear.frame(height: 16)
                
                // All incomplete tasks in one list
                ForEach(incompleteTasks) { task in
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
                
                // Completed tasks section - simple divider
                if !completedTasks.isEmpty {
                    // Simple separator line
                    if !incompleteTasks.isEmpty {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .padding(.horizontal)
                    }
                    
                    // Completed tasks
                    ForEach(completedTasks) { task in
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
                            
                            Button {
                                uncompleteTask(task)
                            } label: {
                                Label("Reopen", systemImage: "arrow.uturn.backward")
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: emptyStateIcon)
                .scaledFont(size: 48)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(emptyStateMessage)
                    .scaledFont(size: 17)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingAddTask = true
            } label: {
                Text("Add Task")
                    .scaledFont(size: 17)
                    .foregroundColor(.accentColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var addTaskButton: some View {
        EmptyView() // FAB moved to navbar
    }
    
    // MARK: - Computed Properties
    
    private var filteredTasks: [Task] {
        var tasks: [Task] = []
        
        if Calendar.current.isDateInToday(selectedDate) {
            // For today, show all tasks (including completed ones)
            tasks = taskManager.tasks
        } else {
            // For other days, show only tasks scheduled/due on that day
            tasks = taskManager.tasks(for: selectedDate)
        }
        
        // Sort tasks: incomplete first, then completed
        return tasks.sorted { task1, task2 in
            if task1.isCompleted == task2.isCompleted {
                // If both have same completion status, sort by priority
                let priority1 = TaskPriority(rawValue: task1.priority) ?? .medium
                let priority2 = TaskPriority(rawValue: task2.priority) ?? .medium
                return priority1.rawValue > priority2.rawValue
            }
            // Incomplete tasks come first
            return !task1.isCompleted && task2.isCompleted
        }
    }
    
    private var incompleteTasks: [Task] {
        filteredTasks.filter { !$0.isCompleted }
    }
    
    private var completedTasks: [Task] {
        filteredTasks.filter { $0.isCompleted }
    }
    
    private var groupedIncompleteTasks: [TaskPriority: [Task]] {
        Dictionary(grouping: incompleteTasks) { task in
            TaskPriority(rawValue: task.priority) ?? .medium
        }
    }
    
    private var emptyStateIcon: String {
        return "checkmark.circle"
    }
    
    private var emptyStateTitle: String {
        return "No tasks for \(formatDayOfWeek(selectedDate))"
    }
    
    private var emptyStateMessage: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "You're all caught up for today!"
        } else if selectedDate < Date() {
            return "No tasks were scheduled for this day"
        } else {
            return "No tasks scheduled yet"
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        return Date.formatDateWithGreeting(date)
    }
    
    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func dayOfWeek(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private func monthString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
    
    private func yearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
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
        _ = taskManager.completeTask(task)
    }
    
    private func uncompleteTask(_ task: Task) {
        _ = taskManager.uncompleteTask(task)
    }
    
    private func deleteTask(_ task: Task) {
        _ = taskManager.deleteTask(task)
    }
}

// MARK: - Preview

#Preview {
    TaskListViewPremium()
        .environmentObject(TaskManager.shared)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}