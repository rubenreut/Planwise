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
    @StateObject private var areaManager = GoalAreaManager.shared
    
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
    @State private var showingHabitPicker = false
    @State private var showingAreaManager = false
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Title - Structured style
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Goal", text: $title)
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .focused($isTitleFocused)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 8)
                        
                        Divider()
                            .padding(.horizontal, 20)
                    }
                    
                    // Icon & Color - Structured style  
                    VStack(alignment: .leading, spacing: 16) {
                        Text("APPEARANCE")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        // Icon grid
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(icons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedIcon == icon ? .white : Color(hex: selectedColor))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedIcon == icon ? Color(hex: selectedColor) : Color(UIColor.secondarySystemFill))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Color picker
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(colors, id: \.self) { color in
                                    Button {
                                        selectedColor = color
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                selectedColor == color ?
                                                Circle()
                                                    .stroke(Color(hex: color), lineWidth: 2)
                                                    .padding(-6)
                                                : nil
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Goal Type - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("GOAL TYPE")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(GoalType.allCases, id: \.self) { type in
                                    Button {
                                        selectedType = type
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 20))
                                            Text(type == .milestone ? "Milestone" : 
                                                 type == .numeric ? "Numeric" :
                                                 type == .habit ? "Habit" : "Project")
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        .foregroundColor(selectedType == type ? .white : .primary)
                                        .frame(width: 90, height: 70)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedType == type ? Color.blue : Color(UIColor.secondarySystemFill))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                        
                    // Type-specific Fields - Structured style
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
                    
                    // Priority - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("PRIORITY")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(GoalPriority.allCases, id: \.self) { prio in
                                    Button {
                                        priority = prio
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "flag.fill")
                                                .font(.system(size: 14))
                                            Text(prio.displayName)
                                                .font(.system(size: 15, weight: .medium))
                                        }
                                        .foregroundColor(priority == prio ? Color(hex: prio.color) : .secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(priority == prio ? Color(hex: prio.color).opacity(0.15) : Color(UIColor.secondarySystemFill))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(priority == prio ? Color(hex: prio.color).opacity(0.3) : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Target Date - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("TARGET DATE")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        HStack {
                            Label {
                                Text("Target Date")
                                    .font(.system(size: 17))
                            } icon: {
                                Image(systemName: "calendar")
                                    .font(.system(size: 17))
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $hasTargetDate)
                                .labelsHidden()
                                .tint(.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemFill))
                        )
                        .padding(.horizontal, 20)
                        
                        if hasTargetDate {
                            DatePicker("", selection: $targetDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .padding(.horizontal, 20)
                        }
                    }
                    
                    // Description - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DESCRIPTION")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        TextField("Add description", text: $description, axis: .vertical)
                            .font(.system(size: 17))
                            .lineLimit(3...8)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemFill))
                            )
                            .padding(.horizontal, 20)
                    }
                    
                    // Bottom padding
                    Color.clear
                        .frame(height: 100)
                }
            }
            .background(Color(UIColor.systemBackground))
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 17))
                }
                
                ToolbarItem(placement: .principal) {
                    Text("New Goal")
                        .font(.system(size: 17, weight: .semibold))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createGoal()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .disabled(title.isEmpty || isCreating)
                }
            }
            .sheet(isPresented: $showingHabitPicker) {
                HabitPickerSheet(selectedHabits: $selectedHabits)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallViewPremium()
            }
            .sheet(isPresented: $showingAreaManager) {
                GoalAreasView()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTitleFocused = true
                }
            }
        }  // NavigationStack
    }  // body
    
    // MARK: - Type-specific Fields
    
    @ViewBuilder
    private var numericGoalFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TARGET")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            HStack {
                Image(systemName: "number")
                    .font(.system(size: 17))
                    .foregroundColor(.purple)
                
                TextField("100", value: $targetValue, format: .number)
                    .font(.system(size: 17))
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                
                TextField("units", text: $unit)
                    .font(.system(size: 17))
                    .frame(width: 100)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemFill))
            )
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var habitGoalFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LINKED HABITS")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            Button {
                showingHabitPicker = true
            } label: {
                HStack {
                    Image(systemName: "link")
                        .font(.system(size: 17))
                        .foregroundColor(.indigo)
                    
                    Text("Link Habits")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if !selectedHabits.isEmpty {
                        Text("\(selectedHabits.count) selected")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemFill))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var milestoneGoalFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MILESTONE INFO")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 17))
                    .foregroundColor(.blue)
                
                Text("This goal will track major milestones")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemFill))
            )
            .padding(.horizontal, 20)
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