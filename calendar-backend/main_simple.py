from fastapi import FastAPI
import os

app = FastAPI(
    title="EventAI API",
    description="Convert text to calendar events using AI",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {
        "service": "EventAI API",
        "version": "1.0.0",
        "description": "Convert text to calendar events using AI",
        "status": "operational"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "version": "1.0.0"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)