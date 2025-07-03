# DANGER ZONES - NEVER MODIFY WITHOUT EXPLICIT PERMISSION

## ⚠️ CRITICAL IDENTIFIERS ⚠️

### Bundle & App IDs
```
Bundle ID: com.rubnereut.momentum
App Group: group.com.rubnereut.productivity
Team ID: [YOUR_TEAM_ID]
```

### CloudKit Configuration
```
Container ID: iCloud.com.rubnereut.ecosystem
NOT: iCloud.com.rubnereut.momentum (this would break future integration)

Development Container: iCloud.com.rubnereut.ecosystem
Production Container: iCloud.com.rubnereut.ecosystem
(Same for both - this is intentional)
```

### Core Data
```
Model Name: Momentum.xcdatamodeld
Current Version: 1.0
Store Name: Momentum.sqlite

NEVER:
- Delete the model file
- Remove existing attributes
- Rename entities or attributes
- Change attribute types
```

## 🔑 API ENDPOINTS & KEYS

### OpenAI
```
Production Endpoint: https://api.openai.com/v1/chat/completions
Model: gpt-4
Temperature: 0.7
Max Tokens: 500

Key Storage: Keychain Service Name: "com.rubnereut.momentum"
Key Name: "OpenAIAPIKey"
```

### RevenueCat (When Added)
```
API Key: Stored in Info.plist as "RevenueCatAPIKey"
Entitlements: ["premium"]
```

## 🚨 CRITICAL FILES - DO NOT MODIFY

### ScheduleManager.swift
- Contains ALL business logic for events
- Single source of truth
- Modifying breaks entire app

### CloudKitManager.swift
- Handles ALL sync logic
- Contains conflict resolution
- Breaking this loses user data

### Event+CoreDataClass.swift
- Generated file - NEVER edit manually
- Regenerate through Core Data model only

## ⚛️ STATE MANAGEMENT

### UserDefaults Keys
```
"hasCompletedOnboarding" - Bool
"lastSyncDate" - Date
"todayAIRequestCount" - Int
"lastAIRequestDate" - Date
"selectedTheme" - String
"premiumExpiryDate" - Date
```

### Keychain Keys
```
"OpenAIAPIKey" - String
"UserPremiumStatus" - Bool
"CloudKitUserID" - String
```

## 🔄 BUILD CONFIGURATIONS

### Debug
```
- Uses development provisioning
- CloudKit development environment
- Verbose logging enabled
- DEBUG flag set
```

### Release
```
- Uses distribution provisioning
- CloudKit production environment
- Minimal logging
- Optimizations enabled
```

### TestFlight
```
- Uses distribution provisioning
- CloudKit production environment
- Crash reporting enabled
- Beta analytics enabled
```

## ❌ NEVER DO THESE

1. **Change CloudKit Schema in Production**
   - Always add new fields as optional
   - Never delete fields
   - Test in development first

2. **Modify Core Data Without Migration**
   - Always create new model version
   - Write migration mapping
   - Test with existing data

3. **Store Sensitive Data in Code**
   - API keys → Keychain
   - User data → Core Data/CloudKit
   - Passwords → Never store

4. **Create Duplicate Endpoints**
   - Check existing services first
   - Reuse instead of recreate
   - Update documentation

5. **Force Unwrap Optionals in Critical Paths**
   - Always use guard let or if let
   - Provide fallback behavior
   - Log errors properly

## 🚀 DEPLOYMENT CHECKLIST

Before ANY deployment:
1. Verify bundle ID matches App Store Connect
2. Check CloudKit container is production
3. Ensure API keys are in Keychain (not code)
4. Test Core Data migration if schema changed
5. Verify all assets are included
6. Check privacy permissions in Info.plist

## 🆘 EMERGENCY PROCEDURES

### If CloudKit Sync Breaks:
1. Check container ID in DANGER_ZONES.md
2. Verify user is signed into iCloud
3. Check CloudKit Dashboard for server issues
4. Enable verbose logging in CloudKitManager

### If AI Stops Working:
1. Check API key in Keychain
2. Verify rate limits not exceeded
3. Check OpenAI service status
4. Review FAILURE_LOG.md for patterns

### If App Crashes on Launch:
1. Check Core Data model version
2. Verify all required fields have values
3. Check Info.plist for missing keys
4. Review crash logs in Xcode

## 📝 MODIFICATION PROTOCOL

To modify anything in this file:
1. Create backup of current working version
2. Document reason for change
3. Test in development environment
4. Get approval from senior dev/yourself
5. Update all related documentation
6. Test again before committing