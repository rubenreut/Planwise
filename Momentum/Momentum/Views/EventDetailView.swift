import SwiftUI

struct EventDetailView: View {
    @ObservedObject var event: Event
    @EnvironmentObject var scheduleManager: ScheduleManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    
    // Edit mode state
    @State private var editTitle: String = ""
    @State private var editStartTime: Date = Date()
    @State private var editEndTime: Date = Date()
    @State private var editCategory: Category?
    @State private var editLocation: String = ""
    @State private var editNotes: String = ""
    @State private var editIsAllDay: Bool = false
    
    private var isAllDay: Bool {
        event.notes?.contains("[ALL_DAY]") ?? false
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if isEditing {
                        editingContent
                    } else {
                        viewingContent
                    }
                }
                .padding()
            }
            .standardNavigationTitle(isEditing ? "Edit Event" : "Event Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            CrashReporter.shared.logUserAction("cancel_edit_event")
                            cancelEditing()
                        }
                    } else {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this event?")
            }
            .trackViewAppearance("EventDetailView", additionalData: [
                "event_id": event.objectID.uriRepresentation().absoluteString,
                "is_all_day": isAllDay
            ])
        }
    }
    
    // MARK: - Viewing Content
    private var viewingContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md + 4) {
            // Title and Category
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(event.title ?? "Untitled")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let category = event.category {
                    HStack {
                        Circle()
                            .fill(Color(hex: category.colorHex ?? "#007AFF"))
                            .frame(width: DesignSystem.Spacing.sm, height: DesignSystem.Spacing.sm)
                        Text(category.name ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Time Information
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Label {
                    if isAllDay {
                        Text("All Day")
                    } else if let start = event.startTime, let end = event.endTime {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                            Text(formatTimeRange(start: start, end: end))
                                .font(.headline)
                            Text(formatDuration(start: start, end: end))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                }
                
                if let start = event.startTime {
                    Label {
                        Text(formatDate(start))
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Location
            if let location = event.location, !location.isEmpty {
                Divider()
                
                Label {
                    Text(location)
                        .font(.body)
                } icon: {
                    Image(systemName: "location")
                        .foregroundColor(.blue)
                }
            }
            
            // Notes
            if let notes = event.notes, !notes.isEmpty, !notes.contains("[ALL_DAY]") {
                Divider()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Label("Notes", systemImage: "note.text")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if let attributedString = try? AttributedString(markdown: notes) {
                        Text(attributedString)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(notes)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Spacer(minLength: 40)
            
            // Delete Button
            Button(action: { showingDeleteAlert = true }) {
                Label("Delete Event", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(DesignSystem.Opacity.light))
                    .foregroundColor(.red)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }
        }
    }
    
    // MARK: - Editing Content
    private var editingContent: some View {
        VStack(spacing: DesignSystem.Spacing.md + 4) {
            // Title
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Title")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Event Title", text: $editTitle)
                    .font(.headline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }
            
            // Category
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Category")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(scheduleManager.categories, id: \.self) { category in
                            EventCategoryChip(
                                category: category,
                                isSelected: editCategory == category,
                                onTap: { editCategory = category }
                            )
                        }
                    }
                }
            }
            
            // All Day Toggle
            Toggle("All Day", isOn: $editIsAllDay)
                .padding(.vertical, DesignSystem.Spacing.xs)
            
            // Time Selection
            if !editIsAllDay {
                VStack(spacing: DesignSystem.Spacing.md) {
                    DatePicker("Start", selection: $editStartTime)
                        .datePickerStyle(.compact)
                    
                    DatePicker("End", selection: $editEndTime, in: editStartTime...)
                        .datePickerStyle(.compact)
                }
            }
            
            // Location
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Add location", text: $editLocation)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }
            
            // Notes
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Add notes", text: $editNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }
        }
    }
    
    // MARK: - Actions
    private func startEditing() {
        editTitle = event.title ?? ""
        editStartTime = event.startTime ?? Date()
        editEndTime = event.endTime ?? Date()
        editCategory = event.category
        editLocation = event.location ?? ""
        // Remove [ALL_DAY] tag from notes when editing
        if let notes = event.notes {
            editNotes = notes.replacingOccurrences(of: "[ALL_DAY]\n", with: "").replacingOccurrences(of: "[ALL_DAY]", with: "")
        } else {
            editNotes = ""
        }
        editIsAllDay = isAllDay
        isEditing = true
    }
    
    private func cancelEditing() {
        isEditing = false
    }
    
    private func saveChanges() {
        let result = scheduleManager.updateEvent(
            event,
            title: editTitle,
            startTime: editIsAllDay ? nil : editStartTime,
            endTime: editIsAllDay ? nil : editEndTime,
            category: editCategory,
            notes: editIsAllDay ? "[ALL_DAY]" + (editNotes.isEmpty ? "" : "\n\(editNotes)") : (editNotes.isEmpty ? nil : editNotes),
            location: editLocation.isEmpty ? nil : editLocation,
            isCompleted: nil,
            colorHex: nil,
            iconName: nil,
            priority: nil,
            tags: nil,
            url: nil,
            energyLevel: nil,
            weatherRequired: nil,
            bufferTimeBefore: nil,
            bufferTimeAfter: nil,
            recurrenceRule: nil,
            recurrenceEndDate: nil,
            linkedTasks: nil
        )
        
        switch result {
        case .success:
            isEditing = false
        case .failure(let error):
            // Could show an error alert here
            break
        }
    }
    
    private func deleteEvent() {
        let result = scheduleManager.deleteEvent(event)
        
        switch result {
        case .success:
            CrashReporter.shared.addBreadcrumb(
                message: "Event deleted successfully",
                category: "user_action",
                level: .info
            )
        case .failure(let error):
            CrashReporter.shared.logError(
                error,
                userInfo: ["context": "delete_event_from_detail_view"]
            )
        }
        
        dismiss()
    }
    
    // MARK: - Formatters
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private func formatDuration(start: Date, end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

// MARK: - Event Category Chip
private struct EventCategoryChip: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.xxs + 2) {
                Circle()
                    .fill(Color(hex: category.colorHex ?? "#007AFF"))
                    .frame(width: 12, height: 12)
                
                Text(category.name ?? "")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.full)
                    .fill(isSelected ? Color(hex: category.colorHex ?? "#007AFF").opacity(DesignSystem.Opacity.medium) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.full)
                    .strokeBorder(
                        isSelected ? Color(hex: category.colorHex ?? "#007AFF") : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        EventDetailView(event: createPreviewEvent())
            .environmentObject(ScheduleManager.shared)
    }
}

@MainActor
private func createPreviewEvent() -> Event {
    let context = PersistenceController.preview.container.viewContext
    let event = Event(context: context)
    event.title = "Team Meeting"
    event.startTime = Date()
    event.endTime = Date().addingTimeInterval(3600)
    event.location = "Conference Room A"
    event.notes = "Discuss Q4 roadmap"
    
    let category = Category(context: context)
    category.name = "Work"
    category.colorHex = "#007AFF"
    event.category = category
    
    return event
}