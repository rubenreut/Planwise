import SwiftUI

struct SettingsNotificationSection: View {
    @ObservedObject var viewModel: NotificationSettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "bell",
                title: "Notifications",
                value: viewModel.notificationStatusText,
                valueColor: viewModel.notificationStatusColor,
                showChevron: true,
                action: {
                    viewModel.openSystemNotificationSettings()
                }
            )
            
            Divider().padding(.leading, 44)
            
            SettingsRow(
                icon: "clock",
                title: "Default Reminder",
                value: viewModel.reminderOptions[viewModel.defaultReminderMinutes] ?? "10 minutes before",
                showChevron: true,
                action: {
                    viewModel.showingNotificationSettings = true
                }
            )
        }
    }
}