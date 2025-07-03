# Future App Integration Architecture

## 🔄 Integration Overview

Momentum is designed as the central hub for a productivity ecosystem. Other apps (workout, study, meals, etc.) will send activity data to Momentum for correlation and insights.

## 📊 Universal Activity Schema

### Base Activity Format
```json
{
  "version": "1.0",
  "activity": {
    "source_app": "com.rubnereut.workout",
    "source_app_name": "WorkoutTracker",
    "activity_id": "550e8400-e29b-41d4-a716-446655440000",
    "activity_type": "exercise",
    "activity_subtype": "strength_training",
    "timestamp": "2024-10-15T10:30:00Z",
    "timezone": "America/New_York",
    "duration_minutes": 65,
    "completed": true,
    "completion_percentage": 100
  },
  "metrics": {
    // App-specific data goes here
  },
  "correlation_hints": {
    "energy_level": "high",
    "difficulty": "medium",
    "satisfaction": 8
  }
}
```

### App-Specific Metrics Examples

#### Workout App
```json
"metrics": {
  "exercises": [
    {
      "name": "Squat",
      "sets": 4,
      "reps": [8, 8, 6, 6],
      "weight_lbs": [225, 225, 245, 245],
      "rest_seconds": [90, 90, 120, 0]
    }
  ],
  "total_volume_lbs": 8240,
  "heart_rate": {
    "average": 142,
    "max": 178,
    "zones": {
      "cardio": 45,
      "peak": 15,
      "fat_burn": 5
    }
  },
  "calories_burned": 487,
  "workout_type": "legs",
  "equipment_used": ["barbell", "rack"]
}
```

#### Study App
```json
"metrics": {
  "subject": "calculus",
  "topics": ["derivatives", "chain_rule"],
  "cards_reviewed": 47,
  "cards_correct": 42,
  "accuracy_percentage": 89.4,
  "average_time_per_card": 12.3,
  "difficulty_distribution": {
    "easy": 15,
    "medium": 20,
    "hard": 12
  },
  "focus_score": 8.5,
  "breaks_taken": 2
}
```

#### Meal Planning App
```json
"metrics": {
  "meal_type": "lunch",
  "calories": 650,
  "macros": {
    "protein_g": 45,
    "carbs_g": 52,
    "fat_g": 28,
    "fiber_g": 8
  },
  "ingredients": ["chicken", "rice", "broccoli"],
  "preparation_time_minutes": 25,
  "meal_prep_batch": true,
  "water_ml": 500,
  "satisfaction_rating": 9
}
```

## 🔌 Integration Methods

### 1. CloudKit Shared Container (Preferred)
```swift
// All apps use same container
let container = CKContainer(identifier: "iCloud.com.rubnereut.ecosystem")

// Write activity
let record = CKRecord(recordType: "ExternalActivity")
record["source_app"] = "com.rubnereut.workout"
record["activity_data"] = activityJSON
container.save(record) { ... }

// Momentum reads activities
let predicate = NSPredicate(format: "timestamp > %@", lastSyncDate)
let query = CKQuery(recordType: "ExternalActivity", predicate: predicate)
```

### 2. URL Schemes
```swift
// From workout app
let activity = ["type": "workout", "duration": 60, ...]
let json = try JSONEncoder().encode(activity)
let base64 = json.base64EncodedString()
let url = URL(string: "momentum://import?data=\(base64)")!
UIApplication.shared.open(url)

// In Momentum
func handleURLImport(_ url: URL) {
    guard let data = url.queryParameters["data"],
          let json = Data(base64Encoded: data) else { return }
    // Process activity
}
```

### 3. Webhook API (Future)
```javascript
// POST to your backend
POST https://api.rubnereut.com/activities
{
  "api_key": "app_specific_key",
  "activity": { ... }
}

// Backend validates and forwards to Momentum
```

## 🧠 Correlation Engine Design

### Data Collection Phase
```swift
struct CorrelationDataPoint {
    let eventId: UUID
    let timestamp: Date
    let contextWindow: ContextWindow
}

struct ContextWindow {
    let priorEvents: [Event] // 24 hours before
    let subsequentEvents: [Event] // 4 hours after
    let externalActivities: [ExternalActivity]
    let environmentalFactors: EnvironmentalFactors
}

struct EnvironmentalFactors {
    let dayOfWeek: Int
    let timeOfDay: TimeBlock // morning/afternoon/evening
    let weather: WeatherData?
    let location: LocationContext?
}
```

### Pattern Detection
```swift
class CorrelationEngine {
    func findPatterns(for category: String) -> [Correlation] {
        // 1. Get all events of this category
        // 2. Look at success rate (completed vs skipped)
        // 3. Find common factors in successful completions
        // 4. Calculate correlation strength
        
        return correlations.filter { $0.confidence > 0.6 }
    }
}

struct Correlation {
    let factor: String // "workout_before"
    let impact: Double // +0.23 (23% improvement)
    let confidence: Double // 0.85 (85% confident)
    let sampleSize: Int // 47 events analyzed
    let description: String // "You study 23% better after workouts"
}
```

## 📱 Implementation Checklist

### In Momentum (Now)
- [x] Event model has `externalAppID` field
- [x] Event model has `rawMetrics` JSON field
- [x] CloudKit container is shared-ready
- [x] ExternalDataManager stub exists
- [ ] URL scheme registered
- [ ] Import UI ready
- [ ] Correlation data structure

### For Other Apps (Later)
- [ ] Add Momentum SDK/framework
- [ ] Implement activity tracking
- [ ] Add export to Momentum option
- [ ] Use shared CloudKit container
- [ ] Follow activity schema

## 🔐 Security & Privacy

### Data Sharing Rules
1. User must explicitly enable integration
2. Each app connection requires permission
3. User can revoke access anytime
4. Data stays in user's iCloud
5. No third-party servers (unless webhook)

### Permission Flow
```swift
// In Momentum
func requestIntegration(with app: String) {
    let alert = UIAlertController(
        title: "Connect \(app)?",
        message: "Allow \(app) to share activity data with Momentum for insights",
        preferredStyle: .alert
    )
    // Handle permission
}
```

## 📈 Future Insights Examples

### Basic Correlations (V1)
- "You complete 80% of workouts scheduled before 2pm"
- "Study sessions after meals average 12% lower scores"
- "Your most productive day is Tuesday"

### Advanced Correlations (V2)
- "Your code quality improves 34% after piano practice"
- "Optimal workout time based on sleep: 10am-12pm"
- "Meal timing affects focus for 3.5 hours"

### Predictive Insights (V3)
- "Based on your patterns, schedule important work at 2pm today"
- "Skip gym today - your recovery metrics suggest rest"
- "You'll need 3.2 hours for this task (usually 2h but you're tired)"

## 🚀 Rollout Strategy

### Phase 1: Data Collection (Momentum V1)
- Build schema for external data
- Start collecting context windows
- No insights yet

### Phase 2: First Integration (V1.5)
- Connect workout app
- Simple correlations
- Basic insights

### Phase 3: Multi-App (V2)
- 3+ apps connected
- Cross-app insights
- Pattern library

### Phase 4: Intelligence (V3)
- Predictive scheduling
- Optimization suggestions
- Full ecosystem benefits

## 📝 Developer Documentation

### For Your Future Apps
```swift
// 1. Import MomentumKit
import MomentumKit

// 2. Track activity
let activity = MKActivity(
    type: .workout,
    duration: 60,
    metrics: workoutMetrics
)

// 3. Send to Momentum
MomentumKit.shared.logActivity(activity)

// 4. (Optional) Get insights back
MomentumKit.shared.getInsights { insights in
    // Show relevant insights in your app
}
```

This architecture ensures Momentum can grow into a true productivity ecosystem hub while keeping V1 simple and shippable!