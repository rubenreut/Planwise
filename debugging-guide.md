# Debugging Guide

## 🔍 Common Issues & Solutions

### CloudKit Sync Not Working

#### Symptoms
- Events not appearing on other devices
- "Failed to sync" error
- Infinite loading spinner

#### Debug Steps
```swift
// 1. Check CloudKit status
CKContainer.default().accountStatus { status, error in
    print("☁️ CloudKit Status: \(status)")
    // .available = good
    // .noAccount = user not signed in
    // .restricted = parental controls
}

// 2. Verify container ID
print("📦 Container: \(CKContainer.default().containerIdentifier)")
// Should be: iCloud.com.rubnereut.ecosystem

// 3. Check for rate limiting
CKContainer.default().database.fetch(withRecordID: testID) { record, error in
    if let ckError = error as? CKError {
        switch ckError.code {
        case .requestRateLimited:
            print("⏱️ Rate limited: retry after \(ckError.retryAfterSeconds ?? 60)s")
        case .networkFailure:
            print("🌐 Network issue")
        default:
            print("❌ CK Error: \(ckError)")
        }
    }
}

// 4. Force refresh
CloudKitManager.shared.forceSyncAll()
```

#### Common Fixes
- Sign out/in of iCloud
- Check Settings > iCloud > iCloud Drive is ON
- Reset development environment in CloudKit Dashboard
- Check network connectivity

### AI Not Responding

#### Debug Steps
```swift
// 1. Check API key exists
if let key = KeychainManager.shared.getAPIKey() {
    print("🔑 API Key exists: \(key.prefix(8))...")
} else {
    print("❌ No API key found")
}

// 2. Check rate limits
print("🤖 AI Requests today: \(AIRateLimiter.shared.todayCount)")
print("🤖 Can make request: \(AIRateLimiter.shared.canMakeRequest())")

// 3. Test API directly
func testOpenAI() {
    let headers = [
        "Authorization": "Bearer \(apiKey)",
        "Content-Type": "application/json"
    ]
    
    let body = [
        "model": "gpt-4",
        "messages": [["role": "user", "content": "test"]],
        "max_tokens": 10
    ]
    
    // Make request and log response
}

// 4. Check error details
AIServiceManager.shared.lastError
```

### Core Data Crashes

#### Debug Steps
```swift
// 1. Enable Core Data debugging
// Edit Scheme > Arguments > Add:
-com.apple.CoreData.SQLDebug 3
-com.apple.CoreData.Logging.stderr 1

// 2. Check for nil values
let fetch = NSFetchRequest<Event>(entityName: "Event")
fetch.returnsObjectsAsFaults = false
let events = try? context.fetch(fetch)
events?.forEach { event in
    // Validate all required fields
    assert(event.title != nil, "Event missing title")
    assert(event.startTime != nil, "Event missing startTime")
}

// 3. Verify model version
if let model = persistentContainer.managedObjectModel {
    print("📊 Model version: \(model.versionIdentifiers)")
}

// 4. Check for duplicate objects
let duplicates = events.filter { event in
    events.filter { $0.id == event.id }.count > 1
}
```

### Memory Leaks

#### Detection
```swift
// 1. Use Xcode Memory Graph
// Debug > Debug Memory Graph
// Look for cycles

// 2. Add deinit logging
deinit {
    print("♻️ \(String(describing: self)) deallocated")
}

// 3. Common leak sources
// Timers not invalidated
timer?.invalidate()
timer = nil

// Notification observers not removed
NotificationCenter.default.removeObserver(self)

// Closure capture cycles
someAsyncCall { [weak self] in
    guard let self = self else { return }
    self.updateUI()
}
```

### UI Not Updating

#### Debug Steps
```swift
// 1. Verify main thread
assert(Thread.isMainThread, "UI update not on main thread")

// 2. Force refresh
DispatchQueue.main.async {
    self.objectWillChange.send()
}

// 3. Check @Published properties
print("🔄 Events count: \(viewModel.events.count)")

// 4. Add update logging
.onReceive(viewModel.$events) { events in
    print("📱 UI received \(events.count) events")
}

// 5. Check view lifecycle
.onAppear {
    print("👁️ View appeared")
}
.onDisappear {
    print("👻 View disappeared")
}
```

## 🛠️ Debug Tools

### Console Helpers
```swift
// Add to AppDelegate or DebugManager
#if DEBUG
extension Event {
    func debugPrint() {
        print("""
        📅 Event Debug:
        - Title: \(title ?? "nil")
        - Time: \(startTime?.formatted() ?? "nil") - \(endTime?.formatted() ?? "nil")
        - Category: \(category ?? "nil")
        - Completed: \(isCompleted)
        - Source: \(dataSource ?? "nil")
        - External ID: \(externalEventID ?? "nil")
        """)
    }
}

// Global debug function
func debugSchedule() {
    let events = ScheduleManager.shared.events
    print("📊 Schedule Debug:")
    print("- Total events: \(events.count)")
    print("- Today: \(events.filter { Calendar.current.isDateInToday($0.startTime) }.count)")
    print("- Completed: \(events.filter { $0.isCompleted }.count)")
}
#endif
```

### Network Debugging
```swift
// URLSession logging
class NetworkLogger: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        print("🌐 Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        return false
    }
}

// Register in AppDelegate
URLProtocol.registerClass(NetworkLogger.self)
```

### Performance Profiling
```swift
// Simple performance timer
func measureTime<T>(operation: () throws -> T) rethrows -> T {
    let start = CFAbsoluteTimeGetCurrent()
    defer {
        let diff = CFAbsoluteTimeGetCurrent() - start
        print("⏱️ Operation took \(diff) seconds")
    }
    return try operation()
}

// Usage
let events = measureTime {
    return ScheduleManager.shared.fetchEvents(for: date)
}
```

## 🐛 Bug Report Template

```markdown
### Environment
- Device: [iPhone model]
- iOS Version: [version]
- App Version: [version]
- Reproducible: Yes/No/Sometimes

### Steps to Reproduce
1. 
2. 
3. 

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Debug Info
- Console output: [paste relevant logs]
- Memory usage: [MB]
- Network status: [Online/Offline]

### Screenshots/Videos
[Attach if applicable]
```

## 🚨 Emergency Fixes

### App Won't Launch
```bash
# Clean build folder
Cmd+Shift+K

# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset simulator
Device > Erase All Content and Settings

# Delete app and reinstall
```

### CloudKit Schema Issues
1. Go to CloudKit Dashboard
2. Development environment
3. Reset Development Environment
4. Deploy to Production when ready

### Core Data Migration Failed
```swift
// Force reset (LOSES DATA)
#if DEBUG
func resetCoreData() {
    let storeURL = persistentContainer.persistentStoreDescriptions.first?.url
    try? persistentContainer.persistentStoreCoordinator.destroyPersistentStore(
        at: storeURL!,
        ofType: NSSQLiteStoreType
    )
    // Recreate
}
#endif
```

## 📊 Debug Metrics to Track

1. **App Launch Time**
   - Cold start: < 1s
   - Warm start: < 0.5s

2. **Memory Usage**
   - Idle: < 50MB
   - Active: < 150MB
   - Peak: < 300MB

3. **Network Requests**
   - API response: < 2s
   - CloudKit sync: < 5s
   - Timeout: 30s

4. **UI Responsiveness**
   - Scroll FPS: 60
   - Animation FPS: 60
   - Touch response: < 100ms

Remember: When debugging, always check FAILURE_LOG.md first - someone might have already solved your issue!