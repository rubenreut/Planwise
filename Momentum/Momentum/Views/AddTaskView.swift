//
//  AddTaskView.swift
//  Momentum
//
//  Minimalist task creation interface
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var taskManager: TaskManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    // Form fields
    @State private var title = ""
    @State private var notes = ""
    @State private var priority: TaskPriority = .medium
    @State private var selectedCategory: Category?
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var hasTime = false
    @State private var tags = ""
    @State private var estimatedDuration: Int = 30
    
    // UI State
    @State private var isCreating = false
    @FocusState private var isTitleFocused: Bool
    @State private var showingCategoryPicker = false
    @State private var showingPaywall = false
    
    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Title - Structured style
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Task", text: $title)
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .focused($isTitleFocused)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 8)
                        
                        Divider()
                            .padding(.horizontal, 20)
                    }
                    
                    // Priority - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("PRIORITY")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(TaskPriority.allCases, id: \.self) { prio in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            priority = prio
                                            selectionFeedback.selectionChanged()
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "flag.fill")
                                                .font(.system(size: 14))
                                            Text(prio.displayName)
                                                .font(.system(size: 15, weight: .medium))
                                        }
                                        .foregroundColor(priority == prio ? prio.color : .secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(priority == prio ? prio.color.opacity(0.15) : Color(UIColor.secondarySystemFill))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(priority == prio ? prio.color.opacity(0.3) : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Due Date - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DUE DATE")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            // Date toggle row
                            HStack {
                                Label {
                                    Text(hasDueDate ? formatDate(dueDate) : "No due date")
                                        .font(.system(size: 17))
                                        .foregroundColor(hasDueDate ? .primary : .secondary)
                                } icon: {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 17))
                                        .foregroundColor(hasDueDate ? .blue : .secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $hasDueDate.animation(.easeInOut(duration: 0.2)))
                                    .labelsHidden()
                                    .tint(.blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.secondarySystemFill))
                            
                            if hasDueDate {
                                Divider()
                                    .background(Color(UIColor.separator).opacity(0.3))
                                
                                // Time toggle row
                                HStack {
                                    Label {
                                        Text(hasTime ? formatTime(dueDate) : "No time set")
                                            .font(.system(size: 17))
                                            .foregroundColor(hasTime ? .primary : .secondary)
                                    } icon: {
                                        Image(systemName: "clock")
                                            .font(.system(size: 17))
                                            .foregroundColor(hasTime ? .orange : .secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $hasTime.animation(.easeInOut(duration: 0.2)))
                                        .labelsHidden()
                                        .tint(.orange)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemFill))
                                
                                if hasDueDate {
                                    DatePicker(
                                        "",
                                        selection: $dueDate,
                                        displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date]
                                    )
                                    .datePickerStyle(.graphical)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(UIColor.secondarySystemFill))
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                    }
                    
                    // Category - Structured style
                    if !scheduleManager.categories.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CATEGORY")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            Button {
                                showingCategoryPicker = true
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
                    
                    // Duration - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DURATION")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                                    Button {
                                        estimatedDuration = minutes
                                        selectionFeedback.selectionChanged()
                                    } label: {
                                        Text(formatDuration(minutes))
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(estimatedDuration == minutes ? .white : .primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(estimatedDuration == minutes ? Color.purple : Color(UIColor.secondarySystemFill))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Custom duration
                                Button {
                                    // Show custom picker
                                } label: {
                                    Text("Custom")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(UIColor.secondarySystemFill))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
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
                    
                    // Tags - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("TAGS")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        TextField("Add tags", text: $tags)
                            .font(.system(size: 17))
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
                    Text("New Task")
                        .font(.system(size: 17, weight: .semibold))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createTask()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(selectedCategory: $selectedCategory)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallViewPremium()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTitleFocused = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(mins)m"
            }
        }
    }
    
    private func createTask() {
        isCreating = true
        
        let tagArray = tags.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        impactFeedback.impactOccurred()
        
        let result = taskManager.createTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes,
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority,
            category: selectedCategory,
            tags: tagArray.isEmpty ? nil : tagArray,
            estimatedDuration: Int16(estimatedDuration),
            scheduledTime: hasDueDate && hasTime ? dueDate : nil,
            linkedEvent: nil
        )
        
        switch result {
        case .success:
            notificationFeedback.notificationOccurred(.success)
            dismiss()
        case .failure(let error):
            notificationFeedback.notificationOccurred(.error)
            isCreating = false
            
            if case ScheduleError.subscriptionLimitReached = error {
                showingPaywall = true
            }
        }
    }
}

// MARK: - Option Row Component

struct OptionRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let accessory: () -> Content
    
    init(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        @ViewBuilder accessory: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.accessory = accessory
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
            
            accessory()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Category Picker

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scheduleManager: ScheduleManager
    
    var body: some View {
        NavigationView {
            List {
                Button {
                    selectedCategory = nil
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        Text("None")
                        Spacer()
                        if selectedCategory == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                ForEach(scheduleManager.categories) { category in
                    Button {
                        selectedCategory = category
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: category.iconName ?? "folder")
                                .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                                .frame(width: 24)
                            Text(category.name ?? "")
                            Spacer()
                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Category")
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

// MARK: - Horizontal Pill Selector

struct HorizontalPillSelector<T: Hashable>: View {
    let items: [T]
    @Binding var selection: T
    let label: (T) -> String
    let color: (T) -> Color
    
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    selection = item
                    selectionFeedback.selectionChanged()
                } label: {
                    Text(label(item))
                        .font(.subheadline)
                        .fontWeight(selection == item ? .semibold : .medium)
                        .foregroundColor(selection == item ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selection == item ? color(item) : Color(UIColor.secondarySystemFill))
                        )
                        .overlay(
                            Capsule()
                                .stroke(selection == item ? Color.clear : Color(UIColor.separator).opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Duration Pill Selector

struct DurationPillSelector: View {
    @Binding var selection: Int
    @State private var showingCustomPicker = false
    @State private var customMinutes: Int = 60
    
    private let presetDurations = [15, 30, 45, 60]
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    var body: some View {
        HStack(spacing: 8) {
            // Preset options
            ForEach(presetDurations, id: \.self) { minutes in
                Button {
                    selection = minutes
                    selectionFeedback.selectionChanged()
                } label: {
                    Text("\(minutes)m")
                        .font(.subheadline)
                        .fontWeight(selection == minutes && !isCustomDuration ? .semibold : .medium)
                        .foregroundColor(selection == minutes && !isCustomDuration ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selection == minutes && !isCustomDuration ? Color.purple : Color(UIColor.secondarySystemFill))
                        )
                        .overlay(
                            Capsule()
                                .stroke(selection == minutes && !isCustomDuration ? Color.clear : Color(UIColor.separator).opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            
            // Custom option
            Button {
                showingCustomPicker = true
                selectionFeedback.selectionChanged()
            } label: {
                Text(isCustomDuration ? "\(selection)m" : "Custom")
                    .font(.subheadline)
                    .fontWeight(isCustomDuration ? .semibold : .medium)
                    .foregroundColor(isCustomDuration ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isCustomDuration ? Color.purple : Color(UIColor.secondarySystemFill))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isCustomDuration ? Color.clear : Color(UIColor.separator).opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingCustomPicker) {
                CustomDurationPicker(selection: $selection, isPresented: $showingCustomPicker)
            }
            
            Spacer()
        }
    }
    
    private var isCustomDuration: Bool {
        !presetDurations.contains(selection)
    }
}

// MARK: - Custom Duration Picker

struct CustomDurationPicker: View {
    @Binding var selection: Int
    @Binding var isPresented: Bool
    @State private var tempSelection: Int = 60
    
    private let commonDurations = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180, 240]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    
                    Spacer()
                    
                    Text("Duration")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Done") {
                        selection = tempSelection
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
                .padding()
                
                Divider()
                
                // Duration picker
                Picker("Duration", selection: $tempSelection) {
                    ForEach(commonDurations, id: \.self) { minutes in
                        Text(formatDurationText(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .padding()
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .onAppear {
            tempSelection = selection
        }
    }
    
    private func formatDurationText(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        } else if minutes == 60 {
            return "1 hour"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60) hours"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
}

#Preview {
    AddTaskView()
        .environmentObject(TaskManager.shared)
        .environmentObject(ScheduleManager.shared)
}