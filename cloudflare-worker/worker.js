/**
 * Momentum AI Worker - Handles OpenAI API requests for the Momentum iOS app
 */

// CORS headers for iOS app
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-App-Secret, X-User-ID',
  'Access-Control-Max-Age': '86400',
};

// Rate limit configuration
const RATE_LIMITS = {
  free: {
    perMinute: 1000,  // Increased for dev
    perHour: 1000,    // Increased for dev
    perDay: 1000,     // Increased for dev
  },
  premium: {
    perMinute: 1000,  // Increased for dev
    perHour: 1000,    // Increased for dev
    perDay: 1000,     // Increased for dev
  },
};

// Helper to get rate limit key
function getRateLimitKey(userId, period) {
  const now = new Date();
  const dateStr = now.toISOString().split('T')[0];
  const hour = now.getHours();
  const minute = now.getMinutes();
  
  switch (period) {
    case 'minute':
      return `rate:${userId}:${dateStr}:${hour}:${minute}`;
    case 'hour':
      return `rate:${userId}:${dateStr}:${hour}`;
    case 'day':
      return `rate:${userId}:${dateStr}`;
    default:
      throw new Error('Invalid period');
  }
}

// Check rate limits
async function checkRateLimit(env, userId, isPremium = false) {
  const limits = isPremium ? RATE_LIMITS.premium : RATE_LIMITS.free;
  const periods = ['minute', 'hour', 'day'];
  
  for (const period of periods) {
    const key = getRateLimitKey(userId, period);
    const count = parseInt((await env.RATE_LIMITS.get(key)) || '0');
    const limit = limits[`per${period.charAt(0).toUpperCase() + period.slice(1)}`];
    
    if (count >= limit) {
      return {
        allowed: false,
        retryAfter: period === 'minute' ? 60 : period === 'hour' ? 3600 : 86400,
        limit,
        remaining: 0,
      };
    }
  }
  
  return {
    allowed: true,
    limit: limits.perDay,
    remaining: limits.perDay - parseInt((await env.RATE_LIMITS.get(getRateLimitKey(userId, 'day'))) || '0'),
  };
}

// Increment rate limit counters
async function incrementRateLimit(env, userId) {
  const periods = [
    { name: 'minute', ttl: 60 },
    { name: 'hour', ttl: 3600 },
    { name: 'day', ttl: 86400 },
  ];
  
  const promises = periods.map(async ({ name, ttl }) => {
    const key = getRateLimitKey(userId, name);
    const count = parseInt((await env.RATE_LIMITS.get(key)) || '0');
    await env.RATE_LIMITS.put(key, String(count + 1), { expirationTtl: ttl });
  });
  
  await Promise.all(promises);
}

// Log request for analytics
async function logRequest(env, userId, model, functionCall) {
  const timestamp = new Date().toISOString();
  const key = `log:${userId}:${timestamp}`;
  const log = {
    timestamp,
    userId,
    model,
    functionCall,
  };
  
  // Store for 30 days
  await env.REQUEST_LOGS.put(key, JSON.stringify(log), {
    expirationTtl: 30 * 24 * 60 * 60,
  });
}

// OpenAI function definitions
const FUNCTIONS = [
  {
    name: 'create_event',
    description: 'Create a new calendar event',
    parameters: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'Event title' },
        startTime: { type: 'string', description: 'ISO 8601 datetime' },
        endTime: { type: 'string', description: 'ISO 8601 datetime' },
        category: { type: 'string', enum: ['work', 'personal', 'health', 'learning', 'other'] },
        notes: { type: 'string', description: 'Optional notes' },
      },
      required: ['title', 'startTime', 'endTime'],
    },
  },
  {
    name: 'update_event',
    description: 'Update an existing calendar event. You can pass updates either nested in an updates object or directly as parameters.',
    parameters: {
      type: 'object',
      properties: {
        eventId: { type: 'string', description: 'Event ID to update (UUID format)' },
        event_id: { type: 'string', description: 'Alternative: Event ID to update (UUID format)' },
        updates: {
          type: 'object',
          description: 'Optional: Object containing the fields to update',
          properties: {
            title: { type: 'string' },
            startTime: { type: 'string', description: 'ISO 8601 datetime' },
            endTime: { type: 'string', description: 'ISO 8601 datetime' },
            category: { type: 'string' },
            notes: { type: 'string' },
            isCompleted: { type: 'boolean' },
          },
        },
        // Direct parameters (alternative to updates object)
        title: { type: 'string' },
        startTime: { type: 'string', description: 'ISO 8601 datetime' },
        endTime: { type: 'string', description: 'ISO 8601 datetime' },
        category: { type: 'string' },
        notes: { type: 'string' },
        isCompleted: { type: 'boolean' },
      },
      required: ['eventId'],
    },
  },
  {
    name: 'delete_event',
    description: 'Delete a calendar event',
    parameters: {
      type: 'object',
      properties: {
        eventId: { type: 'string', description: 'Event ID to delete' },
      },
      required: ['eventId'],
    },
  },
  {
    name: 'list_events',
    description: 'List events for a specific date range',
    parameters: {
      type: 'object',
      properties: {
        startDate: { type: 'string', description: 'ISO 8601 date' },
        endDate: { type: 'string', description: 'ISO 8601 date' },
      },
      required: ['startDate'],
    },
  },
  {
    name: 'suggest_schedule',
    description: 'Suggest an optimized schedule based on user preferences',
    parameters: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'ISO 8601 date' },
        preferences: {
          type: 'object',
          properties: {
            workHoursStart: { type: 'string' },
            workHoursEnd: { type: 'string' },
            breakDuration: { type: 'number' },
            focusBlocks: { type: 'number' },
          },
        },
      },
      required: ['date'],
    },
  },
  {
    name: 'delete_all_events',
    description: 'Delete events. Can delete all events for a specific date, a date range, or ALL events in the calendar.',
    parameters: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'ISO 8601 date (YYYY-MM-DD) for single date deletion' },
        startDate: { type: 'string', description: 'ISO 8601 date (YYYY-MM-DD) for start of date range' },
        endDate: { type: 'string', description: 'ISO 8601 date (YYYY-MM-DD) for end of date range' },
      },
      // No required parameters - if none provided, deletes ALL events
    },
  },
  {
    name: 'create_multiple_events',
    description: 'Create multiple calendar events at once. Useful for setting up a full day schedule.',
    parameters: {
      type: 'object',
      properties: {
        events: {
          type: 'array',
          description: 'Array of events to create',
          items: {
            type: 'object',
            properties: {
              title: { type: 'string', description: 'Event title' },
              startTime: { type: 'string', description: 'ISO 8601 datetime' },
              endTime: { type: 'string', description: 'ISO 8601 datetime' },
              category: { type: 'string', enum: ['work', 'personal', 'health', 'learning', 'other'] },
              notes: { type: 'string', description: 'Optional notes' },
            },
            required: ['title', 'startTime', 'endTime'],
          },
        },
      },
      required: ['events'],
    },
  },
  {
    name: 'update_all_events',
    description: 'Update all events for a specific date with the same changes (e.g., mark all as completed, change category).',
    parameters: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'ISO 8601 date (YYYY-MM-DD) for which to update all events' },
        updates: {
          type: 'object',
          properties: {
            isCompleted: { type: 'boolean' },
            category: { type: 'string' },
            notes: { type: 'string' },
          },
        },
      },
      required: ['date', 'updates'],
    },
  },
  {
    name: 'mark_all_complete',
    description: 'Mark all events for a specific date as completed.',
    parameters: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'ISO 8601 date (YYYY-MM-DD) for which to mark all events as completed' },
      },
      required: ['date'],
    },
  },
  {
    name: 'create_recurring_event',
    description: 'Create a recurring event that repeats on a schedule (daily, weekly, monthly, etc.)',
    parameters: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'Event title' },
        startTime: { type: 'string', description: 'ISO 8601 datetime for the first occurrence' },
        duration: { type: 'number', description: 'Duration in minutes' },
        recurrence: { 
          type: 'string', 
          description: 'Recurrence pattern: "daily", "weekdays", "weekends", "weekly", "every Monday", "every Tuesday and Thursday", "monthly", "every 2 weeks", etc.' 
        },
        endDate: { type: 'string', description: 'Optional ISO 8601 date when recurrence ends' },
        category: { type: 'string', enum: ['work', 'personal', 'health', 'learning', 'other'] },
        notes: { type: 'string', description: 'Optional notes' },
      },
      required: ['title', 'startTime', 'duration', 'recurrence'],
    },
  },
];

// System prompt for the AI
const SYSTEM_PROMPT = `You are Momentum Assistant, an AI helper for the Momentum productivity app. Your role is to help users manage their calendar and schedule effectively.

Key capabilities:
- Create, update, and delete calendar events (single or bulk operations)
- Provide schedule suggestions and optimizations
- Understand natural language time expressions
- Be concise and helpful

When responding about function results:
- Include details about what was done
- Confirm the specific actions taken
- Provide full context of the operation

FORMATTING RULES - ALWAYS FOLLOW:
1. **Use bold text** for important information like event titles, times, and key actions
2. Use bullet points (•) for lists of items or events
3. Add line breaks between different sections or topics
4. Format schedules with clear visual separation

Examples of good formatting:

For event creation:
"I've created your **Team Meeting** for **tomorrow at 2:00 PM - 3:00 PM**.

**Details:**
• Title: Team Meeting
• Time: 2:00 PM - 3:00 PM
• Category: Work"

For listing events:
"Here's your schedule for **tomorrow**:

**Morning:**
• **9:00 AM - 10:00 AM** - Morning Standup
• **10:30 AM - 12:00 PM** - Deep Work Session

**Afternoon:**
• **2:00 PM - 3:00 PM** - Client Call
• **3:30 PM - 4:30 PM** - Code Review"

For confirmations:
"✅ **Successfully deleted** all events for tomorrow.

**Removed:**
• Morning Meditation (6:00 AM)
• Team Standup (9:00 AM)
• Lunch Break (12:00 PM)
• Project Review (3:00 PM)"

ALWAYS:
- Bold event titles and times
- Use bullet points for lists
- Add spacing between sections
- Use checkmarks (✅) for successful actions
- Use clear headers for different time periods

BULK OPERATIONS:
When users ask to perform actions on "all" events or multiple events, use the bulk functions:
- delete_all_events: Very flexible deletion function:
  * "delete all events" → Call with no parameters to delete ALL events
  * "delete all events this week" → Call with startDate (Monday) and endDate (Sunday)
  * "delete all events tomorrow" → Call with date parameter for single day
  * "delete all events next week" → Calculate the date range and use startDate/endDate
- create_multiple_events: Create multiple events at once
- update_all_events: Update all events for a date with the same changes

IMPORTANT DELETION RULES:
- When user says "delete all events" without specifying a date, call delete_all_events with NO parameters
- When user specifies a time period like "this week", "next week", calculate the date range
- Always confirm the deletion action in your response
- mark_all_complete: Mark all events for a date as completed

Examples:
- "Delete all events tomorrow" → use delete_all_events
- "Mark all of today's tasks as done" → use mark_all_complete
- "Create a morning routine" → use create_multiple_events with multiple events
- "Schedule a team meeting every Tuesday at 2pm" → use create_recurring_event
- "Add gym every weekday at 6am" → use create_recurring_event with recurrence: "weekdays"

TIMEZONE HANDLING:
The user's timezone and offset are provided in the context. When users specify times:
1. They mean times in THEIR LOCAL TIMEZONE
2. You must convert to UTC for function calls
3. Use the timezone offset to calculate correct UTC times

IMPORTANT: When DISPLAYING times to the user, ALWAYS show them in their local time WITHOUT any timezone indicators.
- WRONG: "6:00 PM (UTC)" or "6:00 PM UTC"
- WRONG: "18:00 (GMT)"
- RIGHT: "6:00 PM"
- RIGHT: "6:00 PM - 7:30 PM"

The user doesn't care about timezones - just show them the time as they would see it on their clock.

Example: User in Dublin (UTC+0) says "3pm" → use "15:00:00Z" in functions, display as "3:00 PM"
Example: User in New York (UTC-5) says "3pm" → use "20:00:00Z" in functions, display as "3:00 PM"

UNDERSTANDING TIME EXPRESSIONS:
When users say relative times, you MUST convert them to absolute ISO 8601 datetime format.
Given the current time in the context, calculate the exact datetime:

Examples (assuming current time is 2025-07-02T10:30:00Z):
- "in 2 hours" → "2025-07-02T12:30:00Z" (add 2 hours to current time)
- "tomorrow at 3pm" → "2025-07-03T15:00:00Z" (adjust for user's timezone!)
- "next Monday" → "2025-07-07T10:30:00Z" (keep same time)
- "this afternoon" → "2025-07-02T14:00:00Z"
- "tonight" → "2025-07-02T20:00:00Z"
- "noon" → "2025-07-02T12:00:00Z"

IMPORTANT: NEVER pass relative times like "in 2 hours" directly to functions.
ALWAYS calculate the absolute datetime first!

CRITICAL FUNCTION CALLING RULES:
1. For list_events: ALWAYS provide startDate parameter in ISO 8601 format (YYYY-MM-DD)
   - Example: {"startDate": "2025-01-08"}
   - For date ranges, also provide endDate

2. For create_event: Use full ISO 8601 datetime with time (YYYY-MM-DDTHH:MM:SSZ)
   - Example: {"title": "Meeting", "startTime": "2025-01-08T14:00:00Z", "endTime": "2025-01-08T15:00:00Z"}
   - ALWAYS convert relative times to absolute ISO 8601 format before calling
   - When user says "create event in 2 hours":
     1. Get current time from context (e.g., 2025-07-02T10:00:00Z)
     2. Add 2 hours: 2025-07-02T12:00:00Z
     3. Calculate end time (e.g., 1 hour later): 2025-07-02T13:00:00Z
     4. Call: create_event({"title": "...", "startTime": "2025-07-02T12:00:00Z", "endTime": "2025-07-02T13:00:00Z"})

3. For update_event: Use the event ID and specify what to update
   - Example: {"eventId": "550e8400-e29b-41d4-a716-446655440000", "title": "New Title"}
   - You can pass updates directly OR in an updates object
   - Direct: {"eventId": "...", "title": "New", "startTime": "..."}
   - With updates object: {"eventId": "...", "updates": {"title": "New", "startTime": "..."}}

4. For delete_event: Use the exact event ID from list_events
   - Example: {"eventId": "550e8400-e29b-41d4-a716-446655440000"}

IMPORTANT: When users say "tomorrow", "next week", etc., you MUST:
1. Calculate the actual date based on the current date provided in context
2. Use that calculated date in your function calls
3. NEVER call list_events without a startDate parameter

For delete/update requests:
1. First call list_events with the correct date
2. Get the event IDs from the response
3. Then call delete_event for EACH event individually

IMPORTANT: To delete multiple events, you MUST:
- Call delete_event multiple times, once for each event
- Extract each event ID from the list_events response
- Never try to pass multiple IDs to a single delete_event call

Example for "delete all events tomorrow":
1. Call list_events with startDate: "2025-07-03"
2. Parse the response to get event IDs like:
   - Morning Meditation: B921BF88-A6BC-4C3E-8A49-93DCE964A590
   - Sprint Planning: F0FA97A8-6D11-493B-9EF1-E3DB824179AA
3. Call delete_event multiple times:
   - delete_event({"eventId": "B921BF88-A6BC-4C3E-8A49-93DCE964A590"})
   - delete_event({"eventId": "F0FA97A8-6D11-493B-9EF1-E3DB824179AA"})
   - Continue for ALL events

NEVER stop after deleting just one event when asked to delete "all" or "every" event!

The current date and time will be provided in the context.`;

export default {
  async fetch(request, env, ctx) {
    console.log('🚀 REQUEST RECEIVED:', {
      method: request.method,
      url: request.url,
      headers: Object.fromEntries(request.headers.entries())
    });
    
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      console.log('✅ Handling CORS preflight');
      return new Response(null, { headers: corsHeaders });
    }
    
    // Only allow POST
    if (request.method !== 'POST') {
      console.log('❌ Method not allowed:', request.method);
      return new Response('Method not allowed', {
        status: 405,
        headers: corsHeaders,
      });
    }
    
    try {
      console.log('📝 Processing POST request');
      // Verify app secret
      const appSecret = request.headers.get('X-App-Secret');
      console.log('🔐 Checking app secret:', appSecret ? 'Present' : 'Missing');
      
      if (appSecret !== env.APP_SECRET) {
        console.log('❌ App secret mismatch!');
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      console.log('✅ App secret verified');
      
      // Get user ID
      const userId = request.headers.get('X-User-ID') || 'anonymous';
      console.log('👤 User ID:', userId);
      
      // Parse request body
      const body = await request.json();
      console.log('📨 Request body:', JSON.stringify(body, null, 2));
      
      const { messages, model = 'gpt-4o-mini', stream = false, userContext } = body;
      
      // Check if any message contains images and adjust model if needed
      let effectiveModel = model;
      const hasImages = messages.some(msg => {
        if (Array.isArray(msg.content)) {
          return msg.content.some(part => part.type === 'image_url');
        }
        return false;
      });
      
      // If images are present, ensure we're using a vision-capable model
      if (hasImages) {
        // gpt-4o-mini supports vision, but we'll log it
        console.log('🖼️ Images detected in messages, using vision-capable model');
        // Could switch to gpt-4o for better vision performance if needed
        // effectiveModel = 'gpt-4o';
      }
      
      console.log('🤖 Model:', effectiveModel);
      console.log('📡 Stream:', stream);
      console.log('📋 User context:', userContext ? 'Present' : 'Not provided');
      console.log('🖼️ Contains images:', hasImages);
      
      // Check rate limits
      const isPremium = userContext?.isPremium || false;
      const rateLimitCheck = await checkRateLimit(env, userId, isPremium);
      
      if (!rateLimitCheck.allowed) {
        return new Response(
          JSON.stringify({
            error: 'Rate limit exceeded',
            retryAfter: rateLimitCheck.retryAfter,
            limit: rateLimitCheck.limit,
            remaining: 0,
          }),
          {
            status: 429,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
              'X-RateLimit-Limit': String(rateLimitCheck.limit),
              'X-RateLimit-Remaining': '0',
              'X-RateLimit-Reset': String(Date.now() + rateLimitCheck.retryAfter * 1000),
            },
          }
        );
      }
      
      // Build messages with system prompt
      const openAIMessages = [
        { role: 'system', content: SYSTEM_PROMPT },
        ...messages,
      ];
      console.log('💬 Initial messages count:', openAIMessages.length);
      
      // Add user context and current date/time
      const now = new Date();
      const currentDate = now.toISOString().split('T')[0]; // YYYY-MM-DD
      const tomorrow = new Date(now);
      tomorrow.setDate(tomorrow.getDate() + 1);
      const tomorrowDate = tomorrow.toISOString().split('T')[0];
      
      console.log('📅 Date context:', {
        today: currentDate,
        tomorrow: tomorrowDate,
        currentTime: now.toISOString()
      });
      
      // Get timezone from user context or default to UTC
      const userTimezone = userContext?.timezone || 'UTC';
      const timezoneOffset = userContext?.timezoneOffset || '+00:00';
      
      let contextMessage = `CURRENT DATE AND TIME:
- Today's date: ${currentDate}
- Tomorrow's date: ${tomorrowDate}
- Current time: ${now.toISOString()}
- User's timezone: ${userTimezone} (${timezoneOffset})

CRITICAL TIME DISPLAY RULES:
1. When showing times to the user, ALWAYS display in their local time
2. NEVER show timezone indicators like (UTC), (GMT), (EST), etc.
3. Just show clean times like "3:00 PM" or "9:00 AM - 10:30 AM"
4. The user sees times as they appear on their local clock/phone

For function calls: Use UTC times (add Z suffix)
For display to user: Show local times without any timezone text

REMEMBER: Always use these dates when calling functions!`;

      if (userContext) {
        contextMessage += `\n\nUser's current schedule:
- Today's events: ${JSON.stringify(userContext.todaySchedule)}
- Recent completions: ${JSON.stringify(userContext.completionHistory)}`;
      }
      
      openAIMessages.push({
        role: 'system',
        content: contextMessage,
      });
      
      console.log('📄 Final system messages:', openAIMessages.filter(m => m.role === 'system').map(m => m.content));
      
      // Make OpenAI API request
      const openAIRequestBody = {
        model: effectiveModel,
        messages: openAIMessages,
        functions: FUNCTIONS,
        function_call: 'auto',
        temperature: 0.7,
        max_tokens: 1500,
        stream,
      };
      
      console.log('🚀 Sending to OpenAI:', {
        model: openAIRequestBody.model,
        messageCount: openAIRequestBody.messages.length,
        functionCount: openAIRequestBody.functions.length,
        stream: openAIRequestBody.stream
      });
      
      console.log('📨 Full OpenAI request:', JSON.stringify(openAIRequestBody, null, 2));
      
      const openAIResponse = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
        },
        body: JSON.stringify(openAIRequestBody),
      });
      
      console.log('📡 OpenAI response status:', openAIResponse.status);
      console.log('📡 OpenAI response headers:', Object.fromEntries(openAIResponse.headers.entries()));
      
      if (!openAIResponse.ok) {
        const error = await openAIResponse.text();
        console.error('❌ OpenAI API error:', error);
        return new Response(
          JSON.stringify({ error: 'AI service error', details: error }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
      
      console.log('✅ OpenAI request successful');
      
      // Increment rate limit
      await incrementRateLimit(env, userId);
      
      // Log request
      await logRequest(env, userId, effectiveModel, body.functionCall);
      
      // Handle streaming response
      if (stream) {
        const { readable, writable } = new TransformStream();
        const writer = writable.getWriter();
        const encoder = new TextEncoder();
        
        // Forward the stream
        ctx.waitUntil(
          (async () => {
            const reader = openAIResponse.body.getReader();
            try {
              while (true) {
                const { done, value } = await reader.read();
                if (done) break;
                await writer.write(value);
              }
            } finally {
              await writer.close();
            }
          })()
        );
        
        return new Response(readable, {
          headers: {
            ...corsHeaders,
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'X-RateLimit-Limit': String(rateLimitCheck.limit),
            'X-RateLimit-Remaining': String(rateLimitCheck.remaining - 1),
          },
        });
      }
      
      // Handle non-streaming response
      const result = await openAIResponse.json();
      
      console.log('🎯 OpenAI response:', JSON.stringify(result, null, 2));
      
      // Log if there's a function call
      if (result.choices?.[0]?.message?.function_call) {
        console.log('🔧 Function call detected:', result.choices[0].message.function_call);
      }
      
      console.log('✅ Sending response back to client');
      
      return new Response(JSON.stringify(result), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'X-RateLimit-Limit': String(rateLimitCheck.limit),
          'X-RateLimit-Remaining': String(rateLimitCheck.remaining - 1),
        },
      });
      
    } catch (error) {
      console.error('Worker error:', error);
      return new Response(
        JSON.stringify({ error: 'Internal server error', message: error.message }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }
  },
};