/**
 * Momentum AI Worker - Handles OpenAI API requests for the Momentum iOS app
 */

// Import additional functions for complete CRUD access
import { ALL_ADDITIONAL_FUNCTIONS } from './additional-functions.js';

// CORS headers for iOS app
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-App-Secret, X-User-ID, X-Device-ID, X-Request-Signature, X-Request-Timestamp',
  'Access-Control-Max-Age': '86400',
};

// Security configuration
const SECURITY_CONFIG = {
  maxRequestSize: 5 * 1024 * 1024, // 5MB max request size
  maxMessagesPerRequest: 50, // Max conversation history length
  maxTokensEstimate: 32000, // Max estimated tokens per request
  requestTimeoutMs: 55000, // 55 second timeout (Cloudflare Worker max is ~60s)
  replayWindowMs: 5 * 60 * 1000, // 5 minute replay window
  signatureAlgorithm: 'SHA-256',
};

// Rate limit configuration
const RATE_LIMITS = {
  free: {
    perMinute: 60,    // Much more generous for testing
    perHour: 500,
    perDay: 1000,
  },
  premium: {
    perMinute: 100,
    perHour: 1000,
    perDay: 2000,
  },
};

// Helper to get client IP
function getClientIP(request) {
  return request.headers.get('CF-Connecting-IP') || 
         request.headers.get('X-Forwarded-For')?.split(',')[0] || 
         'unknown';
}

// Helper to get rate limit key
function getRateLimitKey(identifier, period, isIP = false) {
  const now = new Date();
  const dateStr = now.toISOString().split('T')[0];
  const hour = now.getHours();
  const minute = now.getMinutes();
  const prefix = isIP ? 'ip' : 'user';
  
  switch (period) {
    case 'minute':
      return `rate:${prefix}:${identifier}:${dateStr}:${hour}:${minute}`;
    case 'hour':
      return `rate:${prefix}:${identifier}:${dateStr}:${hour}`;
    case 'day':
      return `rate:${prefix}:${identifier}:${dateStr}`;
    default:
      throw new Error('Invalid period');
  }
}

// Check rate limits with IP fallback
async function checkRateLimit(env, request, userId, isPremium = false) {
  const limits = isPremium ? RATE_LIMITS.premium : RATE_LIMITS.free;
  const periods = ['minute', 'hour', 'day'];
  const clientIP = getClientIP(request);
  
  // Check user-based rate limits if userId exists
  if (userId && userId !== 'anonymous') {
    for (const period of periods) {
      const key = getRateLimitKey(userId, period, false);
      const count = parseInt((await env.RATE_LIMITS.get(key)) || '0');
      const limit = limits[`per${period.charAt(0).toUpperCase() + period.slice(1)}`];
      
      if (count >= limit) {
        return {
          allowed: false,
          retryAfter: period === 'minute' ? 60 : period === 'hour' ? 3600 : 86400,
          limit,
          remaining: 0,
          rateLimitType: 'user',
        };
      }
    }
    
    return {
      allowed: true,
      limit: limits.perDay,
      remaining: limits.perDay - parseInt((await env.RATE_LIMITS.get(getRateLimitKey(userId, 'day', false))) || '0'),
      rateLimitType: 'user',
    };
  }
  
  // Fall back to IP-based rate limiting for anonymous users
  // More generous limits for testing
  const ipLimits = {
    perMinute: 30,
    perHour: 200,
    perDay: 500,
  };
  
  for (const period of periods) {
    const key = getRateLimitKey(clientIP, period, true);
    const count = parseInt((await env.RATE_LIMITS.get(key)) || '0');
    const limit = ipLimits[`per${period.charAt(0).toUpperCase() + period.slice(1)}`];
    
    if (count >= limit) {
      return {
        allowed: false,
        retryAfter: period === 'minute' ? 60 : period === 'hour' ? 3600 : 86400,
        limit,
        remaining: 0,
        rateLimitType: 'ip',
      };
    }
  }
  
  return {
    allowed: true,
    limit: ipLimits.perDay,
    remaining: ipLimits.perDay - parseInt((await env.RATE_LIMITS.get(getRateLimitKey(clientIP, 'day', true))) || '0'),
    rateLimitType: 'ip',
  };
}

// Increment rate limit counters with IP fallback
async function incrementRateLimit(env, request, userId) {
  const periods = [
    { name: 'minute', ttl: 60 },
    { name: 'hour', ttl: 3600 },
    { name: 'day', ttl: 86400 },
  ];
  
  const clientIP = getClientIP(request);
  const isUserBased = userId && userId !== 'anonymous';
  
  const promises = periods.map(async ({ name, ttl }) => {
    if (isUserBased) {
      // Increment user-based counter
      const key = getRateLimitKey(userId, name, false);
      const count = parseInt((await env.RATE_LIMITS.get(key)) || '0');
      await env.RATE_LIMITS.put(key, String(count + 1), { expirationTtl: ttl });
    } else {
      // Increment IP-based counter
      const key = getRateLimitKey(clientIP, name, true);
      const count = parseInt((await env.RATE_LIMITS.get(key)) || '0');
      await env.RATE_LIMITS.put(key, String(count + 1), { expirationTtl: ttl });
    }
  });
  
  await Promise.all(promises);
}

// Estimate token count (rough approximation)
function estimateTokens(messages) {
  let totalTokens = 0;
  
  for (const message of messages) {
    if (typeof message.content === 'string') {
      // Rough estimate: 1 token per 4 characters
      totalTokens += Math.ceil(message.content.length / 4);
    } else if (Array.isArray(message.content)) {
      // Handle multimodal content
      for (const item of message.content) {
        if (item.type === 'text' && item.text) {
          totalTokens += Math.ceil(item.text.length / 4);
        } else if (item.type === 'image_url') {
          // Each image adds approximately 765 tokens for vision models
          totalTokens += 765;
        }
      }
    }
  }
  
  return totalTokens;
}

// Validate request signature
async function validateRequestSignature(request, env, body) {
  const signature = request.headers.get('X-Request-Signature');
  const timestamp = request.headers.get('X-Request-Timestamp');
  
  if (!signature || !timestamp) {
    return false;
  }
  
  // Check timestamp is within replay window
  const requestTime = parseInt(timestamp);
  const now = Date.now();
  if (Math.abs(now - requestTime) > SECURITY_CONFIG.replayWindowMs) {
    return false;
  }
  
  // Verify signature
  const encoder = new TextEncoder();
  const data = encoder.encode(`${timestamp}.${JSON.stringify(body)}`);
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(env.APP_SECRET),
    { name: 'HMAC', hash: SECURITY_CONFIG.signatureAlgorithm },
    false,
    ['verify']
  );
  
  const signatureBuffer = Uint8Array.from(atob(signature), c => c.charCodeAt(0));
  return await crypto.subtle.verify('HMAC', key, signatureBuffer, data);
}

// Validate and sanitize messages
function validateMessages(messages) {
  if (!Array.isArray(messages)) {
    throw new Error('Messages must be an array');
  }
  
  if (messages.length > SECURITY_CONFIG.maxMessagesPerRequest) {
    throw new Error(`Too many messages. Maximum allowed: ${SECURITY_CONFIG.maxMessagesPerRequest}`);
  }
  
  // Sanitize messages
  const sanitized = messages.map(msg => {
    if (!msg.role || !['user', 'assistant', 'system'].includes(msg.role)) {
      throw new Error('Invalid message role');
    }
    
    // Basic sanitization to prevent prompt injection
    if (typeof msg.content === 'string') {
      // Remove potential injection patterns
      msg.content = msg.content
        .replace(/\[INST\]/gi, '')
        .replace(/\[\/INST\]/gi, '')
        .replace(/\{\{.*?\}\}/g, '')
        .replace(/<\|.*?\|>/g, '');
    }
    
    return msg;
  });
  
  return sanitized;
}

// Log request for analytics
async function logRequest(env, userId, model, functionCall, tokenCount) {
  const timestamp = new Date().toISOString();
  const key = `log:${userId}:${timestamp}`;
  const log = {
    timestamp,
    userId,
    model,
    functionCall,
    estimatedTokens: tokenCount,
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
        category: { type: 'string', description: 'Category name - use one of: work, personal, health, learning, meeting, fitness, finance, family, social, travel, shopping, hobby, home, creative, other' },
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
            category: { type: 'string', description: 'Category name (built-in or custom)' },
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
    name: 'delete_multiple_events',
    description: 'Delete multiple specific events at once',
    parameters: {
      type: 'object',
      properties: {
        eventIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of event IDs to delete',
        },
      },
      required: ['eventIds'],
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
    description: 'Create multiple calendar events at once. MUST include category for EACH event. Use varied categories: work, personal, health, learning, meeting, other.',
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
              category: { type: 'string', description: 'MUST use an existing category (default: work, personal, health, learning, meeting, other) OR a user-created category' },
              notes: { type: 'string', description: 'Optional notes' },
            },
            required: ['title', 'startTime', 'endTime', 'category'],
          },
        },
      },
      required: ['events'],
    },
  },
  {
    name: 'update_all_events',
    description: 'Update all events for a specific date with the same changes. Can update any combination of title, time, category, location, notes, or completion status.',
    parameters: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'ISO 8601 date (YYYY-MM-DD) for which to update all events' },
        updates: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'New title for all events' },
            startTime: { type: 'string', description: 'ISO 8601 datetime to set as start time (will adjust end time to maintain duration)' },
            endTime: { type: 'string', description: 'ISO 8601 datetime to set as end time' },
            addMinutes: { type: 'number', description: 'Number of minutes to add to all event times (negative to subtract)' },
            category: { type: 'string', description: 'Category name (built-in or custom)' },
            location: { type: 'string', description: 'Location for all events' },
            notes: { type: 'string', description: 'Notes for all events' },
            isCompleted: { type: 'boolean', description: 'Mark all as completed or not completed' },
          },
        },
      },
      required: ['date', 'updates'],
    },
  },
  {
    name: 'update_multiple_events',
    description: 'Update multiple specific events by their IDs. Perfect for moving specific events to a different date/time.',
    parameters: {
      type: 'object',
      properties: {
        eventIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of event IDs (UUID format) to update'
        },
        updates: {
          type: 'object',
          properties: {
            title: { type: 'string' },
            startTime: { type: 'string', description: 'ISO 8601 datetime' },
            endTime: { type: 'string', description: 'ISO 8601 datetime' },
            category: { type: 'string', description: 'Category name (built-in or custom)' },
            notes: { type: 'string' },
            isCompleted: { type: 'boolean' },
            adjustTimeOnly: { type: 'boolean', description: 'If true, only change the time but keep the same date' }
          }
        }
      },
      required: ['eventIds', 'updates']
    }
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
        category: { type: 'string', description: 'Category name - use one of: work, personal, health, learning, meeting, fitness, finance, family, social, travel, shopping, hobby, home, creative, other' },
        notes: { type: 'string', description: 'Optional notes' },
      },
      required: ['title', 'startTime', 'duration', 'recurrence'],
    },
  },
  {
    name: 'move_all_events',
    description: 'Move ALL events from one date to another date. Use this when the user wants to reschedule an entire day (e.g., "move all today\'s events to tomorrow", "reschedule Monday to Tuesday", "change all events from today to next week").',
    parameters: {
      type: 'object',
      properties: {
        fromDate: { type: 'string', description: 'ISO 8601 date (YYYY-MM-DD) to move events from (e.g., "2024-01-15" for today)' },
        toDate: { type: 'string', description: 'ISO 8601 date (YYYY-MM-DD) to move events to (e.g., "2024-01-16" for tomorrow)' },
        preserveTime: { type: 'boolean', description: 'If true, keep the same time on the new date. If false, stack events starting from morning.', default: true }
      },
      required: ['fromDate', 'toDate']
    }
  },
  {
    name: 'create_category',
    description: 'Create a custom category with a color and icon',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Category name' },
        color: { type: 'string', description: 'Hex color code (e.g., "#FF5733") or color name (e.g., "red", "blue", "purple")' },
        icon: { 
          type: 'string', 
          description: 'SF Symbol name (e.g., "briefcase.fill", "heart.fill", "book.fill", "dumbbell.fill", "person.3.fill", "house.fill", "car.fill", "airplane", "music.note", "paintbrush.fill", "camera.fill", "gamecontroller.fill", "gift.fill", "cart.fill", "leaf.fill", "star.fill", "flag.fill", "bell.fill", "envelope.fill", "phone.fill", "bubble.left.fill", "video.fill", "mic.fill", "headphones", "tv.fill", "display", "keyboard", "printer.fill", "scanner", "folder.fill", "paperclip", "link", "lock.fill", "key.fill", "shield.fill", "crown.fill", "hands.clap.fill", "hand.thumbsup.fill", "face.smiling.fill", "sun.max.fill", "moon.fill", "cloud.fill", "bolt.fill", "flame.fill", "drop.fill", "wind", "tornado", "bicycle", "scooter", "bus.fill", "tram.fill", "train.side.front.car", "ferry.fill", "airplane.departure", "rocket.fill", "globe.americas.fill", "map.fill", "building.2.fill", "house.and.flag.fill", "tent.fill", "tree.fill", "mountain.2.fill", "beach.umbrella.fill", "sportscourt.fill", "football.fill", "baseball.fill", "basketball.fill", "tennis.racket", "hockey.puck.fill", "figure.run", "figure.walk", "figure.dance", "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "birthday.cake.fill", "carrot.fill", "applelogo", "cross.case.fill", "pills.fill", "bandage.fill", "heart.text.square.fill", "bed.double.fill", "alarm.fill", "stopwatch.fill", "timer", "clock.fill", "calendar", "note.text", "doc.text.fill", "book.closed.fill", "bookmark.fill", "graduationcap.fill", "pencil", "highlighter", "scissors", "ruler.fill", "paperplane.fill", "tray.fill", "archivebox.fill", "tag.fill", "ticket.fill", "puzzlepiece.fill", "lightbulb.fill", "brain", "atom", "function", "percent", "chart.line.uptrend.xyaxis", "chart.pie.fill", "creditcard.fill", "banknote.fill", "dollarsign.circle.fill", "cart.fill.badge.plus", "giftcard.fill", "wallet.pass.fill")' 
        },
      },
      required: ['name', 'color', 'icon'],
    },
  },
  // Task Management Functions
  // Bulk Task Operations FIRST to prioritize them
  {
    name: 'create_multiple_tasks',
    description: '🚨 USE THIS FOR MULTIPLE TASKS! When user says "create 3 tasks", "add 5 tasks", "create tasks for X" - this creates many tasks at once. Each task is a separate object in the tasks array.',
    parameters: {
      type: 'object',
      properties: {
        tasks: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              title: { type: 'string', description: 'Task title' },
              notes: { type: 'string', description: 'Optional task notes' },
              dueDate: { type: 'string', description: 'Optional ISO 8601 date/datetime' },
              priority: { type: 'string', enum: ['low', 'medium', 'high'] },
              category: { type: 'string', description: 'Optional category' },
              tags: { type: 'array', items: { type: 'string' } },
              estimatedDuration: { type: 'number', description: 'Duration in minutes' },
              scheduledTime: { type: 'string', description: 'ISO 8601 datetime' },
              subtasks: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    title: { type: 'string' },
                    notes: { type: 'string' },
                  },
                  required: ['title'],
                },
                description: 'Optional subtasks to create with this task',
              },
            },
            required: ['title'],
          },
          description: 'Array of tasks to create',
        },
      },
      required: ['tasks'],
    },
  },
  {
    name: 'update_multiple_tasks',
    description: 'Update multiple tasks at once by their IDs with full attribute support',
    parameters: {
      type: 'object',
      properties: {
        taskIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of task IDs to update',
        },
        updates: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'New title for all tasks' },
            notes: { type: 'string', description: 'New notes/description for all tasks' },
            priority: { type: 'string', enum: ['low', 'medium', 'high'] },
            category: { type: 'string' },
            dueDate: { type: 'string', description: 'ISO 8601 date' },
            scheduledTime: { type: 'string', description: 'ISO 8601 datetime' },
            estimatedDuration: { type: 'number', description: 'Estimated duration in minutes' },
            tags: { type: 'array', items: { type: 'string' } },
            addTags: { type: 'array', items: { type: 'string' }, description: 'Tags to add without replacing existing' },
            removeTags: { type: 'array', items: { type: 'string' }, description: 'Tags to remove' },
            isCompleted: { type: 'boolean', description: 'Mark as completed or not completed' },
          },
        },
      },
      required: ['taskIds', 'updates'],
    },
  },
  {
    name: 'update_all_tasks',
    description: 'Update all tasks matching certain criteria with the same changes',
    parameters: {
      type: 'object',
      properties: {
        filter: {
          type: 'object',
          description: 'Filter criteria (if empty, updates ALL tasks)',
          properties: {
            date: { type: 'string', description: 'Update all tasks due on this date (ISO 8601)' },
            priority: { type: 'string', enum: ['low', 'medium', 'high'], description: 'Update all tasks with this priority' },
            category: { type: 'string', description: 'Update all tasks in this category' },
            tag: { type: 'string', description: 'Update all tasks with this tag' },
            overdue: { type: 'boolean', description: 'Update all overdue tasks' },
            completed: { type: 'boolean', description: 'Update completed or incomplete tasks' },
          },
        },
        updates: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'New title for all matching tasks' },
            notes: { type: 'string', description: 'New notes/description' },
            priority: { type: 'string', enum: ['low', 'medium', 'high'] },
            category: { type: 'string' },
            dueDate: { type: 'string', description: 'ISO 8601 date' },
            addDays: { type: 'number', description: 'Number of days to add to due date (negative to subtract)' },
            scheduledTime: { type: 'string', description: 'ISO 8601 datetime' },
            estimatedDuration: { type: 'number', description: 'Estimated duration in minutes' },
            tags: { type: 'array', items: { type: 'string' } },
            addTags: { type: 'array', items: { type: 'string' }, description: 'Tags to add' },
            removeTags: { type: 'array', items: { type: 'string' }, description: 'Tags to remove' },
            isCompleted: { type: 'boolean', description: 'Mark as completed or not completed' },
          },
        },
      },
      required: ['updates'],
    },
  },
  {
    name: 'complete_multiple_tasks',
    description: 'Mark multiple tasks as completed at once',
    parameters: {
      type: 'object',
      properties: {
        taskIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of task IDs to mark as completed',
        },
      },
      required: ['taskIds'],
    },
  },
  {
    name: 'reopen_multiple_tasks',
    description: 'Reopen multiple completed tasks',
    parameters: {
      type: 'object',
      properties: {
        taskIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of task IDs to reopen',
        },
      },
      required: ['taskIds'],
    },
  },
  {
    name: 'delete_multiple_tasks',
    description: 'Delete multiple tasks at once',
    parameters: {
      type: 'object',
      properties: {
        taskIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of task IDs to delete',
        },
      },
      required: ['taskIds'],
    },
  },
  {
    name: 'complete_all_tasks_by_filter',
    description: 'Complete all tasks matching certain criteria',
    parameters: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'Complete all tasks due on this date (ISO 8601)' },
        priority: { type: 'string', enum: ['low', 'medium', 'high'], description: 'Complete all tasks with this priority' },
        category: { type: 'string', description: 'Complete all tasks in this category' },
        tag: { type: 'string', description: 'Complete all tasks with this tag' },
        overdue: { type: 'boolean', description: 'Complete all overdue tasks' },
      },
    },
  },
  {
    name: 'delete_all_completed_tasks',
    description: 'Delete all completed tasks (cleanup operation)',
    parameters: {
      type: 'object',
      properties: {
        olderThanDays: { type: 'number', description: 'Only delete tasks completed more than X days ago' },
      },
    },
  },
  {
    name: 'delete_all_tasks',
    description: 'Delete ALL tasks or all tasks matching criteria. Use with caution!',
    parameters: {
      type: 'object',
      properties: {
        filter: {
          type: 'object',
          description: 'Filter criteria (if empty, deletes ALL tasks)',
          properties: {
            date: { type: 'string', description: 'Delete all tasks due on this date (ISO 8601)' },
            priority: { type: 'string', enum: ['low', 'medium', 'high'], description: 'Delete all tasks with this priority' },
            category: { type: 'string', description: 'Delete all tasks in this category' },
            tag: { type: 'string', description: 'Delete all tasks with this tag' },
            overdue: { type: 'boolean', description: 'Delete all overdue tasks' },
            completed: { type: 'boolean', description: 'Delete completed or incomplete tasks' },
          },
        },
        confirm: { type: 'boolean', description: 'Must be true to confirm deletion' },
      },
      required: ['confirm'],
    },
  },
  {
    name: 'reschedule_tasks',
    description: 'Reschedule multiple tasks to a new date/time',
    parameters: {
      type: 'object',
      properties: {
        taskIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Task IDs to reschedule',
        },
        newDate: { type: 'string', description: 'New date (ISO 8601) for all tasks' },
        preserveTime: { type: 'boolean', description: 'Keep original times, just change date' },
        spacingMinutes: { type: 'number', description: 'Space tasks by X minutes starting from newDate' },
      },
      required: ['taskIds', 'newDate'],
    },
  },
  // Single Task Operations (after bulk operations)
  {
    name: 'create_task',
    description: 'Create a single new task (for ONE task only - use create_multiple_tasks for multiple)',
    parameters: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'Task title' },
        notes: { type: 'string', description: 'Optional task notes/description' },
        dueDate: { type: 'string', description: 'Optional ISO 8601 date/datetime when task is due' },
        priority: { type: 'string', enum: ['low', 'medium', 'high'], description: 'Task priority (default: medium)' },
        category: { type: 'string', description: 'Optional category name (built-in or custom)' },
        tags: { 
          type: 'array', 
          items: { type: 'string' },
          description: 'Optional tags for organizing tasks' 
        },
        estimatedDuration: { type: 'number', description: 'Estimated duration in minutes' },
        scheduledTime: { type: 'string', description: 'Optional ISO 8601 datetime to schedule the task' },
      },
      required: ['title'],
    },
  },
  {
    name: 'list_tasks',
    description: 'List tasks based on filters (by date, status, priority, or tags)',
    parameters: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'ISO 8601 date to get tasks for' },
        status: { type: 'string', enum: ['all', 'pending', 'completed', 'overdue'], description: 'Filter by task status' },
        priority: { type: 'string', enum: ['low', 'medium', 'high'], description: 'Filter by priority' },
        tag: { type: 'string', description: 'Filter by tag' },
        unscheduled: { type: 'boolean', description: 'Show only unscheduled tasks' },
      },
    },
  },
  {
    name: 'update_task',
    description: 'Update an existing task',
    parameters: {
      type: 'object',
      properties: {
        taskId: { type: 'string', description: 'Task ID to update' },
        title: { type: 'string', description: 'New title' },
        notes: { type: 'string', description: 'New notes' },
        dueDate: { type: 'string', description: 'New due date (ISO 8601)' },
        priority: { type: 'string', enum: ['low', 'medium', 'high'], description: 'New priority' },
        category: { type: 'string', description: 'New category' },
        tags: { 
          type: 'array', 
          items: { type: 'string' },
          description: 'New tags for organizing tasks' 
        },
        estimatedDuration: { type: 'number', description: 'New estimated duration in minutes' },
        scheduledTime: { type: 'string', description: 'New scheduled time (ISO 8601)' },
      },
      required: ['taskId'],
    },
  },
  {
    name: 'complete_task',
    description: 'Mark a task as completed',
    parameters: {
      type: 'object',
      properties: {
        taskId: { type: 'string', description: 'Task ID to complete' },
      },
      required: ['taskId'],
    },
  },
  {
    name: 'delete_task',
    description: 'Delete a task',
    parameters: {
      type: 'object',
      properties: {
        taskId: { type: 'string', description: 'Task ID to delete' },
      },
      required: ['taskId'],
    },
  },
  {
    name: 'create_subtasks',
    description: 'Create subtasks for an existing task',
    parameters: {
      type: 'object',
      properties: {
        parentTaskId: { type: 'string', description: 'Parent task ID' },
        subtasks: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              title: { type: 'string', description: 'Subtask title' },
              notes: { type: 'string', description: 'Optional notes' },
            },
            required: ['title'],
          },
          description: 'Array of subtasks to create',
        },
      },
      required: ['parentTaskId', 'subtasks'],
    },
  },
  {
    name: 'link_task_to_event',
    description: 'Link a task to a calendar event',
    parameters: {
      type: 'object',
      properties: {
        taskId: { type: 'string', description: 'Task ID' },
        eventId: { type: 'string', description: 'Event ID to link to' },
      },
      required: ['taskId', 'eventId'],
    },
  },
  {
    name: 'search_tasks',
    description: 'Search tasks by keyword in title or notes',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search query' },
        includeCompleted: { type: 'boolean', description: 'Include completed tasks in search' },
      },
      required: ['query'],
    },
  },
  {
    name: 'get_task_statistics',
    description: 'Get statistics about tasks (completion rate, overdue count, etc.)',
    parameters: {
      type: 'object',
      properties: {
        period: { type: 'string', enum: ['today', 'week', 'month', 'all'], description: 'Time period for statistics' },
      },
    },
  },
  // Habit Management Functions
  {
    name: 'create_habit',
    description: 'Create a new habit to track',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Habit name' },
        icon: { type: 'string', description: 'SF Symbol icon name (e.g., star.fill, heart.fill)' },
        color: { type: 'string', description: 'Hex color code (e.g., #FF6B6B)' },
        frequency: { type: 'string', enum: ['daily', 'weekly', 'custom'], description: 'How often to track' },
        trackingType: { type: 'string', enum: ['binary', 'quantity', 'duration', 'quality'], description: 'Type of tracking' },
        goalTarget: { type: 'number', description: 'Target value for quantity/duration tracking' },
        goalUnit: { type: 'string', description: 'Unit for the goal (e.g., glasses, minutes, pages)' },
        category: { type: 'string', description: 'Category name' },
        notes: { type: 'string', description: 'Additional notes' },
      },
      required: ['name'],
    },
  },
  {
    name: 'create_multiple_habits',
    description: 'Create multiple habits at once',
    parameters: {
      type: 'object',
      properties: {
        habits: {
          type: 'array',
          description: 'Array of habit objects to create',
          items: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Habit name' },
              icon: { type: 'string', description: 'SF Symbol icon name (e.g., star.fill, heart.fill)' },
              color: { type: 'string', description: 'Hex color code (e.g., #FF6B6B)' },
              frequency: { type: 'string', enum: ['daily', 'weekly', 'custom'], description: 'How often to track' },
              trackingType: { type: 'string', enum: ['binary', 'quantity', 'duration', 'quality'], description: 'Type of tracking' },
              goalTarget: { type: 'number', description: 'Target value for quantity/duration tracking' },
              goalUnit: { type: 'string', description: 'Unit for the goal (e.g., glasses, minutes, pages)' },
              category: { type: 'string', description: 'Category name' },
              notes: { type: 'string', description: 'Additional notes' },
            },
            required: ['name'],
          },
        },
      },
      required: ['habits'],
    },
  },
  {
    name: 'log_habit',
    description: 'Log/complete a habit for today or a specific date',
    parameters: {
      type: 'object',
      properties: {
        habitName: { type: 'string', description: 'Name of the habit to log' },
        value: { type: 'number', description: 'Value for quantity/duration/quality tracking (default: 1)' },
        date: { type: 'string', description: 'ISO 8601 date to log for (default: today)' },
        notes: { type: 'string', description: 'Notes about this entry' },
        mood: { type: 'number', description: 'Mood rating 1-5' },
        quality: { type: 'number', description: 'Quality rating 1-5' },
      },
      required: ['habitName'],
    },
  },
  {
    name: 'list_habits',
    description: 'List habits for today or a specific date',
    parameters: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'ISO 8601 date (default: today)' },
      },
    },
  },
  {
    name: 'update_habit',
    description: 'Update habit settings',
    parameters: {
      type: 'object',
      properties: {
        habitName: { type: 'string', description: 'Current habit name' },
        newName: { type: 'string', description: 'New name for the habit' },
        icon: { type: 'string', description: 'New icon' },
        color: { type: 'string', description: 'New color' },
        goalTarget: { type: 'number', description: 'New goal target' },
        goalUnit: { type: 'string', description: 'New goal unit' },
      },
      required: ['habitName'],
    },
  },
  {
    name: 'delete_habit',
    description: 'Delete a habit and all its data',
    parameters: {
      type: 'object',
      properties: {
        habitName: { type: 'string', description: 'Name of habit to delete' },
      },
      required: ['habitName'],
    },
  },
  {
    name: 'get_habit_stats',
    description: 'Get statistics and performance data for habits',
    parameters: {
      type: 'object',
      properties: {
        period: { type: 'string', enum: ['week', 'month', 'year'], description: 'Time period' },
      },
    },
  },
  {
    name: 'pause_habit',
    description: 'Temporarily pause a habit (vacation, injury, etc.)',
    parameters: {
      type: 'object',
      properties: {
        habitName: { type: 'string', description: 'Habit to pause' },
        days: { type: 'number', description: 'Number of days to pause (default: 7)' },
      },
      required: ['habitName'],
    },
  },
  {
    name: 'get_habit_insights',
    description: 'Get AI insights and correlations for habits',
    parameters: {
      type: 'object',
      properties: {
        habitName: { type: 'string', description: 'Specific habit to analyze (or all if not specified)' },
      },
    },
  },
  // Bulk Habit Operations
  {
    name: 'update_multiple_habits',
    description: 'Update multiple habits at once with full attribute support',
    parameters: {
      type: 'object',
      properties: {
        habitNames: {
          type: 'array',
          items: { type: 'string' },
          description: 'Names of habits to update',
        },
        updates: {
          type: 'object',
          description: 'Fields to update for all habits',
          properties: {
            name: { type: 'string', description: 'New name for all habits (be careful!)' },
            description: { type: 'string', description: 'New description for all habits' },
            icon: { type: 'string', description: 'New icon for all habits' },
            color: { type: 'string', description: 'New color for all habits' },
            goalTarget: { type: 'number', description: 'New goal target' },
            goalUnit: { type: 'string', description: 'New goal unit' },
            frequency: { type: 'string', enum: ['daily', 'weekly', 'custom'] },
            category: { type: 'string', description: 'New category for all habits' },
            reminderTime: { type: 'string', description: 'HH:MM format for daily reminder' },
            isPaused: { type: 'boolean', description: 'Pause or resume all habits' },
          },
        },
      },
      required: ['habitNames', 'updates'],
    },
  },
  {
    name: 'update_all_habits',
    description: 'Update all habits matching certain criteria with the same changes',
    parameters: {
      type: 'object',
      properties: {
        filter: {
          type: 'object',
          description: 'Filter criteria (if empty, updates ALL habits)',
          properties: {
            category: { type: 'string', description: 'Update all habits in this category' },
            frequency: { type: 'string', enum: ['daily', 'weekly', 'custom'], description: 'Update all habits with this frequency' },
            isPaused: { type: 'boolean', description: 'Update paused or active habits' },
            hasReminder: { type: 'boolean', description: 'Update habits with or without reminders' },
          },
        },
        updates: {
          type: 'object',
          properties: {
            description: { type: 'string', description: 'New description' },
            icon: { type: 'string', description: 'New icon' },
            color: { type: 'string', description: 'New color' },
            goalTarget: { type: 'number', description: 'New goal target' },
            goalUnit: { type: 'string', description: 'New goal unit' },
            frequency: { type: 'string', enum: ['daily', 'weekly', 'custom'] },
            category: { type: 'string', description: 'New category' },
            reminderTime: { type: 'string', description: 'HH:MM format for daily reminder' },
            isPaused: { type: 'boolean', description: 'Pause or resume habits' },
          },
        },
      },
      required: ['updates'],
    },
  },
  {
    name: 'delete_multiple_habits',
    description: 'Delete multiple habits at once',
    parameters: {
      type: 'object',
      properties: {
        habitNames: {
          type: 'array',
          items: { type: 'string' },
          description: 'Names of habits to delete',
        },
      },
      required: ['habitNames'],
    },
  },
  {
    name: 'delete_all_habits',
    description: 'Delete all habits (use with caution)',
    parameters: {
      type: 'object',
      properties: {
        category: { type: 'string', description: 'Only delete habits in this category' },
        includeData: { type: 'boolean', description: 'Also delete all habit entries/data' },
      },
    },
  },
  {
    name: 'pause_multiple_habits',
    description: 'Pause multiple habits at once',
    parameters: {
      type: 'object',
      properties: {
        habitNames: {
          type: 'array',
          items: { type: 'string' },
          description: 'Names of habits to pause',
        },
        days: { type: 'number', description: 'Number of days to pause (default: 7)' },
      },
      required: ['habitNames'],
    },
  },
  {
    name: 'resume_multiple_habits',
    description: 'Resume multiple paused habits',
    parameters: {
      type: 'object',
      properties: {
        habitNames: {
          type: 'array',
          items: { type: 'string' },
          description: 'Names of habits to resume',
        },
      },
      required: ['habitNames'],
    },
  },
  {
    name: 'log_multiple_habits',
    description: 'Log completion for multiple habits at once',
    parameters: {
      type: 'object',
      properties: {
        entries: {
          type: 'array',
          description: 'Array of habit entries to log',
          items: {
            type: 'object',
            properties: {
              habitName: { type: 'string', description: 'Name of the habit' },
              value: { type: 'number', description: 'Value for quantity/duration tracking' },
              date: { type: 'string', description: 'ISO 8601 date (default: today)' },
              notes: { type: 'string', description: 'Notes about this entry' },
              mood: { type: 'number', description: 'Mood rating 1-5' },
              quality: { type: 'number', description: 'Quality rating 1-5' },
            },
            required: ['habitName'],
          },
        },
      },
      required: ['entries'],
    },
  },
  // Goal Management Functions
  {
    name: 'create_goal',
    description: 'Create a new goal',
    parameters: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'Goal title' },
        description: { type: 'string', description: 'Detailed description of the goal' },
        type: { type: 'string', enum: ['milestone', 'numeric', 'habit', 'project'], description: 'Type of goal' },
        targetValue: { type: 'number', description: 'Target value for numeric goals' },
        targetDate: { type: 'string', description: 'ISO 8601 date when goal should be achieved' },
        unit: { type: 'string', description: 'Unit for numeric goals (e.g., pounds, miles, dollars)' },
        priority: { type: 'string', enum: ['low', 'medium', 'high', 'critical'], description: 'Goal priority' },
        category: { type: 'string', description: 'Category name' },
        currentValue: { type: 'number', description: 'Initial current value for numeric goals (default: 0)' },
        linkedHabitNames: { type: 'array', items: { type: 'string' }, description: 'Names of habits to link to this goal' },
      },
      required: ['title', 'type'],
    },
  },
  {
    name: 'create_multiple_goals',
    description: 'Create multiple goals at once',
    parameters: {
      type: 'object',
      properties: {
        goals: {
          type: 'array',
          description: 'Array of goal objects to create',
          items: {
            type: 'object',
            properties: {
              title: { type: 'string', description: 'Goal title' },
              description: { type: 'string', description: 'Detailed description' },
              type: { type: 'string', enum: ['milestone', 'numeric', 'habit', 'project'] },
              targetValue: { type: 'number' },
              targetDate: { type: 'string', description: 'ISO 8601 date' },
              unit: { type: 'string' },
              priority: { type: 'string', enum: ['low', 'medium', 'high', 'critical'] },
              category: { type: 'string' },
              currentValue: { type: 'number', description: 'Initial current value for numeric goals' },
              linkedHabitNames: { type: 'array', items: { type: 'string' } },
            },
            required: ['title', 'type'],
          },
        },
      },
      required: ['goals'],
    },
  },
  {
    name: 'list_goals',
    description: 'List goals based on filters',
    parameters: {
      type: 'object',
      properties: {
        status: { type: 'string', enum: ['active', 'completed', 'all'], description: 'Filter by goal status' },
        category: { type: 'string', description: 'Filter by category' },
        priority: { type: 'string', enum: ['low', 'medium', 'high', 'critical'], description: 'Filter by priority' },
        daysUntilDeadline: { type: 'number', description: 'Filter goals due within X days' },
      },
    },
  },
  {
    name: 'update_goal',
    description: 'Update an existing goal',
    parameters: {
      type: 'object',
      properties: {
        goalId: { type: 'string', description: 'Goal ID to update' },
        updates: {
          type: 'object',
          description: 'Fields to update',
          properties: {
            title: { type: 'string' },
            description: { type: 'string' },
            targetValue: { type: 'number' },
            targetDate: { type: 'string', description: 'ISO 8601 date' },
            unit: { type: 'string' },
            priority: { type: 'string', enum: ['low', 'medium', 'high', 'critical'] },
            category: { type: 'string' },
          },
        },
      },
      required: ['goalId'],
    },
  },
  {
    name: 'update_goal_progress',
    description: 'Update progress on a goal',
    parameters: {
      type: 'object',
      properties: {
        goalId: { type: 'string', description: 'Goal ID' },
        value: { type: 'number', description: 'Progress value' },
        notes: { type: 'string', description: 'Notes about this progress update' },
      },
      required: ['goalId', 'value'],
    },
  },
  {
    name: 'complete_goal',
    description: 'Mark a goal as completed',
    parameters: {
      type: 'object',
      properties: {
        goalId: { type: 'string', description: 'Goal ID to complete' },
        completionNotes: { type: 'string', description: 'Notes about goal completion' },
      },
      required: ['goalId'],
    },
  },
  {
    name: 'delete_goal',
    description: 'Delete a goal',
    parameters: {
      type: 'object',
      properties: {
        goalId: { type: 'string', description: 'Goal ID to delete' },
      },
      required: ['goalId'],
    },
  },
  {
    name: 'add_goal_milestone',
    description: 'Add a milestone to a goal',
    parameters: {
      type: 'object',
      properties: {
        goalId: { type: 'string', description: 'Goal ID' },
        title: { type: 'string', description: 'Milestone title' },
        targetValue: { type: 'number', description: 'Target value for this milestone' },
        targetDate: { type: 'string', description: 'ISO 8601 date for milestone' },
      },
      required: ['goalId', 'title'],
    },
  },
  {
    name: 'add_multiple_milestones',
    description: 'Add multiple milestones to one or more goals at once',
    parameters: {
      type: 'object',
      properties: {
        milestones: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              goalId: { type: 'string', description: 'Goal ID' },
              title: { type: 'string', description: 'Milestone title' },
              targetValue: { type: 'number', description: 'Target value for this milestone' },
              targetDate: { type: 'string', description: 'ISO 8601 date for milestone' },
            },
            required: ['goalId', 'title'],
          },
          description: 'Array of milestone objects to create',
        },
      },
      required: ['milestones'],
    },
  },
  {
    name: 'update_milestone',
    description: 'Update a single milestone',
    parameters: {
      type: 'object',
      properties: {
        milestoneId: { type: 'string', description: 'Milestone ID' },
        updates: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'New title' },
            targetValue: { type: 'number', description: 'New target value' },
            targetDate: { type: 'string', description: 'New target date (ISO 8601)' },
            isCompleted: { type: 'boolean', description: 'Mark as completed' },
          },
        },
      },
      required: ['milestoneId', 'updates'],
    },
  },
  {
    name: 'update_multiple_milestones',
    description: 'Update multiple milestones at once',
    parameters: {
      type: 'object',
      properties: {
        updates: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              milestoneId: { type: 'string', description: 'Milestone ID' },
              title: { type: 'string', description: 'New title' },
              targetValue: { type: 'number', description: 'New target value' },
              targetDate: { type: 'string', description: 'New target date (ISO 8601)' },
              isCompleted: { type: 'boolean', description: 'Mark as completed' },
            },
            required: ['milestoneId'],
          },
          description: 'Array of milestone updates',
        },
      },
      required: ['updates'],
    },
  },
  {
    name: 'delete_milestone',
    description: 'Delete a single milestone',
    parameters: {
      type: 'object',
      properties: {
        milestoneId: { type: 'string', description: 'Milestone ID to delete' },
        confirm: { type: 'boolean', description: 'Confirmation flag (always true)' },
      },
      required: ['milestoneId', 'confirm'],
    },
  },
  {
    name: 'delete_multiple_milestones',
    description: 'Delete multiple milestones at once',
    parameters: {
      type: 'object',
      properties: {
        milestoneIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of milestone IDs to delete',
        },
        confirm: { type: 'boolean', description: 'Confirmation flag (always true)' },
      },
      required: ['milestoneIds', 'confirm'],
    },
  },
  {
    name: 'complete_milestone',
    description: 'Mark a milestone as completed',
    parameters: {
      type: 'object',
      properties: {
        milestoneId: { type: 'string', description: 'Milestone ID' },
      },
      required: ['milestoneId'],
    },
  },
  {
    name: 'complete_multiple_milestones',
    description: 'Mark multiple milestones as completed',
    parameters: {
      type: 'object',
      properties: {
        milestoneIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of milestone IDs to complete',
        },
      },
      required: ['milestoneIds'],
    },
  },
  {
    name: 'link_goal_to_habits',
    description: 'Link a goal to one or more habits',
    parameters: {
      type: 'object',
      properties: {
        goalId: { type: 'string', description: 'Goal ID' },
        habitNames: { type: 'array', items: { type: 'string' }, description: 'Names of habits to link' },
      },
      required: ['goalId', 'habitNames'],
    },
  },
  {
    name: 'get_goal_statistics',
    description: 'Get goal completion statistics and insights',
    parameters: {
      type: 'object',
      properties: {
        period: { type: 'string', enum: ['week', 'month', 'year', 'all'], description: 'Time period for statistics' },
      },
    },
  },
  // Bulk Goal Operations
  {
    name: 'update_multiple_goals',
    description: 'Update multiple goals at once with full attribute support',
    parameters: {
      type: 'object',
      properties: {
        goalIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of goal IDs to update',
        },
        updates: {
          type: 'object',
          description: 'Fields to update for all goals',
          properties: {
            title: { type: 'string', description: 'New title for all goals' },
            description: { type: 'string', description: 'New description' },
            priority: { type: 'string', enum: ['low', 'medium', 'high', 'critical'] },
            targetDate: { type: 'string', description: 'ISO 8601 date' },
            targetValue: { type: 'number', description: 'New target value' },
            unit: { type: 'string', description: 'New unit of measurement' },
            category: { type: 'string', description: 'New category for all goals' },
            isCompleted: { type: 'boolean', description: 'Mark as completed or not completed' },
          },
        },
      },
      required: ['goalIds', 'updates'],
    },
  },
  {
    name: 'update_all_goals',
    description: 'Update all goals matching certain criteria with the same changes',
    parameters: {
      type: 'object',
      properties: {
        filter: {
          type: 'object',
          description: 'Filter criteria (if empty, updates ALL goals)',
          properties: {
            type: { type: 'string', enum: ['milestone', 'numeric', 'habit', 'project'], description: 'Update all goals of this type' },
            priority: { type: 'string', enum: ['low', 'medium', 'high', 'critical'], description: 'Update all goals with this priority' },
            category: { type: 'string', description: 'Update all goals in this category' },
            isCompleted: { type: 'boolean', description: 'Update completed or incomplete goals' },
            overdue: { type: 'boolean', description: 'Update overdue goals' },
          },
        },
        updates: {
          type: 'object',
          properties: {
            description: { type: 'string', description: 'New description' },
            priority: { type: 'string', enum: ['low', 'medium', 'high', 'critical'] },
            targetDate: { type: 'string', description: 'ISO 8601 date' },
            addDays: { type: 'number', description: 'Number of days to add to target date (negative to subtract)' },
            targetValue: { type: 'number', description: 'New target value' },
            unit: { type: 'string', description: 'New unit of measurement' },
            category: { type: 'string', description: 'New category' },
            isCompleted: { type: 'boolean', description: 'Mark as completed or not completed' },
          },
        },
      },
      required: ['updates'],
    },
  },
  {
    name: 'delete_multiple_goals',
    description: 'Delete multiple goals at once',
    parameters: {
      type: 'object',
      properties: {
        goalIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of goal IDs to delete',
        },
      },
      required: ['goalIds'],
    },
  },
  {
    name: 'delete_all_goals',
    description: 'Delete all goals (use with caution)',
    parameters: {
      type: 'object',
      properties: {
        status: { type: 'string', enum: ['active', 'completed', 'all'], description: 'Filter by status' },
        category: { type: 'string', description: 'Only delete goals in this category' },
      },
    },
  },
  {
    name: 'complete_multiple_goals',
    description: 'Mark multiple goals as completed',
    parameters: {
      type: 'object',
      properties: {
        goalIds: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of goal IDs to complete',
        },
        completionNotes: { type: 'string', description: 'Notes about completion' },
      },
      required: ['goalIds'],
    },
  },
  {
    name: 'update_multiple_goal_progress',
    description: 'Update progress for multiple goals at once',
    parameters: {
      type: 'object',
      properties: {
        updates: {
          type: 'array',
          description: 'Array of progress updates',
          items: {
            type: 'object',
            properties: {
              goalId: { type: 'string', description: 'Goal ID' },
              value: { type: 'number', description: 'Progress value' },
              notes: { type: 'string', description: 'Notes about this update' },
            },
            required: ['goalId', 'value'],
          },
        },
      },
      required: ['updates'],
    },
  },
  // Cross-Entity Operations
  {
    name: 'create_goal_with_habits',
    description: 'Create a goal and automatically create and link related habits',
    parameters: {
      type: 'object',
      properties: {
        goal: {
          type: 'object',
          properties: {
            title: { type: 'string' },
            description: { type: 'string' },
            type: { type: 'string', enum: ['milestone', 'numeric', 'habit', 'project'] },
            targetValue: { type: 'number' },
            targetDate: { type: 'string', description: 'ISO 8601 date' },
            unit: { type: 'string' },
            priority: { type: 'string', enum: ['low', 'medium', 'high', 'critical'] },
            category: { type: 'string' },
          },
          required: ['title', 'type'],
        },
        habits: {
          type: 'array',
          description: 'Habits to create and link to the goal',
          items: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              icon: { type: 'string' },
              color: { type: 'string' },
              frequency: { type: 'string', enum: ['daily', 'weekly', 'custom'] },
              trackingType: { type: 'string', enum: ['binary', 'quantity', 'duration', 'quality'] },
              goalTarget: { type: 'number' },
              goalUnit: { type: 'string' },
            },
            required: ['name'],
          },
        },
      },
      required: ['goal', 'habits'],
    },
  },
];

// Combine all functions including additional CRUD operations
// Remove create_category since we now have 15 built-in categories
const ALL_FUNCTIONS = [...FUNCTIONS, ...ALL_ADDITIONAL_FUNCTIONS].filter(f => f.name !== 'create_category');

// System prompt for the AI
const SYSTEM_PROMPT = `# Momentum Assistant

You are an AI calendar and task management assistant. You help users organize their time, tasks, habits, and goals.

## CRITICAL RULES

### 1. CONTEXT AWARENESS
The system message includes "USER'S CURRENT CONTEXT" with their:
- Goals (with IDs!), tasks, habits, and events
- DO NOT call list functions to gather data you already have
- Use the provided context instead of asking questions
- When adding milestones to existing goals, use the goal IDs from context
- NOTE: Context updates between messages - check for newly created items

### 2. BULK OPERATIONS
- Multiple tasks → use create_multiple_tasks (NOT create_task repeatedly)
- Multiple events → use create_multiple_events
- Multiple habits → use create_multiple_habits
- Each item must be separate - don't consolidate into notes

### 3. STREAMING LIMITATION
- You can only make ONE function call per response
- For operations needing multiple steps, explain and guide the user
- IMPORTANT: You cannot create goals AND add milestones in same response
- After creating goals, tell user: "Goals created! Say 'add milestones' to add milestones to them"

### 4. CATEGORIES
- EVERY event MUST have a category field
- Use: work, personal, health, learning, meeting, fitness, finance, family, social, travel, shopping, hobby, home, creative, other
- Match categories intelligently to content

### 5. TIME HANDLING
- User times = their local timezone
- Convert to UTC for function calls
- "Move up/forward" = EARLIER, "Push back/delay" = LATER

## TASK FIELDS
- title: Required
- priority: high/medium/low (default: medium)
- category: Match to content (use lowercase)
- estimatedDuration: Be realistic (e.g., "drink water"=2min, "workout"=30-60min)
- dueDate, notes, tags: Add when relevant

## RESPONSE FORMAT
- **Bold** for titles, times, dates
- _Italics_ for categories, notes
- • Bullet points for lists
- ✅ Success indicators
- Never show IDs/UUIDs

## EXAMPLES

"Create 3 workout tasks":
{
  "name": "create_multiple_tasks",
  "arguments": {
    "tasks": [
      {"title": "Morning run", "category": "fitness", "estimatedDuration": 30},
      {"title": "Strength training", "category": "fitness", "estimatedDuration": 45},
      {"title": "Evening yoga", "category": "fitness", "estimatedDuration": 20}
    ]
  }
}

"Schedule based on my goals":
✓ Check context for user's goals
✓ Create events using create_multiple_events
✗ Don't call list_goals

"Delete all my tasks":
{
  "name": "delete_all_tasks",
  "arguments": {
    "filters": {},
    "confirm": true
  }
}

"Add milestones" (after creating goals):
1. First: {"name": "list_goals", "arguments": {}}
2. Then for each goal: {
  "name": "add_goal_milestone",
  "arguments": {
    "goalId": "[actual-id-from-list]",
    "title": "First milestone",
    "targetValue": 25
  }
}

CRITICAL COUNTING RULE:
- User says "create 10 habits" = create EXACTLY 10 habit objects
- User says "create 5 tasks" = create EXACTLY 5 task objects

## HABIT TRACKING
- Types: binary (yes/no), quantity (count), duration (time), quality (1-5)
- Track streaks and provide encouragement
- "Log meditation" → log_habit
- "Drank 6 glasses" → log_habit with value: 6

## GOALS AND MILESTONES
- Creating goals with milestones requires 2 steps (due to streaming limits)
- Step 1: Create goals using create_goal or create_multiple_goals
- Step 2: Add milestones using goal IDs from context

When user says "create goals with milestones":
1. First response: Create the goals
2. Tell user: "✅ Created [X] goals! Now say 'add milestones' and I'll add milestones to each goal."

When user says "add milestones" or "create milestones for my goal":
1. Check the USER'S CURRENT CONTEXT for existing goals with their IDs
2. Use add_multiple_milestones to add all milestones in one call
3. DO NOT call list_goals - use the goal IDs already in your context!

Example:
{
  "name": "add_multiple_milestones",
  "arguments": {
    "milestones": [
      {"goalId": "id-from-context", "title": "Lose 5 pounds", "targetValue": 5},
      {"goalId": "id-from-context", "title": "Lose 10 pounds", "targetValue": 10},
      {"goalId": "different-goal-id", "title": "Complete Chapter 1"}
    ]
  }
}
   
Example milestone ideas:
- Fitness goal → "Lose 5 lbs", "Run 5K", "Gym 3x/week for a month"
- Learning goal → "Complete chapter 1", "Pass quiz", "Finish course"
- Project goal → "Design phase", "Implementation", "Testing", "Launch"

## DELETE OPERATIONS
- ALWAYS set confirm: true when calling delete functions
- User saying "delete" = they confirmed, so set confirm: true
- Never ask user to confirm - just do it with confirm: true
- For delete_all_tasks, delete_multiple_tasks, etc: ALWAYS include "confirm": true in arguments
- Example: {"filter": {}, "confirm": true} or {"filters": {}, "confirm": true}

Remember: Be helpful, use context, and follow the rules above!`;

export default {
  async fetch(request, env, ctx) {
    console.log('🚀 REQUEST RECEIVED:', {
      method: request.method,
      url: request.url,
      headers: Object.fromEntries(request.headers.entries())
    });
    
    // Handle test endpoint to see the request
    const url = new URL(request.url);
    if (url.pathname === '/test-request' && request.method === 'GET') {
      // Minimal test with single function
      const minimalFunction = {
        name: 'create_event',
        description: 'Create a new calendar event',
        parameters: {
          type: 'object',
          properties: {
            title: { type: 'string' },
            startTime: { type: 'string' },
            endTime: { type: 'string' }
          },
          required: ['title', 'startTime', 'endTime']
        }
      };
      
      const testRequest = {
        model: 'o4-mini',
        messages: [
          {
            role: 'user',
            content: 'Create a meeting at 3pm'
          }
        ],
        functions: [minimalFunction],
        max_completion_tokens: 4096,
        stream: false
      };
      
      return new Response(JSON.stringify({
        message: 'This is what gets sent to OpenAI for o4-mini',
        endpoint: 'https://api.openai.com/v1/chat/completions',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_OPENAI_API_KEY'
        },
        body: testRequest
      }, null, 2), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    
    // Test endpoint to actually make the call
    if (url.pathname === '/test-o4-mini' && request.method === 'GET') {
      const testPayload = {
        model: 'o4-mini',
        messages: [
          { role: 'user', content: 'Say hello' }
        ],
        max_completion_tokens: 100
      };
      
      console.log('🧪 Testing O4-MINI with minimal payload:', JSON.stringify(testPayload, null, 2));
      
      const testResponse = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
        },
        body: JSON.stringify(testPayload),
      });
      
      const responseText = await testResponse.text();
      console.log('🧪 Test response status:', testResponse.status);
      console.log('🧪 Test response:', responseText);
      
      return new Response(JSON.stringify({
        status: testResponse.status,
        headers: Object.fromEntries(testResponse.headers.entries()),
        body: responseText,
        request: testPayload
      }, null, 2), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    
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
      
      // Check request size
      const contentLength = parseInt(request.headers.get('content-length') || '0');
      if (contentLength > SECURITY_CONFIG.maxRequestSize) {
        console.log('❌ Request too large:', contentLength);
        return new Response(JSON.stringify({ error: 'Request too large' }), {
          status: 413,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      
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
      
      // Get user ID and device ID for better rate limiting
      const userId = request.headers.get('X-User-ID');
      const deviceId = request.headers.get('X-Device-ID');
      
      // Validate user ID if provided
      if (userId && !/^[a-zA-Z0-9-_]+$/.test(userId)) {
        console.log('❌ Invalid user ID format');
        return new Response(JSON.stringify({ error: 'Invalid user ID format' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      
      console.log('👤 User ID:', userId || 'none');
      console.log('📱 Device ID:', deviceId || 'none');
      
      // Parse request body with timeout
      const bodyPromise = request.json();
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Request parsing timeout')), 5000)
      );
      
      const body = await Promise.race([bodyPromise, timeoutPromise]);
      console.log('📨 Request body size:', JSON.stringify(body).length);
      
      // Validate request signature (optional for now, will be enforced later)
      const hasSignature = request.headers.get('X-Request-Signature') !== null;
      if (hasSignature) {
        const isValidSignature = await validateRequestSignature(request, env, body);
        if (!isValidSignature) {
          console.log('❌ Invalid request signature');
          return new Response(JSON.stringify({ error: 'Invalid request signature' }), {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        console.log('✅ Request signature verified');
      }
      
      const { messages, model = 'gpt-4o-mini', stream = false, userContext } = body;
      
      // Validate and sanitize messages
      let sanitizedMessages;
      try {
        sanitizedMessages = validateMessages(messages);
      } catch (error) {
        console.log('❌ Message validation failed:', error.message);
        return new Response(JSON.stringify({ error: error.message }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      
      // Estimate token count
      const estimatedTokens = estimateTokens(sanitizedMessages);
      console.log('🔢 Estimated tokens:', estimatedTokens);
      
      if (estimatedTokens > SECURITY_CONFIG.maxTokensEstimate) {
        console.log('❌ Request exceeds token limit');
        return new Response(JSON.stringify({ 
          error: 'Request too large',
          estimatedTokens,
          maxAllowed: SECURITY_CONFIG.maxTokensEstimate 
        }), {
          status: 413,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      
      // Check if any message contains images and adjust model if needed
      let effectiveModel = model;
      const hasImages = sanitizedMessages.some(msg => {
        if (Array.isArray(msg.content)) {
          return msg.content.some(part => part.type === 'image_url');
        }
        return false;
      });
      
      // If images are present, ensure we're using a vision-capable model
      if (hasImages) {
        // IMPORTANT: gpt-4o-mini does NOT support vision, despite the name
        // We must use gpt-4o or gpt-4-turbo for vision capabilities
        console.log('🖼️ Images detected in messages, switching to vision-capable model');
        effectiveModel = 'gpt-4o'; // Use gpt-4o which has vision support
      }
      
      console.log('🤖 Model:', effectiveModel);
      console.log('📡 Stream:', stream);
      console.log('📋 User context:', userContext ? 'Present' : 'Not provided');
      console.log('🖼️ Contains images:', hasImages);
      
      // Check rate limits
      const isPremium = userContext?.isPremium || false;
      const rateLimitCheck = await checkRateLimit(env, request, userId, isPremium);
      
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
      
      // Token management - trim conversation history if needed
      const MAX_CONTEXT_TOKENS = 8000; // Leave room for response
      const CHARS_PER_TOKEN = 4; // Rough estimate
      
      // Estimate tokens for system message (including user context)
      const systemMessageLength = SYSTEM_PROMPT.length + 1000 + 
        (userContext?.personalContext?.length || 0) + 
        JSON.stringify(userContext?.todaySchedule || []).length +
        JSON.stringify(userContext?.completionHistory || []).length;
      let totalTokenEstimate = Math.ceil(systemMessageLength / CHARS_PER_TOKEN);
      
      // Keep messages from newest to oldest until we hit token limit
      const messagesToKeep = [];
      for (let i = sanitizedMessages.length - 1; i >= 0; i--) {
        const msg = sanitizedMessages[i];
        const msgContent = typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content);
        const msgTokens = Math.ceil(msgContent.length / CHARS_PER_TOKEN);
        
        if (totalTokenEstimate + msgTokens > MAX_CONTEXT_TOKENS && messagesToKeep.length > 0) {
          console.log(`🔪 Trimming conversation at message ${i} to stay under ${MAX_CONTEXT_TOKENS} tokens`);
          console.log(`   Kept ${messagesToKeep.length} messages, estimated ${totalTokenEstimate} tokens`);
          break;
        }
        
        messagesToKeep.unshift(msg);
        totalTokenEstimate += msgTokens;
      }
      
      // Build messages with system prompt
      // Note: Some models like o1/o4 series might not support system messages
      let openAIMessages;
      
      if (effectiveModel.startsWith('o4') || effectiveModel.startsWith('o1')) {
        // For o4/o1 models, we need to inject context into the first user message
        // since these models don't support system messages
        
        // Find system messages with context
        const systemMessagesFromClient = messagesToKeep.filter(msg => msg.role === 'system');
        const contextMessage = systemMessagesFromClient.find(msg => {
          const content = typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content);
          return content.includes('USER\'S CURRENT CONTEXT');
        });
        
        // Get other messages
        const otherMessages = messagesToKeep.filter(msg => msg.role !== 'system');
        
        // If we have context and user messages, prepend context to first user message
        if (contextMessage && otherMessages.length > 0) {
          const contextContent = typeof contextMessage.content === 'string' ? contextMessage.content : JSON.stringify(contextMessage.content);
          const firstUserMsgIndex = otherMessages.findIndex(msg => msg.role === 'user');
          
          if (firstUserMsgIndex !== -1) {
            const originalContent = typeof otherMessages[firstUserMsgIndex].content === 'string' 
              ? otherMessages[firstUserMsgIndex].content 
              : JSON.stringify(otherMessages[firstUserMsgIndex].content);
            
            // Prepend context to the user's message
            otherMessages[firstUserMsgIndex] = {
              role: 'user',
              content: contextContent + '\n\n' + SYSTEM_PROMPT + '\n\nUser: ' + originalContent
            };
            
            console.log('🔍 Injected context into first user message for o4/o1 model');
          }
        }
        
        openAIMessages = otherMessages.map(msg => ({
          role: msg.role,
          content: typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content)
        })).filter(msg => msg.role === 'user' || msg.role === 'assistant');
      } else {
        // Check if there's already a system message with user context
        const systemMessagesFromClient = messagesToKeep.filter(msg => msg.role === 'system');
        const otherMessages = messagesToKeep.filter(msg => msg.role !== 'system');
        
        // Combine system prompts - worker prompt first, then any client system messages
        const systemMessages = [
          { role: 'system', content: SYSTEM_PROMPT }
        ];
        
        // Add any system messages from the client (like user context)
        systemMessagesFromClient.forEach(msg => {
          systemMessages.push({
            role: 'system',
            content: typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content)
          });
        });
        
        openAIMessages = [
          ...systemMessages,
          ...otherMessages
        ];
        
        console.log('🔍 System messages count:', systemMessages.length);
        if (systemMessages.length > 1) {
          console.log('📋 Found additional system messages from client');
          // Log context message content
          systemMessagesFromClient.forEach((msg, index) => {
            const content = typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content);
            if (content.includes('USER\'S CURRENT CONTEXT')) {
              console.log('✅ Found user context in system message', index + 1);
              console.log('📊 Context preview:', content.substring(0, 200) + '...');
            }
          });
        }
      }
      console.log('💬 Final messages count:', openAIMessages.length, 'Estimated tokens:', totalTokenEstimate);
      
      // Get timezone from user context or default to UTC
      const userTimezone = userContext?.timezone || 'UTC';
      const timezoneOffset = userContext?.timezoneOffset || '+00:00';
      
      // Parse the timezone offset to get hours and minutes
      const offsetMatch = timezoneOffset.match(/([+-])(\d{2}):(\d{2})/);
      const offsetHours = offsetMatch ? parseInt(offsetMatch[2]) * (offsetMatch[1] === '+' ? 1 : -1) : 0;
      const offsetMinutes = offsetMatch ? parseInt(offsetMatch[3]) * (offsetMatch[1] === '+' ? 1 : -1) : 0;
      
      // Get current UTC time
      const now = new Date();
      
      // Calculate the user's current local time by adding the offset
      const userLocalTimeMs = now.getTime() + (offsetHours * 60 + offsetMinutes) * 60 * 1000;
      const userLocalTime = new Date(userLocalTimeMs);
      
      // Get today's date in user's timezone (just the date part)
      const year = userLocalTime.getUTCFullYear();
      const month = String(userLocalTime.getUTCMonth() + 1).padStart(2, '0');
      const day = String(userLocalTime.getUTCDate()).padStart(2, '0');
      const currentDate = `${year}-${month}-${day}`;
      
      // Calculate tomorrow's date
      const tomorrowTime = new Date(userLocalTimeMs + 24 * 60 * 60 * 1000);
      const tomorrowYear = tomorrowTime.getUTCFullYear();
      const tomorrowMonth = String(tomorrowTime.getUTCMonth() + 1).padStart(2, '0');
      const tomorrowDay = String(tomorrowTime.getUTCDate()).padStart(2, '0');
      const tomorrowDate = `${tomorrowYear}-${tomorrowMonth}-${tomorrowDay}`;
      
      console.log('📅 Date context:', {
        userTimezone,
        timezoneOffset,
        utcNow: now.toISOString(),
        userNow: userLocalTime.toISOString(),
        today: currentDate,
        tomorrow: tomorrowDate
      });
      
      // Calculate some example dates for the AI
      const nextWeek = new Date(userLocalTimeMs + 7 * 24 * 60 * 60 * 1000);
      const nextWeekDate = `${nextWeek.getUTCFullYear()}-${String(nextWeek.getUTCMonth() + 1).padStart(2, '0')}-${String(nextWeek.getUTCDate()).padStart(2, '0')}`;
      
      let contextMessage = `CURRENT DATE AND TIME:
- Current UTC time: ${now.toISOString()}
- User's local time: ${userLocalTime.toISOString()}
- User's timezone: ${userTimezone} (${timezoneOffset})
- Today (in user's timezone): ${currentDate}
- Tomorrow (in user's timezone): ${tomorrowDate}
- Next week: ${nextWeekDate}

TIMEZONE OFFSET: ${timezoneOffset} means:
- To convert local time to UTC: subtract ${offsetHours} hours
- User's midnight = ${String(0 - offsetHours < 0 ? 24 + (0 - offsetHours) : 0 - offsetHours).padStart(2, '0')}:00:00Z
- User's noon = ${String(12 - offsetHours).padStart(2, '0')}:00:00Z
- User's 3pm = ${String(15 - offsetHours).padStart(2, '0')}:00:00Z

EXAMPLES OF TIME EXPRESSIONS TO ISO FORMAT:
1. "in 2 hours" → Add to current UTC: ${new Date(now.getTime() + 2 * 60 * 60 * 1000).toISOString()}
2. "in 10 hours" → Add to current UTC: ${new Date(now.getTime() + 10 * 60 * 60 * 1000).toISOString()}
3. "tomorrow at 2pm" → ${tomorrowDate}T${String(14 - offsetHours).padStart(2, '0')}:00:00Z
4. "next week at 3pm" → ${nextWeekDate}T${String(15 - offsetHours).padStart(2, '0')}:00:00Z
5. "January 17th at noon" → 2025-01-17T${String(12 - offsetHours).padStart(2, '0')}:00:00Z

CRITICAL RULES:
- ALWAYS use the user's timezone perspective for dates
- ALWAYS convert times to UTC for function calls
- NEVER use relative expressions in function calls - convert to absolute ISO first
- For "in X hours", add to current UTC time
- For specific dates/times, use the date + convert the time to UTC`;

      if (userContext) {
        // Add personal context if provided
        if (userContext.personalContext) {
          contextMessage += `\n\nUser's personal context: ${userContext.personalContext}`;
        }
        
        contextMessage += `\n\nUser's current schedule:
- Today's events: ${JSON.stringify(userContext.todaySchedule)}
- Recent completions: ${JSON.stringify(userContext.completionHistory)}`;
        
        // Add goals if provided
        if (userContext.goals && userContext.goals.length > 0) {
          contextMessage += `\n- Active goals: ${JSON.stringify(userContext.goals)}`;
        }
        
        // Add tasks if provided
        if (userContext.tasks && userContext.tasks.length > 0) {
          contextMessage += `\n- Tasks: ${JSON.stringify(userContext.tasks)}`;
        }
        
        // Add habits if provided
        if (userContext.habits && userContext.habits.length > 0) {
          contextMessage += `\n- Habits: ${JSON.stringify(userContext.habits)}`;
        }
      }
      
      openAIMessages.push({
        role: 'system',
        content: contextMessage,
      });
      
      console.log('📄 Final system messages:', openAIMessages.filter(m => m.role === 'system').map(m => m.content));
      
      // Make OpenAI API request
      const isO4Model = effectiveModel.startsWith('o4');
      const isO1Model = effectiveModel.startsWith('o1');
      
      // Build request body based on model type
      let openAIRequestBody = {
        model: effectiveModel,
        messages: openAIMessages,
        stream,
      };
      
      // Check if this is a "create full day" request
      const lastUserMessage = openAIMessages.filter(m => m.role === 'user').pop()?.content || '';
      const isFullDayRequest = /create.*(?:mock|full).*(?:day|schedule)|full.*scheduled.*day/i.test(lastUserMessage);
      
      // Filter functions for full day requests to prevent category creation
      let functionsToUse = ALL_FUNCTIONS;
      if (isFullDayRequest) {
        console.log('🚨 Full day request detected - filtering out create_category');
        functionsToUse = ALL_FUNCTIONS.filter(f => f.name !== 'create_category');
      }
      
      // Check if we have user context in system messages
      const hasUserContext = openAIMessages.some(msg => 
        msg.role === 'system' && 
        msg.content && 
        msg.content.includes('USER\'S CURRENT CONTEXT')
      );
      
      if (hasUserContext) {
        console.log('🎯 User context detected - removing list functions to force context usage');
        // Remove all list functions when we have context
        functionsToUse = functionsToUse.filter(f => 
          !f.name.includes('list_goals') && 
          !f.name.includes('list_tasks') && 
          !f.name.includes('list_habits') && 
          !f.name.includes('list_events')
        );
        console.log('📋 Removed list functions, remaining:', functionsToUse.length);
      }
      
      // Debug: Log if this is a task creation request
      const isTaskRequest = /create.*(?:task|tasks)|add.*(?:task|tasks)|(?:\d+).*tasks/i.test(lastUserMessage);
      const isMultipleTaskRequest = /(?:create|add|make)\s+(?:\d+|multiple|several|many|list of)\s+tasks?|tasks\s+for|^\d+\s+tasks/i.test(lastUserMessage);
      
      if (isTaskRequest) {
        console.log('📋 TASK REQUEST DETECTED:', lastUserMessage);
        console.log('📋 Is multiple task request:', isMultipleTaskRequest);
        console.log('📋 Available task functions:', functionsToUse.filter(f => f.name.includes('task')).map(f => f.name));
        
        // If user wants multiple tasks, REMOVE create_task to force using create_multiple_tasks
        if (isMultipleTaskRequest) {
          console.log('🚨 MULTIPLE TASKS REQUESTED - Filtering out create_task!');
          functionsToUse = functionsToUse.filter(f => f.name !== 'create_task');
          console.log('📋 Functions after filtering:', functionsToUse.filter(f => f.name.includes('task')).map(f => f.name));
        }
        
        // Find create_multiple_tasks function
        const multiTaskFunc = functionsToUse.find(f => f.name === 'create_multiple_tasks');
        if (multiTaskFunc) {
          console.log('✅ create_multiple_tasks is available');
        } else {
          console.log('❌ create_multiple_tasks is NOT available!');
        }
      }
      
      // Debug: Log if this is a habit creation request
      const isHabitRequest = /create.*(?:habit|habits)|add.*(?:habit|habits)|(?:\d+).*habits/i.test(lastUserMessage);
      const isMultipleHabitRequest = /(?:create|add|make)\s+(?:\d+|multiple|several|many|list of)\s+habits?|habits\s+for|^\d+\s+habits|create\s+\d+\s+habits/i.test(lastUserMessage);
      
      if (isHabitRequest) {
        console.log('🎯 HABIT REQUEST DETECTED:', lastUserMessage);
        console.log('🎯 Is multiple habit request:', isMultipleHabitRequest);
        console.log('🎯 Available habit functions BEFORE filtering:', functionsToUse.filter(f => f.name.includes('habit')).map(f => f.name));
        
        // If user wants multiple habits, REMOVE create_habit to force using create_multiple_habits
        if (isMultipleHabitRequest) {
          console.log('🚨 MULTIPLE HABITS REQUESTED - Filtering out create_habit!');
          functionsToUse = functionsToUse.filter(f => f.name !== 'create_habit');
          console.log('🎯 Functions AFTER filtering:', functionsToUse.filter(f => f.name.includes('habit')).map(f => f.name));
          console.log('🎯 Total functions available:', functionsToUse.length);
          
          // Extra check - make sure create_multiple_habits is first
          const multiHabitIndex = functionsToUse.findIndex(f => f.name === 'create_multiple_habits');
          if (multiHabitIndex > 0) {
            console.log('🔄 Moving create_multiple_habits to front of list');
            const multiHabitFunc = functionsToUse.splice(multiHabitIndex, 1)[0];
            functionsToUse.unshift(multiHabitFunc);
          }
        }
        
        // Find create_multiple_habits function
        const multiHabitFunc = functionsToUse.find(f => f.name === 'create_multiple_habits');
        if (multiHabitFunc) {
          console.log('✅ create_multiple_habits is available');
        } else {
          console.log('❌ create_multiple_habits is NOT available!');
        }
        
        // Log what habit functions are available
        console.log('🎯 Final habit functions:', functionsToUse.filter(f => f.name.includes('habit')).map(f => f.name));
      }
      
      // Add model-specific parameters
      if (!isO4Model && !isO1Model) {
        // Standard models support all parameters
        openAIRequestBody.functions = functionsToUse;
        openAIRequestBody.function_call = 'auto';
        openAIRequestBody.temperature = 0.7;
        openAIRequestBody.max_tokens = 15000;
      } else {
        // O1/O4 models have different requirements
        openAIRequestBody.functions = functionsToUse;
        // Don't include function_call for o4 models - defaults to auto
        openAIRequestBody.max_completion_tokens = 4096; // O4 models use max_completion_tokens
        // Don't include temperature for o1/o4 models
      }
      
      console.log('🚀 Sending to OpenAI:', {
        model: openAIRequestBody.model,
        messageCount: openAIRequestBody.messages.length,
        functionCount: openAIRequestBody.functions.length,
        stream: openAIRequestBody.stream
      });
      
      // Log the complete request for o4-mini
      if (effectiveModel === 'o4-mini') {
        console.log('🎯 O4-MINI REQUEST DETAILS:');
        console.log('📨 Full OpenAI request:', JSON.stringify(openAIRequestBody, null, 2));
        console.log('🔑 Headers being sent:', {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.OPENAI_API_KEY.substring(0, 10)}...`, // Show first 10 chars only
        });
        console.log('🌐 Endpoint:', 'https://api.openai.com/v1/chat/completions');
        
        // Validate the request has only expected fields
        const validFields = ['model', 'messages', 'functions', 'max_completion_tokens', 'stream'];
        const requestFields = Object.keys(openAIRequestBody);
        const extraFields = requestFields.filter(field => !validFields.includes(field));
        if (extraFields.length > 0) {
          console.warn('⚠️ Extra fields detected:', extraFields);
        }
        
        // Log cleaned request
        console.log('✅ Cleaned O4-MINI request (no function_call, max_completion_tokens=4096)');
        console.log('📦 Request fields:', requestFields);
      } else {
        console.log('📨 Full OpenAI request:', JSON.stringify(openAIRequestBody, null, 2));
      }
      
      // Create timeout controller
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), SECURITY_CONFIG.requestTimeoutMs);
      
      try {
        const openAIResponse = await fetch('https://api.openai.com/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
          },
          body: JSON.stringify(openAIRequestBody),
          signal: controller.signal,
        });
        
        clearTimeout(timeout);
        
        console.log('📡 OpenAI response status:', openAIResponse.status);
        console.log('📡 OpenAI response headers:', Object.fromEntries(openAIResponse.headers.entries()));
        
        if (!openAIResponse.ok) {
          const errorText = await openAIResponse.text();
          console.error('❌ OpenAI API error:', errorText);
          
          // Try to parse the error as JSON
          let errorMessage = 'AI service error';
          let errorDetails = errorText;
          
          try {
            const errorJson = JSON.parse(errorText);
            console.error('❌ Parsed error:', JSON.stringify(errorJson, null, 2));
            
            if (errorJson.error) {
              errorMessage = errorJson.error.message || errorJson.error.type || 'AI service error';
              errorDetails = errorJson.error;
              
              // Log specific error details for debugging
              console.error('❌ Error type:', errorJson.error.type);
              console.error('❌ Error message:', errorJson.error.message);
              console.error('❌ Error code:', errorJson.error.code);
              if (errorJson.error.param) {
                console.error('❌ Error param:', errorJson.error.param);
              }
            }
          } catch (e) {
            // If not JSON, use the raw text
            console.error('❌ Could not parse error as JSON');
            console.error('❌ Raw error text:', errorText);
          }
          
          // Return the actual error from OpenAI to the client
          return new Response(
            JSON.stringify({ 
              error: errorMessage,
              details: errorDetails,
              status: openAIResponse.status 
            }),
            {
              status: openAIResponse.status,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            }
          );
        }
        
        console.log('✅ OpenAI request successful');
        
        // Increment rate limit
        await incrementRateLimit(env, request, userId);
        
        // Log request
        await logRequest(env, userId || getClientIP(request), effectiveModel, body.functionCall, estimatedTokens);
        
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
        
      } catch (timeoutError) {
        if (timeoutError.name === 'AbortError') {
          console.error('⏱️ OpenAI request timeout');
          return new Response(
            JSON.stringify({ error: 'Request timeout', message: 'AI service took too long to respond' }),
            {
              status: 504,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            }
          );
        }
        throw timeoutError;
      }
      
    } catch (error) {
      console.error('Worker error:', error);
      console.error('Error stack:', error.stack);
      
      // More detailed error response for debugging
      const errorDetails = {
        error: 'Internal server error',
        message: error.message,
        type: error.constructor.name,
        // Only include stack in development
        stack: error.stack
      };
      
      return new Response(
        JSON.stringify(errorDetails),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }
  },
};