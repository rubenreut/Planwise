//
//  AddTaskView.swift
//  Momentum
//
//  Minimalist task creation interface
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var taskManager: TaskManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
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
    
    // Attachment State
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachedImages: [UIImage] = []
    @State private var showingDocumentPicker = false
    @State private var attachedFileNames: [String] = []
    
    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Task", text: $title)
                .scaledFont(size: 34, weight: .bold, design: .default)
                .focused($isTitleFocused)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PRIORITY")
                .scaledFont(size: 13, weight: .semibold, design: .default)
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
                                    .scaledFont(size: 14)
                                    .scaledIcon()
                                Text(prio.displayName)
                                    .scaledFont(size: 15, weight: .medium)
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
    }
    
    @ViewBuilder
    private var attachmentsList: some View {
        if !attachedImages.isEmpty || !attachedFileNames.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Attached")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundColor(.secondary)
                
                // Images
                if !attachedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(attachedImages.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            attachedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.5)))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                            }
                        }
                    }
                }
                
                // Files
                ForEach(attachedFileNames, id: \.self) { fileName in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.purple)
                            .scaledFont(size: 14)
                        Text(fileName)
                            .scaledFont(size: 14)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            attachedFileNames.removeAll { $0 == fileName }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .scaledFont(size: 16)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.tertiarySystemFill))
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    titleSection
                    prioritySection
                    
                    // Due Date - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DUE DATE")
                            .scaledFont(size: 13, weight: .semibold, design: .default)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            // Date toggle row
                            HStack {
                                Label {
                                    Text(hasDueDate ? formatDate(dueDate) : "No due date")
                                        .scaledFont(size: 17)
                                        .foregroundColor(hasDueDate ? .primary : .secondary)
                                } icon: {
                                    Image(systemName: "calendar")
                                        .scaledFont(size: 17)
                                        .scaledIcon()
                                        .foregroundColor(hasDueDate ? Color.fromAccentString(selectedAccentColor) : .secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $hasDueDate.animation(.easeInOut(duration: 0.2)))
                                    .onChange(of: hasDueDate) { _, _ in
                                        HapticFeedback.selection.trigger()
                                    }
                                    .labelsHidden()
                                    .tint(Color.fromAccentString(selectedAccentColor))
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
                                            .scaledFont(size: 17)
                                            .foregroundColor(hasTime ? .primary : .secondary)
                                    } icon: {
                                        Image(systemName: "clock")
                                            .scaledFont(size: 17)
                                            .scaledIcon()
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
                                .scaledFont(size: 13, weight: .semibold, design: .default)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            Button {
                                showingCategoryPicker = true
                            } label: {
                                HStack {
                                    if let category = selectedCategory {
                                        Image(systemName: category.iconName ?? "folder")
                                            .scaledFont(size: 17)
                                            .scaledIcon()
                                            .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                                        Text(category.name ?? "")
                                            .scaledFont(size: 17)
                                            .foregroundColor(.primary)
                                    } else {
                                        Image(systemName: "folder")
                                            .scaledFont(size: 17)
                                            .foregroundColor(.secondary)
                                        Text("No category")
                                            .scaledFont(size: 17)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .scaledFont(size: 14, weight: .semibold)
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
                            .scaledFont(size: 13, weight: .semibold, design: .default)
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
                                            .scaledFont(size: 15, weight: .medium)
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
                                        .scaledFont(size: 15, weight: .medium)
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
                    
                    // Notes & Attachments - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("NOTES & ATTACHMENTS")
                            .scaledFont(size: 13, weight: .semibold, design: .default)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            // Notes field
                            TextField("Add notes...", text: $notes, axis: .vertical)
                                .scaledFont(size: 17)
                                .lineLimit(3...8)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(UIColor.secondarySystemFill))
                                )
                                .padding(.horizontal, 20)
                            
                            // Attachment buttons
                            HStack(spacing: 12) {
                                // Photo picker
                                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                                    Label {
                                        Text("Add Photos")
                                            .scaledFont(size: 15, weight: .medium)
                                    } icon: {
                                        Image(systemName: "photo")
                                            .scaledIcon()
                                            .scaledFont(size: 15)
                                    }
                                    .foregroundColor(Color.fromAccentString(selectedAccentColor))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.fromAccentString(selectedAccentColor).opacity(0.1))
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                // Document picker
                                Button {
                                    showingDocumentPicker = true
                                } label: {
                                    Label {
                                        Text("Add Files")
                                            .scaledFont(size: 15, weight: .medium)
                                    } icon: {
                                        Image(systemName: "doc")
                                            .scaledIcon()
                                            .scaledFont(size: 15)
                                    }
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.purple.opacity(0.1))
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            // Show attached items
                            attachmentsList
                        }
                    }
                    
                    // Tags - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("TAGS")
                            .scaledFont(size: 13, weight: .semibold, design: .default)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        TextField("Add tags", text: $tags)
                            .scaledFont(size: 17)
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
                        HapticFeedback.light.trigger()
                        dismiss()
                    }
                    .scaledFont(size: 17)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("New Task")
                        .scaledFont(size: 17, weight: .semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        HapticFeedback.success.trigger()
                        createTask()
                    }
                    .scaledFont(size: 17, weight: .semibold)
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(selectedCategory: $selectedCategory)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallViewPremium()
            }
            .sheet(isPresented: $showingDocumentPicker) {
                AddTaskDocumentPicker(fileNames: $attachedFileNames)
            }
        }
        .task(id: selectedPhotos) {
            attachedImages = []
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    attachedImages.append(image)
                }
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
                .scaledFont(size: 16)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(title)
                .scaledFont(size: 17)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .scaledFont(size: 17)
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
                        .scaledFont(size: 15)
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
                        .scaledFont(size: 15)
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
                    .scaledFont(size: 15)
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
                        .scaledFont(size: 17, weight: .semibold)
                    
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
                        Text(formatDurationText(minutes))
                            .tag(minutes)
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

// MARK: - Task Document Picker

struct AddTaskDocumentPicker: UIViewControllerRepresentable {
    @Binding var fileNames: [String]
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .text, .plainText, .image, .spreadsheet, .presentation], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: AddTaskDocumentPicker
        
        init(_ parent: AddTaskDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                parent.fileNames.append(url.lastPathComponent)
            }
        }
    }
}

#Preview {
    AddTaskView()
        .environmentObject(TaskManager.shared)
        .environmentObject(ScheduleManager.shared)
}
