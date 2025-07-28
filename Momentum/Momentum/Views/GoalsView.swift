//
//  GoalsView.swift
//  Momentum
//
//  Display and manage goals with progress tracking
//

import SwiftUI
import Charts

struct GoalsView: View {
    @EnvironmentObject private var goalManager: GoalManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedGoal: Goal?
    @State private var showingAddGoal = false
    @State private var selectedFilter: GoalFilter = .active
    @Environment(\.colorScheme) var colorScheme
    
    enum GoalFilter: String, CaseIterable {
        case active = "Active"
        case completed = "Completed" 
        case all = "All"
        
        var icon: String {
            switch self {
            case .active: return "target"
            case .completed: return "checkmark.circle.fill"
            case .all: return "list.bullet"
            }
        }
    }
    
    var filteredGoals: [Goal] {
        switch selectedFilter {
        case .active:
            return goalManager.activeGoals
        case .completed:
            return goalManager.completedGoals
        case .all:
            return goalManager.goals
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.softBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Goals")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            // Stats Overview
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                GoalStatCard(
                                    value: "\(goalManager.activeGoals.count)",
                                    label: "Active",
                                    color: .blue,
                                    icon: "target"
                                )
                                
                                GoalStatCard(
                                    value: "\(goalManager.completedGoals.count)",
                                    label: "Completed",
                                    color: .green,
                                    icon: "checkmark.circle.fill"
                                )
                                
                                GoalStatCard(
                                    value: String(format: "%.0f%%", goalManager.completionRate() * 100),
                                    label: "Success Rate",
                                    color: .orange,
                                    icon: "chart.line.uptrend.xyaxis"
                                )
                            }
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            
                            // Filter Picker with glass effect
                            Picker("Filter", selection: $selectedFilter) {
                                ForEach(GoalFilter.allCases, id: \.self) { filter in
                                    Label(filter.rawValue, systemImage: filter.icon)
                                        .tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                            .glassmorphic(cornerRadius: DesignSystem.CornerRadius.sm + 4, shadowRadius: DesignSystem.Shadow.sm.radius * 0.75)
                        }
                        .padding(.horizontal)
                        
                        // Upcoming Deadlines
                        if selectedFilter == .active {
                            let upcoming = goalManager.upcomingDeadlines()
                            if !upcoming.isEmpty {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                    Text("Upcoming Deadlines")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: DesignSystem.Spacing.sm) {
                                            ForEach(upcoming) { goal in
                                                DeadlineCard(goal: goal)
                                                    .onTapGesture {
                                                        selectedGoal = goal
                                                    }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        
                        // Goals List
                        if filteredGoals.isEmpty {
                            emptyStateView
                                .padding(.vertical, DesignSystem.Spacing.xxxl - 4)
                        } else {
                            LazyVStack(spacing: DesignSystem.Spacing.md) {
                                ForEach(filteredGoals) { goal in
                                    GoalCard(goal: goal)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedGoal = goal
                                        }
                                    .contextMenu {
                                        Button {
                                            selectedGoal = goal
                                        } label: {
                                            Label("View Details", systemImage: "eye")
                                        }
                                        
                                        if !goal.isCompleted {
                                            Button {
                                                // Quick update progress
                                                showQuickUpdate(for: goal)
                                            } label: {
                                                Label("Update Progress", systemImage: "chart.line.uptrend.xyaxis")
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        Button(role: .destructive) {
                                            deleteGoal(goal)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: DesignSystem.Spacing.xxxl + DesignSystem.Spacing.xl + 4)
                    }
                    .padding(.top)
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        FloatingActionButton(
                            icon: "plus",
                            accessibilityLabel: "Add new goal"
                        ) {
                            showingAddGoal = true
                        }
                        .padding(.trailing, DesignSystem.Spacing.lg - 4)
                        .padding(.bottom, DesignSystem.Spacing.lg - 4)
                    }
                }
            }
            .navigationBarHidden(DeviceType.isIPad ? false : true) // Show nav bar on iPad for sidebar toggle
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(item: $selectedGoal) { goal in
                GoalDetailView(goal: goal)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
    }
    
    private var emptyStateView: some View {
        Group {
            switch selectedFilter {
            case .all:
                EmptyStateView(config: .noGoals {
                    showingAddGoal = true
                })
            case .active:
                EmptyStateView(config: .noActiveGoals(
                    action: { showingAddGoal = true },
                    viewCompleted: { selectedFilter = .completed }
                ))
            case .completed:
                EmptyStateView(config: EmptyStateConfig(
                    illustration: AnyView(CelebrationIllustration()),
                    title: "No Completed Goals Yet",
                    subtitle: "Your journey to achievement starts with setting meaningful goals. Each completed goal is a victory worth celebrating.",
                    tip: "Set SMART goals: Specific, Measurable, Achievable, Relevant, Time-bound",
                    accentColor: .adaptiveGreen,
                    actions: [
                        EmptyStateAction(
                            title: "Set Your First Goal",
                            icon: "flag.fill",
                            handler: { showingAddGoal = true }
                        ),
                        EmptyStateAction(
                            title: "View Active Goals",
                            icon: "target",
                            isPrimary: false,
                            handler: { selectedFilter = .active }
                        )
                    ]
                ))
            }
        }
    }
    
    private func showQuickUpdate(for goal: Goal) {
        // TODO: Implement quick update sheet
    }
    
    private func deleteGoal(_ goal: Goal) {
        _ = goalManager.deleteGoal(goal)
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: Goal
    @Environment(\.colorScheme) var colorScheme
    
    private var goalColor: Color {
        Color(hex: goal.colorHex ?? "#007AFF")
    }
    
    var body: some View {
        GlassCard(cornerRadius: DesignSystem.CornerRadius.lg - 4, padding: 0) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Header
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Icon with colored background
                    ZStack {
                        ColoredIconBackground(color: goalColor, size: DesignSystem.IconSize.xxl + 6)
                        Image(systemName: goal.iconName ?? "target")
                            .font(.system(size: DesignSystem.IconSize.lg))
                            .foregroundColor(goalColor)
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text(goal.title ?? "")
                            .font(.headline)
                        
                        if let desc = goal.desc {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Priority Badge
                    PriorityBadge(priority: goal.priorityEnum)
                }
                
                // Progress Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Progress Header
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                            Text("\(Int(goal.progress * 100))%")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                            if goal.typeEnum == .milestone || goal.typeEnum == .project {
                                let milestones = goal.sortedMilestones
                                let completedCount = milestones.filter { $0.isCompleted }.count
                                Text("\(completedCount)/\(milestones.count) milestones")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Progress")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if let targetDate = goal.targetDate {
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                Text(targetDate, style: .date)
                                    .font(.caption)
                            }
                            .foregroundColor(goal.isOverdue ? .red : .secondary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs - 2)
                            .background(
                                Capsule()
                                    .fill(goal.isOverdue ? Color.red.opacity(DesignSystem.Opacity.light) : Color.gray.opacity(DesignSystem.Opacity.light))
                            )
                        }
                    }
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm - 2)
                                .fill(Color.gray.opacity(DesignSystem.Opacity.light))
                                .frame(height: DesignSystem.Spacing.sm)
                            
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm - 2)
                                .fill(
                                    LinearGradient(
                                        colors: [goalColor, goalColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * goal.progress, height: DesignSystem.Spacing.sm)
                                // Removed animation for faster response
                        }
                    }
                    .frame(height: DesignSystem.Spacing.sm)
                }
                
                // Stats Row
                HStack(spacing: DesignSystem.Spacing.md) {
                    if goal.typeEnum == .numeric {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Text("\(Int(goal.currentValue))")
                                    .fontWeight(.semibold)
                                Text("/")
                                    .foregroundColor(.secondary)
                                Text("\(Int(goal.targetValue))")
                                if let unit = goal.unit {
                                    Text(unit)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.callout)
                            Text("Current")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let daysRemaining = goal.daysRemaining, !goal.isCompleted {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs / 2) {
                            Text("\(daysRemaining)")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(daysRemaining <= 7 ? .orange : .primary)
                            Text("Days left")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if goal.isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Completed")
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(DesignSystem.Opacity.light))
                        )
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg - 4)
        }
    }
}

// MARK: - Deadline Card

struct DeadlineCard: View {
    let goal: Goal
    
    private var goalColor: Color {
        Color(hex: goal.colorHex ?? "#007AFF")
    }
    
    var body: some View {
        GlassCard(cornerRadius: DesignSystem.CornerRadius.md, padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    ColoredIconBackground(color: goalColor, size: DesignSystem.Spacing.xl + DesignSystem.Spacing.xs, iconOpacity: DesignSystem.Opacity.light + 0.05)
                    Image(systemName: goal.iconName ?? "target")
                        .font(.system(size: DesignSystem.IconSize.md))
                        .foregroundColor(goalColor)
                }
                
                Text(goal.title ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let days = goal.daysRemaining {
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text("\(days) days")
                            .fontWeight(.bold)
                    }
                    .font(.caption)
                    .foregroundColor(days <= 3 ? .red : .orange)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill((days <= 3 ? Color.red : Color.orange).opacity(DesignSystem.Opacity.light))
                    )
                }
            }
            .frame(width: DesignSystem.Spacing.xxxl + DesignSystem.Spacing.xxl + 8)
        }
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: GoalPriority
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(hex: priority.color))
            )
    }
}

// MARK: - Goal Stat Card

struct GoalStatCard: View {
    let value: String
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        GlassCard(cornerRadius: DesignSystem.CornerRadius.md, padding: DesignSystem.Spacing.md) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    ColoredIconBackground(color: color, size: DesignSystem.IconSize.xxl, iconOpacity: DesignSystem.Opacity.light + 0.05)
                    Image(systemName: icon)
                        .font(.system(size: DesignSystem.IconSize.lg - 2))
                        .foregroundColor(color)
                }
                
                VStack(spacing: DesignSystem.Spacing.xxs) {
                    Text(value)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                    
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}


#Preview {
    GoalsView()
        .environmentObject(GoalManager.shared)
        .environmentObject(SubscriptionManager.shared)
}