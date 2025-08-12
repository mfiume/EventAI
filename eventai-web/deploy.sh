#!/bin/bash

# EventAI Web App Deployment Script
# This script deploys the web app to Google App Engine

echo "🚀 Deploying EventAI Web App to Google Cloud..."

# Check if gcloud CLI is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud CLI is not installed. Please install it first:"
    echo "   https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo "❌ Not authenticated with Google Cloud. Please run:"
    echo "   gcloud auth login"
    exit 1
fi

# Set project - using same project as backend API
PROJECT_ID="levelup-467902"

echo "📋 Setting project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "🔧 Enabling required APIs..."
gcloud services enable appengine.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Validate files exist
if [ ! -f "index.html" ]; then
    echo "❌ index.html not found! Make sure you're in the right directory."
    exit 1
fi

if [ ! -f "style.css" ]; then
    echo "❌ style.css not found! Make sure you're in the right directory."
    exit 1
fi

if [ ! -f "script.js" ]; then
    echo "❌ script.js not found! Make sure you're in the right directory."
    exit 1
fi

if [ ! -f "app.yaml" ]; then
    echo "❌ app.yaml not found! Make sure you're in the right directory."
    exit 1
fi

echo "✅ All required files found"

# Deploy to App Engine
echo "☁️  Deploying to Google App Engine..."
gcloud app deploy app.yaml --quiet

echo "✅ Deployment complete!"
echo ""
echo "🌐 Your web app is now available at:"
gcloud app describe --format="value(defaultHostname)" | sed 's/^/   https:\/\//'
echo ""
echo "💡 Custom domain setup:"
echo "   - The app should be accessible at https://eventai.leveluplife.app"
echo "   - Make sure DNS is configured to point to Google App Engine"
echo "   - Verify in Google Cloud Console > App Engine > Settings > Custom domains"
echo ""
echo "📊 To monitor your app:"
echo "   gcloud app logs tail -s default"
echo ""
echo "🔧 API Integration:"
echo "   - Web app connects to: https://eventai.leveluplife.app/api"
echo "   - Backend API is deployed separately (eventai-api service)"
echo "   - Both services share the same custom domain with different paths"