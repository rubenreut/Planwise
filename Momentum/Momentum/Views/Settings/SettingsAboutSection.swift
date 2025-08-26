import SwiftUI

struct SettingsAboutSection: View {
    @ObservedObject var accountVM: AccountSettingsViewModel
    var onSendFeedback: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "star",
                title: "Rate App",
                action: {
                    accountVM.requestAppReview()
                }
            )
            
            Divider().padding(.leading, 44)
            
            SettingsRow(
                icon: "envelope",
                title: "Send Feedback",
                action: onSendFeedback
            )
            
            Divider().padding(.leading, 44)
            
            SettingsRow(
                icon: "doc.text",
                title: "Terms of Service",
                showChevron: true,
                action: {
                    // Navigate to terms
                }
            )
            
            Divider().padding(.leading, 44)
            
            SettingsRow(
                icon: "hand.raised",
                title: "Privacy Policy",
                showChevron: true,
                action: {
                    // Navigate to privacy
                }
            )
            
            Divider().padding(.leading, 44)
            
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
                    .padding(.trailing, 8)
                
                VStack(alignment: .leading) {
                    Text("Version")
                        .font(.body)
                    Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}