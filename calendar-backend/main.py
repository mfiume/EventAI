from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
from datetime import datetime, timedelta
import re
from typing import Optional
import anthropic
from icalendar import Calendar, Event
import uuid
import pytz
from dotenv import load_dotenv

# Load environment variables from secrets directory
load_dotenv("secrets/secrets.env")

app = FastAPI(
    title="EventAI API",
    description="Convert text to calendar events using AI",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Anthropic client
client = anthropic.Anthropic(
    api_key=os.getenv("ANTHROPIC_API_KEY")
)

class TextToCalendarRequest(BaseModel):
    text: str
    timezone: Optional[str] = "UTC"

class CalendarEventResponse(BaseModel):
    ics_content: str
    events_found: int
    message: str

@app.get("/")
async def root():
    return {
        "service": "EventAI API",
        "version": "1.0.0",
        "description": "Convert text to calendar events using AI",
        "status": "operational",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "uptime": "running"
    }

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
        event.add('description', event_data.get('description', ''))
        
        # Parse dates
        start_date = datetime.fromisoformat(event_data['start_date'].replace('Z', '+00:00'))
        if event_data.get('end_date'):
            end_date = datetime.fromisoformat(event_data['end_date'].replace('Z', '+00:00'))
        else:
            end_date = start_date + timedelta(hours=1)
        
        # Apply timezone
        start_date = start_date.replace(tzinfo=tz)
        end_date = end_date.replace(tzinfo=tz)
        
        event.add('dtstart', start_date)
        event.add('dtend', end_date)
        event.add('dtstamp', datetime.utcnow())
        event.add('created', datetime.utcnow())
        
        if event_data.get('location'):
            event.add('location', event_data['location'])
            
        cal.add_component(event)
    
    return cal.to_ical().decode('utf-8')

@app.post("/convert", response_model=CalendarEventResponse)
async def convert_text_to_calendar(request: TextToCalendarRequest):
    """Convert natural language text to calendar events"""
    
    if not os.getenv("ANTHROPIC_API_KEY"):
        raise HTTPException(status_code=500, detail="Anthropic API key not configured")
    
    try:
        # Prompt for Claude to extract calendar events
        prompt = f"""
        Extract calendar events from the following text and return them in JSON format.
        For each event, provide:
        - title (required): Brief title for the event
        - description (optional): Additional details
        - start_date (required): ISO format datetime (YYYY-MM-DDTHH:MM:SS)
        - end_date (optional): ISO format datetime, if not provided will default to 1 hour after start
        - location (optional): Location if mentioned
        
        If no specific time is mentioned, assume a reasonable time (e.g., 9 AM for morning, 2 PM for afternoon, 7 PM for evening).
        If no specific date is mentioned but relative dates are used (tomorrow, next week, etc.), calculate based on today being {datetime.now().strftime('%Y-%m-%d')}.
        
        Return only valid JSON array of events. If no events found, return empty array [].
        
        Text to analyze:
        {request.text}
        """
        
        message = client.messages.create(
            model="claude-3-sonnet-20240229",
            max_tokens=2000,
            temperature=0.1,
            messages=[
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        )
        
        response_text = message.content[0].text
        
        # Extract JSON from response
        import json
        try:
            # Look for JSON array in the response
            json_start = response_text.find('[')
            json_end = response_text.rfind(']') + 1
            if json_start != -1 and json_end > json_start:
                json_str = response_text[json_start:json_end]
                events_data = json.loads(json_str)
            else:
                events_data = []
        except (json.JSONDecodeError, ValueError):
            events_data = []
        
        if not events_data:
            return CalendarEventResponse(
                ics_content="",
                events_found=0,
                message="No calendar events were detected in the provided text."
            )
        
        # Generate ICS content
        ics_content = create_calendar_from_events(events_data, request.timezone)
        
        return CalendarEventResponse(
            ics_content=ics_content,
            events_found=len(events_data),
            message=f"Successfully created {len(events_data)} calendar event(s)."
        )
        
    except anthropic.APIError as e:
        raise HTTPException(status_code=500, detail=f"AI service error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)