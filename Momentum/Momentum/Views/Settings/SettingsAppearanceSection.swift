import SwiftUI
import PhotosUI

struct SettingsAppearanceSection: View {
    @ObservedObject var viewModel: AppearanceSettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // App Icon
            SettingsRow(
                icon: "app",
                title: "App Icon",
                value: viewModel.selectedAppIcon,
                action: {
                    viewModel.cycleAppIcon()
                }
            )
            
            Divider().padding(.leading, 44)
            
            // Accent Color
            SettingsRow(
                icon: "paintpalette",
                title: "Accent Color",
                showChevron: true,
                action: {
                    viewModel.showingColorPicker = true
                }
            ) {
                Circle()
                    .fill(Color.fromAccentString(viewModel.selectedAccentColor))
                    .frame(width: 24, height: 24)
            }
            
            Divider().padding(.leading, 44)
            
            // Font Size
            SettingsRow(
                icon: "textformat.size",
                title: "Font Size",
                value: viewModel.appFontSize.displayName,
                showChevron: true,
                action: {
                    viewModel.showingFontSelector = true
                }
            )
            
            Divider().padding(.leading, 44)
            
            // Header Image
            SettingsRow(
                icon: "photo",
                title: "Header Image",
                value: viewModel.headerImageName.isEmpty ? "Not Set" : "Custom",
                showChevron: true,
                action: {
                    viewModel.showingImagePicker = true
                }
            )
        }
    }
}