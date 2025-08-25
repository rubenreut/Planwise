import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                Text("Last Updated: July 1, 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Introduction
                Section {
                    Text("Your privacy is important to us. Planwise is designed with privacy at its core.")
                        .scaledFont(size: 17)
                }
                
                // Data Collection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Information We Collect")
                        .font(.headline)
                    
                    Text("""
                    Planwise collects minimal information:
                    
                    • **Event Data**: Your calendar events, tasks, and notes are stored locally on your device
                    • **Usage Logs**: Optional local logs to help debug issues (never sent anywhere)
                    """)
                    .scaledFont(size: 17)
                }
                
                // iCloud Sync
                VStack(alignment: .leading, spacing: 10) {
                    Text("iCloud Synchronization")
                        .font(.headline)
                    
                    Text("""
                    Planwise uses iCloud to sync your data across your devices:
                    
                    • Your data is encrypted and stored in your personal iCloud account
                    • We do not have access to your iCloud data
                    • Sync is automatic when you're signed into iCloud
                    • You can disable iCloud sync in your device settings
                    • All data remains under your control via your Apple ID
                    """)
                    .scaledFont(size: 17)
                }
                
                // Data Storage
                VStack(alignment: .leading, spacing: 10) {
                    Text("Data Storage")
                        .font(.headline)
                    
                    Text("""
                    • All personal data is stored locally on your device
                    • iCloud sync uses Apple's secure infrastructure
                    • We do not have any servers or collect any data
                    • Your AI conversation context is stored locally
                    • Crash logs and analytics (if enabled) stay on your device
                    """)
                    .scaledFont(size: 17)
                }
                
                // Third Party Services
                VStack(alignment: .leading, spacing: 10) {
                    Text("Third-Party Services")
                        .font(.headline)
                    
                    Text("""
                    Planwise uses these third-party services:
                    
                    • **OpenAI**: For AI assistant features (conversations are not stored)
                    • **StoreKit**: For premium subscriptions (managed by Apple)
                    """)
                    .scaledFont(size: 17)
                }
                
                // User Rights
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Rights")
                        .font(.headline)
                    
                    Text("""
                    You have the right to:
                    
                    • Delete all your data at any time
                    • Disable analytics and crash reporting
                    • Export your data
                    • Disable iCloud sync
                    • Request information about data we collect
                    """)
                    .scaledFont(size: 17)
                }
                
                // Contact
                VStack(alignment: .leading, spacing: 10) {
                    Text("Contact Us")
                        .font(.headline)
                    
                    Text("If you have questions about this privacy policy, please contact us at rubenreut19@gmail.com")
                        .scaledFont(size: 17)
                }
                
                // Changes
                VStack(alignment: .leading, spacing: 10) {
                    Text("Changes to This Policy")
                        .font(.headline)
                    
                    Text("We may update this privacy policy from time to time. We will notify you of any changes by updating the 'Last Updated' date.")
                        .scaledFont(size: 17)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        PrivacyPolicyView()
    }
}