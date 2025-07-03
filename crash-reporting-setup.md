# Crash Reporting Setup Documentation

## Overview
Momentum uses Firebase Crashlytics for comprehensive crash reporting and error tracking. The implementation follows iOS privacy best practices with user-controlled data collection.

## Architecture

### Components
1. **CrashReporter Service** (`Services/CrashReporter.swift`)
   - Singleton wrapper around Firebase Crashlytics
   - Privacy-conscious implementation with opt-in/opt-out
   - Breadcrumb logging for debugging context
   - Performance metrics tracking
   - Error logging with contextual information

2. **App Integration** (`MomentumApp.swift`)
   - Firebase initialization on app launch
   - Automatic lifecycle tracking
   - User preference handling via @AppStorage

3. **View Extensions** (`Extensions/View+CrashReporting.swift`)
   - SwiftUI view modifiers for easy tracking
   - Navigation tracking
   - User action logging
   - Performance monitoring

## Setup Instructions

### 1. Firebase Configuration
1. Create a Firebase project at https://console.firebase.google.com
2. Add your iOS app with bundle ID: `com.rubenreut.momentum`
3. Download `GoogleService-Info.plist`
4. Add the plist file to the Xcode project (target: Momentum)

### 2. Dependencies
The Firebase SDK is already added via Swift Package Manager in `Package.swift`:
```swift
.package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0")
```

### 3. Privacy Settings
Users can control crash reporting through Settings:
- **Crash Reporting**: Toggle on/off
- **Analytics**: Toggle on/off
- **Clear All Data**: Remove all collected data

## Usage

### Basic Error Logging
```swift
// Log an error with context
CrashReporter.shared.logError(
    error,
    userInfo: [
        "operation": "fetch_data",
        "item_count": items.count
    ]
)
```

### Breadcrumb Logging
```swift
// Add breadcrumbs for debugging context
CrashReporter.shared.addBreadcrumb(
    message: "User started editing",
    category: "user_action",
    level: .info,
    data: ["item_id": itemID]
)
```

### User Actions
```swift
// Log user interactions
CrashReporter.shared.logUserAction(
    "button_tapped",
    target: "save_button",
    data: ["form_valid": isValid]
)
```

### Navigation Tracking
```swift
// Track navigation events
CrashReporter.shared.logNavigation(
    from: "HomeView",
    to: "SettingsView"
)
```

### Performance Metrics
```swift
// Log performance data
CrashReporter.shared.logPerformanceMetric(
    name: "data_fetch_time",
    value: elapsed,
    unit: "seconds"
)
```

### View Tracking with SwiftUI
```swift
// Track view appearances
MyView()
    .trackViewAppearance("MyView")

// Track async operations
MyView()
    .trackAsyncOperation("load_data") {
        try await loadData()
    }

// Track button taps
Button("Save") { save() }
    .trackTap("save_button")
```

## Privacy Considerations

### Data Collection
- **Anonymous User ID**: Generated UUID, not linked to personal information
- **No PII**: No personally identifiable information is collected
- **User Control**: Users can opt-out at any time
- **Data Clearing**: Users can clear all collected data

### What's Collected
- Crash reports and stack traces
- Non-fatal errors with context
- User action breadcrumbs (no personal data)
- Performance metrics
- Device information (model, OS version)
- App version and build number

### What's NOT Collected
- User names or email addresses
- Location data
- Personal calendar events
- Notes or task content
- Any user-generated content

## Testing

### Debug Mode
In debug builds, a "Test Crash" button is available in Settings to verify crash reporting is working.

### Breadcrumb Trail
The last 100 breadcrumbs are included with crash reports to help debug issues:
- User actions
- Navigation events
- Performance warnings
- Error occurrences

## Best Practices

1. **Always Log Errors**: Use `logError` for all catch blocks
2. **Add Context**: Include relevant data in userInfo
3. **Track Key Actions**: Log important user interactions
4. **Monitor Performance**: Track slow operations
5. **Respect Privacy**: Never log personal information

## Monitoring

### Firebase Console
1. Visit https://console.firebase.google.com
2. Select your project
3. Navigate to Crashlytics
4. View crash reports, trends, and user metrics

### Key Metrics
- **Crash-free users**: Percentage of users without crashes
- **Crash rate**: Crashes per user session
- **Top crashes**: Most common crash signatures
- **Velocity alerts**: Sudden increases in crash rate

## Troubleshooting

### Crashes Not Appearing
1. Ensure Firebase is configured correctly
2. Check that crash reporting is enabled in Settings
3. Crashes appear after app restart (not immediately)
4. Verify `GoogleService-Info.plist` is in the project

### Performance Issues
- Breadcrumbs are limited to 100 entries
- Old breadcrumbs are automatically removed
- Crash reports are queued and sent on next launch

## Future Enhancements
- Custom crash report grouping
- Integration with bug tracking systems
- Automated alerts for crash spikes
- A/B testing for stability improvements