#!/usr/bin/env python3
"""
EventAI Test Suite
Comprehensive testing for accuracy and latency of the AI calendar conversion endpoint
"""

import json
import time
import requests
import os
import base64
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import statistics

class EventAITestSuite:
    def __init__(self, 
                 production_url: str = "https://eventai-api-661796696046.us-central1.run.app/api",
                 staging_url: str = "https://eventai-api-staging-661796696046.us-central1.run.app/api",
                 staging_api_key: str = None):
        self.production_url = production_url
        self.staging_url = staging_url
        self.staging_api_key = staging_api_key
        self.test_results = []
        
    def create_device_id(self, test_name: str) -> str:
        """Create unique device ID for each test"""
        timestamp = int(time.time())
        return f"test-{test_name.lower().replace(' ', '-')}-{timestamp}"
    
    def run_test(self, test_name: str, text: str, image_path: Optional[str] = None, 
                 expected_events: int = None, timezone: str = "America/New_York",
                 endpoint: str = "production") -> Dict:
        """Run a single test case"""
        
        print(f"\n🧪 Running Test: {test_name}")
        print("=" * 50)
        
        # Determine endpoint
        if endpoint == "production":
            url = self.production_url
            headers = {"X-Device-ID": self.create_device_id(test_name)}
        else:  # staging
            url = self.staging_url
            headers = {
                "X-Device-ID": self.create_device_id(test_name),
                "X-API-Key": self.staging_api_key
            }
        
        # Prepare request
        files = {}
        data = {
            "text": text,
            "timezone": timezone
        }
        
        # Add image if provided
        if image_path and os.path.exists(image_path):
            with open(image_path, 'rb') as f:
                files["image"] = f
                
        # Execute test
        start_time = time.time()
        try:
            response = requests.post(
                f"{url}/convert",
                headers=headers,
                data=data,
                files=files if files else None,
                timeout=60
            )
            end_time = time.time()
            latency = end_time - start_time
            
            # Parse response
            if response.status_code == 200:
                result = response.json()
                events_found = result.get("eventsFound", 0)
                success = events_found > 0
                message = result.get("message", "")
                events = result.get("events", [])
            else:
                result = {}
                events_found = 0
                success = False
                message = f"HTTP {response.status_code}: {response.text}"
                events = []
                
        except Exception as e:
            end_time = time.time()
            latency = end_time - start_time
            result = {}
            events_found = 0
            success = False
            message = f"Error: {str(e)}"
            events = []
        
        # Calculate accuracy score
        accuracy = self.calculate_accuracy(events_found, expected_events, events)
        
        # Store results
        test_result = {
            "test_name": test_name,
            "endpoint": endpoint,
            "success": success,
            "latency": latency,
            "events_found": events_found,
            "expected_events": expected_events,
            "accuracy": accuracy,
            "message": message,
            "events": events,
            "timestamp": datetime.now().isoformat()
        }
        
        self.test_results.append(test_result)
        
        # Print results
        print(f"⏱️  Latency: {latency:.3f}s")
        print(f"📊 Events Found: {events_found}")
        print(f"🎯 Expected Events: {expected_events if expected_events else 'Any'}")
        print(f"✅ Success: {success}")
        print(f"📈 Accuracy Score: {accuracy:.1f}%")
        print(f"💬 Message: {message}")
        
        if events:
            print("📅 Parsed Events:")
            for i, event in enumerate(events[:3]):  # Show first 3
                print(f"   {i+1}. {event.get('title', 'N/A')}")
                print(f"      Start: {event.get('start_date', 'N/A')}")
                print(f"      Recurring: {event.get('is_recurring', False)}")
        
        return test_result
    
    def calculate_accuracy(self, events_found: int, expected_events: Optional[int], events: List) -> float:
        """Calculate accuracy score based on events found vs expected"""
        if expected_events is None:
            return 100.0 if events_found > 0 else 0.0
        
        if expected_events == 0:
            return 100.0 if events_found == 0 else 0.0
        
        # Base accuracy on how close we got to expected count
        if events_found == 0:
            return 0.0
        
        # Perfect match gets 100%, deduct points for over/under detection
        if events_found == expected_events:
            base_score = 100.0
        else:
            # Calculate deviation penalty
            deviation = abs(events_found - expected_events)
            max_penalty = 30  # Maximum penalty for count mismatch
            penalty = min(max_penalty, deviation * 10)  # 10 points per event mismatch
            base_score = max(0, 100.0 - penalty)
        
        # Quality bonus for good parsing (but can't exceed 100% total)
        quality_bonus = 0
        for event in events:
            if event.get('title') and event.get('start_date'):
                quality_bonus += 2
            if event.get('location'):
                quality_bonus += 1
            if event.get('is_recurring') and event.get('recurrence_pattern'):
                quality_bonus += 1
        
        final_score = min(100.0, base_score + quality_bonus)
        
        # Add warning for count mismatches
        if events_found != expected_events:
            print(f"⚠️  Count Mismatch: Found {events_found}, expected {expected_events} (accuracy penalty applied)")
        
        return final_score
    
    def run_test_suite(self, endpoint: str = "production"):
        """Run the complete test suite"""
        
        print(f"\n🚀 Starting EventAI Test Suite - {endpoint.upper()}")
        print("=" * 60)
        
        # Test Case 1: Trip Planning (Complex Multi-day)
        trip_text = """Mexico Family Vacation - March 10-15, 2025
Day 1 - Monday, March 10
* 8:00 AM - Flight AC456 to Cancun, departs Toronto Pearson (YYZ), Terminal 1
* 2:30 PM - Arrive in Cancun, hotel check-in at The Grand at Moon Palace
* 6:00 PM - Welcome dinner at hotel restaurant

Day 2 - Tuesday, March 11
* 9:00 AM - Chichen Itza guided tour (hotel lobby pickup)
* 7:30 PM - Evening stroll through Cancun downtown

Day 3 - Wednesday, March 12
* 10:00 AM - Snorkeling at Isla Mujeres
* 7:00 PM - Sunset dinner cruise, Puerto Cancun Marina

Day 4 - Thursday, March 13
* 8:00 AM - Family breakfast at hotel
* 10:00 AM - Beach day at Playa Delfines
* 5:00 PM - Shopping at La Isla Shopping Village

Day 5 - Friday, March 14
* 9:00 AM - Jungle zipline adventure tour
* 6:30 PM - Farewell dinner at Lorenzillo's

Day 6 - Saturday, March 15
* 10:00 AM - Morning swim at hotel pool
* 12:00 PM - Hotel check-out
* 3:15 PM - Flight AC457 back to Toronto (YYZ), Terminal 1"""
        
        self.run_test("Trip Planning - Mexico Vacation", trip_text, expected_events=15, endpoint=endpoint)
        
        # Test Case 2: Recurring Meeting
        recurring_text = """Set up a recurring coffee meeting at The Alchemist with Laura, 
every other Tuesday 9-10am starting next Tuesday until December 1st."""
        
        self.run_test("Recurring Meeting - Coffee with Laura", recurring_text, expected_events=1, endpoint=endpoint)
        
        # Test Case 3: Simple Meeting
        simple_text = "Meeting with client tomorrow at 2pm about project proposal. Lunch with team on Friday at 12:30pm in conference room A."
        
        self.run_test("Simple Meeting", simple_text, expected_events=2, endpoint=endpoint)
        
        # Test Case 4: Weekly Schedule
        schedule_text = """My weekly schedule:
Monday 9am - Team standup (Conference Room B)
Tuesday 2pm - Client review meeting
Wednesday 10am - Project planning session
Thursday 3pm - Code review with dev team
Friday 11am - Weekly retrospective"""
        
        self.run_test("Weekly Schedule", schedule_text, expected_events=5, endpoint=endpoint)
        
        # Test Case 5: Conference Schedule
        conference_text = """TechConf 2025 - Day 1 Schedule
9:00 AM - Registration and Welcome Coffee
10:00 AM - Keynote: The Future of AI
11:30 AM - Break
12:00 PM - Panel: Machine Learning Ethics
1:00 PM - Lunch Break
2:30 PM - Workshop: Building ML Pipelines
4:00 PM - Networking Session
5:30 PM - Closing Remarks"""
        
        # Expected: 8 events (all time slots including breaks are valid events)
        self.run_test("Conference Schedule", conference_text, expected_events=8, endpoint=endpoint)
        
        # Test Case 6: Medical Appointments
        medical_text = """Dr. appointments for next month:
- Dentist cleaning on March 15th at 10:30am
- Annual physical with Dr. Smith on March 22nd at 2pm
- Eye exam on March 28th at 11am
- Follow-up with cardiologist on April 3rd at 9:30am"""
        
        self.run_test("Medical Appointments", medical_text, expected_events=4, endpoint=endpoint)
        
    def generate_report(self):
        """Generate a comprehensive test report"""
        if not self.test_results:
            print("No test results to report")
            return
        
        print(f"\n📊 TEST SUITE REPORT")
        print("=" * 60)
        
        # Overall statistics
        total_tests = len(self.test_results)
        successful_tests = sum(1 for r in self.test_results if r["success"])
        success_rate = (successful_tests / total_tests) * 100
        
        latencies = [r["latency"] for r in self.test_results]
        avg_latency = statistics.mean(latencies)
        min_latency = min(latencies)
        max_latency = max(latencies)
        
        accuracies = [r["accuracy"] for r in self.test_results]
        avg_accuracy = statistics.mean(accuracies)
        
        print(f"📈 Overall Results:")
        print(f"   Total Tests: {total_tests}")
        print(f"   Successful: {successful_tests}")
        print(f"   Success Rate: {success_rate:.1f}%")
        print(f"   Average Accuracy: {avg_accuracy:.1f}%")
        print()
        print(f"⏱️  Latency Statistics:")
        print(f"   Average: {avg_latency:.3f}s")
        print(f"   Min: {min_latency:.3f}s")
        print(f"   Max: {max_latency:.3f}s")
        print()
        
        # Detailed results
        print(f"📋 Detailed Results:")
        print(f"{'Test Name':<30} | {'Success':<7} | {'Latency':<8} | {'Events':<7} | {'Accuracy':<8}")
        print("-" * 80)
        
        for result in self.test_results:
            print(f"{result['test_name'][:29]:<30} | "
                  f"{'✅' if result['success'] else '❌':<7} | "
                  f"{result['latency']:.3f}s{'':<2} | "
                  f"{result['events_found']:<7} | "
                  f"{result['accuracy']:.1f}%{'':<4}")
        
        # Save detailed results to file
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"test_results_{timestamp}.json"
        with open(filename, 'w') as f:
            json.dump(self.test_results, f, indent=2)
        
        print(f"\n💾 Detailed results saved to: {filename}")

def main():
    """Main function to run tests"""
    
    # Configuration
    staging_api_key = "eak_8892df309f67ead69e192d7dc0c5cdb76a563e9cdcc016dd246ddb6c4827c1b4"
    
    # Initialize test suite
    test_suite = EventAITestSuite(staging_api_key=staging_api_key)
    
    # Run tests on both endpoints
    print("🎯 Testing Production Endpoint (Claude-3.5-Sonnet)")
    test_suite.run_test_suite(endpoint="production")
    
    print("\n" + "="*60)
    print("🧪 Testing Staging Endpoint (Claude-3-Haiku)")  
    test_suite.run_test_suite(endpoint="staging")
    
    # Generate comprehensive report
    test_suite.generate_report()

if __name__ == "__main__":
    main()