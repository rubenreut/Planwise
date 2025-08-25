//
//  EditHabitView.swift
//  Momentum
//
//  Edit existing habit interface
//

import SwiftUI
import UIKit

struct EditHabitView: View {
    let habit: Habit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var habitManager: HabitManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    
    // Form fields
    @State private var name = ""
    @State private var selectedCategory: Category?
    @State private var frequency: HabitFrequency = .daily
    @State private var trackingType: HabitTrackingType = .binary
    @State private var goalTarget: Double = 1.0
    @State private var goalUnit = ""
    @State private var notes = ""
    @State private var weeklyTarget: Int = 7
    @State private var customDays: Set<Int> = []
    
    // UI State
    @State private var isSaving = false
    @FocusState private var isNameFocused: Bool
    @State private var showingAdvancedOptions = false
    
    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    // Predefined options
    let icons = [
        "flame.fill", "star.fill", "bolt.fill", "heart.fill",
        "figure.walk", "figure.run", "book.fill", "brain",
        "moon.fill", "sun.max.fill", "drop.fill", "leaf.fill"
    ]
    
    let colors = [
        "#007AFF", "#34C759", "#FF3B30", "#FF9500",
        "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE",
        "#32ADE6", "#FFD60A", "#8E8E93", "#F2B8D4",
        "#88D3CE", "#6FA3EF", "#F7B267", "#C08497"
    ]
    
    let weekDays = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"),
        (5, "T"), (6, "F"), (7, "S")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Title - Structured style
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Habit", text: $name)
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .focused($isNameFocused)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 8)
                        
                        Divider()
                            .padding(.horizontal, 20)
                    }
                    
                    // Tracking Type - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("TRACKING TYPE")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(HabitTrackingType.allCases, id: \.self) { type in
                                    Button {
                                        trackingType = type
                                        selectionFeedback.selectionChanged()
                                    } label: {
                                        Text(type.displayName)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(trackingType == type ? .white : .primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(trackingType == type ? Color.blue : Color(UIColor.secondarySystemFill))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Goal setting (if not binary) - Structured style
                    if trackingType != .binary {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("DAILY GOAL")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            HStack {
                                Image(systemName: "target")
                        .scaledIcon()
                    .scaledFont(size: 17)
                                    .foregroundColor(.orange)
                                
                                if trackingType == .duration {
                                    TextField("30", value: $goalTarget, format: .number)
                                        .font(.system(size: 17))
                                        .keyboardType(.numberPad)
                                        .frame(width: 60)
                                    
                                    Text("minutes")
                                        .font(.system(size: 17))
                                        .foregroundColor(.secondary)
                                } else if trackingType == .quantity {
                                    TextField("8", value: $goalTarget, format: .number)
                                        .font(.system(size: 17))
                                        .keyboardType(.decimalPad)
                                        .frame(width: 60)
                                    
                                    TextField("units", text: $goalUnit)
                                        .font(.system(size: 17))
                                        .frame(width: 100)
                                } else if trackingType == .quality {
                                    Text("Rate 1-5")
                                        .font(.system(size: 17))
                                        .foregroundColor(.secondary)
                                }
                                
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
                    
                    // Frequency - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("FREQUENCY")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 1) {
                            ForEach(HabitFrequency.allCases, id: \.self) { freq in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        frequency = freq
                                    }
                                    selectionFeedback.selectionChanged()
                                } label: {
                                    HStack {
                                        Text(freq.displayName)
                                            .font(.system(size: 17))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if frequency == freq {
                                            Image(systemName: "checkmark")
                        .scaledIcon()
                    .scaledFont(size: 15, weight: .semibold)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                    .background(
                                        Color(UIColor.secondarySystemFill)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        
                        // Custom frequency days
                        if frequency == .custom {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SELECT DAYS")
                                    .scaledFont(size: 13, weight: .semibold, design: .default)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                                
                                HStack(spacing: 8) {
                                    ForEach(weekDays, id: \.0) { day, letter in
                                        Button {
                                            if customDays.contains(day) {
                                                customDays.remove(day)
                                            } else {
                                                customDays.insert(day)
                                            }
                                            selectionFeedback.selectionChanged()
                                        } label: {
                                            Text(letter)
                                                .scaledFont(size: 16, weight: .semibold)
                                                .frame(width: 42, height: 42)
                                                .background(
                                                    Circle()
                                                        .fill(customDays.contains(day) ? Color.blue : Color(UIColor.secondarySystemFill))
                                                )
                                                .foregroundColor(customDays.contains(day) ? .white : .primary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                if !customDays.isEmpty {
                                    Text("\(customDays.count) day\(customDays.count == 1 ? "" : "s") per week")
                                        .scaledFont(size: 14, weight: .regular)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                            )
                            .padding(.horizontal, 20)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                    }
                    
                    // Notes & Attachments - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("NOTES & ATTACHMENTS")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $notes)
                                .font(.system(size: 17))
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(UIColor.secondarySystemFill))
                                )
                            
                            HStack(spacing: 4) {
                                Image(systemName: "paperclip")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("You can paste links or describe attached documents here")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .onAppear {
                loadHabitData()
                selectionFeedback.prepare()
            }
        }
    }
    
    private func loadHabitData() {
        name = habit.name ?? ""
        selectedCategory = habit.category
        frequency = habit.frequencyEnum
        trackingType = habit.trackingTypeEnum
        goalTarget = habit.goalTarget
        goalUnit = habit.goalUnit ?? ""
        notes = habit.notes ?? ""
        weeklyTarget = Int(habit.weeklyTarget)
        // Load custom days if frequency is custom
        if let frequencyDays = habit.frequencyDays {
            customDays = Set(frequencyDays.split(separator: ",").compactMap { Int($0) })
        }
    }
    
    private func saveChanges() {
        isSaving = true
        
        // Update habit properties
        habit.name = name
        // Keep existing icon and color - don't change them
        habit.category = selectedCategory
        habit.frequency = frequency.rawValue
        habit.trackingType = trackingType.rawValue
        habit.goalTarget = goalTarget
        habit.goalUnit = goalUnit.isEmpty ? nil : goalUnit
        habit.notes = notes.isEmpty ? nil : notes
        habit.weeklyTarget = Int16(weeklyTarget)
        // Save custom days if frequency is custom
        if frequency == .custom && !customDays.isEmpty {
            habit.frequencyDays = customDays.sorted().map(String.init).joined(separator: ",")
        } else {
            habit.frequencyDays = nil
        }
        
        // Save using habit manager
        _ = habitManager.updateHabit(habit)
        
        impactFeedback.impactOccurred()
        dismiss()
    }
}

#Preview {
    let habit = Habit(context: PersistenceController.preview.container.viewContext)
    habit.name = "Morning Meditation"
    habit.iconName = "flame.fill"
    habit.colorHex = "#007AFF"
    habit.frequency = HabitFrequency.daily.rawValue
    habit.trackingType = HabitTrackingType.duration.rawValue
    habit.goalTarget = 10
    
    return EditHabitView(habit: habit)
        .environmentObject(HabitManager.shared)
        .environmentObject(ScheduleManager.shared)
}