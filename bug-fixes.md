# Bug Fixes Log

## Bug #1: App Crashes on Launch
**Date:** 2025-06-29
**What happens:** App immediately crashes when opened on physical device
**When it happens:** Every time the app is launched after installation
**Root cause:** Multiple issues:
1. iOS deployment target was set to 18.0 but device likely running iOS 17.x
2. Core Data initialization was happening in app startup, potentially causing crashes
**Fix:** 
1. Changed deployment target from iOS 18.0 to iOS 17.0 in project.pbxproj
2. Temporarily removed Core Data initialization from MomentumApp.swift
3. Created SimpleContentView to verify basic app functionality
**Status:** Fixed - app now launches successfully

## Bug #2: Build Error - Missing View References
**Date:** 2025-06-29
**What happens:** Build would fail with "Cannot find 'DayView' in scope" error
**When it happens:** When trying to use MainTabView that references DayView, DayTimelineView, etc.
**Root cause:** MainTabView was referencing views (DayView, DayTimelineView, AIChatView, SettingsView, WeekView) that don't exist yet
**Fix:** Simplified MainTabView to use placeholder Text views instead of non-existent view references
**Status:** Fixed - ready to build and test

## Bug #3: Build Error - Duplicate CurrentTimeIndicator Declaration
**Date:** 2025-06-29
**What happens:** Build fails with "error: invalid redeclaration of 'CurrentTimeIndicator'"
**When it happens:** When building after creating DayView.swift
**Root cause:** CurrentTimeIndicator struct is declared in both SimpleDayView.swift and DayView.swift
**Fix:** Rename CurrentTimeIndicator in DayView.swift to TimeIndicator to avoid naming conflict
**Status:** Fixed - renamed to TimeIndicator

## Bug #4: Build Error - Duplicate PersistenceController Declaration
**Date:** 2025-06-29
**What happens:** Build fails with "PersistenceController is ambiguous for type lookup"
**When it happens:** When building after creating PersistenceController.swift
**Root cause:** There are two PersistenceController structs - one in Persistence.swift and one in PersistenceController.swift
**Fix:** Delete the old Persistence.swift file since we have a new one
**Status:** Fixed - removed duplicate Persistence.swift

## Bug #5: Build Error - Missing initializeDefaultCategories Method
**Date:** 2025-06-29
**What happens:** Build fails with "value of type 'PersistenceController' has no member 'initializeDefaultCategories'"
**When it happens:** When building after creating new PersistenceController
**Root cause:** SettingsView.swift references a method that doesn't exist in the new PersistenceController
**Fix:** Comment out or remove the problematic line in SettingsView
**Status:** Fixed - updated to use ScheduleManager.shared.loadCategories()

## Bug #6: App Crashes on Launch with Core Data
**Date:** 2025-06-29
**What happens:** App immediately crashes when opened after Core Data integration
**When it happens:** Every time the app launches with Core Data enabled
**Root cause:** Likely Core Data initialization issue or missing Core Data model configuration
**Fix:** Need to check if Core Data model is properly included in the build
**Status:** In progress - investigating Core Data crash
**Findings:**
- App works fine without Core Data
- Crashes immediately when Core Data is initialized
- Added extensive debugging but console output not visible
- Tried NSPersistentContainer instead of NSPersistentCloudKitContainer
- Core Data model file exists and looks correct
**Next steps:** Need to check if model is included in build phases