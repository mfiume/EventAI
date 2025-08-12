# EventAI Web Application

A web version of the EventAI iOS app that converts natural language text into calendar events using AI.

## Features

- **Natural Language Processing**: Convert plain English descriptions into structured calendar events
- **Photo Analysis**: Upload images of schedules or documents for event extraction
- **Usage Tracking**: Freemium model with daily conversion limits
- **Calendar Export**: Download events as .ics files for import into any calendar app
- **Premium Subscription**: Enhanced limits and features via RevenueCat integration
- **Responsive Design**: Works on desktop, tablet, and mobile devices

## Architecture

- **Frontend**: Vanilla HTML/CSS/JavaScript (no build step required)
- **Backend API**: Uses existing EventAI API at `https://eventai.leveluplife.app/api`
- **Hosting**: Google App Engine static hosting
- **Domain**: Deployed at `https://eventai.leveluplife.app`

## Files

- `index.html` - Main HTML structure
- `style.css` - Styles matching iOS app design
- `script.js` - JavaScript functionality
- `app.yaml` - Google App Engine configuration
- `deploy.sh` - Deployment script

## Deployment

1. Ensure you have Google Cloud CLI installed and authenticated
2. Run the deployment script:

```bash
./deploy.sh
```

This will deploy the web app to Google App Engine at the configured domain.

## API Integration

The web app integrates with the existing EventAI backend API:

- **Base URL**: `https://eventai.leveluplife.app/api`
- **Usage Endpoint**: `GET /usage` - Get daily usage stats
- **Convert Endpoint**: `POST /convert` - Convert text/image to calendar events

### API Request Format

```javascript
const formData = new FormData();
formData.append('text', 'Meeting tomorrow at 2pm');
formData.append('timezone', 'America/New_York');
formData.append('image', imageFile); // Optional

fetch('https://eventai.leveluplife.app/api/convert', {
    method: 'POST',
    body: formData
});
```

### API Response Format

```json
{
    "eventsFound": 1,
    "message": "Successfully created calendar events",
    "icsContent": "BEGIN:VCALENDAR...",
    "events": [
        {
            "title": "Meeting",
            "start_date": "2024-01-15T14:00:00",
            "end_date": "2024-01-15T15:00:00",
            "location": null,
            "description": null,
            "is_recurring": false,
            "recurrence_pattern": null,
            "timezone": "America/New_York"
        }
    ]
}
```

## Features Matching iOS App

### Core Functionality
- ✅ Text input with placeholder and examples
- ✅ Photo upload and preview
- ✅ Usage tracking and limits display
- ✅ Premium modal with upgrade options
- ✅ Event preview with selection
- ✅ Calendar export (.ics download)
- ✅ Success celebration animation

### UI/UX Elements
- ✅ iOS-style input field with toolbar
- ✅ Example buttons with icons
- ✅ Usage indicator for free users
- ✅ Premium modal with feature list
- ✅ Event cards with detailed information
- ✅ Responsive design for all screen sizes

### Technical Features
- ✅ Timezone detection and display
- ✅ Image upload with validation
- ✅ API error handling
- ✅ Loading states and animations
- ✅ Event selection and bulk actions
- ✅ ICS file generation and download

## Browser Compatibility

- Modern browsers with ES6+ support
- File API for image uploads
- Fetch API for network requests
- CSS Grid and Flexbox for layout

## Development

No build step required. Simply edit the HTML, CSS, and JavaScript files directly and deploy.

For local development:
1. Open `index.html` in a browser, or
2. Serve with a simple HTTP server: `python -m http.server 8000`

## Production Considerations

- Static files are served directly by Google App Engine
- HTTPS enforced for all connections
- Auto-scaling based on traffic
- Integrates with existing EventAI backend infrastructure