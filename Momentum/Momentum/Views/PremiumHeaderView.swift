import SwiftUI
import UIKit

struct PremiumHeaderView: View {
    let dateTitle: String
    let selectedDate: Date
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    let onToday: () -> Void
    let onSettings: () -> Void
    let onAddEvent: () -> Void
    let onDateSelected: ((Date) -> Void)?
    
    @Environment(\.colorScheme) var colorScheme
    @State private var currentTime = Date()
    @State private var showDatePicker = false
    @State private var tempSelectedDate: Date = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            // Previous day button
            Button(action: onPreviousDay) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous day")
            .accessibilityHint("Navigate to the previous day")
            
            Spacer()
            
            // Center date section - tappable
            Button(action: {
                tempSelectedDate = selectedDate
                showDatePicker = true
            }) {
                VStack(spacing: 2) {
                    Text(dateTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    if Calendar.current.isDateInToday(selectedDate) {
                        Text(timeString)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(dateTitle)\(Calendar.current.isDateInToday(selectedDate) ? ", current time \(timeString)" : "")")
            .accessibilityHint("Double tap to select a different date")
            .accessibilityAddTraits(.isButton)
            
            Spacer()
            
            // Next day button
            Button(action: onNextDay) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next day")
            .accessibilityHint("Navigate to the next day")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                DatePicker(
                    "Select Date",
                    selection: $tempSelectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            if let onDateSelected = onDateSelected {
                                onDateSelected(tempSelectedDate)
                            } else {
                                // Fallback to old behavior
                                let calendar = Calendar.current
                                let days = calendar.dateComponents([.day], from: selectedDate, to: tempSelectedDate).day ?? 0
                                
                                if days > 0 {
                                    for _ in 0..<days {
                                        onNextDay()
                                    }
                                } else if days < 0 {
                                    for _ in 0..<abs(days) {
                                        onPreviousDay()
                                    }
                                }
                            }
                            
                            showDatePicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
    
}


#Preview {
    VStack {
        PremiumHeaderView(
            dateTitle: "Monday, June 29",
            selectedDate: Date(),
            onPreviousDay: {},
            onNextDay: {},
            onToday: {},
            onSettings: {},
            onAddEvent: {},
            onDateSelected: nil
        )
        
        Spacer()
    }
    .background(Color(UIColor.systemGroupedBackground))
}