import SwiftUI

struct SettingsAccountSection: View {
    @ObservedObject var accountVM: AccountSettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "crown",
                title: "Subscription",
                value: accountVM.subscriptionStatusText,
                valueColor: accountVM.subscriptionBadgeColor,
                showChevron: true,
                action: {
                    accountVM.openSubscriptionManagement()
                }
            )
            
            Divider().padding(.leading, 44)
            
            SettingsRow(
                icon: "arrow.clockwise",
                title: "Restore Purchases",
                action: {
                    _Concurrency.Task {
                        await accountVM.restorePurchases()
                    }
                }
            )
        }
    }
}