#!/bin/bash

# EventAI Backend Deployment Script
echo "🚀 Deploying EventAI Backend to Google Cloud Run..."

# Check if secrets file exists
if [ ! -f "secrets/secrets.env" ]; then
    echo "❌ Error: secrets/secrets.env not found!"
    echo "📝 Please copy secrets.example.env to secrets.env and add your API keys"
    exit 1
fi

# Load environment variables for deployment
export $(grep -v '^#' secrets/secrets.env | xargs)

# Set project ID
PROJECT_ID="levelup-467902"
SERVICE_NAME="eventai-api"
REGION="us-central1"

# Generate production API keys
echo "🔑 Generating production API keys..."
IOS_PROD_KEY=$(openssl rand -hex 32)
WEB_PROD_KEY=$(openssl rand -hex 32)
DEV_PROD_KEY=$(openssl rand -hex 32)

echo "Generated production API keys:"
echo "iOS Production Key: eak_${IOS_PROD_KEY:0:8}...${IOS_PROD_KEY: -8}"
echo "Web Production Key: eak_${WEB_PROD_KEY:0:8}...${WEB_PROD_KEY: -8}"
echo "Dev Production Key: eak_${DEV_PROD_KEY:0:8}...${DEV_PROD_KEY: -8}"

# Load environment variables from secrets file
if [ -f "secrets/secrets.env" ]; then
    echo "📁 Loading secrets from secrets.env..."
    export $(grep -v '^#' secrets/secrets.env | xargs)
else
    echo "⚠️  Warning: secrets/secrets.env not found"
fi

# Set the project
gcloud config set project $PROJECT_ID

# Deploy to Cloud Run with API key authentication
gcloud run deploy $SERVICE_NAME \
  --source . \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  --set-env-vars CLAUDE_MODEL=claude-3-5-haiku-20241022 \
  --set-env-vars IOS_CLIENT_API_KEY="eak_${IOS_PROD_KEY}" \
  --set-env-vars WEB_CLIENT_API_KEY="eak_${WEB_PROD_KEY}" \
  --set-env-vars DEV_CLIENT_API_KEY="eak_${DEV_PROD_KEY}" \
  --set-env-vars GOOGLE_CLOUD_PROJECT="$PROJECT_ID" \
  --set-env-vars GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}" \
  --set-env-vars GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET}" \
  --set-env-vars GOOGLE_REDIRECT_URI="https://eventai.leveluplife.app/api/gmail/oauth/callback" \
  --set-env-vars REVENUECAT_WEBHOOK_SECRET="${REVENUECAT_WEBHOOK_SECRET}" \
  --memory 1Gi \
  --cpu 1 \
  --max-instances 10 \
  --timeout 300

echo "✅ Deployment complete!"

# Get the actual service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)')
echo "🌐 Service URL: $SERVICE_URL"

# Test the deployment
echo "🔍 Testing deployment..."
curl -X GET "$SERVICE_URL/health"
echo ""
echo "✅ Health check complete!"

# Output production API keys
echo ""
echo "🎯 Production Environment Ready!"
echo "==============================================="
echo "Production API URL: $SERVICE_URL/api"
echo "iOS Production Key: eak_${IOS_PROD_KEY}"
echo "Web Production Key: eak_${WEB_PROD_KEY}"
echo "Dev Production Key: eak_${DEV_PROD_KEY}"
echo "==============================================="
echo ""
echo "🔧 Next Steps:"
echo "1. Update iOS app Config.xcconfig with production key"
echo "2. Update web app with production key"
echo "3. Test API endpoints require authentication"
echo "⚠️  Keep production keys secure!"

# Save production keys to file
echo "eak_${IOS_PROD_KEY}" > production-ios-key.txt
echo "eak_${WEB_PROD_KEY}" > production-web-key.txt  
echo "eak_${DEV_PROD_KEY}" > production-dev-key.txt
echo "📝 Production keys saved to: production-*-key.txt files"