import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @State private var showingCategoryManagement = false
    @AppStorage("crashReportingEnabled") private var crashReportingEnabled = true
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true
    
    var body: some View {
        NavigationView {
            List {
                // Categories Section
                Section("Organization") {
                    Button(action: {
                        showingCategoryManagement = true
                    }) {
                        HStack {
                            Label("Categories", systemImage: "folder.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(scheduleManager.categories.count)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
                
                // Appearance Section
                Section("Appearance") {
                    HStack {
                        Label("Theme", systemImage: "paintbrush.fill")
                        Spacer()
                        Text("System")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("App Icon", systemImage: "app.fill")
                        Spacer()
                        Text("Default")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Calendar Section
                Section("Calendar") {
                    HStack {
                        Label("First Day of Week", systemImage: "calendar")
                        Spacer()
                        Text("Monday")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Time Format", systemImage: "clock.fill")
                        Spacer()
                        Text("24-hour")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    Toggle(isOn: .constant(true)) {
                        Label("Enable Notifications", systemImage: "bell.fill")
                    }
                    
                    HStack {
                        Label("Default Reminder", systemImage: "alarm.fill")
                        Spacer()
                        Text("10 min before")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Privacy Section
                Section("Privacy") {
                    Toggle(isOn: $crashReportingEnabled) {
                        VStack(alignment: .leading) {
                            Label("Crash Reporting", systemImage: "exclamationmark.triangle.fill")
                            Text("Help improve the app by sending crash reports")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: crashReportingEnabled) { newValue in
                        CrashReporter.shared.addBreadcrumb(
                            message: "Crash reporting \(newValue ? "enabled" : "disabled")",
                            category: "settings",
                            level: .info
                        )
                    }
                    
                    Toggle(isOn: $analyticsEnabled) {
                        VStack(alignment: .leading) {
                            Label("Analytics", systemImage: "chart.bar.fill")
                            Text("Share anonymous usage data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: analyticsEnabled) { newValue in
                        CrashReporter.shared.addBreadcrumb(
                            message: "Analytics \(newValue ? "enabled" : "disabled")",
                            category: "settings",
                            level: .info
                        )
                    }
                    
                    Button(action: {
                        CrashReporter.shared.clearUserData()
                        CrashReporter.shared.logUserAction("clear_data", target: "privacy_settings")
                    }) {
                        Label("Clear All Data", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle.fill")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        // Add feedback action
                        CrashReporter.shared.logUserAction("send_feedback", target: "settings")
                    }) {
                        Label("Send Feedback", systemImage: "envelope.fill")
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        // Add rate action
                        CrashReporter.shared.logUserAction("rate_app", target: "settings")
                    }) {
                        Label("Rate Momentum", systemImage: "star.fill")
                            .foregroundColor(.primary)
                    }
                    
                    #if DEBUG
                    Button(action: {
                        CrashReporter.shared.testCrash()
                    }) {
                        Label("Test Crash (Debug)", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    #endif
                }
            }
            .navigationTitle("Settings")
            .listStyle(InsetGroupedListStyle())
            .sheet(isPresented: $showingCategoryManagement) {
                CategoryManagementView()
                    .environmentObject(scheduleManager)
            }
            .trackViewAppearance("SettingsView")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ScheduleManager.shared)
}