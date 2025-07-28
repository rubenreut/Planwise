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
    @State private var showingIconPicker = false
    @State private var isCreating = false
    @FocusState private var isNameFocused: Bool
    @State private var showingAdvancedOptions = false
    @State private var showingPaywall = false
    
    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    // Predefined options
    let iconCategories: [(name: String, icons: [String])] = [
        ("Health & Fitness", ["heart.fill", "figure.walk", "figure.run", "dumbbell.fill", "bicycle", "figure.yoga", "figure.dance", "sportscourt.fill"]),
        ("Wellness", ["brain", "moon.fill", "sun.max.fill", "drop.fill", "leaf.fill", "lungs.fill", "eye", "ear"]),
        ("Productivity", ["flame.fill", "star.fill", "bolt.fill", "book.fill", "pencil", "checkmark.circle.fill", "target", "trophy.fill"]),
        ("Daily Life", ["cup.and.saucer.fill", "bed.double.fill", "pills.fill", "carrot.fill", "hands.clap.fill", "music.note", "tv.fill", "gamecontroller.fill"]),
        ("Mindfulness", ["figure.mind.and.body", "sparkles", "wind", "cloud.fill", "mountain.2.fill", "tree.fill", "flower.fill", "butterfly.fill"])
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
        NavigationView {
            ZStack {
                // Background
                Color.adaptiveBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header with icon and name
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Icon selector with animation
                            Button {
                                showingIconPicker = true
                                impactFeedback.impactOccurred()
                            } label: {
                                ZStack {
                                    LinearGradient(
                                        colors: [
                                            Color(hex: selectedColor).opacity(0.2),
                                            Color(hex: selectedColor).opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    
                                    Circle()
                                        .strokeBorder(Color(hex: selectedColor).opacity(0.3), lineWidth: 1)
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: selectedIcon)
                                        .font(.system(size: DesignSystem.IconSize.xxl))
                                        .foregroundColor(Color(hex: selectedColor))
                                        .symbolRenderingMode(.hierarchical)
                                    
                                    // Edit indicator
                                    ZStack {
                                        Color(UIColor.systemBackground)
                                            .frame(width: DesignSystem.IconSize.xl - 2, height: DesignSystem.IconSize.xl - 2)
                                            .clipShape(Circle())
                                        
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: DesignSystem.IconSize.lg))
                                            .foregroundColor(.secondary)
                                    }
                                    .offset(x: 35, y: 35)
                                }
                            }
                            .scaleEffect(showingIconPicker ? 0.95 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingIconPicker)
                            
                            // Name input with floating label
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                TextField("What habit do you want to build?", text: $name)
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .focused($isNameFocused)
                                    .onSubmit {
                                        if !name.isEmpty {
                                            selectionFeedback.selectionChanged()
                                        }
                                    }
                                
                                LinearGradient(
                                    colors: [
                                        Color(hex: selectedColor).opacity(0.3),
                                        Color(hex: selectedColor).opacity(0.1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(height: 2)
                                    .frame(width: isNameFocused || !name.isEmpty ? 250 : 150)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isNameFocused)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: name)
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.xxl - 8)
                        
                        // Color picker with proper spacing
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Label("Color", systemImage: "paintpalette")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(colors, id: \.self) { color in
                                        Button {
                                            selectedColor = color
                                            selectionFeedback.selectionChanged()
                                        } label: {
                                            ZStack {
                                                Color(hex: color)
                                                    .frame(width: 44, height: 44)
                                                    .clipShape(Circle())
                                                
                                                if selectedColor == color {
                                                    Circle()
                                                        .strokeBorder(Color.primary, lineWidth: 3)
                                                        .frame(width: 52, height: 52)
                                                    
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                        .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColor)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, DesignSystem.Spacing.xs) // Fix cropping
                            }
                        }
                        
                        // Quick setup cards
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Label("Quick Setup", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    QuickSetupCard(
                                        title: "Daily Check",
                                        description: "Simple yes/no tracking",
                                        icon: "checkmark.circle",
                                        color: .green,
                                        isSelected: trackingType == .binary && frequency == .daily,
                                        action: {
                                        trackingType = .binary
                                        frequency = .daily
                                        impactFeedback.impactOccurred()
                                    })
                                    
                                    QuickSetupCard(
                                        title: "Count",
                                        description: "Track quantity or amount",
                                        icon: "number.circle",
                                        color: .blue,
                                        isSelected: trackingType == .quantity,
                                        action: {
                                        trackingType = .quantity
                                        impactFeedback.impactOccurred()
                                    })
                                    
                                    QuickSetupCard(
                                        title: "Time",
                                        description: "Track duration in minutes",
                                        icon: "clock",
                                        color: .orange,
                                        isSelected: trackingType == .duration,
                                        action: {
                                        trackingType = .duration
                                        goalUnit = "minutes"
                                        impactFeedback.impactOccurred()
                                    })
                                    
                                    QuickSetupCard(
                                        title: "Quality",
                                        description: "Rate on a scale of 1-5",
                                        icon: "star.leadinghalf.filled",
                                        color: .purple,
                                        isSelected: trackingType == .quality,
                                        action: {
                                        trackingType = .quality
                                        impactFeedback.impactOccurred()
                                    })
                                }
                                .padding(.horizontal)
                                .padding(.vertical, DesignSystem.Spacing.xs) // Add vertical padding to prevent clipping
                            }
                            .clipped()
                        }
                        
                        // Goal setting (if not binary)
                        if trackingType != .binary {
                            VStack(spacing: DesignSystem.Spacing.md + 4) {
                                HStack {
                                    Label("Daily Goal", systemImage: "target")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    if trackingType == .duration {
                                        HStack(spacing: DesignSystem.Spacing.xs) {
                                            TextField("30", value: $goalTarget, format: .number)
                                                .frame(width: 60)
                                                .textFieldStyle(.roundedBorder)
                                                .multilineTextAlignment(.center)
                                                .keyboardType(.numberPad)
                                            
                                            Text("minutes")
                                                .foregroundColor(.secondary)
                                        }
                                    } else if trackingType == .quantity {
                                        HStack(spacing: DesignSystem.Spacing.xs) {
                                            TextField("8", value: $goalTarget, format: .number)
                                                .frame(width: 60)
                                                .textFieldStyle(.roundedBorder)
                                                .multilineTextAlignment(.center)
                                                .keyboardType(.decimalPad)
                                            
                                            TextField("glasses", text: $goalUnit)
                                                .frame(width: 100)
                                                .textFieldStyle(.roundedBorder)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(
                                    Color(UIColor.secondarySystemBackground)
                                        .cornerRadius(DesignSystem.CornerRadius.sm)
                                )
                                .padding(.horizontal)
                            }
                        }
                        
                        // Frequency selector
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Label("Frequency", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                ForEach(HabitFrequency.allCases, id: \.self) { freq in
                                    FrequencyCard(
                                        frequency: freq,
                                        isSelected: frequency == freq
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            frequency = freq
                                        }
                                        selectionFeedback.selectionChanged()
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Custom frequency days
                            if frequency == .custom {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                    Text("Select days")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: DesignSystem.Spacing.xs) {
                                        ForEach(weekDays, id: \.0) { day, letter in
                                            DaySelector(
                                                letter: letter,
                                                isSelected: customDays.contains(day),
                                                color: Color(hex: selectedColor)
                                            ) {
                                                if customDays.contains(day) {
                                                    customDays.remove(day)
                                                } else {
                                                    customDays.insert(day)
                                                }
                                                impactFeedback.impactOccurred()
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        
                        // Advanced options (collapsed by default)
                        DisclosureGroup(isExpanded: $showingAdvancedOptions) {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                // Category
                                if !scheduleManager.categories.isEmpty {
                                    HStack {
                                        Label("Category", systemImage: "folder")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
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
                                            HStack(spacing: DesignSystem.Spacing.xxs + 2) {
                                                if let category = selectedCategory {
                                                    Image(systemName: category.iconName ?? "folder")
                                                        .font(.caption)
                                                    Text(category.name ?? "")
                                                        .font(.callout)
                                                } else {
                                                    Text("None")
                                                        .font(.callout)
                                                }
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(selectedCategory != nil ? Color(hex: selectedCategory?.colorHex ?? "#007AFF") : .secondary)
                                        }
                                    }
                                }
                                
                                // Notes
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Label("Notes", systemImage: "note.text")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    TextEditor(text: $notes)
                                        .frame(minHeight: 80)
                                        .padding(DesignSystem.Spacing.xs)
                                        .scrollContentBackground(.hidden)
                                        .background(
                                            Color(UIColor.tertiarySystemFill)
                                                .cornerRadius(DesignSystem.CornerRadius.sm)
                                        )
                                }
                            }
                            .padding(.top, DesignSystem.Spacing.sm)
                        } label: {
                            HStack {
                                Label("Advanced Options", systemImage: "slider.horizontal.3")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            Color(UIColor.secondarySystemBackground)
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                        )
                        .padding(.horizontal)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .standardNavigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        selectionFeedback.selectionChanged()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        createHabit()
                    } label: {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(
                    selectedIcon: $selectedIcon,
                    selectedColor: selectedColor,
                    iconCategories: iconCategories
                )
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallViewPremium()
            }
            .interactiveDismissDisabled(isCreating)
            .onAppear {
                selectionFeedback.prepare()
                impactFeedback.prepare()
                
                // Focus name field after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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

// MARK: - Supporting Views

struct QuickSetupCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 140, height: 100, alignment: .topLeading)
            .padding()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(isSelected ? color : Color(UIColor.secondarySystemBackground))
                }
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .strokeBorder(isSelected ? Color.clear : color.opacity(DesignSystem.Opacity.strong), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FrequencyCard: View {
    let frequency: HabitFrequency
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(frequency.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(isSelected ? Color.blue : Color(UIColor.tertiarySystemFill))
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DaySelector: View {
    let letter: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 40, height: 40)
                .background(
                    ZStack {
                        Circle()
                            .fill(isSelected ? color : Color(UIColor.tertiarySystemFill))
                    }
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Icon Picker

struct IconPickerView: View {
    @Binding var selectedIcon: String
    let selectedColor: String
    let iconCategories: [(name: String, icons: [String])]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    
    var filteredCategories: [(name: String, icons: [String])] {
        if searchText.isEmpty {
            return iconCategories
        } else {
            return iconCategories.compactMap { category in
                let filteredIcons = category.icons.filter { icon in
                    icon.localizedCaseInsensitiveContains(searchText)
                }
                return filteredIcons.isEmpty ? nil : (category.name, filteredIcons)
            }
        }
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 70), spacing: DesignSystem.Spacing.md)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    ForEach(filteredCategories, id: \.name) { category in
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(category.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.md) {
                                ForEach(category.icons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        dismiss()
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                                .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(DesignSystem.Opacity.medium - 0.05) : Color(UIColor.tertiarySystemFill))
                                                .frame(width: 70, height: 70)
                                            
                                            if selectedIcon == icon {
                                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                                    .strokeBorder(Color(hex: selectedColor), lineWidth: 2)
                                                    .frame(width: 70, height: 70)
                                            }
                                            
                                            Image(systemName: icon)
                                                .font(.system(size: DesignSystem.IconSize.xl - 4))
                                                .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : .primary)
                                                .symbolRenderingMode(.hierarchical)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .scaleEffect(selectedIcon == icon ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIcon)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search icons")
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
    AddHabitView()
        .environmentObject(HabitManager.shared)
        .environmentObject(ScheduleManager.shared)
}