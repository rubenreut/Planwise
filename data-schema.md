# Complete Data Schema

## Core Data Entities

### Event
```swift
// CRITICAL: Never delete fields, only add optional ones
entity Event {
    // Core fields
    id: UUID
    title: String
    startTime: Date
    endTime: Date
    category: String
    colorHex: String
    iconName: String?
    
    // Details
    notes: String?
    location: String?
    url: String?
    
    // Status
    isCompleted: Bool
    completedAt: Date?
    completionDuration: Int32? // actual minutes spent
    
    // Metadata
    createdAt: Date
    modifiedAt: Date
    syncToken: String?
    
    // Recurrence
    recurrenceRule: String? // "daily", "weekly", "custom"
    recurrenceEndDate: Date?
    recurrenceID: UUID? // links recurring events
    
    // Integration Ready (USE THESE)
    dataSource: String // "manual", "ai", "imported", "external_app"
    externalAppID: String? // "com.yourname.workout"
    externalEventID: String?
    rawMetrics: Data? // JSON blob from other apps
    completionMetrics: Data? // JSON blob when completed
    
    // Future proofing (hidden in v1)
    priority: String? // "high", "medium", "low"
    energyLevel: String? // "high", "medium", "low"
    tags: String? // Comma separated
    bufferTimeBefore: Int32? // minutes
    bufferTimeAfter: Int32? // minutes
    weatherRequired: String? // "any", "indoor", "outdoor"
    
    // Relationships
    category: Category
}
```

### Category
```swift
entity Category {
    id: UUID
    name: String
    colorHex: String
    iconName: String // SF Symbol name
    isDefault: Bool
    isActive: Bool
    sortOrder: Int32
    createdAt: Date
    
    // Relationships
    events: [Event]
}
```

### UserPreferences
```swift
entity UserPreferences {
    id: UUID
    
    // Display
    firstDayOfWeek: Int32 // 1=Sunday, 2=Monday
    timeFormat: String // "12h" or "24h"
    defaultDuration: Int32 // minutes
    
    // Notifications
    enableNotifications: Bool
    defaultReminderMinutes: Int32
    
    // AI
    aiSuggestionsEnabled: Bool
    lastAIRequestCount: Int32
    lastAIRequestDate: Date?
    
    // Premium
    isPremium: Bool
    premiumExpiryDate: Date?
    
    // Theme
    selectedTheme: String // "default", "minimal", custom themes
    accentColor: String
    
    // Privacy
    analyticsEnabled: Bool
    crashReportingEnabled: Bool
}
```

## CloudKit Schema

### Container
`iCloud.com.rubnereut.ecosystem` (NOT just .momentum)

### Record Types

#### Event Record
```
RecordType: "Event"
Fields:
    - title: String
    - startTime: Date
    - endTime: Date
    - category: String
    - colorHex: String
    - notes: String
    - location: String
    - url: String
    - isCompleted: Int64
    - completedAt: Date
    - dataSource: String
    - externalAppID: String
    - externalEventID: String
    - rawMetrics: Bytes
    - modifiedAt: Date
```

#### Category Record
```
RecordType: "Category"
Fields:
    - name: String
    - colorHex: String
    - iconName: String
    - isDefault: Int64
    - sortOrder: Int64
```

#### ExternalActivity Record (Future)
```
RecordType: "ExternalActivity"
Fields:
    - sourceApp: String
    - activityType: String
    - timestamp: Date
    - duration: Int64
    - metrics: Bytes
    - correlationData: Bytes
```

## JSON Structures

### External App Data Format
```json
{
  "source": "workout_app",
  "event_id": "12345",
  "timestamp": "2024-10-15T10:30:00Z",
  "type": "strength_training",
  "duration_minutes": 65,
  "metrics": {
    "exercises": [
      {
        "name": "Squat",
        "sets": 4,
        "reps": [8, 8, 6, 6],
        "weight": [225, 225, 245, 245]
      }
    ],
    "total_volume": 8240,
    "heart_rate_avg": 142,
    "calories": 487
  }
}
```

### AI Command Format
```json
{
  "command": "reschedule",
  "parameters": {
    "event_id": "uuid-here",
    "new_start": "2024-10-15T14:00:00Z",
    "new_end": "2024-10-15T15:30:00Z",
    "reason": "running_late"
  }
}
```

## Migration Strategy
1. Always use Core Data lightweight migration when possible
2. Add new fields as optional
3. Never rename or delete fields
4. Use mapping models for complex changes
5. Test migrations with large datasets