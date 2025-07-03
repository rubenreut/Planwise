import Foundation

// MARK: - App Store Configuration

struct AppStoreConfiguration {
    // Bundle and App IDs
    static let bundleID = "com.rubenreut.momentum"
    static let appID = "" // Will be assigned by App Store Connect
    
    // In-App Purchase Product IDs
    struct Products {
        static let monthlySubscription = "com.rubenreut.momentum.premium.monthly"
        static let annualSubscription = "com.rubenreut.momentum.premium.annual"
        static let lifetimePurchase = "com.rubenreut.momentum.premium.lifetime"
    }
    
    // Subscription Details
    struct Subscriptions {
        static let monthlyPrice = "$9.99"
        static let annualPrice = "$79.99"
        static let lifetimePrice = "$149.99"
        
        static let monthlyDuration = "1 Month"
        static let annualDuration = "1 Year"
        
        // Free trial configuration
        static let freeTrialDays = 7
        static let freeMessageLimit = 10
    }
    
    // App Store Metadata
    struct Metadata {
        static let appName = "Momentum - AI Scheduler"
        static let subtitle = "Smart Time Blocking with AI"
        
        static let keywords = [
            "ai",
            "scheduler",
            "calendar",
            "productivity",
            "time blocking",
            "assistant",
            "planner",
            "schedule",
            "chatgpt",
            "time management"
        ]
        
        static let primaryCategory = "Productivity"
        static let secondaryCategory = "Business"
        
        static let supportURL = URL(string: "https://rubenreut.github.io/Planwise-legal/privacy-policy.html")! // Using privacy page as support for now
        static let privacyPolicyURL = URL(string: "https://rubenreut.github.io/Planwise-legal/privacy-policy.html")!
        static let termsOfServiceURL = URL(string: "https://rubenreut.github.io/Planwise-legal/terms-of-service.html")!
    }
    
    // Review Prompts
    struct Review {
        static let minimumActionsBeforePrompt = 10
        static let minimumDaysBeforePrompt = 3
        static let daysBetweenPrompts = 60
    }
}

// MARK: - App Store Description Template

/*
 
# Momentum - AI Scheduler

Transform your productivity with Momentum, the intelligent scheduling assistant that understands how you work.

## Why Momentum?

Momentum combines the power of AI with beautiful time-blocking to help you:
• Create perfect daily schedules in seconds
• Never miss important tasks or appointments
• Balance work and personal time effortlessly
• Track your productivity patterns

## Key Features

**AI-Powered Scheduling**
Simply tell Momentum what you need to do, and it creates an optimized schedule based on your preferences and patterns.

**Natural Language Input**
"Schedule a 2-hour deep work session tomorrow morning" - Momentum understands and acts instantly.

**Smart Time Blocking**
Visual timeline shows your entire day at a glance with beautiful, color-coded blocks.

**Intelligent Suggestions**
Momentum learns your habits and suggests the best times for different activities.

**CloudKit Sync**
Your schedule syncs seamlessly across all your Apple devices.

## Premium Features

• Unlimited AI interactions
• Photo and screenshot analysis
• Advanced analytics
• Priority support

## Subscription Options

• Monthly: $9.99/month
• Annual: $79.99/year (save 33%)
• Lifetime: $149.99 one-time

New users get 10 free AI messages to try Momentum.

## Privacy First

Your data stays on your device and in your private iCloud. We never see your schedule or conversations.

## Get Started

Download Momentum today and experience the future of scheduling. Your perfect day is just a conversation away.

---

Version 1.0 - Initial Release
• AI-powered scheduling
• Natural language processing
• Time blocking interface
• CloudKit sync
• Dark mode support

*/