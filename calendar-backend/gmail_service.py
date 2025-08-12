#!/usr/bin/env python3
"""
Gmail Integration Service for EventAI
Handles Google OAuth, Gmail API, and Google Calendar integration
"""

import os
import json
import hashlib
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
import requests
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import Flow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GmailService:
    """Service for handling Gmail and Google Calendar integration"""
    
    def __init__(self):
        self.client_id = os.getenv("GOOGLE_CLIENT_ID")
        self.client_secret = os.getenv("GOOGLE_CLIENT_SECRET")
        self.redirect_uri = os.getenv("GOOGLE_REDIRECT_URI", "https://eventai-api-661796696046.us-central1.run.app/api/gmail/oauth/callback")
        
        if not self.client_id or not self.client_secret:
            logger.warning("Google OAuth credentials not configured")
        
        # OAuth scopes needed for Gmail and Calendar access
        self.scopes = [
            'https://www.googleapis.com/auth/gmail.readonly',
            'https://www.googleapis.com/auth/calendar',
            'https://www.googleapis.com/auth/userinfo.email'
        ]
    
    def get_oauth_url(self, state: str = None) -> str:
        """Generate Google OAuth authorization URL"""
        if not self.client_id:
            raise ValueError("Google OAuth not configured")
        
        flow = Flow.from_client_config(
            {
                "web": {
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                    "redirect_uris": [self.redirect_uri]
                }
            },
            scopes=self.scopes
        )
        flow.redirect_uri = self.redirect_uri
        
        authorization_url, _ = flow.authorization_url(
            access_type='offline',
            include_granted_scopes='true',
            state=state
        )
        
        return authorization_url
    
    def exchange_code_for_tokens(self, authorization_code: str) -> Dict[str, Any]:
        """Exchange authorization code for access tokens"""
        if not self.client_id:
            raise ValueError("Google OAuth not configured")
        
        flow = Flow.from_client_config(
            {
                "web": {
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                    "redirect_uris": [self.redirect_uri]
                }
            },
            scopes=self.scopes
        )
        flow.redirect_uri = self.redirect_uri
        
        # Exchange code for tokens
        flow.fetch_token(code=authorization_code)
        
        # Get user info
        credentials = flow.credentials
        user_info = self.get_user_info(credentials)
        
        return {
            "access_token": credentials.token,
            "refresh_token": credentials.refresh_token,
            "expires_at": credentials.expiry.timestamp() if credentials.expiry else None,
            "user_email": user_info.get("email"),
            "user_id": user_info.get("id"),
            "user_name": user_info.get("name")
        }
    
    def refresh_access_token(self, refresh_token: str) -> Dict[str, Any]:
        """Refresh access token using refresh token"""
        credentials = Credentials(
            token=None,
            refresh_token=refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=self.client_id,
            client_secret=self.client_secret
        )
        
        request = Request()
        credentials.refresh(request)
        
        return {
            "access_token": credentials.token,
            "expires_at": credentials.expiry.timestamp() if credentials.expiry else None
        }
    
    def get_user_info(self, credentials: Credentials) -> Dict[str, Any]:
        """Get user information from Google"""
        try:
            service = build('oauth2', 'v2', credentials=credentials)
            user_info = service.userinfo().get().execute()
            return user_info
        except HttpError as e:
            logger.error(f"Error getting user info: {e}")
            return {}
    
    def get_email_content(self, credentials: Credentials, message_id: str) -> Dict[str, Any]:
        """Extract email content from Gmail"""
        try:
            service = build('gmail', 'v1', credentials=credentials)
            
            # Get the email message
            message = service.users().messages().get(
                userId='me', 
                id=message_id,
                format='full'
            ).execute()
            
            # Extract email content
            email_data = self._parse_email_message(message)
            
            return {
                "success": True,
                "subject": email_data.get("subject", ""),
                "body": email_data.get("body", ""),
                "sender": email_data.get("sender", ""),
                "date": email_data.get("date", ""),
                "message_id": message_id
            }
            
        except HttpError as e:
            logger.error(f"Error getting email content: {e}")
            return {
                "success": False,
                "error": f"Failed to access email: {str(e)}"
            }
    
    def _parse_email_message(self, message: Dict) -> Dict[str, str]:
        """Parse Gmail message to extract readable content"""
        headers = message['payload'].get('headers', [])
        
        # Extract headers
        subject = ""
        sender = ""
        date = ""
        
        for header in headers:
            name = header.get('name', '').lower()
            value = header.get('value', '')
            
            if name == 'subject':
                subject = value
            elif name == 'from':
                sender = value
            elif name == 'date':
                date = value
        
        # Extract body content
        body = self._extract_body_from_payload(message['payload'])
        
        return {
            "subject": subject,
            "body": body,
            "sender": sender,
            "date": date
        }
    
    def _extract_body_from_payload(self, payload: Dict) -> str:
        """Extract text content from email payload"""
        body = ""
        
        # Handle different payload structures
        if 'parts' in payload:
            # Multi-part message
            for part in payload['parts']:
                if part.get('mimeType') == 'text/plain':
                    if 'data' in part.get('body', {}):
                        import base64
                        body += base64.urlsafe_b64decode(
                            part['body']['data'].encode('utf-8')
                        ).decode('utf-8')
                elif part.get('mimeType') == 'text/html' and not body:
                    # Fallback to HTML if no plain text
                    if 'data' in part.get('body', {}):
                        import base64
                        html_content = base64.urlsafe_b64decode(
                            part['body']['data'].encode('utf-8')
                        ).decode('utf-8')
                        # Simple HTML to text conversion
                        from html import unescape
                        import re
                        text_content = re.sub('<[^<]+?>', '', html_content)
                        body += unescape(text_content)
        else:
            # Single part message
            if payload.get('mimeType') == 'text/plain':
                if 'data' in payload.get('body', {}):
                    import base64
                    body = base64.urlsafe_b64decode(
                        payload['body']['data'].encode('utf-8')
                    ).decode('utf-8')
        
        return body.strip()
    
    def list_calendars(self, credentials: Credentials) -> List[Dict[str, Any]]:
        """List user's Google Calendars"""
        try:
            service = build('calendar', 'v3', credentials=credentials)
            
            calendar_list = service.calendarList().list().execute()
            calendars = []
            
            for calendar_item in calendar_list.get('items', []):
                calendars.append({
                    "id": calendar_item['id'],
                    "name": calendar_item['summary'],
                    "description": calendar_item.get('description', ''),
                    "primary": calendar_item.get('primary', False),
                    "access_role": calendar_item.get('accessRole', ''),
                    "background_color": calendar_item.get('backgroundColor', '#3F51B5'),
                    "foreground_color": calendar_item.get('foregroundColor', '#FFFFFF')
                })
            
            return calendars
            
        except HttpError as e:
            logger.error(f"Error listing calendars: {e}")
            return []
    
    def create_calendar_event(self, credentials: Credentials, calendar_id: str, event_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create an event in Google Calendar"""
        try:
            service = build('calendar', 'v3', credentials=credentials)
            
            # Format event for Google Calendar API
            google_event = {
                'summary': event_data.get('title', 'EventAI Event'),
                'description': event_data.get('description', ''),
                'start': {
                    'dateTime': event_data.get('start_date'),
                    'timeZone': event_data.get('timezone', 'UTC'),
                },
                'end': {
                    'dateTime': event_data.get('end_date', event_data.get('start_date')),
                    'timeZone': event_data.get('timezone', 'UTC'),
                }
            }
            
            # Add location if provided
            if event_data.get('location'):
                google_event['location'] = event_data['location']
            
            # Add recurrence if provided
            if event_data.get('is_recurring') and event_data.get('recurrence_pattern'):
                google_event['recurrence'] = [f"RRULE:{event_data['recurrence_pattern']}"]
            
            # Create the event
            event = service.events().insert(calendarId=calendar_id, body=google_event).execute()
            
            return {
                "success": True,
                "event_id": event['id'],
                "event_url": event.get('htmlLink', ''),
                "created": event.get('created', '')
            }
            
        except HttpError as e:
            logger.error(f"Error creating calendar event: {e}")
            return {
                "success": False,
                "error": f"Failed to create event: {str(e)}"
            }
    
    def generate_user_api_key(self, user_email: str) -> str:
        """Generate a unique API key for Gmail users"""
        # Create a unique identifier for the user
        user_hash = hashlib.sha256(f"gmail_user_{user_email}".encode()).hexdigest()[:16]
        timestamp = int(datetime.now().timestamp())
        
        # Create API key with gmail prefix
        api_key = f"gmail_{user_hash}_{timestamp}"
        return hashlib.sha256(api_key.encode()).hexdigest()[:32]
    
    def create_credentials_from_token(self, access_token: str, refresh_token: str = None) -> Credentials:
        """Create Google credentials object from tokens"""
        return Credentials(
            token=access_token,
            refresh_token=refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=self.client_id,
            client_secret=self.client_secret
        )