# Firebase Setup Instructions for Momentum

## Prerequisites
- Firebase account (create at https://firebase.google.com)
- Xcode 15.0 or later
- iOS 17.0+ deployment target

## Step-by-Step Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a project"
3. Name your project (e.g., "Momentum")
4. Enable Google Analytics (optional but recommended)
5. Complete project creation

### 2. Add iOS App to Firebase
1. In Firebase Console, click "Add app" and select iOS
2. Enter iOS bundle ID: `com.rubenreut.momentum`
3. App nickname: "Momentum" (optional)
4. App Store ID: Leave blank for now
5. Click "Register app"

### 3. Download Configuration File
1. Download `GoogleService-Info.plist` when prompted
2. **IMPORTANT**: Replace the placeholder file at:
   `/Users/rubenreut/Momentum/Momentum/Momentum/GoogleService-Info.plist`
3. Ensure the file is added to the Xcode project target

### 4. Enable Crashlytics
1. In Firebase Console, navigate to "Release & Monitor" → "Crashlytics"
2. Click "Enable Crashlytics"
3. Follow the setup wizard

### 5. Configure Privacy & Security
1. In Firebase Console, go to Project Settings
2. Navigate to "Privacy & Security" tab
3. Configure data retention settings:
   - Crash reports: 90 days (recommended)
   - Analytics data: 14 months (default)

### 6. Set Up Debug Symbols (Required for Crash Reports)
1. In Xcode, select your project
2. Go to Build Phases
3. Click "+" → "New Run Script Phase"
4. Add this script:
```bash
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```
5. In Input Files, add:
```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}
${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}
```

### 7. Test Crash Reporting
1. Build and run the app on a real device
2. Go to Settings → Privacy
3. Ensure "Crash Reporting" is enabled
4. Tap "Test Crash (Debug)" button (only visible in debug builds)
5. Relaunch the app
6. Check Firebase Console after a few minutes

## Privacy Compliance

### App Store Privacy Labels
When submitting to the App Store, declare the following data collection:

**Crash Data**
- Data type: Crash Data
- Purpose: App Functionality
- Linked to user: No
- Used for tracking: No

**Usage Data** (if Analytics enabled)
- Data type: Product Interaction
- Purpose: Analytics
- Linked to user: No
- Used for tracking: No

### User Consent
The app implements privacy-conscious crash reporting:
- Users can opt-out via Settings → Privacy
- No personally identifiable information is collected
- Anonymous user IDs are used for crash grouping
- Users can clear all data at any time

## Monitoring & Alerts

### Set Up Alerts
1. In Firebase Console, go to Crashlytics
2. Click "Alert Settings"
3. Configure alerts for:
   - New fatal issues
   - Regression alerts
   - Velocity alerts (spike in crash rate)

### Key Metrics to Monitor
- **Crash-free users**: Target > 99.5%
- **Crash-free sessions**: Target > 99.8%
- **Top crashes**: Fix within 24-48 hours
- **User impact**: Prioritize by affected users

## Troubleshooting

### Crashes Not Appearing
1. Ensure GoogleService-Info.plist is correctly added
2. Verify crash reporting is enabled in Settings
3. Crashes appear after app restart
4. Check Firebase project matches bundle ID

### Build Errors
1. Clean build folder: Cmd+Shift+K
2. Reset package caches: File → Packages → Reset Package Caches
3. Ensure Firebase SDK is properly linked

### Debug Symbol Upload Failed
1. Check run script phase is configured correctly
2. Ensure you have upload-symbols permissions
3. Verify network connectivity during build

## Best Practices
1. Always test on real devices (simulators don't send crash reports)
2. Monitor crash-free metrics after each release
3. Fix top crashes first (highest user impact)
4. Use breadcrumbs to understand crash context
5. Test crash reporting in TestFlight before App Store release

## Support
- Firebase Documentation: https://firebase.google.com/docs/crashlytics
- Firebase Support: https://firebase.google.com/support
- Community: https://stackoverflow.com/questions/tagged/firebase-crashlytics