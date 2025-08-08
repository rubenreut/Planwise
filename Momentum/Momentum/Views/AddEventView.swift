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
    @FocusState private var isTitleFocused: Bool
    
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
    
    private var eventDuration: String {
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            return "\(minutes) min"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Title - Structured style
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Event", text: $title)
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .focused($isTitleFocused)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 8)
                        
                        Divider()
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
                                showingNewCategory = true
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
                    
                    // Date & Time - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DATE & TIME")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            // All day toggle
                            HStack {
                                Label {
                                    Text("All Day")
                                        .font(.system(size: 17))
                                } icon: {
                                    Image(systemName: "sun.max.fill")
                                        .font(.system(size: 17))
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $isAllDay)
                                    .labelsHidden()
                                    .tint(.orange)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.secondarySystemFill))
                            
                            if !isAllDay {
                                Divider()
                                    .background(Color(UIColor.separator).opacity(0.3))
                                
                                // Start time
                                HStack {
                                    Label {
                                        Text("Start")
                                            .font(.system(size: 17))
                                    } icon: {
                                        Image(systemName: "clock")
                                            .font(.system(size: 17))
                                            .foregroundColor(.green)
                                    }
                                    
                                    Spacer()
                                    
                                    DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemFill))
                                
                                Divider()
                                    .background(Color(UIColor.separator).opacity(0.3))
                                
                                // End time
                                HStack {
                                    Label {
                                        Text("End")
                                            .font(.system(size: 17))
                                    } icon: {
                                        Image(systemName: "clock.badge.checkmark")
                                            .font(.system(size: 17))
                                            .foregroundColor(.red)
                                    }
                                    
                                    Spacer()
                                    
                                    DatePicker("", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemFill))
                            } else {
                                Divider()
                                    .background(Color(UIColor.separator).opacity(0.3))
                                
                                DatePicker("", selection: $startTime, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .padding(8)
                                    .background(Color(UIColor.secondarySystemFill))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                    }
                    
                    // Location - Structured style
                    VStack(alignment: .leading, spacing: 16) {
                        Text("LOCATION")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.red)
                            
                            TextField("Add location", text: $location)
                                .font(.system(size: 17))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemFill))
                        )
                        .padding(.horizontal, 20)
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
                    .font(.system(size: 17))
                }
                
                ToolbarItem(placement: .principal) {
                    Text("New Event")
                        .font(.system(size: 17, weight: .semibold))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createEvent()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .disabled(title.isEmpty)
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
            .sheet(isPresented: $showingNewCategory) {
                CreateCategorySheet(
                    isPresented: $showingNewCategory,
                    onSave: { name, color, icon in
                        createNewCategory(name: name, color: color, icon: icon)
                    }
                )
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTitleFocused = true
                }
            }
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
    
    private func createNewCategory(name: String, color: Color, icon: String) {
        let colorHex = color.toHex()
        let result = scheduleManager.createCategory(
            name: name,
            icon: icon,
            colorHex: colorHex
        )
        if case .success(let category) = result {
            selectedCategory = category
        }
    }
}

// MARK: - Supporting Views



struct CreateCategorySheet: View {
    @Binding var isPresented: Bool
    let onSave: (String, Color, String) -> Void
    
    @State private var categoryName = ""
    @State private var selectedColor = Color.blue
    @State private var selectedIcon = "folder.fill"
    
    let colors: [Color] = [
        .blue, .purple, .pink, .red, .orange, 
        .yellow, .green, .mint, .teal, .cyan,
        .indigo, .brown, .gray
    ]
    
    let icons = [
        "folder.fill", "star.fill", "flag.fill", "bookmark.fill",
        "tag.fill", "briefcase.fill", "house.fill", "graduationcap.fill",
        "heart.fill", "bolt.fill", "flame.fill", "leaf.fill"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Name")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter name", text: $categoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Color selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .opacity(selectedColor == color ? 1 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                }
                
                // Icon selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Icon")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(selectedIcon == icon ? selectedColor : .secondary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedIcon == icon ? selectedColor.opacity(0.1) : Color(UIColor.tertiarySystemFill))
                                )
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(categoryName, selectedColor, selectedIcon)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(categoryName.isEmpty)
                }
            }
        }
    }
}


#Preview {
    AddEventView()
        .environmentObject(ScheduleManager.shared)
}