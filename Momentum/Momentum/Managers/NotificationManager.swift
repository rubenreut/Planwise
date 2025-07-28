import Foundation
import UserNotifications
import CoreData

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var notificationSettings: UNNotificationSettings?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isAuthorized = granted
            }
            if granted {
                await scheduleAllEventNotifications()
            }
            return granted
        } catch {
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationSettings = settings
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Scheduling Notifications
    
    func scheduleNotification(for event: Event) async {
        
        guard isAuthorized else {
            return
        }
        
        guard let eventId = event.id,
              let startTime = event.startTime,
              let title = event.title else {
            return
        }
        
        // Remove existing notifications for this event
        await cancelNotifications(for: eventId)
        
        // Get reminder preferences - for now just use defaults
        // TODO: Add reminderMinutes to Event entity if we want per-event customization
        var reminderMinutes = getDefaultReminderMinutes()
        
        // Fallback to ensure we have at least one reminder
        if reminderMinutes.isEmpty {
            reminderMinutes = [10]
        }
        
        
        
        for minutes in reminderMinutes {
            guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -minutes, to: startTime) else {
                continue
            }
            
            // Don't schedule notifications in the past
            if triggerDate < Date() {
                continue
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            
            // Add subtitle with time
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            content.subtitle = "at \(timeFormatter.string(from: startTime))"
            
            // Add body with location if available
            if let location = event.location {
                content.body = "📍 \(location)"
            } else if let notes = event.notes?.prefix(100) {
                content.body = String(notes)
            }
            
            // Add category
            content.categoryIdentifier = "EVENT_REMINDER"
            
            // Add sound
            content.sound = .default
            
            // Add user info
            content.userInfo = [
                "eventId": eventId.uuidString,
                "eventTitle": title,
                "startTime": startTime.timeIntervalSince1970
            ]
            
            // Create trigger
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // Create unique identifier
            let identifier = "\(eventId.uuidString)_\(minutes)min"
            
            // Create request
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            do {
                try await notificationCenter.add(request)
            } catch {
            }
        }
    }
    
    func scheduleAllEventNotifications() async {
        // Get all future events
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "startTime > %@", Date() as NSDate)
        
        do {
            let context = PersistenceController.shared.container.viewContext
            let events = try context.fetch(fetchRequest)
            
            for event in events {
                await scheduleNotification(for: event)
            }
            
        } catch {
        }
    }
    
    func cancelNotifications(for eventId: UUID) async {
        // Cancel all notifications for this event (could have multiple for different reminder times)
        let identifierPrefix = eventId.uuidString
        let pendingNotifications = await notificationCenter.pendingNotificationRequests()
        
        let identifiersToRemove = pendingNotifications
            .map { $0.identifier }
            .filter { $0.hasPrefix(identifierPrefix) }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
    }
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Settings
    
    func getDefaultReminderMinutes() -> [Int] {
        // Get from UserDefaults or return default
        if let saved = UserDefaults.standard.array(forKey: "defaultReminderMinutes") as? [Int], !saved.isEmpty {
            return saved
        }
        
        // Check if we have a single integer saved (for backwards compatibility)
        let singleValue = UserDefaults.standard.integer(forKey: "defaultReminderMinutes")
        if singleValue > 0 {
            return [singleValue]
        }
        
        return [10] // Default 10 minutes before
    }
    
    func setDefaultReminderMinutes(_ minutes: [Int]) {
        UserDefaults.standard.set(minutes, forKey: "defaultReminderMinutes")
        UserDefaults.standard.synchronize() // Force save
    }
    
    // MARK: - Notification Actions
    
    func setupNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze 5 min",
            options: []
        )
        
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Complete",
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [snoozeAction, completeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        notificationCenter.setNotificationCategories([category])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner even when app is open
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              didReceive response: UNNotificationResponse, 
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "SNOOZE_ACTION":
            handleSnoozeAction(userInfo: userInfo)
        case "COMPLETE_ACTION":
            handleCompleteAction(userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            // User tapped on notification
            handleNotificationTap(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleSnoozeAction(userInfo: [AnyHashable: Any]) {
        guard let eventIdString = userInfo["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdString),
              let eventTitle = userInfo["eventTitle"] as? String else { return }
        
        // Schedule new notification for 5 minutes from now
        AsyncTask {
            let content = UNMutableNotificationContent()
            content.title = eventTitle
            content.subtitle = "Snoozed reminder"
            content.sound = .default
            content.categoryIdentifier = "EVENT_REMINDER"
            content.userInfo = userInfo
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false) // 5 minutes
            let request = UNNotificationRequest(
                identifier: "\(eventIdString)_snooze_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            try? await notificationCenter.add(request)
        }
    }
    
    private func handleCompleteAction(userInfo: [AnyHashable: Any]) {
        guard let eventIdString = userInfo["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdString) else { return }
        
        // Mark event as completed
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", eventId as CVarArg)
        
        if let event = try? context.fetch(fetchRequest).first {
            event.isCompleted = true
            event.completedAt = Date()
            try? context.save()
        }
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // Post notification to navigate to event
        if let eventIdString = userInfo["eventId"] as? String {
            NotificationCenter.default.post(
                name: .navigateToEvent,
                object: nil,
                userInfo: ["eventId": eventIdString]
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToEvent = Notification.Name("navigateToEvent")
}

// MARK: - Event Extension for Reminders

extension Event {
    var reminderMinutes: [Int]? {
        // TODO: Add reminderMinutes property to Core Data model
        // For now, return nil to use defaults
        return nil
    }
}