import SwiftUI
import StoreKit
import MessageUI
import CoreData
import UserNotifications
import LocalAuthentication
import PhotosUI

// MARK: - Main Settings View (Coordinator)
struct SettingsView: View {
    // MARK: - Environment & Dependencies
    @EnvironmentObject var scheduleManager: ScheduleManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - ViewModels (Facade Pattern)
    @StateObject private var appearanceVM = AppearanceSettingsViewModel()
    @StateObject private var accountVM = AccountSettingsViewModel()
    @StateObject private var notificationVM = NotificationSettingsViewModel()
    @StateObject private var dataVM = DataManagementViewModel()
    @StateObject private var privacyVM = PrivacySettingsViewModel()
    @StateObject private var calendarVM = CalendarSettingsViewModel()
    @StateObject private var aiVM = AISettingsViewModel()
    
    // MARK: - Local State
    @State private var showingCategoryManagement = false
    @State private var showingScreenTimeSettings = false
    @State private var showingMailComposer = false
    @State private var showingProfileEditor = false
    @State private var showingExportSheet = false
    @State private var exportedFileURL: URL?
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    SettingsProfileHeader(
                        accountVM: accountVM,
                        appearanceVM: appearanceVM,
                        onEditProfile: {
                            showingProfileEditor = true
                        }
                    )
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                    
                    // Settings Content
                    settingsContent
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingProfileEditor) {
            ProfileEditorSheet(userName: $accountVM.userName, userAvatar: $accountVM.userAvatar)
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView()
        }
        .sheet(isPresented: $showingScreenTimeSettings) {
            ScreenTimeSettingsView()
        }
        .sheet(isPresented: $appearanceVM.showingColorPicker) {
            ColorPickerSheet(
                selectedColor: Color.fromAccentString(appearanceVM.selectedAccentColor),
                onSave: { color in
                    appearanceVM.saveCustomColor(color)
                }
            )
        }
        .photosPicker(isPresented: $appearanceVM.showingImagePicker, 
                     selection: $appearanceVM.selectedImageItem, 
                     matching: .images)
        .sheet(isPresented: $aiVM.showingAIContext) {
            AIContextSheet(aiContextInfo: $aiVM.aiContextInfo)
        }
        .sheet(isPresented: $notificationVM.showingNotificationSettings) {
            NotificationSettingsDetailView(viewModel: notificationVM)
        }
        .sheet(isPresented: $dataVM.showingExportOptions) {
            ExportOptionsView(viewModel: dataVM)
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingMailComposer) {
            MailView(recipients: ["support@momentum.app"], subject: "Momentum App Feedback")
        }
        .alert("Delete All Data", isPresented: $dataVM.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                dataVM.deleteAllUserData()
            }
        } message: {
            Text("This will permanently delete all your data. This action cannot be undone.")
        }
        .alert("Restore Purchases", isPresented: $accountVM.showingRestoreAlert) {
            Button("OK") { }
        } message: {
            Text(accountVM.restoreMessage)
        }
        .onChange(of: dataVM.exportedFileURL) { newValue in
            if let url = newValue {
                exportedFileURL = url
                showingExportSheet = true
            }
        }
    }
    
    // MARK: - Settings Content Layout
    @ViewBuilder
    private var settingsContent: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad Layout
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        settingsColumn1
                    }
                    .frame(maxWidth: 500)
                    
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        settingsColumn2
                    }
                    .frame(maxWidth: 500)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
            } else {
                // iPhone Layout
                VStack(spacing: DesignSystem.Spacing.lg) {
                    settingsColumn1
                    settingsColumn2
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
    }
    
    // MARK: - Settings Columns
    @ViewBuilder
    private var settingsColumn1: some View {
        // Group 1: Personalization
        VStack(spacing: DesignSystem.Spacing.md) {
            SettingsSection(title: "Appearance", icon: "paintbrush.fill", color: .purple) {
                SettingsAppearanceSection(viewModel: appearanceVM)
            }
            
            SettingsSection(title: "Calendar & Scheduling", icon: "calendar", color: .red) {
                SettingsCalendarSection(calendarVM: calendarVM, appearanceVM: appearanceVM)
            }
            
            SettingsSection(title: "Organization", icon: "folder.fill", color: .blue) {
                SettingsOrganizationSection(onManageCategories: {
                    showingCategoryManagement = true
                })
                .environmentObject(scheduleManager)
            }
        }
        
        // Group 2: Features
        VStack(spacing: DesignSystem.Spacing.md) {
            SettingsSection(title: "AI Assistant", icon: "brain", color: .indigo) {
                SettingsAISection(aiVM: aiVM)
            }
            
            SettingsSection(title: "Notifications", icon: "bell.fill", color: .orange) {
                SettingsNotificationSection(viewModel: notificationVM)
            }
            
            SettingsSection(title: "Screen Time", icon: "hourglass", color: .purple) {
                SettingsScreenTimeSection(onShowScreenTimeSettings: {
                    showingScreenTimeSettings = true
                })
            }
        }
    }
    
    @ViewBuilder
    private var settingsColumn2: some View {
        // Privacy & Security
        SettingsSection(title: "Privacy & Security", icon: "lock.shield.fill", color: .mint) {
            SettingsPrivacySection(privacyVM: privacyVM, appearanceVM: appearanceVM)
        }
        
        // Account & Data
        VStack(spacing: DesignSystem.Spacing.md) {
            SettingsSection(title: "Premium", icon: "crown.fill", color: .yellow) {
                SettingsAccountSection(accountVM: accountVM)
            }
            
            SettingsSection(title: "Data Management", icon: "externaldrive.fill", color: .green) {
                SettingsDataSection(dataVM: dataVM, appearanceVM: appearanceVM)
            }
        }
        
        // About
        SettingsSection(title: "About", icon: "info.circle.fill", color: .gray) {
            SettingsAboutSection(accountVM: accountVM, onSendFeedback: sendFeedback)
        }
        
        #if DEBUG
        SettingsSection(title: "Debug", icon: "ant.fill", color: .orange) {
            SettingsDebugSection(notificationVM: notificationVM)
        }
        #endif
    }
    
    // MARK: - Helper Methods
    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            if let url = URL(string: "mailto:support@momentum.app") {
                UIApplication.shared.open(url)
            }
        }
    }
}

