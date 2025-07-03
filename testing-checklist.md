# Pre-Launch Testing Checklist

## 📱 Device Testing Matrix

### iPhones (Required)
- [ ] iPhone 13 mini - iOS 17.0 (smallest screen)
- [ ] iPhone 15 - iOS 17.5 (standard)
- [ ] iPhone 15 Pro Max - iOS 17.5 (largest)
- [ ] iPhone 12 - iOS 17.0 (older processor)

### iPads (Required) 
- [ ] iPad Pro 12.9" - Latest iOS
- [ ] iPad mini 6 - Latest iOS
- [ ] iPad Air - Landscape + portrait
- [ ] iPad with external keyboard

### Edge Devices (Nice to Have)
- [ ] iPhone SE 3rd gen (small + Touch ID)
- [ ] Simulator with 150% text size
- [ ] Device with VoiceOver enabled

## ⚡ Core Functionality Tests

### Event Management
- [ ] Create event with all fields
- [ ] Create event with minimal fields
- [ ] Edit every field of an event
- [ ] Delete single event
- [ ] Delete recurring event (all/this only)
- [ ] Create overlapping events (should fail)
- [ ] Create 100 events in one day
- [ ] Create event at midnight boundary
- [ ] Drag to resize across day boundary

### Time Zones
- [ ] Change device timezone mid-use
- [ ] Create event in one timezone, view in another
- [ ] Daylight savings transition
- [ ] Travel mode (3+ timezone changes)

### Sync Testing
- [ ] Sign out/in of iCloud
- [ ] Sync between 2 devices
- [ ] Airplane mode changes
- [ ] Conflict resolution (edit same event)
- [ ] Delete on one device, edit on another
- [ ] 1000+ events sync performance

## 🤖 AI Assistant Tests

### Basic Commands
- [ ] "Add gym at 3pm"
- [ ] "Move my 2pm meeting to 4pm"
- [ ] "Delete lunch"
- [ ] "What's my schedule today?"
- [ ] "I'm running 2 hours late"

### Edge Cases
- [ ] Ambiguous commands ("add meeting")
- [ ] Invalid times ("add gym at 25 o'clock")
- [ ] Past times ("add event 2 hours ago")
- [ ] Conflicting instructions
- [ ] Very long event names (100+ chars)
- [ ] Multiple commands at once
- [ ] Network timeout during request
- [ ] Rate limit exceeded

### Rescheduling
- [ ] "I woke up late" suggestions
- [ ] Compress day strategy
- [ ] Drop low priority strategy
- [ ] Preserve critical events
- [ ] Undo/redo AI changes

## 💰 Premium Features

### Subscription Flow
- [ ] Purchase premium
- [ ] Restore purchase
- [ ] Cancel subscription (verify features disabled)
- [ ] Expire subscription (graceful degradation)
- [ ] Purchase with no internet
- [ ] Multiple device entitlements
- [ ] Upgrade/downgrade plans
- [ ] Free trial (if applicable)

### Feature Limits
- [ ] Free: 10 AI requests → show upgrade
- [ ] Free: 3 month history → older hidden
- [ ] Premium: Unlimited verified
- [ ] Theme access (premium only)

## 📊 Performance Tests

### Load Testing
- [ ] 10,000 historical events
- [ ] 50 events in single day
- [ ] Month view with 1000 events
- [ ] Scroll through year quickly
- [ ] Search through all events

### Memory Testing
- [ ] Use app for 30+ minutes
- [ ] Background/foreground 20 times
- [ ] Create/delete 100 events
- [ ] Memory warnings handled
- [ ] No memory leaks in Instruments

### Battery Testing
- [ ] 1 hour active use battery drain
- [ ] Background refresh impact
- [ ] Location services (if used)

## 🎨 UI/UX Testing

### Visual Testing
- [ ] Dark mode (all screens)
- [ ] Light mode (all screens) 
- [ ] Dynamic type (largest text)
- [ ] Landscape orientation (iPad)
- [ ] Reduced motion enabled
- [ ] Increase contrast enabled

### Gesture Testing
- [ ] Tap to create event
- [ ] Drag to resize
- [ ] Swipe between days/weeks
- [ ] Pinch to zoom (if applicable)
- [ ] Long press actions
- [ ] Pull to refresh

### Animation Testing
- [ ] No janky animations
- [ ] 60fps scrolling
- [ ] Smooth transitions
- [ ] Haptic feedback works

## 🔔 Notification Testing

### Permission Flow
- [ ] First-time permission request
- [ ] Permission denied handling
- [ ] Settings deep link
- [ ] Re-enable notifications

### Delivery Testing
- [ ] Single event reminder
- [ ] Multiple reminders queue
- [ ] App in foreground
- [ ] App in background
- [ ] App terminated
- [ ] Do not disturb mode
- [ ] Custom sounds (if any)

## 🌐 Network Conditions

### Connection Types
- [ ] WiFi - fast
- [ ] WiFi - slow (throttled)
- [ ] Cellular - 5G
- [ ] Cellular - 3G
- [ ] Airplane mode
- [ ] Intermittent connection
- [ ] VPN active

### API Testing
- [ ] OpenAI down
- [ ] CloudKit down
- [ ] Timeout handling
- [ ] Retry logic
- [ ] Cancel requests

## 🚨 Edge Cases

### Data Integrity
- [ ] Import corrupted data
- [ ] Export with special characters
- [ ] Unicode in event names
- [ ] Very long notes (10k chars)
- [ ] Empty schedule
- [ ] Null/nil handling

### User Flows
- [ ] First launch experience
- [ ] Onboarding skip
- [ ] Return after 6 months
- [ ] Update from old version
- [ ] Fresh install vs update
- [ ] Account deletion request

## 🔍 Accessibility Testing

### VoiceOver
- [ ] All buttons labeled
- [ ] Event details readable
- [ ] Navigation logical
- [ ] Actions announced

### Other
- [ ] Keyboard navigation (iPad)
- [ ] Voice Control
- [ ] Switch Control
- [ ] Reduce motion respected

## 📋 App Store Prep

### Screenshots
- [ ] iPhone 6.7" (15 Pro Max)
- [ ] iPhone 6.5" (older Max)
- [ ] iPhone 5.5"
- [ ] iPad Pro 12.9"
- [ ] iPad Pro 11"
- [ ] All localizations

### Metadata
- [ ] Description under 4000 chars
- [ ] Keywords optimized
- [ ] What's New written
- [ ] Support URL works
- [ ] Privacy policy current
- [ ] Age rating accurate

## 🚀 Final Checks

### Critical Paths
- [ ] New user can create first event
- [ ] User can upgrade to premium
- [ ] Events sync between devices
- [ ] AI responds appropriately
- [ ] App doesn't crash on launch

### Regression Suite
- [ ] All V1.0 features still work
- [ ] No features accidentally removed
- [ ] Performance not degraded
- [ ] UI elements not broken

### Sign-off Criteria
- [ ] 0 crash rate in TestFlight
- [ ] All critical bugs fixed
- [ ] Performance acceptable
- [ ] UI polished
- [ ] Ready to submit! 🎉

## Testing Notes

- Test with real data, not just perfect scenarios
- Have non-developers test (they find different bugs)
- Test the update path, not just fresh installs
- Keep TestFlight open for 1 week minimum
- Document any "won't fix" issues