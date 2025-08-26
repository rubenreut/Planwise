import SwiftUI

#if DEBUG
struct SettingsDebugSection: View {
    @ObservedObject var notificationVM: NotificationSettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "ladybug",
                title: "Test Notification",
                action: {
                    notificationVM.testNotification()
                }
            )
            
            Divider().padding(.leading, 44)
            
            SettingsRow(
                icon: "waveform",
                title: "Reset Onboarding",
                action: {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                }
            )
        }
    }
}
#endif