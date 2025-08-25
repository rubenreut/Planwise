//
//  GoalDetailView.swift
//  Momentum
//
//  Detailed goal view with progress tracking and updates
//

import SwiftUI
import Charts

struct GoalDetailView: View {
    @ObservedObject var goal: Goal
    @EnvironmentObject private var goalManager: GoalManager
    @EnvironmentObject private var habitManager: HabitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    @State private var showingUpdateProgress = false
    @State private var showingAddMilestone = false
    @State private var showingEditGoal = false
    @State private var progressValue: Double = 0
    @State private var updateNotes = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header Card
                    headerCard
                    
                    // Progress Overview
                    progressOverview
                    
                    // Quick Actions
                    if !goal.isCompleted {
                        quickActions
                    }
                    
                    // Milestones (if applicable)
                    if goal.typeEnum == .milestone || goal.typeEnum == .project {
                        milestonesSection
                    }
                    
                    // Progress History Chart
                    progressHistoryChart
                    
                    // Recent Updates
                    recentUpdatesSection
                    
                    // Linked Habits (if applicable)
                    if goal.typeEnum == .habit {
                        linkedHabitsSection
                    }
                    
                    Spacer(minLength: DesignSystem.Spacing.xxl)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .background(Color.adaptiveBackground)
            .navigationTitle("Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingEditGoal = true
                        } label: {
                            Label("Edit Goal", systemImage: "pencil")
                        }
                        
                        if !goal.isCompleted {
                            Button {
                                markAsCompleted()
                            } label: {
                                Label("Mark as Completed", systemImage: "checkmark.circle")
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            deleteGoal()
                        } label: {
                            Label("Delete Goal", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingUpdateProgress) {
                UpdateProgressSheet(
                    goal: goal,
                    progressValue: $progressValue,
                    notes: $updateNotes
                ) {
                    updateProgress()
                }
            }
            .sheet(isPresented: $showingAddMilestone) {
                AddMilestoneSheet(goal: goal)
            }
            .sheet(isPresented: $showingEditGoal) {
                EditGoalSheet(goal: goal)
                    .environmentObject(habitManager)
            }
            .onAppear {
                progressValue = goal.currentValue
            }
        }
    }
    
    // MARK: - Components
    
    private var headerCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Icon and Title
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color(hex: goal.category?.colorHex ?? "#007AFF").opacity(DesignSystem.Opacity.medium))
                        .frame(width: DesignSystem.IconSize.xxl + DesignSystem.Spacing.md, height: DesignSystem.IconSize.xxl + DesignSystem.Spacing.md)
                    
                    Image(systemName: goal.category?.iconName ?? "target")
                        .font(.title)
                        .foregroundColor(Color(hex: goal.category?.colorHex ?? "#007AFF"))
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(goal.title ?? "")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let desc = goal.desc {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Stats Row
            HStack(spacing: DesignSystem.Spacing.lg) {
                VStack(spacing: 4) {
                    Text("Priority")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: goal.priorityEnum.color))
                            .frame(width: 8, height: 8)
                        Text(goal.priorityEnum.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: goal.priorityEnum.color))
                    }
                }
                
                if let daysRemaining = goal.daysRemaining {
                    GoalStatItem(
                        label: "Days Left",
                        value: "\(daysRemaining)",
                        color: daysRemaining <= 7 ? .orange : Color.fromAccentString(selectedAccentColor)
                    )
                }
                
                if goal.isCompleted {
                    GoalStatItem(
                        label: "Status",
                        value: "Completed",
                        color: .green
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(DesignSystem.Shadow.md.opacity), radius: DesignSystem.Shadow.md.radius)
        )
    }
    
    private var progressOverview: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Minimal progress bar
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text("\(Int(goal.progress * 100))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if goal.typeEnum == .numeric {
                        Text("\(Int(goal.currentValue)) / \(Int(goal.targetValue)) \(goal.unit ?? "")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if goal.typeEnum == .milestone || goal.typeEnum == .project {
                        let milestones = goal.sortedMilestones
                        let completedCount = milestones.filter { $0.isCompleted }.count
                        Text("\(completedCount) / \(milestones.count) milestones")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: goal.category?.colorHex ?? "#007AFF"))
                            .frame(width: geometry.size.width * goal.progress, height: 8)
                            .animation(.spring(response: 0.5), value: goal.progress)
                    }
                }
                .frame(height: 8)
            }
            
            // Stats row
            if goal.typeEnum == .numeric && goal.targetValue > 0 {
                HStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Average")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let startDate = goal.startDate {
                            let days = max(1, Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 1)
                            let average = goal.currentValue / Double(days)
                            Text("\(Int(average)) \(goal.unit ?? "")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if let daysRemaining = goal.daysRemaining, daysRemaining > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Required Daily")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            let remaining = goal.targetValue - goal.currentValue
                            let dailyNeeded = remaining / Double(daysRemaining)
                            Text("\(Int(ceil(dailyNeeded))) \(goal.unit ?? "")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(dailyNeeded > 10 ? .orange : .primary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(UIColor.tertiarySystemFill))
        )
    }
    
    private var quickActions: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                showingUpdateProgress = true
            } label: {
                Label("Update Progress", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            if goal.typeEnum == .milestone || goal.typeEnum == .project {
                Button {
                    showingAddMilestone = true
                } label: {
                    Label("Add Milestone", systemImage: "flag")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Milestones")
                .font(.headline)
            
            if goal.sortedMilestones.isEmpty {
                Text("No milestones added yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            } else {
                ForEach(goal.sortedMilestones) { milestone in
                    MilestoneRow(milestone: milestone) {
                        completeMilestone(milestone)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteMilestone(milestone)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(UIColor.tertiarySystemFill))
        )
    }
    
    private var progressHistoryChart: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Progress History")
                .font(.headline)
            
            if goal.recentUpdates.isEmpty {
                Text("No progress updates yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xl)
            } else {
                Chart(goal.recentUpdates) { update in
                    LineMark(
                        x: .value("Date", update.date ?? Date()),
                        y: .value("Progress", update.value)
                    )
                    .foregroundStyle(Color(hex: goal.category?.colorHex ?? "#007AFF"))
                    
                    PointMark(
                        x: .value("Date", update.date ?? Date()),
                        y: .value("Progress", update.value)
                    )
                    .foregroundStyle(Color(hex: goal.category?.colorHex ?? "#007AFF"))
                }
                .frame(height: 200)
                .chartYScale(domain: 0...(goal.targetValue > 0 ? goal.targetValue : 100))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(UIColor.tertiarySystemFill))
        )
    }
    
    private var recentUpdatesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Recent Updates")
                .font(.headline)
            
            if goal.recentUpdates.isEmpty {
                Text("No updates yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            } else {
                ForEach(goal.recentUpdates.prefix(5)) { update in
                    HStack {
                        Image(systemName: updateIcon(for: update))
                            .foregroundColor(Color(hex: goal.category?.colorHex ?? "#007AFF"))
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                            Text(update.notes ?? "Progress update")
                                .font(.subheadline)
                            
                            HStack {
                                Text(update.date ?? Date(), style: .date)
                                Text("•")
                                Text("\(Int(update.value)) \(goal.unit ?? "")")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(UIColor.tertiarySystemFill))
        )
    }
    
    private var linkedHabitsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Linked Habits")
                .font(.headline)
            
            let habits = goal.linkedHabits?.allObjects as? [Habit] ?? []
            
            if habits.isEmpty {
                Text("No linked habits")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            } else {
                ForEach(habits) { habit in
                    HStack {
                        Image(systemName: habit.iconName ?? "star")
                            .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                        
                        Text(habit.name ?? "")
                        
                        Spacer()
                        
                        HStack(spacing: DesignSystem.Spacing.xxs) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("\(habit.currentStreak)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(UIColor.tertiarySystemFill))
        )
    }
    
    // MARK: - Actions
    
    private func updateProgress() {
        _ = goalManager.updateProgress(
            for: goal,
            value: progressValue,
            notes: updateNotes.isEmpty ? nil : updateNotes
        )
        showingUpdateProgress = false
        updateNotes = ""
    }
    
    private func completeMilestone(_ milestone: GoalMilestone) {
        _ = goalManager.completeMilestone(milestone)
    }
    
    private func deleteMilestone(_ milestone: GoalMilestone) {
        _ = goalManager.deleteMilestone(milestone, from: goal)
    }
    
    private func markAsCompleted() {
        goal.isCompleted = true
        goal.completedDate = Date()
        _ = goalManager.updateGoal(goal)
    }
    
    private func deleteGoal() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            _ = goalManager.deleteGoal(goal)
        }
    }
    
    private func updateIcon(for update: GoalUpdate) -> String {
        switch update.type {
        case GoalUpdateType.milestone.rawValue:
            return "flag.checkered"
        case GoalUpdateType.note.rawValue:
            return "note.text"
        default:
            return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Supporting Views

struct GoalStatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct MilestoneRow: View {
    let milestone: GoalMilestone
    let onComplete: () -> Void
    
    var body: some View {
        HStack {
            Button {
                if !milestone.isCompleted {
                    onComplete()
                }
            } label: {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(milestone.isCompleted ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title ?? "")
                    .strikethrough(milestone.isCompleted)
                    .foregroundColor(milestone.isCompleted ? .secondary : .primary)
                
                if milestone.isCompleted, let date = milestone.completedDate {
                    Text("Completed \(date, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(Int(milestone.targetValue))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct UpdateProgressSheet: View {
    let goal: Goal
    @Binding var progressValue: Double
    @Binding var notes: String
    let onUpdate: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Progress")
                            .font(.headline)
                        
                        HStack {
                            TextField("0", value: $progressValue, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            if let unit = goal.unit {
                                Text(unit)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if goal.targetValue > 0 {
                            Slider(value: $progressValue, in: 0...goal.targetValue, step: 1.0)
                                .accentColor(Color(hex: goal.category?.colorHex ?? "#007AFF"))
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Notes (optional)")
                            .font(.headline)
                        
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                    }
                }
            }
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update") {
                        onUpdate()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct AddMilestoneSheet: View {
    let goal: Goal
    @State private var title = ""
    @State private var targetValue: Double = 0
    @EnvironmentObject private var goalManager: GoalManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Milestone Title", text: $title)
                    
                    HStack {
                        TextField("Target Value", value: $targetValue, format: .number)
                            .keyboardType(.decimalPad)
                        
                        if let unit = goal.unit {
                            Text(unit)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        _ = goalManager.addMilestone(
                            to: goal,
                            title: title,
                            targetValue: targetValue
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || targetValue <= 0)
                }
            }
        }
    }
}

struct EditGoalSheet: View {
    let goal: Goal
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var targetValue: Double = 0
    @State private var unit: String = ""
    @State private var selectedType: GoalType = .numeric
    @State private var selectedPriority: GoalPriority = .medium
    @State private var targetDate: Date = Date()
    @State private var selectedColor: String = "#007AFF"
    @State private var selectedIcon: String = "target"
    @State private var selectedCategory: Category?
    @State private var selectedHabits: Set<Habit> = []
    @State private var showingColorPicker = false
    @State private var showingIconPicker = false
    @State private var showingHabitPicker = false
    @State private var showingAddMilestone = false
    @State private var editedMilestones: [GoalMilestone] = []
    
    @EnvironmentObject private var goalManager: GoalManager
    @EnvironmentObject private var habitManager: HabitManager
    @StateObject private var areaManager = GoalAreaManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section(header: Text("Basic Information")) {
                    TextField("Goal Title", text: $title)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Description, links, or attachments...", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("You can paste links or describe documents here")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Goal Type and Values
                Section(header: Text("Goal Details")) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    if selectedType == .numeric {
                        HStack {
                            TextField("Target Value", value: $targetValue, format: .number)
                                .keyboardType(.decimalPad)
                            
                            TextField("Unit", text: $unit)
                                .frame(maxWidth: 100)
                        }
                    }
                    
                    DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                    
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(GoalPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(Color(hex: priority.color))
                                    .frame(width: 8, height: 8)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                }
                
                // Linked Habits for habit-based goals
                if selectedType == .habit {
                    Section(header: Text("Linked Habits")) {
                        Button {
                            showingHabitPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                    .font(.system(size: 17))
                                    .foregroundColor(.indigo)
                                
                                Text("Link Habits")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if !selectedHabits.isEmpty {
                                    Text("\(selectedHabits.count) selected")
                                        .foregroundColor(.secondary)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                        }
                        
                        // Display selected habits
                        if !selectedHabits.isEmpty {
                            ForEach(Array(selectedHabits)) { habit in
                                HStack {
                                    Image(systemName: habit.iconName ?? "star")
                                        .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                                    Text(habit.name ?? "")
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                
                // Milestones for milestone/project goals
                if selectedType == .milestone || selectedType == .project {
                    Section(header: Text("Milestones")) {
                        Button {
                            showingAddMilestone = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(.blue)
                                
                                Text("Add Milestone")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                        
                        // Display existing milestones
                        ForEach(editedMilestones) { milestone in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(milestone.title ?? "")
                                        .font(.system(size: 16))
                                    
                                    if milestone.targetValue > 0 {
                                        Text("Target: \(Int(milestone.targetValue))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if milestone.isCompleted {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                            Text("Completed")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if !milestone.isCompleted {
                                    Button {
                                        HapticFeedback.light.trigger()
                                        withAnimation {
                                            editedMilestones.removeAll { $0.id == milestone.id }
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 16))
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Category/Area Selection
                Section(header: Text("Category")) {
                    Picker("Area", selection: $selectedCategory) {
                        Text("None").tag(nil as Category?)
                        ForEach(areaManager.categories.filter { $0.isActive }) { category in
                            HStack {
                                Image(systemName: category.iconName ?? "folder.fill")
                                    .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                                Text(category.name ?? "")
                            }
                            .tag(category as Category?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Appearance
                Section(header: Text("Appearance")) {
                    Button(action: { showingColorPicker = true }) {
                        HStack {
                            Text("Color")
                                .foregroundColor(.primary)
                            Spacer()
                            Circle()
                                .fill(Color(hex: selectedColor))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    
                    Button(action: { showingIconPicker = true }) {
                        HStack {
                            Text("Icon")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: selectedIcon)
                                .font(.title2)
                                .foregroundColor(Color(hex: selectedColor))
                        }
                    }
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateGoal()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                // Load categories first
                areaManager.loadCategories()
                
                // Load current goal values
                title = goal.title ?? ""
                description = goal.desc ?? ""
                targetValue = goal.targetValue
                unit = goal.unit ?? ""
                selectedType = goal.typeEnum
                selectedPriority = goal.priorityEnum
                targetDate = goal.targetDate ?? Date()
                selectedColor = goal.category?.colorHex ?? "#007AFF"
                selectedIcon = goal.category?.iconName ?? "target"
                selectedCategory = goal.category
                
                // Load linked habits
                if let linkedHabits = goal.linkedHabits?.allObjects as? [Habit] {
                    selectedHabits = Set(linkedHabits)
                }
                
                // Load existing milestones
                if let milestones = goal.milestones?.allObjects as? [GoalMilestone] {
                    editedMilestones = milestones.sorted { 
                        ($0.sortOrder, $0.title ?? "") < ($1.sortOrder, $1.title ?? "")
                    }
                }
            }
            .sheet(isPresented: $showingColorPicker) {
                GoalColorPickerSheet(selectedColor: $selectedColor)
            }
            .sheet(isPresented: $showingIconPicker) {
                GoalIconPickerSheet(selectedIcon: $selectedIcon, selectedColor: selectedColor)
            }
            .sheet(isPresented: $showingHabitPicker) {
                HabitPickerSheet(selectedHabits: $selectedHabits)
                    .environmentObject(habitManager)
            }
            .sheet(isPresented: $showingAddMilestone) {
                AddEditMilestoneSheet(
                    goal: goal,
                    milestones: $editedMilestones,
                    isPresented: $showingAddMilestone
                )
            }
        }
    }
    
    private func updateGoal() {
        print("🎯 UpdateGoal - Selected category: \(selectedCategory?.name ?? "None")")
        print("🎯 UpdateGoal - Category ID: \(selectedCategory?.id?.uuidString ?? "nil")")
        
        // Use the proper updateGoal function with parameters
        let result = goalManager.updateGoal(
            goal,
            title: title,
            description: description.isEmpty ? nil : description,
            targetValue: targetValue,
            targetDate: targetDate,
            unit: unit.isEmpty ? nil : unit,
            priority: selectedPriority,
            category: selectedCategory,
            updateCategory: true  // Explicitly update category
        )
        
        // Also update the type directly since it's not in the updateGoal function parameters
        goal.type = selectedType.rawValue
        goal.modifiedAt = Date()
        
        // Update linked habits if this is a habit-based goal
        if selectedType == .habit {
            // Get current linked habits
            let currentHabits = Set((goal.linkedHabits?.allObjects as? [Habit]) ?? [])
            
            // Find habits to unlink (in current but not in selected)
            let habitsToUnlink = currentHabits.subtracting(selectedHabits)
            for habit in habitsToUnlink {
                _ = goalManager.unlinkHabit(habit, from: goal)
            }
            
            // Find habits to link (in selected but not in current)
            let habitsToLink = selectedHabits.subtracting(currentHabits)
            for habit in habitsToLink {
                _ = goalManager.linkHabit(habit, to: goal)
            }
        }
        
        // Update milestones if this is a milestone/project goal
        if selectedType == .milestone || selectedType == .project {
            // Get current milestones
            let currentMilestones = goal.milestones?.allObjects as? [GoalMilestone] ?? []
            
            // Delete removed milestones
            for milestone in currentMilestones {
                if !editedMilestones.contains(where: { $0.id == milestone.id }) {
                    _ = goalManager.deleteMilestone(milestone, from: goal)
                }
            }
            
            // Add new milestones (those without IDs or not in current)
            for milestone in editedMilestones {
                if !currentMilestones.contains(where: { $0.id == milestone.id }) {
                    _ = goalManager.addMilestone(
                        to: goal,
                        title: milestone.title ?? "",
                        targetValue: milestone.targetValue
                    )
                }
            }
        }
        
        // Save the context to ensure changes persist
        do {
            try goal.managedObjectContext?.save()
            print("🎯 UpdateGoal - Context saved successfully")
        } catch {
            print("🎯 UpdateGoal - Failed to save goal changes: \(error)")
        }
        
        // Print result
        switch result {
        case .success:
            print("🎯 UpdateGoal - Goal updated successfully")
            print("🎯 UpdateGoal - Goal category after update: \(goal.category?.name ?? "None")")
            print("🎯 UpdateGoal - Linked habits count: \(goal.linkedHabits?.count ?? 0)")
        case .failure(let error):
            print("🎯 UpdateGoal - Failed to update goal: \(error)")
        }
    }
}

// MARK: - Goal Color Picker Sheet

struct GoalColorPickerSheet: View {
    @Binding var selectedColor: String
    @Environment(\.dismiss) private var dismiss
    
    let colors = [
        "#007AFF", "#34C759", "#FF3B30", "#FF9500",
        "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE",
        "#32ADE6", "#FFD60A", "#8E8E93", "#F2B8D4"
    ]
    
    let columns = [GridItem(.adaptive(minimum: 60))]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.md) {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            selectedColor = color
                            dismiss()
                        } label: {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    selectedColor == color ?
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 3)
                                        .padding(-4)
                                    : nil
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Goal Icon Picker Sheet  

struct GoalIconPickerSheet: View {
    @Binding var selectedIcon: String
    let selectedColor: String
    @Environment(\.dismiss) private var dismiss
    
    let icons = [
        "target", "flag.checkered", "chart.line.uptrend.xyaxis", "trophy",
        "star", "bolt", "flame", "heart",
        "book", "graduationcap", "dollarsign", "house",
        "airplane", "car", "bicycle", "figure.run",
        "briefcase.fill", "heart.fill", "figure.run", "dumbbell.fill",
        "leaf.fill", "moon.fill", "sun.max.fill", "sparkles",
        "paintbrush.fill", "music.note", "camera.fill", "gamecontroller.fill"
    ]
    
    let columns = [GridItem(.adaptive(minimum: 60))]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.md) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                            dismiss()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.2) : Color(UIColor.tertiarySystemFill))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : .primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    // Create a sample goal for preview
    let goal = Goal(context: PersistenceController.preview.container.viewContext)
    goal.title = "Read 50 Books"
    goal.desc = "Complete my reading challenge for the year"
    goal.type = GoalType.numeric.rawValue
    goal.targetValue = 50
    goal.currentValue = 23
    goal.unit = "books"
    // Color and icon come from category
    goal.startDate = Date()
    goal.targetDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())
    
    return GoalDetailView(goal: goal)
        .environmentObject(GoalManager.shared)
}

// MARK: - Add/Edit Milestone Sheet

struct AddEditMilestoneSheet: View {
    let goal: Goal
    @Binding var milestones: [GoalMilestone]
    @Binding var isPresented: Bool
    
    @State private var title = ""
    @State private var targetValue: Double = 0
    @State private var includeTarget = false
    @FocusState private var isTitleFocused: Bool
    
    @EnvironmentObject private var goalManager: GoalManager
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Milestone title", text: $title)
                        .focused($isTitleFocused)
                    
                    Toggle("Include target value", isOn: $includeTarget.animation())
                        .onChange(of: includeTarget) { _, _ in
                            HapticFeedback.selection.trigger()
                        }
                    
                    if includeTarget {
                        HStack {
                            Text("Target")
                            Spacer()
                            TextField("0", value: $targetValue, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }
                
                if !milestones.isEmpty {
                    Section(header: Text("Existing Milestones")) {
                        ForEach(milestones) { milestone in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(milestone.title ?? "")
                                        .font(.system(size: 15))
                                    if milestone.targetValue > 0 {
                                        Text("Target: \(Int(milestone.targetValue))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if milestone.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticFeedback.light.trigger()
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        HapticFeedback.success.trigger()
                        
                        // Create a temporary milestone to add to the list
                        let context = goal.managedObjectContext ?? PersistenceController.shared.container.viewContext
                        let newMilestone = GoalMilestone(context: context)
                        newMilestone.id = UUID()
                        newMilestone.title = title
                        newMilestone.targetValue = includeTarget ? targetValue : 0
                        newMilestone.isCompleted = false
                        newMilestone.sortOrder = Int32(milestones.count)
                        
                        milestones.append(newMilestone)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTitleFocused = true
                }
            }
        }
    }
}