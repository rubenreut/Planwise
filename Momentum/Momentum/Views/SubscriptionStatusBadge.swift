import SwiftUI

struct SubscriptionStatusBadge: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    
    private let baseUnit: CGFloat = 8
    
    var body: some View {
        Button(action: {
            if !subscriptionManager.isPremium {
                showingPaywall = true
            }
        }) {
            HStack(spacing: baseUnit) {
                Image(systemName: subscriptionManager.isPremium ? "crown.fill" : "sparkles")
                    .font(.system(size: 14, weight: .medium))
                
                Text(subscriptionManager.isPremium ? "Pro" : "Free")
                    .font(.system(size: 14, weight: .semibold))
                
                if !subscriptionManager.isPremium {
                    Text("\(subscriptionManager.messageCount)/\(10)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(subscriptionManager.isPremium ? .white : .primary)
            .padding(.horizontal, baseUnit * 1.5)
            .padding(.vertical, baseUnit)
            .background(
                RoundedRectangle(cornerRadius: baseUnit * 2)
                    .fill(subscriptionManager.isPremium ? 
                          LinearGradient(
                              colors: [Color.purple, Color.pink],
                              startPoint: .leading,
                              endPoint: .trailing
                          ) : 
                          LinearGradient(
                              colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.15)],
                              startPoint: .leading,
                              endPoint: .trailing
                          )
                    )
            )
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallViewPremium()
        }
    }
}

#Preview {
    SubscriptionStatusBadge()
}