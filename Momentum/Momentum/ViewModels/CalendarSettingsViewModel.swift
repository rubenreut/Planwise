import SwiftUI

/// Manages calendar and scheduling settings
@MainActor
class CalendarSettingsViewModel: ObservableObject {
    // MARK: - Calendar Settings
    @AppStorage("firstDayOfWeek") var firstDayOfWeek = 1 // Sunday = 1
    @AppStorage("showWeekNumbers") var showWeekNumbers = false
    @AppStorage("defaultEventDuration") var defaultEventDuration = 60
    @AppStorage("workingHoursStart") var workingHoursStart = 9
    @AppStorage("workingHoursEnd") var workingHoursEnd = 17
    
    // MARK: - Published Properties
    @Published var showingCalendarIntegration = false
    
    // MARK: - Constants
    let weekdays = [
        1: "Sunday",
        2: "Monday",
        3: "Tuesday",
        4: "Wednesday",
        5: "Thursday",
        6: "Friday",
        7: "Saturday"
    ]
    
    let durationOptions = [
        15: "15 minutes",
        30: "30 minutes",
        45: "45 minutes",
        60: "1 hour",
        90: "1.5 hours",
        120: "2 hours",
        180: "3 hours",
        240: "4 hours"
    ]
    
    // MARK: - Methods
    
    func weekdayName(_ day: Int) -> String {
        weekdays[day] ?? "Unknown"
    }
    
    func formatHour(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    func updateCalendarSettings() {
        // Post notification for calendar view updates
        NotificationCenter.default.post(
            name: Notification.Name("CalendarSettingsChanged"),
            object: nil
        )
    }
    
    var workingHoursRange: String {
        "\(formatHour(workingHoursStart)) - \(formatHour(workingHoursEnd))"
    }
    
    var formattedEventDuration: String {
        durationOptions[defaultEventDuration] ?? "\(defaultEventDuration) minutes"
    }
}