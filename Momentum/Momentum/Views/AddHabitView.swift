//
//  AddHabitView.swift
//  Momentum
//
//  Premium habit creation interface with Apple design standards
//

import SwiftUI
import UIKit

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var habitManager: HabitManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    
    // Form fields
    @State private var name = ""
    @State private var selectedIcon = "flame.fill"
    @State private var selectedColor = "#007AFF"
    @State private var selectedCategory: Category?
    @State private var frequency: HabitFrequency = .daily
    @State private var trackingType: HabitTrackingType = .binary
    @State private var goalTarget: Double = 1.0
    @State private var goalUnit = ""
    @State private var notes = ""
    @State private var weeklyTarget: Int = 7
    @State private var customDays: Set<Int> = []
    
    // UI State
    @State private var isCreating = false
    @FocusState private var isNameFocused: Bool
    @State private var showingAdvancedOptions = false
    @State private var showingPaywall = false
    
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
                                        selectionFeedback.selectionChanged()
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
                                        selectionFeedback.selectionChanged()
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
                                    .font(.system(size: 17))
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
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(HabitFrequency.allCases, id: \.self) { freq in
                                    Button {
                                        frequency = freq
                                        selectionFeedback.selectionChanged()
                                    } label: {
                                        Text(freq.displayName)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(frequency == freq ? .white : .primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(frequency == freq ? Color.green : Color(UIColor.secondarySystemFill))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Custom frequency days
                        if frequency == .custom {
                            HStack(spacing: 8) {
                                ForEach(weekDays, id: \.0) { day, letter in
                                    Button {
                                        if customDays.contains(day) {
                                            customDays.remove(day)
                                        } else {
                                            customDays.insert(day)
                                        }
                                    } label: {
                                        Text(letter)
                                            .font(.system(size: 14, weight: .semibold))
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(customDays.contains(day) ? Color(hex: selectedColor) : Color(UIColor.secondarySystemFill))
                                            )
                                            .foregroundColor(customDays.contains(day) ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Category - Structured style
                    if !scheduleManager.categories.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CATEGORY")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
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
                                            .font(.system(size: 17))
                                            .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                                        Text(category.name ?? "")
                                            .font(.system(size: 17))
                                            .foregroundColor(.primary)
                                    } else {
                                        Image(systemName: "folder")
                                            .font(.system(size: 17))
                                            .foregroundColor(.secondary)
                                        Text("No category")
                                            .font(.system(size: 17))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
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
                    
                    // Notes - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("NOTES")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        TextField("Add notes", text: $notes, axis: .vertical)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 17))
                }
                
                ToolbarItem(placement: .principal) {
                    Text("New Habit")
                        .font(.system(size: 17, weight: .semibold))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createHabit()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .disabled(name.isEmpty || isCreating)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallViewPremium()
            }
            .interactiveDismissDisabled(isCreating)
            .onAppear {
                selectionFeedback.prepare()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isNameFocused = true
                }
            }
        }
    }
    
    private func createHabit() {
        isCreating = true
        
        // Set default unit if needed
        if trackingType != .binary && goalUnit.isEmpty {
            goalUnit = trackingType.defaultUnit ?? ""
        }
        
        // Create frequency days string for custom frequency
        var frequencyDays: String? = nil
        if frequency == .custom && !customDays.isEmpty {
            frequencyDays = customDays.sorted().map(String.init).joined(separator: ",")
        }
        
        let result = habitManager.createHabit(
            name: name,
            icon: selectedIcon,
            color: selectedColor,
            frequency: frequency,
            trackingType: trackingType,
            goalTarget: trackingType == .binary ? 1 : goalTarget,
            goalUnit: goalUnit.isEmpty ? nil : goalUnit,
            category: selectedCategory,
            notes: notes.isEmpty ? nil : notes
        )
        
        switch result {
        case .success(let habit):
            // Set additional properties
            habit.weeklyTarget = Int16(weeklyTarget)
            habit.frequencyDays = frequencyDays
            
            // Save changes
            _ = habitManager.updateHabit(habit)
            
            // Success feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
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



#Preview {
    AddHabitView()
        .environmentObject(HabitManager.shared)
        .environmentObject(ScheduleManager.shared)
}