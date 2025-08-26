import SwiftUI

struct SettingsProfileHeader: View {
    @ObservedObject var accountVM: AccountSettingsViewModel
    @ObservedObject var appearanceVM: AppearanceSettingsViewModel
    var onEditProfile: () -> Void
    
    var body: some View {
        Button(action: onEditProfile) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Profile Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [
                                Color.fromAccentString(appearanceVM.selectedAccentColor),
                                Color.fromAccentString(appearanceVM.selectedAccentColor).opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: accountVM.userAvatar)
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
                        .background(Circle().fill(Color.fromAccentString(appearanceVM.selectedAccentColor)))
                        .offset(x: 30, y: 30)
                )
                
                Text(accountVM.userName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Tap to edit profile")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}