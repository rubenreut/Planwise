import SwiftUI

struct SettingsAISection: View {
    @ObservedObject var aiVM: AISettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(
                icon: "brain",
                title: "Personal Context",
                value: aiVM.hasAIContext ? "Configured" : "Not Set",
                valueColor: aiVM.hasAIContext ? .green : .secondary,
                action: {
                    aiVM.showingAIContext = true
                }
            )
        }
    }
}