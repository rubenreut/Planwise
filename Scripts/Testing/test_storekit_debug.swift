#!/usr/bin/env swift

import Foundation

print("StoreKit Debug Information")
print("=========================")

// Check bundle ID
let bundleID = Bundle.main.bundleIdentifier ?? "Unknown"
print("Bundle ID: \(bundleID)")

// Check if running on device vs simulator
#if targetEnvironment(simulator)
print("Environment: Simulator")
#else
print("Environment: Physical Device")
#endif

// Check build configuration
#if DEBUG
print("Build Configuration: Debug")
#else
print("Build Configuration: Release")
#endif

// Product IDs
let monthlyProductID = "com.rubenreut.planwise.pro.monthly"
let annualProductID = "com.rubenreut.planwise.pro.annual"

print("\nProduct IDs:")
print("- Monthly: \(monthlyProductID)")
print("- Annual: \(annualProductID)")

print("\nRecommendations:")
print("1. Ensure products in App Store Connect match these IDs exactly")
print("2. Make sure products are in 'Ready to Submit' or 'Approved' status")
print("3. Check that your Apple ID has proper permissions")
print("4. Verify you're signed into the correct sandbox account on device")
print("5. Try Settings > App Store > Sandbox Account on device")