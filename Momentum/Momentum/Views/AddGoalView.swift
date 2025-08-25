//
//  AddGoalView.swift
//  Momentum
//
//  Create new goals with various tracking types
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var goalManager: GoalManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var habitManager: HabitManager
    @StateObject private var areaManager = GoalAreaManager.shared
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    // Form State
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType: GoalType = .hybrid // Default to hybrid for new goals
    @State private var targetValue: Double = 100
    @State private var hasTargetValue = false // Make numeric target optional
    @State private var unit = ""
    @State private var targetDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @State private var hasTargetDate = false // Make target date optional
    @State private var priority: GoalPriority = .medium
    @State private var selectedCategory: Category?
    @State private var selectedHabits: Set<Habit> = []
    @State private var hasMilestones = false // Track if user wants milestones
    @State private var hasLinkedHabits = false // Track if user wants linked habits
    
    // UI State
    @State private var showingHabitPicker = false
    @State private var showingAreaManager = false
    @State private var isCreating = false
    @FocusState private var isTitleFocused: Bool
    @State private var showingPaywall = false
    
    // Milestone management
    @State private var milestones: [MilestoneItem] = []
    @State private var showingAddMilestone = false
    @State private var newMilestoneTitle = ""
    @State private var newMilestoneTargetValue: Double = 0
    
    // Attachment State
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachedImages: [UIImage] = []
    @State private var showingDocumentPicker = false
    @State private var attachedFileNames: [String] = []
    
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
    
    @ViewBuilder
    private var attachmentsList: some View {
        if !attachedImages.isEmpty || !attachedFileNames.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Attached")
                    .font(.caption)
                    .fontWeight(.semibold)
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
                            .font(.system(size: 14))
                        Text(fileName)
                            .scaledFont(size: 14)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            attachedFileNames.removeAll { $0 == fileName }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
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
    
    // MARK: - Computed Properties for UI Sections
    
    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Goal", text: $title)
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
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("APPEARANCE")
                .scaledFont(size: 13, weight: .semibold, design: .default)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            // Color and icon come from category
        }
    }
    
    @ViewBuilder
    private var goalComponentsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("GOAL COMPONENTS")
                .scaledFont(size: 13, weight: .semibold, design: .default)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            Text("Add any combination of components to track your goal")
                .scaledFont(size: 14)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                // Numeric Target Toggle
                toggleRow(
                    title: "Numeric Target",
                    subtitle: "Track progress toward a specific number",
                    icon: "chart.line.uptrend.xyaxis",
                    isOn: $hasTargetValue
                )
                
                // Milestones Toggle
                toggleRow(
                    title: "Milestones",
                    subtitle: "Break goal into checkpoints",
                    icon: "flag.checkered",
                    isOn: $hasMilestones
                )
                
                // Linked Habits Toggle
                toggleRow(
                    title: "Linked Habits",
                    subtitle: "Connect daily habits to this goal",
                    icon: "repeat.circle",
                    isOn: $hasLinkedHabits
                )
                
                // Target Date Toggle
                toggleRow(
                    title: "Target Date",
                    subtitle: "Set a deadline for completion",
                    icon: "calendar",
                    isOn: $hasTargetDate
                )
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private func toggleRow(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .scaledIcon()
                .font(.system(size: 20))
                .foregroundColor(Color.fromAccentString(selectedAccentColor))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .scaledFont(size: 16, weight: .medium)
                
                Text(subtitle)
                    .scaledFont(size: 12)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var componentSpecificSections: some View {
        VStack(spacing: 20) {
            // Numeric fields - shown when hasTargetValue is true
            if hasTargetValue {
                numericGoalFields
            }
            
            // Milestones - shown when hasMilestones is true
            if hasMilestones {
                milestoneGoalFields
            }
            
            // Linked habits - shown when hasLinkedHabits is true
            if hasLinkedHabits {
                habitGoalFields
            }
            
            // Target date - shown when hasTargetDate is true
            if hasTargetDate {
                targetDateSection
            }
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
                    ForEach(GoalPriority.allCases, id: \.self) { prio in
                        priorityButton(for: prio)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    @ViewBuilder
    private func priorityButton(for prio: GoalPriority) -> some View {
        Button {
            priority = prio
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .scaledIcon()
                    .font(.system(size: 14))
                
                Text(prio.displayName)
                    .scaledFont(size: 15, weight: .medium)
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
    
    @ViewBuilder
    private var targetDateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TARGET DATE")
                .scaledFont(size: 13, weight: .semibold, design: .default)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            DatePicker("", selection: $targetDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var targetDateToggle: some View {
        HStack {
            Label {
                Text("Target Date")
                    .scaledFont(size: 17)
            } icon: {
                Image(systemName: "calendar")
                    .scaledIcon()
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
    }
    
    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DESCRIPTION & ATTACHMENTS")
                .scaledFont(size: 13, weight: .semibold, design: .default)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                descriptionField
                attachmentButtons
                attachmentsList
            }
        }
    }
    
    @ViewBuilder
    private var descriptionField: some View {
        TextField("Add description...", text: $description, axis: .vertical)
            .scaledFont(size: 17)
            .lineLimit(3...8)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemFill))
            )
            .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var attachmentButtons: some View {
        HStack(spacing: 12) {
            photoPickerButton
            documentPickerButton
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var photoPickerButton: some View {
        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
            Label {
                Text("Add Photos")
                    .scaledFont(size: 15, weight: .medium)
            } icon: {
                Image(systemName: "photo")
                    .scaledIcon()
                    .font(.system(size: 15))
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
    }
    
    @ViewBuilder
    private var documentPickerButton: some View {
        Button {
            showingDocumentPicker = true
        } label: {
            Label {
                Text("Add Files")
                    .scaledFont(size: 15, weight: .medium)
            } icon: {
                Image(systemName: "doc")
                    .scaledIcon()
                    .font(.system(size: 15))
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
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    titleSection
                    appearanceSection
                    goalComponentsSection // New unified components section
                    componentSpecificSections // Shows fields based on toggles
                    prioritySection
                    descriptionSection
                    
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
                    .scaledFont(size: 17)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("New Goal")
                        .scaledFont(size: 17, weight: .semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createGoal()
                    }
                    .scaledFont(size: 17, weight: .semibold)
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
            .sheet(isPresented: $showingDocumentPicker) {
                GoalDocumentPicker(fileNames: $attachedFileNames)
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
        }  // NavigationStack
    }  // body
    
    // MARK: - Type-specific Fields
    
    @ViewBuilder
    private var numericGoalFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TARGET")
                .scaledFont(size: 13, weight: .semibold, design: .default)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            HStack {
                Image(systemName: "number")
                    .scaledIcon()
                    .font(.system(size: 17))
                    .foregroundColor(.purple)
                
                TextField("100", value: $targetValue, format: .number)
                    .scaledFont(size: 17)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                
                TextField("units", text: $unit)
                    .scaledFont(size: 17)
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
                .scaledFont(size: 13, weight: .semibold, design: .default)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            Button {
                showingHabitPicker = true
            } label: {
                HStack {
                    Image(systemName: "link")
                        .scaledIcon()
                        .font(.system(size: 17))
                        .foregroundColor(.indigo)
                    
                    Text("Link Habits")
                        .scaledFont(size: 17)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if !selectedHabits.isEmpty {
                        Text("\(selectedHabits.count) selected")
                            .scaledFont(size: 17)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .scaledIcon()
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
            // Header with add button
            HStack {
                Text("MILESTONES")
                    .scaledFont(size: 13, weight: .semibold, design: .default)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    HapticFeedback.light.trigger()
                    showingAddMilestone = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundColor(Color.fromAccentString(selectedAccentColor))
                }
            }
            .padding(.horizontal, 20)
            
            if milestones.isEmpty {
                // Empty state
                HStack {
                    Image(systemName: "flag.checkered")
                        .scaledIcon()
                        .font(.system(size: 17))
                        .foregroundColor(Color.fromAccentString(selectedAccentColor))
                    
                    Text("Add milestones to track progress")
                        .scaledFont(size: 15)
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
            } else {
                // Milestone list
                VStack(spacing: 0) {
                    ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                        HStack {
                            // Milestone number
                            Text("\(index + 1)")
                                .scaledFont(size: 14, weight: .semibold)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.fromAccentString(selectedAccentColor)))
                            
                            // Milestone details
                            VStack(alignment: .leading, spacing: 2) {
                                Text(milestone.title)
                                    .scaledFont(size: 16, weight: .medium)
                                    .foregroundColor(.primary)
                                
                                if milestone.targetValue > 0 {
                                    Text("Target: \(Int(milestone.targetValue))")
                                        .scaledFont(size: 13)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Delete button
                            Button {
                                HapticFeedback.light.trigger()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    milestones.removeAll { $0.id == milestone.id }
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .scaledIcon()
                                    .font(.system(size: 16))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if index < milestones.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemFill))
                )
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showingAddMilestone) {
            AddNewMilestoneSheet(
                milestones: $milestones,
                isPresented: $showingAddMilestone
            )
        }
    }
    
    // MARK: - Actions
    
    private func createGoal() {
        isCreating = true
        
        // Always use hybrid type for new goals with multiple components
        let result = goalManager.createGoal(
            title: title,
            description: description.isEmpty ? nil : description,
            type: .hybrid, // Always hybrid for maximum flexibility
            targetValue: hasTargetValue ? targetValue : nil,
            targetDate: hasTargetDate ? targetDate : nil,
            unit: unit.isEmpty ? nil : unit,
            priority: priority,
            category: selectedCategory,
            linkedHabits: hasLinkedHabits ? Array(selectedHabits) : []
        )
        
        switch result {
        case .success(let goal):
            // Add milestones if user chose to add them
            if hasMilestones && !milestones.isEmpty {
                for milestone in milestones {
                    _ = goalManager.addMilestone(
                        to: goal,
                        title: milestone.title,
                        targetValue: milestone.targetValue
                    )
                }
            }
            
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
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    var body: some View {
        NavigationView {
            List(habitManager.habits) { habit in
                HStack {
                    Image(systemName: habit.iconName ?? "star")
                        .scaledIcon()
                        .foregroundColor(Color(hex: habit.colorHex ?? "#007AFF"))
                    
                    Text(habit.name ?? "")
                    
                    Spacer()
                    
                    if selectedHabits.contains(habit) {
                        Image(systemName: "checkmark.circle.fill")
                            .scaledIcon()
                            .foregroundColor(Color.fromAccentString(selectedAccentColor))
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

// MARK: - Goal Document Picker

struct GoalDocumentPicker: UIViewControllerRepresentable {
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
        let parent: GoalDocumentPicker
        
        init(_ parent: GoalDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                parent.fileNames.append(url.lastPathComponent)
            }
        }
    }
}

// MARK: - Milestone Item

struct MilestoneItem: Identifiable {
    let id = UUID()
    var title: String
    var targetValue: Double
}

// MARK: - Add New Milestone Sheet

struct AddNewMilestoneSheet: View {
    @Binding var milestones: [MilestoneItem]
    @Binding var isPresented: Bool
    
    @State private var title = ""
    @State private var targetValue: Double = 0
    @State private var includeTarget = false
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Milestone title", text: $title)
                        .focused($isTitleFocused)
                    
                    Toggle("Include target value", isOn: $includeTarget.animation())
                        .onChange(of: includeTarget) { _, _ in
                            HapticFeedback.selection.trigger()
                        }
                    
                    if includeTarget {
                        HStack {
                            Text("Target")
                            Spacer()
                            TextField("0", value: $targetValue, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }
            }
            .navigationTitle("Add Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticFeedback.light.trigger()
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        HapticFeedback.success.trigger()
                        let milestone = MilestoneItem(
                            title: title,
                            targetValue: includeTarget ? targetValue : 0
                        )
                        milestones.append(milestone)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTitleFocused = true
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