#!/bin/bash

# Momentum AI Cloudflare Worker Setup Script

echo "🚀 Momentum AI Cloudflare Worker Setup"
echo "====================================="
echo ""

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo "❌ Wrangler CLI not found. Installing..."
    npm install -g wrangler
else
    echo "✅ Wrangler CLI is installed"
fi

echo ""
echo "📝 Next steps:"
echo ""
echo "1. Login to Cloudflare:"
echo "   wrangler login"
echo ""
echo "2. Create KV namespaces:"
echo "   wrangler kv:namespace create RATE_LIMITS"
echo "   wrangler kv:namespace create REQUEST_LOGS"
echo ""
echo "3. Update wrangler.toml with your namespace IDs"
echo ""
echo "4. Generate a secure app secret:"
echo "   openssl rand -base64 32"
echo ""
echo "5. Set your secrets:"
echo "   wrangler secret put OPENAI_API_KEY"
echo "   wrangler secret put APP_SECRET"
echo ""
echo "6. Deploy your worker:"
echo "   wrangler deploy"
echo ""
echo "7. Update APIConfiguration.swift with:"
echo "   - Your worker URL"
echo "   - Your app secret"
echo ""
echo "Need help? Check README.md for detailed instructions."