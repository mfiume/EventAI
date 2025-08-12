// EventAI Web App - JavaScript functionality matching iOS app

class EventAIApp {
    constructor() {
        this.API_BASE_URL = 'https://eventai.leveluplife.app/api';
        this.currentEvents = [];
        this.selectedEvents = new Set();
        this.currentICSContent = '';
        this.usage = { count: 0, limit: 0, remaining: 0, isPremium: false };
        this.isLoading = false;
        this.attachedImage = null;
        this.timezone = this.detectTimezone();
        
        this.init();
    }
    
    init() {
        console.log('🚀 EventAI Web App initializing...');
        this.setupEventListeners();
        this.loadUsage();
        this.updateTimezoneDisplay();
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
        
        // Premium modal events
        const upgradeBtn = document.getElementById('upgradeBtn');
        const upgradePremiumBtn = document.getElementById('upgradePremiumBtn');
        const closePremiumModal = document.getElementById('closePremiumModal');
        
        upgradeBtn.addEventListener('click', () => this.showPremiumModal());
        upgradePremiumBtn.addEventListener('click', () => this.handlePremiumUpgrade());
        closePremiumModal.addEventListener('click', () => this.hidePremiumModal());
        
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
        
        // Timezone display click (for future timezone picker)
        document.getElementById('timezoneDisplay').addEventListener('click', () => {
            // Placeholder for timezone picker - could be enhanced later
            console.log('Timezone picker would open here');
        });
    }
    
    detectTimezone() {
        const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
        console.log('🌍 Detected timezone:', timezone);
        return timezone;
    }
    
    updateTimezoneDisplay() {
        const timezoneText = document.getElementById('timezoneText');
        const tz = this.timezone;
        
        // Simplified timezone display similar to iOS app
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
    
    async loadUsage() {
        console.log('📊 Loading usage stats...');
        
        try {
            const response = await fetch(`${this.API_BASE_URL}/usage`);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }
            
            const usage = await response.json();
            this.usage = usage;
            
            console.log('📊 Usage loaded:', usage);
            this.updateUsageDisplay();
            
        } catch (error) {
            console.error('❌ Failed to load usage:', error);
            // Keep existing stats on error
        }
    }
    
    updateUsageDisplay() {
        const usageIndicator = document.getElementById('usageIndicator');
        const usageCount = document.getElementById('usageCount');
        
        if (this.usage.isPremium) {
            usageIndicator.style.display = 'none';
        } else {
            usageIndicator.style.display = 'flex';
            usageCount.textContent = `${this.usage.remaining} of ${this.usage.limit} remaining`;
        }
        
        // Update premium modal comparison if user is free
        if (!this.usage.isPremium && this.usage.limit > 0) {
            const upgradeComparison = document.getElementById('upgradeComparison');
            const comparisonText = document.getElementById('comparisonText');
            const premiumLimit = this.usage.limit < 100 ? 20 : 200; // Handle testing vs production
            
            upgradeComparison.style.display = 'block';
            comparisonText.textContent = `Upgrade from ${this.usage.limit} to ${premiumLimit} daily conversions`;
        }
    }
    
    handleTextInputChange() {
        const textInput = document.getElementById('textInput');
        const clearBtn = document.getElementById('clearBtn');
        const generateBtn = document.getElementById('generateBtn');
        const examplesSection = document.getElementById('examplesSection');
        
        const hasContent = textInput.value.trim().length > 0 || this.attachedImage;
        
        // Show/hide clear button
        clearBtn.style.display = textInput.value.trim().length > 0 ? 'flex' : 'none';
        
        // Enable/disable generate button
        generateBtn.disabled = !hasContent || this.isLoading;
        
        // Show/hide examples
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
    
    handleImageUpload(event) {
        const file = event.target.files[0];
        if (!file) return;
        
        console.log('🖼️ Image selected:', file.name, file.size, 'bytes');
        
        // Validate file type
        if (!file.type.startsWith('image/')) {
            alert('Please select an image file.');
            return;
        }
        
        // Validate file size (10MB limit)
        if (file.size > 10 * 1024 * 1024) {
            alert('Image file is too large. Please select an image smaller than 10MB.');
            return;
        }
        
        this.attachedImage = file;
        
        // Show preview
        const reader = new FileReader();
        reader.onload = (e) => {
            const imagePreview = document.getElementById('imagePreview');
            const previewImage = document.getElementById('previewImage');
            
            previewImage.src = e.target.result;
            imagePreview.style.display = 'block';
            
            // Update photo button color
            const photoBtn = document.getElementById('photoBtn');
            photoBtn.classList.add('active');
        };
        reader.readAsDataURL(file);
        
        // Update input state
        this.handleTextInputChange();
        
        // Clear the input so the same file can be selected again
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
    
    async generateEvents() {
        const textInput = document.getElementById('textInput');
        const text = textInput.value.trim();
        
        if (!text && !this.attachedImage) return;
        
        // Check usage limits for non-premium users
        if (!this.usage.isPremium && this.usage.remaining <= 0) {
            this.showPremiumModal();
            return;
        }
        
        console.log('🔗 Starting event generation...');
        this.setLoading(true);
        
        try {
            // Prepare form data
            const formData = new FormData();
            
            // Prepare text with image context if image is attached
            let finalText = text;
            if (this.attachedImage) {
                if (!finalText) {
                    finalText = 'Please analyze this image and create calendar events from any schedule, meeting, or event information you can see.';
                } else {
                    finalText += '\n\n[Image attached - please analyze the image for additional schedule information]';
                }
                formData.append('image', this.attachedImage);
            }
            
            formData.append('text', finalText);
            formData.append('timezone', this.timezone);
            
            console.log('🔍 DEBUG - REQUEST TO BACKEND:');
            console.log('='.repeat(80));
            console.log('Text:', finalText);
            console.log('Timezone:', this.timezone);
            console.log('Image:', this.attachedImage ? `Attached (${this.attachedImage.name})` : 'None');
            console.log('='.repeat(80));
            
            const response = await fetch(`${this.API_BASE_URL}/convert`, {
                method: 'POST',
                body: formData
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const result = await response.json();
            
            console.log('🤖 DEBUG - RESPONSE FROM BACKEND:');
            console.log('='.repeat(80));
            console.log('Events Found:', result.eventsFound);
            console.log('Message:', result.message);
            console.log('Events:', result.events);
            console.log('ICS Content Length:', result.icsContent.length, 'characters');
            console.log('='.repeat(80));
            
            if (result.eventsFound > 0 && result.events && result.events.length > 0) {
                this.currentEvents = result.events;
                this.currentICSContent = result.icsContent;
                this.showEventPreview();
                
                // Clear input after successful conversion
                this.clearInput();
                
                // Refresh usage stats for non-premium users
                if (!this.usage.isPremium) {
                    await this.loadUsage();
                }
            } else {
                // Only show error alerts for actual API/technical errors, not \"no events found\"
                if (!result.message.toLowerCase().includes('no events') && 
                    !result.message.toLowerCase().includes('couldn\\'t find') &&
                    !result.message.toLowerCase().includes('no calendar events')) {
                    alert(`Error: ${result.message}`);
                }
                // For \"no events found\", just do nothing - user can try again
            }
            
        } catch (error) {
            console.error('❌ Event generation failed:', error);
            alert(`Error: ${error.message}`);
        } finally {
            this.setLoading(false);
        }
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
    
    showPremiumModal() {
        const modal = document.getElementById('premiumModal');
        modal.style.display = 'flex';
        modal.classList.add('fade-in');
    }
    
    hidePremiumModal() {
        const modal = document.getElementById('premiumModal');
        modal.style.display = 'none';
    }
    
    handlePremiumUpgrade() {
        // For now, just show a placeholder message
        // In a real implementation, this would integrate with RevenueCat Web SDK
        alert('Premium upgrade functionality would be implemented here with RevenueCat Web SDK.');
        
        // Placeholder: simulate successful upgrade
        // this.usage.isPremium = true;
        // this.updateUsageDisplay();
        // this.hidePremiumModal();
    }
    
    showEventPreview() {
        const modal = document.getElementById('eventPreviewModal');
        const eventsContainer = document.getElementById('eventsContainer');
        const eventsSummaryText = document.getElementById('eventsSummaryText');
        
        // Update summary
        const eventCount = this.currentEvents.length;
        eventsSummaryText.textContent = `Found ${eventCount} Event${eventCount === 1 ? '' : 's'}`;
        
        // Select all events by default
        this.selectedEvents = new Set(this.currentEvents.map((_, index) => index));
        
        // Render events
        this.renderEvents();
        
        // Update action button
        this.updateAddToCalendarButton();
        
        modal.style.display = 'flex';
        modal.classList.add('fade-in');
    }
    
    hideEventPreview() {
        const modal = document.getElementById('eventPreviewModal');
        modal.style.display = 'none';
        
        // Reset state
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
        
        // Parse dates
        const startDate = this.parseEventDate(event.start_date);
        const endDate = event.end_date ? this.parseEventDate(event.end_date) : null;
        
        card.innerHTML = `
            <div class=\"event-header\">
                <svg class=\"event-checkbox\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\">
                    <${isSelected ? 'path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path><path d=\"m9 11 3 3L22 4\"' : 'circle cx=\"12\" cy=\"12\" r=\"10\"'}></path>
                </svg>
                <h3 class=\"event-title\">${this.escapeHtml(event.title)}</h3>
            </div>
            
            <div class=\"event-details\">
                ${event.is_recurring ? `
                <div class=\"recurring-badge\">
                    <svg class=\"icon\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\">
                        <path d=\"M21 12c0 4.97-4.03 9-9 9s-9-4.03-9-9 4.03-9 9-9c2.41 0 4.6.95 6.21 2.64L21 3v6h-6\"></path>
                    </svg>
                    ${this.formatRecurrencePattern(event.recurrence_pattern)}
                </div>
                ` : ''}
                
                ${startDate ? `
                <div class=\"time-info\">
                    <div class=\"time-header\">
                        <svg class=\"time-icon\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\">
                            <circle cx=\"12\" cy=\"12\" r=\"10\"></circle>
                            <polyline points=\"12,6 12,12 16,14\"></polyline>
                        </svg>
                        <div class=\"time-details\">
                            ${event.is_recurring ? '<div class=\"first-occurrence\">First occurrence</div>' : ''}
                            <div class=\"time-text\">${this.formatEventTime(startDate, endDate, event.is_recurring)}</div>
                            ${event.timezone ? `<div class=\"timezone-text\">${this.formatTimezone(event.timezone)}</div>` : ''}
                        </div>
                        ${endDate ? `<div class=\"duration-badge\">${this.formatDuration(startDate, endDate)}</div>` : ''}
                    </div>
                </div>
                ` : ''}
                
                ${event.location ? `
                <div class=\"location-info\">
                    <div class=\"info-header\">
                        <svg class=\"location-icon\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\">
                            <path d=\"M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z\"></path>
                            <circle cx=\"12\" cy=\"10\" r=\"3\"></circle>
                        </svg>
                        <span class=\"info-text\">${this.escapeHtml(event.location)}</span>
                    </div>
                </div>
                ` : ''}
                
                ${event.description ? `
                <div class=\"description-info\">
                    <div class=\"info-header\">
                        <svg class=\"description-icon\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\">
                            <line x1=\"3\" y1=\"6\" x2=\"21\" y2=\"6\"></line>
                            <line x1=\"3\" y1=\"12\" x2=\"21\" y2=\"12\"></line>
                            <line x1=\"3\" y1=\"18\" x2=\"15\" y2=\"18\"></line>
                        </svg>
                    </div>
                    <div class=\"description-text\">${this.escapeHtml(event.description)}</div>
                </div>
                ` : ''}
            </div>
        `;
        
        return card;
    }
    
    parseEventDate(dateString) {
        // Try multiple date formats similar to iOS app
        try {
            // ISO format
            const isoDate = new Date(dateString);
            if (!isNaN(isoDate.getTime())) {
                return isoDate;
            }
            
            // Manual parsing for other formats
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
            
            console.error('❌ Failed to parse date:', dateString);
            return null;
            
        } catch (error) {
            console.error('❌ Date parsing error:', error);
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
                
                // Check if same day
                if (this.isSameDay(startDate, endDate)) {
                    return `Starts ${startDateStr}\\n${startTimeStr} - ${endTimeStr}`;
                } else {
                    const endDateStr = dateFormatter.format(endDate);
                    return `Starts ${startDateStr} ${startTimeStr}\\nEnds ${endDateStr} ${endTimeStr}`;
                }
            } else {
                return `Starts ${startDateStr} ${startTimeStr}\\nEnds ∞ Indefinite`;
            }
        } else {
            const dateStr = dateFormatter.format(startDate);
            const startTimeStr = timeFormatter.format(startDate);
            
            if (endDate) {
                const endTimeStr = timeFormatter.format(endDate);
                return `${dateStr}\\n${startTimeStr} - ${endTimeStr}`;
            } else {
                return `${dateStr}\\n${startTimeStr}`;
            }
        }
    }
    
    formatTimezone(timezone) {
        try {
            const tz = Intl.DateTimeFormat('en', { timeZone: timezone }).resolvedOptions().timeZone;
            const now = new Date();
            const shortName = now.toLocaleString('en', { timeZoneName: 'short', timeZone: timezone }).split(' ').pop();
            return `${timezone.replace('_', ' ')} (${shortName})`;
        } catch {
            return timezone.replace('_', ' ');
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
        
        // Parse RFC 5545 patterns
        if (p.includes('freq=')) {
            return this.parseRFC5545Recurrence(p);
        }
        
        // Handle natural language patterns
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
    
    isSameDay(date1, date2) {
        return date1.getFullYear() === date2.getFullYear() &&
               date1.getMonth() === date2.getMonth() &&
               date1.getDate() === date2.getDate();
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
        
        console.log('📅 Adding events to calendar...');
        
        // Create ICS file for selected events
        const selectedEventData = Array.from(this.selectedEvents).map(index => this.currentEvents[index]);
        this.downloadICSFile(selectedEventData);
        
        // Show celebration
        this.showCelebration(this.selectedEvents.size);
        
        // Close preview modal
        setTimeout(() => {
            this.hideEventPreview();
        }, 2500);
    }
    
    shareEvents() {
        if (this.currentEvents.length === 0) return;
        
        console.log('🔗 Sharing events...');
        
        // Create and download ICS file
        this.downloadICSFile(this.currentEvents);
    }
    
    downloadICSFile(events) {
        // Create ICS content for selected events
        let icsContent = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//EventAI//EventAI Web//EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
X-WR-CALNAME:EventAI Events
X-WR-TIMEZONE:${this.timezone}

`;
        
        events.forEach(event => {
            const startDate = this.parseEventDate(event.start_date);
            const endDate = event.end_date ? this.parseEventDate(event.end_date) : null;
            
            if (startDate) {
                icsContent += `BEGIN:VEVENT
UID:${this.generateUID()}@eventai.leveluplife.app
DTSTART:${this.formatDateForICS(startDate)}
${endDate ? `DTEND:${this.formatDateForICS(endDate)}` : ''}
SUMMARY:${this.escapeICSText(event.title)}
${event.description ? `DESCRIPTION:${this.escapeICSText(event.description)}` : ''}
${event.location ? `LOCATION:${this.escapeICSText(event.location)}` : ''}
${event.is_recurring && event.recurrence_pattern ? `RRULE:${event.recurrence_pattern}` : ''}
CREATED:${this.formatDateForICS(new Date())}
LAST-MODIFIED:${this.formatDateForICS(new Date())}
SEQUENCE:0
STATUS:CONFIRMED
TRANSP:OPAQUE
END:VEVENT

`;
            }
        });
        
        icsContent += 'END:VCALENDAR';
        
        // Download the file
        const blob = new Blob([icsContent], { type: 'text/calendar;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = 'EventAI-Events.ics';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        
        URL.revokeObjectURL(url);
        
        console.log('📅 ICS file downloaded');
    }
    
    formatDateForICS(date) {
        return date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
    }
    
    escapeICSText(text) {
        return text.replace(/[\\\\,;\\n]/g, match => {
            switch (match) {
                case '\\\\': return '\\\\\\\\';
                case ',': return '\\\\,';
                case ';': return '\\\\;';
                case '\\n': return '\\\\n';
                default: return match;
            }
        });
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
        
        // Auto-hide after 2.5 seconds
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