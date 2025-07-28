import Foundation

// MARK: - App Store Configuration

struct AppStoreConfiguration {
    // Bundle and App IDs
    static let bundleID = "com.rubenreut.momentum"
    static let appID = "6748081658"
    
    // In-App Purchase Product IDs
    struct Products {
        static let monthlySubscription = "com.rubenreut.planwise.pro.monthly"
        static let annualSubscription = "com.rubenreut.planwise.pro.annual"
        // static let lifetimePurchase = "com.rubenreut.planwise.premium.lifetime" // Not configured yet
    }
    
    // Subscription Details (matching App Store Connect)
    struct Subscriptions {
        static let monthlyPrice = "€12.99"  // Planwise Pro (1 Month)
        static let annualPrice = "€79.99"   // Planwise Pro (1 Year)
        // static let lifetimePrice = "$149.99" // Not configured in App Store Connect
        
        static let monthlyDuration = "1 Month"
        static let annualDuration = "1 Year"
        
        // Free trial configuration
        static let freeTrialDays = 7  // No free trial shown in App Store Connect
        static let freeMessageLimit = 10
    }
    
    // App Store Metadata
    struct Metadata {
        static let appName = "Planwise"
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
 
# Planwise - AI Scheduler

Transform your productivity with Planwise, the intelligent scheduling assistant that understands how you work.

## Why Planwise?

Planwise combines the power of AI with beautiful time-blocking to help you:
• Create perfect daily schedules in seconds
• Never miss important tasks or appointments
• Balance work and personal time effortlessly
• Stay organized and focused

## Key Features

**AI-Powered Scheduling**
Simply tell Planwise what you need to do, and it creates your schedule instantly with natural conversation.

**Natural Language Input**
"Schedule a 2-hour deep work session tomorrow morning" - Planwise understands and acts instantly.

**Smart Time Blocking**
Visual timeline shows your entire day at a glance with beautiful, color-coded blocks.

**Voice & Vision Input**
Speak your schedule or upload screenshots of calendars and to-do lists - Planwise understands it all.

**CloudKit Sync**
Your schedule syncs seamlessly across all your Apple devices.

## Premium Features

• 500 daily AI messages (50x more than free)
• 20 daily image/PDF uploads  
• Voice input for hands-free scheduling
• Priority support
• All future features included

## Subscription Options

• Monthly: $9.99/month
• Annual: $79.99/year (save 33%)
• Lifetime: $149.99 one-time

New users get 10 free AI messages to try Planwise.

## Privacy First

Your data stays on your device and in your private iCloud. We never see your schedule or conversations.

## Get Started

Download Planwise today and experience the future of scheduling. Your perfect day is just a conversation away.

---

Version 1.0 - Initial Release
• AI-powered scheduling
• Natural language processing
• Time blocking interface
• CloudKit sync
• Dark mode support

*/