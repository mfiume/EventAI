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
SERVICE_NAME="event-ai-api"
REGION="us-central1"

# Set the project
gcloud config set project $PROJECT_ID

# Deploy to Cloud Run
gcloud run deploy $SERVICE_NAME \
  --source . \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars NODE_ENV=production,ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  --memory 1Gi \
  --cpu 1 \
  --max-instances 10 \
  --timeout 300

echo "✅ Deployment complete!"
echo "🌐 Service URL: https://$SERVICE_NAME-*.run.app"

# Test the deployment
echo "🔍 Testing deployment..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)')
curl -X GET "$SERVICE_URL/health"
echo ""
echo "✅ Health check complete!"