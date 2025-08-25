import SwiftUI
import CoreData

struct CompletedTasksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var taskManager: TaskManager
    @State private var selectedFilter = CompletedTaskFilter.all
    @State private var searchText = ""
    @State private var selectedTask: Task?
    @State private var showingTaskDetail = false
    
    enum CompletedTaskFilter: String, CaseIterable {
        case today = "Today"
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case lastYear = "Last Year"
        case all = "All Time"
        
        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .lastWeek: return "calendar.day.timeline.left"
            case .lastMonth: return "calendar"
            case .lastYear: return "calendar.circle"
            case .all: return "infinity"
            }
        }
        
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
            case .lastYear:
                let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                return (start, now)
            case .all:
                return (nil, now)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CompletedTaskFilter.allCases, id: \.self) { filter in
                                FilterPill(
                                    title: filter.rawValue,
                                    icon: filter.icon,
                                    isSelected: selectedFilter == filter
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedFilter = filter
                                    }
                                    HapticFeedback.light.trigger()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search completed tasks...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    // Stats Bar
                    HStack(spacing: 20) {
                        StatBadge(
                            title: "Completed",
                            value: "\(filteredTasks.count)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        
                        StatBadge(
                            title: "Streak",
                            value: "\(calculateStreak())",
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        StatBadge(
                            title: "Best Day",
                            value: "\(bestDay())",
                            icon: "star.fill",
                            color: .yellow
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    
                    Divider()
                    
                    // Tasks List
                    if filteredTasks.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(groupedTasks.keys.sorted(by: >), id: \.self) { date in
                                    if let tasks = groupedTasks[date] {
                                        Section {
                                            ForEach(tasks) { task in
                                                CompletedTaskRow(task: task) {
                                                    selectedTask = task
                                                    showingTaskDetail = true
                                                }
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 6)
                                                
                                                if task != tasks.last {
                                                    Divider()
                                                        .padding(.leading, 20)
                                                }
                                            }
                                        } header: {
                                            HStack {
                                                Text(formatSectionDate(date))
                                                    .scaledFont(size: 13, weight: .semibold)
                                                    .foregroundColor(.secondary)
                                                    .textCase(.uppercase)
                                                
                                                Spacer()
                                                
                                                Text("\(tasks.count)")
                                                    .scaledFont(size: 12, weight: .medium)
                                                    .foregroundColor(.secondary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color(UIColor.tertiarySystemFill))
                                                    )
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(Color(UIColor.systemGroupedBackground))
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("Completed Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            exportTasks()
                        } label: {
                            Label("Export Tasks", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive) {
                            clearOldTasks()
                        } label: {
                            Label("Clear Old Tasks", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredTasks: [Task] {
        let dateRange = selectedFilter.dateRange
        
        // Get all completed tasks
        let completedTasks = taskManager.tasks.filter { $0.isCompleted }
        print("🔍 CompletedTasksView - Total completed tasks: \(completedTasks.count)")
        
        var tasks = completedTasks
        
        // Apply date filter
        if let startDate = dateRange.start {
            tasks = tasks.filter { task in
                guard let completedAt = task.completedAt else { 
                    print("⚠️ Task '\(task.title ?? "Unknown")' is completed but has no completedAt date")
                    return false 
                }
                return completedAt >= startDate && completedAt <= dateRange.end
            }
            print("📅 After date filter (\(selectedFilter.rawValue)): \(tasks.count) tasks")
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            tasks = tasks.filter { task in
                (task.title ?? "").localizedCaseInsensitiveContains(searchText) ||
                (task.notes ?? "").localizedCaseInsensitiveContains(searchText) ||
                task.tagsArray.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
            print("🔎 After search filter: \(tasks.count) tasks")
        }
        
        return tasks.sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
    }
    
    private var groupedTasks: [Date: [Task]] {
        let calendar = Calendar.current
        return Dictionary(grouping: filteredTasks) { task in
            calendar.startOfDay(for: task.completedAt ?? Date())
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedFilter == .today ? "checkmark.circle" : "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .scaledFont(size: 18, weight: .semibold)
            
            Text(emptyStateSubtitle)
                .scaledFont(size: 14)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .today:
            return "No tasks completed today"
        case .lastWeek:
            return "No tasks completed this week"
        case .lastMonth:
            return "No tasks completed this month"
        case .lastYear:
            return "No tasks completed this year"
        case .all:
            return searchText.isEmpty ? "No completed tasks" : "No results found"
        }
    }
    
    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .today:
            return "Complete some tasks to see them here"
        case .lastWeek:
            return "Tasks completed in the last 7 days will appear here"
        case .lastMonth:
            return "Tasks completed in the last month will appear here"
        case .lastYear:
            return "Tasks completed in the last year will appear here"
        case .all:
            return searchText.isEmpty ? "Your completed tasks will appear here" : "Try adjusting your search"
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        let sortedDates = taskManager.tasks
            .filter { $0.isCompleted }
            .compactMap { $0.completedAt }
            .map { calendar.startOfDay(for: $0) }
            .sorted(by: >)
        
        guard !sortedDates.isEmpty else { return 0 }
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for date in sortedDates {
            if date == currentDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? date
            } else if date < currentDate {
                break
            }
        }
        
        return streak
    }
    
    private func bestDay() -> Int {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: taskManager.tasks.filter { $0.isCompleted }) { task in
            calendar.startOfDay(for: task.completedAt ?? Date())
        }
        return grouped.values.map { $0.count }.max() ?? 0
    }
    
    private func exportTasks() {
        // TODO: Implement export functionality
    }
    
    private func clearOldTasks() {
        // TODO: Implement clear old tasks with confirmation
    }
}

// MARK: - Supporting Views

struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .scaledFont(size: 14, weight: .medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(UIColor.tertiarySystemFill))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .scaledFont(size: 18, weight: .bold)
            }
            Text(title)
                .scaledFont(size: 11)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// CompletedTaskRow has been moved to TaskListView.swift to avoid duplication

#Preview {
    CompletedTasksView()
        .environmentObject(TaskManager.shared)
}