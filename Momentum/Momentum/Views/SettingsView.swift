import SwiftUI
import StoreKit
import MessageUI
import CoreData
import UserNotifications
import LocalAuthentication
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingCategoryManagement = false
    @State private var showingCalendarIntegration = false
    @AppStorage("aiContextInfo") private var aiContextInfo = ""
    @State private var showingAIContext = false
    @State private var isRestoringPurchases = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingExportOptions = false
    @State private var exportFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingNotificationSettings = false
    @State private var defaultReminderMinutes: Int = 10
    @State private var showingDeleteConfirmation = false
    @State private var showingDataDeletedAlert = false
    @AppStorage("selectedTheme") private var selectedTheme = 0
    @Environment(\.colorScheme) var colorScheme
    
    // Profile Settings
    @AppStorage("userName") private var userName = "Momentum User"
    @AppStorage("userAvatar") private var userAvatar = "person.circle.fill"
    @State private var showingProfileEditor = false
    
    // Appearance Settings
    @AppStorage("appIcon") private var selectedAppIcon = "AppIcon"
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @AppStorage("customAccentColorHex") private var customAccentColorHex = ""
    @State private var showingColorPicker = false
    @State private var tempCustomColor = Color.blue
    @AppStorage("useSystemFont") private var useSystemFont = true
    @AppStorage("headerImageName") private var headerImageName = ""
    @AppStorage("headerImageRectX") private var headerImageRectX: Double = 0.0
    @AppStorage("headerImageRectY") private var headerImageRectY: Double = 0.0
    @AppStorage("headerImageRectWidth") private var headerImageRectWidth: Double = 0.0
    @AppStorage("headerImageRectHeight") private var headerImageRectHeight: Double = 0.0
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingFontSelector = false
    
    // Calendar Settings
    @AppStorage("firstDayOfWeek") private var firstDayOfWeek = 1 // Sunday = 1
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false
    @AppStorage("defaultEventDuration") private var defaultEventDuration = 60
    @AppStorage("workingHoursStart") private var workingHoursStart = 9
    @AppStorage("workingHoursEnd") private var workingHoursEnd = 17
    
    // Privacy Settings
    @AppStorage("useFaceID") private var useFaceID = false
    @AppStorage("hideNotificationContent") private var hideNotificationContent = false
    @AppStorage("enableAnalytics") private var enableAnalytics = true
    
    // Backup Settings
    @AppStorage("autoBackupEnabled") private var autoBackupEnabled = false
    @AppStorage("lastBackupDate") private var lastBackupTimestamp: Double = 0
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationView {
            ScrollView {
                Group {
                    if horizontalSizeClass == .regular {
                        // iPad/Mac Layout
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                            // Left Column
                            VStack(spacing: DesignSystem.Spacing.md + 4) {
                                profileHeader
                                    .frame(maxWidth: 400)
                                
                                VStack(spacing: DesignSystem.Spacing.lg) {
                                    // Personalization
                                    VStack(spacing: DesignSystem.Spacing.md) {
                                        SettingsSection(
                                            title: "Appearance",
                                            icon: "paintbrush.fill",
                                            color: .purple
                                        ) {
                                            appearanceSettings
                                        }
                                        
                                        SettingsSection(
                                            title: "Calendar & Scheduling",
                                            icon: "calendar",
                                            color: .red
                                        ) {
                                            calendarSettings
                                        }
                                    }
                                    
                                    // Features
                                    VStack(spacing: DesignSystem.Spacing.md) {
                                        SettingsSection(
                                            title: "Organization",
                                            icon: "folder.fill",
                                            color: .blue
                                        ) {
                                            organizationSettings
                                        }
                                        
                                        SettingsSection(
                                            title: "AI Assistant",
                                            icon: "brain",
                                            color: .indigo
                                        ) {
                                            aiSettings
                                        }
                                    }
                                }
                                .frame(maxWidth: 500)
                            }
                            
                            // Right Column
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                // Notifications & Privacy
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    SettingsSection(
                                        title: "Notifications",
                                        icon: "bell.fill",
                                        color: .orange
                                    ) {
                                        notificationSettings
                                    }
                                    
                                    SettingsSection(
                                        title: "Privacy & Security",
                                        icon: "lock.shield.fill",
                                        color: .mint
                                    ) {
                                        privacySettings
                                    }
                                }
                                
                                // Account & Data
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    SettingsSection(
                                        title: "Premium",
                                        icon: "crown.fill",
                                        color: .yellow
                                    ) {
                                        premiumSettings
                                    }
                                    
                                    SettingsSection(
                                        title: "Data Management",
                                        icon: "externaldrive.fill",
                                        color: .green
                                    ) {
                                        dataSettings
                                    }
                                }
                                
                                // About
                                SettingsSection(
                                    title: "About",
                                    icon: "info.circle.fill",
                                    color: .gray
                                ) {
                                    aboutSettings
                                }
                                
                                #if DEBUG
                                SettingsSection(
                                    title: "Debug",
                                    icon: "ant.fill",
                                    color: .orange
                                ) {
                                    debugSettings
                                }
                                #endif
                            }
                            .frame(maxWidth: 500)
                        }
                        .padding()
                    } else {
                        // iPhone Layout
                        VStack(spacing: DesignSystem.Spacing.md + 4) {
                            // Profile Header
                            profileHeader
                            
                            // Main Settings Sections - Grouped for better organization
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                // Group 1: Personalization
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    SettingsSection(
                                        title: "Appearance",
                                        icon: "paintbrush.fill",
                                        color: .purple
                                    ) {
                                        appearanceSettings
                                    }
                                    
                                    SettingsSection(
                                        title: "Calendar & Scheduling",
                                        icon: "calendar",
                                        color: .red
                                    ) {
                                        calendarSettings
                                    }
                                    
                                    SettingsSection(
                                        title: "Organization",
                                        icon: "folder.fill",
                                        color: .blue
                                    ) {
                                        organizationSettings
                                    }
                                }
                        
                                // Group 2: Features
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    SettingsSection(
                                        title: "AI Assistant",
                                        icon: "brain",
                                        color: .indigo
                                    ) {
                                        aiSettings
                                    }
                                    
                                    SettingsSection(
                                        title: "Notifications",
                                        icon: "bell.fill",
                                        color: .orange
                                    ) {
                                        notificationSettings
                                    }
                                    
                                    SettingsSection(
                                        title: "Privacy & Security",
                                        icon: "lock.shield.fill",
                                        color: .mint
                                    ) {
                                        privacySettings
                                    }
                                }
                        
                                // Group 3: Account & Data
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    SettingsSection(
                                        title: "Premium",
                                        icon: "crown.fill",
                                        color: .yellow
                                    ) {
                                        premiumSettings
                                    }
                                    
                                    SettingsSection(
                                        title: "Data Management",
                                        icon: "externaldrive.fill",
                                        color: .green
                                    ) {
                                        dataSettings
                                    }
                                }
                        
                                // Group 4: Information
                                SettingsSection(
                                    title: "About",
                                    icon: "info.circle.fill",
                                    color: .gray
                                ) {
                                    aboutSettings
                                }
                                
                                // Debug Section (only in DEBUG builds)
                                #if DEBUG
                                SettingsSection(
                                    title: "Debug",
                                    icon: "ant.fill",
                                    color: .orange
                                ) {
                                    debugSettings
                                }
                                #endif
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .standardNavigationTitle("Settings")
        }
        .navigationViewStyle(.automatic)
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView()
                .environmentObject(scheduleManager)
        }
        .sheet(isPresented: $showingCalendarIntegration) {
            CalendarIntegrationView()
        }
        .sheet(isPresented: $showingAIContext) {
            AIContextSheet(aiContextInfo: $aiContextInfo)
        }
        .sheet(isPresented: $showingProfileEditor) {
            ProfileEditorSheet(userName: $userName, userAvatar: $userAvatar)
        }
        .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
            Button("Calendar File (.ics)") {
                exportData(format: .ics)
            }
            Button("Spreadsheet (.csv)") {
                exportData(format: .csv)
            }
            Button("JSON (.json)") {
                exportData(format: .json)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose export format for your calendar data")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                deleteAllUserData()
            }
        } message: {
            Text("This will permanently delete all your events, categories, and settings. This action cannot be undone.")
        }
        .alert("Data Deleted", isPresented: $showingDataDeletedAlert) {
            Button("OK") {}
        } message: {
            Text("All data has been deleted successfully. Please restart the app to complete the process.")
        }
        .onAppear {
            updateAppearance()
            // Load saved reminder minutes
            let savedMinutes = NotificationManager.shared.getDefaultReminderMinutes()
            if !savedMinutes.isEmpty {
                defaultReminderMinutes = savedMinutes[0]
            }
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _ in
            if let item = selectedPhotoItem {
                loadImageDirectly(from: item)
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(
                selectedColor: $tempCustomColor,
                onSave: { color in
                    // Convert Color to hex string
                    if let components = UIColor(color).cgColor.components, components.count >= 3 {
                        let r = Int(components[0] * 255)
                        let g = Int(components[1] * 255)
                        let b = Int(components[2] * 255)
                        customAccentColorHex = String(format: "#%02X%02X%02X", r, g, b)
                        selectedAccentColor = "custom"
                    }
                    showingColorPicker = false
                }
            )
        }
        .sheet(isPresented: $showingFontSelector) {
            FontSelectorView()
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        Button(action: {
            showingProfileEditor = true
        }) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Profile Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(selectedAccentColor), Color(selectedAccentColor).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: userAvatar)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay(
                    Circle()
                        .stroke(Color(UIColor.systemBackground), lineWidth: 3)
                )
                .overlay(
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color(selectedAccentColor)))
                        .offset(x: 30, y: 30)
                )
                
                Text(userName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Tap to edit profile")
                    .font(.caption)
                    .foregroundColor(.secondary)
            
                // Stats
                HStack(spacing: DesignSystem.Spacing.xl - 2) {
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("\(scheduleManager.events.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("\(TaskManager.shared.tasks.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("\(HabitManager.shared.habits.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Habits")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg - 4)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Settings Sections
    
    private var appearanceSettings: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "circle.lefthalf.filled",
                title: "Theme",
                value: themeText,
                showChevron: false,
                expandedContent: {
                    Picker("Theme", selection: $selectedTheme) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.top, DesignSystem.Spacing.xs)
                    .onChange(of: selectedTheme) { _, _ in
                        updateAppearance()
                    }
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "app.badge.fill",
                title: "App Icon",
                value: appIconName,
                action: {
                    // In a real app, this would show an app icon picker
                    // For now, we'll just cycle through options
                    cycleAppIcon()
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "paintpalette.fill",
                title: "Accent Color",
                showChevron: false,
                expandedContent: {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            // Predefined colors
                            ForEach(["blue", "purple", "pink", "red", "orange", "green", "indigo"], id: \.self) { color in
                                Circle()
                                    .fill(Color(color))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .opacity(selectedAccentColor == color ? 1 : 0)
                                    )
                                    .onTapGesture {
                                        selectedAccentColor = color
                                        customAccentColorHex = ""
                                    }
                            }
                            
                            // Custom color picker
                            Circle()
                                .fill(selectedAccentColor == "custom" && !customAccentColorHex.isEmpty ? 
                                     Color(hex: customAccentColorHex) : Color.gray)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: selectedAccentColor == "custom" ? "checkmark" : "plus")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                )
                                .onTapGesture {
                                    showingColorPicker = true
                                }
                        }
                        
                        if selectedAccentColor == "custom" && !customAccentColorHex.isEmpty {
                            Text("Custom Color")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "textformat",
                title: "Font Style",
                value: UserDefaults.standard.string(forKey: "selectedFontFamily") ?? "System",
                action: {
                    showingFontSelector = true
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "photo.fill",
                title: "Header Background",
                value: headerImageName.isEmpty ? "Default" : "Custom Image",
                showChevron: false,
                expandedContent: {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Button("Choose Image") {
                                showingImagePicker = true
                            }
                            .buttonStyle(BorderedButtonStyle())
                            
                            if !headerImageName.isEmpty {
                                Button("Reset to Default") {
                                    deleteOldHeaderImage()
                                    headerImageName = ""
                                    headerImageRectX = 0.0
                                    headerImageRectY = 0.0
                                    headerImageRectWidth = 0.0
                                    headerImageRectHeight = 0.0
                                    // Clear extracted colors
                                    UserDefaults.standard.clearExtractedColors()
                                    UserDefaults.standard.removeObject(forKey: "headerImageVerticalOffset")
                                }
                                .buttonStyle(BorderedButtonStyle())
                                .tint(.red)
                            }
                        }
                        
                        if !headerImageName.isEmpty {
                            Button("Adjust Position") {
                                // Set a flag to indicate we want to edit
                                UserDefaults.standard.set(true, forKey: "shouldStartHeaderEdit")
                                // Dismiss settings and go to day view
                                dismiss()
                            }
                            .buttonStyle(BorderedButtonStyle())
                            .tint(.blue)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "textformat",
                title: "Use System Font",
                showChevron: false
            ) {
                Toggle("", isOn: $useSystemFont)
                    .labelsHidden()
            }
        }
    }
    
    private var organizationSettings: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "folder.fill",
                title: "Categories",
                value: "\(scheduleManager.categories.count)",
                action: {
                    showingCategoryManagement = true
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "calendar.badge.plus",
                title: "Calendar Integration",
                value: CalendarIntegrationManager.shared.selectedCalendarIds.isEmpty ? "Not Connected" : "\(CalendarIntegrationManager.shared.selectedCalendarIds.count) Connected",
                valueColor: CalendarIntegrationManager.shared.selectedCalendarIds.isEmpty ? .secondary : .green,
                action: {
                    showingCalendarIntegration = true
                }
            )
        }
    }
    
    private var aiSettings: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "brain",
                title: "Personal Context",
                value: aiContextInfo.isEmpty ? "Not Set" : "Configured",
                valueColor: aiContextInfo.isEmpty ? .secondary : .green,
                action: {
                    showingAIContext = true
                }
            )
        }
    }
    
    private var notificationSettings: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "bell.fill",
                title: "Notifications",
                value: notificationManager.isAuthorized ? "Enabled" : "Disabled",
                valueColor: notificationManager.isAuthorized ? .green : .secondary,
                action: {
                    if !notificationManager.isAuthorized {
                        AsyncTask {
                            await notificationManager.requestAuthorization()
                        }
                    } else {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "clock.fill",
                title: "Default Reminder",
                value: reminderText,
                showChevron: false,
                expandedContent: {
                    Picker("Default Reminder", selection: $defaultReminderMinutes) {
                        Text("None").tag(0)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("1 hour").tag(60)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.top, DesignSystem.Spacing.xs)
                    .onChange(of: defaultReminderMinutes) { oldValue, newValue in
                        if oldValue != newValue {
                            if newValue == 0 {
                                NotificationManager.shared.setDefaultReminderMinutes([])
                            } else {
                                NotificationManager.shared.setDefaultReminderMinutes([newValue])
                            }
                        }
                    }
                }
            )
        }
    }
    
    private var premiumSettings: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "crown.fill",
                title: "Subscription",
                value: subscriptionManager.isPremium ? "Premium" : "Free",
                valueColor: subscriptionManager.isPremium ? .green : .secondary,
                action: subscriptionManager.isPremium ? {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } : nil
            )
            
            if subscriptionManager.isPremium {
                Divider()
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "chart.bar.fill",
                    title: "Usage Today",
                    value: "\(subscriptionManager.messageCount)/500 messages",
                    showChevron: false
                )
            } else {
                Divider()
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "arrow.clockwise",
                    title: "Restore Purchases",
                    showChevron: false,
                    isLoading: isRestoringPurchases,
                    action: {
                        AsyncTask {
                            isRestoringPurchases = true
                            try? await subscriptionManager.restorePurchases()
                            isRestoringPurchases = false
                        }
                    }
                )
            }
        }
    }
    
    private var dataSettings: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "icloud.and.arrow.up.fill",
                title: "Auto Backup",
                value: autoBackupEnabled ? "On" : "Off",
                valueColor: autoBackupEnabled ? .green : .secondary,
                showChevron: false
            ) {
                Toggle("", isOn: $autoBackupEnabled)
                    .labelsHidden()
            }
            
            if lastBackupTimestamp > 0 {
                Divider()
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    title: "Last Backup",
                    value: formatBackupDate(Date(timeIntervalSince1970: lastBackupTimestamp)),
                    showChevron: false
                )
            }
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "square.and.arrow.up",
                title: "Export Data",
                action: {
                    showingExportOptions = true
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "square.and.arrow.down",
                title: "Import Data",
                action: {
                    // This would show a file picker in a real app
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "trash.fill",
                title: "Delete All Data",
                textColor: .red,
                action: {
                    showingDeleteConfirmation = true
                }
            )
        }
    }
    
    private var aboutSettings: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "star.fill",
                title: "Rate Planwise",
                action: {
                    requestAppReview()
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "envelope.fill",
                title: "Send Feedback",
                action: {
                    sendFeedback()
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "app.badge",
                title: "Version",
                value: appVersion,
                showChevron: false
            )
        }
    }
    
    #if DEBUG
    private var debugSettings: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "ant.circle.fill",
                title: "Check StoreKit Status",
                action: {
                    AsyncTask {
                        await subscriptionManager.debugCheckStoreKitStatus()
                    }
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "crown.fill",
                title: "Enable Premium (Debug)",
                action: {
                    subscriptionManager.debugEnablePremium()
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "doc.text.fill",
                title: "Products Loaded",
                value: "\(subscriptionManager.products.count)",
                showChevron: false
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "checkmark.circle.fill",
                title: "Is Premium",
                value: subscriptionManager.isPremium ? "Yes" : "No",
                showChevron: false
            )
        }
    }
    #endif
    
    // MARK: - Calendar Settings
    
    private var calendarSettings: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "calendar.day.timeline.left",
                title: "First Day of Week",
                value: weekdayName(firstDayOfWeek),
                showChevron: false,
                expandedContent: {
                    Picker("First Day of Week", selection: $firstDayOfWeek) {
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                        Text("Saturday").tag(7)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.top, DesignSystem.Spacing.xs)
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "number.square.fill",
                title: "Show Week Numbers",
                showChevron: false
            ) {
                Toggle("", isOn: $showWeekNumbers)
                    .labelsHidden()
            }
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "clock.fill",
                title: "Default Event Duration",
                value: "\(defaultEventDuration) min",
                showChevron: false,
                expandedContent: {
                    Picker("Duration", selection: $defaultEventDuration) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("1 hour").tag(60)
                        Text("90 min").tag(90)
                        Text("2 hours").tag(120)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.top, DesignSystem.Spacing.xs)
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "briefcase.fill",
                title: "Working Hours",
                value: "\(formatHour(workingHoursStart)) - \(formatHour(workingHoursEnd))",
                showChevron: false,
                expandedContent: {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Start")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("End")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Picker("Start", selection: $workingHoursStart) {
                                ForEach(0..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 100)
                            
                            Picker("End", selection: $workingHoursEnd) {
                                ForEach(0..<24) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 100)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            )
        }
    }
    
    // MARK: - Privacy Settings
    
    private var privacySettings: some View {
        VStack(spacing: 0) {
            if UIDevice.current.userInterfaceIdiom == .phone {
                SettingsRow(
                    icon: "faceid",
                    title: "Require Face ID",
                    showChevron: false
                ) {
                    Toggle("", isOn: $useFaceID)
                        .labelsHidden()
                }
                
                Divider()
                    .padding(.leading, 44)
            }
            
            SettingsRow(
                icon: "eye.slash.fill",
                title: "Hide Notification Content",
                showChevron: false
            ) {
                Toggle("", isOn: $hideNotificationContent)
                    .labelsHidden()
            }
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Share Analytics",
                showChevron: false
            ) {
                Toggle("", isOn: $enableAnalytics)
                    .labelsHidden()
            }
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "lock.doc.fill",
                title: "Privacy Policy",
                action: {
                    if let url = URL(string: "https://momentum.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
            )
            
            Divider()
                .padding(.leading, 44)
            
            SettingsRow(
                icon: "doc.text.fill",
                title: "Terms of Service",
                action: {
                    if let url = URL(string: "https://momentum.app/terms") {
                        UIApplication.shared.open(url)
                    }
                }
            )
        }
    }
    
    // MARK: - Helper Properties
    
    private var themeText: String {
        switch selectedTheme {
        case 1: return "Light"
        case 2: return "Dark"
        default: return "System"
        }
    }
    
    private var appIconName: String {
        switch selectedAppIcon {
        case "AppIcon-Dark": return "Dark"
        case "AppIcon-Light": return "Light"
        case "AppIcon-Rainbow": return "Rainbow"
        default: return "Default"
        }
    }
    
    private var reminderText: String {
        switch defaultReminderMinutes {
        case 0: return "None"
        case 5: return "5 min"
        case 10: return "10 min"
        case 15: return "15 min"
        case 30: return "30 min"
        case 60: return "1 hour"
        default: return "\(defaultReminderMinutes) min"
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    // MARK: - Helper Methods
    
    private func weekdayName(_ day: Int) -> String {
        switch day {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 7: return "Saturday"
        default: return "Sunday"
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
    
    private func formatBackupDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func cycleAppIcon() {
        let icons = ["AppIcon", "AppIcon-Dark", "AppIcon-Light", "AppIcon-Rainbow"]
        if let currentIndex = icons.firstIndex(of: selectedAppIcon) {
            let nextIndex = (currentIndex + 1) % icons.count
            selectedAppIcon = icons[nextIndex]
            
            // In a real app, this would change the app icon
            // UIApplication.shared.setAlternateIconName(selectedAppIcon == "AppIcon" ? nil : selectedAppIcon)
        }
    }
    
    // MARK: - Actions
    
    private func updateAppearance() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        switch selectedTheme {
        case 1: // Light
            window.overrideUserInterfaceStyle = .light
        case 2: // Dark
            window.overrideUserInterfaceStyle = .dark
        default: // System
            window.overrideUserInterfaceStyle = .unspecified
        }
    }
    
    private func exportData(format: ExportFormat) {
        let events = scheduleManager.events
        let exportService = DataExportService.shared
        
        switch format {
        case .ics:
            let icsContent = exportService.exportToICS(events: events)
            let filename = "Planwise_Export_\(Date().formatted(date: .abbreviated, time: .omitted).replacingOccurrences(of: "/", with: "-")).ics"
            if let url = exportService.createTemporaryFile(content: icsContent, filename: filename) {
                exportFileURL = url
                showingShareSheet = true
            }
            
        case .csv:
            let csvContent = exportService.exportToCSV(events: events)
            let filename = "Planwise_Export_\(Date().formatted(date: .abbreviated, time: .omitted).replacingOccurrences(of: "/", with: "-")).csv"
            if let url = exportService.createTemporaryFile(content: csvContent, filename: filename) {
                exportFileURL = url
                showingShareSheet = true
            }
            
        case .json:
            if let jsonData = exportService.exportToJSON(events: events) {
                let filename = "Planwise_Export_\(Date().formatted(date: .abbreviated, time: .omitted).replacingOccurrences(of: "/", with: "-")).json"
                if let url = exportService.createTemporaryFile(data: jsonData, filename: filename) {
                    exportFileURL = url
                    showingShareSheet = true
                }
            }
        }
    }
    
    private func sendFeedback() {
        let email = "support@planwise.app"
        let subject = "Planwise Feedback"
        let body = """
        
        
        ---
        App Version: \(appVersion)
        iOS Version: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        """
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
    
    private func requestAppReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    
    private func deleteAllUserData() {
        // Clear Core Data
        let container = PersistenceController.shared.container
        let entities = container.managedObjectModel.entities
        
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
            
            do {
                try container.viewContext.execute(deleteRequest)
            } catch {
            }
        }
        
        // Save context
        do {
            try container.viewContext.save()
        } catch {
        }
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Show success alert
        showingDataDeletedAlert = true
    }
    
    // MARK: - Header Image Handling
    
    private func loadImageDirectly(from item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    // Fix image orientation
                    let fixedImage = image.fixedOrientation()
                    DispatchQueue.main.async {
                        // Save the image directly without cropping
                        self.saveHeaderImage(fixedImage)
                        self.selectedPhotoItem = nil
                        // Set default position (centered)
                        self.headerImageRectX = 0
                        self.headerImageRectY = 0
                        self.headerImageRectWidth = Double(fixedImage.size.width)
                        self.headerImageRectHeight = Double(fixedImage.size.height)
                        
                        // Extract and save dominant colors
                        DispatchQueue.global(qos: .userInitiated).async {
                            let colors = ImageColorExtractor.extractDominantColors(from: fixedImage, maxColors: 3)
                            // Convert colors to hex strings for storage
                            let colorHexStrings = colors.compactMap { color -> String? in
                                if let components = UIColor(color).cgColor.components, components.count >= 3 {
                                    let r = Int(components[0] * 255)
                                    let g = Int(components[1] * 255)
                                    let b = Int(components[2] * 255)
                                    return String(format: "#%02X%02X%02X", r, g, b)
                                }
                                return nil
                            }
                            UserDefaults.standard.set(colorHexStrings, forKey: "headerImageExtractedColors")
                        }
                        
                        // Automatically open the editor
                        UserDefaults.standard.set(true, forKey: "shouldStartHeaderEdit")
                        // Dismiss settings to go to day view
                        self.dismiss()
                    }
                }
            case .failure(let error):
                print("Error loading image: \(error)")
                DispatchQueue.main.async {
                    self.selectedPhotoItem = nil
                }
            }
        }
    }
    
    
    private func saveHeaderImage(_ image: UIImage) {
        // Save to documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "headerImage_\(UUID().uuidString).jpg"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        // Compress and save the image
        if let jpegData = image.jpegData(compressionQuality: 0.9) {
            do {
                try jpegData.write(to: fileURL)
                
                // Delete old image if exists
                if !headerImageName.isEmpty {
                    deleteOldHeaderImage()
                }
                headerImageName = fileName
                
                // Extract colors from the image
                let extractedColors = ColorExtractor.extractColors(from: image)
                UserDefaults.standard.setExtractedColors(extractedColors)
                
                // Set flag to start header edit mode and navigate to DayView
                UserDefaults.standard.set(true, forKey: "shouldStartHeaderEdit")
                
                // Navigate to DayView
                DispatchQueue.main.async {
                    // Find navigation state in view hierarchy
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                       let rootView = window.rootViewController {
                        // Dismiss settings first
                        self.dismiss()
                        
                        // Navigate to DayView after a slight delay to ensure dismiss completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(
                                name: Notification.Name("NavigateToDayView"),
                                object: nil
                            )
                        }
                    }
                }
            } catch {
                print("Error saving header image: \(error)")
            }
        }
    }
    
    private func deleteOldHeaderImage() {
        guard !headerImageName.isEmpty else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(headerImageName)
        
        try? FileManager.default.removeItem(at: fileURL)
        
        // Clear extracted colors when removing image
        UserDefaults.standard.clearExtractedColors()
    }
    
    static func loadHeaderImage() -> (image: UIImage, visibleRect: CGRect)? {
        let headerImageName = UserDefaults.standard.string(forKey: "headerImageName") ?? ""
        guard !headerImageName.isEmpty else { return nil }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(headerImageName)
        
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            let rect = CGRect(
                x: UserDefaults.standard.double(forKey: "headerImageRectX"),
                y: UserDefaults.standard.double(forKey: "headerImageRectY"),
                width: UserDefaults.standard.double(forKey: "headerImageRectWidth"),
                height: UserDefaults.standard.double(forKey: "headerImageRectHeight")
            )
            return (image, rect)
        }
        return nil
    }
}

// MARK: - Settings Section Component

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Section Header
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.IconSize.sm, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: DesignSystem.IconSize.lg)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            
            // Section Content
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var valueColor: Color = .secondary
    var textColor: Color = .primary
    var showChevron: Bool = true
    var isLoading: Bool = false
    var action: (() -> Void)? = nil
    var expandedContent: AnyView? = nil
    
    @State private var isExpanded = false
    
    init(icon: String, title: String, value: String? = nil, valueColor: Color = .secondary, textColor: Color = .primary, showChevron: Bool = true, isLoading: Bool = false, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.textColor = textColor
        self.showChevron = showChevron
        self.isLoading = isLoading
        self.action = action
        self.expandedContent = nil
    }
    
    init<Content: View>(icon: String, title: String, value: String? = nil, valueColor: Color = .secondary, textColor: Color = .primary, showChevron: Bool = true, isLoading: Bool = false, action: (() -> Void)? = nil, @ViewBuilder expandedContent: () -> Content) {
        self.icon = icon
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.textColor = textColor
        self.showChevron = showChevron
        self.isLoading = isLoading
        self.action = action
        self.expandedContent = AnyView(expandedContent())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                if action != nil {
                    action?()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: DesignSystem.IconSize.md))
                        .foregroundColor(textColor == .primary ? .blue : textColor)
                        .frame(width: DesignSystem.IconSize.lg)
                    
                    Text(title)
                        .foregroundColor(textColor)
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let value = value {
                        Text(value)
                            .foregroundColor(valueColor)
                            .font(.subheadline)
                    }
                    
                    if showChevron && action != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: DesignSystem.Spacing.sm, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded, let expandedContent = expandedContent {
                expandedContent
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
    }
}

// MARK: - AI Context Sheet

struct AIContextSheet: View {
    @Binding var aiContextInfo: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextEditor(text: Binding(
                        get: { aiContextInfo },
                        set: { newValue in
                            if newValue.count <= 500 {
                                aiContextInfo = newValue
                            } else {
                                aiContextInfo = String(newValue.prefix(500))
                            }
                        }
                    ))
                    .frame(minHeight: 200)
                    .padding(DesignSystem.Spacing.xxs)
                } header: {
                    HStack {
                        Text("Personal Information")
                        Spacer()
                        Text("\(aiContextInfo.count)/500")
                            .font(.caption)
                            .foregroundColor(aiContextInfo.count >= 500 ? .red : .secondary)
                    }
                } footer: {
                    Text("This information helps the AI assistant understand your preferences and provide better suggestions. For example: work hours, timezone, job role, personal goals, etc.")
                        .font(.caption)
                }
            }
            .navigationTitle("AI Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum ExportFormat: String {
    case ics = "ics"
    case csv = "csv"
    case json = "json"
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Profile Editor Sheet

struct ProfileEditorSheet: View {
    @Binding var userName: String
    @Binding var userAvatar: String
    @Environment(\.dismiss) var dismiss
    @State private var tempName: String = ""
    @State private var tempAvatar: String = ""
    
    let avatarOptions = [
        "person.circle.fill",
        "person.crop.circle.fill",
        "face.smiling.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "bolt.circle.fill",
        "flame.circle.fill",
        "leaf.circle.fill",
        "pawprint.circle.fill",
        "airplane.circle.fill",
        "bicycle.circle.fill",
        "car.circle.fill"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Name") {
                    TextField("Enter your name", text: $tempName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("Choose Avatar") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: DesignSystem.Spacing.md) {
                        ForEach(avatarOptions, id: \.self) { icon in
                            Button(action: {
                                tempAvatar = icon
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(tempAvatar == icon ? Color.blue : Color(UIColor.secondarySystemBackground))
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(tempAvatar == icon ? .white : .primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        userName = tempName.isEmpty ? "Momentum User" : tempName
                        userAvatar = tempAvatar.isEmpty ? "person.circle.fill" : tempAvatar
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(tempName.isEmpty && tempAvatar.isEmpty)
                }
            }
        }
        .onAppear {
            tempName = userName
            tempAvatar = userAvatar
        }
    }
}

// MARK: - Color Picker Sheet

struct ColorPickerSheet: View {
    @Binding var selectedColor: Color
    let onSave: (Color) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var tempColor: Color = .blue
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose Your Accent Color")
                    .font(.headline)
                    .padding(.top)
                
                ColorPicker("Select Color", selection: $tempColor)
                    .labelsHidden()
                    .frame(width: 200, height: 200)
                    .scaleEffect(2.0)
                
                // Preview
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(tempColor)
                            .frame(width: 60, height: 60)
                        Text("New Color")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(tempColor)
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Custom Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(tempColor)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            tempColor = selectedColor
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}

#Preview {
    SettingsView()
        .environmentObject(ScheduleManager.shared)
}