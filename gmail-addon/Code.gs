/**
 * EventAI Gmail Add-on
 * Extract calendar events from emails using AI
 */

// EventAI API Configuration
var EVENTAI_API_BASE = 'https://eventai.leveluplife.app/api';
var EVENTAI_API_KEY = 'eak_ef662640876f80ec5d7519c16bf14c667d1be3fe8c84a60f68b4da0e914b70ab'; // Gmail Add-on specific key

/**
 * Build the Gmail add-on main interface
 */
function buildGmailAddon(e) {
  console.log('Building Gmail addon interface');
  
  try {
    // Create the main card
    var card = CardService.newCardBuilder()
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
  var section = CardService.newCardSection()
    .setHeader('📅 Extract Calendar Events');
  
  // Check if we have access to current email
  console.log('Event object:', JSON.stringify(e));
  if (e && e.messageMetadata) {
    // Extract Events button
    var extractButton = CardService.newTextButton()
      .setText('🚀 Extract Events from this Email')
      .setOnClickAction(CardService.newAction()
        .setFunctionName('extractEventsFromCurrentEmail')
        .setParameters({messageId: e.messageMetadata.messageId}))
      .setTextButtonStyle(CardService.TextButtonStyle.FILLED);
    
    section.addWidget(CardService.newButtonSet()
      .addButton(extractButton));
    
    // Email info - try different ways to get subject
    var emailSubject = 'No subject';
    if (e.messageMetadata) {
      console.log('messageMetadata:', JSON.stringify(e.messageMetadata));
      emailSubject = e.messageMetadata.subject || 
                    e.messageMetadata.Subject || 
                    (e.gmail && e.gmail.subject) ||
                    'No subject available';
    }
    section.addWidget(CardService.newTextParagraph()
      .setText('📧 Current email: ' + emailSubject));
  } else {
    // No email selected
    section.addWidget(CardService.newTextParagraph()
      .setText('📧 Open an email to extract calendar events from it.'));
  }
  
  // Instructions
  section.addWidget(CardService.newTextParagraph()
    .setText('💡 EventAI will analyze your email content and extract any meetings, appointments, or events it finds.'));
  
  // Settings button
  var settingsButton = CardService.newTextButton()
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
    var messageId = e.parameters.messageId;
    if (!messageId) {
      return buildErrorCard('No email selected. Please open an email first.');
    }
    
    // Get email content
    var emailData = getEmailContent(messageId);
    if (!emailData.success) {
      return buildErrorCard('Failed to read email: ' + emailData.error);
    }
    
    // If email body is empty or failed to decode, use subject and basic info
    if (!emailData.body || emailData.body.length < 10 || emailData.body.indexOf('Could not') !== -1) {
      console.log('Email body extraction failed, using subject and sender info');
      emailData.body = 'Email from ' + emailData.sender + ' with subject: ' + emailData.subject;
    }
    
    // Process email content directly (synchronous)
    return processEmailForEvents(emailData, messageId);
    
  } catch (error) {
    console.error('Error extracting events:', error);
    return buildErrorCard('Error: ' + error.message);
  }
}

/**
 * Process email content for events
 */
function processEmailForEvents(emailData, messageId) {
  try {
    // Get user's timezone
    var userTimezone = Session.getScriptTimeZone();
    
    // Prepare email content for EventAI
    var emailText = 'Subject: ' + emailData.subject + '\nFrom: ' + emailData.sender + '\n\n' + emailData.body;
    
    // Call EventAI API
    var response = callEventAIAPI('/gmail/extract', {
      email_content: emailData.body,
      subject: emailData.subject,
      sender: emailData.sender,
      timezone: userTimezone,
      user_email: Session.getActiveUser().getEmail()
    });
    
    if (response.success && response.events_found > 0) {
      // Show events preview
      var eventsCard = buildEventsPreviewCard(response.events, response.message);
      
      // Update the card
      return CardService.newActionResponseBuilder()
        .setNavigation(CardService.newNavigation()
          .updateCard(eventsCard))
        .build();
    } else {
      // No events found
      var noEventsCard = buildNoEventsCard(response.message || 'No events found in this email.');
      
      return CardService.newActionResponseBuilder()
        .setNavigation(CardService.newNavigation()
          .updateCard(noEventsCard))
        .build();
    }
    
  } catch (error) {
    console.error('Error processing email for events:', error);
    var errorCard = buildErrorCard('Processing failed: ' + error.message);
    
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
    console.log('=== EMAIL CONTENT EXTRACTION DEBUG ===');
    console.log('Message ID:', messageId);
    
    var message = Gmail.Users.Messages.get('me', messageId, {'format': 'full'});
    console.log('Full message object structure:');
    console.log('- message.payload type:', typeof message.payload);
    console.log('- message.payload.headers length:', (message.payload.headers || []).length);
    console.log('- message.payload.parts:', !!message.payload.parts);
    console.log('- message.payload.body:', !!message.payload.body);
    console.log('- message.payload.mimeType:', message.payload.mimeType);
    
    var headers = message.payload.headers || [];
    var subject = '';
    var sender = '';
    var date = '';
    
    // Extract headers
    headers.forEach(function(header) {
      var name = header.name.toLowerCase();
      if (name === 'subject') subject = header.value;
      if (name === 'from') sender = header.value;
      if (name === 'date') date = header.value;
    });
    
    console.log('Extracted headers:');
    console.log('- Subject:', subject);
    console.log('- Sender:', sender);
    console.log('- Date:', date);
    
    // Extract body content
    var body = extractBodyFromPayload(message.payload);
    
    console.log('Final extracted body:');
    console.log('- Body length:', body ? body.length : 0);
    console.log('- Body preview:', body ? body.substring(0, 100) + '...' : 'EMPTY');
    console.log('=== END EMAIL DEBUG ===');
    
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
  console.log('=== PAYLOAD EXTRACTION DEBUG ===');
  var body = '';
  
  // Handle case where payload is null or undefined
  if (!payload) {
    console.log('Payload is null or undefined');
    return 'No email content available';
  }
  
  console.log('Payload structure:');
  console.log('- payload.mimeType:', payload.mimeType);
  console.log('- payload.parts exists:', !!payload.parts);
  console.log('- payload.body exists:', !!payload.body);
  if (payload.parts) {
    console.log('- payload.parts length:', payload.parts.length);
  }
  if (payload.body) {
    console.log('- payload.body.data exists:', !!payload.body.data);
    console.log('- payload.body.size:', payload.body.size);
  }
  
  if (payload.parts) {
    // Multi-part message
    for (var i = 0; i < payload.parts.length; i++) {
      var part = payload.parts[i];
      if (part.mimeType === 'text/plain' && part.body.data) {
        try {
          body += Utilities.newBlob(Utilities.base64DecodeWebSafe(part.body.data)).getDataAsString();
        } catch (e) {
          console.error('Error decoding plain text:', e);
        }
      } else if (part.mimeType === 'text/html' && part.body.data && !body) {
        // Fallback to HTML if no plain text
        try {
          var htmlContent = Utilities.newBlob(Utilities.base64DecodeWebSafe(part.body.data)).getDataAsString();
          body += htmlContent.replace(/<[^>]*>/g, ''); // Simple HTML tag removal
        } catch (e) {
          console.error('Error decoding HTML:', e);
        }
      }
    }
  } else if (payload.body && payload.body.data) {
    console.log('Processing single part message:');
    console.log('- payload.body.data type:', typeof payload.body.data);
    console.log('- payload.body.data length:', payload.body.data ? payload.body.data.length : 0);
    
    // Single part message
    try {
      console.log('Trying base64DecodeWebSafe...');
      // Try web-safe base64 decode first
      body = Utilities.newBlob(Utilities.base64DecodeWebSafe(payload.body.data)).getDataAsString();
      console.log('WebSafe decode SUCCESS, body type:', typeof body, 'length:', body.length);
    } catch (e) {
      console.error('Error decoding single part message:', e);
      try {
        console.log('Trying standard base64Decode...');
        // Try standard base64 decode
        body = Utilities.newBlob(Utilities.base64Decode(payload.body.data)).getDataAsString();
        console.log('Standard decode SUCCESS, body type:', typeof body, 'length:', body.length);
      } catch (e2) {
        console.error('Error with standard base64 decode:', e2);
        console.log('Using fallback approach...');
        // Last resort: try to get plain text from payload
        if (payload.mimeType === 'text/plain') {
          body = payload.body.data || 'Could not extract email content';
        } else {
          body = 'Could not decode email content - please try with a different email';
        }
        console.log('Fallback result, body type:', typeof body);
      }
    }
  } else {
    console.log('No usable body data found');
    body = 'No email content available';
  }
  
  console.log('Extraction complete:');
  console.log('- Final body type:', typeof body);
  console.log('- Final body length:', body ? body.length : 0);
  console.log('- Body preview:', (typeof body === 'string') ? body.substring(0, 50) : 'NOT_STRING: ' + body);
  console.log('=== END PAYLOAD DEBUG ===');
  
  // Ensure body is always a string before calling trim
  if (typeof body !== 'string') {
    console.log('Converting body to string, was:', typeof body);
    body = String(body || '');
  }
  return body.trim();
}

/**
 * Build events preview card
 */
function buildEventsPreviewCard(events, message) {
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader()
      .setTitle('EventAI')
      .setSubtitle('Found ' + events.length + ' event(s)'));
  
  // Message section
  var messageSection = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText('✅ ' + message));
  
  card.addSection(messageSection);
  
  // Events section
  var eventsSection = CardService.newCardSection()
    .setHeader('📅 Extracted Events');
  
  events.forEach(function(event, index) {
    var eventWidget = CardService.newDecoratedText()
      .setTopLabel('Event ' + (index + 1))
      .setText(event.title || 'Untitled Event')
      .setBottomLabel(formatEventTime(event.start_date, event.end_date))
      .setWrapText(true);
    
    if (event.location) {
      eventWidget.setBottomLabel(formatEventTime(event.start_date, event.end_date) + ' • ' + event.location);
    }
    
    eventsSection.addWidget(eventWidget);
  });
  
  card.addSection(eventsSection);
  
  // Action buttons
  var actionsSection = CardService.newCardSection();
  
  var addToCalendarButton = CardService.newTextButton()
    .setText('📅 Add to Google Calendar')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('showCalendarSelection')
      .setParameters({events: JSON.stringify(events)}))
    .setTextButtonStyle(CardService.TextButtonStyle.FILLED);
  
  var backButton = CardService.newTextButton()
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
    var events = JSON.parse(e.parameters.events);
    
    // Get user's calendars
    var calendars = getUserCalendars();
    
    var card = CardService.newCardBuilder()
      .setHeader(CardService.newCardHeader()
        .setTitle('Select Calendar')
        .setSubtitle('Choose where to add events'));
    
    var section = CardService.newCardSection()
      .setHeader('📅 Available Calendars');
    
    if (calendars.length === 0) {
      section.addWidget(CardService.newTextParagraph()
        .setText('No calendars found. Please check your Google Calendar access.'));
    } else {
      calendars.forEach(function(calendar) {
        var calendarButton = CardService.newTextButton()
          .setText('📅 ' + calendar.name)
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
    var backButton = CardService.newTextButton()
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
    return buildErrorCard('Error: ' + error.message);
  }
}

/**
 * Add events to selected calendar
 */
function addEventsToCalendar(e) {
  try {
    var calendarId = e.parameters.calendarId;
    var calendarName = e.parameters.calendarName;
    var events = JSON.parse(e.parameters.events);
    
    var createdCount = 0;
    var failedCount = 0;
    var results = [];
    
    // Create each event
    events.forEach(function(eventData) {
      try {
        var event = {
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
        
        var createdEvent = Calendar.Events.insert(event, calendarId);
        createdCount++;
        results.push({
          title: eventData.title,
          success: true,
          eventId: createdEvent.id
        });
        
      } catch (error) {
        console.error('Failed to create event: ' + eventData.title, error);
        failedCount++;
        results.push({
          title: eventData.title,
          success: false,
          error: error.message
        });
      }
    });
    
    // Show results
    var resultsCard = buildResultsCard(createdCount, failedCount, calendarName, results);
    
    return CardService.newActionResponseBuilder()
      .setNavigation(CardService.newNavigation()
        .updateCard(resultsCard))
      .build();
    
  } catch (error) {
    console.error('Error adding events to calendar:', error);
    return buildErrorCard('Failed to add events: ' + error.message);
  }
}

/**
 * Build results card after adding events
 */
function buildResultsCard(createdCount, failedCount, calendarName, results) {
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader()
      .setTitle('Events Added')
      .setSubtitle(createdCount + ' successful, ' + failedCount + ' failed'));
  
  // Summary section
  var summarySection = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText('✅ Successfully added ' + createdCount + ' event(s) to "' + calendarName + '"'));
  
  if (failedCount > 0) {
    summarySection.addWidget(CardService.newTextParagraph()
      .setText('❌ Failed to add ' + failedCount + ' event(s)'));
  }
  
  card.addSection(summarySection);
  
  // Results details
  if (results.length > 0) {
    var detailsSection = CardService.newCardSection()
      .setHeader('Details');
    
    results.forEach(function(result) {
      var status = result.success ? '✅' : '❌';
      detailsSection.addWidget(CardService.newTextParagraph()
        .setText(status + ' ' + result.title));
    });
    
    card.addSection(detailsSection);
  }
  
  // Action buttons
  var actionsSection = CardService.newCardSection();
  
  var doneButton = CardService.newTextButton()
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
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader()
      .setTitle('EventAI')
      .setSubtitle('No events found'));
  
  var section = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText('📭 ' + message))
    .addWidget(CardService.newTextParagraph()
      .setText('💡 Try with emails that contain:\n• Meeting invitations\n• Event announcements\n• Appointment confirmations\n• Travel itineraries'));
  
  var backButton = CardService.newTextButton()
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
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader()
      .setTitle('EventAI')
      .setSubtitle('Error'));
  
  var section = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText('❌ ' + errorMessage))
    .addWidget(CardService.newTextParagraph()
      .setText('Please try again or contact support if the problem persists.'));
  
  var retryButton = CardService.newTextButton()
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
  var card = CardService.newCardBuilder()
    .setHeader(CardService.newCardHeader()
      .setTitle('EventAI Settings')
      .setSubtitle('Configure preferences'));
  
  var section = CardService.newCardSection()
    .setHeader('⚙️ Configuration')
    .addWidget(CardService.newTextParagraph()
      .setText('📧 User: ' + Session.getActiveUser().getEmail()))
    .addWidget(CardService.newTextParagraph()
      .setText('🕒 Timezone: ' + Session.getScriptTimeZone()))
    .addWidget(CardService.newTextParagraph()
      .setText('🔗 API: ' + EVENTAI_API_BASE));
  
  var backButton = CardService.newTextButton()
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
    var calendarList = Calendar.CalendarList.list();
    var calendars = [];
    
    calendarList.items.forEach(function(calendar) {
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
    calendars.sort(function(a, b) {
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
    var url = EVENTAI_API_BASE + endpoint;
    
    var options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + EVENTAI_API_KEY
      },
      payload: JSON.stringify(payload)
    };
    
    var response = UrlFetchApp.fetch(url, options);
    var responseText = response.getContentText();
    
    if (response.getResponseCode() !== 200) {
      throw new Error('API error: ' + response.getResponseCode() + ' - ' + responseText);
    }
    
    return JSON.parse(responseText);
    
  } catch (error) {
    console.error('Error calling EventAI API:', error);
    throw new Error('Failed to connect to EventAI: ' + error.message);
  }
}

/**
 * Format event time for display
 */
function formatEventTime(startDate, endDate) {
  try {
    var start = new Date(startDate);
    var end = endDate ? new Date(endDate) : null;
    
    var options = {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    };
    
    var timeString = start.toLocaleDateString('en-US', options);
    
    if (end && end.getTime() !== start.getTime()) {
      var endOptions = {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
      };
      
      // Same day - just show end time
      if (start.toDateString() === end.toDateString()) {
        timeString += ' - ' + end.toLocaleDateString('en-US', endOptions);
      } else {
        // Different day - show full end date
        timeString += ' - ' + end.toLocaleDateString('en-US', options);
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