import SwiftUI

struct AddEventView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    let preselectedDate: Date?
    let preselectedHour: Int?
    
    @State private var title = ""
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedCategory: Category?
    @State private var notes = ""
    @State private var location = ""
    @State private var isAllDay = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingNewCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = Color.blue
    @State private var showingPaywall = false
    
    init(preselectedDate: Date? = nil, preselectedHour: Int? = nil) {
        self.preselectedDate = preselectedDate
        self.preselectedHour = preselectedHour
        
        let calendar = Calendar.current
        if let date = preselectedDate, let hour = preselectedHour {
            // Create start time at the selected hour
            let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? Date()
            _startTime = State(initialValue: start)
            _endTime = State(initialValue: start.addingTimeInterval(3600))
        } else if let date = preselectedDate {
            // Use the preselected date with current time
            _startTime = State(initialValue: date)
            _endTime = State(initialValue: date.addingTimeInterval(3600))
        } else {
            // Default to current time
            _startTime = State(initialValue: Date())
            _endTime = State(initialValue: Date().addingTimeInterval(3600))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .accessibilityLabel("Event title")
                        .accessibilityHint("Enter the name of your event")
                    
                    if !isAllDay {
                        DatePicker("Start", selection: $startTime)
                            .accessibilityLabel("Start time")
                            .accessibilityHint("Select when the event begins")
                        DatePicker("End", selection: $endTime)
                            .accessibilityLabel("End time")
                            .accessibilityHint("Select when the event ends")
                    } else {
                        DatePicker("Date", selection: $startTime, displayedComponents: .date)
                            .accessibilityLabel("Event date")
                            .accessibilityHint("Select the date for this all-day event")
                    }
                    
                    Toggle("All Day", isOn: $isAllDay)
                        .accessibilityLabel("All day event")
                        .accessibilityHint("Toggle to make this an all-day event")
                } header: {
                    StandardSectionHeader("Event Details", icon: "calendar")
                }
                
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(nil as Category?)
                        ForEach(scheduleManager.categories) { category in
                            Label {
                                Text(category.name ?? "")
                            } icon: {
                                Image(systemName: category.iconName ?? "circle.fill")
                                    .font(.system(size: DesignSystem.IconSize.sm))
                                    .foregroundColor(Color(hex: category.colorHex ?? "#000000"))
                            }
                            .tag(category as Category?)
                        }
                    }
                } header: {
                    StandardSectionHeader("Category", icon: "folder")
                }
                
                Section {
                    TextField("Location", text: $location)
                        .accessibilityLabel("Event location")
                        .accessibilityHint("Enter where the event will take place")
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Event notes")
                        .accessibilityHint("Add any additional details about the event")
                } header: {
                    StandardSectionHeader("Additional Info", icon: "info.circle")
                }
            }
            .standardNavigationTitle("New Event")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        CrashReporter.shared.logUserAction("cancel_add_event")
                        dismiss()
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Discard this event and close")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        createEvent()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Add event")
                    .accessibilityHint(title.isEmpty ? "Enter a title to enable" : "Save this event to your calendar")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallViewPremium()
            }
            .trackViewAppearance("AddEventView")
        }
    }
    
    private func createEvent() {
        
        let finalEndTime = isAllDay ? Calendar.current.date(byAdding: .day, value: 1, to: startTime)! : endTime
        
        let result = scheduleManager.createEvent(
            title: title,
            startTime: startTime,
            endTime: finalEndTime,
            category: selectedCategory,
            notes: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location,
            isAllDay: isAllDay
        )
        
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            if case ScheduleError.subscriptionLimitReached = error {
                showingPaywall = true
            } else {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func createNewCategory() {
        let colorHex = newCategoryColor.toHex()
        let result = scheduleManager.createCategory(
            name: newCategoryName,
            icon: "folder.fill",
            colorHex: colorHex
        )
        if case .success(let category) = result {
            selectedCategory = category
        }
        newCategoryName = ""
        newCategoryColor = .blue
        showingNewCategory = false
    }
}


#Preview {
    AddEventView()
        .environmentObject(ScheduleManager.shared)
}