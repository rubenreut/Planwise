//
//  MomentumApp.swift
//  Momentum
//
//  Created by Ruben Reut on 29/06/2025.
//

import SwiftUI

@main
struct MomentumApp: App {
    @StateObject private var dependencyContainer = DependencyContainer.shared
    @AppStorage("crashReportingEnabled") private var crashReportingEnabled = true
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true
    
    init() {
        // TODO: Configure Firebase when available
        // FirebaseApp.configure()
        
        // Configure crash reporting based on user preference
        CrashReporter.shared.configure(
            enabled: UserDefaults.standard.object(forKey: "crashReportingEnabled") as? Bool ?? true,
            userIdentifier: generateAnonymousUserID()
        )
        
        // TODO: Configure analytics when Firebase is available
        // Analytics.setAnalyticsCollectionEnabled(
        //     UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? true
        // )
        
        // Log app launch
        CrashReporter.shared.addBreadcrumb(
            message: "App launched",
            category: "lifecycle",
            level: .info,
            data: [
                "launch_time": Date().timeIntervalSince1970,
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            ]
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dependencyContainer.persistenceProvider.container.viewContext)
                .environmentObject(dependencyContainer.scheduleManager as! ScheduleManager)
                .environmentObject(dependencyContainer.scrollPositionManager as! ScrollPositionManager)
                .injectDependencies(dependencyContainer)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Log app termination
                    CrashReporter.shared.addBreadcrumb(
                        message: "App will terminate",
                        category: "lifecycle",
                        level: .info
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Log app entering background
                    CrashReporter.shared.addBreadcrumb(
                        message: "App entered background",
                        category: "lifecycle",
                        level: .info
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Log app entering foreground
                    CrashReporter.shared.addBreadcrumb(
                        message: "App entered foreground",
                        category: "lifecycle",
                        level: .info
                    )
                }
                .onChange(of: crashReportingEnabled) { newValue in
                    // Update crash reporting preference
                    CrashReporter.shared.configure(
                        enabled: newValue,
                        userIdentifier: newValue ? generateAnonymousUserID() : nil
                    )
                }
                .onChange(of: analyticsEnabled) { newValue in
                    // TODO: Update analytics preference when Firebase is available
                    // Analytics.setAnalyticsCollectionEnabled(newValue)
                }
        }
    }
    
    /// Generate an anonymous user ID for crash reporting
    /// This ID is not tied to any personal information
    private func generateAnonymousUserID() -> String {
        if let existingID = UserDefaults.standard.string(forKey: "anonymousUserID") {
            return existingID
        }
        
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: "anonymousUserID")
        return newID
    }
}