# EventAI Refactoring Plan: Backend Removal & Client-Side AI

**Goal**: Remove the hosted backend service and enable users to configure their own Anthropic or OpenAI API keys for direct client-side AI event generation.

**Date**: November 2, 2025
**Status**: Planning Complete, Ready for Execution

---

## Executive Summary

### Current Architecture
- **Backend**: Python FastAPI service hosted on Google Cloud Run
- **AI Provider**: Anthropic Claude 3.5 Haiku (backend-controlled)
- **Database**: Firestore + BigQuery for usage tracking, subscriptions
- **Monetization**: Freemium model (2 free, 20 premium conversions/day)
- **Clients**: iOS app (Swift/SwiftUI) + Web app (vanilla JS)

### Target Architecture
- **Backend**: None (completely removed)
- **AI Provider**: User-configurable (Anthropic Claude OR OpenAI GPT)
- **Database**: None (no usage tracking needed)
- **Monetization**: Free app, users bring their own API keys
- **Clients**: iOS app + Web app with embedded AI logic

### Benefits
1. ✅ **Zero hosting costs** - no Cloud Run, Firestore, BigQuery
2. ✅ **No rate limiting** - users pay for their own API usage
3. ✅ **Privacy-focused** - no user tracking or data collection
4. ✅ **Simplified maintenance** - single codebase per platform
5. ✅ **Transparent costs** - users see exactly what they pay

---

## Phase 1: iOS App Refactoring

### 1.1 Remove Backend Dependencies

**Files to Modify**:
- `EventAI/Services/APIService.swift` - Remove all backend API calls
- `EventAI/Services/SubscriptionService.swift` - Remove completely
- `EventAI/Services/AdService.swift` - Remove completely
- `EventAI/ContentView.swift` - Remove usage tracking, premium logic

**Actions**:
```swift
// DELETE:
- APIService.convertTextToCalendar() → backend call
- APIService.getUsageStats() → backend call
- APIService.syncSubscriptionStatus() → backend call
- SubscriptionService (entire file)
- AdService (entire file)

// UPDATE Config.xcconfig:
- Remove: BACKEND_BASE_URL
- Remove: API_KEY
- Remove: ADMOB_APP_ID
- Remove: BANNER_AD_UNIT_ID
```

**Dependencies to Remove** (Podfile/Package.swift):
```
- Google Mobile Ads SDK
- StoreKit 2 subscription code
```

### 1.2 Add AI Configuration UI

**New Files**:
- `EventAI/Views/SettingsView.swift` - Settings screen
- `EventAI/Models/AIConfiguration.swift` - Config model
- `EventAI/Services/AIService.swift` - Direct AI API calls

**Settings Screen Features**:
```swift
struct SettingsView: View {
    // AI Provider Selection
    - Picker: Anthropic Claude / OpenAI GPT

    // API Key Input
    - SecureField for API key entry
    - "Test Connection" button
    - Key validation feedback

    // Model Selection (based on provider)
    - Anthropic: claude-3-5-haiku, claude-3-5-sonnet
    - OpenAI: gpt-4o-mini, gpt-4o, gpt-4-turbo

    // Advanced Settings
    - Temperature slider (0.0 - 1.0)
    - Max tokens slider (500 - 4000)

    // Storage
    - Save to iOS Keychain (secure storage)
}
```

**Storage Implementation**:
```swift
// Use iOS Keychain for secure API key storage
class KeychainService {
    static func saveAPIKey(_ key: String) throws
    static func loadAPIKey() throws -> String?
    static func deleteAPIKey() throws
}

// User defaults for non-sensitive config
UserDefaults.standard.set("anthropic", forKey: "ai_provider")
UserDefaults.standard.set("claude-3-5-haiku-20241022", forKey: "ai_model")
```

### 1.3 Implement Direct AI API Calls

**New Service**: `AIService.swift`

**Anthropic Implementation**:
```swift
class AnthropicService {
    let apiKey: String
    let model: String = "claude-3-5-haiku-20241022"
    let baseURL = "https://api.anthropic.com/v1/messages"

    func convertTextToEvents(
        text: String,
        timezone: String,
        image: UIImage? = nil
    ) async throws -> [CalendarEvent] {

        // Build prompt (port from backend)
        let prompt = """
        Extract calendar events from the following text.
        Current timezone: \(timezone)
        Current date: \(Date().formatted())

        Return JSON array with format:
        [{
          "title": "Event Title",
          "start_date": "2025-11-05T14:00:00",
          "end_date": "2025-11-05T15:00:00",
          "is_all_day": false,
          "is_recurring": false,
          "recurrence_pattern": null,
          "location": null,
          "description": null
        }]

        Text: \(text)
        """

        // Build request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Handle image if provided
        var content: [[String: Any]] = [
            ["type": "text", "text": prompt]
        ]

        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            let base64 = imageData.base64EncodedString()
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64
                ]
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "temperature": 0.1,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let contentArray = json["content"] as! [[String: Any]]
        let textContent = contentArray[0]["text"] as! String

        // Parse JSON from Claude response
        let events = try parseEventsJSON(textContent)

        return events
    }
}
```

**OpenAI Implementation**:
```swift
class OpenAIService {
    let apiKey: String
    let model: String = "gpt-4o-mini"
    let baseURL = "https://api.openai.com/v1/chat/completions"

    func convertTextToEvents(
        text: String,
        timezone: String,
        image: UIImage? = nil
    ) async throws -> [CalendarEvent] {

        // Similar implementation with OpenAI API format
        // Uses "messages" array with system/user roles
        // Vision support via image_url content type

        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": "You extract calendar events from text..."
            ],
            [
                "role": "user",
                "content": buildContentArray(text: text, image: image)
            ]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.1,
            "max_tokens": 2000
        ]

        // ... make request, parse response
    }
}
```

**Unified Interface**:
```swift
protocol AIServiceProtocol {
    func convertTextToEvents(
        text: String,
        timezone: String,
        image: UIImage?
    ) async throws -> [CalendarEvent]

    func testConnection() async throws -> Bool
}

// Factory pattern
class AIServiceFactory {
    static func createService(
        provider: AIProvider,
        apiKey: String,
        model: String
    ) -> AIServiceProtocol {
        switch provider {
        case .anthropic:
            return AnthropicService(apiKey: apiKey, model: model)
        case .openai:
            return OpenAIService(apiKey: apiKey, model: model)
        }
    }
}
```

### 1.4 Update Main UI Flow

**ContentView.swift Changes**:

```swift
struct ContentView: View {
    @State private var inputText = ""
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var events: [CalendarEvent] = []
    @State private var showSettings = false
    @State private var showAPIKeyAlert = false

    // Remove all usage tracking state vars
    // Remove premium/subscription state
    // Remove ad banner view

    var body: some View {
        NavigationView {
            VStack {
                // Settings button in nav bar

                // Input text area
                TextEditor(text: $inputText)

                // Image upload button
                PhotosPicker(...)

                // Convert button
                Button("Create Calendar Events") {
                    Task {
                        await convertToEvents()
                    }
                }
                .disabled(isProcessing || inputText.isEmpty)

                // Event preview list (if events exist)
                if !events.isEmpty {
                    EventPreviewList(events: events)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("API Key Required", isPresented: $showAPIKeyAlert) {
                Button("Open Settings") {
                    showSettings = true
                }
            }
        }
    }

    func convertToEvents() async {
        // Check if API key is configured
        guard let apiKey = try? KeychainService.loadAPIKey(),
              !apiKey.isEmpty else {
            showAPIKeyAlert = true
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Get AI config
            let provider = AIProvider(
                rawValue: UserDefaults.standard.string(forKey: "ai_provider") ?? "anthropic"
            )!
            let model = UserDefaults.standard.string(forKey: "ai_model") ?? "claude-3-5-haiku-20241022"

            // Create service
            let aiService = AIServiceFactory.createService(
                provider: provider,
                apiKey: apiKey,
                model: model
            )

            // Convert to events
            let timezone = TimeZone.current.identifier
            events = try await aiService.convertTextToEvents(
                text: inputText,
                timezone: timezone,
                image: selectedImage
            )

            // Show success
            // User can now select events to add to calendar

        } catch {
            // Show error alert
            print("Error: \(error)")
        }
    }
}
```

### 1.5 Update Calendar Integration

**CalendarService.swift** - Minimal changes needed:
- Already has ICS parsing logic
- Already creates EventKit events
- Just needs to receive events from new AI service instead of backend

```swift
// No major changes needed
// Already has:
- parseICSContent() → parse ICS string to events
- addEventToCalendar() → add to iOS calendar
- generateICSContent() → create ICS from event data

// New helper:
func generateICSFromEvents(_ events: [CalendarEvent]) -> String {
    // Port ICS generation logic from Python backend
    // Use iCalendar format
    return icsContent
}
```

---

## Phase 2: Web App Refactoring

### 2.1 Remove Backend Dependencies

**Files to Modify**:
- `calendar-web-client/public/index.html`
- `calendar-web-client/public/script.js`
- `calendar-web-client/public/style.css`

**Actions**:
```javascript
// DELETE from EventAIApp class:
- API_BASE_URL constant
- getUsageStats() method
- displayUsage() method
- showPremiumModal() method

// UPDATE convertText() method:
- Remove backend fetch call
- Add direct AI API call
```

### 2.2 Add Settings UI

**New HTML** (add to index.html):
```html
<!-- Settings Modal -->
<div id="settingsModal" class="modal" style="display: none;">
  <div class="modal-content settings-modal">
    <span class="close" onclick="app.closeSettings()">&times;</span>
    <h2>⚙️ Settings</h2>

    <div class="settings-section">
      <h3>AI Provider</h3>
      <select id="aiProvider" onchange="app.updateProvider()">
        <option value="anthropic">Anthropic Claude</option>
        <option value="openai">OpenAI GPT</option>
      </select>
    </div>

    <div class="settings-section">
      <h3>API Key</h3>
      <input
        type="password"
        id="apiKey"
        placeholder="sk-ant-... or sk-..."
        autocomplete="off"
      />
      <button onclick="app.testAPIKey()">Test Connection</button>
      <p class="hint">Your API key is stored locally and never sent to our servers.</p>
    </div>

    <div class="settings-section">
      <h3>Model</h3>
      <select id="aiModel">
        <!-- Populated dynamically based on provider -->
      </select>
    </div>

    <button onclick="app.saveSettings()">Save Settings</button>
  </div>
</div>
```

### 2.3 Implement Direct AI Calls

**New JavaScript** (update script.js):

```javascript
class EventAIApp {
    constructor() {
        this.config = this.loadConfig();
        this.ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages';
        this.OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions';
    }

    loadConfig() {
        return {
            provider: localStorage.getItem('ai_provider') || 'anthropic',
            apiKey: localStorage.getItem('api_key') || '',
            model: localStorage.getItem('ai_model') || 'claude-3-5-haiku-20241022'
        };
    }

    saveConfig() {
        localStorage.setItem('ai_provider', this.config.provider);
        localStorage.setItem('api_key', this.config.apiKey);
        localStorage.setItem('ai_model', this.config.model);
    }

    async convertText() {
        const text = document.getElementById('eventText').value.trim();

        if (!this.config.apiKey) {
            alert('Please configure your API key in Settings');
            this.showSettings();
            return;
        }

        if (!text) {
            alert('Please enter some text to convert');
            return;
        }

        this.showLoading(true);

        try {
            let events;

            if (this.config.provider === 'anthropic') {
                events = await this.convertWithAnthropic(text);
            } else {
                events = await this.convertWithOpenAI(text);
            }

            this.displayEvents(events);

        } catch (error) {
            console.error('Error:', error);
            alert(`Error: ${error.message}`);
        } finally {
            this.showLoading(false);
        }
    }

    async convertWithAnthropic(text) {
        const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
        const currentDate = new Date().toLocaleString();

        const prompt = `Extract calendar events from the following text.
Current timezone: ${timezone}
Current date: ${currentDate}

Return a JSON array with this exact format (no additional text):
[{
  "title": "Event Title",
  "start_date": "2025-11-05T14:00:00",
  "end_date": "2025-11-05T15:00:00",
  "is_all_day": false,
  "is_recurring": false,
  "recurrence_pattern": null,
  "location": null,
  "description": null
}]

Text: ${text}`;

        // Handle image if present
        const content = [{ type: 'text', text: prompt }];

        const imageInput = document.getElementById('imageInput');
        if (imageInput.files.length > 0) {
            const base64 = await this.fileToBase64(imageInput.files[0]);
            content.push({
                type: 'image',
                source: {
                    type: 'base64',
                    media_type: 'image/jpeg',
                    data: base64.split(',')[1] // Remove data:image/jpeg;base64, prefix
                }
            });
        }

        const response = await fetch(this.ANTHROPIC_API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': this.config.apiKey,
                'anthropic-version': '2023-06-01'
            },
            body: JSON.stringify({
                model: this.config.model,
                max_tokens: 2000,
                temperature: 0.1,
                messages: [{
                    role: 'user',
                    content: content
                }]
            })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error?.message || 'API request failed');
        }

        const data = await response.json();
        const eventsText = data.content[0].text;

        // Parse JSON from response
        const jsonMatch = eventsText.match(/\[[\s\S]*\]/);
        if (!jsonMatch) {
            throw new Error('Could not parse events from AI response');
        }

        return JSON.parse(jsonMatch[0]);
    }

    async convertWithOpenAI(text) {
        const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
        const currentDate = new Date().toLocaleString();

        const systemPrompt = `You are a calendar event extraction assistant. Extract events and return ONLY a JSON array, no other text.`;

        const userPrompt = `Extract calendar events from this text.
Timezone: ${timezone}
Current date: ${currentDate}

Return JSON array:
[{
  "title": "Event Title",
  "start_date": "2025-11-05T14:00:00",
  "end_date": "2025-11-05T15:00:00",
  "is_all_day": false,
  "is_recurring": false,
  "recurrence_pattern": null,
  "location": null,
  "description": null
}]

Text: ${text}`;

        const messages = [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt }
        ];

        // Handle image if present
        const imageInput = document.getElementById('imageInput');
        if (imageInput.files.length > 0) {
            const base64 = await this.fileToBase64(imageInput.files[0]);
            messages[1].content = [
                { type: 'text', text: userPrompt },
                { type: 'image_url', image_url: { url: base64 } }
            ];
        }

        const response = await fetch(this.OPENAI_API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.config.apiKey}`
            },
            body: JSON.stringify({
                model: this.config.model,
                messages: messages,
                temperature: 0.1,
                max_tokens: 2000
            })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error?.message || 'API request failed');
        }

        const data = await response.json();
        const eventsText = data.choices[0].message.content;

        // Parse JSON from response
        const jsonMatch = eventsText.match(/\[[\s\S]*\]/);
        if (!jsonMatch) {
            throw new Error('Could not parse events from AI response');
        }

        return JSON.parse(jsonMatch[0]);
    }

    fileToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = () => resolve(reader.result);
            reader.onerror = error => reject(error);
        });
    }

    displayEvents(events) {
        // Generate ICS content
        const icsContent = this.generateICS(events);

        // Show download button
        const downloadBtn = document.getElementById('downloadBtn');
        downloadBtn.style.display = 'block';
        downloadBtn.onclick = () => this.downloadICS(icsContent);

        // Display event list
        const eventList = document.getElementById('eventList');
        eventList.innerHTML = events.map(e => `
            <div class="event-preview">
                <h4>${e.title}</h4>
                <p>📅 ${new Date(e.start_date).toLocaleString()}</p>
                ${e.location ? `<p>📍 ${e.location}</p>` : ''}
                ${e.is_recurring ? `<p>🔄 ${e.recurrence_pattern}</p>` : ''}
            </div>
        `).join('');
    }

    generateICS(events) {
        // Port ICS generation logic from Python backend
        let ics = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//EventAI//EventAI 1.0//EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
`;

        events.forEach(event => {
            const uid = Math.random().toString(36).substring(2) + Date.now();
            const dtstamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';

            ics += `BEGIN:VEVENT
UID:${uid}@eventai.app
DTSTAMP:${dtstamp}
DTSTART:${this.formatICSDate(event.start_date)}
DTEND:${this.formatICSDate(event.end_date)}
SUMMARY:${this.escapeICS(event.title)}
`;

            if (event.location) {
                ics += `LOCATION:${this.escapeICS(event.location)}\n`;
            }

            if (event.description) {
                ics += `DESCRIPTION:${this.escapeICS(event.description)}\n`;
            }

            if (event.is_recurring && event.recurrence_pattern) {
                ics += `RRULE:${this.parseRecurrencePattern(event.recurrence_pattern)}\n`;
            }

            ics += `STATUS:CONFIRMED
END:VEVENT
`;
        });

        ics += 'END:VCALENDAR';
        return ics;
    }

    formatICSDate(dateStr) {
        const date = new Date(dateStr);
        return date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
    }

    escapeICS(str) {
        return str.replace(/[\\,;]/g, '\\$&').replace(/\n/g, '\\n');
    }

    parseRecurrencePattern(pattern) {
        // Simple pattern parsing (can be enhanced)
        pattern = pattern.toLowerCase();

        if (pattern.includes('daily')) return 'FREQ=DAILY';
        if (pattern.includes('weekly')) return 'FREQ=WEEKLY';
        if (pattern.includes('monthly')) return 'FREQ=MONTHLY';
        if (pattern.includes('yearly')) return 'FREQ=YEARLY';

        return 'FREQ=WEEKLY'; // Default
    }

    downloadICS(icsContent) {
        const blob = new Blob([icsContent], { type: 'text/calendar' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'events.ics';
        a.click();
        URL.revokeObjectURL(url);
    }
}

// Initialize app
const app = new EventAIApp();
```

---

## Phase 3: Backend Decommissioning

### 3.1 Data Preservation

**Before deletion, export critical data**:
```bash
# Export Firestore data (if needed for analytics)
gcloud firestore export gs://eventai-backups/final-export

# Export BigQuery tables (if needed for historical analysis)
bq extract --destination_format=NEWLINE_DELIMITED_JSON \
  eventai.usage_tracking \
  gs://eventai-backups/usage_tracking.json
```

### 3.2 Resource Deletion

**Google Cloud Resources to Delete**:
```bash
# 1. Cloud Run service
gcloud run services delete eventai-api --region=us-central1

# 2. Firestore database (after export)
# (Manual deletion from console - requires careful confirmation)

# 3. BigQuery dataset
bq rm -r -f eventai

# 4. Cloud Storage buckets (if any)
gsutil rm -r gs://eventai-*

# 5. IAM service accounts
gcloud iam service-accounts delete eventai-service@levelup-467902.iam.gserviceaccount.com

# 6. Container Registry images
gcloud container images delete gcr.io/levelup-467902/eventai-api
```

### 3.3 Domain/DNS Updates

**Update DNS records**:
```
Current: eventai.leveluplife.app → Cloud Run service
New: eventai.leveluplife.app → Static web hosting (Netlify/Vercel/GitHub Pages)
```

### 3.4 Repository Cleanup

**Files to delete**:
```bash
rm -rf /Users/mfiume/Development/EventAI/calendar-backend/
rm -rf /Users/mfiume/Development/EventAI/secrets/
rm /Users/mfiume/Development/EventAI/calendar-backend.Dockerfile
rm /Users/mfiume/Development/EventAI/deploy-calendar-backend.sh
```

---

## Phase 4: Testing & Validation

### 4.1 iOS App Testing

**Test Cases**:
1. ✅ First launch - prompt for API key
2. ✅ Settings screen - save/load configuration
3. ✅ Anthropic API - text-to-event conversion
4. ✅ OpenAI API - text-to-event conversion
5. ✅ Image upload - vision-based event extraction
6. ✅ Event preview - display parsed events
7. ✅ Calendar integration - add to iOS calendar
8. ✅ Recurrence rules - weekly, monthly patterns
9. ✅ All-day events - proper date handling
10. ✅ Error handling - invalid API key, network failure

**Testing Procedure**:
```bash
# Build iOS app
cd EventAI
xcodebuild -workspace EventAI.xcworkspace -scheme EventAI -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests
xcodebuild test -workspace EventAI.xcworkspace -scheme EventAI -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 4.2 Web App Testing

**Test Cases**:
1. ✅ Settings modal - save configuration
2. ✅ API key storage - localStorage persistence
3. ✅ Anthropic integration - fetch and parse
4. ✅ OpenAI integration - fetch and parse
5. ✅ Image upload - base64 encoding
6. ✅ ICS generation - valid calendar file
7. ✅ File download - browser compatibility
8. ✅ Mobile responsive - touch interactions
9. ✅ Error handling - API errors, CORS
10. ✅ Cross-browser - Chrome, Safari, Firefox

**Testing Procedure**:
```bash
# Serve locally
cd calendar-web-client
python3 -m http.server 8080

# Open browser
open http://localhost:8080
```

### 4.3 API Cost Testing

**Estimate costs per conversion**:
```
Anthropic Claude 3.5 Haiku:
- Input: $0.80 / million tokens
- Output: $4.00 / million tokens
- Average conversion: ~500 input + 200 output tokens
- Cost per conversion: ~$0.001 (0.1 cents)

OpenAI GPT-4o-mini:
- Input: $0.15 / million tokens
- Output: $0.60 / million tokens
- Average conversion: ~500 input + 200 output tokens
- Cost per conversion: ~$0.0002 (0.02 cents)

Result: Extremely affordable for end users
```

---

## Phase 5: Documentation & Release

### 5.1 Update README

**New README.md**:
```markdown
# EventAI - AI-Powered Calendar Event Creation

Convert natural language and images into calendar events using AI.

## Features
- 📝 Natural language event creation
- 📸 Image-based event extraction
- 🤖 Anthropic Claude or OpenAI GPT support
- 🔒 Privacy-focused (no backend, no tracking)
- 📅 Direct iOS Calendar integration
- 🌐 Web app with ICS file download

## Setup

### iOS App
1. Download from App Store
2. Open Settings → Configure API key
3. Choose AI provider (Anthropic or OpenAI)
4. Start creating events!

### Web App
1. Visit https://eventai.leveluplife.app
2. Click Settings → Enter API key
3. Convert text to calendar events
4. Download ICS file

## Getting API Keys

### Anthropic Claude
1. Visit https://console.anthropic.com
2. Sign up for account
3. Generate API key
4. Recommended model: claude-3-5-haiku-20241022

### OpenAI
1. Visit https://platform.openai.com
2. Sign up for account
3. Generate API key
4. Recommended model: gpt-4o-mini

## Privacy

- ✅ No backend server
- ✅ No usage tracking
- ✅ No data collection
- ✅ API keys stored locally (iOS Keychain / browser localStorage)
- ✅ Direct API calls to AI providers

## Cost

EventAI is free. You pay only for AI API usage:
- Claude Haiku: ~$0.001 per conversion (0.1 cents)
- GPT-4o-mini: ~$0.0002 per conversion (0.02 cents)

Most users spend less than $1/month.
```

### 5.2 User Migration Guide

**For existing users**:
```markdown
# Migration Guide: EventAI 2.0

## What's Changed?

EventAI 2.0 removes the hosted backend and usage limits. You now use your own AI API keys.

## Benefits

- ✅ Unlimited conversions
- ✅ No subscription required
- ✅ Lower cost (pay only for AI usage)
- ✅ Enhanced privacy
- ✅ Faster processing

## Setup Required

1. Update to EventAI 2.0
2. Get an API key:
   - Anthropic: https://console.anthropic.com
   - OpenAI: https://platform.openai.com
3. Add key in Settings
4. Start converting!

## Cost Comparison

Old: $0.99/month subscription (20 conversions/day)
New: ~$0.001 per conversion (unlimited)

Example: 10 conversions/day = ~$3/month vs $12/year old pricing
```

### 5.3 App Store Updates

**iOS App Store Description**:
```
EventAI - AI Calendar Assistant

Convert natural language into calendar events instantly.

NEW: Version 2.0
• Unlimited conversions
• Bring your own API key
• No subscription required
• Enhanced privacy

Features:
• Natural language processing
• Image-based event extraction
• Recurring event support
• Direct calendar integration
• Anthropic Claude & OpenAI support

How it works:
1. Enter text like "Team meeting every Monday at 10am"
2. EventAI uses AI to parse events
3. Add directly to your calendar

Privacy First:
• No backend server
• No usage tracking
• API keys stored securely on device

Get started today!
```

---

## Phase 6: Deployment & Rollout

### 6.1 iOS App Deployment

**Xcode Build**:
```bash
# 1. Update version number
# Info.plist: CFBundleShortVersionString = 2.0.0

# 2. Archive build
xcodebuild -workspace EventAI.xcworkspace \
  -scheme EventAI \
  -configuration Release \
  -archivePath build/EventAI.xcarchive \
  archive

# 3. Export IPA
xcodebuild -exportArchive \
  -archivePath build/EventAI.xcarchive \
  -exportPath build/ \
  -exportOptionsPlist ExportOptions.plist

# 4. Upload to App Store Connect
xcrun altool --upload-app \
  --type ios \
  --file build/EventAI.ipa \
  --apiKey {api_key} \
  --apiIssuer {issuer_id}
```

### 6.2 Web App Deployment

**Static Hosting** (Netlify example):
```bash
# 1. Build (if using build step)
cd calendar-web-client
# (No build step needed for vanilla JS)

# 2. Deploy to Netlify
netlify deploy --prod --dir=public

# 3. Configure custom domain
# Domain: eventai.leveluplife.app
# DNS: CNAME → {netlify-subdomain}.netlify.app
```

### 6.3 Rollout Strategy

**Phased Rollout**:
1. **Beta Testing** (1 week)
   - TestFlight release to 50-100 users
   - Collect feedback on API key setup flow
   - Monitor error rates

2. **Soft Launch** (1 week)
   - Release to 20% of App Store users
   - Monitor crash reports
   - Validate AI API error handling

3. **Full Release** (after validation)
   - Release to 100% of users
   - Announce on social media, website
   - Email existing users with migration guide

---

## Risk Assessment & Mitigation

### Risks

1. **API Key Leakage**
   - Risk: Users accidentally expose keys
   - Mitigation: Clear warnings, secure storage guidance

2. **High AI Costs for Users**
   - Risk: Unexpected bills from AI providers
   - Mitigation: Cost transparency, usage estimates in UI

3. **Complexity for Non-Technical Users**
   - Risk: API key setup too difficult
   - Mitigation: Detailed onboarding, video tutorials

4. **AI Provider Outages**
   - Risk: Service unavailable if provider down
   - Mitigation: Support both Anthropic and OpenAI (redundancy)

5. **CORS Issues on Web**
   - Risk: Browser blocks direct API calls
   - Mitigation: Test all browsers, provide fallback proxy option

### Rollback Plan

If critical issues arise:
1. Revert to v1.x in App Store (backend-based version)
2. Keep backend running for 30 days post-launch
3. Gradual migration rather than hard cutover

---

## Success Metrics

### Key Performance Indicators

1. **User Adoption**
   - Target: 80% of users configure API key within 7 days
   - Metric: Track via analytics event (anonymous)

2. **Error Rates**
   - Target: <5% API call failure rate
   - Metric: Client-side error logging

3. **User Satisfaction**
   - Target: 4.5+ star rating on App Store
   - Metric: App Store reviews

4. **Cost Savings**
   - Target: $0 monthly hosting costs
   - Metric: Google Cloud billing dashboard

### Timeline

- **Planning**: 1 day (completed)
- **iOS Development**: 3-4 days
- **Web Development**: 2-3 days
- **Testing**: 2-3 days
- **Beta Testing**: 1 week
- **Full Release**: 1 week
- **Total**: 3-4 weeks

---

## Conclusion

This refactoring eliminates the hosted backend, reduces costs to zero, improves user privacy, and provides unlimited usage. The architecture becomes simpler and more maintainable while delivering the same core functionality.

**Next Steps**:
1. Begin iOS app refactoring (Phase 1)
2. Implement web app changes (Phase 2)
3. Comprehensive testing (Phase 4)
4. Beta release (Phase 6)

**Ready to execute? Let's go! 🚀**
