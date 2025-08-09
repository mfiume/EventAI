#!/bin/bash

# EventAI iOS Configuration Setup Script

echo "🚀 Setting up EventAI iOS Configuration"

# Check if secrets directory exists
if [ ! -d "secrets" ]; then
    echo "❌ Error: secrets directory not found!"
    echo "📁 Please run this script from the EventAI-ios directory"
    exit 1
fi

# Copy example config if config doesn't exist
if [ ! -f "secrets/Config.xcconfig" ]; then
    echo "📝 Creating Config.xcconfig from template..."
    cp secrets/Config.example.xcconfig secrets/Config.xcconfig
    echo "✅ Config.xcconfig created"
else
    echo "✅ Config.xcconfig already exists"
fi

# Show current configuration
echo ""
echo "📋 Current API Configuration:"
grep "API_BASE_URL" secrets/Config.xcconfig || echo "⚠️  API_BASE_URL not found in config"

echo ""
echo "🔧 To complete setup:"
echo "1. Edit secrets/Config.xcconfig with your AdMob IDs (optional)"
echo "2. Open EventAI.xcodeproj in Xcode"  
echo "3. Build and run the app"
echo ""
echo "📌 Note: API endpoint is now hardcoded in APIService.swift for simplicity"

echo ""
echo "🌐 The app is hardcoded to use: https://eventai.leveluplife.app/api/"
echo "📝 API endpoint is configured directly in APIService.swift"
echo "✅ Setup complete!"