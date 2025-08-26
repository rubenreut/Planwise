import SwiftUI

struct SettingsScreenTimeSection: View {
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    var onShowScreenTimeSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "hourglass",
                title: "Daily Usage",
                value: "View Usage",
                valueColor: .gray,
                showChevron: true,
                action: onShowScreenTimeSettings
            )
        }
    }
}