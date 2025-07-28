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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
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
                        .fill(Color(hex: goal.colorHex ?? "#007AFF").opacity(DesignSystem.Opacity.medium))
                        .frame(width: DesignSystem.IconSize.xxl + DesignSystem.Spacing.md, height: DesignSystem.IconSize.xxl + DesignSystem.Spacing.md)
                    
                    Image(systemName: goal.iconName ?? "target")
                        .font(.title)
                        .foregroundColor(Color(hex: goal.colorHex ?? "#007AFF"))
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
                GoalStatItem(
                    label: "Priority",
                    value: goal.priorityEnum.displayName,
                    color: Color(hex: goal.priorityEnum.color)
                )
                
                if let daysRemaining = goal.daysRemaining {
                    GoalStatItem(
                        label: "Days Left",
                        value: "\(daysRemaining)",
                        color: daysRemaining <= 7 ? .orange : .blue
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
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Progress Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(DesignSystem.Opacity.medium), lineWidth: 20)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .trim(from: 0, to: goal.progress)
                    .stroke(
                        Color(hex: goal.colorHex ?? "#007AFF"),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: goal.progress)
                
                VStack(spacing: DesignSystem.Spacing.xxs) {
                    Text("\(Int(goal.progress * 100))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("percent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Current vs Target
            if goal.typeEnum == .numeric {
                HStack(spacing: DesignSystem.Spacing.xl) {
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(goal.currentValue))")
                            .font(.title2)
                            .fontWeight(.bold)
                        if let unit = goal.unit {
                            Text(unit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("Target")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(goal.targetValue))")
                            .font(.title2)
                            .fontWeight(.bold)
                        if let unit = goal.unit {
                            Text(unit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else if goal.typeEnum == .milestone || goal.typeEnum == .project {
                // For milestone goals, show milestone completion status
                VStack(spacing: DesignSystem.Spacing.xxs) {
                    Text("Milestones")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let milestones = goal.sortedMilestones
                    let completedCount = milestones.filter { $0.isCompleted }.count
                    
                    HStack {
                        Text("\(completedCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("of")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(milestones.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
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
                    .foregroundStyle(Color(hex: goal.colorHex ?? "#007AFF"))
                    
                    PointMark(
                        x: .value("Date", update.date ?? Date()),
                        y: .value("Progress", update.value)
                    )
                    .foregroundStyle(Color(hex: goal.colorHex ?? "#007AFF"))
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
                            .foregroundColor(Color(hex: goal.colorHex ?? "#007AFF"))
                        
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
                                .accentColor(Color(hex: goal.colorHex ?? "#007AFF"))
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
    
    @EnvironmentObject private var goalManager: GoalManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section(header: Text("Basic Information")) {
                    TextField("Goal Title", text: $title)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
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
                
                // Appearance
                Section(header: Text("Appearance")) {
                    HStack {
                        Text("Color")
                        Spacer()
                        Circle()
                            .fill(Color(hex: selectedColor))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    HStack {
                        Text("Icon")
                        Spacer()
                        Image(systemName: selectedIcon)
                            .font(.title2)
                            .foregroundColor(Color(hex: selectedColor))
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
                // Load current goal values
                title = goal.title ?? ""
                description = goal.desc ?? ""
                targetValue = goal.targetValue
                unit = goal.unit ?? ""
                selectedType = goal.typeEnum
                selectedPriority = goal.priorityEnum
                targetDate = goal.targetDate ?? Date()
                selectedColor = goal.colorHex ?? "#007AFF"
                selectedIcon = goal.iconName ?? "target"
            }
        }
    }
    
    private func updateGoal() {
        goal.title = title
        goal.desc = description.isEmpty ? nil : description
        goal.type = selectedType.rawValue
        goal.targetValue = targetValue
        goal.unit = unit.isEmpty ? nil : unit
        goal.priority = selectedPriority.rawValue
        goal.targetDate = targetDate
        goal.colorHex = selectedColor
        goal.iconName = selectedIcon
        
        _ = goalManager.updateGoal(goal)
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
    goal.colorHex = "#007AFF"
    goal.iconName = "book"
    goal.startDate = Date()
    goal.targetDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())
    
    return GoalDetailView(goal: goal)
        .environmentObject(GoalManager.shared)
}