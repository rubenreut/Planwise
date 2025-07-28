import Foundation
import StoreKit
import SwiftUI

// Using global AsyncTask typealias to avoid naming conflict with Core Data Task entity

@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var messageCount: Int = 0
    @Published private(set) var imageMessageCount: Int = 0
    @Published private(set) var remainingFreeMessages: Int = 10
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    
    // MARK: - Constants
    
    private let messageCountKey = "com.planwise.messageCount"
    private let imageCountKey = "com.planwise.imageCount"
    private let firstLaunchKey = "com.planwise.firstLaunch"
    
    // Development mode - set to true for testing without StoreKit
    #if DEBUG
    private let isDevelopmentMode = false // Set to false to test real payments
    // For sandbox testing
    private let isSandboxEnvironment = true
    #else
    private let isDevelopmentMode = false
    private let isSandboxEnvironment = false
    #endif
    
    // Debug mode for comprehensive logging
    private let debugStoreKit = true
    
    // Simple package limits
    private let freeMessageLimit = 10
    private let freeImageLimit = 0
    
    // Entity limits for free users
    private let freeEventLimitPerDay = 3
    private let freeHabitLimit = 3
    private let freeTaskLimit = 3
    private let freeGoalLimit = 3
    
    // Premium package: balanced mix
    private let premiumTextMessageLimit = 500    // Regular text chats
    private let premiumImageMessageLimit = 20    // Images/PDFs per day
    
    // Product IDs - must match App Store Connect
    let monthlyProductID = "com.rubenreut.planwise.pro.monthly"
    let annualProductID = "com.rubenreut.planwise.pro.annual"
    
    private var updateListenerTask: _Concurrency.Task<Void, Error>?
    
    // Type aliases to avoid ambiguity
    typealias Transaction = StoreKit.Transaction
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        
        if debugStoreKit {
            #if DEBUG
            print("\n🚀 INITIALIZING SubscriptionManager")
            print("🔍 App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
            print("🔍 Build Number: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")")
            #endif
        }
        
        loadMessageCount()
        checkFirstLaunch()
        resetDailyUsageIfNeeded()
        
        AsyncTask {
            if debugStoreKit {
                #if DEBUG
                print("\n🔍 Starting async initialization...")
                #endif
            }
            
            // Add delay to ensure StoreKit is ready
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await loadProducts()
            await updatePurchasedProducts()
            startTransactionListener()
            
            // In development mode, simulate premium access
            if isDevelopmentMode {
                self.isPremium = true
                if debugStoreKit {
                    #if DEBUG
                    print("\n⚠️ Development Mode: Premium access simulated")
                    #endif
                }
            }
            
            if debugStoreKit {
                #if DEBUG
                print("\n✅ SubscriptionManager initialization complete")
                #endif
            }
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Message Tracking
    
    private func loadMessageCount() {
        messageCount = UserDefaults.standard.integer(forKey: messageCountKey)
        imageMessageCount = UserDefaults.standard.integer(forKey: imageCountKey)
        remainingFreeMessages = max(0, freeMessageLimit - messageCount)
        
        // Reset daily counts if new day
        resetDailyUsageIfNeeded()
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
    
    func incrementMessageCount(isImageMessage: Bool = false, imageCount: Int = 1) {
        let dateKey = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        
        if isImageMessage {
            imageMessageCount += imageCount
            UserDefaults.standard.set(imageMessageCount, forKey: "imageCount_\(dateKey)")
        } else {
            messageCount += 1
            UserDefaults.standard.set(messageCount, forKey: "messageCount_\(dateKey)")
        }
        
        // Update remaining for free users
        if !isPremium {
            remainingFreeMessages = max(0, freeMessageLimit - messageCount)
        }
    }
    
    func resetDailyUsageIfNeeded() {
        let dateKey = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let lastResetKey = "lastUsageReset"
        
        if let lastReset = UserDefaults.standard.string(forKey: lastResetKey), lastReset != dateKey {
            // New day, reset daily counters
            messageCount = 0
            imageMessageCount = 0
            remainingFreeMessages = freeMessageLimit
            
            UserDefaults.standard.set(dateKey, forKey: lastResetKey)
        } else {
            // Load today's usage from UserDefaults
            messageCount = UserDefaults.standard.integer(forKey: "messageCount_\(dateKey)")
            imageMessageCount = UserDefaults.standard.integer(forKey: "imageCount_\(dateKey)")
        }
    }
    
    // MARK: - Convenience Properties
    
    var imageLimit: Int {
        return isPremium ? premiumImageMessageLimit : 0
    }
    
    var remainingTextMessages: Int {
        if isPremium {
            return max(0, premiumTextMessageLimit - messageCount)
        } else {
            return remainingFreeMessages
        }
    }
    
    var remainingImageMessages: Int {
        if isPremium {
            return max(0, premiumImageMessageLimit - imageMessageCount)
        } else {
            return 0
        }
    }
    
    var dailyLimitDescription: String {
        if isPremium {
            return "\(remainingTextMessages) texts, \(remainingImageMessages) images remaining today"
        } else {
            return "\(remainingFreeMessages) free messages remaining"
        }
    }
    
    func canSendMessage(withImage: Bool = false, imageCount: Int = 1) -> Bool {
        // In development mode, always allow sending
        if isDevelopmentMode {
            return true
        }
        
        if isPremium {
            // Premium users have daily limits
            if withImage {
                return (imageMessageCount + imageCount) <= premiumImageMessageLimit
            } else {
                return messageCount < premiumTextMessageLimit
            }
        } else {
            // Free users
            if withImage {
                return false // No image uploads for free users
            } else {
                return messageCount < freeMessageLimit
            }
        }
    }
    
    func canUploadImage() -> Bool {
        // In development mode, always allow uploads
        if isDevelopmentMode {
            return true
        }
        return isPremium
    }
    
    // MARK: - Entity Limit Checking
    
    func canCreateEvent(currentCount: Int) -> Bool {
        if isPremium || isDevelopmentMode {
            return true
        }
        // For free users, check daily event limit
        return currentCount < freeEventLimitPerDay
    }
    
    func canCreateHabit(currentCount: Int) -> Bool {
        if isPremium || isDevelopmentMode {
            return true
        }
        return currentCount < freeHabitLimit
    }
    
    func canCreateTask(currentCount: Int) -> Bool {
        if isPremium || isDevelopmentMode {
            return true
        }
        return currentCount < freeTaskLimit
    }
    
    func canCreateGoal(currentCount: Int) -> Bool {
        if isPremium || isDevelopmentMode {
            return true
        }
        return currentCount < freeGoalLimit
    }
    
    var entityLimitsDescription: String {
        if isPremium {
            return "Unlimited events, tasks, habits & goals"
        } else {
            return "Limited to \(freeEventLimitPerDay) events/day, \(freeTaskLimit) tasks, \(freeHabitLimit) habits, \(freeGoalLimit) goals"
        }
    }
    
    // MARK: - StoreKit Integration
    
    func loadProducts() async {
        if debugStoreKit {
            #if DEBUG
            print("\n🔍 DEBUG: Starting loadProducts()")
            print("🔍 Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
            print("🔍 Is Development Mode: \(isDevelopmentMode)")
            print("🔍 Is Sandbox Environment: \(isSandboxEnvironment)")
            print("🔍 Product IDs to load:")
            print("   - Monthly: \(monthlyProductID)")
            print("   - Annual: \(annualProductID)")
            #endif
        }
        
        do {
            let productIDs = [monthlyProductID, annualProductID]
            
            if debugStoreKit {
                #if DEBUG
                print("\n🔍 Calling Product.products(for:) with IDs: \(productIDs)")
                #endif
            }
            
            // Check if StoreKit is available
            products = try await Product.products(for: productIDs)
            
            // Sort products by price
            products.sort { $0.price < $1.price }
            
            if debugStoreKit {
                #if DEBUG
                print("\n✅ Successfully loaded \(products.count) products:")
                for (index, product) in products.enumerated() {
                    print("\n📱 Product \(index + 1):")
                    print("   ID: \(product.id)")
                    print("   Display Name: \(product.displayName)")
                    print("   Display Price: \(product.displayPrice)")
                    print("   Description: \(product.description)")
                    print("   Price: \(product.price)")
                    print("   Type: \(product.type.rawValue)")
                    if let subscription = product.subscription {
                        print("   Subscription Period: \(subscription.subscriptionPeriod.unit) - \(subscription.subscriptionPeriod.value)")
                    }
                }
                #endif
            }
            
            if products.isEmpty {
                if debugStoreKit {
                    #if DEBUG
                    print("\n⚠️ WARNING: No products loaded!")
                    print("🔍 Possible reasons:")
                    print("   1. Product IDs don't match App Store Connect")
                    print("   2. Products not approved/available in App Store Connect")
                    print("   3. StoreKit configuration file not properly linked")
                    print("   4. Network connectivity issues")
                    print("   5. Sandbox account issues")
                    
                    // Try to get more info
                    print("\n🔍 Checking StoreKit configuration:")
                    print("   Build Configuration: \(getCurrentBuildConfiguration())")
                    #endif
                }
            }
        } catch {
            if debugStoreKit {
                #if DEBUG
                print("\n❌ ERROR: Failed to load products")
                print("   Error Type: \(type(of: error))")
                print("   Error Description: \(error.localizedDescription)")
                print("   Full Error: \(error)")
                
                // Check for specific StoreKit errors
                if let skError = error as? StoreKitError {
                    print("\n🔍 StoreKit Error Details:")
                    switch skError {
                    case .networkError(let urlError):
                        print("   Network Error: \(urlError)")
                    case .systemError(let systemError):
                        print("   System Error: \(systemError)")
                    case .userCancelled:
                        print("   User Cancelled")
                    case .notAvailableInStorefront:
                        print("   Not Available in Storefront")
                    case .notEntitled:
                        print("   Not Entitled")
                    default:
                        print("   Unknown StoreKit Error: \(skError)")
                    }
                }
                #endif
            }
        }
    }
    
    private func getCurrentBuildConfiguration() -> String {
        #if DEBUG
        return "Debug"
        #else
        return "Release"
        #endif
    }
    
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        defer { isLoading = false }
        
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Check whether the transaction is verified
            let transaction = try checkVerified(verification)
            
            // Update purchase state
            await updatePurchasedProducts()
            
            // Always finish transactions
            await transaction.finish()
            
            return transaction
            
        case .userCancelled:
            return nil
            
        case .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        
        
        try await AppStore.sync()
        await updatePurchasedProducts()
        
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
        if debugStoreKit {
            #if DEBUG
            print("\n🔍 DEBUG: Updating purchased products...")
            #endif
        }
        
        var purchased: Set<String> = []
        var hasActiveSubscription = false
        var entitlementCount = 0
        
        // Check all current entitlements
        for await result in Transaction.currentEntitlements {
            entitlementCount += 1
            
            switch result {
            case .verified(let transaction):
                if debugStoreKit {
                    #if DEBUG
                    print("\n✅ Verified Transaction:")
                    print("   Product ID: \(transaction.productID)")
                    print("   Purchase Date: \(transaction.purchaseDate)")
                    print("   Expiration Date: \(transaction.expirationDate?.description ?? "None")")
                    print("   Revocation Date: \(transaction.revocationDate?.description ?? "None")")
                    print("   Transaction ID: \(transaction.id)")
                    #endif
                }
                
                purchased.insert(transaction.productID)
                
                switch transaction.productID {
                case monthlyProductID, annualProductID:
                    if transaction.revocationDate == nil && 
                       (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                        hasActiveSubscription = true
                        if debugStoreKit {
                            #if DEBUG
                            print("   ✅ Active subscription found!")
                            #endif
                        }
                    } else {
                        if debugStoreKit {
                            #if DEBUG
                            print("   ❌ Subscription expired or revoked")
                            #endif
                        }
                    }
                default:
                    if debugStoreKit {
                        #if DEBUG
                        print("   ⚠️ Unknown product ID: \(transaction.productID)")
                        #endif
                    }
                }
                
            case .unverified(let transaction, let error):
                if debugStoreKit {
                    #if DEBUG
                    print("\n❌ Unverified Transaction:")
                    print("   Product ID: \(transaction.productID)")
                    print("   Verification Error: \(error)")
                    #endif
                }
            }
        }
        
        if debugStoreKit {
            #if DEBUG
            print("\n🔍 Transaction Summary:")
            print("   Total Entitlements: \(entitlementCount)")
            print("   Purchased Product IDs: \(purchased)")
            print("   Has Active Subscription: \(hasActiveSubscription)")
            #endif
        }
        
        self.purchasedProductIDs = purchased
        self.isPremium = hasActiveSubscription
    }
    
    private func startTransactionListener() {
        updateListenerTask = _Concurrency.Task {
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
        // Hardcode to 49% until App Store Connect prices are fixed
        return 49
        
        // Original calculation (uncomment when prices are fixed in App Store Connect)
        /*
        guard let monthly = monthlyProduct,
              let annual = annualProduct else { return 0 }
        
        let monthlyYearCost = monthly.price * 12
        let monthlyYearCostDecimal = NSDecimalNumber(decimal: monthly.price * 12).doubleValue
        let annualPriceDecimal = NSDecimalNumber(decimal: annual.price).doubleValue
        let savings = (monthlyYearCostDecimal - annualPriceDecimal) / monthlyYearCostDecimal
        return Int(savings * 100)
        */
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    func debugEnablePremium() {
        isPremium = true
    }
    
    func debugCheckStoreKitStatus() async {
        print("\n🔍 =================")
        print("🔍 STOREKIT DEBUG CHECK")
        print("🔍 =================")
        
        // Check environment
        print("\n📱 Environment:")
        print("   Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("   Build Config: \(getCurrentBuildConfiguration())")
        print("   Is Sandbox: \(isSandboxEnvironment)")
        
        // Check if running on device vs simulator
        #if targetEnvironment(simulator)
        print("   Running on: Simulator")
        #else
        print("   Running on: Physical Device")
        #endif
        
        // Check product configuration
        print("\n📦 Product Configuration:")
        print("   Monthly ID: \(monthlyProductID)")
        print("   Annual ID: \(annualProductID)")
        
        // Check current status
        print("\n💰 Current Status:")
        print("   Products Loaded: \(products.count)")
        print("   Is Premium: \(isPremium)")
        print("   Purchased IDs: \(purchasedProductIDs)")
        
        // Try to reload products
        print("\n🔄 Attempting to reload products...")
        await loadProducts()
        
        // Check App Store Server connectivity
        print("\n🌐 Checking App Store connectivity...")
        do {
            let testProductIDs = ["com.test.invalid.product"]
            let testProducts = try await Product.products(for: testProductIDs)
            print("   ✅ StoreKit is responsive (returned \(testProducts.count) products for test)")
        } catch {
            print("   ❌ StoreKit connectivity issue: \(error)")
        }
        
        print("\n🔍 Debug check complete")
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