# EventAI

EventAI is an iOS app that converts natural language text into calendar events using AI. Simply describe your event in plain English, and EventAI will create a calendar entry that you can import directly into your iOS calendar.

## Features

- 🤖 **AI-Powered**: Uses Claude AI to intelligently parse natural language
- 📱 **Native iOS**: Built with SwiftUI for a smooth user experience  
- 📅 **Direct Calendar Integration**: Adds events directly to your iOS calendar
- 💰 **Ad-Supported**: Free to use with unobtrusive banner advertisements
- ⚡ **Fast & Reliable**: Hosted on Google Cloud Run for high availability

## Architecture

- **iOS App**: Native Swift/SwiftUI app with EventKit integration
- **Backend**: Python FastAPI service with Claude AI integration
- **Deployment**: Google Cloud Run with custom domain routing
- **Monetization**: Google AdMob banner advertisements

## Getting Started

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd calendar-backend
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Set up secrets:
   ```bash
   cp secrets/secrets.example.env secrets/secrets.env
   # Edit secrets/secrets.env with your Anthropic API key
   ```

4. Deploy to Google Cloud Run:
   ```bash
   ./deploy.sh
   ```

### iOS App Setup

1. Navigate to the iOS directory:
   ```bash
   cd EventAI-ios
   ```

2. Set up secrets:
   ```bash
   cp secrets/Config.example.xcconfig secrets/Config.xcconfig
   # Edit secrets/Config.xcconfig with your API endpoints and AdMob IDs
   ```

3. Open in Xcode:
   ```bash
   open EventAI.xcodeproj
   ```

4. Build and run on your device or simulator

## Usage Examples

EventAI can parse various types of natural language input:

- "Dentist appointment tomorrow at 2pm"
- "Team meeting next Monday from 9 to 10 AM in Conference Room B"
- "Birthday party this Saturday at 6pm at John's house"
- "Call mom every Sunday at 3pm"

## Configuration

### Environment Variables (Backend)

- `ANTHROPIC_API_KEY`: Your Claude API key from Anthropic
- `PORT`: Server port (default: 8080)
- `NODE_ENV`: Environment (production/development)

### iOS Configuration

Edit `secrets/Config.xcconfig` with:
- `API_BASE_URL`: Your backend API endpoint
- `ADMOB_APP_ID`: Your Google AdMob App ID
- `BANNER_AD_UNIT_ID`: Your AdMob Banner Ad Unit ID

## Security

- **No API keys in source code**: All keys stored in gitignored `secrets/` directories
- **Secure random key generation**: Use `openssl rand -hex 32` for secrets
- **Calendar permissions**: Requests proper iOS calendar access permissions

## Domain Setup

The app is configured to use the custom domain `eventai.leveluplife.app` which should be mapped to your Google Cloud Run service.

## License

This project is proprietary software. All rights reserved.

## Contact

For questions or support, contact: [your-email@domain.com]