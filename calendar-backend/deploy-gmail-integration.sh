#!/bin/bash

# EventAI Gmail Integration Deployment Script
# Deploys the backend with Gmail integration support

set -e

echo "🚀 EventAI Gmail Integration Deployment"
echo "======================================="

# Check if we're in the right directory
if [ ! -f "main.py" ]; then
    echo "❌ Error: main.py not found. Please run from calendar-backend directory."
    exit 1
fi

# Get project ID
PROJECT_ID="levelup-467902"

echo "📦 Project: $PROJECT_ID"
echo "🌍 Region: us-central1"
echo ""

# Check required files
echo "🔍 Checking required files..."
required_files=("main.py" "gmail_service.py" "gmail_endpoints.py" "requirements.txt")
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (missing)"
        exit 1
    fi
done
echo ""

# Check environment variables
echo "🔐 Checking environment configuration..."
if [ -z "$GOOGLE_CLIENT_ID" ]; then
    echo "⚠️  GOOGLE_CLIENT_ID not set (will need to be configured in Cloud Run)"
fi

if [ -z "$GOOGLE_CLIENT_SECRET" ]; then
    echo "⚠️  GOOGLE_CLIENT_SECRET not set (will need to be configured in Cloud Run)"
fi
echo ""

# Prompt for deployment target
echo "📋 Select deployment target:"
echo "1. Staging (eventai-api-staging)"
echo "2. Production (eventai-api)"
echo "3. New Gmail service (eventai-gmail-api)"
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        SERVICE_NAME="eventai-api-staging"
        echo "🧪 Deploying to STAGING"
        ;;
    2)
        SERVICE_NAME="eventai-api"
        echo "🏭 Deploying to PRODUCTION"
        read -p "⚠️  Are you sure you want to deploy to production? (y/N): " confirm
        if [[ $confirm != [yY] ]]; then
            echo "❌ Deployment cancelled"
            exit 0
        fi
        ;;
    3)
        SERVICE_NAME="eventai-gmail-api"
        echo "📧 Deploying new Gmail-specific service"
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac
echo ""

# Deploy to Cloud Run
echo "🚀 Deploying $SERVICE_NAME to Google Cloud Run..."
echo "This may take several minutes..."
echo ""

gcloud run deploy $SERVICE_NAME \
    --source . \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated \
    --port 8080 \
    --memory 2Gi \
    --cpu 2 \
    --max-instances 10 \
    --set-env-vars ENVIRONMENT=gmail-integration \
    --set-env-vars CLAUDE_MODEL=claude-3-5-haiku-20241022 \
    --set-env-vars CLAUDE_MAX_TOKENS=2000 \
    --set-env-vars ANTHROPIC_API_KEY="$(gcloud secrets versions access latest --secret=anthropic-api-key)" \
    --set-env-vars GOOGLE_CLOUD_PROJECT="$PROJECT_ID" \
    --project $PROJECT_ID

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    
    # Get service URL
    SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region us-central1 --project $PROJECT_ID --format="value(status.url)")
    echo "🌐 Service URL: $SERVICE_URL"
    
    # Test endpoints
    echo ""
    echo "🧪 Testing endpoints..."
    
    # Health check
    echo "Testing health endpoint..."
    curl -s "$SERVICE_URL/health" | jq '.' || echo "❌ Health check failed"
    
    # Gmail health check
    echo "Testing Gmail integration health..."
    curl -s "$SERVICE_URL/api/gmail/health" | jq '.' || echo "❌ Gmail health check failed"
    
    echo ""
    echo "📋 Next Steps:"
    echo "1. Configure Google OAuth credentials:"
    echo "   - Set GOOGLE_CLIENT_ID environment variable"
    echo "   - Set GOOGLE_CLIENT_SECRET environment variable"
    echo "   - Set GOOGLE_REDIRECT_URI to: $SERVICE_URL/api/gmail/oauth/callback"
    echo ""
    echo "2. Update Gmail Add-on configuration:"
    echo "   - Update EVENTAI_API_BASE in Code.gs to: $SERVICE_URL"
    echo "   - Configure API authentication if needed"
    echo ""
    echo "3. Test Gmail integration:"
    echo "   - Deploy Gmail Add-on to Google Apps Script"
    echo "   - Test event extraction with sample emails"
    echo ""
    echo "🎉 Gmail integration deployment complete!"
    
else
    echo ""
    echo "❌ Deployment failed!"
    echo "Check the error messages above and try again."
    exit 1
fi