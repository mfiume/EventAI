from fastapi import FastAPI, HTTPException, File, UploadFile, Form, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
from datetime import datetime, timedelta, timezone
import re
from typing import Optional, Union, Dict
import requests
import json
from geopy.geocoders import Nominatim
from timezonefinder import TimezoneFinder
from icalendar import Calendar, Event
import uuid
import pytz
from dotenv import load_dotenv
import base64
from PIL import Image
import io
import hashlib
import time

# Load environment variables from secrets directory (if exists locally)
if os.path.exists("secrets/secrets.env"):
    load_dotenv("secrets/secrets.env")
else:
    # In production, environment variables are set directly by Cloud Run
    pass

app = FastAPI(
    title="EventAI API",
    description="Convert text to calendar events using AI",
    version="1.0.0"
)

# Import APIRouter
from fastapi import APIRouter

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Anthropic API connection (using direct HTTP calls)
anthropic_api_key = os.getenv("ANTHROPIC_API_KEY")
anthropic_api_url = "https://api.anthropic.com/v1/messages"
anthropic_error = None

if anthropic_api_key:
    print("✅ Anthropic API key configured - using direct HTTP API")
else:
    print("⚠️ Anthropic API key not configured")
    anthropic_error = "API key not configured"

# Usage tracking - in-memory storage (replace with database in production)
user_usage: Dict[str, Dict] = {}
user_subscriptions: Dict[str, Dict] = {}

# Usage limits
FREE_DAILY_LIMIT = 3
PREMIUM_DAILY_LIMIT = 20

class UserUsageService:
    @staticmethod
    def get_user_id(request: Request) -> str:
        """Generate consistent user ID from device info or IP"""
        # Try to get device ID from headers
        device_id = request.headers.get("X-Device-ID")
        if device_id:
            return hashlib.sha256(device_id.encode()).hexdigest()[:16]
        
        # Fallback to IP + User-Agent hash
        ip = request.client.host
        user_agent = request.headers.get("User-Agent", "")
        combined = f"{ip}:{user_agent}"
        return hashlib.sha256(combined.encode()).hexdigest()[:16]
    
    @staticmethod
    def reset_daily_usage():
        """Reset usage counters for all users (called daily)"""
        global user_usage
        current_date = datetime.now(timezone.utc).date()
        
        for user_id in user_usage:
            user_usage[user_id] = {
                "count": 0,
                "last_reset": current_date.isoformat(),
                "first_use": user_usage[user_id].get("first_use", current_date.isoformat())
            }
        print(f"🔄 Reset daily usage for {len(user_usage)} users")
    
    @staticmethod
    def get_user_usage(user_id: str) -> Dict:
        """Get current usage stats for user"""
        current_date = datetime.now(timezone.utc).date()
        
        if user_id not in user_usage:
            user_usage[user_id] = {
                "count": 0,
                "last_reset": current_date.isoformat(),
                "first_use": current_date.isoformat()
            }
        
        # Reset if it's a new day
        user_data = user_usage[user_id]
        last_reset = datetime.fromisoformat(user_data["last_reset"]).date()
        
        if current_date > last_reset:
            user_data["count"] = 0
            user_data["last_reset"] = current_date.isoformat()
        
        return user_data
    
    @staticmethod
    def is_premium(user_id: str) -> bool:
        """Check if user has active premium subscription"""
        if user_id not in user_subscriptions:
            return False
        
        sub = user_subscriptions[user_id]
        if not sub.get("is_active", False):
            return False
        
        # Check if subscription is expired
        expiry = datetime.fromisoformat(sub["expiry_date"])
        if expiry < datetime.now(timezone.utc):
            sub["is_active"] = False
            return False
        
        return True
    
    @staticmethod
    def can_convert(user_id: str) -> Dict:
        """Check if user can perform a conversion"""
        is_premium = UserUsageService.is_premium(user_id)
        usage = UserUsageService.get_user_usage(user_id)
        
        if is_premium:
            limit = PREMIUM_DAILY_LIMIT
        else:
            limit = FREE_DAILY_LIMIT
        
        can_proceed = usage["count"] < limit
        remaining = max(0, limit - usage["count"])
        
        return {
            "allowed": can_proceed,
            "count": usage["count"],
            "limit": limit,
            "remaining": remaining,
            "is_premium": is_premium,
            "reset_date": usage["last_reset"]
        }
    
    @staticmethod
    def increment_usage(user_id: str):
        """Increment user's conversion count"""
        usage = UserUsageService.get_user_usage(user_id)
        usage["count"] += 1
        print(f"📊 User {user_id[:8]}... used {usage['count']} conversions today")

# Initialize usage service
usage_service = UserUsageService()

# Root endpoint for app health
@app.get("/")
async def app_root():
    return {
        "service": "EventAI API",
        "version": "1.0.0", 
        "api_endpoints": "Available at /api/",
        "status": "operational"
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "EventAI API"}

class CalendarEventResponse(BaseModel):
    icsContent: str
    eventsFound: int
    message: str
    events: Optional[list] = None
    usage: Optional[Dict] = None
    requiresPremium: Optional[bool] = False

class UsageResponse(BaseModel):
    count: int
    limit: int
    remaining: int
    is_premium: bool
    reset_date: str
    can_convert: bool

class SubscriptionRequest(BaseModel):
    receipt_data: str
    device_id: str
    product_id: str

class SubscriptionResponse(BaseModel):
    is_premium: bool
    expiry_date: Optional[str] = None
    product_id: Optional[str] = None


def convert_recurrence_pattern_to_rrule(pattern: str) -> Optional[dict]:
    """Convert natural language recurrence pattern to RRULE dictionary"""
    pattern = pattern.lower().strip()
    
    # Daily patterns
    if pattern in ['daily', 'every day', 'each day']:
        return {'freq': 'DAILY'}
    
    # Parse multiple days (e.g., "monday, wednesday, and friday" or "mon wed fri")
    days_mapping = {
        'monday': 'MO', 'mon': 'MO',
        'tuesday': 'TU', 'tue': 'TU', 'tues': 'TU',
        'wednesday': 'WE', 'wed': 'WE',
        'thursday': 'TH', 'thu': 'TH', 'thur': 'TH', 'thurs': 'TH',
        'friday': 'FR', 'fri': 'FR',
        'saturday': 'SA', 'sat': 'SA',
        'sunday': 'SU', 'sun': 'SU'
    }
    
    # Extract all mentioned days
    mentioned_days = []
    for day_name, day_code in days_mapping.items():
        if day_name in pattern:
            if day_code not in mentioned_days:  # Avoid duplicates
                mentioned_days.append(day_code)
    
    # If multiple days are mentioned, create BYDAY rule
    if len(mentioned_days) > 1:
        return {'freq': 'WEEKLY', 'byday': ','.join(mentioned_days)}
    elif len(mentioned_days) == 1:
        return {'freq': 'WEEKLY', 'byday': mentioned_days[0]}
    
    # Single day weekly patterns (fallback for cleaner phrases)
    if 'weekly on monday' in pattern or 'every monday' in pattern:
        return {'freq': 'WEEKLY', 'byday': 'MO'}
    elif 'weekly on tuesday' in pattern or 'every tuesday' in pattern:
        return {'freq': 'WEEKLY', 'byday': 'TU'}
    elif 'weekly on wednesday' in pattern or 'every wednesday' in pattern:
        return {'freq': 'WEEKLY', 'byday': 'WE'}
    elif 'weekly on thursday' in pattern or 'every thursday' in pattern:
        return {'freq': 'WEEKLY', 'byday': 'TH'}
    elif 'weekly on friday' in pattern or 'every friday' in pattern:
        return {'freq': 'WEEKLY', 'byday': 'FR'}
    elif 'weekly on saturday' in pattern or 'every saturday' in pattern:
        return {'freq': 'WEEKLY', 'byday': 'SA'}
    elif 'weekly on sunday' in pattern or 'every sunday' in pattern:
        return {'freq': 'WEEKLY', 'byday': 'SU'}
    
    # General weekly pattern
    if pattern in ['weekly', 'every week', 'each week']:
        return {'freq': 'WEEKLY'}
    
    # Weekday patterns
    if 'weekdays' in pattern or 'monday through friday' in pattern or 'mon-fri' in pattern:
        return {'freq': 'WEEKLY', 'byday': 'MO,TU,WE,TH,FR'}
    
    # Weekend patterns
    if 'weekends' in pattern or 'saturday and sunday' in pattern:
        return {'freq': 'WEEKLY', 'byday': 'SA,SU'}
    
    # Bi-weekly patterns
    if 'bi-weekly' in pattern or 'every 2 weeks' in pattern or 'every two weeks' in pattern:
        if mentioned_days:
            return {'freq': 'WEEKLY', 'interval': 2, 'byday': ','.join(mentioned_days)}
        return {'freq': 'WEEKLY', 'interval': 2}
    
    # Monthly patterns
    if pattern in ['monthly', 'every month', 'each month']:
        return {'freq': 'MONTHLY'}
    elif 'monthly on' in pattern:
        # Extract day number if present (e.g., "monthly on the 15th")
        import re
        day_match = re.search(r'(\d+)(st|nd|rd|th)?', pattern)
        if day_match:
            day = int(day_match.group(1))
            return {'freq': 'MONTHLY', 'bymonthday': day}
        return {'freq': 'MONTHLY'}
    
    # First/last/nth weekday of month (e.g., "first monday of each month")
    if 'first' in pattern and any(day in pattern for day in days_mapping.keys()):
        for day_name, day_code in days_mapping.items():
            if day_name in pattern:
                return {'freq': 'MONTHLY', 'byday': f'1{day_code}'}
    elif 'second' in pattern and any(day in pattern for day in days_mapping.keys()):
        for day_name, day_code in days_mapping.items():
            if day_name in pattern:
                return {'freq': 'MONTHLY', 'byday': f'2{day_code}'}
    elif 'third' in pattern and any(day in pattern for day in days_mapping.keys()):
        for day_name, day_code in days_mapping.items():
            if day_name in pattern:
                return {'freq': 'MONTHLY', 'byday': f'3{day_code}'}
    elif 'fourth' in pattern and any(day in pattern for day in days_mapping.keys()):
        for day_name, day_code in days_mapping.items():
            if day_name in pattern:
                return {'freq': 'MONTHLY', 'byday': f'4{day_code}'}
    elif 'last' in pattern and any(day in pattern for day in days_mapping.keys()):
        for day_name, day_code in days_mapping.items():
            if day_name in pattern:
                return {'freq': 'MONTHLY', 'byday': f'-1{day_code}'}
    
    # Yearly patterns
    if pattern in ['yearly', 'annually', 'every year', 'each year']:
        return {'freq': 'YEARLY'}
    
    # For any unrecognized pattern, try to extract FREQ= if present
    if 'freq=' in pattern.upper():
        # Already in RRULE format
        parts = pattern.upper().split(';')
        rrule_dict = {}
        for part in parts:
            if '=' in part:
                key, value = part.split('=', 1)
                rrule_dict[key.lower()] = value
        return rrule_dict
    
    # Default fallback
    return None


def infer_timezone_from_location(location_string: str) -> Optional[str]:
    """Infer timezone from location string using geocoding and timezone lookup"""
    try:
        # Initialize geocoder and timezone finder
        geolocator = Nominatim(user_agent="eventai")
        tf = TimezoneFinder()
        
        # Geocode the location to get coordinates
        location = geolocator.geocode(location_string)
        if location:
            # Get timezone from coordinates
            timezone_str = tf.timezone_at(lat=location.latitude, lng=location.longitude)
            return timezone_str
        return None
    except Exception as e:
        print(f"Warning: Could not infer timezone from location '{location_string}': {e}")
        return None

def create_calendar_from_events(events_data: list, timezone_str: str = "UTC") -> str:
    """Create an ICS calendar file from parsed events"""
    cal = Calendar()
    cal.add('prodid', '-//EventAI//EventAI 1.0//EN')
    cal.add('version', '2.0')
    cal.add('calscale', 'GREGORIAN')
    cal.add('method', 'PUBLISH')
    
    # Set timezone
    try:
        tz = pytz.timezone(timezone_str)
    except:
        tz = pytz.UTC
    
    for event_data in events_data:
        event = Event()
        event.add('uid', str(uuid.uuid4()))
        event.add('summary', event_data['title'])
        
        # Add EventAI attribution to description
        description = event_data.get('description') or ''
        if description:
            description += '\n\n'
        description += 'Created by EventAI (https://leveluplife.app/eventai)'
        event.add('description', description)
        
        # Parse dates
        try:
            # Handle timezone-aware parsing
            if 'T' in event_data['start_date'] and '+' not in event_data['start_date'] and 'Z' not in event_data['start_date']:
                # Add timezone offset to make it timezone-aware
                start_date_str = event_data['start_date']
                # If it's naive datetime, assume it's in the specified timezone
                start_date = datetime.fromisoformat(start_date_str)
                start_date = tz.localize(start_date) if tz != pytz.UTC else start_date.replace(tzinfo=pytz.UTC)
            else:
                start_date = datetime.fromisoformat(event_data['start_date'].replace('Z', '+00:00'))
                if start_date.tzinfo is None:
                    start_date = tz.localize(start_date) if tz != pytz.UTC else start_date.replace(tzinfo=pytz.UTC)
        except:
            # Fallback parsing
            start_date = datetime.fromisoformat(event_data['start_date'].replace('Z', '+00:00'))
            if start_date.tzinfo is None:
                start_date = tz.localize(start_date) if tz != pytz.UTC else start_date.replace(tzinfo=pytz.UTC)
        
        if event_data.get('end_date'):
            try:
                if 'T' in event_data['end_date'] and '+' not in event_data['end_date'] and 'Z' not in event_data['end_date']:
                    end_date_str = event_data['end_date']
                    end_date = datetime.fromisoformat(end_date_str)
                    end_date = tz.localize(end_date) if tz != pytz.UTC else end_date.replace(tzinfo=pytz.UTC)
                else:
                    end_date = datetime.fromisoformat(event_data['end_date'].replace('Z', '+00:00'))
                    if end_date.tzinfo is None:
                        end_date = tz.localize(end_date) if tz != pytz.UTC else end_date.replace(tzinfo=pytz.UTC)
            except:
                end_date = datetime.fromisoformat(event_data['end_date'].replace('Z', '+00:00'))
                if end_date.tzinfo is None:
                    end_date = tz.localize(end_date) if tz != pytz.UTC else end_date.replace(tzinfo=pytz.UTC)
        else:
            end_date = start_date + timedelta(hours=1)
        
        # Use proper timezone formatting for iOS compatibility
        event.add('dtstart', start_date)
        event.add('dtend', end_date)
        
        # Add required fields for iOS compatibility
        now_utc = datetime.utcnow().replace(tzinfo=pytz.UTC)
        event.add('dtstamp', now_utc)
        event.add('created', now_utc)
        event.add('last-modified', now_utc)
        event.add('sequence', 0)
        event.add('status', 'CONFIRMED')
        event.add('transp', 'OPAQUE')
        
        if event_data.get('location'):
            event.add('location', event_data['location'])
            
        # Add recurrence rule if this is a recurring event
        if event_data.get('is_recurring') and event_data.get('recurrence_pattern'):
            # Convert natural language recurrence pattern to RRULE
            rrule = convert_recurrence_pattern_to_rrule(event_data['recurrence_pattern'])
            if rrule:
                event.add('rrule', rrule)
            
        cal.add_component(event)
    
    return cal.to_ical().decode('utf-8')

# Create API router and define endpoints
api_router = APIRouter(prefix="/api")

@api_router.get("/")
async def api_root():
    return {
        "service": "EventAI API",
        "version": "1.0.0",
        "description": "Convert text to calendar events using AI",
        "status": "operational",
        "timestamp": datetime.utcnow().isoformat()
    }

@api_router.get("/health")
async def api_health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "uptime": "running"
    }

@api_router.get("/debug")
async def api_debug_info():
    return {
        "anthropic_key_configured": bool(anthropic_api_key),
        "anthropic_key_length": len(anthropic_api_key or ""),
        "anthropic_api_url": anthropic_api_url,
        "anthropic_error": anthropic_error,
        "api_method": "direct_http_calls",
        "environment_keys": list(os.environ.keys())
    }

@api_router.get("/usage", response_model=UsageResponse)
async def get_usage_stats(request: Request):
    """Get current user usage statistics"""
    user_id = usage_service.get_user_id(request)
    usage_check = usage_service.can_convert(user_id)
    
    return UsageResponse(
        count=usage_check["count"],
        limit=usage_check["limit"],
        remaining=usage_check["remaining"],
        is_premium=usage_check["is_premium"],
        reset_date=usage_check["reset_date"],
        can_convert=usage_check["allowed"]
    )

@api_router.post("/subscription/verify", response_model=SubscriptionResponse)
async def verify_subscription(subscription: SubscriptionRequest, request: Request):
    """Verify and activate subscription (simplified version - implement StoreKit validation in production)"""
    user_id = usage_service.get_user_id(request)
    
    # TODO: Implement proper App Store receipt validation
    # For now, we'll simulate successful validation
    expiry_date = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()
    
    user_subscriptions[user_id] = {
        "is_active": True,
        "expiry_date": expiry_date,
        "product_id": subscription.product_id,
        "device_id": subscription.device_id,
        "receipt_data": subscription.receipt_data
    }
    
    print(f"✅ Activated subscription for user {user_id[:8]}... Product: {subscription.product_id}")
    
    return SubscriptionResponse(
        is_premium=True,
        expiry_date=expiry_date,
        product_id=subscription.product_id
    )

@api_router.get("/subscription/status", response_model=SubscriptionResponse)
async def get_subscription_status(request: Request):
    """Get current subscription status"""
    user_id = usage_service.get_user_id(request)
    is_premium = usage_service.is_premium(user_id)
    
    if is_premium:
        sub = user_subscriptions[user_id]
        return SubscriptionResponse(
            is_premium=True,
            expiry_date=sub["expiry_date"],
            product_id=sub["product_id"]
        )
    else:
        return SubscriptionResponse(is_premium=False)

@api_router.post("/convert", response_model=CalendarEventResponse)
async def convert_to_calendar(
    request: Request,
    text: str = Form(""),
    timezone: str = Form("UTC"),
    userLocation: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None)
):
    """Convert natural language text and/or image to calendar events"""
    user_id = usage_service.get_user_id(request)
    is_premium = usage_service.is_premium(user_id)
    
    # Check if user is trying to use premium-only image feature
    if image and not is_premium:
        return CalendarEventResponse(
            icsContent="",
            eventsFound=0,
            message="Photo support is a premium feature. Upgrade to EventAI Premium to analyze images!",
            events=[],
            usage=usage_service.can_convert(user_id),
            requiresPremium=True
        )
    
    # Check usage limits before processing
    usage_check = usage_service.can_convert(user_id)
    
    if not usage_check["allowed"]:
        return CalendarEventResponse(
            icsContent="",
            eventsFound=0,
            message=f"Daily limit of {usage_check['limit']} conversions reached. {'Upgrade to Premium for more conversions!' if not usage_check['is_premium'] else 'Try again tomorrow!'}",
            events=[],
            usage=usage_check,
            requiresPremium=not usage_check["is_premium"]
        )
    
    # Process image if provided
    image_data = None
    if image:
        image_content = await image.read()
        image_data = base64.b64encode(image_content).decode('utf-8')
        
    # Process the request
    result = await process_calendar_request(text, timezone, userLocation, image_data)
    
    # Increment usage if conversion was successful
    if result.eventsFound > 0:
        usage_service.increment_usage(user_id)
        updated_usage = usage_service.can_convert(user_id)
        result.usage = updated_usage
    
    return result

async def process_calendar_request(text: str, timezone: str, userLocation: Optional[str], image_data: Optional[str]):
    """Convert natural language text and/or image to calendar events"""
    
    if not anthropic_api_key:
        raise HTTPException(status_code=500, detail="Anthropic API key not configured")
    
    try:
        print(f"🔍 Processing request - Text length: {len(text)}, Image: {'Yes' if image_data else 'No'}")
        if image_data:
            print(f"🖼️ Image data length: {len(image_data)} characters")
        # Determine the effective timezone
        effective_timezone = timezone
        if userLocation and effective_timezone == "UTC":
            # Try to infer timezone from location
            inferred_timezone = infer_timezone_from_location(userLocation)
            if inferred_timezone:
                effective_timezone = inferred_timezone
                print(f"📍 Inferred timezone '{effective_timezone}' from location '{userLocation}'")
        
        # Prompt for Claude to extract calendar events
        location_context = f"\n\nUser's current location: {userLocation}" if userLocation else ""
        
        prompt = f"""
        You are an expert at parsing natural language text into calendar events for ICS (iCalendar) format.

        Extract calendar events from the following text and return them as a JSON array. Each event must be suitable for ICS format.
        
        SPECIAL HANDLING FOR TABLES AND SCHEDULES:
        - Users may paste in tables, schedules, or structured data with dates and activities
        - Parse each row/line carefully to identify dates, times, and event information
        - Look for column-based patterns where different columns may represent different categories, teams, or activities
        - Pay attention to any user-specified filters (e.g., "only create events for team X", "just the meetings", etc.)
        - Parse ALL relevant rows in the table - don't skip any entries that match the user's criteria
        - Use context clues to determine missing information (year, time, etc.)
        
        REQUIRED FIELDS for each event:
        - title (string): Brief, clear title for the event
        - start_date (string): ISO format datetime (YYYY-MM-DDTHH:MM:SS) - REQUIRED for ICS
        - end_date (string): ISO format datetime (YYYY-MM-DDTHH:MM:SS) - if not specified, set to 1 hour after start
        - is_recurring (boolean): true for recurring events, false for one-time events
        
        OPTIONAL FIELDS:
        - description (string): Additional details about the event
        - location (string): Physical or virtual location
        - timezone (string): Timezone identifier (e.g., "America/New_York", "Europe/London")
        - recurrence_pattern (string): If recurring, describe pattern clearly (e.g., "FREQ=WEEKLY;BYDAY=MO", "daily", "weekly on Fridays", "monthly on 15th", "yearly on birthday")
        
        PARSING RULES:
        1. Date/Time: Calculate from today ({datetime.now().strftime('%A, %B %d, %Y')})
           - For month/day formats like "September 6", determine the correct year:
             - If the date has already passed this year, use next year
             - If the date hasn't occurred yet this year, use this year
           - Default times: morning=9AM, afternoon=2PM, evening=7PM
           - "tomorrow" = next day
           - "next Monday" = next occurrence of Monday
           - "in 2 weeks" = 14 days from now
           
        2. Recurring Events: Look for patterns like:
           - "every day/week/month/year" → is_recurring=true
           - "daily/weekly/monthly/yearly" → is_recurring=true
           - "every Monday/Tuesday/etc" → is_recurring=true, pattern="weekly on [day]"
           - "bi-weekly", "every two weeks" → is_recurring=true, pattern="every 2 weeks"
           - "Daily [activity]" (e.g., "Daily call with mom", "Daily standup") → is_recurring=true, pattern="daily"
           - "Weekly [activity]" → is_recurring=true, pattern="weekly"
           - "Monthly [activity]" → is_recurring=true, pattern="monthly"
           - Single mentions like "meeting tomorrow" → is_recurring=false
           
        3. Location: Include if mentioned or can be reasonably inferred
           {location_context}
        
        4. Timezone: Use effective timezone "{effective_timezone}" or infer from context
        
        IMPORTANT: 
        - Each event must have valid date/time for ICS format
        - If you cannot determine a specific date/time, do not include that event
        - When parsing tables/schedules, be thorough - examine EVERY row and don't skip entries that match the user's criteria
        - Pay close attention to any filtering requirements specified by the user
        - Look for patterns and interpret abbreviations based on context
        - If user provides additional context about what the columns/abbreviations mean, use that information
        
        Return ONLY a valid JSON array. Example format:
        [
          {{
            "title": "Team Meeting",
            "start_date": "2025-08-10T10:00:00",
            "end_date": "2025-08-10T11:00:00",
            "location": "Conference Room A",
            "description": "Weekly team standup meeting",
            "is_recurring": true,
            "recurrence_pattern": "weekly on Fridays",
            "timezone": "America/New_York"
          }}
        ]
        
        Text to analyze:
        {text}
        """
        
        # Prepare content for API call
        if image_data:
            # Include image in the request
            content = [
                {
                    "type": "text",
                    "text": prompt
                }
            ]
            
            # Add image if provided
            if image_data:
                # Detect media type from image data or default to JPEG since iOS sends JPEG
                media_type = "image/jpeg"  # iOS sends JPEG by default
                if image_data.startswith("/9j/"):  # JPEG signature
                    media_type = "image/jpeg"
                elif image_data.startswith("iVBOR"):  # PNG signature
                    media_type = "image/png"
                elif image_data.startswith("UklGR"):  # WebP signature
                    media_type = "image/webp"
                
                content.append({
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": media_type,
                        "data": image_data
                    }
                })
                print(f"🖼️ Image media type detected: {media_type}")
                print(f"🖼️ Including image in request (size: {len(image_data)} chars)")
        else:
            content = prompt
        
        # DEBUG: Print the prompt being sent to AI
        print("🔍 DEBUG - PROMPT SENT TO AI:")
        print("=" * 80)
        if isinstance(content, str):
            print(content)
        else:
            print("Text prompt + image attachment")
        print("=" * 80)
        
        # Make direct HTTP request to Anthropic API
        headers = {
            'Content-Type': 'application/json',
            'x-api-key': anthropic_api_key,
            'anthropic-version': '2023-06-01'
        }
        
        payload = {
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 2000,
            "temperature": 0.1,
            "messages": [
                {
                    "role": "user",
                    "content": content
                }
            ]
        }
        
        print("🤖 Making request to Anthropic API...")
        response = requests.post(anthropic_api_url, headers=headers, json=payload, timeout=30)
        print(f"🤖 Anthropic API response status: {response.status_code}")
        
        if response.status_code != 200:
            error_detail = f"Anthropic API error: {response.status_code} - {response.text}"
            print(f"❌ {error_detail}")
            raise HTTPException(status_code=500, detail=error_detail)
        
        try:
            response_data = response.json()
            response_text = response_data.get('content', [{}])[0].get('text', '')
            
            # DEBUG: Print the response from AI
            print("🤖 DEBUG - RESPONSE FROM AI:")
            print("=" * 80)
            print(response_text[:500] + "..." if len(response_text) > 500 else response_text)
            print("=" * 80)
        except Exception as json_parse_error:
            print(f"❌ Error parsing Anthropic response JSON: {json_parse_error}")
            print(f"Raw response: {response.text[:500]}...")
            raise HTTPException(status_code=500, detail=f"Failed to parse AI response: {str(json_parse_error)}")
        
        # Extract JSON from response
        try:
            # Look for JSON array in the response
            json_start = response_text.find('[')
            json_end = response_text.rfind(']') + 1
            if json_start != -1 and json_end > json_start:
                json_str = response_text[json_start:json_end]
                raw_events_data = json.loads(json_str)
                
                # Ensure all required fields are present with defaults and format dates properly
                events_data = []
                for event in raw_events_data:
                    try:
                        # Process dates to ensure they include timezone information
                        start_date = event.get('start_date', '')
                        end_date = event.get('end_date', None)
                        
                        # Parse and reformat dates to include timezone if not present
                        try:
                            if start_date and 'T' in start_date and '+' not in start_date and 'Z' not in start_date:
                                parsed_start = datetime.fromisoformat(start_date)
                                tz = pytz.timezone(effective_timezone)
                                parsed_start = tz.localize(parsed_start)
                                start_date = parsed_start.isoformat()
                        except Exception as date_error:
                            print(f"⚠️ Date parsing error for start_date '{start_date}': {date_error}")
                        
                        try:
                            if end_date and 'T' in end_date and '+' not in end_date and 'Z' not in end_date:
                                parsed_end = datetime.fromisoformat(end_date)
                                tz = pytz.timezone(effective_timezone)
                                parsed_end = tz.localize(parsed_end)
                                end_date = parsed_end.isoformat()
                        except Exception as date_error:
                            print(f"⚠️ Date parsing error for end_date '{end_date}': {date_error}")
                        
                        processed_event = {
                            'title': event.get('title', ''),
                            'description': event.get('description', None),
                            'start_date': start_date,
                            'end_date': end_date,
                            'location': event.get('location', None),
                            'is_recurring': event.get('is_recurring', False),
                            'recurrence_pattern': event.get('recurrence_pattern', None),
                            'timezone': effective_timezone  # Always use effective timezone
                        }
                        events_data.append(processed_event)
                    except Exception as event_error:
                        print(f"❌ Error processing event: {event_error}")
                        print(f"Event data: {event}")
                        continue
                    
                # DEBUG: Print processed events to see timezone assignment
                print("🎯 DEBUG - PROCESSED EVENTS:")
                for i, event in enumerate(events_data):
                    print(f"  Event {i+1}: {event['title']}")
                    print(f"    Timezone: {event['timezone']}")
                    print(f"    Start: {event['start_date']}")
                    print(f"    End: {event['end_date']}")
                print("=" * 80)
            else:
                events_data = []
        except (json.JSONDecodeError, ValueError):
            events_data = []
        
        if not events_data:
            # Provide contextual error message based on whether image was provided
            if image_data:
                error_message = "No calendar events were detected in the provided text or image. Please ensure your content contains dates, times, or scheduled activities."
            else:
                error_message = "No calendar events were detected in the provided text. Please ensure your text contains dates, times, or scheduled activities."
            
            return CalendarEventResponse(
                icsContent="",
                eventsFound=0,
                message=error_message,
                events=[]
            )
        
        # Generate ICS content using effective timezone
        ics_content = create_calendar_from_events(events_data, effective_timezone)
        
        return CalendarEventResponse(
            icsContent=ics_content,
            eventsFound=len(events_data),
            message=f"Successfully created {len(events_data)} calendar event(s).",
            events=events_data
        )
        
    except requests.RequestException as e:
        raise HTTPException(status_code=500, detail=f"AI service connection error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing error: {str(e)}")

# Include the API router
app.include_router(api_router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)