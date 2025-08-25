//
//  ScreenTimeDataReader.swift
//  Momentum
//
//  Attempts to read Screen Time data using available APIs
//

import Foundation
import UIKit
import CoreData
import SQLite3

@MainActor
class ScreenTimeDataReader: ObservableObject {
    static let shared = ScreenTimeDataReader()
    
    @Published var screenTimeData: [AppUsageData] = []
    
    struct AppUsageData {
        let appName: String
        let bundleID: String
        let duration: TimeInterval
        let lastUsed: Date
    }
    
    private init() {}
    
    // MARK: - Method 1: Try to read from Screen Time database directly
    func attemptDirectDatabaseRead() {
        print("🔍 Attempting to read Screen Time database...")
        
        // Possible locations of Screen Time database
        let possiblePaths = [
            "/private/var/mobile/Library/CoreDuet/Knowledge/knowledgeC.db",
            "/var/mobile/Library/CoreDuet/Knowledge/knowledgeC.db",
            "~/Library/Application Support/Knowledge/knowledgeC.db",
            "/System/Library/PrivateFrameworks/CoreDuet.framework/knowledgeC.db"
        ]
        
        for path in possiblePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            print("📂 Checking: \(expandedPath)")
            
            if FileManager.default.fileExists(atPath: expandedPath) {
                print("✅ Found database at: \(expandedPath)")
                readKnowledgeDatabase(at: expandedPath)
            }
        }
    }
    
    private func readKnowledgeDatabase(at path: String) {
        var db: OpaquePointer?
        
        // Try to open the database in read-only mode
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
            print("📖 Opened database successfully")
            
            // Query for app usage data
            let query = """
                SELECT 
                    ZOBJECT.ZVALUESTRING AS bundleID,
                    ZOBJECT.ZSTARTDATE AS startDate,
                    ZOBJECT.ZENDDATE AS endDate
                FROM ZOBJECT
                WHERE ZOBJECT.ZSTREAMNAME = '/app/usage'
                ORDER BY ZOBJECT.ZSTARTDATE DESC
                LIMIT 100
            """
            
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let bundleID = sqlite3_column_text(statement, 0) {
                        let bundle = String(cString: bundleID)
                        print("📱 Found app usage: \(bundle)")
                    }
                }
            }
            sqlite3_finalize(statement)
        } else {
            print("❌ Could not open database")
        }
        
        sqlite3_close(db)
    }
    
    // MARK: - Method 2: Use CoreSpotlight usage data
    func readFromCoreSpotlight() {
        print("🔍 Checking CoreSpotlight for usage patterns...")
        
        // CoreSpotlight might have app usage patterns
        // This is a more limited approach but might give some data
        
        let userDefaults = UserDefaults.standard
        let recentApps = userDefaults.array(forKey: "com.apple.RecentApplications") as? [String] ?? []
        
        print("📱 Recent apps from UserDefaults: \(recentApps)")
    }
    
    // MARK: - Method 3: Read from system logs
    func readFromSystemLogs() {
        print("🔍 Attempting to read system logs...")
        
        // Try to read from unified logging system
        let logPath = "/var/mobile/Library/Logs/CrashReporter/DiagnosticLogs/Analytics"
        
        if FileManager.default.fileExists(atPath: logPath) {
            print("📁 Found analytics logs")
            
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: logPath)
                for file in files where file.contains("Analytics") {
                    print("📄 Log file: \(file)")
                    // Parse log files for app usage data
                }
            } catch {
                print("❌ Error reading logs: \(error)")
            }
        }
    }
    
    // MARK: - Method 4: Use app launch notifications
    func monitorAppLaunches() {
        print("🔍 Setting up app launch monitoring...")
        
        // Monitor when apps become active/inactive
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        print("📱 App became active at: \(Date())")
        // Track app usage manually
    }
    
    @objc private func appWillResignActive() {
        print("📱 App resigned active at: \(Date())")
        // Calculate duration and store
    }
    
    // MARK: - Main function to try all methods
    func fetchScreenTimeData() {
        print("🚀 Starting Screen Time data fetch attempts...")
        
        // Try all methods
        attemptDirectDatabaseRead()
        readFromCoreSpotlight()
        readFromSystemLogs()
        monitorAppLaunches()
        
        // Check if we can access usage statistics
        checkUsageStatistics()
    }
    
    private func checkUsageStatistics() {
        print("🔍 Checking for usage statistics...")
        
        // Try to access battery usage data (which includes app usage)
        let batteryUsagePath = "/var/mobile/Library/BatteryLife/CurrentPowerlog.PLSQL"
        
        if FileManager.default.fileExists(atPath: batteryUsagePath) {
            print("🔋 Found battery usage database")
            // This might contain app usage data
        }
        
        // Check for DataUsage.sqlite which tracks network usage per app
        let dataUsagePath = "/var/mobile/Library/UserNotificationServices/DataUsage.sqlite"
        
        if FileManager.default.fileExists(atPath: dataUsagePath) {
            print("📊 Found data usage database")
        }
    }
}