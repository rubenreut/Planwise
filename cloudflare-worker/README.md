# Momentum AI Cloudflare Worker

This Cloudflare Worker handles secure communication between the Momentum iOS app and OpenAI's API.

## Setup Instructions

### 1. Install Wrangler CLI
```bash
npm install -g wrangler
```

### 2. Login to Cloudflare
```bash
wrangler login
```

### 3. Create KV Namespaces
```bash
# Create rate limiting namespace
wrangler kv:namespace create "RATE_LIMITS"

# Create request logs namespace  
wrangler kv:namespace create "REQUEST_LOGS"
```

### 4. Update wrangler.toml
Replace the KV namespace IDs in `wrangler.toml` with the IDs from step 3.

### 5. Set Secrets
```bash
# Set your OpenAI API key
wrangler secret put OPENAI_API_KEY

# Set your app secret (generate a strong random string)
wrangler secret put APP_SECRET
```

### 6. Deploy
```bash
wrangler deploy
```

### 7. Update iOS App
In `OpenAIService.swift`, update the `workerURL` to your deployed worker URL.

## Local Development

```bash
# Install dependencies
npm install

# Run local development server
npm run dev

# Test the worker
npm test
```

## Security Notes

- Never commit API keys or secrets
- The APP_SECRET must match between the worker and iOS app
- Rate limits are enforced per user ID
- All requests are logged for monitoring

## Monitoring

View logs and analytics in the Cloudflare dashboard:
1. Go to Workers & Pages
2. Select your worker
3. Check Logs and Analytics tabs