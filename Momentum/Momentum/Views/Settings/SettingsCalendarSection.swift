import SwiftUI

struct SettingsCalendarSection: View {
    @ObservedObject var calendarVM: CalendarSettingsViewModel
    @ObservedObject var appearanceVM: AppearanceSettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "calendar",
                title: "First Day of Week",
                value: calendarVM.weekdayName(calendarVM.firstDayOfWeek),
                showChevron: true,
                action: {
                    // TODO: Show picker
                }
            )
            
            Divider().padding(.leading, 44)
            
            SettingsRow(
                icon: "clock",
                title: "Default Duration",
                value: calendarVM.formattedEventDuration,
                showChevron: true,
                action: {
                    // TODO: Show picker
                }
            )
            
            Divider().padding(.leading, 44)
            
            SettingsRow(
                icon: "briefcase",
                title: "Working Hours",
                value: calendarVM.workingHoursRange,
                showChevron: true,
                action: {
                    // TODO: Show picker
                }
            )
            
            Divider().padding(.leading, 44)
            
            Toggle(isOn: $calendarVM.showWeekNumbers) {
                HStack {
                    Image(systemName: "number.square")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .frame(width: 28, height: 28)
                        .padding(.trailing, 8)
                    
                    Text("Show Week Numbers")
                        .font(.body)
                }
            }
            .tint(Color.fromAccentString(appearanceVM.selectedAccentColor))
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}