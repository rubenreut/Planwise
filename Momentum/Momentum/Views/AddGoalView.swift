//
//  AddGoalView.swift
//  Momentum
//
//  Create new goals with various tracking types
//

import SwiftUI

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var goalManager: GoalManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var habitManager: HabitManager
    
    // Form State
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType: GoalType = .milestone
    @State private var targetValue: Double = 100
    @State private var unit = ""
    @State private var targetDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @State private var hasTargetDate = true
    @State private var priority: GoalPriority = .medium
    @State private var selectedColor = "#007AFF"
    @State private var selectedIcon = "target"
    @State private var selectedCategory: Category?
    @State private var selectedHabits: Set<Habit> = []
    
    // UI State
    @State private var showingIconPicker = false
    @State private var showingHabitPicker = false
    @State private var isCreating = false
    @FocusState private var isTitleFocused: Bool
    @State private var showingPaywall = false
    
    let colors = [
        "#007AFF", "#34C759", "#FF3B30", "#FF9500",
        "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE",
        "#32ADE6", "#FFD60A", "#8E8E93", "#F2B8D4"
    ]
    
    let icons = [
        "target", "flag.checkered", "chart.line.uptrend.xyaxis", "trophy",
        "star", "bolt", "flame", "heart",
        "book", "graduationcap", "dollarsign", "house",
        "airplane", "car", "bicycle", "figure.run"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header with Icon
                    VStack(spacing: DesignSystem.Spacing.md + 4) {
                        Button {
                            showingIconPicker = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: selectedColor).opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: selectedIcon)
                                    .font(.system(size: DesignSystem.IconSize.xl + 4))
                                    .foregroundColor(Color(hex: selectedColor))
                                
                                // Edit indicator
                                ZStack {
                                    Circle()
                                        .fill(Color(UIColor.systemBackground))
                                        .frame(width: DesignSystem.IconSize.xl - 4, height: DesignSystem.IconSize.xl - 4)
                                    
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: DesignSystem.IconSize.lg))
                                        .foregroundColor(.secondary)
                                }
                                .offset(x: 30, y: 30)
                            }
                        }
                        
                        // Title Input
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            TextField("Goal Title", text: $title)
                                .font(.title2)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .focused($isTitleFocused)
                            
                            Rectangle()
                                .fill(Color(hex: selectedColor))
                                .frame(height: 2)
                                .frame(width: isTitleFocused || !title.isEmpty ? 250 : 150)
                                .animation(.spring(response: 0.3), value: isTitleFocused)
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.md + 4)
                    
                    // Goal Type Selection
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Label("Goal Type", systemImage: "square.grid.2x2")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                            ForEach(GoalType.allCases, id: \.self) { type in
                                GoalTypeCard(
                                    type: type,
                                    isSelected: selectedType == type,
                                    color: Color(hex: selectedColor)
                                ) {
                                    selectedType = type
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Type-specific Fields
                    Group {
                        switch selectedType {
                        case .numeric:
                            numericGoalFields
                        case .habit:
                            habitGoalFields
                        case .milestone, .project:
                            milestoneGoalFields
                        }
                    }
                    .padding(.horizontal)
                    
                    // Common Fields
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Description
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Label("Description", systemImage: "text.alignleft")
                                .font(.headline)
                            
                            TextEditor(text: $description)
                                .frame(minHeight: 80)
                                .padding(DesignSystem.Spacing.xs)
                                .scrollContentBackground(.hidden)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .fill(Color(UIColor.tertiarySystemFill))
                                )
                        }
                        
                        // Target Date
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Toggle(isOn: $hasTargetDate) {
                                Label("Set Target Date", systemImage: "calendar")
                                    .font(.headline)
                            }
                            
                            if hasTargetDate {
                                DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                            }
                        }
                        
                        // Priority
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Priority", systemImage: "flag")
                                .font(.headline)
                            
                            Picker("Priority", selection: $priority) {
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
                            .pickerStyle(.segmented)
                        }
                        
                        // Color Selection
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Color", systemImage: "paintpalette")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(colors, id: \.self) { color in
                                        Button {
                                            selectedColor = color
                                        } label: {
                                            Circle()
                                                .fill(Color(hex: color))
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    selectedColor == color ?
                                                    Circle()
                                                        .stroke(Color.primary, lineWidth: 3)
                                                        .padding(-DesignSystem.Spacing.xxs)
                                                    : nil
                                                )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Category
                        if !scheduleManager.categories.isEmpty {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Label("Category", systemImage: "folder")
                                    .font(.headline)
                                
                                Menu {
                                    Button("None") {
                                        selectedCategory = nil
                                    }
                                    ForEach(scheduleManager.categories) { category in
                                        Button {
                                            selectedCategory = category
                                        } label: {
                                            Label(category.name ?? "", systemImage: category.iconName ?? "folder")
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if let category = selectedCategory {
                                            Image(systemName: category.iconName ?? "folder")
                                            Text(category.name ?? "")
                                        } else {
                                            Text("Select Category")
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .fill(Color(UIColor.tertiarySystemFill))
                                    )
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color.adaptiveBackground)
            .standardNavigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        createGoal()
                    } label: {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerSheet(selectedIcon: $selectedIcon, icons: icons)
            }
            .sheet(isPresented: $showingHabitPicker) {
                HabitPickerSheet(selectedHabits: $selectedHabits)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallViewPremium()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isTitleFocused = true
                }
            }
        }
    }
    
    // MARK: - Type-specific Fields
    
    private var numericGoalFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Target", systemImage: "number")
                .font(.headline)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                TextField("100", value: $targetValue, format: .number)
                    .font(.title)
                    .fontWeight(.bold)
                    .keyboardType(.decimalPad)
                    .frame(width: 100)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.tertiarySystemFill))
                    )
                
                TextField("unit (e.g., miles, books)", text: $unit)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.tertiarySystemFill))
                    )
            }
        }
    }
    
    private var habitGoalFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Link Habits", systemImage: "link")
                .font(.headline)
            
            Button {
                showingHabitPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Select Habits")
                    Spacer()
                    if !selectedHabits.isEmpty {
                        Text("\(selectedHabits.count) selected")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.tertiarySystemFill))
                )
            }
            .foregroundColor(.primary)
            
            if !selectedHabits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(Array(selectedHabits)) { habit in
                            HStack(spacing: DesignSystem.Spacing.xxs) {
                                Image(systemName: habit.iconName ?? "star")
                                Text(habit.name ?? "")
                            }
                            .font(.caption)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xxs + 2)
                            .background(
                                Capsule()
                                    .fill(Color(hex: habit.colorHex ?? "#007AFF").opacity(DesignSystem.Opacity.medium))
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var milestoneGoalFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("This goal will track major milestones", systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func createGoal() {
        isCreating = true
        
        let result = goalManager.createGoal(
            title: title,
            description: description.isEmpty ? nil : description,
            type: selectedType,
            targetValue: selectedType == .numeric ? targetValue : nil,
            targetDate: hasTargetDate ? targetDate : nil,
            unit: unit.isEmpty ? nil : unit,
            priority: priority,
            colorHex: selectedColor,
            iconName: selectedIcon,
            category: selectedCategory,
            linkedHabits: Array(selectedHabits)
        )
        
        switch result {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        case .failure(let error):
            isCreating = false
            if case ScheduleError.subscriptionLimitReached = error {
                showingPaywall = true
            } else {
            }
        }
    }
}

// MARK: - Supporting Views

struct GoalTypeCard: View {
    let type: GoalType
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(isSelected ? color : Color(UIColor.tertiarySystemFill))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct IconPickerSheet: View {
    @Binding var selectedIcon: String
    let icons: [String]
    @Environment(\.dismiss) private var dismiss
    
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
                                    .fill(selectedIcon == icon ? Color.blue.opacity(DesignSystem.Opacity.medium) : Color(UIColor.tertiarySystemFill))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? .blue : .primary)
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

struct HabitPickerSheet: View {
    @Binding var selectedHabits: Set<Habit>
    @EnvironmentObject private var habitManager: HabitManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(habitManager.habits) { habit in
                HStack {
                    Image(systemName: habit.iconName ?? "star")
                        .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                    
                    Text(habit.name ?? "")
                    
                    Spacer()
                    
                    if selectedHabits.contains(habit) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedHabits.contains(habit) {
                        selectedHabits.remove(habit)
                    } else {
                        selectedHabits.insert(habit)
                    }
                }
            }
            .navigationTitle("Select Habits")
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
    AddGoalView()
        .environmentObject(GoalManager.shared)
        .environmentObject(ScheduleManager.shared)
        .environmentObject(HabitManager.shared)
}