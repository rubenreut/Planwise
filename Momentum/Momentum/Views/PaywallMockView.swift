import SwiftUI

// Mock version of paywall for screenshots only
struct PaywallMockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedOption = "annual"
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895
    private let baseUnit: Double = 8.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.1),
                        Color.accentColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: baseUnit * 3) {
                        // Header
                        headerView
                        
                        // Features
                        featuresView
                        
                        // Pricing options
                        pricingView
                        
                        // Action buttons
                        actionButtons
                        
                        // Terms
                        termsView
                    }
                    .padding(.horizontal, baseUnit * 2)
                    .padding(.vertical, baseUnit * 3)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: baseUnit * 2) {
            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding(.top, baseUnit * 2)
            
            // Title
            Text("Unlock Planwise Pro")
                .font(.system(size: 28, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text("Transform your productivity with AI-powered scheduling")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, baseUnit * 2)
        }
    }
    
    // MARK: - Features View
    
    private var featuresView: some View {
        VStack(alignment: .leading, spacing: baseUnit * 2) {
            FeatureRow(
                icon: "infinity",
                title: "Unlimited AI Messages",
                description: "No limits on scheduling assistance"
            )
            
            FeatureRow(
                icon: "photo.on.rectangle.angled",
                title: "Image Analysis",
                description: "Upload screenshots and photos for AI to analyze"
            )
            
            FeatureRow(
                icon: "clock.arrow.circlepath",
                title: "Smart Scheduling",
                description: "AI learns your patterns and suggests optimal times"
            )
            
            FeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Advanced Analytics",
                description: "Track productivity and time usage insights"
            )
            
            FeatureRow(
                icon: "bolt.fill",
                title: "Priority Support",
                description: "Get help faster with premium support"
            )
        }
        .padding(.vertical, baseUnit * 2)
    }
    
    // MARK: - Pricing View
    
    private var pricingView: some View {
        VStack(spacing: baseUnit * 1.5) {
            // Best value badge
            HStack {
                Spacer()
                Text("SAVE 49%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, baseUnit * 1.5)
                    .padding(.vertical, baseUnit / 2)
                    .background(Color.green)
                    .cornerRadius(baseUnit * 2)
                    .offset(y: baseUnit)
                    .zIndex(1)
            }
            .padding(.horizontal, baseUnit * 2)
            
            // Monthly option
            MockPricingOption(
                title: "Planwise Pro Monthly",
                price: "€12.99",
                period: "per month",
                isSelected: selectedOption == "monthly"
            ) {
                selectedOption = "monthly"
            }
            
            // Annual option
            MockPricingOption(
                title: "Planwise Pro Annual",
                price: "€79.99",
                period: "per year",
                isSelected: selectedOption == "annual",
                isBestValue: true
            ) {
                selectedOption = "annual"
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: baseUnit * 2) {
            // Purchase button
            Button(action: {}) {
                Text("Subscribe Now")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(baseUnit * 2)
            }
            
            // Restore button
            Button(action: {}) {
                Text("Restore Purchases")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.top, baseUnit * 2)
    }
    
    // MARK: - Terms View
    
    private var termsView: some View {
        VStack(spacing: baseUnit) {
            Text("By subscribing, you agree to our")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            HStack(spacing: baseUnit * 2) {
                Text("Terms of Service")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
                
                Text("Privacy Policy")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.top, baseUnit * 3)
    }
}

struct MockPricingOption: View {
    let title: String
    let price: String
    let period: String
    let isSelected: Bool
    var isBestValue: Bool = false
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    private let baseUnit: Double = 8.0
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: baseUnit / 2) {
                    HStack {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                        
                        if isBestValue {
                            Text("Best Value")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, baseUnit)
                                .padding(.vertical, baseUnit / 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(baseUnit)
                        }
                    }
                    
                    Text("\(price) \(period)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding(baseUnit * 2)
            .background(
                RoundedRectangle(cornerRadius: baseUnit * 1.5)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: baseUnit * 1.5)
                    .fill(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    PaywallMockView()
}