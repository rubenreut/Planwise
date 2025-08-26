import SwiftUI

/// Manages AI assistant settings
@MainActor
class AISettingsViewModel: ObservableObject {
    // MARK: - AI Settings
    @AppStorage("aiContextInfo") var aiContextInfo = ""
    
    // MARK: - Published Properties
    @Published var showingAIContext = false
    
    // MARK: - Methods
    
    func openAIContextEditor() {
        showingAIContext = true
    }
    
    func clearAIContext() {
        aiContextInfo = ""
    }
    
    var hasAIContext: Bool {
        !aiContextInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var contextPreview: String {
        guard hasAIContext else { return "No context set" }
        let preview = aiContextInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        if preview.count > 50 {
            return String(preview.prefix(50)) + "..."
        }
        return preview
    }
}