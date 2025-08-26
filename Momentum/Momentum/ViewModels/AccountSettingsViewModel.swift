import SwiftUI
import StoreKit

/// Manages user account and subscription settings
@MainActor
class AccountSettingsViewModel: ObservableObject {
    // MARK: - Profile Settings
    @AppStorage("userName") var userName = "Momentum User"
    @AppStorage("userAvatar") var userAvatar = "person.circle.fill"
    
    // MARK: - Published Properties
    @Published var showingProfileEditor = false
    @Published var isRestoringPurchases = false
    @Published var showingRestoreAlert = false
    @Published var restoreMessage = ""
    
    // MARK: - Dependencies
    let subscriptionManager = SubscriptionManager.shared
    
    // MARK: - Avatar Options
    let avatarOptions = [
        "person.circle.fill",
        "person.crop.circle.fill",
        "person.crop.square.fill",
        "face.smiling.fill",
        "star.circle.fill",
        "moon.circle.fill",
        "sun.max.circle.fill",
        "bolt.circle.fill",
        "flame.circle.fill",
        "leaf.circle.fill",
        "pawprint.circle.fill",
        "heart.circle.fill"
    ]
    
    // MARK: - Methods
    
    func restorePurchases() async {
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }
        
        do {
            try await AppStore.sync()
            // Subscription status automatically updated via AppStore.sync()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }
    
    func requestAppReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    
    func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    var subscriptionStatusText: String {
        if subscriptionManager.isPremium {
            // TODO: Get expiration date if needed
            return "Premium Active"
        } else {
            return "Free Plan"
        }
    }
    
    var subscriptionBadgeColor: Color {
        subscriptionManager.isPremium ? .green : .gray
    }
}