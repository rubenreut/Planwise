# Claude Code Instructions for Momentum Development

## Project Overview
Building Momentum - a smart time-blocking iOS app with AI integration and future app ecosystem support.

## Critical Rules
1. **NEVER modify these without explicit permission:**
   - Bundle ID: com.rubenreut.momentum
   - CloudKit Container: iCloud.com.rubnereut.ecosystem
   - Core Data model (once created)
   - ScheduleManager.swift (once created)

2. **Always check before coding:**
   - Read danger-zones.md for restricted items
   - Check failure-log.md for known issues
   - Review current state in state-snapshot.md

3. **Follow established patterns:**
   - MVVM architecture
   - Single source of truth (Managers)
   - Offline-first approach
   - Test everything

4. **Problem-solving approach:**
   - NEVER remove or simplify features when they don't work
   - ALWAYS fix issues properly - figure out the root cause
   - If something is complex, that's fine - implement it correctly
   - Don't suggest "simpler alternatives" - fix what's asked

5. **Debugging Protocol:**
   - When encountering ANY issue, FIRST do deep analysis
   - Add comprehensive debugging output that YOU can read from the console
   - Use print statements, logging, or debug views that show:
     - Variable states
     - Function calls and their parameters
     - Error details with full context
     - Data flow through the app
   - Run the app with debugging enabled to see what's actually happening
   - Don't ask the user to check logs - add debugging that YOU can see
   - After fixing, you can remove or comment out debug code

## Automated Error Recovery
If build fails, automatically:
1. Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/Momentum-*`
2. Reset package cache if needed: `rm -rf ~/Library/Caches/org.swift.swiftpm`
3. Parse specific error patterns and apply known fixes:
   - "No such module" → Check Package.swift or project dependencies
   - "ambiguous use of" → Add type annotations
   - "Value of type X has no member Y" → Check API availability
   - "Extra argument in call" → Check function signature changes
4. Retry with verbose logging
5. Only ask user if all automated fixes fail

## iOS Development Guardrails

### Memory Management
- ALWAYS use [weak self] in closures that capture self
- NEVER retain view controllers in closures
- ALWAYS invalidate timers in deinit
- ALWAYS remove notification observers

### Thread Safety
- UI updates MUST be on main thread:
  ```swift
  DispatchQueue.main.async { /* UI updates */ }
  ```
- Core Data contexts are NOT thread-safe
- Use actors for shared mutable state

### SwiftUI Gotchas
- @StateObject: Initialize ONCE (in view)
- @ObservedObject: Pass from parent
- @Published: Triggers on willSet, not didSet
- ForEach requires stable IDs
- Don't use id: \.self with mutable data

### Common Patterns
```swift
// Weak self in closures
someAsyncCall { [weak self] result in
    guard let self = self else { return }
    // use self safely
}

// Main thread UI updates
Task { @MainActor in
    // UI updates here
}
```

## Performance Monitoring
Add automatic performance tracking to all operations:

```swift
// For any potentially slow operation:
let startTime = CFAbsoluteTimeGetCurrent()
defer { 
    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
    if elapsed > 1.0 {
        print("⚠️ PERF: Slow operation (\(elapsed)s): \(#function)")
    }
}

// For async operations:
func measureAsync<T>(_ operation: String, block: () async throws -> T) async throws -> T {
    let start = CFAbsoluteTimeGetCurrent()
    defer {
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print("⏱️ \(operation): \(String(format: "%.3f", elapsed))s")
    }
    return try await block()
}
```

### Performance Rules
- Log any operation taking > 1 second
- Main thread operations should complete in < 16ms
- Network calls should timeout after 30 seconds
- Monitor memory usage in Instruments

## File Organization
```
/Models - Core Data and data models
/Views - SwiftUI views
/ViewModels - View logic
/Managers - Business logic (single source of truth)
/Services - External integrations
/Extensions - Helper extensions
/Resources - Assets and localization
```

## Development Workflow
1. Update state-snapshot.md before starting
2. Create feature branch
3. Test on real device
4. Update documentation as you go
5. Log any failures in failure-log.md

## Code Style
- Use SwiftUI and iOS 17+ features
- Prefer native components
- Async/await over completion handlers
- Guard statements for early returns
- Meaningful variable names
- Comments for WHY, not WHAT

## Testing Requirements
- Test with 0 events
- Test with 1000+ events  
- Test offline mode
- Test sync conflicts
- Test on smallest iPhone (SE)

## Building and Deployment
**ALWAYS use the build_deploy.sh script to build and run on device:**
```bash
./build_deploy.sh
```

This script will:
1. Clean the build
2. Build for Ruben's iPhone (device ID: 00008140-000105483E2A801C)
3. Install the app
4. Launch the app

**IMPORTANT BUILD RULES:**
- If the build script has errors, FIX THE SCRIPT - don't create a new one
- NEVER simplify or remove features because they're not working
- NEVER say "this is too complex, let's simplify"
- If something breaks, figure out the proper fix
- Always maintain full functionality
- When debugging, the script output will show in the console - READ IT
- Add console logging/print statements that will appear in build output
- You can see runtime logs by checking the script's console output

## Common Commands
```bash
# Build and deploy to device
./build_deploy.sh

# Xcode shortcuts
cmd+B  # Build
cmd+R  # Run
cmd+U  # Test
cmd+shift+K  # Clean
```

## Remember
- This app will be the hub for a productivity ecosystem
- Every decision should consider future integration
- Performance and user experience are critical
- Ship iteratively - v1.0 doesn't need to be perfect

## Current Status
- [ ] Core Data model created
- [ ] CloudKit configured
- [ ] Basic UI structure
- [ ] AI integration
- [ ] Premium features
- [ ] App Store ready

Update this file with any project-specific patterns or decisions as we progress.