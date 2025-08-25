//
//  ScreenTimeManager.swift
//  Momentum
//
//  Reads iOS Screen Time data and creates events for app usage
//

import Foundation
import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings
import CoreData

@MainActor
class ScreenTimeManager: NSObject, ObservableObject {
    static let shared = ScreenTimeManager()
    
    @Published var isAuthorized = false
    @Published var isMonitoring = false
    @Published var todayUsage: [AppUsage] = []
    
    @AppStorage("screenTimeTrackingEnabled") private var trackingEnabled = false
    @AppStorage("screenTimeMinThreshold") private var minThresholdMinutes = 10
    
    private let center = AuthorizationCenter.shared
    private let deviceActivityCenter = DeviceActivityCenter()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.rubenreut.momentum")
    private var updateTimer: Timer?
    private var notificationObserver: NSObjectProtocol?
    
    struct AppUsage: Identifiable {
        let id = UUID()
        let appName: String
        let bundleIdentifier: String
        let duration: TimeInterval
        let startTime: Date
        let endTime: Date
    }
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
        setupNotificationObserver()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupNotificationObserver() {
        // Listen for notifications from the Device Activity extension
        let notificationName = "com.momentum.deviceactivity.threshold" as CFString
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, name, _, _ in
                // Handle notification from extension
                AsyncTask { @MainActor in
                    await ScreenTimeManager.shared.handleDeviceActivityNotification()
                }
            },
            notificationName,
            nil,
            .deliverImmediately
        )
    }
    
    private func handleDeviceActivityNotification() async {
        print("🔔 Screen Time: Received notification from Device Activity extension")
        await fetchScreenTimeData()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            try await center.requestAuthorization(for: .individual)
            await MainActor.run {
                self.isAuthorized = center.authorizationStatus == .approved
            }
            
            if isAuthorized {
                await startMonitoring()
            }
            
            return isAuthorized
        } catch {
            print("Failed to request Screen Time authorization: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        isAuthorized = center.authorizationStatus == .approved
        print("🔐 Screen Time Authorization Status: \(isAuthorized ? "Approved" : "Not Approved")")
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() async {
        guard isAuthorized, trackingEnabled else { return }
        
        isMonitoring = true
        
        // Set up a schedule to monitor all day
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        // Create events with thresholds (e.g., every 15 minutes of usage)
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            DeviceActivityEvent.Name("15min"): DeviceActivityEvent(
                applications: Set(), // Empty = monitor all apps
                categories: Set(),   // Empty = monitor all categories  
                webDomains: Set(),   // Empty = monitor all web domains
                threshold: DateComponents(minute: 15)
            ),
            DeviceActivityEvent.Name("30min"): DeviceActivityEvent(
                applications: Set(),
                categories: Set(),
                webDomains: Set(),
                threshold: DateComponents(minute: 30)
            ),
            DeviceActivityEvent.Name("1hour"): DeviceActivityEvent(
                applications: Set(),
                categories: Set(),
                webDomains: Set(),
                threshold: DateComponents(hour: 1)
            )
        ]
        
        let activityName = DeviceActivityName("dailyUsage")
        
        do {
            // Start monitoring with threshold events
            try deviceActivityCenter.startMonitoring(
                activityName,
                during: schedule,
                events: events
            )
            
            print("✅ Screen Time: Started monitoring with thresholds at 15min, 30min, 1hr")
            
            // Start checking for threshold events
            startPeriodicDataFetch()
            
        } catch {
            print("❌ Screen Time: Failed to start monitoring: \(error)")
            isMonitoring = false
        }
    }
    
    func stopMonitoring() {
        let activityName = DeviceActivityName("com.momentum.screentime")
        deviceActivityCenter.stopMonitoring([activityName])
        isMonitoring = false
        updateTimer?.invalidate()
    }
    
    // MARK: - Data Fetching
    
    private func startPeriodicDataFetch() {
        print("⏰ Screen Time: Starting periodic data fetch...")
        
        // Check every 30 minutes for new screen time data
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            AsyncTask { @MainActor in
                print("⏰ Screen Time: Periodic fetch triggered")
                await self?.fetchScreenTimeData()
            }
        }
        
        // Fetch immediately
        AsyncTask {
            print("🚀 Screen Time: Initial fetch triggered")
            await fetchScreenTimeData()
        }
    }
    
    private func fetchScreenTimeData() async {
        guard isAuthorized else {
            print("🔴 Screen Time: Not authorized")
            return
        }
        
        print("🟢 Screen Time: Checking for threshold events...")
        
        // Check for events from the Device Activity Monitor extension
        if let events = sharedDefaults?.array(forKey: "screenTimeEvents") as? [[String: Any]] {
            print("📱 Found \(events.count) threshold events")
            
            for eventData in events {
                if let eventName = eventData["eventName"] as? String,
                   let timestamp = eventData["timestamp"] as? TimeInterval {
                    
                    let eventDate = Date(timeIntervalSince1970: timestamp)
                    
                    // Create calendar event based on threshold
                    createEventFromThreshold(eventName: eventName, timestamp: eventDate)
                }
            }
            
            // Clear processed events
            sharedDefaults?.removeObject(forKey: "screenTimeEvents")
            sharedDefaults?.synchronize()
        }
    }
    
    private func createEventFromThreshold(eventName: String, timestamp: Date) {
        print("🎯 Threshold '\(eventName)' reached at \(timestamp)")
        
        // Parse the threshold type
        let duration: TimeInterval
        let title: String
        
        switch eventName {
        case "15min":
            duration = 15 * 60
            title = "📱 Screen Time: 15 min"
        case "30min":
            duration = 30 * 60
            title = "📱 Screen Time: 30 min"
        case "1hour":
            duration = 60 * 60
            title = "📱 Screen Time: 1 hour"
        default:
            duration = 15 * 60
            title = "📱 Screen Time Activity"
        }
        
        // Calculate start time (threshold reached time minus duration)
        let startTime = timestamp.addingTimeInterval(-duration)
        
        // Create the event
        createScreenTimeEvent(
            appName: "App Usage",
            bundleId: "screentime.threshold",
            startTime: startTime,
            duration: duration
        )
    }
    
    
    
    // MARK: - Event Creation
    
    private func createScreenTimeEvent(appName: String, bundleId: String, startTime: Date, duration: TimeInterval) {
        print("📝 Screen Time: Creating event for \(appName)...")
        
        let scheduleManager = ScheduleManager.shared
        
        // Format duration
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        let durationText: String
        if hours > 0 {
            durationText = "\(hours)h \(remainingMinutes)m"
        } else {
            durationText = "\(minutes) minutes"
        }
        
        print("⏱️ Screen Time: \(appName) used for \(durationText)")
        
        // Create event title with app name
        let eventTitle = "📱 \(appName)"
        let eventNotes = """
        Screen time session
        App: \(appName)
        Duration: \(durationText)
        Bundle: \(bundleId)
        
        Data from iOS Screen Time
        """
        
        let endTime = startTime.addingTimeInterval(duration)
        
        // Find or create Screen Time category
        let category = findOrCreateScreenTimeCategory()
        
        // Check if event already exists to avoid duplicates
        if !eventExists(appName: appName, startTime: startTime) {
            let result = scheduleManager.createEvent(
                title: eventTitle,
                startTime: startTime,
                endTime: endTime,
                category: category,
                notes: eventNotes,
                location: nil,
                isAllDay: false
            )
            
            switch result {
            case .success:
                print("✅ Screen Time: Created event for \(appName) at \(startTime)")
                
                // Add to today's usage
                let usage = AppUsage(
                    appName: appName,
                    bundleIdentifier: bundleId,
                    duration: duration,
                    startTime: startTime,
                    endTime: endTime
                )
                todayUsage.append(usage)
            case .failure(let error):
                print("❌ Screen Time: Failed to create event for \(appName): \(error)")
            }
        } else {
            print("⏭️ Screen Time: Event already exists for \(appName) at \(startTime)")
        }
    }
    
    private func eventExists(appName: String, startTime: Date) -> Bool {
        // Check if we already created an event for this app at this time
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        
        // Look for events with same title and start time
        let calendar = Calendar.current
        let startOfMinute = calendar.dateInterval(of: .minute, for: startTime)?.start ?? startTime
        let endOfMinute = calendar.dateInterval(of: .minute, for: startTime)?.end ?? startTime
        
        request.predicate = NSPredicate(
            format: "title CONTAINS[c] %@ AND startTime >= %@ AND startTime <= %@",
            appName,
            startOfMinute as NSDate,
            endOfMinute as NSDate
        )
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }
    
    private func findOrCreateScreenTimeCategory() -> Category? {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", "Screen Time")
        
        do {
            let categories = try context.fetch(request)
            if let category = categories.first {
                return category
            }
            
            // Create new category
            let category = Category(context: context)
            category.id = UUID()
            category.name = "Screen Time"
            category.iconName = "iphone"
            category.colorHex = "#5856D6" // Purple
            category.sortOrder = 99
            category.isActive = true
            category.createdAt = Date()
            
            try context.save()
            return category
            
        } catch {
            print("Error with Screen Time category: \(error)")
            return nil
        }
    }
    
    // MARK: - Public Methods
    
    func toggleTracking() async {
        if trackingEnabled {
            trackingEnabled = false
            stopMonitoring()
        } else {
            trackingEnabled = true
            if !isAuthorized {
                _ = await requestAuthorization()
            } else {
                await startMonitoring()
            }
        }
    }
    
    func setMinimumThreshold(minutes: Int) {
        minThresholdMinutes = minutes
    }
    
    func refreshData() async {
        await fetchScreenTimeData()
    }
}

// MARK: - Mock DeviceActivity Event

// Mock structure for testing until DeviceActivityReport is properly set up
struct MockDeviceActivityEvent {
    let applicationName: String?
    let bundleIdentifier: String?
    let startDate: Date
    let duration: TimeInterval
}

// MARK: - DeviceActivityReport Context
extension DeviceActivityReport.Context {
    static let totalActivity = Self("totalActivity")
    static let apps = Self("apps")
}

// Note: The actual implementation requires:
// 1. DeviceActivityReport extension target (MomentumDeviceActivity)
// 2. Proper entitlements for Family Controls
// 3. App Groups for sharing data between main app and extension
// 
// Setup instructions:
// 1. Add MomentumDeviceActivity target to Xcode project
// 2. Enable App Groups capability for both targets
// 3. Add Family Controls capability
// 4. Configure entitlements properly
// 
// For more info: https://developer.apple.com/documentation/deviceactivity