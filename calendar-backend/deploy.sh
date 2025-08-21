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

# API keys are managed in Firestore database, not as environment variables
echo "🔑 API keys are loaded from Firestore database on startup"

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
  --set-env-vars GOOGLE_CLOUD_PROJECT="$PROJECT_ID" \
  --set-env-vars GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}" \
  --set-env-vars GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET}" \
  --set-env-vars GOOGLE_REDIRECT_URI="https://eventai.leveluplife.app/api/gmail/oauth/callback" \
  --set-env-vars REVENUECAT_WEBHOOK_SECRET="${REVENUECAT_WEBHOOK_SECRET}" \
  --memory 2Gi \
  --cpu 2 \
  --min-instances 1 \
  --max-instances 10 \
  --timeout 300 \
  --concurrency 80

echo "✅ Deployment complete!"

# Get the actual service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)')
echo "🌐 Service URL: $SERVICE_URL"

# Test the deployment
echo "🔍 Testing deployment..."
curl -X GET "$SERVICE_URL/health"
echo ""
echo "✅ Health check complete!"

# API keys are managed in Firestore - no file output needed
echo ""
echo "🎯 Production Environment Ready!"
echo "==============================================="
echo "Production API URL: $SERVICE_URL/api"
echo "🔑 API keys are loaded from Firestore database"
echo "🔍 Use /health endpoint to check service status"
echo "==============================================="