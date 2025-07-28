//
//  HabitsView.swift
//  Momentum
//
//  Clean, professional habit tracking UI
//

import SwiftUI
import Charts

struct HabitsView: View {
    @EnvironmentObject private var habitManager: HabitManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedHabit: Habit?
    @State private var showingAddHabit = false
    @State private var selectedDate = Date()
    @State private var showingStats = false
    @State private var refreshID = UUID()
    @State private var habitToDelete: Habit?
    @State private var showingDeleteAlert = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.softBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg - 4) {
                        // Header with date picker
                        HStack {
                            Text("Habits")
                                .font(DeviceType.isIPad ? .largeTitle : .title)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .glassmorphic(cornerRadius: DesignSystem.CornerRadius.sm + 4, shadowRadius: DesignSystem.Shadow.sm.radius * 0.75)
                        }
                        .adaptiveHorizontalPadding()
                        .padding(.top)
                        
                        // Unified layout for iPhone and iPad
                        VStack(spacing: DesignSystem.Spacing.lg - 4) {
                            // Progress Overview
                            TodayProgressCard()
                                .padding(.horizontal)
                            
                            // Quick Stats
                            QuickStatsRow()
                            
                            // Habit List
                            habitList
                                .padding(.horizontal)
                        }
                        
                        Spacer(minLength: DesignSystem.Spacing.xxxl + DesignSystem.Spacing.xl + 4)
                    }
                }
                .refreshable {
                    await refresh()
                }
                
                // Floating action button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        FloatingActionButton(
                            icon: "plus",
                            accessibilityLabel: "Add new habit"
                        ) {
                            showingAddHabit = true
                        }
                        .padding(.trailing, DesignSystem.Spacing.lg - 4)
                        .padding(.bottom, DesignSystem.Spacing.lg - 4)
                    }
                }
            }
            .navigationBarHidden(DeviceType.isIPad ? false : true) // Show nav bar on iPad for sidebar toggle
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    IconButton(
                        icon: "chart.xyaxis.line",
                        style: .tertiary,
                        size: .small,
                        accessibilityLabel: "View habit statistics"
                    ) {
                        showingStats = true
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(item: $selectedHabit) { habit in
                HabitDetailView(habit: habit)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showingStats) {
                HabitStatsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .alert("Delete Habit", isPresented: $showingDeleteAlert, presenting: habitToDelete) { habit in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteHabit(habit)
                }
            } message: { habit in
                Text("Are you sure you want to delete '\(habit.name ?? "")'? This will also delete all associated entries and cannot be undone.")
            }
        }
        .id(refreshID)
    }
    
    private var habitList: some View {
        Group {
            if habitManager.habitsForDate(selectedDate).isEmpty {
                EmptyStateView(config: habitManager.habits.isEmpty ? .noHabits {
                    showingAddHabit = true
                } : .noHabitsForDate(date: selectedDate) {
                    showingAddHabit = true
                })
                .padding(.vertical, DesignSystem.Spacing.xxxl - 4)
                .frame(maxWidth: .infinity, minHeight: DesignSystem.Spacing.xxxl * 3 + DesignSystem.Spacing.xs)
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(habitManager.habitsForDate(selectedDate)) { habit in
                        HabitRow(
                            habit: habit,
                            date: selectedDate,
                            onTap: {
                                selectedHabit = habit
                            },
                            onComplete: { value in
                                completeHabit(habit, value: value)
                            }
                        )
                        .contextMenu {
                            Button {
                                selectedHabit = habit
                            } label: {
                                Label("Edit Habit", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                habitToDelete = habit
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete Habit", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    private func refresh() async {
        habitManager.updateStreaks()
        refreshID = UUID()
    }
    
    private func completeHabit(_ habit: Habit, value: Double) {
        let result = habitManager.logHabit(
            habit,
            value: value,
            date: selectedDate,
            notes: nil,
            mood: nil,
            duration: nil,
            quality: nil
        )
        
        if case .success = result {
            // Generate haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    private func deleteHabit(_ habit: Habit) {
        let result = habitManager.deleteHabit(habit)
        
        if case .success = result {
            // Generate haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            // Refresh the view
            refreshID = UUID()
        }
    }
}

// MARK: - Today's Progress Card

struct TodayProgressCard: View {
    @EnvironmentObject private var habitManager: HabitManager
    @Environment(\.colorScheme) var colorScheme
    
    private var progress: (completed: Int, total: Int, percentage: Double) {
        habitManager.todayProgress()
    }
    
    var body: some View {
        GlassCard(cornerRadius: DesignSystem.CornerRadius.lg - 4, padding: DesignSystem.Adaptive.value(iPhone: DesignSystem.Spacing.lg - 4, iPad: DesignSystem.Spacing.lg, mac: DesignSystem.Spacing.lg)) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Today's Progress")
                        .font(DeviceType.isIPad ? .title3 : .headline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xxs) {
                        Text("\(progress.completed)")
                            .font(.system(size: DesignSystem.Adaptive.value(iPhone: DesignSystem.Spacing.xl + 4, iPad: DesignSystem.IconSize.xxl + 4, mac: DesignSystem.IconSize.xxl + 4), weight: .bold, design: .rounded))
                        Text("of \(progress.total)")
                            .font(DeviceType.isIPad ? .title2 : .title3)
                            .foregroundColor(.secondary)
                    }
                    
                    if progress.total > 0 {
                        Text("\(Int(progress.percentage * 100))% complete")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Glass progress ring
                GlassProgressRing(
                    progress: progress.percentage,
                    color: progress.percentage == 1 ? .green : .blue,
                    size: DesignSystem.Adaptive.value(iPhone: DesignSystem.Spacing.xxxl + 16, iPad: DesignSystem.Spacing.xxxl + DesignSystem.Spacing.xl + 4, mac: DesignSystem.Spacing.xxxl + DesignSystem.Spacing.xl + 4),
                    lineWidth: DesignSystem.Adaptive.value(iPhone: DesignSystem.Spacing.xs, iPad: DesignSystem.Spacing.xs + 2, mac: DesignSystem.Spacing.xs + 2)
                )
            }
        }
    }
}

// MARK: - Quick Stats Row

struct QuickStatsRow: View {
    @EnvironmentObject private var habitManager: HabitManager
    @Environment(\.colorScheme) var colorScheme
    
    private var totalStreak: Int32 {
        habitManager.habits.map(\.currentStreak).reduce(0, +)
    }
    
    private var bestHabit: Habit? {
        habitManager.habits.max(by: { $0.currentStreak < $1.currentStreak })
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            StatCard(
                icon: "flame.fill",
                color: .orange,
                title: "Total Streak",
                value: "\(totalStreak)",
                subtitle: "days combined"
            )
            
            if let best = bestHabit, best.currentStreak > 0 {
                StatCard(
                    icon: "trophy.fill",
                    color: .yellow,
                    title: "Best Streak",
                    value: "\(best.currentStreak)",
                    subtitle: best.name ?? ""
                )
            }
            
            StatCard(
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                title: "This Week",
                value: "\(weeklyCompletions)",
                subtitle: "completions"
            )
        }
        .padding(.horizontal)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
    
    private var weeklyCompletions: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        return habitManager.habits.flatMap { habit in
            habitManager.entriesForHabit(habit, in: weekAgo...Date())
        }.count
    }
}

struct StatCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    let subtitle: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GlassCard(cornerRadius: DesignSystem.CornerRadius.md, padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    ColoredIconBackground(color: color, size: DesignSystem.Spacing.xl + DesignSystem.Spacing.xs, iconOpacity: DesignSystem.Opacity.light + 0.05)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: DesignSystem.IconSize.md))
                }
                
                Text(value)
                    .font(.system(size: DesignSystem.IconSize.lg + 4, weight: .bold, design: .rounded))
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Habit Row

struct HabitRow: View {
    let habit: Habit
    let date: Date
    let onTap: () -> Void
    let onComplete: (Double) -> Void
    
    @State private var isCompleted: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var habitManager: HabitManager
    
    private var entry: HabitEntry? {
        habit.entries?.first { entry in
            guard let entry = entry as? HabitEntry,
                  let entryDate = entry.date else { return false }
            return Calendar.current.isDate(entryDate, inSameDayAs: date)
        } as? HabitEntry
    }
    
    private var habitColor: Color {
        Color(hex: habit.colorHex ?? "#007AFF")
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Tappable area for details
            Button {
                onTap()
            } label: {
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Simple icon
                    Image(systemName: habit.iconName ?? "star.fill")
                        .foregroundColor(habitColor)
                        .font(.system(size: DesignSystem.IconSize.md, weight: .medium))
                        .frame(width: DesignSystem.IconSize.lg + 4)
                    
                    // Habit info
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text(habit.name ?? "")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(isCompleted ? .secondary : .primary)
                        
                        // Progress info for non-binary habits
                        if habit.trackingTypeEnum != .binary {
                            if let entry = entry {
                                Text("\(formatEntryValue(entry)) / \(Int(habit.goalTarget)) \(habit.goalUnit ?? "")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("0 / \(Int(habit.goalTarget)) \(habit.goalUnit ?? "")")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(DesignSystem.Opacity.disabled + 0.1))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Streak badge if active
                    if habit.currentStreak > 0 {
                        HStack(spacing: DesignSystem.Spacing.xxs - 1) {
                            Text("\(habit.currentStreak)")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "flame.fill")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Separate completion button with larger tap area
            Button {
                handleCompletion()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: DesignSystem.IconSize.lg))
                    .foregroundColor(isCompleted ? habitColor : .gray.opacity(DesignSystem.Opacity.strong))
                    .frame(width: DesignSystem.IconSize.xxl, height: DesignSystem.IconSize.xxl) // Larger tap target
                    .contentShape(Rectangle()) // Make entire frame tappable
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, DesignSystem.Spacing.lg - 4)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .contextMenu {
            Button {
                handleCompletion()
            } label: {
                Label(isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: isCompleted ? "xmark.circle" : "checkmark.circle")
            }
            
            Button {
                onTap()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
        }
        .onAppear {
            isCompleted = entry != nil && !entry!.skipped
        }
        .onChange(of: isCompleted) { _, newValue in
            // Update when changed
        }
    }
    
    private func handleCompletion() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if isCompleted {
            // Remove entry
            if let entry = entry {
                _ = habitManager.deleteEntry(entry)
                // Removed animation for faster response
                isCompleted = false
            }
        } else {
            // Complete with default value based on type
            let value: Double
            switch habit.trackingTypeEnum {
            case .binary:
                value = 1.0
            case .quantity, .duration:
                value = habit.goalTarget
            case .quality:
                value = 5.0 // Default to max quality
            }
            
            onComplete(value)
            // Removed animation for faster response
            isCompleted = true
        }
    }
    
    private func formatEntryValue(_ entry: HabitEntry) -> String {
        switch habit.trackingTypeEnum {
        case .quantity:
            return "\(Int(entry.value))"
        case .duration:
            return "\(Int(entry.value)) min"
        case .quality:
            let stars = Int(entry.value)
            return String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)
        case .binary:
            return "✓"
        }
    }
}





#Preview {
    HabitsView()
        .environmentObject(HabitManager.shared)
        .environmentObject(SubscriptionManager.shared)
}