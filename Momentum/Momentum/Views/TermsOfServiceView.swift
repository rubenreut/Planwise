import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Service")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                Text("Last Updated: July 1, 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Agreement
                Section {
                    Text("By using Planwise, you agree to these Terms of Service.")
                        .font(.body)
                        .padding(.bottom, 10)
                }
                
                // Use License
                VStack(alignment: .leading, spacing: 10) {
                    Text("License to Use")
                        .font(.headline)
                    
                    Text("""
                    We grant you a personal, non-transferable, non-exclusive license to use Planwise on your devices. This license is for personal and non-commercial use only.
                    """)
                    .font(.body)
                }
                
                // Acceptable Use
                VStack(alignment: .leading, spacing: 10) {
                    Text("Acceptable Use")
                        .font(.headline)
                    
                    Text("""
                    You agree to use Planwise only for lawful purposes. You will not:
                    
                    • Use the app for any illegal activities
                    • Attempt to hack, reverse engineer, or disrupt the service
                    • Share your account or subscription with others
                    • Use the app in any way that could damage our reputation
                    """)
                    .font(.body)
                }
                
                // Subscriptions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Premium Subscriptions")
                        .font(.headline)
                    
                    Text("""
                    • Premium features require a paid subscription
                    • Subscriptions auto-renew unless cancelled
                    • Payment is processed through Apple's App Store
                    • You can manage subscriptions in your Apple ID settings
                    • Refunds are subject to Apple's refund policy
                    """)
                    .font(.body)
                }
                
                // User Content
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Content")
                        .font(.headline)
                    
                    Text("""
                    • You retain ownership of all content you create in Planwise
                    • You're responsible for backing up your data
                    • We're not liable for any loss of data
                    • Your data syncs via iCloud under Apple's terms
                    """)
                    .font(.body)
                }
                
                // AI Usage
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI Assistant")
                        .font(.headline)
                    
                    Text("""
                    The AI assistant feature:
                    
                    • Processes your requests using OpenAI's API
                    • May have limitations or provide incorrect information
                    • Should not be relied upon for critical decisions
                    • Is subject to usage limits based on your subscription
                    """)
                    .font(.body)
                }
                
                // Disclaimers
                VStack(alignment: .leading, spacing: 10) {
                    Text("Disclaimers")
                        .font(.headline)
                    
                    Text("""
                    • Planwise is provided "as is" without warranties
                    • We don't guarantee the app will be error-free
                    • We're not responsible for missed appointments or lost data
                    • Features may change or be discontinued
                    """)
                    .font(.body)
                }
                
                // Limitation of Liability
                VStack(alignment: .leading, spacing: 10) {
                    Text("Limitation of Liability")
                        .font(.headline)
                    
                    Text("""
                    To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of Planwise.
                    """)
                    .font(.body)
                }
                
                // Termination
                VStack(alignment: .leading, spacing: 10) {
                    Text("Termination")
                        .font(.headline)
                    
                    Text("""
                    We may terminate or suspend your access to Planwise immediately, without prior notice, for any breach of these Terms.
                    """)
                    .font(.body)
                }
                
                // Governing Law
                VStack(alignment: .leading, spacing: 10) {
                    Text("Governing Law")
                        .font(.headline)
                    
                    Text("These Terms are governed by the laws of Ireland and the European Union.")
                        .font(.body)
                }
                
                // Contact
                VStack(alignment: .leading, spacing: 10) {
                    Text("Contact")
                        .font(.headline)
                    
                    Text("For questions about these Terms, contact us at rubenreut19@gmail.com")
                        .font(.body)
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        TermsOfServiceView()
    }
}