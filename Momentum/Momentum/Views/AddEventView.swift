import SwiftUI

struct AddEventView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600) // 1 hour later
    @State private var selectedCategory: Category?
    @State private var notes = ""
    @State private var location = ""
    @State private var isAllDay = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                    
                    if !isAllDay {
                        DatePicker("Start", selection: $startTime)
                        DatePicker("End", selection: $endTime)
                    } else {
                        DatePicker("Date", selection: $startTime, displayedComponents: .date)
                    }
                    
                    Toggle("All Day", isOn: $isAllDay)
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(nil as Category?)
                        ForEach(scheduleManager.categories) { category in
                            Label {
                                Text(category.name ?? "")
                            } icon: {
                                Image(systemName: category.iconName ?? "circle.fill")
                                    .foregroundColor(Color(hex: category.colorHex ?? "#000000"))
                            }
                            .tag(category as Category?)
                        }
                    }
                }
                
                Section("Additional Info") {
                    TextField("Location", text: $location)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        CrashReporter.shared.logUserAction("cancel_add_event")
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        createEvent()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .trackViewAppearance("AddEventView")
        }
    }
    
    private func createEvent() {
        print("🎯 AddEventView.createEvent() called")
        print("   Title: '\(title)'")
        print("   Start: \(startTime)")
        print("   End: \(endTime)")
        print("   All Day: \(isAllDay)")
        print("   Category: \(selectedCategory?.name ?? "none")")
        
        let finalEndTime = isAllDay ? Calendar.current.date(byAdding: .day, value: 1, to: startTime)! : endTime
        print("   Final End Time: \(finalEndTime)")
        
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
            print("✅ Event created successfully, dismissing view")
            dismiss()
        case .failure(let error):
            print("❌ Event creation failed: \(error)")
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}


#Preview {
    AddEventView()
        .environmentObject(ScheduleManager.shared)
}