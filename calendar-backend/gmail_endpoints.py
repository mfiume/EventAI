#!/usr/bin/env python3
"""
Gmail Integration Endpoints for EventAI
FastAPI routes for Gmail Add-on integration
"""

import os
import json
import hashlib
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from fastapi import APIRouter, HTTPException, Request, Depends, Form, Query, status
from fastapi.responses import JSONResponse, RedirectResponse
from pydantic import BaseModel, EmailStr
import logging

from gmail_service import GmailService
from auth_service import require_api_key, APIKeyInfo

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create Gmail router
gmail_router = APIRouter(prefix="/api/gmail", tags=["Gmail Integration"])

# Initialize Gmail service
gmail_service = GmailService()

# Pydantic models for request/response
class EmailExtractionRequest(BaseModel):
    email_content: str
    subject: Optional[str] = ""
    sender: Optional[str] = ""
    timezone: str = "UTC"
    user_email: Optional[str] = None
    email_date: Optional[str] = None  # When the email was sent

class CalendarSelectionRequest(BaseModel):
    calendar_id: str
    events: List[Dict[str, Any]]
    user_email: str
    access_token: str

class GoogleAuthResponse(BaseModel):
    success: bool
    auth_url: Optional[str] = None
    access_token: Optional[str] = None
    user_email: Optional[str] = None
    error: Optional[str] = None

class EventExtractionResponse(BaseModel):
    success: bool
    events_found: int
    events: Optional[List[Dict[str, Any]]] = None
    message: str
    ics_content: Optional[str] = None
    error: Optional[str] = None

class CalendarListResponse(BaseModel):
    success: bool
    calendars: Optional[List[Dict[str, Any]]] = None
    error: Optional[str] = None

# In-memory token storage (in production, use Redis or database)
user_tokens = {}

@gmail_router.get("/oauth/authorize", response_model=GoogleAuthResponse)
async def initiate_google_oauth(
    request: Request, 
    user_email: Optional[str] = Query(None),
    api_key_info: APIKeyInfo = Depends(require_api_key)
):
    """Initiate Google OAuth flow for Gmail integration"""
    try:
        # Generate state parameter for security
        state = hashlib.sha256(f"{user_email}_{datetime.now().isoformat()}".encode()).hexdigest()[:16]
        
        # Get OAuth URL from Gmail service
        auth_url = gmail_service.get_oauth_url(state=state)
        
        # Store state for validation
        if user_email:
            user_tokens[state] = {"user_email": user_email, "timestamp": datetime.now()}
        
        logger.info(f"Generated OAuth URL for user: {user_email}")
        
        return GoogleAuthResponse(
            success=True,
            auth_url=auth_url
        )
        
    except Exception as e:
        logger.error(f"Error initiating OAuth: {e}")
        return GoogleAuthResponse(
            success=False,
            error=f"Failed to initiate authentication: {str(e)}"
        )

@gmail_router.get("/oauth/callback")
async def handle_google_oauth_callback(
    request: Request,
    code: Optional[str] = Query(None),
    state: Optional[str] = Query(None),
    error: Optional[str] = Query(None)
):
    """Handle Google OAuth callback"""
    if error:
        logger.error(f"OAuth error: {error}")
        return JSONResponse(
            status_code=400,
            content={"success": False, "error": f"Authentication failed: {error}"}
        )
    
    if not code:
        return JSONResponse(
            status_code=400,
            content={"success": False, "error": "Authorization code not provided"}
        )
    
    try:
        # Exchange code for tokens
        token_data = gmail_service.exchange_code_for_tokens(code)
        
        # Store tokens (in production, use secure storage)
        user_email = token_data.get("user_email")
        if user_email:
            user_tokens[user_email] = {
                "access_token": token_data["access_token"],
                "refresh_token": token_data["refresh_token"],
                "expires_at": token_data["expires_at"],
                "user_id": token_data["user_id"],
                "user_name": token_data["user_name"],
                "timestamp": datetime.now()
            }
            
            logger.info(f"OAuth successful for user: {user_email}")
        
        # Return success page or redirect
        return JSONResponse(content={
            "success": True,
            "message": "Authentication successful! You can now close this window.",
            "user_email": user_email,
            "access_token": token_data["access_token"][:20] + "..."  # Partial token for verification
        })
        
    except Exception as e:
        logger.error(f"Error in OAuth callback: {e}")
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": f"Authentication failed: {str(e)}"}
        )

@gmail_router.post("/extract", response_model=EventExtractionResponse)
async def extract_events_from_email(
    request: EmailExtractionRequest,
    api_key_info: APIKeyInfo = Depends(require_api_key)
):
    """Extract calendar events from email content using EventAI"""
    try:
        logger.info(f"Processing email extraction for user: {request.user_email}")
        
        # Prepare text for EventAI processing
        email_text = f"""
Email Subject: {request.subject}
From: {request.sender}

{request.email_content}
        """.strip()
        
        # Process the email content using EventAI logic
        result = await convert_email_to_events(
            text=email_text,
            timezone=request.timezone,
            user_location=None,  # Gmail doesn't have location context
            image=None,
            email_date=request.email_date
        )
        
        logger.info(f"EventAI processing complete. Found {result.get('eventsFound', 0)} events")
        
        return EventExtractionResponse(
            success=True,
            events_found=result.get("eventsFound", 0),
            events=result.get("events", []),
            message=result.get("message", "Processing complete"),
            ics_content=result.get("icsContent", "")
        )
        
    except Exception as e:
        logger.error(f"Error extracting events from email: {e}")
        return EventExtractionResponse(
            success=False,
            events_found=0,
            message="Failed to process email",
            error=str(e)
        )

@gmail_router.get("/calendars", response_model=CalendarListResponse)
async def list_user_calendars(
    user_email: str = Query(...), 
    access_token: str = Query(...),
    api_key_info: APIKeyInfo = Depends(require_api_key)
):
    """List user's Google Calendars"""
    try:
        # Create credentials from token
        credentials = gmail_service.create_credentials_from_token(access_token)
        
        # Get user's calendars
        calendars = gmail_service.list_calendars(credentials)
        
        logger.info(f"Retrieved {len(calendars)} calendars for user: {user_email}")
        
        return CalendarListResponse(
            success=True,
            calendars=calendars
        )
        
    except Exception as e:
        logger.error(f"Error listing calendars: {e}")
        return CalendarListResponse(
            success=False,
            error=f"Failed to retrieve calendars: {str(e)}"
        )

@gmail_router.post("/events/create")
async def create_calendar_events(
    request: CalendarSelectionRequest,
    api_key_info: APIKeyInfo = Depends(require_api_key)
):
    """Create events in user's Google Calendar"""
    try:
        # Create credentials from token
        credentials = gmail_service.create_credentials_from_token(request.access_token)
        
        created_events = []
        failed_events = []
        
        # Create each event
        for event in request.events:
            try:
                result = gmail_service.create_calendar_event(
                    credentials=credentials,
                    calendar_id=request.calendar_id,
                    event_data=event
                )
                
                if result.get("success"):
                    created_events.append({
                        "title": event.get("title", "Untitled Event"),
                        "event_id": result["event_id"],
                        "event_url": result.get("event_url", "")
                    })
                else:
                    failed_events.append({
                        "title": event.get("title", "Untitled Event"),
                        "error": result.get("error", "Unknown error")
                    })
                    
            except Exception as e:
                failed_events.append({
                    "title": event.get("title", "Untitled Event"),
                    "error": str(e)
                })
        
        logger.info(f"Created {len(created_events)} events, {len(failed_events)} failed for user: {request.user_email}")
        
        return {
            "success": len(created_events) > 0,
            "created_events": created_events,
            "failed_events": failed_events,
            "total_created": len(created_events),
            "total_failed": len(failed_events),
            "message": f"Successfully created {len(created_events)} of {len(request.events)} events"
        }
        
    except Exception as e:
        logger.error(f"Error creating calendar events: {e}")
        return {
            "success": False,
            "error": f"Failed to create events: {str(e)}",
            "created_events": [],
            "failed_events": [],
            "total_created": 0,
            "total_failed": len(request.events)
        }

@gmail_router.get("/email/{message_id}")
async def get_email_content(
    message_id: str,
    user_email: str = Query(...),
    access_token: str = Query(...),
    api_key_info: APIKeyInfo = Depends(require_api_key)
):
    """Get email content from Gmail (for debugging/testing)"""
    try:
        # Create credentials from token
        credentials = gmail_service.create_credentials_from_token(access_token)
        
        # Get email content
        email_data = gmail_service.get_email_content(credentials, message_id)
        
        if email_data.get("success"):
            logger.info(f"Retrieved email {message_id} for user: {user_email}")
            return email_data
        else:
            raise HTTPException(
                status_code=400,
                detail=email_data.get("error", "Failed to retrieve email")
            )
        
    except Exception as e:
        logger.error(f"Error getting email content: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to retrieve email: {str(e)}"
        )

@gmail_router.get("/health")
async def gmail_health_check():
    """Health check for Gmail integration"""
    return {
        "status": "healthy",
        "service": "EventAI Gmail Integration",
        "version": "1.0.0",
        "oauth_configured": bool(gmail_service.client_id and gmail_service.client_secret),
        "timestamp": datetime.now().isoformat()
    }

# Helper function to convert email to events
async def convert_email_to_events(text: str, timezone: str, user_location: Optional[str], image, email_date: Optional[str] = None) -> Dict[str, Any]:
    """Convert email content to calendar events using EventAI logic"""
    try:
        # We'll implement the actual conversion using the same logic as the main convert endpoint
        # For now, let's create a simplified version that calls the Anthropic API directly
        
        anthropic_api_key = os.getenv("ANTHROPIC_API_KEY")
        if not anthropic_api_key:
            raise ValueError("Anthropic API key not configured")
        
        # Get current date for context
        from datetime import datetime, timedelta
        import pytz
        from dateutil import parser
        
        # Get current date in the user's timezone
        user_tz = pytz.timezone(timezone)
        current_date = datetime.now(user_tz).strftime("%Y-%m-%d")
        current_day = datetime.now(user_tz).strftime("%A, %B %d, %Y")
        
        # Parse email date and use it as reference point
        email_date_context = ""
        email_reference_date = current_date  # Default to today
        email_reference_day = current_day
        
        if email_date:
            try:
                # Parse the email date and convert to user's timezone
                email_dt = parser.parse(email_date)
                if email_dt.tzinfo is None:
                    email_dt = email_dt.replace(tzinfo=pytz.UTC)
                email_dt_user_tz = email_dt.astimezone(user_tz)
                email_reference_date = email_dt_user_tz.strftime("%Y-%m-%d")
                email_reference_day = email_dt_user_tz.strftime("%A, %B %d, %Y")
                email_date_context = f"Email was sent on: {email_reference_day}"
            except:
                # If parsing fails, use current date
                email_date_context = "Email date could not be parsed, using current date as reference"
        else:
            # No email date provided, assume recent
            email_date_context = "Email date not provided, assuming recent email"
        
        # Prepare the prompt for Claude  
        prompt = f"""
Please analyze the following email content and extract any calendar events, meetings, appointments, or time-based commitments.

CONTEXT FOR DATE INTERPRETATION:
- Today's actual date is: {current_day} ({current_date}) 
- {email_date_context}
- Email reference date for "tomorrow", "next week", etc: {email_reference_day} ({email_reference_date})

CRITICAL INSTRUCTIONS:
1. If this is an old email (email date is before today), calculate relative dates FROM THE EMAIL DATE, not from today
2. "Tomorrow" in the email means the day after {email_reference_date} (which would be {(datetime.strptime(email_reference_date, '%Y-%m-%d') + timedelta(days=1)).strftime('%Y-%m-%d')})
3. All events should be interpreted relative to when the email was sent
4. Use the year {datetime.strptime(email_reference_date, '%Y-%m-%d').year} for events unless explicitly specified otherwise

Email Content:
{text}

For each event found, provide:
- Title (concise but descriptive)  
- Start date and time in ISO format (use timezone: {timezone})
- End date and time in ISO format (estimate duration if not specified)
- Location (if mentioned)
- Description (brief)
- Whether it's recurring (true/false)

REMEMBER: Use {email_reference_date} as the base date for all relative date calculations!

Output in this exact JSON format:
{{
  "events": [
    {{
      "title": "Event Title",
      "start_date": "2025-08-13T10:00:00-04:00",
      "end_date": "2025-08-13T11:00:00-04:00",
      "description": "Event description",
      "location": "Event location",
      "is_recurring": false,
      "timezone": "{timezone}"
    }}
  ]
}}
"""

        # Call Anthropic API
        anthropic_api_url = "https://api.anthropic.com/v1/messages"
        headers = {
            'Content-Type': 'application/json',
            'x-api-key': anthropic_api_key,
            'anthropic-version': '2023-06-01'
        }
        
        # Configure model and tokens
        model = os.getenv("CLAUDE_MODEL", "claude-3-5-sonnet-20241022")
        max_tokens = int(os.getenv("CLAUDE_MAX_TOKENS", "2000"))
        
        payload = {
            "model": model,
            "max_tokens": max_tokens,
            "temperature": 0.1,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        }
        
        response = requests.post(anthropic_api_url, headers=headers, json=payload, timeout=30)
        response_data = response.json()
        
        if response.status_code != 200:
            raise Exception(f"Anthropic API error: {response.status_code} - {response_data}")
        
        # Extract the response content
        content = response_data.get('content', [{}])[0].get('text', '')
        
        # Parse the JSON response from Claude
        try:
            # Extract JSON from the response
            import re
            json_match = re.search(r'\{.*\}', content, re.DOTALL)
            if json_match:
                events_data = json.loads(json_match.group())
                events = events_data.get('events', [])
            else:
                events = []
        except:
            events = []
        
        # Generate ICS content
        ics_content = generate_ics_content(events)
        
        return {
            "eventsFound": len(events),
            "events": events,
            "message": f"Successfully extracted {len(events)} event(s) from email" if events else "No events found in email",
            "icsContent": ics_content
        }
        
    except Exception as e:
        logger.error(f"Error converting email to events: {e}")
        return {
            "eventsFound": 0,
            "events": [],
            "message": f"Error processing email: {str(e)}",
            "icsContent": ""
        }

def generate_ics_content(events: List[Dict[str, Any]]) -> str:
    """Generate ICS calendar content from events"""
    from icalendar import Calendar, Event as ICSEvent
    import uuid
    from datetime import datetime
    
    cal = Calendar()
    cal.add('prodid', '-//EventAI//Gmail Integration//EN')
    cal.add('version', '2.0')
    
    for event_data in events:
        event = ICSEvent()
        event.add('uid', str(uuid.uuid4()))
        event.add('summary', event_data.get('title', 'Untitled Event'))
        event.add('description', event_data.get('description', ''))
        
        # Parse dates
        try:
            start_date = datetime.fromisoformat(event_data.get('start_date', '').replace('Z', '+00:00'))
            event.add('dtstart', start_date)
            
            if event_data.get('end_date'):
                end_date = datetime.fromisoformat(event_data.get('end_date', '').replace('Z', '+00:00'))
                event.add('dtend', end_date)
        except:
            # Fallback to current time if parsing fails
            now = datetime.now()
            event.add('dtstart', now)
            event.add('dtend', now)
        
        if event_data.get('location'):
            event.add('location', event_data['location'])
        
        cal.add_component(event)
    
    return cal.to_ical().decode('utf-8')