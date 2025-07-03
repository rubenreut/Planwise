import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var showingError = false
    @State private var errorMessage = ""
    
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
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .interactiveDismissDisabled(subscriptionManager.isLoading)
        .onAppear {
            // Select annual by default (best value)
            selectedProduct = subscriptionManager.annualProduct
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
            // Loading state
            if subscriptionManager.products.isEmpty && subscriptionManager.isLoading {
                ProgressView("Loading products...")
                    .padding(.vertical, baseUnit * 4)
            } else if subscriptionManager.products.isEmpty {
                VStack(spacing: baseUnit) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Products not available")
                        .font(.headline)
                    
                    Text("Please check your internet connection and try again.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Retry") {
                        Task {
                            await subscriptionManager.loadProducts()
                        }
                    }
                    .padding(.top)
                }
                .padding(.vertical, baseUnit * 4)
            } else {
            // Best value badge
            if subscriptionManager.annualSavingsPercentage > 0 {
                HStack {
                    Spacer()
                    Text("SAVE \(subscriptionManager.annualSavingsPercentage)%")
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
            }
            
            // Subscription options
            ForEach(subscriptionManager.products, id: \.id) { product in
                PricingOption(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isBestValue: product.id == subscriptionManager.annualProductID
                ) {
                    selectedProduct = product
                }
            }
            } // Added closing brace for else
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: baseUnit * 2) {
            // Purchase button
            Button(action: purchase) {
                Group {
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(purchaseButtonTitle)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(baseUnit * 2)
            }
            .disabled(selectedProduct == nil || subscriptionManager.isLoading)
            
            // Restore button
            Button(action: restore) {
                Text("Restore Purchases")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            .disabled(subscriptionManager.isLoading)
            
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
                Link("Terms of Service", destination: URL(string: "https://rubenreut.github.io/Planwise-legal/terms-of-service.html")!)
                    .font(.system(size: 12, weight: .medium))
                
                Link("Privacy Policy", destination: URL(string: "https://rubenreut.github.io/Planwise-legal/privacy-policy.html")!)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.top, baseUnit * 3)
    }
    
    // MARK: - Computed Properties
    
    private var purchaseButtonTitle: String {
        guard let product = selectedProduct else { return "Select a Plan" }
        
        return "Subscribe Now"
    }
    
    // MARK: - Actions
    
    private func purchase() {
        guard let product = selectedProduct else { return }
        
        Task {
            do {
                if try await subscriptionManager.purchase(product) != nil {
                    // Success! Dismiss the paywall
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func restore() {
        Task {
            do {
                try await subscriptionManager.restorePurchases()
                
                if subscriptionManager.isPremium {
                    // Restored successfully
                    dismiss()
                } else {
                    errorMessage = "No active subscriptions found"
                    showingError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    private let baseUnit: Double = 8.0
    
    var body: some View {
        HStack(alignment: .top, spacing: baseUnit * 2) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: baseUnit / 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct PricingOption: View {
    let product: Product
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
                        Text(product.displayName)
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
                    
                    Text(priceDescription)
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
    
    private var priceDescription: String {
        if product.id.contains("annual") {
            return "\(product.displayPrice) per year"
        } else {
            return "\(product.displayPrice) per month"
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}