//
//  DeviceActivityMonitor.swift
//  MomentumDeviceActivity
//
//  Monitors device activity events and creates events when thresholds are crossed
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

// Device Activity Monitor Extension - this runs in the background
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let userDefaults = UserDefaults(suiteName: "group.com.rubenreut.momentum")
    
    // Called when an app/category reaches the threshold (e.g., 15 minutes of usage)
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        print("📱 Threshold reached for event: \(event.rawValue)")
        
        // Get current timestamp
        let now = Date()
        
        // Create event data to share with main app
        let eventData: [String: Any] = [
            "eventName": event.rawValue,
            "activityName": activity.rawValue,
            "timestamp": now.timeIntervalSince1970,
            "thresholdReached": true
        ]
        
        // Store in shared UserDefaults for main app to process
        var events = userDefaults?.array(forKey: "screenTimeEvents") as? [[String: Any]] ?? []
        events.append(eventData)
        
        // Keep only last 100 events
        if events.count > 100 {
            events = Array(events.suffix(100))
        }
        
        userDefaults?.set(events, forKey: "screenTimeEvents")
        userDefaults?.synchronize()
        
        print("✅ Stored threshold event for main app to process")
        
        // Notify main app if it's running
        notifyMainApp()
    }
    
    // Called when monitoring interval starts
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        print("⏰ Monitoring interval started for: \(activity.rawValue)")
        
        userDefaults?.set(Date().timeIntervalSince1970, forKey: "lastIntervalStart")
        userDefaults?.synchronize()
    }
    
    // Called when monitoring interval ends
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        print("⏹️ Monitoring interval ended for: \(activity.rawValue)")
        
        // Store interval end time
        userDefaults?.set(Date().timeIntervalSince1970, forKey: "lastIntervalEnd")
        userDefaults?.synchronize()
    }
    
    // Warning before threshold is reached (optional)
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        
        print("⚠️ Warning: Approaching threshold for: \(event.rawValue)")
    }
    
    // MARK: - Helper Methods
    
    private func notifyMainApp() {
        // Use Darwin notification to notify main app
        let notificationName = "com.momentum.screentime.threshold" as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName),
            nil,
            nil,
            true
        )
    }
}