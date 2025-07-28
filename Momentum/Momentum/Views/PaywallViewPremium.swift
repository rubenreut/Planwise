import SwiftUI
import StoreKit

struct PaywallViewPremium: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: PricingPlan = .annual
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var animateGradient = false
    
    enum PricingPlan: String, CaseIterable {
        case annual = "annual"
        case monthly = "monthly"
        
        var displayName: String {
            switch self {
            case .monthly: return "Monthly"
            case .annual: return "Best Value"
            }
        }
        
        var productId: String {
            switch self {
            case .monthly: return "com.rubenreut.planwise.pro.monthly"
            case .annual: return "com.rubenreut.planwise.pro.annual"
            }
        }
        
        var features: [String] {
            return [
                "✓ Unlimited everything",
                "✓ AI assistant included", 
                "✓ Priority support",
                "✓ Cancel anytime"
            ]
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    closeButton
                    headerSection
                    pricingCardsSection
                    ctaSection
                    trustBadgesSection
                    termsSection
                }
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemBackground))
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
            }
        }
        .padding(.horizontal)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Smaller animated icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .scaleEffect(animateGradient ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                        value: animateGradient
                    )
                
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.blue)
            }
            .frame(height: 60)
            .onAppear { animateGradient = true }
            
            VStack(spacing: 6) {
                Text("Go Premium Today")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Join thousands achieving more")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 10)
    }
    
    private var pricingCardsSection: some View {
        VStack(spacing: 16) {
            ForEach(PricingPlan.allCases, id: \.self) { plan in
                PricingCard(
                    plan: plan,
                    isSelected: selectedPlan == plan,
                    action: { selectedPlan = plan },
                    subscriptionManager: subscriptionManager
                )
            }
        }
        .padding(.horizontal)
    }
    
    
    private var ctaSection: some View {
        VStack(spacing: 16) {
            Button(action: purchase) {
                HStack {
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue with \(selectedPlan.displayName)")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(subscriptionManager.isLoading)
            
            Button(action: restore) {
                Text("Restore Purchases")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .disabled(subscriptionManager.isLoading)
        }
        .padding(.horizontal)
    }
    
    private var trustBadgesSection: some View {
        TrustBadgesView()
    }
    
    private var termsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                Link("Terms", destination: URL(string: "https://rubenreut.github.io/Planwise-legal/terms-of-service.html")!)
                Link("Privacy", destination: URL(string: "https://rubenreut.github.io/Planwise-legal/privacy-policy.html")!)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
            
            Text("Cancel anytime • Renews automatically")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.bottom, 40)
    }
    
    private func purchase() {
        let productId = selectedPlan == .monthly ? "com.rubenreut.planwise.pro.monthly" : "com.rubenreut.planwise.pro.annual"
        guard let product = subscriptionManager.products.first(where: { $0.id == productId }) else {
            errorMessage = "Product not found"
            showingError = true
            return
        }
        
        _Concurrency.Task {
            do {
                try await subscriptionManager.purchase(product)
                await MainActor.run {
                    if subscriptionManager.isPremium {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func restore() {
        _Concurrency.Task {
            do {
                try await subscriptionManager.restorePurchases()
                await MainActor.run {
                    if subscriptionManager.isPremium {
                        dismiss()
                    } else {
                        errorMessage = "No purchases found to restore"
                        showingError = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Pricing Card

struct PricingCard: View {
    let plan: PaywallViewPremium.PricingPlan
    let isSelected: Bool
    let action: () -> Void
    let subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                content
                    .padding(20)
                    .background(cardBackground)
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.1) : Color.black.opacity(0.05),
                        radius: isSelected ? 12 : 8,
                        x: 0,
                        y: 4
                    )
                    .scaleEffect(isSelected ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
                
                // Most Popular badge for annual
                if plan == .annual {
                    Text("MOST POPULAR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(4)
                        .offset(x: -10, y: -10)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            // Features are now in the header for compactness
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                titleRow
                priceRow
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundColor(isSelected ? .blue : .secondary.opacity(0.5))
        }
    }
    
    private var titleRow: some View {
        HStack {
            Text(plan.displayName)
                .font(.system(size: 20, weight: .semibold))
            
            if let savings = calculateSavings() {
                Text(savings)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.green)
                    )
            }
        }
    }
    
    private var priceRow: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(priceString)
                .font(.system(size: 28, weight: .bold))
            Text(periodString)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
    
    private var priceString: String {
        if let product = subscriptionManager.products.first(where: { $0.id == plan.productId }) {
            return product.displayPrice
        }
        // Fallback prices
        return plan == .monthly ? "€12.99" : "€79.99"
    }
    
    private var periodString: String {
        if let product = subscriptionManager.products.first(where: { $0.id == plan.productId }) {
            let period = product.subscription?.subscriptionPeriod
            if period?.unit == .year {
                // Calculate monthly price for annual
                let monthlyPrice = product.price / 12
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.locale = product.priceFormatStyle.locale
                let monthlyString = formatter.string(from: monthlyPrice as NSNumber) ?? ""
                return "per year • \(monthlyString)/mo"
            }
            return "per month"
        }
        // Fallback
        return plan == .monthly ? "per month" : "per year • €6.67/mo"
    }
    
    private func calculateSavings() -> String? {
        guard plan == .annual,
              let annualProduct = subscriptionManager.products.first(where: { $0.id == plan.productId }),
              let monthlyProduct = subscriptionManager.products.first(where: { $0.id == PaywallViewPremium.PricingPlan.monthly.productId }) else {
            return plan == .annual ? "SAVE 49%" : nil
        }
        
        let annualPrice = NSDecimalNumber(decimal: annualProduct.price)
        let monthlyYearlyPrice = NSDecimalNumber(decimal: monthlyProduct.price * 12)
        let savingsDecimal = monthlyYearlyPrice.subtracting(annualPrice).dividing(by: monthlyYearlyPrice).multiplying(by: NSDecimalNumber(value: 100))
        let savingsInt = Int(savingsDecimal.doubleValue)
        
        return "SAVE \(savingsInt)%"
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(plan.features, id: \.self) { feature in
                featureRow(feature)
            }
        }
    }
    
    private func featureRow(_ feature: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.green)
            
            Text(feature)
                .font(.system(size: 14))
                .foregroundColor(.primary.opacity(0.9))
            
            Spacer()
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }
}

// MARK: - Features Comparison

struct FeaturesComparisonView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let features = [
        ("Events per day", ["3", "Unlimited"]),
        ("Tasks limit", ["3", "Unlimited"]),
        ("Habits limit", ["3", "Unlimited"]),
        ("Goals limit", ["3", "Unlimited"]),
        ("AI Messages daily", ["10", "500"]),
        ("Image/PDF uploads", ["0", "20"]),
        ("Voice input", ["-", "✓"]),
        ("Priority support", ["-", "✓"])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compare Plans")
                .font(.system(size: 20, weight: .semibold))
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Features")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Free")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 80)
                    
                    Text("Premium")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 80)
                }
                
                Divider()
                
                // Features
                ForEach(features, id: \.0) { feature in
                    HStack {
                        Text(feature.0)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach(0..<2) { index in
                            Text(feature.1[index])
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(feature.1[index] == "-" ? .secondary.opacity(0.5) : .primary)
                                .frame(width: 80)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.tertiarySystemBackground) : Color.gray.opacity(0.05))
            )
        }
    }
}

// MARK: - Trust Badges

struct TrustBadgesView: View {
    var body: some View {
        HStack(spacing: 32) {
            TrustBadge(icon: "lock.fill", text: "Secure\nPayment")
            TrustBadge(icon: "arrow.triangle.2.circlepath", text: "Cancel\nAnytime")
        }
        .padding(.vertical, 20)
    }
}

struct TrustBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PaywallViewPremium()
}