/**
 * Test script for Momentum AI Cloudflare Worker
 * Run with: node test-worker.js
 */

const WORKER_URL = 'http://localhost:8787'; // Change to production URL when deployed
const APP_SECRET = 'momentum-2025-secure-key-xyz789'; // Must match your worker config

// Test cases
const tests = {
  // Basic chat test
  basicChat: {
    messages: [
      { role: 'user', content: 'Hello, can you help me manage my schedule?' }
    ],
    model: 'gpt-4',
    temperature: 0.7
  },

  // Function calling test
  createEvent: {
    messages: [
      { role: 'user', content: 'Schedule a team meeting tomorrow at 2pm for 1 hour' }
    ],
    model: 'gpt-4',
    temperature: 0.7,
    userContext: {
      currentTime: new Date().toISOString(),
      todaySchedule: [],
      completionHistory: []
    }
  },

  // Rescheduling test
  reschedule: {
    messages: [
      { role: 'user', content: "I'm running 30 minutes late, can you push everything back?" }
    ],
    model: 'gpt-4',
    temperature: 0.7,
    userContext: {
      currentTime: new Date().toISOString(),
      todaySchedule: [
        {
          id: '123e4567-e89b-12d3-a456-426614174000',
          title: 'Morning standup',
          startTime: new Date(Date.now() + 3600000).toISOString(),
          endTime: new Date(Date.now() + 4200000).toISOString(),
          category: 'work',
          isCompleted: false
        },
        {
          id: '223e4567-e89b-12d3-a456-426614174000',
          title: 'Lunch break',
          startTime: new Date(Date.now() + 7200000).toISOString(),
          endTime: new Date(Date.now() + 10800000).toISOString(),
          category: 'personal',
          isCompleted: false
        }
      ],
      completionHistory: []
    }
  },

  // Streaming test
  streamingChat: {
    messages: [
      { role: 'user', content: 'Give me a detailed productivity tip for time blocking' }
    ],
    model: 'gpt-4',
    temperature: 0.7,
    stream: true
  }
};

// Test runner
async function runTest(testName, testData) {
  console.log(`\n🧪 Running test: ${testName}`);
  console.log('Request:', JSON.stringify(testData, null, 2));

  try {
    const response = await fetch(WORKER_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-App-Secret': APP_SECRET,
        'X-Request-ID': `test-${Date.now()}`
      },
      body: JSON.stringify(testData)
    });

    console.log(`\n📊 Response Status: ${response.status}`);
    
    // Log rate limit headers
    const rateLimitHeaders = ['X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-RateLimit-Reset'];
    rateLimitHeaders.forEach(header => {
      const value = response.headers.get(header);
      if (value) {
        console.log(`${header}: ${value}`);
      }
    });

    if (testData.stream) {
      // Handle streaming response
      console.log('\n📡 Streaming response:');
      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        
        const chunk = decoder.decode(value);
        process.stdout.write(chunk);
      }
      console.log('\n✅ Stream complete');
    } else {
      // Handle JSON response
      const data = await response.json();
      console.log('\n📄 Response:', JSON.stringify(data, null, 2));

      // Check for function calls
      if (data.choices?.[0]?.message?.function_call) {
        console.log('\n🔧 Function Call Detected:');
        console.log('Name:', data.choices[0].message.function_call.name);
        console.log('Arguments:', data.choices[0].message.function_call.arguments);
      }
    }

    console.log(`\n✅ Test ${testName} completed successfully`);

  } catch (error) {
    console.error(`\n❌ Test ${testName} failed:`, error.message);
  }
}

// Run all tests
async function runAllTests() {
  console.log('🚀 Momentum AI Worker Test Suite');
  console.log('================================');
  console.log(`Worker URL: ${WORKER_URL}`);
  console.log(`App Secret: ${APP_SECRET.substring(0, 10)}...`);

  for (const [testName, testData] of Object.entries(tests)) {
    await runTest(testName, testData);
    
    // Wait a bit between tests to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  console.log('\n\n✨ All tests completed!');
}

// Error handling tests
async function testErrorCases() {
  console.log('\n\n🔴 Testing Error Cases');
  console.log('======================');

  // Test unauthorized access
  console.log('\n1️⃣ Testing unauthorized access...');
  try {
    const response = await fetch(WORKER_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-App-Secret': 'wrong-secret'
      },
      body: JSON.stringify({ messages: [{ role: 'user', content: 'test' }] })
    });
    console.log(`Status: ${response.status} (expected 401)`);
    const data = await response.json();
    console.log('Response:', data);
  } catch (error) {
    console.error('Error:', error.message);
  }

  // Test invalid JSON
  console.log('\n2️⃣ Testing invalid JSON...');
  try {
    const response = await fetch(WORKER_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-App-Secret': APP_SECRET
      },
      body: 'invalid json'
    });
    console.log(`Status: ${response.status} (expected 400)`);
    const data = await response.json();
    console.log('Response:', data);
  } catch (error) {
    console.error('Error:', error.message);
  }

  // Test missing messages
  console.log('\n3️⃣ Testing missing messages...');
  try {
    const response = await fetch(WORKER_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-App-Secret': APP_SECRET
      },
      body: JSON.stringify({ model: 'gpt-4' })
    });
    console.log(`Status: ${response.status} (expected 400)`);
    const data = await response.json();
    console.log('Response:', data);
  } catch (error) {
    console.error('Error:', error.message);
  }
}

// CORS preflight test
async function testCORS() {
  console.log('\n\n🌐 Testing CORS');
  console.log('===============');

  try {
    const response = await fetch(WORKER_URL, {
      method: 'OPTIONS',
      headers: {
        'Origin': 'https://example.com',
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'Content-Type, X-App-Secret'
      }
    });

    console.log(`Status: ${response.status} (expected 200)`);
    console.log('CORS Headers:');
    ['Access-Control-Allow-Origin', 'Access-Control-Allow-Methods', 'Access-Control-Allow-Headers'].forEach(header => {
      console.log(`  ${header}: ${response.headers.get(header)}`);
    });
  } catch (error) {
    console.error('Error:', error.message);
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--errors')) {
    await testErrorCases();
  } else if (args.includes('--cors')) {
    await testCORS();
  } else if (args.length > 0 && tests[args[0]]) {
    // Run specific test
    await runTest(args[0], tests[args[0]]);
  } else {
    // Run all tests
    await runAllTests();
  }
}

// Run the tests
main().catch(console.error);

// Usage instructions
if (process.argv.length === 2) {
  console.log(`
Usage:
  node test-worker.js              # Run all tests
  node test-worker.js basicChat    # Run specific test
  node test-worker.js --errors     # Test error cases
  node test-worker.js --cors       # Test CORS

Available tests: ${Object.keys(tests).join(', ')}
  `);
}