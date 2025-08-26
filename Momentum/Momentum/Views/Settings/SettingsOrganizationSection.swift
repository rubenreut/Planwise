import SwiftUI

struct SettingsOrganizationSection: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    var onManageCategories: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "folder",
                title: "Categories",
                value: "\(scheduleManager.categories.count)",
                showChevron: true,
                action: onManageCategories
            )
        }
    }
}