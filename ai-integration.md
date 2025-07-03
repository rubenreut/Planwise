# AI Integration Specifications

## OpenAI Configuration

### API Setup
```swift
// Model: GPT-4
// Endpoint: https://api.openai.com/v1/chat/completions
// API Key: Stored in Cloudflare Workers (NEVER in app code)
// Timeout: 30 seconds
// Max retries: 3 with exponential backoff
```

### Cloudflare Workers Setup (Recommended)
```javascript
// Create a worker at workers.cloudflare.com
export default {
  async fetch(request, env) {
    // Only accept requests from your app
    const authHeader = request.headers.get('X-App-Secret');
    if (authHeader !== env.APP_SECRET) {
      return new Response('Unauthorized', { status: 401 });
    }

    // Forward to OpenAI
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: request.body
    });

    return response;
  }
}
```

### iOS Implementation
```swift
// Your Cloudflare Worker URL
let workerURL = "https://momentum-ai.rubnereut.workers.dev"

// App secret (hardcoded is OK, just for basic protection)
let appSecret = "your-random-string-here"

func callAI(messages: [Message]) async throws -> AIResponse {
    var request = URLRequest(url: URL(string: workerURL)!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(appSecret, forHTTPHeaderField: "X-App-Secret")
    request.httpBody = try JSONEncoder().encode([
        "model": "gpt-4",
        "messages": messages
    ])
    
    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(AIResponse.self, from: data)
}
```

## System Prompt
```
You are an AI assistant for Momentum, a smart time-blocking app. You help users manage their schedule through natural conversation.

Capabilities:
- View current schedule
- Create new time blocks
- Modify existing blocks
- Delete blocks
- Reschedule when users are running late
- Suggest optimal times based on patterns
- Batch reschedule multiple items

Rules:
1. Always confirm changes before executing
2. Consider user's past patterns when suggesting times
3. Never double-book time slots
4. Respect user's energy levels and preferences
5. Be concise but friendly

User Context:
- Current time: [PROVIDED]
- Today's schedule: [PROVIDED]
- Completion history: [PROVIDED]
```

## Function Definitions

### create_event
```json
{
  "name": "create_event",
  "description": "Create a new time block",
  "parameters": {
    "type": "object",
    "properties": {
      "title": {
        "type": "string",
        "description": "Name of the activity"
      },
      "startTime": {
        "type": "string",
        "description": "ISO8601 formatted start time"
      },
      "endTime": {
        "type": "string",
        "description": "ISO8601 formatted end time"
      },
      "category": {
        "type": "string",
        "enum": ["work", "personal", "health", "social", "tasks"],
        "description": "Event category"
      },
      "notes": {
        "type": "string",
        "description": "Optional notes"
      }
    },
    "required": ["title", "startTime", "endTime"]
  }
}
```

### reschedule_event
```json
{
  "name": "reschedule_event",
  "description": "Move an existing event to a new time",
  "parameters": {
    "type": "object",
    "properties": {
      "eventId": {
        "type": "string",
        "description": "UUID of the event to reschedule"
      },
      "newStartTime": {
        "type": "string",
        "description": "New ISO8601 start time"
      },
      "newEndTime": {
        "type": "string",
        "description": "New ISO8601 end time"
      }
    },
    "required": ["eventId", "newStartTime", "newEndTime"]
  }
}
```

### delete_event
```json
{
  "name": "delete_event",
  "description": "Remove an event from the schedule",
  "parameters": {
    "type": "object",
    "properties": {
      "eventId": {
        "type": "string",
        "description": "UUID of the event to delete"
      },
      "reason": {
        "type": "string",
        "description": "Optional reason for deletion"
      }
    },
    "required": ["eventId"]
  }
}
```

### bulk_reschedule
```json
{
  "name": "bulk_reschedule",
  "description": "Reschedule multiple events based on a strategy",
  "parameters": {
    "type": "object",
    "properties": {
      "fromTime": {
        "type": "string",
        "description": "Start of time range to reschedule"
      },
      "strategy": {
        "type": "string",
        "enum": ["compress", "shift", "drop_low_priority", "smart"],
        "description": "How to handle the rescheduling"
      },
      "constraints": {
        "type": "object",
        "properties": {
          "preserveCritical": {
            "type": "boolean",
            "description": "Keep critical events at original time"
          },
          "maxCompression": {
            "type": "number",
            "description": "Maximum compression factor (0.5 = 50%)"
          }
        }
      }
    },
    "required": ["fromTime", "strategy"]
  }
}
```

### suggest_optimal_time
```json
{
  "name": "suggest_optimal_time",
  "description": "Find the best time for an activity based on user patterns",
  "parameters": {
    "type": "object",
    "properties": {
      "activityType": {
        "type": "string",
        "description": "Type of activity to schedule"
      },
      "duration": {
        "type": "integer",
        "description": "Duration in minutes"
      },
      "preferences": {
        "type": "object",
        "properties": {
          "afterDate": {
            "type": "string",
            "description": "Schedule after this date/time"
          },
          "beforeDate": {
            "type": "string",
            "description": "Schedule before this date/time"
          },
          "energyLevel": {
            "type": "string",
            "enum": ["high", "medium", "low"],
            "description": "Required energy level"
          }
        }
      }
    },
    "required": ["activityType", "duration"]
  }
}
```

## Command Parser Implementation

```swift
class CommandParser {
    func parseAIResponse(_ response: String) -> AICommand {
        // 1. Parse function call from response
        // 2. Validate parameters
        // 3. Create command object
        // 4. Add to command queue
    }
    
    func validateCommand(_ command: AICommand) -> Bool {
        // Check for conflicts
        // Verify time constraints
        // Ensure data integrity
    }
}
```

## Rate Limiting

### Free Tier
- 10 requests per day
- Reset at midnight local time
- Show remaining count in UI

### Premium Tier
- 100 requests per day (or unlimited)
- Priority queue for requests
- Faster timeout (20s vs 30s)

### Implementation
```swift
class AIRateLimiter {
    private let freeLimit = 10
    private let premiumLimit = 100
    
    func canMakeRequest(isPremium: Bool) -> Bool {
        let limit = isPremium ? premiumLimit : freeLimit
        return todayRequestCount < limit
    }
    
    func recordRequest() {
        todayRequestCount += 1
        saveToUserDefaults()
    }
}
```

## Error Handling

### Common Errors
1. **Rate Limit Exceeded**
   - Show upgrade prompt
   - Suggest waiting until tomorrow

2. **Network Timeout**
   - Retry with exponential backoff
   - Show offline message after 3 attempts

3. **Invalid Response**
   - Log to FAILURE_LOG.md
   - Show generic error to user

4. **Conflicting Schedule**
   - Return conflict details
   - Suggest alternative times

## Privacy & Security

1. **Data Sent to AI (via Cloudflare Worker):**
   - Schedule data (anonymized option available)
   - User preferences
   - Past completion patterns

2. **Data NOT Sent:**
   - User identity
   - Location data (unless in event)
   - OpenAI API key (stays in Cloudflare)

3. **Security Measures:**
   - API key never in app code
   - Cloudflare Worker proxy
   - HTTPS only
   - App secret for basic auth
   - No data retention on OpenAI side