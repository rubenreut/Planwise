//
//  MomentumApp.swift
//  Momentum
//
//  Created by Ruben Reut on 29/06/2025.
//

import SwiftUI
import WidgetKit

@main
struct MomentumApp: App {
    @StateObject private var dependencyContainer = DependencyContainer.shared
    @AppStorage("crashReportingEnabled") private var crashReportingEnabled = true
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    
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
        
        // Setup notification categories
        NotificationManager.shared.setupNotificationCategories()
        
        // Setup API key in Keychain
        KeychainService.shared.setupAPIKeyIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dependencyContainer.persistenceProvider.container.viewContext)
                .environmentObject(dependencyContainer.scheduleManager as! ScheduleManager)
                .environmentObject(dependencyContainer.scrollPositionManager as! ScrollPositionManager)
                .environmentObject(dependencyContainer.taskManager as! TaskManager)
                .environmentObject(dependencyContainer.habitManager as! HabitManager)
                .environmentObject(GoalManager.shared)
                .injectDependencies(dependencyContainer)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingViewPremium(showOnboarding: $showOnboarding)
                        .environmentObject(dependencyContainer.scheduleManager as! ScheduleManager)
                }
                .onAppear {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                    // Force widget refresh
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
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
    
    /// Handle deep links from widgets
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "momentum" else { return }
        
        switch url.host {
        case "add-task":
            NotificationCenter.default.post(name: .showAddTask, object: nil)
        case "add-event":
            NotificationCenter.default.post(name: .showAddEvent, object: nil)
        case "add-habit":
            NotificationCenter.default.post(name: .showAddHabit, object: nil)
        case "add-note":
            NotificationCenter.default.post(name: .showAddNote, object: nil)
        case "quick-add":
            NotificationCenter.default.post(name: .showQuickAdd, object: nil)
        case "quick-capture":
            NotificationCenter.default.post(name: .showQuickCapture, object: nil)
        case "habits":
            NotificationCenter.default.post(name: .navigateToHabits, object: nil)
        case "schedule":
            NotificationCenter.default.post(name: .navigateToSchedule, object: nil)
        default:
            break
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let showAddTask = Notification.Name("showAddTask")
    static let showAddEvent = Notification.Name("showAddEvent")
    static let showAddHabit = Notification.Name("showAddHabit")
    static let showAddNote = Notification.Name("showAddNote")
    static let showQuickAdd = Notification.Name("showQuickAdd")
    static let showQuickCapture = Notification.Name("showQuickCapture")
    static let navigateToHabits = Notification.Name("navigateToHabits")
    static let navigateToSchedule = Notification.Name("navigateToSchedule")
}