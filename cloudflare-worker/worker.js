/**
 * Momentum AI Worker - Handles OpenAI API requests for the Momentum iOS app
 */

// Import new simplified functions (5 functions to replace 103)
import { SIMPLIFIED_FUNCTIONS } from './simplified-functions.js';

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

// OpenAI function definitions - Now using 5 simplified functions
// OLD FUNCTIONS REMOVED - see git history if needed
const FUNCTIONS = SIMPLIFIED_FUNCTIONS; // Using the new 5 functions

// Legacy functions removed - using new simplified functions
// Combine all functions - using new simplified functions
// The 5 simplified functions replace all 103 old functions
const ALL_FUNCTIONS = [...SIMPLIFIED_FUNCTIONS];

// System prompt for the AI
const SYSTEM_PROMPT = `# Momentum Assistant - NEW SIMPLIFIED API

You are an AI calendar and task management assistant. You help users organize their time, tasks, habits, and goals.

## CRITICAL: YOU ONLY HAVE 5 FUNCTIONS AVAILABLE
The ONLY functions you can call are:
1. manage_events
2. manage_tasks
3. manage_habits
4. manage_goals
5. manage_categories

THERE ARE NO OTHER FUNCTIONS. Functions like create_event, delete_task, update_habit DO NOT EXIST.

Each function takes:
- action: 'create', 'update', 'delete', 'list', 'search', etc.
- parameters: object with the relevant data

## CRITICAL RULES

### 1. ALWAYS USE MANAGE_* FUNCTIONS
If user says "create an event" → Call manage_events with action: 'create'
If user says "delete a task" → Call manage_tasks with action: 'delete'
If user says "update my goal" → Call manage_goals with action: 'update'

OLD FUNCTION NAMES DO NOT EXIST:
❌ create_event - DOES NOT EXIST
❌ delete_task - DOES NOT EXIST
❌ update_habit - DOES NOT EXIST
✅ manage_events - USE THIS
✅ manage_tasks - USE THIS
✅ manage_habits - USE THIS

### 2. CONTEXT AWARENESS
The system message includes "USER'S CURRENT CONTEXT" with their:
- Goals (with IDs!), tasks, habits, and events
- DO NOT call list functions to gather data you already have
- Use the provided context instead of asking questions
- When adding milestones to existing goals, use the goal IDs from context

### 3. BULK OPERATIONS
For multiple items, pass an items array in parameters:
{
  "action": "create",
  "parameters": {
    "items": [
      {"title": "Task 1", ...},
      {"title": "Task 2", ...}
    ]
  }
}

### 4. CATEGORIES
- EVERY event MUST have a category field
- Use: work, personal, health, learning, meeting, fitness, finance, family, social, travel, shopping, hobby, home, creative, other
- Match categories intelligently to content

### 5. TIME HANDLING
- User times = their local timezone
- Convert to UTC for function calls
- "Move up/forward" = EARLIER, "Push back/delay" = LATER

## EXAMPLES

"Create an event":
{
  "name": "manage_events",
  "arguments": {
    "action": "create",
    "parameters": {
      "title": "Team Meeting",
      "startTime": "2025-01-09T14:00:00Z",
      "endTime": "2025-01-09T15:00:00Z",
      "category": "meeting"
    }
  }
}

"Create 3 workout tasks":
{
  "name": "manage_tasks",
  "arguments": {
    "action": "create",
    "parameters": {
      "items": [
        {"title": "Morning run", "category": "fitness", "estimatedMinutes": 30},
        {"title": "Strength training", "category": "fitness", "estimatedMinutes": 45},
        {"title": "Evening yoga", "category": "fitness", "estimatedMinutes": 20}
      ]
    }
  }
}

"Delete all tasks":
{
  "name": "manage_tasks",
  "arguments": {
    "action": "delete",
    "parameters": {
      "ids": ["all"]
    }
  }
}

"Add milestone to goal":
{
  "name": "manage_goals",
  "arguments": {
    "action": "create_milestone",
    "parameters": {
      "goalId": "[goal-id-from-context]",
      "title": "First milestone",
      "targetValue": 25
    }
  }
}

CRITICAL: Always use manage_* functions with appropriate action!

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
      // Test with one of the new simplified functions
      const minimalFunction = {
        name: 'manage_events',
        description: 'Manage events - create, update, delete, list events',
        parameters: {
          type: 'object',
          properties: {
            action: { type: 'string', enum: ['create', 'update', 'delete', 'list'] },
            parameters: { 
              type: 'object',
              properties: {
                title: { type: 'string' },
                startTime: { type: 'string' },
                endTime: { type: 'string' }
              }
            }
          },
          required: ['action', 'parameters']
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
        tools: [{
          type: 'function',
          function: minimalFunction
        }],
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
      
      // Skip adding duplicate context if it already exists in messages
      const hasUserContext = openAIMessages.some(msg => 
        msg.role === 'system' && 
        (msg.content.includes('USER\'S CURRENT CONTEXT') || msg.content.includes('Current tasks:'))
      );
      
      if (hasUserContext) {
        console.log('✅ User context already present, skipping duplicate');
      }
      
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
      
      // Only add context message if we don't already have user context
      if (!hasUserContext) {
        openAIMessages.push({
          role: 'system',
          content: contextMessage,
        });
      }
      
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
      
      // Use ALL_FUNCTIONS which contains our 5 simplified functions
      const lastUserMessage = openAIMessages.filter(m => m.role === 'user').pop()?.content || '';
      let functionsToUse = ALL_FUNCTIONS;
      
      // Debug: Log available functions
      console.log('📋 Available functions:', functionsToUse.map(f => f.name));
      console.log('📋 Total functions:', functionsToUse.length);
      
      // Add model-specific parameters
      // Convert functions to tools format for OpenAI
      const tools = functionsToUse.map(func => ({
        type: 'function',
        function: func
      }));
      
      if (!isO4Model && !isO1Model) {
        // Standard models support all parameters
        openAIRequestBody.tools = tools;
        
        // FORCE function usage when user is clearly asking for data
        const userWantsData = lastUserMessage.toLowerCase().match(
          /show|list|display|what|check|view|see|tell me|get|fetch|find|my tasks|my events|my goals|my habits/
        );
        
        if (userWantsData) {
          console.log('🎯 User wants data - FORCING function call usage');
          openAIRequestBody.tool_choice = 'required';
        } else {
          console.log('💬 Regular conversation - functions optional');
          openAIRequestBody.tool_choice = 'auto';
        }
        
        openAIRequestBody.temperature = 0.7;
        openAIRequestBody.max_tokens = 15000;
      } else {
        // O1/O4 models have different requirements
        openAIRequestBody.tools = tools;
        // Don't include tool_choice for o4 models - defaults to auto
        openAIRequestBody.max_completion_tokens = 4096; // O4 models use max_completion_tokens
        // Don't include temperature for o1/o4 models
      }
      
      console.log('🚀 Sending to OpenAI:', {
        model: openAIRequestBody.model,
        messageCount: openAIRequestBody.messages.length,
        toolCount: openAIRequestBody.tools ? openAIRequestBody.tools.length : 0,
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
        const validFields = ['model', 'messages', 'tools', 'max_completion_tokens', 'stream'];
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
        
        // Log if there's a function/tool call
        if (result.choices?.[0]?.message?.tool_calls) {
          console.log('🔧 Tool calls detected:', result.choices[0].message.tool_calls);
        } else if (result.choices?.[0]?.message?.function_call) {
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