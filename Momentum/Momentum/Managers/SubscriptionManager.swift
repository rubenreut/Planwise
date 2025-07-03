import Foundation
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var messageCount: Int = 0
    @Published private(set) var remainingFreeMessages: Int = 10
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    
    // MARK: - Constants
    
    private let messageCountKey = "com.momentum.messageCount"
    private let firstLaunchKey = "com.momentum.firstLaunch"
    
    // Development mode - set to true for testing without StoreKit
    #if DEBUG
    private let isDevelopmentMode = false // Set to false to test real payments
    #else
    private let isDevelopmentMode = false
    #endif
    
    private let freeMessageLimit = 10
    
    // Product IDs - must match App Store Connect
    let monthlyProductID = "com.rubenreut.planwise.premium.monthly"
    let annualProductID = "com.rubenreut.planwise.premium.annual"
    
    private var updateListenerTask: Task<Void, Error>?
    
    // Type aliases to avoid ambiguity
    typealias Transaction = StoreKit.Transaction
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        loadMessageCount()
        checkFirstLaunch()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
            startTransactionListener()
            
            // In development mode, simulate premium access
            if isDevelopmentMode {
                print("🔧 Development mode enabled - simulating premium access")
                self.isPremium = true
            }
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Message Tracking
    
    private func loadMessageCount() {
        messageCount = UserDefaults.standard.integer(forKey: messageCountKey)
        remainingFreeMessages = max(0, freeMessageLimit - messageCount)
    }
    
    private func checkFirstLaunch() {
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) {
            // First launch - reset counter
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            UserDefaults.standard.set(0, forKey: messageCountKey)
            messageCount = 0
            remainingFreeMessages = freeMessageLimit
        }
    }
    
    func incrementMessageCount() {
        guard !isPremium else { return }
        
        messageCount += 1
        remainingFreeMessages = max(0, freeMessageLimit - messageCount)
        UserDefaults.standard.set(messageCount, forKey: messageCountKey)
        
        print("📊 Message count: \(messageCount)/\(freeMessageLimit)")
    }
    
    func canSendMessage() -> Bool {
        // In development mode, always allow sending
        if isDevelopmentMode {
            return true
        }
        return isPremium || messageCount < freeMessageLimit
    }
    
    func canUploadImage() -> Bool {
        // In development mode, always allow uploads
        if isDevelopmentMode {
            return true
        }
        return isPremium
    }
    
    // MARK: - StoreKit Integration
    
    func loadProducts() async {
        do {
            let productIDs = [monthlyProductID, annualProductID]
            print("🔍 Attempting to load products: \(productIDs)")
            
            products = try await Product.products(for: productIDs)
            
            // Sort products by price
            products.sort { $0.price < $1.price }
            
            print("💰 Loaded \(products.count) products")
            for product in products {
                print("  - \(product.displayName): \(product.displayPrice)")
            }
            
            if products.isEmpty {
                print("⚠️ No products loaded. Make sure:")
                print("   1. Products are configured in App Store Connect")
                print("   2. StoreKit Configuration file is set up for testing")
                print("   3. Bundle ID matches: \(Bundle.main.bundleIdentifier ?? "unknown")")
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
    }
    
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        defer { isLoading = false }
        
        print("🛒 Attempting to purchase: \(product.displayName)")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Check whether the transaction is verified
            let transaction = try checkVerified(verification)
            
            // Update purchase state
            await updatePurchasedProducts()
            
            // Always finish transactions
            await transaction.finish()
            
            print("✅ Purchase successful: \(product.displayName)")
            return transaction
            
        case .userCancelled:
            print("❌ User cancelled purchase")
            return nil
            
        case .pending:
            print("⏳ Purchase pending")
            return nil
            
        @unknown default:
            print("❓ Unknown purchase result")
            return nil
        }
    }
    
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        
        print("🔄 Restoring purchases...")
        
        try await AppStore.sync()
        await updatePurchasedProducts()
        
        print("✅ Restore complete. Premium status: \(isPremium)")
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var hasActiveSubscription = false
        
        // Check all current entitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
                
                switch transaction.productID {
                case monthlyProductID, annualProductID:
                    if transaction.revocationDate == nil && 
                       (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                        hasActiveSubscription = true
                    }
                default:
                    break
                }
            }
        }
        
        self.purchasedProductIDs = purchased
        self.isPremium = hasActiveSubscription
        
        print("🔐 Premium status updated: \(isPremium)")
        print("   Active subscriptions: \(purchased)")
    }
    
    private func startTransactionListener() {
        updateListenerTask = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await updatePurchasedProducts()
                    await transaction.finish()
                }
            }
        }
    }
    
    // MARK: - Subscription Info
    
    func getActiveSubscription() -> Product? {
        for product in products {
            if purchasedProductIDs.contains(product.id) && 
               (product.id == monthlyProductID || product.id == annualProductID) {
                return product
            }
        }
        return nil
    }
    
    func getSubscriptionExpirationDate() async -> Date? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == monthlyProductID || 
                   transaction.productID == annualProductID {
                    return transaction.expirationDate
                }
            }
        }
        return nil
    }
    
    // MARK: - Helpers
    
    var monthlyProduct: Product? {
        products.first { $0.id == monthlyProductID }
    }
    
    var annualProduct: Product? {
        products.first { $0.id == annualProductID }
    }
    
    
    var annualSavingsPercentage: Int {
        guard let monthly = monthlyProduct,
              let annual = annualProduct else { return 0 }
        
        let monthlyYearCost = monthly.price * 12
        let monthlyYearCostDecimal = NSDecimalNumber(decimal: monthly.price * 12).doubleValue
        let annualPriceDecimal = NSDecimalNumber(decimal: annual.price).doubleValue
        let savings = (monthlyYearCostDecimal - annualPriceDecimal) / monthlyYearCostDecimal
        return Int(savings * 100)
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    func debugEnablePremium() {
        print("🔧 DEBUG: Enabling premium access")
        isPremium = true
    }
    #endif
}

// MARK: - Error Types

enum StoreError: LocalizedError {
    case verificationFailed
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Purchase verification failed"
        case .productNotFound:
            return "Product not found"
        }
    }
}