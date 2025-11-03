// EventAI Web App - Standalone with Direct AI API Integration

class EventAIApp {
    constructor() {
        // Remove backend URL - we're calling AI APIs directly now
        this.ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages';
        this.OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions';

        // Model configurations
        this.ANTHROPIC_MODELS = [
            { value: 'claude-3-5-haiku-20241022', label: 'Claude 3.5 Haiku (Fast & Affordable)' },
            { value: 'claude-3-5-sonnet-20241022', label: 'Claude 3.5 Sonnet (Best Quality)' }
        ];

        this.OPENAI_MODELS = [
            { value: 'gpt-4o-mini', label: 'GPT-4o Mini (Fast & Affordable)' },
            { value: 'gpt-4o', label: 'GPT-4o (Best Quality)' },
            { value: 'gpt-4-turbo', label: 'GPT-4 Turbo' }
        ];

        // Configuration from localStorage
        this.config = this.loadConfig();

        // State
        this.currentEvents = [];
        this.selectedEvents = new Set();
        this.currentICSContent = '';
        this.isLoading = false;
        this.attachedImage = null;
        this.timezone = this.detectTimezone();

        this.init();
    }

    init() {
        console.log('EventAI Web App initializing (standalone mode)...');
        this.setupEventListeners();
        this.updateTimezoneDisplay();
        this.updateModelOptions(); // Populate model dropdown based on provider
        this.loadSavedSettings(); // Load saved settings into UI

        // Check if API key is configured on startup
        if (!this.config.apiKey) {
            this.showSettings();
        }
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
        console.log('Settings saved to localStorage');
    }

    loadSavedSettings() {
        // Populate settings UI with saved values
        document.getElementById('aiProvider').value = this.config.provider;
        document.getElementById('apiKey').value = this.config.apiKey;
        document.getElementById('aiModel').value = this.config.model;
    }

    updateModelOptions() {
        const modelSelect = document.getElementById('aiModel');
        const provider = this.config.provider;

        // Clear existing options
        modelSelect.innerHTML = '';

        // Get models for current provider
        const models = provider === 'anthropic' ? this.ANTHROPIC_MODELS : this.OPENAI_MODELS;

        // Populate options
        models.forEach(model => {
            const option = document.createElement('option');
            option.value = model.value;
            option.textContent = model.label;
            modelSelect.appendChild(option);
        });

        // Set default model if current model doesn't exist for this provider
        const modelExists = models.some(m => m.value === this.config.model);
        if (!modelExists) {
            this.config.model = models[0].value;
            modelSelect.value = this.config.model;
        } else {
            modelSelect.value = this.config.model;
        }
    }

    setupEventListeners() {
        // Text input events
        const textInput = document.getElementById('textInput');
        const clearBtn = document.getElementById('clearBtn');
        const generateBtn = document.getElementById('generateBtn');

        textInput.addEventListener('input', () => this.handleTextInputChange());
        clearBtn.addEventListener('click', () => this.clearInput());
        generateBtn.addEventListener('click', () => this.generateEvents());

        // Photo upload events
        const photoBtn = document.getElementById('photoBtn');
        const photoInput = document.getElementById('photoInput');
        const removeImageBtn = document.getElementById('removeImageBtn');

        photoBtn.addEventListener('click', () => photoInput.click());
        photoInput.addEventListener('change', (e) => this.handleImageUpload(e));
        removeImageBtn.addEventListener('click', () => this.removeImage());

        // Example button events
        document.querySelectorAll('.example-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const example = btn.dataset.example;
                textInput.value = example;
                this.handleTextInputChange();
                this.hideExamples();
            });
        });

        // Settings modal events
        const settingsBtn = document.getElementById('settingsBtn');
        const closeSettingsModal = document.getElementById('closeSettingsModal');
        const saveSettingsBtn = document.getElementById('saveSettingsBtn');
        const testConnectionBtn = document.getElementById('testConnectionBtn');
        const aiProviderSelect = document.getElementById('aiProvider');

        settingsBtn.addEventListener('click', () => this.showSettings());
        closeSettingsModal.addEventListener('click', () => this.hideSettings());
        saveSettingsBtn.addEventListener('click', () => this.saveSettings());
        testConnectionBtn.addEventListener('click', () => this.testConnection());
        aiProviderSelect.addEventListener('change', () => this.handleProviderChange());

        // Event preview modal events
        const closeEventPreview = document.getElementById('closeEventPreview');
        const selectAllBtn = document.getElementById('selectAllBtn');
        const addToCalendarBtn = document.getElementById('addToCalendarBtn');
        const shareEventsBtn = document.getElementById('shareEventsBtn');

        closeEventPreview.addEventListener('click', () => this.hideEventPreview());
        selectAllBtn.addEventListener('click', () => this.toggleSelectAll());
        addToCalendarBtn.addEventListener('click', () => this.addEventsToCalendar());
        shareEventsBtn.addEventListener('click', () => this.shareEvents());

        // Close modals when clicking overlay
        document.querySelectorAll('.modal-overlay').forEach(overlay => {
            overlay.addEventListener('click', (e) => {
                if (e.target === overlay) {
                    overlay.style.display = 'none';
                }
            });
        });
    }

    detectTimezone() {
        const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
        console.log('Detected timezone:', timezone);
        return timezone;
    }

    updateTimezoneDisplay() {
        const timezoneText = document.getElementById('timezoneText');
        const tz = this.timezone;

        // Simplified timezone display
        const abbreviations = {
            'America/New_York': 'EST',
            'America/Chicago': 'CST',
            'America/Denver': 'MST',
            'America/Los_Angeles': 'PST',
            'Europe/London': 'GMT',
            'Asia/Tokyo': 'JST',
            'Australia/Sydney': 'AEDT'
        };

        const abbrev = abbreviations[tz] || tz.split('/').pop().replace('_', ' ').substring(0, 8);
        timezoneText.textContent = abbrev;
    }

    // Settings Management
    showSettings() {
        const modal = document.getElementById('settingsModal');
        modal.style.display = 'flex';
        modal.classList.add('fade-in');
    }

    hideSettings() {
        const modal = document.getElementById('settingsModal');
        modal.style.display = 'none';
    }

    handleProviderChange() {
        const provider = document.getElementById('aiProvider').value;
        this.config.provider = provider;
        this.updateModelOptions();
    }

    saveSettings() {
        const provider = document.getElementById('aiProvider').value;
        const apiKey = document.getElementById('apiKey').value.trim();
        const model = document.getElementById('aiModel').value;

        if (!apiKey) {
            this.showConnectionStatus('Please enter an API key', 'error');
            return;
        }

        this.config.provider = provider;
        this.config.apiKey = apiKey;
        this.config.model = model;

        this.saveConfig();
        this.showConnectionStatus('Settings saved successfully!', 'success');

        setTimeout(() => {
            this.hideSettings();
        }, 1500);
    }

    async testConnection() {
        const apiKey = document.getElementById('apiKey').value.trim();
        const provider = document.getElementById('aiProvider').value;

        if (!apiKey) {
            this.showConnectionStatus('Please enter an API key first', 'error');
            return;
        }

        this.showConnectionStatus('Testing connection...', 'loading');

        try {
            const testPrompt = 'Hello';

            if (provider === 'anthropic') {
                const response = await fetch(this.ANTHROPIC_API_URL, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'x-api-key': apiKey,
                        'anthropic-version': '2023-06-01'
                    },
                    body: JSON.stringify({
                        model: 'claude-3-5-haiku-20241022',
                        max_tokens: 10,
                        messages: [{
                            role: 'user',
                            content: testPrompt
                        }]
                    })
                });

                if (response.ok) {
                    this.showConnectionStatus('Connection successful!', 'success');
                } else {
                    const error = await response.json();
                    this.showConnectionStatus(`Error: ${error.error?.message || 'Connection failed'}`, 'error');
                }
            } else {
                const response = await fetch(this.OPENAI_API_URL, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${apiKey}`
                    },
                    body: JSON.stringify({
                        model: 'gpt-4o-mini',
                        messages: [{ role: 'user', content: testPrompt }],
                        max_tokens: 10
                    })
                });

                if (response.ok) {
                    this.showConnectionStatus('Connection successful!', 'success');
                } else {
                    const error = await response.json();
                    this.showConnectionStatus(`Error: ${error.error?.message || 'Connection failed'}`, 'error');
                }
            }
        } catch (error) {
            this.showConnectionStatus(`Error: ${error.message}`, 'error');
        }
    }

    showConnectionStatus(message, type) {
        const statusDiv = document.getElementById('connectionStatus');
        statusDiv.textContent = message;
        statusDiv.className = `connection-status ${type}`;
        statusDiv.style.display = 'block';
    }

    // Text Input Handling
    handleTextInputChange() {
        const textInput = document.getElementById('textInput');
        const clearBtn = document.getElementById('clearBtn');
        const generateBtn = document.getElementById('generateBtn');

        const hasContent = textInput.value.trim().length > 0 || this.attachedImage;

        clearBtn.style.display = textInput.value.trim().length > 0 ? 'flex' : 'none';
        generateBtn.disabled = !hasContent || this.isLoading;

        if (textInput.value.trim().length > 0 || this.attachedImage) {
            this.hideExamples();
        } else {
            this.showExamples();
        }
    }

    showExamples() {
        const examplesSection = document.getElementById('examplesSection');
        examplesSection.style.display = 'block';
    }

    hideExamples() {
        const examplesSection = document.getElementById('examplesSection');
        examplesSection.style.display = 'none';
    }

    clearInput() {
        const textInput = document.getElementById('textInput');
        textInput.value = '';
        this.removeImage();
        this.handleTextInputChange();
        textInput.focus();
    }

    // Image Handling
    handleImageUpload(event) {
        const file = event.target.files[0];
        if (!file) return;

        console.log('Image selected:', file.name, file.size, 'bytes');

        if (!file.type.startsWith('image/')) {
            alert('Please select an image file.');
            return;
        }

        if (file.size > 10 * 1024 * 1024) {
            alert('Image file is too large. Please select an image smaller than 10MB.');
            return;
        }

        this.attachedImage = file;

        const reader = new FileReader();
        reader.onload = (e) => {
            const imagePreview = document.getElementById('imagePreview');
            const previewImage = document.getElementById('previewImage');

            previewImage.src = e.target.result;
            imagePreview.style.display = 'block';

            const photoBtn = document.getElementById('photoBtn');
            photoBtn.classList.add('active');
        };
        reader.readAsDataURL(file);

        this.handleTextInputChange();
        event.target.value = '';
    }

    removeImage() {
        this.attachedImage = null;

        const imagePreview = document.getElementById('imagePreview');
        const photoBtn = document.getElementById('photoBtn');

        imagePreview.style.display = 'none';
        photoBtn.classList.remove('active');

        this.handleTextInputChange();
    }

    fileToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = () => resolve(reader.result);
            reader.onerror = error => reject(error);
        });
    }

    // Event Generation with Direct AI API Calls
    async generateEvents() {
        const textInput = document.getElementById('textInput');
        const text = textInput.value.trim();

        if (!text && !this.attachedImage) return;

        if (!this.config.apiKey) {
            alert('Please configure your API key in Settings first.');
            this.showSettings();
            return;
        }

        console.log('Starting event generation with direct AI API...');
        this.setLoading(true);

        try {
            let events;

            if (this.config.provider === 'anthropic') {
                events = await this.convertWithAnthropic(text);
            } else {
                events = await this.convertWithOpenAI(text);
            }

            if (events && events.length > 0) {
                this.currentEvents = events;
                this.showEventPreview();
                this.clearInput();
            } else {
                console.log('No events found in AI response');
            }

        } catch (error) {
            console.error('Event generation failed:', error);
            alert(`Error: ${error.message}`);
        } finally {
            this.setLoading(false);
        }
    }

    async convertWithAnthropic(text) {
        const timezone = this.timezone;
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

        const content = [{ type: 'text', text: prompt }];

        // Add image if present
        if (this.attachedImage) {
            const base64 = await this.fileToBase64(this.attachedImage);
            const base64Data = base64.split(',')[1]; // Remove data:image/jpeg;base64, prefix

            content.push({
                type: 'image',
                source: {
                    type: 'base64',
                    media_type: this.attachedImage.type,
                    data: base64Data
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
            throw new Error(error.error?.message || 'Anthropic API request failed');
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
        const timezone = this.timezone;
        const currentDate = new Date().toLocaleString();

        const systemPrompt = 'You are a calendar event extraction assistant. Extract events and return ONLY a JSON array, no other text.';

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

        let messages = [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt }
        ];

        // Add image if present (OpenAI uses different format)
        if (this.attachedImage) {
            const base64 = await this.fileToBase64(this.attachedImage);
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
            throw new Error(error.error?.message || 'OpenAI API request failed');
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

    setLoading(loading) {
        this.isLoading = loading;
        const generateBtn = document.getElementById('generateBtn');
        const generateBtnText = document.getElementById('generateBtnText');
        const generateSpinner = document.getElementById('generateSpinner');

        if (loading) {
            generateBtnText.style.display = 'none';
            generateSpinner.style.display = 'block';
            generateBtn.disabled = true;
        } else {
            generateBtnText.style.display = 'block';
            generateSpinner.style.display = 'none';
            const textInput = document.getElementById('textInput');
            const hasContent = textInput.value.trim().length > 0 || this.attachedImage;
            generateBtn.disabled = !hasContent;
        }
    }

    // Event Preview and Management (keeping existing logic)
    showEventPreview() {
        const modal = document.getElementById('eventPreviewModal');
        const eventsContainer = document.getElementById('eventsContainer');
        const eventsSummaryText = document.getElementById('eventsSummaryText');

        const eventCount = this.currentEvents.length;
        eventsSummaryText.textContent = `Found ${eventCount} Event${eventCount === 1 ? '' : 's'}`;

        this.selectedEvents = new Set(this.currentEvents.map((_, index) => index));
        this.renderEvents();
        this.updateAddToCalendarButton();

        modal.style.display = 'flex';
        modal.classList.add('fade-in');
    }

    hideEventPreview() {
        const modal = document.getElementById('eventPreviewModal');
        modal.style.display = 'none';

        this.currentEvents = [];
        this.selectedEvents.clear();
        this.currentICSContent = '';
    }

    renderEvents() {
        const eventsContainer = document.getElementById('eventsContainer');
        eventsContainer.innerHTML = '';

        this.currentEvents.forEach((event, index) => {
            const eventCard = this.createEventCard(event, index);
            eventsContainer.appendChild(eventCard);
        });
    }

    createEventCard(event, index) {
        const isSelected = this.selectedEvents.has(index);

        const card = document.createElement('div');
        card.className = `event-card ${isSelected ? 'selected' : ''}`;
        card.addEventListener('click', () => this.toggleEventSelection(index));

        const startDate = this.parseEventDate(event.start_date);
        const endDate = event.end_date ? this.parseEventDate(event.end_date) : null;

        card.innerHTML = `
            <div class="event-header">
                <svg class="event-checkbox" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <${isSelected ? 'path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><path d="m9 11 3 3L22 4"' : 'circle cx="12" cy="12" r="10"'}></path>
                </svg>
                <h3 class="event-title">${this.escapeHtml(event.title)}</h3>
            </div>

            <div class="event-details">
                ${event.is_recurring ? `
                <div class="recurring-badge">
                    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M21 12c0 4.97-4.03 9-9 9s-9-4.03-9-9 4.03-9 9-9c2.41 0 4.6.95 6.21 2.64L21 3v6h-6"></path>
                    </svg>
                    ${this.formatRecurrencePattern(event.recurrence_pattern)}
                </div>
                ` : ''}

                ${startDate ? `
                <div class="time-info">
                    <div class="time-header">
                        <svg class="time-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <circle cx="12" cy="12" r="10"></circle>
                            <polyline points="12,6 12,12 16,14"></polyline>
                        </svg>
                        <div class="time-details">
                            ${event.is_recurring ? '<div class="first-occurrence">First occurrence</div>' : ''}
                            <div class="time-text">${this.formatEventTime(startDate, endDate, event.is_recurring)}</div>
                        </div>
                        ${endDate ? `<div class="duration-badge">${this.formatDuration(startDate, endDate)}</div>` : ''}
                    </div>
                </div>
                ` : ''}

                ${event.location ? `
                <div class="location-info">
                    <div class="info-header">
                        <svg class="location-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                            <circle cx="12" cy="10" r="3"></circle>
                        </svg>
                        <span class="info-text">${this.escapeHtml(event.location)}</span>
                    </div>
                </div>
                ` : ''}

                ${event.description ? `
                <div class="description-info">
                    <div class="info-header">
                        <svg class="description-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <line x1="3" y1="6" x2="21" y2="6"></line>
                            <line x1="3" y1="12" x2="21" y2="12"></line>
                            <line x1="3" y1="18" x2="15" y2="18"></line>
                        </svg>
                    </div>
                    <div class="description-text">${this.escapeHtml(event.description)}</div>
                </div>
                ` : ''}
            </div>
        `;

        return card;
    }

    parseEventDate(dateString) {
        try {
            const isoDate = new Date(dateString);
            if (!isNaN(isoDate.getTime())) {
                return isoDate;
            }

            const formats = [
                /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/,
                /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/
            ];

            for (const format of formats) {
                const match = dateString.match(format);
                if (match) {
                    const [, year, month, day, hour, minute, second] = match;
                    return new Date(year, month - 1, day, hour, minute, second);
                }
            }

            console.error('Failed to parse date:', dateString);
            return null;

        } catch (error) {
            console.error('Date parsing error:', error);
            return null;
        }
    }

    formatEventTime(startDate, endDate, isRecurring) {
        const dateFormatter = new Intl.DateTimeFormat('en-US', {
            dateStyle: 'medium',
            timeZone: this.timezone
        });

        const timeFormatter = new Intl.DateTimeFormat('en-US', {
            timeStyle: 'short',
            timeZone: this.timezone
        });

        if (isRecurring) {
            const startDateStr = dateFormatter.format(startDate);
            const startTimeStr = timeFormatter.format(startDate);

            if (endDate) {
                const endTimeStr = timeFormatter.format(endDate);
                return `Starts ${startDateStr}\n${startTimeStr} - ${endTimeStr}`;
            } else {
                return `Starts ${startDateStr} ${startTimeStr}\nEnds ∞ Indefinite`;
            }
        } else {
            const dateStr = dateFormatter.format(startDate);
            const startTimeStr = timeFormatter.format(startDate);

            if (endDate) {
                const endTimeStr = timeFormatter.format(endDate);
                return `${dateStr}\n${startTimeStr} - ${endTimeStr}`;
            } else {
                return `${dateStr}\n${startTimeStr}`;
            }
        }
    }

    formatDuration(startDate, endDate) {
        const diffMs = endDate.getTime() - startDate.getTime();
        const hours = Math.floor(diffMs / (1000 * 60 * 60));
        const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

        if (hours > 0 && minutes > 0) {
            return `${hours}h ${minutes}m`;
        } else if (hours > 0) {
            return `${hours}h`;
        } else if (minutes > 0) {
            return `${minutes}m`;
        } else {
            return '1h';
        }
    }

    formatRecurrencePattern(pattern) {
        if (!pattern) return 'Recurs regularly';

        const p = pattern.toLowerCase();

        if (p.includes('freq=')) {
            return this.parseRFC5545Recurrence(p);
        }

        if (p.includes('daily')) return 'Recurs daily';
        if (p.includes('weekly')) return 'Recurs weekly';
        if (p.includes('monthly')) return 'Recurs monthly';
        if (p.includes('yearly')) return 'Recurs yearly';

        return 'Recurs regularly';
    }

    parseRFC5545Recurrence(pattern) {
        const parts = pattern.split(';');
        let freq = '';
        let interval = 1;

        for (const part of parts) {
            if (part.startsWith('freq=')) {
                freq = part.substring(5);
            } else if (part.startsWith('interval=')) {
                interval = parseInt(part.substring(9)) || 1;
            }
        }

        switch (freq.toLowerCase()) {
            case 'daily':
                return interval === 1 ? 'Recurs daily' : `Recurs every ${interval} days`;
            case 'weekly':
                return interval === 1 ? 'Recurs weekly' : `Recurs every ${interval} weeks`;
            case 'monthly':
                return interval === 1 ? 'Recurs monthly' : `Recurs every ${interval} months`;
            case 'yearly':
                return interval === 1 ? 'Recurs yearly' : `Recurs every ${interval} years`;
            default:
                return 'Recurs regularly';
        }
    }

    toggleEventSelection(index) {
        if (this.selectedEvents.has(index)) {
            this.selectedEvents.delete(index);
        } else {
            this.selectedEvents.add(index);
        }

        this.renderEvents();
        this.updateAddToCalendarButton();
        this.updateSelectAllButton();
    }

    toggleSelectAll() {
        if (this.selectedEvents.size === this.currentEvents.length) {
            this.selectedEvents.clear();
        } else {
            this.selectedEvents = new Set(this.currentEvents.map((_, index) => index));
        }

        this.renderEvents();
        this.updateAddToCalendarButton();
        this.updateSelectAllButton();
    }

    updateSelectAllButton() {
        const selectAllBtn = document.getElementById('selectAllBtn');
        selectAllBtn.textContent = this.selectedEvents.size === this.currentEvents.length ? 'Deselect All' : 'Select All';
    }

    updateAddToCalendarButton() {
        const addToCalendarBtn = document.getElementById('addToCalendarBtn');
        const addToCalendarText = document.getElementById('addToCalendarText');

        const selectedCount = this.selectedEvents.size;
        addToCalendarBtn.disabled = selectedCount === 0;
        addToCalendarText.textContent = `Add ${selectedCount} Event${selectedCount === 1 ? '' : 's'} to Calendar`;
    }

    addEventsToCalendar() {
        if (this.selectedEvents.size === 0) return;

        console.log('Adding events to calendar...');

        const selectedEventData = Array.from(this.selectedEvents).map(index => this.currentEvents[index]);
        this.downloadICSFile(selectedEventData);

        this.showCelebration(this.selectedEvents.size);

        setTimeout(() => {
            this.hideEventPreview();
        }, 2500);
    }

    shareEvents() {
        if (this.currentEvents.length === 0) return;

        console.log('Sharing events...');
        this.downloadICSFile(this.currentEvents);
    }

    // ICS File Generation (Ported from Python backend)
    downloadICSFile(events) {
        const icsContent = this.generateICS(events);

        const blob = new Blob([icsContent], { type: 'text/calendar;charset=utf-8' });
        const url = URL.createObjectURL(blob);

        const a = document.createElement('a');
        a.href = url;
        a.download = 'EventAI-Events.ics';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);

        URL.revokeObjectURL(url);

        console.log('ICS file downloaded');
    }

    generateICS(events) {
        let ics = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//EventAI//EventAI 1.0//EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
X-WR-CALNAME:EventAI Events
X-WR-TIMEZONE:${this.timezone}

`;

        events.forEach(event => {
            const startDate = this.parseEventDate(event.start_date);
            const endDate = event.end_date ? this.parseEventDate(event.end_date) : null;

            if (startDate) {
                const uid = this.generateUID();
                const dtstamp = this.formatDateForICS(new Date());

                ics += `BEGIN:VEVENT
UID:${uid}@eventai.leveluplife.app
DTSTAMP:${dtstamp}
`;

                // Handle all-day events
                if (event.is_all_day) {
                    ics += `DTSTART;VALUE=DATE:${this.formatDateOnlyForICS(startDate)}
DTEND;VALUE=DATE:${this.formatDateOnlyForICS(endDate || new Date(startDate.getTime() + 86400000))}
`;
                } else {
                    ics += `DTSTART:${this.formatDateForICS(startDate)}
DTEND:${this.formatDateForICS(endDate || new Date(startDate.getTime() + 3600000))}
`;
                }

                ics += `SUMMARY:${this.escapeICSText(event.title)}
`;

                if (event.description) {
                    ics += `DESCRIPTION:${this.escapeICSText(event.description)}
`;
                }

                if (event.location) {
                    ics += `LOCATION:${this.escapeICSText(event.location)}
`;
                }

                if (event.is_recurring && event.recurrence_pattern) {
                    ics += `RRULE:${this.parseRecurrencePatternToRFC5545(event.recurrence_pattern)}
`;
                }

                ics += `CREATED:${dtstamp}
LAST-MODIFIED:${dtstamp}
SEQUENCE:0
STATUS:CONFIRMED
TRANSP:OPAQUE
URL:https://leveluplife.app/eventai
END:VEVENT

`;
            }
        });

        ics += 'END:VCALENDAR';
        return ics;
    }

    formatDateForICS(date) {
        return date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
    }

    formatDateOnlyForICS(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}${month}${day}`;
    }

    escapeICSText(text) {
        return text.replace(/\\/g, '\\\\')
                   .replace(/,/g, '\\,')
                   .replace(/;/g, '\\;')
                   .replace(/\n/g, '\\n');
    }

    parseRecurrencePatternToRFC5545(pattern) {
        if (!pattern) return 'FREQ=WEEKLY';

        // If already in RFC 5545 format, return as-is
        if (pattern.toUpperCase().startsWith('FREQ=')) {
            return pattern.toUpperCase();
        }

        // Convert natural language to RFC 5545
        const p = pattern.toLowerCase();

        if (p.includes('daily')) return 'FREQ=DAILY';
        if (p.includes('weekly')) return 'FREQ=WEEKLY';
        if (p.includes('monthly')) return 'FREQ=MONTHLY';
        if (p.includes('yearly')) return 'FREQ=YEARLY';

        return 'FREQ=WEEKLY'; // Default
    }

    generateUID() {
        return 'xxxx-xxxx-4xxx-yxxx-xxxx'.replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0;
            const v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    showCelebration(eventCount) {
        const overlay = document.getElementById('celebrationOverlay');
        const message = document.getElementById('celebrationMessage');

        message.textContent = `Added ${eventCount} event${eventCount === 1 ? '' : 's'} to your calendar`;

        overlay.style.display = 'flex';
        overlay.classList.add('fade-in');

        setTimeout(() => {
            overlay.style.display = 'none';
            overlay.classList.remove('fade-in');
        }, 2500);
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize the app when the DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.eventAI = new EventAIApp();
});
