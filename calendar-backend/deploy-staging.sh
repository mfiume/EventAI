#!/bin/bash

# EventAI Backend - Staging Deployment Script
# Deploys to separate staging service for testing

set -e

echo "🚀 Starting EventAI Staging Deployment..."

# Configuration
PROJECT_ID="levelup-467902"
STAGING_SERVICE_NAME="eventai-api-staging"
STAGING_REGION="us-central1"

# Generate staging API keys if they don't exist
echo "🔑 Checking staging API keys..."

# Generate secure keys for staging environment
IOS_STAGING_KEY=$(openssl rand -hex 32)
WEB_STAGING_KEY=$(openssl rand -hex 32)
DEV_STAGING_KEY=$(openssl rand -hex 32)

echo "Generated staging API keys:"
echo "iOS Staging Key: eak_${IOS_STAGING_KEY:0:8}...${IOS_STAGING_KEY: -8}"
echo "Web Staging Key: eak_${WEB_STAGING_KEY:0:8}...${WEB_STAGING_KEY: -8}"
echo "Dev Staging Key: eak_${DEV_STAGING_KEY:0:8}...${DEV_STAGING_KEY: -8}"

# Deploy to staging service
echo "📦 Deploying to staging service: $STAGING_SERVICE_NAME"

gcloud run deploy $STAGING_SERVICE_NAME \
    --source . \
    --platform managed \
    --region $STAGING_REGION \
    --allow-unauthenticated \
    --port 8080 \
    --memory 1Gi \
    --cpu 1 \
    --max-instances 10 \
    --set-env-vars ENVIRONMENT=staging \
    --set-env-vars CLAUDE_MODEL=claude-3-5-haiku-20241022 \
    --set-env-vars CLAUDE_MAX_TOKENS=2000 \
    --set-env-vars IOS_CLIENT_API_KEY="eak_${IOS_STAGING_KEY}" \
    --set-env-vars WEB_CLIENT_API_KEY="eak_${WEB_STAGING_KEY}" \
    --set-env-vars DEV_CLIENT_API_KEY="eak_${DEV_STAGING_KEY}" \
    --set-env-vars ANTHROPIC_API_KEY="$(gcloud secrets versions access latest --secret=anthropic-api-key)" \
    --set-env-vars GOOGLE_CLOUD_PROJECT="$PROJECT_ID" \
    --project $PROJECT_ID

# Get the staging URL
STAGING_URL=$(gcloud run services describe $STAGING_SERVICE_NAME --region=$STAGING_REGION --format="value(status.url)" --project=$PROJECT_ID)

echo "✅ Staging deployment completed!"
echo "🌐 Staging URL: $STAGING_URL"
echo "📋 Staging API Base: $STAGING_URL/api"

# Test the staging deployment
echo "🧪 Testing staging deployment..."

# Test health endpoint
echo "Testing health endpoint..."
curl -s "$STAGING_URL/health" | jq '.' || echo "Health check response (no jq):"

# Test API health with staging key
echo "Testing authenticated API endpoint..."
curl -s -H "X-API-Key: eak_${DEV_STAGING_KEY}" "$STAGING_URL/api/" | jq '.' || echo "API test response (no jq):"

echo ""
echo "🎯 Staging Environment Ready!"
echo "==============================================="
echo "Staging API URL: $STAGING_URL/api"
echo "iOS Staging Key: eak_${IOS_STAGING_KEY}"
echo "Web Staging Key: eak_${WEB_STAGING_KEY}" 
echo "Dev Staging Key: eak_${DEV_STAGING_KEY}"
echo "==============================================="
echo ""
echo "🔧 Next Steps:"
echo "1. Update iOS app Config.xcconfig with staging key"
echo "2. Test API endpoints with authentication"
echo "3. Validate rate limiting behavior"
echo "4. Once tested, deploy to production with production keys"

# Save keys to staging config file (for reference)
cat > staging-keys.txt << EOF
# EventAI Staging API Keys
# Generated: $(date)
# 
# IMPORTANT: These are staging keys only!
# Do not use in production.

IOS_STAGING_KEY=eak_${IOS_STAGING_KEY}
WEB_STAGING_KEY=eak_${WEB_STAGING_KEY}
DEV_STAGING_KEY=eak_${DEV_STAGING_KEY}

# Staging API Base URL
STAGING_API_URL=${STAGING_URL}/api

# Test command:
# curl -H "X-API-Key: eak_${DEV_STAGING_KEY}" ${STAGING_URL}/api/
EOF

echo "📝 Staging keys saved to: staging-keys.txt"
echo "⚠️  Keep staging keys secure and separate from production!"