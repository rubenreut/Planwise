import SwiftUI

struct TaskDetailView: View {
    let task: Task
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var taskManager: TaskManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var priority: TaskPriority = .medium
    @State private var selectedCategory: Category?
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool = false
    @State private var scheduledTime: Date?
    @State private var hasScheduledTime: Bool = false
    @State private var tags: String = ""
    @State private var estimatedDuration: Int = 30
    @State private var linkedEvent: Event?
    
    @State private var showingDatePicker = false
    @State private var showingTimePicker = false
    @State private var showingEventPicker = false
    @State private var showingDeleteAlert = false
    @State private var showingSubtasks = false
    
    private var hasUnsavedChanges: Bool {
        title != (task.title ?? "") ||
        notes != (task.notes ?? "") ||
        priority != task.priorityEnum ||
        selectedCategory?.id != task.category?.id ||
        dueDate != task.dueDate ||
        scheduledTime != task.scheduledTime ||
        tags != task.tagsArray.joined(separator: ", ") ||
        estimatedDuration != Int(task.estimatedDuration)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Rectangle()
                    .fill(Color.adaptiveBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Title and Notes Card
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            TextField("Task Title", text: $title)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .textFieldStyle(PlainTextFieldStyle())
                            
                            Divider()
                            
                            ZStack(alignment: .topLeading) {
                                if notes.isEmpty {
                                    Text("Add notes...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                }
                                TextEditor(text: $notes)
                                    .frame(minHeight: 100)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? DesignSystem.Opacity.strong : DesignSystem.Shadow.sm.opacity), radius: DesignSystem.Shadow.md.radius, x: 0, y: 2)
                        )
                        .padding(.horizontal)
                        
                        // Properties Card
                        VStack(spacing: 0) {
                            // Priority
                            HStack {
                                Label("Priority", systemImage: "flag")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Picker("", selection: $priority) {
                                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                                        HStack {
                                            Image(systemName: "flag.fill")
                                                .foregroundColor(priority.color)
                                            Text(priority.displayName)
                                        }
                                        .tag(priority)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .accentColor(priority.color)
                            }
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            
                            Divider()
                                .padding(.horizontal, DesignSystem.Spacing.md)
                            
                            // Category
                            HStack {
                                Label("Category", systemImage: "folder")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Menu {
                                    Button("None") {
                                        selectedCategory = nil
                                    }
                                    
                                    ForEach(scheduleManager.categories, id: \.self) { category in
                                        Button {
                                            selectedCategory = category
                                        } label: {
                                            Label {
                                                Text(category.name ?? "")
                                            } icon: {
                                                Image(systemName: category.iconName ?? "folder.fill")
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if let category = selectedCategory {
                                            Image(systemName: category.iconName ?? "folder.fill")
                                                .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                                            Text(category.name ?? "")
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("None")
                                                .foregroundColor(.secondary)
                                        }
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            
                            Divider()
                                .padding(.horizontal, DesignSystem.Spacing.md)
                            
                            // Estimated Duration
                            HStack {
                                Label("Duration", systemImage: "clock")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Picker("", selection: $estimatedDuration) {
                                    Text("15 min").tag(15)
                                    Text("30 min").tag(30)
                                    Text("45 min").tag(45)
                                    Text("1 hour").tag(60)
                                    Text("1.5 hours").tag(90)
                                    Text("2 hours").tag(120)
                                    Text("3 hours").tag(180)
                                    Text("4 hours").tag(240)
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? DesignSystem.Opacity.strong : DesignSystem.Shadow.sm.opacity), radius: DesignSystem.Shadow.md.radius, x: 0, y: 2)
                        )
                        .padding(.horizontal)
                        
                        // Scheduling Card
                        VStack(spacing: 0) {
                            // Due Date
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Toggle(isOn: $hasDueDate) {
                                    Label("Due Date", systemImage: "calendar")
                                        .foregroundColor(.primary)
                                }
                                .onChange(of: hasDueDate) { _, enabled in
                                    if enabled && dueDate == nil {
                                        dueDate = Date().addingTimeInterval(86400) // Tomorrow
                                    }
                                }
                                
                                if hasDueDate {
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { dueDate ?? Date() },
                                            set: { dueDate = $0 }
                                        ),
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .datePickerStyle(CompactDatePickerStyle())
                                }
                            }
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            
                            if hasDueDate || hasScheduledTime {
                                Divider()
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                            }
                            
                            // Scheduled Time
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Toggle(isOn: $hasScheduledTime) {
                                    Label("Schedule Time", systemImage: "clock.badge.checkmark")
                                        .foregroundColor(.primary)
                                }
                                .onChange(of: hasScheduledTime) { _, enabled in
                                    if enabled && scheduledTime == nil {
                                        scheduledTime = Date().addingTimeInterval(3600) // 1 hour from now
                                    }
                                }
                                
                                if hasScheduledTime {
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { scheduledTime ?? Date() },
                                            set: { scheduledTime = $0 }
                                        ),
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .datePickerStyle(CompactDatePickerStyle())
                                }
                            }
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? DesignSystem.Opacity.strong : DesignSystem.Shadow.sm.opacity), radius: DesignSystem.Shadow.md.radius, x: 0, y: 2)
                        )
                        .padding(.horizontal)
                        
                        // Tags Card
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Tags")
                                .font(.headline)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                            
                            HStack {
                                Image(systemName: "tag")
                                    .foregroundColor(.secondary)
                                TextField("Add tags (comma separated)", text: $tags)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .fill(Color(UIColor.tertiarySystemFill))
                            )
                            .padding(.horizontal, 16)
                            
                            Text("Use tags to organize and filter your tasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? DesignSystem.Opacity.strong : DesignSystem.Shadow.sm.opacity), radius: DesignSystem.Shadow.md.radius, x: 0, y: 2)
                        )
                        .padding(.horizontal)
                        
                        // Linked Event Card
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Linked Event")
                                .font(.headline)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                            
                            if let event = linkedEvent {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(event.title ?? "Untitled Event")
                                            .font(.body)
                                        Text(formatEventTime(event))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        linkedEvent = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .fill(Color(UIColor.tertiarySystemFill))
                                )
                                .padding(.horizontal, DesignSystem.Spacing.md)
                            } else {
                                Button {
                                    showingEventPicker = true
                                } label: {
                                    Label("Link to Event", systemImage: "calendar.badge.plus")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .fill(Color(UIColor.tertiarySystemFill))
                                )
                                .padding(.horizontal, DesignSystem.Spacing.md)
                            }
                            
                            Text("Link this task to a calendar event for better context")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? DesignSystem.Opacity.strong : DesignSystem.Shadow.sm.opacity), radius: DesignSystem.Shadow.md.radius, x: 0, y: 2)
                        )
                        .padding(.horizontal)
                        
                        // Subtasks
                        if task.hasSubtasks || !task.isCompleted {
                            Button {
                                showingSubtasks = true
                            } label: {
                                HStack {
                                    Label("Manage Subtasks", systemImage: "list.bullet.indent")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if task.hasSubtasks {
                                        Text("\(task.completedSubtaskCount)/\(task.totalSubtaskCount)")
                                            .foregroundColor(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                                        .shadow(color: Color.black.opacity(colorScheme == .dark ? DesignSystem.Opacity.strong : DesignSystem.Shadow.sm.opacity), radius: DesignSystem.Shadow.md.radius, x: 0, y: 2)
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Actions
                        VStack(spacing: 12) {
                            if task.isCompleted {
                                Button {
                                    markAsIncomplete()
                                } label: {
                                    Label("Mark as Incomplete", systemImage: "arrow.uturn.backward")
                                        .foregroundColor(.orange)
                                        .frame(maxWidth: .infinity)
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .fill(Color.orange.opacity(DesignSystem.Opacity.light))
                                )
                            } else {
                                Button {
                                    markAsComplete()
                                } label: {
                                    Label("Mark as Complete", systemImage: "checkmark")
                                        .foregroundColor(.green)
                                        .frame(maxWidth: .infinity)
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .fill(Color.green.opacity(DesignSystem.Opacity.light))
                                )
                            }
                            
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete Task", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .fill(Color.red.opacity(DesignSystem.Opacity.light))
                            )
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: DesignSystem.Spacing.xxl)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("")
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
                }
            }
            .sheet(isPresented: $showingEventPicker) {
                EventPickerView(selectedEvent: $linkedEvent)
            }
            .sheet(isPresented: $showingSubtasks) {
                SubtasksView(parentTask: task)
            }
            .alert("Delete Task", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteTask()
                }
            } message: {
                Text("Are you sure you want to delete this task? This action cannot be undone.")
            }
            .onAppear {
                loadTaskData()
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .presentationBackground(.regularMaterial)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTaskData() {
        title = task.title ?? ""
        notes = task.notes ?? ""
        priority = task.priorityEnum
        selectedCategory = task.category
        dueDate = task.dueDate
        hasDueDate = task.dueDate != nil
        scheduledTime = task.scheduledTime
        hasScheduledTime = task.scheduledTime != nil
        tags = task.tagsArray.joined(separator: ", ")
        estimatedDuration = Int(task.estimatedDuration)
        linkedEvent = task.linkedEvent
    }
    
    private func saveChanges() {
        let tagArray = tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        _ = taskManager.updateTask(
            task,
            title: title,
            notes: notes.isEmpty ? nil : notes,
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority,
            category: selectedCategory,
            tags: tagArray.isEmpty ? nil : tagArray,
            estimatedDuration: Int16(estimatedDuration),
            scheduledTime: hasScheduledTime ? scheduledTime : nil,
            linkedEvent: linkedEvent,
            parentTask: nil
        )
        
        dismiss()
    }
    
    private func markAsComplete() {
        _ = taskManager.completeTask(task)
        dismiss()
    }
    
    private func markAsIncomplete() {
        _ = taskManager.uncompleteTask(task)
        dismiss()
    }
    
    private func deleteTask() {
        _ = taskManager.deleteTask(task)
        dismiss()
    }
    
    private func formatEventTime(_ event: Event) -> String {
        guard let startTime = event.startTime else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
}

// MARK: - Supporting Views

struct EventPickerView: View {
    @Binding var selectedEvent: Event?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                List {
                    ForEach(scheduleManager.events(for: selectedDate)) { event in
                        Button {
                            selectedEvent = event
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(event.title ?? "Untitled")
                                        .font(.body)
                                    if let startTime = event.startTime, let endTime = event.endTime {
                                        Text("\(startTime, style: .time) - \(endTime, style: .time)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedEvent?.id == event.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Select Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SubtasksView: View {
    let parentTask: Task
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var taskManager: TaskManager
    @State private var newSubtaskTitle = ""
    @FocusState private var isAddingSubtask: Bool
    
    var subtasks: [Task] {
        (parentTask.subtasks?.allObjects as? [Task] ?? []).sorted {
            ($0.createdAt ?? Date()) < ($1.createdAt ?? Date())
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Add new subtask
                HStack {
                    TextField("Add subtask...", text: $newSubtaskTitle)
                        .focused($isAddingSubtask)
                        .onSubmit {
                            addSubtask()
                        }
                    
                    Button("Add") {
                        addSubtask()
                    }
                    .disabled(newSubtaskTitle.isEmpty)
                }
                
                // Existing subtasks
                ForEach(subtasks) { subtask in
                    HStack {
                        Button {
                            toggleSubtask(subtask)
                        } label: {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(subtask.isCompleted ? .green : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(subtask.title ?? "")
                            .strikethrough(subtask.isCompleted)
                            .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                        
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    deleteSubtasks(at: indexSet)
                }
            }
            .navigationTitle("Subtasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isAddingSubtask = true
        }
    }
    
    private func addSubtask() {
        guard !newSubtaskTitle.isEmpty else { return }
        
        _ = taskManager.createSubtask(
            for: parentTask,
            title: newSubtaskTitle,
            notes: nil
        )
        
        newSubtaskTitle = ""
        isAddingSubtask = true
    }
    
    private func toggleSubtask(_ subtask: Task) {
        if subtask.isCompleted {
            _ = taskManager.uncompleteTask(subtask)
        } else {
            _ = taskManager.completeTask(subtask)
        }
    }
    
    private func deleteSubtasks(at offsets: IndexSet) {
        for index in offsets {
            let subtask = subtasks[index]
            _ = taskManager.deleteTask(subtask)
        }
    }
}

#Preview {
    TaskDetailView(task: createSampleTask())
        .environmentObject(TaskManager.shared)
        .environmentObject(ScheduleManager.shared)
}

// Preview helper
private func createSampleTask() -> Task {
    let context = PersistenceController.preview.container.viewContext
    let task = Task(context: context)
    task.id = UUID()
    task.title = "Review presentation slides"
    task.notes = "Make sure to include Q4 metrics"
    task.priority = TaskPriority.high.rawValue
    task.dueDate = Date().addingTimeInterval(86400)
    task.isCompleted = false
    task.createdAt = Date()
    return task
}