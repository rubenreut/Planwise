//
//  AddTaskView.swift
//  Momentum
//
//  Premium task creation interface with Apple design standards
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
    @State private var selectedQuickDate: QuickDateOption? = nil
    @State private var showingPaywall = false
    
    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    enum QuickDateOption: String, CaseIterable {
        case today = "Today"
        case tomorrow = "Tomorrow"
        case nextWeek = "Next Week"
        
        var date: Date {
            let calendar = Calendar.current
            switch self {
            case .today:
                return Date()
            case .tomorrow:
                return calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            case .nextWeek:
                return calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
            }
        }
        
        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .tomorrow: return "sun.haze.fill"
            case .nextWeek: return "calendar.badge.plus"
            }
        }
        
        var color: Color {
            switch self {
            case .today: return .orange
            case .tomorrow: return .blue
            case .nextWeek: return .purple
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Subtle gradient background
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground),
                        Color(UIColor.systemBackground).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Title Section with modern design
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("What needs to be done?")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            TextField("Task title", text: $title, axis: .vertical)
                                .font(DeviceType.isIPad ? .title : .title2)
                                .fontWeight(.medium)
                                .focused($isTitleFocused)
                                .submitLabel(.done)
                                .lineLimit(1...3)
                                .padding(.vertical, DesignSystem.Spacing.xxs)
                        }
                        .adaptiveHorizontalPadding()
                        .padding(.top)
                        .adaptiveMaxWidth()
                        .frame(maxWidth: .infinity)
                        
                        // Priority Selection with visual cards
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Priority", systemImage: "flag.fill")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(TaskPriority.allCases, id: \.self) { level in
                                        PriorityCard(
                                            priority: level,
                                            isSelected: priority == level
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                priority = level
                                            }
                                            selectionFeedback.selectionChanged()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .adaptiveMaxWidth()
                        .frame(maxWidth: .infinity)
                        
                        // Quick Date Options
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Due Date", systemImage: "calendar")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    // No date option
                                    QuickDateCard(
                                        title: "No Date",
                                        icon: "infinity",
                                        color: .gray,
                                        isSelected: !hasDueDate
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            hasDueDate = false
                                            selectedQuickDate = nil
                                        }
                                        impactFeedback.impactOccurred()
                                    }
                                    
                                    // Quick date options
                                    ForEach(QuickDateOption.allCases, id: \.self) { option in
                                        QuickDateCard(
                                            title: option.rawValue,
                                            icon: option.icon,
                                            color: option.color,
                                            isSelected: hasDueDate && selectedQuickDate == option
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                hasDueDate = true
                                                selectedQuickDate = option
                                                dueDate = option.date
                                                hasTime = false
                                            }
                                            impactFeedback.impactOccurred()
                                        }
                                    }
                                    
                                    // Custom date option
                                    QuickDateCard(
                                        title: "Custom",
                                        icon: "calendar.badge.plus",
                                        color: .indigo,
                                        isSelected: hasDueDate && selectedQuickDate == nil
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            hasDueDate = true
                                            selectedQuickDate = nil
                                        }
                                        impactFeedback.impactOccurred()
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Custom date picker (if selected)
                            if hasDueDate && selectedQuickDate == nil {
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    DatePicker(
                                        "Date",
                                        selection: $dueDate,
                                        displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date]
                                    )
                                    .datePickerStyle(.compact)
                                    .padding(.horizontal)
                                    
                                    Toggle("Include time", isOn: $hasTime.animation())
                                        .padding(.horizontal)
                                        .onChange(of: hasTime) { _, _ in
                                            selectionFeedback.selectionChanged()
                                        }
                                }
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                                .padding(.horizontal)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                            }
                        }
                        
                        // Category & Duration Row
                        HStack(spacing: DesignSystem.Spacing.md) {
                            // Category
                            if !scheduleManager.categories.isEmpty {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Label("Category", systemImage: "folder")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                        .tracking(0.5)
                                    
                                    Button {
                                        showingCategoryPicker = true
                                        impactFeedback.impactOccurred()
                                    } label: {
                                        HStack {
                                            if let category = selectedCategory {
                                                Image(systemName: category.iconName ?? "folder")
                                                Text(category.name ?? "")
                                            } else {
                                                Image(systemName: "folder")
                                                Text("None")
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(selectedCategory != nil ? Color(hex: selectedCategory?.colorHex ?? "#007AFF") : .primary)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(DesignSystem.CornerRadius.sm)
                                    }
                                    .buttonStyle(.ghost)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Duration
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Label("Duration", systemImage: "clock")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                
                                Menu {
                                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                                        Button {
                                            estimatedDuration = minutes
                                            selectionFeedback.selectionChanged()
                                        } label: {
                                            if minutes < 60 {
                                                Text("\(minutes) minutes")
                                            } else {
                                                Text("\(minutes / 60) hour\(minutes > 60 ? "s" : "")")
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.fill")
                                        if estimatedDuration < 60 {
                                            Text("\(estimatedDuration) min")
                                        } else {
                                            Text("\(estimatedDuration / 60)h")
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.primary)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                        
                        // Notes Section with enhanced design
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Notes", systemImage: "note.text")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            ZStack(alignment: .topLeading) {
                                if notes.isEmpty {
                                    Text("Add notes or details...")
                                        .foregroundColor(Color(UIColor.placeholderText))
                                        .padding(.top, DesignSystem.Spacing.sm)
                                        .padding(.horizontal, DesignSystem.Spacing.xs)
                                }
                                
                                TextEditor(text: $notes)
                                    .frame(minHeight: 100)
                                    .scrollContentBackground(.hidden)
                                    .padding(DesignSystem.Spacing.xs)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Tags Section
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Tags", systemImage: "tag")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            TextField("Add tags (comma separated)", text: $tags)
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.done)
                            
                            // Suggested tags
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    ForEach(["work", "personal", "urgent", "important"], id: \.self) { tag in
                                        TagChip(tag: tag, isSelected: tags.contains(tag)) {
                                            toggleTag(tag)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Spacer for floating button
                        Spacer(minLength: 100)
                    }
                }
            }
            .standardNavigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        selectionFeedback.selectionChanged()
                        dismiss()
                    }
                    .buttonStyle(.tertiary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    LoadingButton(action: createTask, isLoading: isCreating, style: .primary, size: .small) {
                        Text("Add")
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(!title.isEmpty || !notes.isEmpty || !tags.isEmpty)
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(selectedCategory: $selectedCategory)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallViewPremium()
            }
            .overlay(alignment: .bottom) {
                // Floating create button
                if !title.isEmpty {
                    MomentumButton("Create Task", icon: "plus.circle.fill", style: .primary, isLoading: isCreating) {
                        createTask()
                    }
                    .padding()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
        }
        .onAppear {
            selectionFeedback.prepare()
            impactFeedback.prepare()
            isTitleFocused = true
        }
    }
    
    // MARK: - Methods
    
    private func toggleTag(_ tag: String) {
        let currentTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if currentTags.contains(tag) {
            tags = currentTags.filter { $0 != tag }.joined(separator: ", ")
        } else {
            if tags.isEmpty {
                tags = tag
            } else {
                tags += ", \(tag)"
            }
        }
        selectionFeedback.selectionChanged()
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
            // Success feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            dismiss()
        case .failure(let error):
            isCreating = false
            if case ScheduleError.subscriptionLimitReached = error {
                showingPaywall = true
            }
        }
    }
}

// MARK: - Supporting Views

struct PriorityCard: View {
    let priority: TaskPriority
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "flag.fill")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : priority.color)
                
                Text(priority.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(isSelected ? priority.color : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .strokeBorder(isSelected ? Color.clear : priority.color.opacity(DesignSystem.Opacity.strong), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.ghost)
    }
}

struct QuickDateCard: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 90, height: 70)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(isSelected ? color : Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .strokeBorder(isSelected ? Color.clear : color.opacity(DesignSystem.Opacity.strong), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.ghost)
    }
}

struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("#\(tag)")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs + 2)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color.blue.opacity(DesignSystem.Opacity.light))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.blue.opacity(DesignSystem.Opacity.strong), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.ghost)
    }
}

// MARK: - Category Picker View

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scheduleManager: ScheduleManager
    
    var body: some View {
        NavigationView {
            List {
                // None option
                Button {
                    selectedCategory = nil
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.secondary)
                            .frame(width: DesignSystem.IconSize.lg)
                        Text("None")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedCategory == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                
                // Categories
                ForEach(scheduleManager.categories) { category in
                    Button {
                        selectedCategory = category
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: category.iconName ?? "folder")
                                .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                                .frame(width: DesignSystem.IconSize.lg)
                            Text(category.name ?? "")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.primary(size: .small))
                }
            }
        }
    }
}

#Preview {
    AddTaskView()
        .environmentObject(TaskManager.shared)
        .environmentObject(ScheduleManager.shared)
}