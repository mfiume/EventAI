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
    // Create the main card with iOS-style white theme
    var card = CardService.newCardBuilder()
      .setHeader(CardService.newCardHeader()
        .setTitle('EventAI')
        .setSubtitle('AI-Powered Calendar Assistant')
        .setImageUrl('https://eventai.leveluplife.app/api/static/eventai-icon.png')
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
    .setHeader('📅 AI Calendar Event Extraction');
  
  // iOS-style welcome message
  section.addWidget(CardService.newTextParagraph()
    .setText('<font color="#666666">Transform your emails into calendar events instantly using advanced AI technology.</font>'));
  
  // Check if we have access to current email
  console.log('Event object:', JSON.stringify(e));
  if (e && e.messageMetadata) {
    // Extract Events button - iOS style primary button
    var extractButton = CardService.newTextButton()
      .setText('🎯 Extract Events from Email')
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
    // Current email info with iOS styling
    section.addWidget(CardService.newDecoratedText()
      .setTopLabel('Current Email')
      .setText(emailSubject)
      .setStartIcon(CardService.newIconImage().setIcon(CardService.Icon.EMAIL))
      .setWrapText(true));
  } else {
    // No email selected - iOS style empty state
    section.addWidget(CardService.newTextParagraph()
      .setText('<font color="#999999">📧 Please open an email to begin extracting calendar events.</font>'));
  }
  
  // Feature highlights - iOS style
  var featuresSection = CardService.newCardSection()
    .setHeader('✨ What EventAI Can Extract');
  
  featuresSection.addWidget(CardService.newTextParagraph()
    .setText('• Meeting invitations & appointments\n• Event announcements & schedules\n• Travel itineraries & reservations\n• Deadline reminders & tasks'));
  
  section.addWidget(CardService.newDivider());
  
  // Settings button - iOS style secondary
  var settingsButton = CardService.newTextButton()
    .setText('⚙️ Settings & Info')
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
    
    // If email body is empty or failed to decode, try alternative extraction methods
    if (!emailData.body || emailData.body.length < 10 || emailData.body.indexOf('Could not') !== -1) {
      console.log('Email body extraction failed, trying alternative methods');
      console.log('Original body length:', emailData.body ? emailData.body.length : 0);
      
      // Try to get more content from headers and subject
      var alternativeContent = '';
      if (emailData.subject) {
        alternativeContent += 'Subject: ' + emailData.subject + '\n';
      }
      if (emailData.sender) {
        alternativeContent += 'From: ' + emailData.sender + '\n';
      }
      if (emailData.date) {
        alternativeContent += 'Date: ' + emailData.date + '\n';
      }
      
      // If we have some body content, even if short, include it
      if (emailData.body && emailData.body.length > 0 && emailData.body.indexOf('Could not') === -1) {
        alternativeContent += '\nContent: ' + emailData.body;
      } else {
        alternativeContent += '\nNote: Email body could not be decoded - this may be a complex HTML email with rich formatting.';
      }
      
      emailData.body = alternativeContent;
      console.log('Using alternative content:', alternativeContent.substring(0, 200) + '...');
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
      user_email: Session.getActiveUser().getEmail(),
      email_date: emailData.date  // Pass the email date for proper context
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
    // Multi-part message - try all parts to get maximum content
    var plainTextBody = '';
    var htmlBody = '';
    
    for (var i = 0; i < payload.parts.length; i++) {
      var part = payload.parts[i];
      console.log('Processing part ' + i + ': ' + part.mimeType);
      
      if (part.mimeType === 'text/plain' && part.body && part.body.data) {
        try {
          plainTextBody += Utilities.newBlob(Utilities.base64DecodeWebSafe(part.body.data)).getDataAsString();
          console.log('Successfully decoded plain text part, length:', plainTextBody.length);
        } catch (e) {
          console.error('Error decoding plain text:', e);
        }
      } else if (part.mimeType === 'text/html' && part.body && part.body.data) {
        try {
          var htmlContent = Utilities.newBlob(Utilities.base64DecodeWebSafe(part.body.data)).getDataAsString();
          // Better HTML parsing - preserve line breaks and clean up formatting
          var cleanHtml = htmlContent
            .replace(/<br\s*\/?>/gi, '\n')           // Convert <br> to newlines
            .replace(/<\/p>/gi, '\n\n')              // Convert </p> to double newlines  
            .replace(/<\/div>/gi, '\n')              // Convert </div> to newlines
            .replace(/<\/h[1-6]>/gi, '\n')           // Convert headers to newlines
            .replace(/<[^>]*>/g, '')                 // Remove all HTML tags
            .replace(/&nbsp;/gi, ' ')                // Convert &nbsp; to spaces
            .replace(/&amp;/gi, '&')                 // Convert &amp; to &
            .replace(/&lt;/gi, '<')                  // Convert &lt; to <
            .replace(/&gt;/gi, '>')                  // Convert &gt; to >
            .replace(/\n\s*\n\s*\n/g, '\n\n')       // Collapse multiple newlines
            .trim();
          htmlBody += cleanHtml;
          console.log('Successfully decoded HTML part, length:', htmlBody.length);
        } catch (e) {
          console.error('Error decoding HTML:', e);
        }
      } else if (part.parts) {
        // Recursive processing for nested parts
        var nestedBody = extractBodyFromPayload(part);
        if (nestedBody && nestedBody.length > 0) {
          body += nestedBody + '\n';
          console.log('Successfully extracted nested content, length:', nestedBody.length);
        }
      }
    }
    
    // Prefer plain text, but use HTML if plain text is empty or too short
    if (plainTextBody && plainTextBody.length > 20) {
      body = plainTextBody;
      console.log('Using plain text body, length:', body.length);
    } else if (htmlBody && htmlBody.length > 20) {
      body = htmlBody;
      console.log('Using HTML body (converted to text), length:', body.length);
    } else if (plainTextBody) {
      body = plainTextBody;
      console.log('Using short plain text body, length:', body.length);
    } else if (htmlBody) {
      body = htmlBody;
      console.log('Using short HTML body, length:', body.length);
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
      .setTitle('EventAI Results')
      .setSubtitle('Successfully found ' + events.length + ' event(s)')
      .setImageUrl('https://eventai.leveluplife.app/api/static/eventai-icon.png')
      .setImageStyle(CardService.ImageStyle.CIRCLE));
  
  // Success message with iOS styling
  var messageSection = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText('<font color="#34C759">✅ ' + message + '</font>'));
  
  card.addSection(messageSection);
  
  // Events section with iOS-style cards
  var eventsSection = CardService.newCardSection()
    .setHeader('📅 Extracted Events');
  
  events.forEach(function(event, index) {
    // Build bottom label with time, location, and description
    var bottomLabel = formatEventTime(event.start_date, event.end_date);
    if (event.location) {
      bottomLabel += ' • ' + event.location;
    }
    if (event.description) {
      bottomLabel += '\n' + event.description;
    }
    
    var eventWidget = CardService.newDecoratedText()
      .setTopLabel('Event ' + (index + 1))
      .setText('<b>' + (event.title || 'Untitled Event') + '</b>')
      .setBottomLabel(bottomLabel)
      .setStartIcon(CardService.newIconImage().setIcon(CardService.Icon.CLOCK))
      .setWrapText(true);
    
    eventsSection.addWidget(eventWidget);
    
    // Add divider between events (except for last one)
    if (index < events.length - 1) {
      eventsSection.addWidget(CardService.newDivider());
    }
  });
  
  card.addSection(eventsSection);
  
  // Action buttons with iOS-style design
  var actionsSection = CardService.newCardSection();
  
  // Primary action button
  var addToCalendarButton = CardService.newTextButton()
    .setText('📅 Add to My Calendar')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('showCalendarSelection')
      .setParameters({events: JSON.stringify(events)}))
    .setTextButtonStyle(CardService.TextButtonStyle.FILLED);
  
  // Secondary action button  
  var backButton = CardService.newTextButton()
    .setText('← Extract More Events')
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
        .setSubtitle('Choose destination for your events')
        .setImageUrl('https://eventai.leveluplife.app/api/static/eventai-icon.png')
        .setImageStyle(CardService.ImageStyle.CIRCLE));
    
    var section = CardService.newCardSection()
      .setHeader('📅 Available Calendars')
      .addWidget(CardService.newTextParagraph()
        .setText('<font color="#666666">Select which Google Calendar to add your extracted events to:</font>'));
    
    if (calendars.length === 0) {
      section.addWidget(CardService.newTextParagraph()
        .setText('<font color="#FF3B30">❌ No writable calendars found. Please check your Google Calendar permissions.</font>'));
    } else {
      calendars.forEach(function(calendar, index) {
        var calendarIcon = calendar.primary ? CardService.Icon.STAR : CardService.Icon.BOOKMARK;
        var calendarLabel = calendar.primary ? calendar.name + ' (Primary)' : calendar.name;
        
        var calendarWidget = CardService.newDecoratedText()
          .setTopLabel('Calendar ' + (index + 1))
          .setText('<b>' + calendarLabel + '</b>')
          .setStartIcon(CardService.newIconImage().setIcon(calendarIcon))
          .setButton(CardService.newTextButton()
            .setText('Add Here')
            .setOnClickAction(CardService.newAction()
              .setFunctionName('addEventsToCalendar')
              .setParameters({
                calendarId: calendar.id,
                events: JSON.stringify(events),
                calendarName: calendar.name
              }))
            .setTextButtonStyle(CardService.TextButtonStyle.FILLED));
        
        section.addWidget(calendarWidget);
        
        if (index < calendars.length - 1) {
          section.addWidget(CardService.newDivider());
        }
      });
    }
    
    // Back button
    section.addWidget(CardService.newDivider());
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
      .setTitle('Calendar Update Complete')
      .setSubtitle(createdCount + ' events successfully added')
      .setImageUrl('https://eventai.leveluplife.app/api/static/eventai-icon.png')
      .setImageStyle(CardService.ImageStyle.CIRCLE));
  
  // Success summary with iOS styling
  var summarySection = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText('<font color="#34C759"><b>✅ Success!</b></font>'))
    .addWidget(CardService.newTextParagraph()
      .setText('Added <b>' + createdCount + '</b> event(s) to <b>"' + calendarName + '"</b>'));
  
  if (failedCount > 0) {
    summarySection.addWidget(CardService.newTextParagraph()
      .setText('<font color="#FF3B30">❌ ' + failedCount + ' event(s) failed to add</font>'));
  }
  
  card.addSection(summarySection);
  
  // Results details with iOS-style cards
  if (results.length > 0) {
    var detailsSection = CardService.newCardSection()
      .setHeader('📋 Event Details');
    
    results.forEach(function(result, index) {
      var statusColor = result.success ? '#34C759' : '#FF3B30';
      var statusIcon = result.success ? '✅' : '❌';
      var statusText = result.success ? 'Added successfully' : ('Failed: ' + (result.error || 'Unknown error'));
      
      var resultWidget = CardService.newDecoratedText()
        .setTopLabel('Event ' + (index + 1))
        .setText('<b>' + result.title + '</b>')
        .setBottomLabel('<font color="' + statusColor + '">' + statusIcon + ' ' + statusText + '</font>')
        .setStartIcon(CardService.newIconImage().setIcon(CardService.Icon.CLOCK))
        .setWrapText(true);
      
      detailsSection.addWidget(resultWidget);
      
      if (index < results.length - 1) {
        detailsSection.addWidget(CardService.newDivider());
      }
    });
    
    card.addSection(detailsSection);
  }
  
  // Action buttons with iOS styling
  var actionsSection = CardService.newCardSection();
  
  var doneButton = CardService.newTextButton()
    .setText('🎉 Great! Extract More Events')
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
      .setSubtitle('No events detected')
      .setImageUrl('https://eventai.leveluplife.app/api/static/eventai-icon.png')
      .setImageStyle(CardService.ImageStyle.CIRCLE));
  
  var section = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText('<font color="#FF9500">📭 ' + message + '</font>'))
    .addWidget(CardService.newDivider())
    .addWidget(CardService.newTextParagraph()
      .setText('<b>💡 EventAI works best with:</b>'))
    .addWidget(CardService.newTextParagraph()
      .setText('• Meeting invitations & calendar requests\n• Event announcements & schedules\n• Appointment confirmations\n• Travel bookings & itineraries\n• Deadline & reminder emails'));
  
  var backButton = CardService.newTextButton()
    .setText('← Try Another Email')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('buildGmailAddon'))
    .setTextButtonStyle(CardService.TextButtonStyle.FILLED);
  
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
      .setSubtitle('Something went wrong')
      .setImageUrl('https://eventai.leveluplife.app/api/static/eventai-icon.png')
      .setImageStyle(CardService.ImageStyle.CIRCLE));
  
  var section = CardService.newCardSection()
    .addWidget(CardService.newTextParagraph()
      .setText('<font color="#FF3B30">❌ ' + errorMessage + '</font>'))
    .addWidget(CardService.newDivider())
    .addWidget(CardService.newTextParagraph()
      .setText('<font color="#666666">If this issue persists, please contact our support team at support@leveluplife.app</font>'));
  
  var retryButton = CardService.newTextButton()
    .setText('🔄 Try Again')
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
      .setSubtitle('Configuration & Information')
      .setImageUrl('https://eventai.leveluplife.app/api/static/eventai-icon.png')
      .setImageStyle(CardService.ImageStyle.CIRCLE));
  
  // User info section
  var userSection = CardService.newCardSection()
    .setHeader('👤 Account Information')
    .addWidget(CardService.newDecoratedText()
      .setTopLabel('Gmail Account')
      .setText(Session.getActiveUser().getEmail())
      .setStartIcon(CardService.newIconImage().setIcon(CardService.Icon.PERSON)))
    .addWidget(CardService.newDecoratedText()
      .setTopLabel('Timezone')
      .setText(Session.getScriptTimeZone())
      .setStartIcon(CardService.newIconImage().setIcon(CardService.Icon.CLOCK)));
  
  // App info section
  var appSection = CardService.newCardSection()
    .setHeader('ℹ️ Application Information')
    .addWidget(CardService.newTextParagraph()
      .setText('<b>EventAI for Gmail</b>\nVersion 1.0.0'))
    .addWidget(CardService.newTextParagraph()
      .setText('<font color="#666666">Powered by advanced AI technology to transform your emails into actionable calendar events.</font>'))
    .addWidget(CardService.newTextParagraph()
      .setText('🔗 <b>API Endpoint:</b> ' + EVENTAI_API_BASE));
  
  var backButton = CardService.newTextButton()
    .setText('← Back to EventAI')
    .setOnClickAction(CardService.newAction()
      .setFunctionName('buildGmailAddon'))
    .setTextButtonStyle(CardService.TextButtonStyle.TEXT);
  
  appSection.addWidget(CardService.newButtonSet()
    .addButton(backButton));
  
  card.addSection(userSection);
  card.addSection(appSection);
  
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
    console.log('Formatting event time:');
    console.log('- startDate input:', startDate);
    console.log('- endDate input:', endDate);
    
    // Handle ISO date strings more robustly
    var start = parseEventDate(startDate);
    var end = endDate ? parseEventDate(endDate) : null;
    
    console.log('- parsed start:', start);
    console.log('- parsed end:', end);
    
    if (!start || isNaN(start.getTime())) {
      console.error('Invalid start date after parsing:', startDate);
      return startDate || 'Invalid date';
    }
    
    var options = {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
      timeZone: Session.getScriptTimeZone()  // Use user's timezone
    };
    
    var timeString = start.toLocaleDateString('en-US', options);
    console.log('- formatted timeString:', timeString);
    
    if (end && !isNaN(end.getTime()) && end.getTime() !== start.getTime()) {
      var endOptions = {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
        timeZone: Session.getScriptTimeZone()
      };
      
      // Same day - just show end time
      if (start.toDateString() === end.toDateString()) {
        timeString += ' - ' + end.toLocaleDateString('en-US', endOptions);
      } else {
        // Different day - show full end date
        timeString += ' - ' + end.toLocaleDateString('en-US', options);
      }
    }
    
    console.log('- final formatted string:', timeString);
    return timeString;
    
  } catch (error) {
    console.error('Error formatting event time:', error);
    console.error('- startDate was:', startDate);
    console.error('- endDate was:', endDate);
    return startDate || 'Invalid date';
  }
}

/**
 * Parse event date string more robustly
 */
function parseEventDate(dateString) {
  if (!dateString) return null;
  
  try {
    // If it's already a Date object, return it
    if (dateString instanceof Date) {
      return dateString;
    }
    
    // If it's a string, try different parsing approaches
    if (typeof dateString === 'string') {
      // First try direct parsing (works for most ISO strings)
      var date = new Date(dateString);
      if (!isNaN(date.getTime())) {
        return date;
      }
      
      // If that fails, try manual parsing for ISO format
      // Format: "2025-08-21T19:30:00-04:00"
      var isoMatch = dateString.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})([-+]\d{2}:\d{2})?$/);
      if (isoMatch) {
        var year = parseInt(isoMatch[1]);
        var month = parseInt(isoMatch[2]) - 1; // JavaScript months are 0-based
        var day = parseInt(isoMatch[3]);
        var hour = parseInt(isoMatch[4]);
        var minute = parseInt(isoMatch[5]);
        var second = parseInt(isoMatch[6]);
        
        // Create date in UTC then adjust for timezone if needed
        var utcDate = new Date(Date.UTC(year, month, day, hour, minute, second));
        
        // Handle timezone offset if present
        if (isoMatch[7]) {
          var tzOffset = isoMatch[7];
          var offsetHours = parseInt(tzOffset.substring(1, 3));
          var offsetMinutes = parseInt(tzOffset.substring(4, 6));
          var totalOffsetMinutes = offsetHours * 60 + offsetMinutes;
          
          if (tzOffset.startsWith('-')) {
            // For -04:00, we need to ADD 4 hours to get UTC
            utcDate.setUTCMinutes(utcDate.getUTCMinutes() + totalOffsetMinutes);
          } else {
            // For +04:00, we need to SUBTRACT 4 hours to get UTC
            utcDate.setUTCMinutes(utcDate.getUTCMinutes() - totalOffsetMinutes);
          }
        }
        
        return utcDate;
      }
    }
    
    // Fallback - try Date constructor
    return new Date(dateString);
    
  } catch (e) {
    console.error('Error parsing date:', dateString, e);
    return null;
  }
}

/**
 * Handle compose trigger (for future enhancement)
 */
function extractEventsFromCompose(e) {
  // Future feature: extract events from email being composed
  return buildErrorCard('Compose extraction not yet implemented');
}