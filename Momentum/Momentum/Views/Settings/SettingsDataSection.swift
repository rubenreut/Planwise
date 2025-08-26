import SwiftUI

struct SettingsDataSection: View {
    @ObservedObject var dataVM: DataManagementViewModel
    @ObservedObject var appearanceVM: AppearanceSettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Export
            SettingsRow(
                icon: "square.and.arrow.up",
                title: "Export Data",
                showChevron: true,
                action: {
                    dataVM.showingExportOptions = true
                }
            )
            
            Divider().padding(.leading, 44)
            
            // Auto Backup
            Toggle(isOn: $dataVM.autoBackupEnabled) {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                        .frame(width: 28, height: 28)
                        .padding(.trailing, 8)
                    
                    VStack(alignment: .leading) {
                        Text("Auto Backup")
                            .font(.body)
                        if let lastBackup = dataVM.lastBackupDate {
                            Text(dataVM.formatBackupDate(lastBackup))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .tint(Color.fromAccentString(appearanceVM.selectedAccentColor))
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider().padding(.leading, 44)
            
            // Delete All Data
            SettingsRow(
                icon: "trash",
                title: "Delete All Data",
                textColor: .red,
                action: {
                    dataVM.showingDeleteConfirmation = true
                }
            )
        }
    }
}