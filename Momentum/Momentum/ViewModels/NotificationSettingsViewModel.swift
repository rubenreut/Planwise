import SwiftUI
import UserNotifications

/// Manages notification-related settings
@MainActor
class NotificationSettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var showingNotificationSettings = false
    @Published var defaultReminderMinutes: Int = 10
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    // MARK: - Dependencies
    let notificationManager = NotificationManager.shared
    
    // MARK: - Reminder Options
    let reminderOptions = [
        0: "At time of event",
        5: "5 minutes before",
        10: "10 minutes before",
        15: "15 minutes before",
        30: "30 minutes before",
        60: "1 hour before",
        120: "2 hours before",
        1440: "1 day before"
    ]
    
    init() {
        checkNotificationStatus()
        loadDefaultReminderTime()
    }
    
    // MARK: - Methods
    
    func checkNotificationStatus() {
        _Concurrency.Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            await MainActor.run {
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestNotificationPermission() {
        _Concurrency.Task {
            do {
                try await notificationManager.requestAuthorization()
                await checkNotificationStatus()
            } catch {
                print("Failed to request notification permission: \(error)")
            }
        }
    }
    
    func openSystemNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func testNotification() {
        _Concurrency.Task {
            let content = UNMutableNotificationContent()
            content.title = "Test Notification"
            content.body = "This is a test notification from Momentum"
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
            
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
    
    func updateDefaultReminderTime() {
        UserDefaults.standard.set(defaultReminderMinutes, forKey: "defaultReminderMinutes")
        NotificationCenter.default.post(
            name: Notification.Name("DefaultReminderTimeChanged"),
            object: nil,
            userInfo: ["minutes": defaultReminderMinutes]
        )
    }
    
    private func loadDefaultReminderTime() {
        defaultReminderMinutes = UserDefaults.standard.integer(forKey: "defaultReminderMinutes")
        if defaultReminderMinutes == 0 && !UserDefaults.standard.bool(forKey: "defaultReminderTimeSet") {
            defaultReminderMinutes = 10
            UserDefaults.standard.set(true, forKey: "defaultReminderTimeSet")
        }
    }
    
    var notificationStatusText: String {
        switch notificationStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Disabled"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }
    
    var notificationStatusColor: Color {
        switch notificationStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        default:
            return .orange
        }
    }
}