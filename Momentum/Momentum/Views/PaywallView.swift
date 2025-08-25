import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedPlanIndex = 1 // Default to annual
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895
    private let baseUnit: Double = 8.0
    
    // Screenshot mode - set to true for App Store screenshots
    private let screenshotMode = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient.adaptiveGradient(
                    from: Color.adaptiveBackground,
                    to: Color.adaptiveSecondaryBackground,
                    darkFrom: Color.black,
                    darkTo: Color(white: 0.05)
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
                .scaledFont(size: 60)
                .foregroundColor(.accentColor)
                .padding(.top, baseUnit * 2)
            
            // Title
            Text("Unlock Planwise Pro")
                .scaledFont(size: 28, weight: .bold, design: .default)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text("Transform your productivity with AI-powered scheduling")
                .scaledFont(size: 16, weight: .medium)
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
                title: "Unlimited Events, Tasks, Habits & Goals",
                description: "Free users limited to 3 of each"
            )
            
            FeatureRow(
                icon: "message.badge.filled.fill",
                title: "500 Daily AI Messages",
                description: "50x more than free plan for all your scheduling needs"
            )
            
            FeatureRow(
                icon: "photo.on.rectangle.angled",
                title: "20 Daily Image/PDF Uploads",
                description: "Analyze screenshots, PDFs, and photos with AI"
            )
            
            FeatureRow(
                icon: "mic.fill",
                title: "Voice Input",
                description: "Speak to create events and tasks instantly"
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
            // Screenshot mode - show fake products
            if screenshotMode {
                // Best value badge
                HStack {
                    Spacer()
                    Text("SAVE 49%")
                        .scaledFont(size: 12, weight: .bold)
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
                Button(action: { selectedPlanIndex = 0 }) {
                    HStack {
                        VStack(alignment: .leading, spacing: baseUnit / 2) {
                            Text("Monthly")
                                .scaledFont(size: 18, weight: .semibold)
                            Text("€12.99 / month")
                                .scaledFont(size: 14)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: selectedPlanIndex == 0 ? "checkmark.circle.fill" : "circle")
                            .scaledFont(size: 24)
                            .foregroundColor(selectedPlanIndex == 0 ? .accentColor : .secondary)
                    }
                    .padding(baseUnit * 2)
                    .background(
                        RoundedRectangle(cornerRadius: baseUnit * 1.5)
                            .stroke(selectedPlanIndex == 0 ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.ghost)
                
                // Annual option
                Button(action: { selectedPlanIndex = 1 }) {
                    HStack {
                        VStack(alignment: .leading, spacing: baseUnit / 2) {
                            Text("Annual")
                                .scaledFont(size: 18, weight: .semibold)
                            Text("€79.99 / year")
                                .scaledFont(size: 14)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: selectedPlanIndex == 1 ? "checkmark.circle.fill" : "circle")
                            .scaledFont(size: 24)
                            .foregroundColor(selectedPlanIndex == 1 ? .accentColor : .secondary)
                    }
                    .padding(baseUnit * 2)
                    .background(
                        RoundedRectangle(cornerRadius: baseUnit * 1.5)
                            .fill(selectedPlanIndex == 1 ? Color.accentColor.opacity(0.1) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: baseUnit * 1.5)
                                    .stroke(selectedPlanIndex == 1 ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(.ghost)
            }
            // Loading state
            else if subscriptionManager.products.isEmpty && subscriptionManager.isLoading {
                ProgressView("Loading products...")
                    .padding(.vertical, baseUnit * 4)
            } else if subscriptionManager.products.isEmpty {
                VStack(spacing: baseUnit) {
                    Image(systemName: "exclamationmark.triangle")
                        .scaledFont(size: 40)
                        .foregroundColor(.orange)
                    
                    Text("Products not available")
                        .font(.headline)
                    
                    Text("Please check your internet connection and try again.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    MomentumButton("Retry", icon: "arrow.clockwise", style: .secondary, size: .small) {
                        AsyncTask {
                            await subscriptionManager.loadProducts()
                        }
                    }
                    
                    Text("Bundle: \(Bundle.main.bundleIdentifier ?? "unknown")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    .padding(.top)
                }
                .padding(.vertical, baseUnit * 4)
            } else {
            // Best value badge
            if subscriptionManager.annualSavingsPercentage > 0 {
                HStack {
                    Spacer()
                    Text("SAVE \(subscriptionManager.annualSavingsPercentage)%")
                        .scaledFont(size: 12, weight: .bold)
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
            LoadingButton(
                action: purchase,
                isLoading: subscriptionManager.isLoading,
                style: .primary,
                size: .large
            ) {
                Text(purchaseButtonTitle)
            }
            .disabled(!screenshotMode && selectedProduct == nil)
            
            // Restore button
            MomentumButton("Restore Purchases", style: .tertiary, size: .medium) {
                restore()
            }
            .disabled(!screenshotMode && subscriptionManager.isLoading)
            
        }
        .padding(.top, baseUnit * 2)
    }
    
    // MARK: - Terms View
    
    private var termsView: some View {
        VStack(spacing: baseUnit * 1.5) {
            // More prominent legal links
            HStack(spacing: baseUnit * 3) {
                Link(destination: URL(string: "https://rubenreut.github.io/Planwise-legal/terms-of-service.html")!) {
                    Text("Terms of Service")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(.accentColor)
                        .underline()
                }
                
                Link(destination: URL(string: "https://rubenreut.github.io/Planwise-legal/privacy-policy.html")!) {
                    Text("Privacy Policy")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(.accentColor)
                        .underline()
                }
            }
            .padding(.vertical, baseUnit)
            .padding(.horizontal, baseUnit * 2)
            .background(
                RoundedRectangle(cornerRadius: baseUnit)
                    .fill(Color.accentColor.opacity(0.1))
            )
            
            Text("Subscriptions automatically renew unless cancelled")
                .scaledFont(size: 12)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Manage Subscriptions")
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.top, baseUnit * 2)
    }
    
    // MARK: - Computed Properties
    
    private var purchaseButtonTitle: String {
        if screenshotMode {
            return "Subscribe Now"
        }
        guard let product = selectedProduct else { return "Select a Plan" }
        
        return "Subscribe Now"
    }
    
    // MARK: - Actions
    
    private func purchase() {
        guard let product = selectedProduct else { return }
        
        AsyncTask {
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
        AsyncTask {
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
                .scaledFont(size: 24)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: baseUnit / 2) {
                Text(title)
                    .scaledFont(size: 16, weight: .semibold)
                
                Text(description)
                    .scaledFont(size: 14)
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
                            .scaledFont(size: 18, weight: .semibold)
                        
                        if isBestValue {
                            Text("Best Value")
                                .scaledFont(size: 11, weight: .bold)
                                .foregroundColor(.green)
                                .padding(.horizontal, baseUnit)
                                .padding(.vertical, baseUnit / 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(baseUnit)
                        }
                        
                    }
                    
                    Text(priceDescription)
                        .scaledFont(size: 14)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .scaledFont(size: 24)
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