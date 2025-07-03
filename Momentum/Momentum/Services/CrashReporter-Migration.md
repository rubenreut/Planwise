# CrashReporter Migration Guide

## Current Implementation

The CrashReporter is currently implemented with local file storage to allow the app to build and run without Firebase dependencies. All crash logs are stored in the app's Documents directory under `CrashLogs/`.

## Features Maintained

The local implementation maintains the exact same API as the Firebase version:
- Privacy-conscious crash reporting
- Breadcrumb logging
- Custom key-value pairs
- User tracking (anonymized)
- Performance metrics
- Automatic device and app info logging

## Migration to Firebase Crashlytics

When ready to integrate Firebase, follow these steps:

### 1. Add Firebase Dependencies

Add to your Podfile or Swift Package Manager:
```swift
// Swift Package Manager
.package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
```

### 2. Update CrashReporter.swift

Replace the local implementation with Firebase calls:

```swift
// At the top of the file
import FirebaseCrashlytics

// In the properties section
private let crashlytics = Crashlytics.crashlytics()

// In configure method
crashlytics.setCrashlyticsCollectionEnabled(enabled)

// In logError method
crashlytics.record(error: nsError, userInfo: context)

// In setCustomValue method
crashlytics.setCustomValue(value, forKey: key)

// In updateUserIdentifier method
crashlytics.setUserID(identifier)
```

### 3. Update MomentumApp.swift

Uncomment the Firebase configuration:
```swift
import FirebaseCore
import FirebaseAnalytics

// In init()
FirebaseApp.configure()
Analytics.setAnalyticsCollectionEnabled(analyticsEnabled)
```

### 4. Configure Firebase Project

1. Create a Firebase project at https://console.firebase.google.com
2. Add your iOS app with bundle ID: com.rubenreut.momentum
3. Download GoogleService-Info.plist and add to project
4. Enable Crashlytics in Firebase Console

### 5. Remove Local Storage Code

After confirming Firebase is working, you can remove:
- The local storage implementation methods
- The crash log directory setup
- The JSON file writing logic

## Local Crash Logs

While using the local implementation, crash logs can be accessed:

```swift
// Get all crash logs
let logs = CrashReporter.shared.getAllCrashLogs()

// Clear all logs
CrashReporter.shared.clearAllCrashLogs()
```

Logs are stored as JSON files with the format:
- `CRASH_[timestamp].json` - Fatal crashes
- `ERROR_[timestamp].json` - Non-fatal errors
- `CONFIG_[timestamp].json` - Configuration changes
- `PERF_[timestamp].json` - Performance issues

## Testing

The local implementation can be tested by:
1. Triggering errors in the app
2. Checking the Documents/CrashLogs directory
3. Using `CrashReporter.shared.testCrash()` in DEBUG builds

## Privacy

Both implementations respect user privacy:
- Crash reporting can be disabled via `configure(enabled: false)`
- User data can be cleared with `clearUserData()`
- Only anonymized user IDs are used
- No PII is collected