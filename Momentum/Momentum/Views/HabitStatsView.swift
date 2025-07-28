//
//  HabitStatsView.swift
//  Momentum
//
//  Advanced habit analytics and insights
//

import SwiftUI
import Charts

struct HabitStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var habitManager: HabitManager
    @State private var selectedTimeRange: TimeRange = .month
    @State private var selectedHabit: Habit?
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }
    
    private var dateRange: ClosedRange<Date> {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: end) ?? end
        return start...end
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Rectangle()
                    .fill(Color.adaptiveBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                    // Time Range Selector
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Overall Stats
                    OverallStatsSection(dateRange: dateRange)
                    
                    // Completion Rate Chart
                    CompletionRateChart(dateRange: dateRange)
                    
                    // Best Performers
                    BestPerformersSection(dateRange: dateRange)
                    
                    // Time of Day Analysis
                    TimeOfDayAnalysis(dateRange: dateRange)
                    
                    // Mood Correlation
                    MoodCorrelationSection()
                    
                    // Habit Comparison
                    HabitComparisonChart(dateRange: dateRange)
                    
                        Spacer(minLength: 50)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Habit Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Overall Stats

struct OverallStatsSection: View {
    let dateRange: ClosedRange<Date>
    @EnvironmentObject private var habitManager: HabitManager
    
    private var stats: (total: Int, completed: Int, rate: Double, streaks: Int) {
        var totalPossible = 0
        var totalCompleted = 0
        var activeStreaks = 0
        
        for habit in habitManager.habits {
            let entries = habitManager.entriesForHabit(habit, in: dateRange)
            let daysInRange = Calendar.current.dateComponents([.day], from: dateRange.lowerBound, to: dateRange.upperBound).day ?? 0
            
            // Calculate possible completions based on frequency
            let possible: Int
            switch habit.frequencyEnum {
            case .daily:
                possible = daysInRange
            case .weekly:
                possible = min(Int(habit.weeklyTarget) * (daysInRange / 7), daysInRange)
            case .custom:
                // Simplified - would need more complex calculation
                possible = daysInRange / 2
            }
            
            totalPossible += possible
            totalCompleted += entries.filter { !$0.skipped }.count
            
            if habit.currentStreak > 0 {
                activeStreaks += 1
            }
        }
        
        let rate = totalPossible > 0 ? Double(totalCompleted) / Double(totalPossible) : 0
        
        return (totalPossible, totalCompleted, rate, activeStreaks)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Overall Performance")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                OverallStatCard(
                    title: "Completion Rate",
                    value: "\(Int(stats.rate * 100))%",
                    icon: "chart.pie.fill",
                    color: stats.rate > 0.8 ? .green : stats.rate > 0.6 ? .yellow : .red
                )
                
                OverallStatCard(
                    title: "Active Streaks",
                    value: "\(stats.streaks)",
                    icon: "flame.fill",
                    color: .orange
                )
            }
            
            HStack(spacing: 16) {
                OverallStatCard(
                    title: "Total Completed",
                    value: "\(stats.completed)",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )
                
                OverallStatCard(
                    title: "Habits Tracked",
                    value: "\(habitManager.habits.count)",
                    icon: "list.bullet",
                    color: .purple
                )
            }
        }
        .padding(.horizontal)
    }
}

struct OverallStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Completion Rate Chart

struct CompletionRateChart: View {
    let dateRange: ClosedRange<Date>
    @EnvironmentObject private var habitManager: HabitManager
    
    private var chartData: [(date: Date, rate: Double)] {
        let calendar = Calendar.current
        var data: [(Date, Double)] = []
        
        var currentDate = dateRange.lowerBound
        while currentDate <= dateRange.upperBound {
            let dayHabits = habitManager.habitsForDate(currentDate)
            let completed = dayHabits.filter { habit in
                habit.entries?.contains { entry in
                    guard let entry = entry as? HabitEntry,
                          let entryDate = entry.date else { return false }
                    return calendar.isDate(entryDate, inSameDayAs: currentDate) && !entry.skipped
                } ?? false
            }.count
            
            let rate = dayHabits.isEmpty ? 0 : Double(completed) / Double(dayHabits.count)
            data.append((currentDate, rate))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? dateRange.upperBound
        }
        
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Completion Rate")
                .font(.headline)
            
            Chart(chartData, id: \.date) { item in
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Rate", item.rate)
                )
                .foregroundStyle(Color.blue.opacity(0.15))
                
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Rate", item.rate)
                )
                .foregroundStyle(Color.blue)
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 200)
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let rate = value.as(Double.self) {
                            Text("\(Int(rate * 100))%")
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

// MARK: - Best Performers

struct BestPerformersSection: View {
    let dateRange: ClosedRange<Date>
    @EnvironmentObject private var habitManager: HabitManager
    
    private var topHabits: [(habit: Habit, rate: Double)] {
        habitManager.habits.compactMap { habit in
            let entries = habitManager.entriesForHabit(habit, in: dateRange)
            let possibleDays = Calendar.current.dateComponents([.day], from: dateRange.lowerBound, to: dateRange.upperBound).day ?? 1
            let rate = Double(entries.filter { !$0.skipped }.count) / Double(possibleDays)
            return (habit, rate)
        }
        .sorted { $0.rate > $1.rate }
        .prefix(5)
        .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Performers")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(topHabits, id: \.habit.id) { item in
                HStack {
                    Image(systemName: item.habit.iconName ?? "star.fill")
                        .foregroundColor(Color(hex: item.habit.colorHex ?? "#007AFF"))
                    
                    Text(item.habit.name ?? "")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(Int(item.rate * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(item.rate > 0.8 ? .green : .primary)
                    
                    // Mini progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: item.habit.colorHex ?? "#007AFF"))
                                .frame(width: geometry.size.width * item.rate, height: 4)
                        }
                    }
                    .frame(width: 60, height: 4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Time of Day Analysis

struct TimeOfDayAnalysis: View {
    let dateRange: ClosedRange<Date>
    @EnvironmentObject private var habitManager: HabitManager
    
    private var hourlyData: [(hour: Int, count: Int)] {
        var hourCounts = Array(repeating: 0, count: 24)
        
        for habit in habitManager.habits {
            let entries = habitManager.entriesForHabit(habit, in: dateRange)
            for entry in entries where !entry.skipped {
                if let completedAt = entry.completedAt {
                    let hour = Calendar.current.component(.hour, from: completedAt)
                    hourCounts[hour] += 1
                }
            }
        }
        
        return hourCounts.enumerated().map { (hour: $0, count: $1) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completion Time Analysis")
                .font(.headline)
            
            Text("When you're most productive")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Chart(hourlyData, id: \.hour) { item in
                BarMark(
                    x: .value("Hour", item.hour),
                    y: .value("Completions", item.count)
                )
                .foregroundStyle(Color.blue)
                .cornerRadius(2)
            }
            .frame(height: 150)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text("\(hour):00")
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

// MARK: - Mood Correlation

struct MoodCorrelationSection: View {
    @EnvironmentObject private var habitManager: HabitManager
    
    private var correlations: [(habit: Habit, score: Double)] {
        habitManager.habits.compactMap { habit in
            if let score = habitManager.getMoodCorrelation(for: habit), score > 0 {
                return (habit, score)
            }
            return nil
        }
        .sorted { $0.score > $1.score }
    }
    
    var body: some View {
        if !correlations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mood Impact")
                    .font(.headline)
                
                Text("Habits that improve your mood")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(correlations.prefix(3), id: \.habit.id) { item in
                    HStack {
                        Image(systemName: item.habit.iconName ?? "star.fill")
                            .foregroundColor(Color(hex: item.habit.colorHex ?? "#007AFF"))
                        
                        Text(item.habit.name ?? "")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                            Text("+\(Int(item.score * 100))%")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .font(.caption)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Habit Comparison

struct HabitComparisonChart: View {
    let dateRange: ClosedRange<Date>
    @EnvironmentObject private var habitManager: HabitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habit Comparison")
                .font(.headline)
            
            // Stacked bar chart showing completion rates
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(habitManager.habits) { habit in
                        VStack(spacing: 8) {
                            // Completion bar
                            GeometryReader { geometry in
                                VStack(spacing: 0) {
                                    let entries = habitManager.entriesForHabit(habit, in: dateRange)
                                    let completed = entries.filter { !$0.skipped }.count
                                    let skipped = entries.filter { $0.skipped }.count
                                    let total = Calendar.current.dateComponents([.day], from: dateRange.lowerBound, to: dateRange.upperBound).day ?? 1
                                    let missed = total - completed - skipped
                                    
                                    let completedHeight = geometry.size.height * (Double(completed) / Double(total))
                                    let skippedHeight = geometry.size.height * (Double(skipped) / Double(total))
                                    
                                    Spacer()
                                    
                                    // Missed (gray)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: geometry.size.height - completedHeight - skippedHeight)
                                    
                                    // Skipped (orange)
                                    if skipped > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.orange)
                                            .frame(height: skippedHeight)
                                    }
                                    
                                    // Completed (habit color)
                                    if completed > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(hex: habit.colorHex ?? "#007AFF"))
                                            .frame(height: completedHeight)
                                    }
                                }
                            }
                            .frame(width: 60, height: 120)
                            
                            Image(systemName: habit.iconName ?? "star.fill")
                                .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                            
                            Text(habit.name ?? "")
                                .font(.caption)
                                .lineLimit(1)
                                .frame(width: 60)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .blue, text: "Completed")
                LegendItem(color: .orange, text: "Skipped")
                LegendItem(color: .gray.opacity(0.3), text: "Missed")
            }
            .font(.caption)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }
}


#Preview {
    HabitStatsView()
        .environmentObject(HabitManager.shared)
}