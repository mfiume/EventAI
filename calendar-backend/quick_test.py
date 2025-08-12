#!/usr/bin/env python3
"""
Quick EventAI Test Runner
Simple tests for rapid evaluation
"""

import json
import time
import requests
from datetime import datetime

def quick_test(endpoint_url, test_name, text, api_key=None):
    """Run a quick test"""
    print(f"\n🧪 {test_name}")
    print("-" * 40)
    
    headers = {"X-Device-ID": f"quick-test-{int(time.time())}"}
    if api_key:
        headers["X-API-Key"] = api_key
    
    data = {
        "text": text,
        "timezone": "America/New_York"
    }
    
    start_time = time.time()
    try:
        response = requests.post(
            f"{endpoint_url}/convert",
            headers=headers,
            data=data,
            timeout=30
        )
        latency = time.time() - start_time
        
        if response.status_code == 200:
            result = response.json()
            events_found = result.get("eventsFound", 0)
            print(f"⏱️  Time: {latency:.3f}s")
            print(f"📊 Events: {events_found}")
            print(f"💬 Message: {result.get('message', 'N/A')}")
            
            if events_found > 0:
                print("📅 Sample Event:")
                first_event = result.get("events", [{}])[0]
                print(f"   Title: {first_event.get('title', 'N/A')}")
                print(f"   Start: {first_event.get('start_date', 'N/A')}")
            return True
        else:
            print(f"❌ Error: {response.status_code} - {response.text[:100]}")
            return False
            
    except Exception as e:
        print(f"❌ Exception: {str(e)}")
        return False

def main():
    """Run quick tests"""
    print("🚀 EventAI Quick Test Suite")
    
    # Endpoints
    production = "https://eventai-api-661796696046.us-central1.run.app/api"
    staging = "https://eventai-api-staging-661796696046.us-central1.run.app/api"
    staging_key = "eak_8892df309f67ead69e192d7dc0c5cdb76a563e9cdcc016dd246ddb6c4827c1b4"
    
    # Test cases
    tests = [
        ("Simple Meeting", "Meeting tomorrow at 2pm with Sarah about the new project"),
        ("Recurring Event", "Weekly team standup every Monday at 9am starting next week"),
        ("Multi-day Trip", "Paris vacation March 15-20: Day 1 flight at 8am, Day 2 Eiffel Tower tour at 2pm, Day 3 Louvre visit at 10am")
    ]
    
    # Test production
    print("\n🏭 PRODUCTION (Claude-3.5-Sonnet):")
    prod_results = []
    for test_name, text in tests:
        success = quick_test(production, test_name, text)
        prod_results.append(success)
    
    # Test staging  
    print("\n🧪 STAGING (Claude-3-Haiku):")
    staging_results = []
    for test_name, text in tests:
        success = quick_test(staging, test_name, text, staging_key)
        staging_results.append(success)
    
    # Summary
    print(f"\n📊 SUMMARY:")
    print(f"Production Success Rate: {sum(prod_results)}/{len(prod_results)} ({sum(prod_results)/len(prod_results)*100:.0f}%)")
    print(f"Staging Success Rate: {sum(staging_results)}/{len(staging_results)} ({sum(staging_results)/len(staging_results)*100:.0f}%)")

if __name__ == "__main__":
    main()