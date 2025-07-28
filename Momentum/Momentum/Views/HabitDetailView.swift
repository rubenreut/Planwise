//
//  HabitDetailView.swift
//  Momentum
//
//  Detailed habit view with charts and insights
//

import SwiftUI
import Charts

struct HabitDetailView: View {
    let habit: Habit
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var habitManager: HabitManager
    @State private var selectedPeriod: Period = .week
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var entries: [HabitEntry] = []
    @State private var insights: [String] = []
    
    enum Period: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 365
            case .all: return 9999
            }
        }
    }
    
    var body: some View {
        NavigationView {
            mainContent
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                headerSection
                contentSections
                Spacer(minLength: DesignSystem.Spacing.xxl)
            }
            .padding(.vertical)
        }
        .navigationTitle(habit.name ?? "Habit")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadData()
        }
        .onChange(of: selectedPeriod) { _ in
            loadData()
        }
        .sheet(isPresented: $showingEditView) {
            AddHabitView()
        }
        .alert("Delete Habit", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { 
                // Cancel action
            }
            Button("Delete", role: .destructive) {
                deleteHabit()
            }
        } message: {
            Text("Are you sure you want to delete this habit? All data will be lost.")
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HeaderCard(habit: habit)
            
            QuickActionsRow(
                habit: habit,
                onEdit: { showingEditView = true },
                onDelete: { showingDeleteAlert = true }
            )
        }
    }
    
    @ViewBuilder  
    private var contentSections: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Period Selector
            periodSelector
            
            // Charts Section
            chartsSection
            
            // Insights Section
            insightsSection
            
            // Recent Entries
            if !entries.isEmpty {
                RecentEntriesSection(entries: Array(entries.prefix(10)))
            }
        }
    }
    
    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(Period.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    private func loadData() {
        let endDate = Date()
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -selectedPeriod.days,
            to: endDate
        ) ?? endDate
        
        entries = habitManager.entriesForHabit(habit, in: startDate...endDate)
        insights = habitManager.getInsights(for: habit)
    }
    
    private func deleteHabit() {
        _ = habitManager.deleteHabit(habit)
        dismiss()
    }
    
    @ViewBuilder
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Completion Chart
            CompletionChart(
                entries: entries,
                period: selectedPeriod,
                habit: habit
            )
            
            // Streak Chart
            if habit.trackingTypeEnum == .binary {
                StreakChart(habit: habit, entries: entries)
            }
            
            // Progress Chart for quantity/duration
            if habit.trackingTypeEnum != .binary {
                ProgressChart(
                    entries: entries,
                    habit: habit,
                    period: selectedPeriod
                )
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var insightsSection: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Insights")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(insights, id: \.self) { insight in
                    InsightCard(text: insight)
                }
            }
        }
    }
}

// MARK: - Header Card

struct HeaderCard: View {
    let habit: Habit
    
    private var streakInfo: (current: Int32, best: Int32, safetyNetActive: Bool) {
        HabitManager.shared.getStreakInfo(for: habit)
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Icon and name
            HStack {
                Image(systemName: habit.iconName ?? "star.fill")
                    .font(.largeTitle)
                    .foregroundColor(Color(hex: habit.colorHex ?? "#FF6B6B"))
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(habit.name ?? "")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let category = habit.category {
                        Label(category.name ?? "", systemImage: category.iconName ?? "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Stats Grid
            HStack(spacing: DesignSystem.Spacing.lg) {
                StatItem(
                    title: "Current",
                    value: "\(streakInfo.current)",
                    subtitle: "day streak",
                    color: .orange
                )
                
                StatItem(
                    title: "Best",
                    value: "\(streakInfo.best)",
                    subtitle: "all time",
                    color: .purple
                )
                
                StatItem(
                    title: "Total",
                    value: "\(habit.totalCompletions)",
                    subtitle: "completions",
                    color: .green
                )
            }
            
            // Current status
            if habit.isPaused {
                Label("Paused", systemImage: "pause.circle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(DesignSystem.Opacity.medium))
                    )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Actions

struct QuickActionsRow: View {
    let habit: Habit
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ActionButton(
                title: "Edit",
                icon: "pencil",
                color: .blue,
                action: onEdit
            )
            
            ActionButton(
                title: "Delete",
                icon: "trash",
                color: .red,
                action: onDelete
            )
        }
        .padding(.horizontal)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(color.opacity(DesignSystem.Opacity.light))
            )
        }
    }
}

// MARK: - Completion Chart

struct CompletionChart: View {
    let entries: [HabitEntry]
    let period: HabitDetailView.Period
    let habit: Habit
    
    private var chartData: [(date: Date, completed: Bool)] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(
            byAdding: .day,
            value: -min(period.days, 60), // Limit to 60 days for performance
            to: endDate
        ) ?? endDate
        
        var data: [(Date, Bool)] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let hasEntry = entries.contains { entry in
                guard let entryDate = entry.date else { return false }
                return calendar.isDate(entryDate, inSameDayAs: currentDate)
            }
            
            data.append((currentDate, hasEntry))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return data
    }
    
    var body: some View {
        completionChartContent
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(Color(UIColor.tertiarySystemBackground))
            )
    }
    
    @ViewBuilder
    private var completionChartContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completion History")
                .font(.headline)
            
            completionChartView
        }
    }
    
    private var completionChartView: some View {
        let habitColor = Color(hex: habit.colorHex ?? "#007AFF")
        let grayColor = Color.gray.opacity(DesignSystem.Opacity.medium)
        
        return Chart {
            ForEach(chartData, id: \.date) { item in
                BarMark(
                    x: .value("Date", item.date),
                    y: .value("Completed", item.completed ? 1 : 0)
                )
                .foregroundStyle(item.completed ? habitColor : grayColor)
            }
        }
        .frame(height: 100)
    }
}

// MARK: - Progress Chart

struct ProgressChart: View {
    let entries: [HabitEntry]
    let habit: Habit
    let period: HabitDetailView.Period
    
    private var chartData: [(date: Date, value: Double)] {
        entries.compactMap { entry in
            guard let date = entry.date else { return nil }
            return (date, entry.value)
        }
        .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Over Time")
                .font(.headline)
            
            if !chartData.isEmpty {
                let habitColor = Color(hex: habit.colorHex ?? "#007AFF")
                let maxValue = max(habit.goalTarget * 1.2, chartData.map(\.value).max() ?? 1)
                
                Chart {
                    ForEach(chartData, id: \.date) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(habitColor)
                        
                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("Value", item.value)
                        )
                        .foregroundStyle(habitColor)
                    }
                    
                    RuleMark(y: .value("Goal", habit.goalTarget))
                        .foregroundStyle(Color.green.opacity(0.5))
                }
                .frame(height: 200)
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Streak Chart

struct StreakChart: View {
    let habit: Habit
    let entries: [HabitEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak Timeline")
                .font(.headline)
            
            // Visual representation of streak
            HStack(spacing: 2) {
                ForEach(0..<30, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: -29 + dayOffset, to: Date()) ?? Date()
                    let hasEntry = entries.contains { entry in
                        guard let entryDate = entry.date else { return false }
                        return Calendar.current.isDate(entryDate, inSameDayAs: date)
                    }
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hasEntry ? Color(hex: habit.colorHex ?? "#FF6B6B") : Color.gray.opacity(DesignSystem.Opacity.medium))
                        .frame(width: 10, height: 40)
                }
            }
            
            Text("Last 30 days")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(Color.yellow.opacity(DesignSystem.Opacity.light))
        )
        .padding(.horizontal)
    }
}

// MARK: - Recent Entries

struct RecentEntriesSection: View {
    let entries: [HabitEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Entries")
                .font(.headline)
                .padding(.horizontal)
            
            if entries.isEmpty {
                Text("No entries yet")
                    .foregroundColor(.secondary)
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(entries) { entry in
                    EntryRow(entry: entry)
                }
            }
        }
    }
}

struct EntryRow: View {
    let entry: HabitEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let notes = entry.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if entry.skipped {
                Text("Skipped")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(DesignSystem.Opacity.medium))
                    )
            } else {
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs / 2) {
                    if let habit = entry.habit {
                        switch habit.trackingTypeEnum {
                        case .binary:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        case .quantity, .duration:
                            Text("\(Int(entry.value)) \(habit.goalUnit ?? "")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        case .quality:
                            HStack(spacing: DesignSystem.Spacing.xxs / 2) {
                                ForEach(0..<Int(entry.value), id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    }
                    
                    Text(entry.completedAt?.formatted(date: .omitted, time: .shortened) ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
        .padding(.horizontal)
    }
}

// Preview disabled - Core Data entities need proper context
// #Preview {
//     HabitDetailView(habit: Habit())
//         .environmentObject(HabitManager.shared)
// }