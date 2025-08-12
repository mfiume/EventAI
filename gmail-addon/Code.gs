/**
 * EventAI Gmail Add-on
 * Extract calendar events from emails using AI
 */

// EventAI API Configuration
const EVENTAI_API_BASE = 'https://eventai-api-661796696046.us-central1.run.app';
const EVENTAI_API_KEY = 'gmail_addon_key_placeholder'; // This will be configured per deployment

/**
 * Build the Gmail add-on main interface
 */
function buildGmailAddon(e) {
  console.log('Building Gmail addon interface');
  
  try {
    // Create the main card
    const card = CardService.newCardBuilder()
      .setHeader(CardService.newCardHeader()
        .setTitle('EventAI')
        .setSubtitle('Extract events from emails')
        .setImageUrl('https://eventai-api-661796696046.us-central1.run.app/static/logo.png')
        .setImageStyle(CardService.ImageStyle.CIRCLE))
      .addSection(buildMainSection(e))
      .build();
    
    return [card];
  } catch (error) {
    console.error('Error building Gmail addon:', error);
    return [buildErrorCard('Failed to load EventAI. Please try again.')];
  }
}

/**
 * Build the main section of the add-on
 */
function buildMainSection(e) {
  const section = CardService.newCardSection()
    .setHeader('📅 Extract Calendar Events');
  
  // Check if we have access to current email
  if (e && e.messageMetadata) {
    // Extract Events button
    const extractButton = CardService.newTextButton()
      .setText('🚀 Extract Events from this Email')
      .setOnClickAction(CardService.newAction()
        .setFunctionName('extractEventsFromCurrentEmail')
        .setParameters({messageId: e.messageMetadata.messageId}))
      .setTextButtonStyle(CardService.TextButtonStyle.FILLED);
    
    section.addWidget(CardService.newButtonSet()
      .addButton(extractButton));
    
    // Email info
    section.addWidget(CardService.newTextParagraph()
      .setText(`📧 Current email: ${e.messageMetadata.subject || 'No subject'}`));
  } else {
    // No email selected
    section.addWidget(CardService.newTextParagraph()
      .setText('📧 Open an email to extract calendar events from it.'));
  }
  
  // Instructions
  section.addWidget(CardService.newTextParagraph()
    .setText('💡 EventAI will analyze your email content and extract any meetings, appointments, or events it finds.'));
  
  // Settings button
  const settingsButton = CardService.newTextButton()
    .setText('⚙️ Settings')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('showSettings'))
    .setTextButtonStyle(CardService.TextButtonStyle.TEXT);
  
  section.addWidget(CardService.newButtonSet()
    .addButton(settingsButton));
  
  return section;
}

/**
 * Extract events from the currently open email
 */
function extractEventsFromCurrentEmail(e) {
  console.log('Extracting events from current email');
  
  try {
    const messageId = e.parameters.messageId;
    if (!messageId) {
      return buildErrorCard('No email selected. Please open an email first.');
    }
    
    // Get email content
    const emailData = getEmailContent(messageId);
    if (!emailData.success) {
      return buildErrorCard(`Failed to read email: ${emailData.error}`);
    }
    
    // Show loading card
    const loadingCard = CardService.newCardBuilder()
      .setHeader(CardService.newCardHeader()
        .setTitle('EventAI')
        .setSubtitle('Processing...'))
      .addSection(CardService.newCardSection()
        .addWidget(CardService.newTextParagraph()
          .setText('🤖 AI is analyzing your email...\n\nThis may take a few seconds.')))
      .build();
    
    // Start async processing
    processEmailForEvents(emailData, messageId);
    
    return CardService.newActionResponseBuilder()
      .setNavigation(CardService.newNavigation()
        .updateCard(loadingCard))
      .build();
    
  } catch (error) {
    console.error('Error extracting events:', error);
    return buildErrorCard(`Error: ${error.message}`);
  }
}

/**
 * Process email content for events
 */
function processEmailForEvents(emailData, messageId) {
  try {
    // Get user's timezone
    const userTimezone = Session.getScriptTimeZone();
    
    // Prepare email content for EventAI
    const emailText = `Subject: ${emailData.subject}\nFrom: ${emailData.sender}\n\n${emailData.body}`;
    
    // Call EventAI API
    const response = callEventAIAPI('/api/gmail/extract', {
      email_content: emailData.body,
      subject: emailData.subject,
      sender: emailData.sender,
      timezone: userTimezone,
      user_email: Session.getActiveUser().getEmail()
    });
    
    if (response.success && response.events_found > 0) {
      // Show events preview
      const eventsCard = buildEventsPreviewCard(response.events, response.message);
      
      // Update the card
      return CardService.newActionResponseBuilder()
        .setNavigation(CardService.newNavigation()
          .updateCard(eventsCard))
        .build();
    } else {
      // No events found
      const noEventsCard = buildNoEventsCard(response.message || 'No events found in this email.');
      
      return CardService.newActionResponseBuilder()
        .setNavigation(CardService.newNavigation()
          .updateCard(noEventsCard))
        .build();
    }
    
  } catch (error) {
    console.error('Error processing email for events:', error);
    const errorCard = buildErrorCard(`Processing failed: ${error.message}`);
    
    return CardService.newActionResponseBuilder()
      .setNavigation(CardService.newNavigation()
        .updateCard(errorCard))
      .build();
  }
}

/**
 * Get email content from Gmail
 */
function getEmailContent(messageId) {
  try {
    const message = Gmail.Users.Messages.get('me', messageId, {format: 'full'});
    
    const headers = message.payload.headers || [];
    let subject = '';
    let sender = '';
    let date = '';
    
    // Extract headers
    headers.forEach(header => {
      const name = header.name.toLowerCase();
      if (name === 'subject') subject = header.value;
      if (name === 'from') sender = header.value;
      if (name === 'date') date = header.value;
    });
    
    // Extract body content
    const body = extractBodyFromPayload(message.payload);
    
    return {
      success: true,
      subject: subject,
      sender: sender,
      date: date,
      body: body,
      messageId: messageId
    };
    
  } catch (error) {
    console.error('Error getting email content:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Extract text content from Gmail message payload
 */
function extractBodyFromPayload(payload) {
  let body = '';
  
  if (payload.parts) {
    // Multi-part message
    for (const part of payload.parts) {
      if (part.mimeType === 'text/plain' && part.body.data) {
        body += Utilities.newBlob(Utilities.base64Decode(part.body.data)).getDataAsString();
      } else if (part.mimeType === 'text/html' && part.body.data && !body) {
        // Fallback to HTML if no plain text
        const htmlContent = Utilities.newBlob(Utilities.base64Decode(part.body.data)).getDataAsString();
        body += htmlContent.replace(/<[^>]*>/g, ''); // Simple HTML tag removal
      }
    }
  } else if (payload.body && payload.body.data) {
    // Single part message
    body = Utilities.newBlob(Utilities.base64Decode(payload.body.data)).getDataAsString();
  }
  
  return body.trim();
}

/**
 * Build events preview card
 */
function buildEventsPreviewCard(events, message) {
  const card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader()
      .setTitle('EventAI')
      .setSubtitle(`Found ${events.length} event(s)`));
  
  // Message section
  const messageSection = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText(`✅ ${message}`));
  
  card.addSection(messageSection);
  
  // Events section
  const eventsSection = CardService.newCardSection()
    .setHeader('📅 Extracted Events');
  
  events.forEach((event, index) => {
    const eventWidget = CardService.newDecoratedText()
      .setTopLabel(`Event ${index + 1}`)
      .setText(event.title || 'Untitled Event')
      .setBottomLabel(formatEventTime(event.start_date, event.end_date))
      .setWrapText(true);
    
    if (event.location) {
      eventWidget.setBottomLabel(`${formatEventTime(event.start_date, event.end_date)} • ${event.location}`);
    }
    
    eventsSection.addWidget(eventWidget);
  });
  
  card.addSection(eventsSection);
  
  // Action buttons
  const actionsSection = CardService.newCardSection();
  
  const addToCalendarButton = CardService.newTextButton()
    .setText('📅 Add to Google Calendar')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('showCalendarSelection')
      .setParameters({events: JSON.stringify(events)}))
    .setTextButtonStyle(CardService.TextButtonStyle.FILLED);
  
  const backButton = CardService.newTextButton()
    .setText('← Back')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('buildGmailAddon'))
    .setTextButtonStyle(CardService.TextButtonStyle.TEXT);
  
  actionsSection.addWidget(CardService.newButtonSet()
    .addButton(addToCalendarButton)
    .addButton(backButton));
  
  card.addSection(actionsSection);
  
  return card.build();
}

/**
 * Show calendar selection interface
 */
function showCalendarSelection(e) {
  try {
    const events = JSON.parse(e.parameters.events);
    
    // Get user's calendars
    const calendars = getUserCalendars();
    
    const card = CardService.newCardBuilder()
      .setHeader(CardService.newCardHeader()
        .setTitle('Select Calendar')
        .setSubtitle('Choose where to add events'));
    
    const section = CardService.newCardSection()
      .setHeader('📅 Available Calendars');
    
    if (calendars.length === 0) {
      section.addWidget(CardService.newTextParagraph()
        .setText('No calendars found. Please check your Google Calendar access.'));
    } else {
      calendars.forEach(calendar => {
        const calendarButton = CardService.newTextButton()
          .setText(`📅 ${calendar.name}`)
          .setOnClickAction(CardService.newAction()
            .setFunctionName('addEventsToCalendar')
            .setParameters({
              calendarId: calendar.id,
              events: JSON.stringify(events),
              calendarName: calendar.name
            }))
          .setTextButtonStyle(CardService.TextButtonStyle.TEXT);
        
        section.addWidget(calendarButton);
      });
    }
    
    // Back button
    const backButton = CardService.newTextButton()
      .setText('← Back to Events')
      .setOnClickAction(CardService.newAction()
        .setFunctionName('buildGmailAddon'))
      .setTextButtonStyle(CardService.TextButtonStyle.TEXT);
    
    section.addWidget(CardService.newButtonSet()
      .addButton(backButton));
    
    card.addSection(section);
    
    return CardService.newActionResponseBuilder()
      .setNavigation(CardService.newNavigation()
        .updateCard(card.build()))
      .build();
    
  } catch (error) {
    console.error('Error showing calendar selection:', error);
    return buildErrorCard(`Error: ${error.message}`);
  }
}

/**
 * Add events to selected calendar
 */
function addEventsToCalendar(e) {
  try {
    const calendarId = e.parameters.calendarId;
    const calendarName = e.parameters.calendarName;
    const events = JSON.parse(e.parameters.events);
    
    let createdCount = 0;
    let failedCount = 0;
    const results = [];
    
    // Create each event
    events.forEach(eventData => {
      try {
        const event = {
          summary: eventData.title || 'EventAI Event',
          description: eventData.description || 'Created by EventAI Gmail Add-on',
          start: {
            dateTime: eventData.start_date,
            timeZone: eventData.timezone || Session.getScriptTimeZone()
          },
          end: {
            dateTime: eventData.end_date || eventData.start_date,
            timeZone: eventData.timezone || Session.getScriptTimeZone()
          }
        };
        
        if (eventData.location) {
          event.location = eventData.location;
        }
        
        const createdEvent = Calendar.Events.insert(event, calendarId);
        createdCount++;
        results.push({
          title: eventData.title,
          success: true,
          eventId: createdEvent.id
        });
        
      } catch (error) {
        console.error(`Failed to create event: ${eventData.title}`, error);
        failedCount++;
        results.push({
          title: eventData.title,
          success: false,
          error: error.message
        });
      }
    });
    
    // Show results
    const resultsCard = buildResultsCard(createdCount, failedCount, calendarName, results);
    
    return CardService.newActionResponseBuilder()
      .setNavigation(CardService.newNavigation()
        .updateCard(resultsCard))
      .build();
    
  } catch (error) {
    console.error('Error adding events to calendar:', error);
    return buildErrorCard(`Failed to add events: ${error.message}`);
  }
}

/**
 * Build results card after adding events
 */
function buildResultsCard(createdCount, failedCount, calendarName, results) {
  const card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader()
      .setTitle('Events Added')
      .setSubtitle(`${createdCount} successful, ${failedCount} failed`));
  
  // Summary section
  const summarySection = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText(`✅ Successfully added ${createdCount} event(s) to "${calendarName}"`));
  
  if (failedCount > 0) {
    summarySection.addWidget(CardService.newTextParagraph()
      .setText(`❌ Failed to add ${failedCount} event(s)`));
  }
  
  card.addSection(summarySection);
  
  // Results details
  if (results.length > 0) {
    const detailsSection = CardService.newCardSection()
      .setHeader('Details');
    
    results.forEach(result => {
      const status = result.success ? '✅' : '❌';
      detailsSection.addWidget(CardService.newTextParagraph()
        .setText(`${status} ${result.title}`));
    });
    
    card.addSection(detailsSection);
  }
  
  // Action buttons
  const actionsSection = CardService.newCardSection();
  
  const doneButton = CardService.newTextButton()
    .setText('🎉 Done')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('buildGmailAddon'))
    .setTextButtonStyle(CardService.TextButtonStyle.FILLED);
  
  actionsSection.addWidget(CardService.newButtonSet()
    .addButton(doneButton));
  
  card.addSection(actionsSection);
  
  return card.build();
}

/**
 * Build no events found card
 */
function buildNoEventsCard(message) {
  const card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader()
      .setTitle('EventAI')
      .setSubtitle('No events found'));
  
  const section = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText(`📭 ${message}`))
    .addWidget(CardService.newTextParagraph()
      .setText('💡 Try with emails that contain:\n• Meeting invitations\n• Event announcements\n• Appointment confirmations\n• Travel itineraries'));
  
  const backButton = CardService.newTextButton()
    .setText('← Back')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('buildGmailAddon'))
    .setTextButtonStyle(CardService.TextButtonStyle.TEXT);
  
  section.addWidget(CardService.newButtonSet()
    .addButton(backButton));
  
  card.addSection(section);
  
  return card.build();
}

/**
 * Build error card
 */
function buildErrorCard(errorMessage) {
  const card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader()
      .setTitle('EventAI')
      .setSubtitle('Error'));
  
  const section = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText(`❌ ${errorMessage}`))
    .addWidget(CardService.newTextParagraph()
      .setText('Please try again or contact support if the problem persists.'));
  
  const retryButton = CardService.newTextButton()
    .setText('🔄 Retry')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('buildGmailAddon'))
    .setTextButtonStyle(CardService.TextButtonStyle.FILLED);
  
  section.addWidget(CardService.newButtonSet()
    .addButton(retryButton));
  
  card.addSection(section);
  
  return card.build();
}

/**
 * Show settings interface
 */
function showSettings() {
  const card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader()
      .setTitle('EventAI Settings')
      .setSubtitle('Configure preferences'));
  
  const section = CardService.newCardSection()
    .setHeader('⚙️ Configuration')
    .addWidget(CardService.newTextParagraph()
      .setText(`📧 User: ${Session.getActiveUser().getEmail()}`))
    .addWidget(CardService.newTextParagraph()
      .setText(`🕒 Timezone: ${Session.getScriptTimeZone()}`))
    .addWidget(CardService.newTextParagraph()
      .setText(`🔗 API: ${EVENTAI_API_BASE}`));
  
  const backButton = CardService.newTextButton()
    .setText('← Back')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('buildGmailAddon'))
    .setTextButtonStyle(CardService.TextButtonStyle.TEXT);
  
  section.addWidget(CardService.newButtonSet()
    .addButton(backButton));
  
  card.addSection(section);
  
  return CardService.newActionResponseBuilder()
    .setNavigation(CardService.newNavigation()
      .updateCard(card.build()))
    .build();
}

/**
 * Get user's Google Calendars
 */
function getUserCalendars() {
  try {
    const calendarList = Calendar.CalendarList.list();
    const calendars = [];
    
    calendarList.items.forEach(calendar => {
      // Only include calendars where user can create events
      if (calendar.accessRole === 'owner' || calendar.accessRole === 'writer') {
        calendars.push({
          id: calendar.id,
          name: calendar.summary,
          description: calendar.description || '',
          primary: calendar.primary || false,
          backgroundColor: calendar.backgroundColor || '#3F51B5'
        });
      }
    });
    
    // Sort by primary first, then alphabetically
    calendars.sort((a, b) => {
      if (a.primary && !b.primary) return -1;
      if (!a.primary && b.primary) return 1;
      return a.name.localeCompare(b.name);
    });
    
    return calendars;
    
  } catch (error) {
    console.error('Error getting user calendars:', error);
    return [];
  }
}

/**
 * Call EventAI API
 */
function callEventAIAPI(endpoint, payload) {
  try {
    const url = EVENTAI_API_BASE + endpoint;
    
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${EVENTAI_API_KEY}`
      },
      payload: JSON.stringify(payload)
    };
    
    const response = UrlFetchApp.fetch(url, options);
    const responseText = response.getContentText();
    
    if (response.getResponseCode() !== 200) {
      throw new Error(`API error: ${response.getResponseCode()} - ${responseText}`);
    }
    
    return JSON.parse(responseText);
    
  } catch (error) {
    console.error('Error calling EventAI API:', error);
    throw new Error(`Failed to connect to EventAI: ${error.message}`);
  }
}

/**
 * Format event time for display
 */
function formatEventTime(startDate, endDate) {
  try {
    const start = new Date(startDate);
    const end = endDate ? new Date(endDate) : null;
    
    const options = {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    };
    
    let timeString = start.toLocaleDateString('en-US', options);
    
    if (end && end.getTime() !== start.getTime()) {
      const endOptions = {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
      };
      
      // Same day - just show end time
      if (start.toDateString() === end.toDateString()) {
        timeString += ` - ${end.toLocaleDateString('en-US', endOptions)}`;
      } else {
        // Different day - show full end date
        timeString += ` - ${end.toLocaleDateString('en-US', options)}`;
      }
    }
    
    return timeString;
    
  } catch (error) {
    console.error('Error formatting event time:', error);
    return startDate || 'Invalid date';
  }
}

/**
 * Handle compose trigger (for future enhancement)
 */
function extractEventsFromCompose(e) {
  // Future feature: extract events from email being composed
  return buildErrorCard('Compose extraction not yet implemented');
}