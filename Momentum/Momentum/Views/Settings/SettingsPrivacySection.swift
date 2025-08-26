import SwiftUI

struct SettingsPrivacySection: View {
    @ObservedObject var privacyVM: PrivacySettingsViewModel
    @ObservedObject var appearanceVM: AppearanceSettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if privacyVM.isBiometricAvailable {
                Toggle(isOn: Binding(
                    get: { privacyVM.useFaceID },
                    set: { _ in privacyVM.toggleBiometricAuth() }
                )) {
                    HStack {
                        Image(systemName: privacyVM.biometricIconName)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 28, height: 28)
                            .padding(.trailing, 8)
                        
                        Text(privacyVM.biometricDisplayName)
                            .font(.body)
                    }
                }
                .tint(Color.fromAccentString(appearanceVM.selectedAccentColor))
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                Divider().padding(.leading, 44)
            }
            
            Toggle(isOn: $privacyVM.hideNotificationContent) {
                HStack {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 20))
                        .foregroundColor(.mint)
                        .frame(width: 28, height: 28)
                        .padding(.trailing, 8)
                    
                    Text("Hide Notification Content")
                        .font(.body)
                }
            }
            .tint(Color.fromAccentString(appearanceVM.selectedAccentColor))
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider().padding(.leading, 44)
            
            Toggle(isOn: $privacyVM.enableAnalytics) {
                HStack {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                        .frame(width: 28, height: 28)
                        .padding(.trailing, 8)
                    
                    Text("Share Analytics")
                        .font(.body)
                }
            }
            .tint(Color.fromAccentString(appearanceVM.selectedAccentColor))
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}