import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct TaskDetailView: View {
    let task: Task
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var taskManager: TaskManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
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
    @State private var showingPhotoOptions = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var attachedPhotos: [TaskPhoto] = []
    @State private var showingFullScreenPhoto: TaskPhoto?
    @State private var showingFilePicker = false
    @State private var attachedFiles: [String] = []
    @State private var fileURLs: [String: URL] = [:]
    @State private var previewURL: URL?
    
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
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("NOTES & ATTACHMENTS")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                ZStack(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text("Add notes, links, or describe attachments...")
                                            .foregroundColor(.secondary)
                                            .padding(.top, 8)
                                    }
                                    TextEditor(text: $notes)
                                        .frame(minHeight: 100)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "paperclip")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("You can paste links or describe attached documents here")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
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
                                            .scaledFont(size: 17)
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
                        
                        // Unified Attachments Section (Photos and Files)
                        AttachmentListView(task: task)
                            .padding(.top, DesignSystem.Spacing.md)
                        
                        // Legacy Photo Attachments (keeping temporarily for compatibility)
                        if false { // Disabled - using new attachment system
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Button {
                                showingPhotoOptions = true
                            } label: {
                                HStack {
                                    Label("Attach Photo", systemImage: "photo")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if !attachedPhotos.isEmpty {
                                        Text("\(attachedPhotos.count)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Color.fromAccentString(selectedAccentColor))
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                                        .shadow(color: Color.black.opacity(colorScheme == .dark ? DesignSystem.Opacity.strong : DesignSystem.Shadow.sm.opacity), radius: DesignSystem.Shadow.md.radius, x: 0, y: 2)
                                )
                            }
                            
                            // Display attached photos
                            if !attachedPhotos.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        ForEach(attachedPhotos) { photo in
                                            Button {
                                                showingFullScreenPhoto = photo
                                            } label: {
                                                if let thumbnailData = photo.thumbnailData,
                                                   let thumbnail = UIImage(data: thumbnailData) {
                                                    Image(uiImage: thumbnail)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 80, height: 80)
                                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                        )
                                                } else if let fullImage = UIImage(data: photo.imageData) {
                                                    // Fallback to full image if no thumbnail
                                                    Image(uiImage: fullImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 80, height: 80)
                                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                        )
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.horizontal)
                        } // End of disabled legacy photo section
                        
                        // Legacy File Attachments (keeping temporarily for compatibility)
                        if false { // Disabled - using new attachment system
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Button {
                                showingFilePicker = true
                            } label: {
                                HStack {
                                    Label("Attach File", systemImage: "doc.badge.plus")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if !attachedFiles.isEmpty {
                                        Text("\(attachedFiles.count)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Color.fromAccentString(selectedAccentColor))
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                                        .shadow(color: Color.black.opacity(colorScheme == .dark ? DesignSystem.Opacity.strong : DesignSystem.Shadow.sm.opacity), radius: DesignSystem.Shadow.md.radius, x: 0, y: 2)
                                )
                            }
                            
                            // Display attached files
                            if !attachedFiles.isEmpty {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    ForEach(attachedFiles, id: \.self) { fileName in
                                        HStack {
                                            Image(systemName: fileIcon(for: fileName))
                                                .foregroundColor(Color.fromAccentString(selectedAccentColor))
                                            Text(fileName)
                                                .font(.footnote)
                                                .lineLimit(1)
                                            Spacer()
                                            
                                            // Open file button
                                            Button {
                                                openFile(fileName)
                                            } label: {
                                                Image(systemName: "arrow.up.forward.square")
                                                    .foregroundColor(Color.fromAccentString(selectedAccentColor))
                                                    .scaledFont(size: 17)
                                            }
                                            
                                            // Delete button
                                            Button {
                                                if let index = attachedFiles.firstIndex(of: fileName) {
                                                    attachedFiles.remove(at: index)
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.caption)
                                            }
                                        }
                                        .padding(DesignSystem.Spacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                                                .fill(Color.gray.opacity(0.1))
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            openFile(fileName)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.horizontal)
                        } // End of disabled legacy file section
                        
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
            .dismissKeyboardOnTap()
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
            .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions) {
                Button("Take Photo") {
                    showingCamera = true
                }
                Button("Choose from Library") {
                    showingImagePicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage) { image in
                    if let image = image {
                        attachPhotoToTask(image)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker(image: $selectedImage) { image in
                    if let image = image {
                        attachPhotoToTask(image)
                    }
                }
            }
            .sheet(item: $showingFullScreenPhoto) { photo in
                FullScreenPhotoView(photo: photo)
            }
            .sheet(isPresented: $showingFilePicker) {
                TaskDocumentPicker { urls in
                    for url in urls {
                        let fileName = url.lastPathComponent
                        attachedFiles.append(fileName)
                        
                        // Copy file to app's documents directory
                        if let taskId = task.id {
                            saveFileForTask(url: url, fileName: fileName, taskId: taskId)
                        }
                    }
                }
            }
            .quickLookPreview($previewURL)
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
        
        // Load attached photos
        if let taskId = task.id {
            attachedPhotos = TaskPhotoManager.shared.loadPhotos(for: taskId)
        }
        
        // Load attached files
        loadAttachedFiles()
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
    
    private func attachPhotoToTask(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        guard let taskId = task.id else { return }
        
        let photo = TaskPhoto(
            taskId: taskId,
            imageData: imageData,
            thumbnailData: TaskPhoto.createThumbnail(from: imageData),
            caption: nil
        )
        
        // Save photo to disk
        do {
            try TaskPhotoManager.shared.savePhoto(photo)
            
            // Add to local array to update UI immediately
            attachedPhotos.append(photo)
            
            // Show success feedback
            HapticFeedback.success.trigger()
            
            print("Photo attached successfully to task: \(task.title ?? "")")
        } catch {
            print("Failed to save photo: \(error)")
        }
    }
    
    private func fileIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.richtext"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "tablecells"
        case "ppt", "pptx":
            return "doc.on.doc"
        case "jpg", "jpeg", "png", "gif", "heic":
            return "photo"
        case "mp4", "mov", "avi":
            return "video"
        case "mp3", "m4a", "wav":
            return "music.note"
        case "zip", "rar", "7z":
            return "doc.zipper"
        case "txt":
            return "doc.plaintext"
        default:
            return "doc"
        }
    }
    
    private func openFile(_ fileName: String) {
        guard let taskId = task.id else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let taskFilesDir = documentsPath.appendingPathComponent("TaskFiles").appendingPathComponent(taskId.uuidString)
        let fileURL = taskFilesDir.appendingPathComponent(fileName)
        
        // Check if file exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Open with QuickLook
            previewURL = fileURL
        } else {
            print("File not found: \(fileURL)")
        }
    }
    
    private func saveFileForTask(url: URL, fileName: String, taskId: UUID) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let taskFilesDir = documentsPath.appendingPathComponent("TaskFiles").appendingPathComponent(taskId.uuidString)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: taskFilesDir, withIntermediateDirectories: true)
        
        let destinationURL = taskFilesDir.appendingPathComponent(fileName)
        
        // Copy file
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: url, to: destinationURL)
            fileURLs[fileName] = destinationURL
            print("File saved: \(destinationURL)")
        } catch {
            print("Failed to save file: \(error)")
        }
    }
    
    private func loadAttachedFiles() {
        guard let taskId = task.id else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let taskFilesDir = documentsPath.appendingPathComponent("TaskFiles").appendingPathComponent(taskId.uuidString)
        
        // Load existing files
        if let files = try? FileManager.default.contentsOfDirectory(at: taskFilesDir, includingPropertiesForKeys: nil) {
            for fileURL in files {
                let fileName = fileURL.lastPathComponent
                if !attachedFiles.contains(fileName) {
                    attachedFiles.append(fileName)
                    fileURLs[fileName] = fileURL
                }
            }
        }
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
                                        .scaledFont(size: 17)
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
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
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
                            ZStack {
                                // Simple circle border
                                Circle()
                                    .stroke(subtask.isCompleted ? Color.fromAccentString(selectedAccentColor) : Color.gray.opacity(0.3), lineWidth: 2)
                                    .scaledFrame(width: 20, height: 20)
                                
                                // Fill when completed
                                if subtask.isCompleted {
                                    Circle()
                                        .fill(Color.fromAccentString(selectedAccentColor))
                                        .scaledFrame(width: 20, height: 20)
                                    
                                    Image(systemName: "checkmark")
                                        .scaledFont(size: 12, weight: .bold)
                                        .scaledIcon()
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 24, height: 24)
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

// MARK: - Full Screen Photo View

struct FullScreenPhotoView: View {
    let photo: TaskPhoto
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastStoredOffset = CGSize.zero
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            if let image = UIImage(data: photo.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1), 4)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1 {
                                    withAnimation(.spring()) {
                                        scale = 1
                                        offset = .zero
                                        lastStoredOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                if scale > 1 {
                                    // Only allow panning when zoomed in
                                    offset = CGSize(
                                        width: lastStoredOffset.width + value.translation.width,
                                        height: lastStoredOffset.height + value.translation.height
                                    )
                                } else {
                                    // Allow vertical swipe to dismiss when not zoomed
                                    if abs(value.translation.height) > 100 {
                                        dismiss()
                                    }
                                }
                            }
                            .onEnded { value in
                                isDragging = false
                                if scale <= 1 && abs(value.translation.height) > 50 {
                                    dismiss()
                                } else {
                                    lastStoredOffset = offset
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                                lastStoredOffset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
            }
            
            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.7))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                            )
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .statusBar(hidden: true)
    }
}

// MARK: - Task Document Picker

struct TaskDocumentPicker: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf, .text, .plainText, .image, .spreadsheet, .presentation
        ], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: TaskDocumentPicker
        
        init(_ parent: TaskDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
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