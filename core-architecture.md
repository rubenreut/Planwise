# Momentum Core Architecture

## Overview
Momentum is a smart time-blocking app that learns from user patterns and will eventually connect to a suite of productivity apps. Built with SwiftUI, CloudKit, and OpenAI integration.

## Architecture Pattern: MVVM

### Core Managers (NEVER DELETE OR MODIFY WITHOUT PERMISSION)
```
ScheduleManager: Single source of truth for all events
CloudKitManager: Handles all sync operations  
AIServiceManager: OpenAI integration
NotificationManager: Local notifications
WidgetManager: Home screen widget updates
ExternalDataManager: Future app integrations (dormant in v1)
AnalyticsManager: Tracks user behavior for insights
```

### Data Flow
```
User Input → View → ViewModel → Manager → Core Data/CloudKit → View Update
                                    ↓
                                AI Service → Command Parser → Manager
```

### File Structure
```
/Models
  - Event.swift (Core Data model - DO NOT MODIFY)
  - Category.swift
  - AICommand.swift
  - UserPreferences.swift
  
/Views
  - ContentView.swift (tab container)
  - DayView.swift (vertical timeline)
  - WeekView.swift (grid layout)
  - MonthView.swift (calendar)
  - AIChatsView.swift
  - SettingsView.swift
  - OnboardingView.swift
  
/ViewModels
  - ScheduleViewModel.swift
  - AIViewModel.swift
  - SettingsViewModel.swift
  
/Managers
  - ScheduleManager.swift (CRITICAL - owns all event logic)
  - CloudKitManager.swift
  - AIServiceManager.swift
  - NotificationManager.swift
  - WidgetManager.swift
  - ExternalDataManager.swift
  - AnalyticsManager.swift
  
/Services
  - OpenAIService.swift
  - CommandParser.swift
  - CorrelationEngine.swift (v2)
  
/Extensions
  - Date+Extensions.swift
  - Color+Extensions.swift
  
/Resources
  - Localizable.strings
  - Assets.xcassets
```

## Key Principles

### 1. Single Source of Truth
- ScheduleManager owns ALL event data
- Never modify events directly in views
- All changes go through manager methods

### 2. Offline-First
- Core Data is primary storage
- CloudKit syncs when available
- All features work offline except AI

### 3. Future-Ready
- Event model includes integration fields
- Manager pattern allows easy extension
- CloudKit container is shared-ready

## Critical Dependencies
- iOS 17.0+ (for latest SwiftUI features)
- CloudKit (for sync)
- WidgetKit (for home screen)
- UserNotifications (for reminders)

## Build Configurations
- Debug: Uses development CloudKit container
- Release: Uses production CloudKit container
- TestFlight: Production container with debug logging