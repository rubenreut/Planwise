//
//  AddHabitView.swift
//  Momentum
//
//  Premium habit creation interface with Apple design standards
//

import SwiftUI
import UIKit
import PhotosUI

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var habitManager: HabitManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
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
    @State private var isCreating = false
    @FocusState private var isNameFocused: Bool
    @State private var showingAdvancedOptions = false
    @State private var showingPaywall = false
    
    // Attachment State
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachedImages: [UIImage] = []
    @State private var showingDocumentPicker = false
    @State private var attachedFileNames: [String] = []
    
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
    
    // MARK: - Computed Properties for UI Sections
    
    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Habit", text: $name)
                .scaledFont(size: 34, weight: .bold, design: .default)
                .focused($isNameFocused)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var trackingTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TRACKING TYPE")
                .scaledFont(size: 13, weight: .semibold, design: .default)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HabitTrackingType.allCases, id: \.self) { type in
                        trackingTypeButton(for: type)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    @ViewBuilder
    private func trackingTypeButton(for type: HabitTrackingType) -> some View {
        Button {
            trackingType = type
            selectionFeedback.selectionChanged()
        } label: {
            Text(type.displayName)
                .scaledFont(size: 15, weight: .medium)
                .foregroundColor(trackingType == type ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(trackingType == type ? Color.fromAccentString(selectedAccentColor) : Color(UIColor.secondarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var goalSettingSection: some View {
        if trackingType != .binary {
            VStack(alignment: .leading, spacing: 16) {
                Text("DAILY GOAL")
                    .scaledFont(size: 13, weight: .semibold, design: .default)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                
                HStack {
                    Image(systemName: "target")
                        .scaledIcon()
                        .scaledFont(size: 17)
                        .foregroundColor(.orange)
                    
                    goalInputFields
                    
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
    }
    
    @ViewBuilder
    private var goalInputFields: some View {
        switch trackingType {
        case .duration:
            TextField("30", value: $goalTarget, format: .number)
                .scaledFont(size: 17)
                .keyboardType(.numberPad)
                .frame(width: 60)
            
            Text("minutes")
                .scaledFont(size: 17)
                .foregroundColor(.secondary)
            
        case .quantity:
            TextField("8", value: $goalTarget, format: .number)
                .scaledFont(size: 17)
                .keyboardType(.decimalPad)
                .frame(width: 60)
            
            TextField("units", text: $goalUnit)
                .scaledFont(size: 17)
                .frame(width: 100)
            
        case .quality:
            Text("Rate 1-5")
                .scaledFont(size: 17)
                .foregroundColor(.secondary)
            
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FREQUENCY")
                .scaledFont(size: 13, weight: .semibold, design: .default)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HabitFrequency.allCases, id: \.self) { freq in
                        frequencyButton(for: freq)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            if frequency == .custom {
                customFrequencyDays
            }
        }
    }
    
    @ViewBuilder
    private func frequencyButton(for freq: HabitFrequency) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                frequency = freq
            }
            selectionFeedback.selectionChanged()
        } label: {
            Text(freq.displayName)
                .scaledFont(size: 15, weight: .medium)
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
    
    @ViewBuilder
    private var customFrequencyDays: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECT DAYS")
                .scaledFont(size: 13, weight: .semibold, design: .default)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            
            HStack(spacing: 8) {
                ForEach(weekDays, id: \.0) { day, letter in
                    dayButton(day: day, letter: letter)
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
    
    @ViewBuilder
    private func dayButton(day: Int, letter: String) -> some View {
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
                        .fill(customDays.contains(day) ? Color.fromAccentString(selectedAccentColor) : Color(UIColor.secondarySystemFill))
                )
                .foregroundColor(customDays.contains(day) ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var categorySection: some View {
        if !scheduleManager.categories.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("CATEGORY")
                    .scaledFont(size: 13, weight: .semibold, design: .default)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                
                categoryMenu
            }
        }
    }
    
    @ViewBuilder
    private var categoryMenu: some View {
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
                        .scaledIcon()
                        .scaledFont(size: 17)
                        .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                    Text(category.name ?? "")
                        .scaledFont(size: 17)
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "folder")
                        .scaledIcon()
                        .scaledFont(size: 17)
                        .foregroundColor(.secondary)
                    Text("No category")
                        .scaledFont(size: 17)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .scaledIcon()
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
    
    @ViewBuilder
    private var notesAndAttachmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NOTES & ATTACHMENTS")
                .scaledFont(size: 13, weight: .semibold, design: .default)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                notesField
                attachmentButtons
                attachmentsList
            }
        }
    }
    
    @ViewBuilder
    private var notesField: some View {
        TextField("Add notes...", text: $notes, axis: .vertical)
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
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                Label {
                    Text("Add Photos")
                        .scaledFont(size: 15, weight: .medium)
                } icon: {
                    Image(systemName: "photo")
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
            
            Button {
                showingDocumentPicker = true
            } label: {
                Label {
                    Text("Add Files")
                        .scaledFont(size: 15, weight: .medium)
                } icon: {
                    Image(systemName: "doc")
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
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    titleSection
                    trackingTypeSection
                    goalSettingSection
                    frequencySection
                    categorySection
                    notesAndAttachmentsSection
                    
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
                    .scaledFont(size: 17)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("New Habit")
                        .scaledFont(size: 17, weight: .semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createHabit()
                    }
                    .scaledFont(size: 17, weight: .semibold)
                    .disabled(name.isEmpty || isCreating)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallViewPremium()
            }
            .sheet(isPresented: $showingDocumentPicker) {
                HabitDocumentPicker(fileNames: $attachedFileNames)
            }
            .interactiveDismissDisabled(isCreating)
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
            icon: "star.fill",
            color: "#007AFF",
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



// MARK: - Document Picker

import UniformTypeIdentifiers

struct HabitDocumentPicker: UIViewControllerRepresentable {
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
        let parent: HabitDocumentPicker
        
        init(_ parent: HabitDocumentPicker) {
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
    AddHabitView()
        .environmentObject(HabitManager.shared)
        .environmentObject(ScheduleManager.shared)
}