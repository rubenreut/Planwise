# Quick Reference for Claude Code

## 🚨 BEFORE YOU CODE - CHECK THESE FIRST

1. **Is this error in FAILURE_LOG.md?** → Use the documented solution
2. **Am I touching something in DANGER_ZONES.md?** → Get permission first
3. **What's the current state?** → Check STATE_SNAPSHOT.md
4. **Is this feature already built?** → Check FEATURE_ROADMAP.md

## 🛠️ Common Tasks - Copy/Paste Solutions

### Fix CloudKit Sync Issues
```swift
// Always check these in order:
1. Verify container ID: "iCloud.com.rubnereut.ecosystem"
2. Check if user signed into iCloud:
   CKContainer.default().accountStatus { status, error in
       // Handle .available, .noAccount, .restricted
   }
3. Force sync: CloudKitManager.shared.forceSyncAll()
```

### Fix AI Not Responding
```swift
// Check in order:
1. Verify API key exists in Keychain
2. Check rate limit: AIRateLimiter.shared.canMakeRequest()
3. Check network: URLSession.shared.configuration.allowsCellularAccess
4. Add timeout: request.timeoutInterval = 30.0
```

### Add New Feature Flag
```swift
// In FeatureFlags.swift:
static let newFeature = false // Start disabled

// In code:
if FeatureFlags.newFeature {
    // New code
} else {
    // Existing code
}
```

### Test Premium Features
```swift
// Force premium in debug:
#if DEBUG
UserDefaults.standard.set(true, forKey: "isPremium")
#endif
```

## 📁 Where Things Live

### User Data
- Events → Core Data → `ScheduleManager`
- Preferences → UserDefaults → `SettingsManager`
- API Keys → Keychain → `KeychainManager`
- Sync → CloudKit → `CloudKitManager`

### UI Components
- Custom views → `/Views/Components/`
- View modifiers → `/Views/Modifiers/`
- Animations → `/Views/Animations/`
- Themes → `/Resources/Themes/`

### Business Logic
- Event CRUD → `ScheduleManager` ONLY
- AI commands → `AIServiceManager`
- Notifications → `NotificationManager`
- Analytics → `AnalyticsManager`

## 🐛 Quick Debug Commands

### Print Current State
```swift
print("🔍 Events count: \(ScheduleManager.shared.events.count)")
print("🔍 Premium: \(UserDefaults.standard.bool(forKey: "isPremium"))")
print("🔍 AI requests today: \(AIRateLimiter.shared.todayCount)")
```

### Force Refresh UI
```swift
DispatchQueue.main.async {
    NotificationCenter.default.post(name: .scheduleDidUpdate, object: nil)
}
```

### Clear All Data (Debug Only)
```swift
#if DEBUG
ScheduleManager.shared.deleteAllEvents()
UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
#endif
```

## ⚡ Performance Fixes

### Slow Scrolling
```swift
// Replace ForEach with LazyVStack
LazyVStack(spacing: 0) {
    ForEach(visibleEvents) { event in
        EventRow(event: event)
            .frame(height: 60) // Fixed height
    }
}
```

### Memory Leaks
```swift
// Always use weak/unowned in closures
someAsyncCall { [weak self] result in
    guard let self = self else { return }
    self.handleResult(result)
}
```

### Reduce CloudKit Calls
```swift
// Batch operations
let operations = events.map { CKModifyRecordsOperation... }
// Instead of individual saves
```

## 🎨 UI Quick Fixes

### Dark Mode Colors
```swift
Color("adaptiveBackground") // Uses asset catalog
// Not: Color.white or Color.black
```

### Safe Area Issues
```swift
.ignoresSafeArea(.keyboard) // For forms
.safeAreaInset(edge: .bottom) { ... } // For custom tab bars
```

### Haptic Feedback
```swift
// Light tap
UIImpactFeedbackGenerator(style: .light).impactOccurred()
// Success
UINotificationFeedbackGenerator().notificationOccurred(.success)
```

## 📝 Git Commit Format

```bash
# Feature
git commit -m "[WORKING] Add AI bulk reschedule"

# Bug fix  
git commit -m "[FIX] CloudKit sync for recurring events"

# In progress
git commit -m "[WIP] Theme store UI - DO NOT DEPLOY"

# Breaking change
git commit -m "[BREAKING] Update Core Data model v2"
```

## 🚀 Pre-Deploy Checklist

1. [ ] Build scheme set to Release
2. [ ] CloudKit container = Production
3. [ ] Version number incremented
4. [ ] CHANGELOG.md updated
5. [ ] All TODOs resolved or documented
6. [ ] Tested on real device
7. [ ] Analytics events verified

## 🆘 Emergency Contacts

- TestFlight crashes → Xcode > Organizer > Crashes
- CloudKit issues → CloudKit Dashboard
- API status → status.openai.com
- App Review issues → App Store Connect > Contact Us

## 🎯 Most Important Rules

1. **NEVER** modify Core Data models directly
2. **NEVER** force unwrap in production code
3. **NEVER** store API keys in code
4. **ALWAYS** update STATE_SNAPSHOT.md
5. **ALWAYS** test with 1000+ events
6. **ALWAYS** handle nil/error cases

## 💡 Pro Tips

- Use `guard let` instead of `if let` for early returns
- Profile with Instruments weekly
- Test on slowest supported device
- Keep methods under 30 lines
- Comment WHY, not WHAT
- Future you will thank current you