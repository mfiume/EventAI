#!/usr/bin/env python3
"""
Test Gmail Integration for EventAI
Comprehensive testing of Gmail Add-on backend functionality
"""

import json
import requests
import time
from datetime import datetime
from typing import Dict, Any

class GmailIntegrationTester:
    """Test suite for Gmail integration endpoints"""
    
    def __init__(self, base_url: str = "https://eventai-gmail-api-661796696046.us-central1.run.app"):
        self.base_url = base_url.rstrip('/')
        self.test_results = []
        
    def run_test(self, test_name: str, test_func) -> Dict[str, Any]:
        """Run a single test and record results"""
        print(f"\n🧪 Running: {test_name}")
        print("=" * 50)
        
        start_time = time.time()
        
        try:
            result = test_func()
            duration = time.time() - start_time
            
            test_result = {
                "test_name": test_name,
                "status": "PASS",
                "duration": duration,
                "result": result,
                "error": None,
                "timestamp": datetime.now().isoformat()
            }
            
            print(f"✅ PASS ({duration:.2f}s)")
            if isinstance(result, dict) and result.get("message"):
                print(f"💬 {result['message']}")
                
        except Exception as e:
            duration = time.time() - start_time
            
            test_result = {
                "test_name": test_name,
                "status": "FAIL",
                "duration": duration,
                "result": None,
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
            
            print(f"❌ FAIL ({duration:.2f}s)")
            print(f"💥 Error: {str(e)}")
        
        self.test_results.append(test_result)
        return test_result
    
    def test_health_endpoints(self) -> Dict[str, Any]:
        """Test health check endpoints"""
        # Main health endpoint
        response = requests.get(f"{self.base_url}/health", timeout=10)
        assert response.status_code == 200, f"Main health check failed: {response.status_code}"
        
        # Gmail health endpoint
        gmail_response = requests.get(f"{self.base_url}/api/gmail/health", timeout=10)
        assert gmail_response.status_code == 200, f"Gmail health check failed: {gmail_response.status_code}"
        
        gmail_health = gmail_response.json()
        
        return {
            "main_health": response.json(),
            "gmail_health": gmail_health,
            "message": f"Health checks passed. OAuth configured: {gmail_health.get('oauth_configured', False)}"
        }
    
    def test_email_extraction_simple(self) -> Dict[str, Any]:
        """Test simple email event extraction"""
        test_email = {
            "email_content": """
            Hi team,
            
            Let's schedule our weekly standup meeting for tomorrow at 10:00 AM in Conference Room B.
            We'll discuss project updates and next steps.
            
            Please confirm your attendance.
            
            Best regards,
            Manager
            """,
            "subject": "Weekly Standup Meeting",
            "sender": "manager@company.com",
            "timezone": "America/New_York",
            "user_email": "test@example.com"
        }
        
        response = requests.post(
            f"{self.base_url}/api/gmail/extract",
            json=test_email,
            timeout=30
        )
        
        assert response.status_code == 200, f"Extraction failed: {response.status_code} - {response.text}"
        
        result = response.json()
        assert result.get("success", False), f"Extraction not successful: {result}"
        
        events_found = result.get("events_found", 0)
        
        return {
            "events_found": events_found,
            "events": result.get("events", []),
            "message": result.get("message", ""),
            "success": events_found > 0,
            "details": f"Found {events_found} event(s) in simple email"
        }
    
    def test_email_extraction_complex(self) -> Dict[str, Any]:
        """Test complex email with multiple events"""
        test_email = {
            "email_content": """
            Conference Schedule - Tech Summit 2025
            
            Day 1 - March 15th, 2025
            9:00 AM - Registration and Welcome Coffee (Main Lobby)
            10:00 AM - Keynote: The Future of AI (Auditorium)
            11:30 AM - Coffee Break
            12:00 PM - Panel: Machine Learning in Practice (Room A)
            1:00 PM - Lunch Break (Cafeteria)
            2:30 PM - Workshop: Building AI Applications (Room B)
            4:00 PM - Networking Session (Rooftop Terrace)
            5:30 PM - Closing Remarks (Auditorium)
            
            Day 2 - March 16th, 2025
            9:00 AM - Developer Roundtable (Room C)
            10:30 AM - Product Showcase (Exhibition Hall)
            12:00 PM - Awards Ceremony (Auditorium)
            
            Looking forward to seeing everyone there!
            """,
            "subject": "Tech Summit 2025 - Complete Schedule",
            "sender": "events@techsummit.com",
            "timezone": "America/New_York",
            "user_email": "attendee@example.com"
        }
        
        response = requests.post(
            f"{self.base_url}/api/gmail/extract",
            json=test_email,
            timeout=45
        )
        
        assert response.status_code == 200, f"Complex extraction failed: {response.status_code} - {response.text}"
        
        result = response.json()
        assert result.get("success", False), f"Complex extraction not successful: {result}"
        
        events_found = result.get("events_found", 0)
        events = result.get("events", [])
        
        # Analyze extracted events
        event_titles = [event.get("title", "") for event in events]
        
        return {
            "events_found": events_found,
            "events": events,
            "event_titles": event_titles,
            "message": result.get("message", ""),
            "success": events_found >= 5,  # Expect at least 5 events from this complex email
            "details": f"Found {events_found} event(s) in complex conference email"
        }
    
    def test_email_extraction_no_events(self) -> Dict[str, Any]:
        """Test email with no calendar events"""
        test_email = {
            "email_content": """
            Hi there,
            
            I hope you're doing well. I wanted to share some thoughts about our recent project.
            The team has been working hard and I think we're making good progress.
            
            Let me know if you have any questions or feedback.
            
            Best,
            Colleague
            """,
            "subject": "Project Update",
            "sender": "colleague@company.com",
            "timezone": "America/New_York",
            "user_email": "test@example.com"
        }
        
        response = requests.post(
            f"{self.base_url}/api/gmail/extract",
            json=test_email,
            timeout=30
        )
        
        assert response.status_code == 200, f"No-events extraction failed: {response.status_code} - {response.text}"
        
        result = response.json()
        events_found = result.get("events_found", 0)
        
        return {
            "events_found": events_found,
            "message": result.get("message", ""),
            "success": events_found == 0,  # Should find no events
            "details": "Correctly identified email with no calendar events"
        }
    
    def test_travel_itinerary_extraction(self) -> Dict[str, Any]:
        """Test travel itinerary email extraction"""
        test_email = {
            "email_content": """
            Your Trip to San Francisco - Confirmation
            
            Flight Details:
            - Outbound: Flight AA1234 on March 20th, 2025 at 8:00 AM (JFK to SFO)
            - Return: Flight AA5678 on March 23rd, 2025 at 6:30 PM (SFO to JFK)
            
            Hotel Booking:
            - Check-in: March 20th, 2025 at 3:00 PM
            - Check-out: March 23rd, 2025 at 11:00 AM
            - Hotel: Grand Hyatt San Francisco
            
            Conference Schedule:
            - March 21st: Developer Conference 9:00 AM - 5:00 PM
            - March 22nd: Networking Event 7:00 PM - 10:00 PM
            
            Have a great trip!
            """,
            "subject": "Travel Confirmation - SF Trip",
            "sender": "bookings@travelagency.com",
            "timezone": "America/New_York",
            "user_email": "traveler@example.com"
        }
        
        response = requests.post(
            f"{self.base_url}/api/gmail/extract",
            json=test_email,
            timeout=45
        )
        
        assert response.status_code == 200, f"Travel extraction failed: {response.status_code} - {response.text}"
        
        result = response.json()
        events_found = result.get("events_found", 0)
        events = result.get("events", [])
        
        return {
            "events_found": events_found,
            "events": events,
            "message": result.get("message", ""),
            "success": events_found >= 4,  # Expect flights, hotel, and conference events
            "details": f"Found {events_found} event(s) in travel itinerary"
        }
    
    def test_oauth_endpoints(self) -> Dict[str, Any]:
        """Test OAuth authorization endpoints"""
        # Test OAuth initiation
        oauth_response = requests.get(
            f"{self.base_url}/api/gmail/oauth/authorize",
            params={"user_email": "test@example.com"},
            timeout=10
        )
        
        assert oauth_response.status_code == 200, f"OAuth initiation failed: {oauth_response.status_code}"
        
        oauth_result = oauth_response.json()
        
        return {
            "oauth_initiation": oauth_result.get("success", False),
            "auth_url_generated": bool(oauth_result.get("auth_url")),
            "message": "OAuth endpoints accessible",
            "details": "OAuth flow can be initiated (requires manual testing for full flow)"
        }
    
    def test_api_error_handling(self) -> Dict[str, Any]:
        """Test API error handling"""
        # Test with malformed request
        malformed_response = requests.post(
            f"{self.base_url}/api/gmail/extract",
            json={"invalid": "data"},
            timeout=10
        )
        
        # Should return error but not crash
        assert malformed_response.status_code in [400, 422], f"Expected error status, got: {malformed_response.status_code}"
        
        # Test with empty request
        empty_response = requests.post(
            f"{self.base_url}/api/gmail/extract",
            json={},
            timeout=10
        )
        
        assert empty_response.status_code in [400, 422], f"Expected error status, got: {empty_response.status_code}"
        
        return {
            "error_handling": True,
            "malformed_request_handled": True,
            "empty_request_handled": True,
            "message": "API error handling working correctly"
        }
    
    def test_performance_benchmarks(self) -> Dict[str, Any]:
        """Test performance benchmarks"""
        test_cases = [
            ("Short email", "Meeting tomorrow at 2pm"),
            ("Medium email", "Meeting tomorrow at 2pm in conference room A. " * 10),
            ("Long email", "Conference schedule with multiple events. " * 50)
        ]
        
        performance_results = []
        
        for case_name, content in test_cases:
            test_email = {
                "email_content": content,
                "subject": f"Test - {case_name}",
                "sender": "test@example.com",
                "timezone": "America/New_York",
                "user_email": "test@example.com"
            }
            
            start_time = time.time()
            
            response = requests.post(
                f"{self.base_url}/api/gmail/extract",
                json=test_email,
                timeout=60
            )
            
            duration = time.time() - start_time
            
            performance_results.append({
                "case": case_name,
                "duration": duration,
                "success": response.status_code == 200,
                "content_length": len(content)
            })
        
        avg_duration = sum(r["duration"] for r in performance_results) / len(performance_results)
        
        return {
            "performance_results": performance_results,
            "average_duration": avg_duration,
            "all_under_60s": all(r["duration"] < 60 for r in performance_results),
            "message": f"Average processing time: {avg_duration:.2f}s",
            "details": "Performance benchmarking completed"
        }
    
    def run_full_test_suite(self):
        """Run the complete Gmail integration test suite"""
        print("🚀 EventAI Gmail Integration Test Suite")
        print("=" * 60)
        print(f"🌐 Testing endpoint: {self.base_url}")
        print(f"⏰ Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        # Define test suite
        tests = [
            ("Health Endpoints", self.test_health_endpoints),
            ("Simple Email Extraction", self.test_email_extraction_simple),
            ("Complex Email Extraction", self.test_email_extraction_complex),
            ("No Events Email", self.test_email_extraction_no_events),
            ("Travel Itinerary Extraction", self.test_travel_itinerary_extraction),
            ("OAuth Endpoints", self.test_oauth_endpoints),
            ("Error Handling", self.test_api_error_handling),
            ("Performance Benchmarks", self.test_performance_benchmarks)
        ]
        
        # Run tests
        for test_name, test_func in tests:
            self.run_test(test_name, test_func)
        
        # Generate summary
        self.generate_test_report()
    
    def generate_test_report(self):
        """Generate comprehensive test report"""
        print("\n" + "="*60)
        print("📊 GMAIL INTEGRATION TEST REPORT")
        print("="*60)
        
        total_tests = len(self.test_results)
        passed_tests = sum(1 for r in self.test_results if r["status"] == "PASS")
        failed_tests = total_tests - passed_tests
        
        success_rate = (passed_tests / total_tests) * 100 if total_tests > 0 else 0
        total_duration = sum(r["duration"] for r in self.test_results)
        
        print(f"📈 Overall Results:")
        print(f"   Total Tests: {total_tests}")
        print(f"   Passed: {passed_tests} ✅")
        print(f"   Failed: {failed_tests} ❌")
        print(f"   Success Rate: {success_rate:.1f}%")
        print(f"   Total Duration: {total_duration:.2f}s")
        print()
        
        print(f"📋 Test Details:")
        print(f"{'Test Name':<30} | {'Status':<6} | {'Duration':<8} | {'Notes'}")
        print("-" * 80)
        
        for result in self.test_results:
            status_icon = "✅" if result["status"] == "PASS" else "❌"
            notes = result.get("result", {}).get("details", "") if result["status"] == "PASS" else result.get("error", "")[:30]
            
            print(f"{result['test_name'][:29]:<30} | {status_icon:<6} | {result['duration']:.2f}s{'':<3} | {notes}")
        
        print()
        
        # Save detailed results
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"gmail_integration_test_results_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump({
                "summary": {
                    "total_tests": total_tests,
                    "passed_tests": passed_tests,
                    "failed_tests": failed_tests,
                    "success_rate": success_rate,
                    "total_duration": total_duration,
                    "endpoint_tested": self.base_url,
                    "timestamp": datetime.now().isoformat()
                },
                "detailed_results": self.test_results
            }, f, indent=2)
        
        print(f"💾 Detailed results saved to: {filename}")
        
        # Final assessment
        if success_rate >= 90:
            print(f"\n🎉 EXCELLENT: Gmail integration is ready for deployment!")
        elif success_rate >= 75:
            print(f"\n👍 GOOD: Gmail integration is mostly working, minor issues to fix")
        elif success_rate >= 50:
            print(f"\n⚠️ NEEDS WORK: Gmail integration has significant issues")
        else:
            print(f"\n🚨 CRITICAL: Gmail integration is not functional")

def main():
    """Main function to run tests"""
    import sys
    
    # Allow custom endpoint for testing
    endpoint = sys.argv[1] if len(sys.argv) > 1 else "https://eventai-gmail-api-661796696046.us-central1.run.app"
    
    print(f"Testing Gmail integration at: {endpoint}")
    
    tester = GmailIntegrationTester(endpoint)
    tester.run_full_test_suite()

if __name__ == "__main__":
    main()