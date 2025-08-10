"""
BigQuery Database Service for EventAI
Handles persistent storage of user data, usage tracking, and subscriptions
"""

import os
import hashlib
from datetime import datetime, date, timezone, timedelta
from typing import Dict, Optional, List, Any
from google.cloud import bigquery
from google.cloud.exceptions import NotFound
import pytz
import json
import uuid

class BigQueryService:
    def __init__(self):
        # Initialize BigQuery client
        # This will use the service account credentials from the environment
        self.client = bigquery.Client(project="levelup-467902")
        self.dataset_id = "eventai"
        self.project_id = "levelup-467902"
        
        # Ensure dataset exists
        self._ensure_dataset_exists()
        
        print(f"🗃️ BigQuery service initialized for project: {self.project_id}, dataset: {self.dataset_id}")
    
    def _ensure_dataset_exists(self):
        """Create the EventAI dataset if it doesn't exist"""
        dataset_ref = self.client.dataset(self.dataset_id)
        
        try:
            self.client.get_dataset(dataset_ref)
            print(f"✅ BigQuery dataset '{self.dataset_id}' exists")
        except NotFound:
            print(f"🔄 Creating BigQuery dataset '{self.dataset_id}'...")
            dataset = bigquery.Dataset(dataset_ref)
            dataset.location = "US"  # Use US multi-region for better performance
            dataset.description = "EventAI application data - usage tracking, subscriptions, and analytics"
            
            self.client.create_dataset(dataset, timeout=30)
            print(f"✅ Created BigQuery dataset '{self.dataset_id}'")
    
    def _get_table_id(self, table_name: str) -> str:
        """Get fully qualified table ID"""
        return f"{self.project_id}.{self.dataset_id}.{table_name}"
    
    def _execute_query(self, query: str, parameters: List = None) -> List[Dict]:
        """Execute a query and return results"""
        try:
            job_config = bigquery.QueryJobConfig()
            if parameters:
                job_config.query_parameters = parameters
            
            query_job = self.client.query(query, job_config=job_config)
            results = query_job.result()
            
            return [dict(row) for row in results]
        except Exception as e:
            print(f"❌ BigQuery query error: {e}")
            print(f"Query: {query}")
            raise
    
    def get_or_create_user(self, user_id: str, device_id: str = None, apple_id: str = None, 
                          user_agent: str = None, ip_address: str = None, timezone_str: str = None) -> Dict:
        """Get existing user or create new user record"""
        # Check if user exists
        query = f"""
        SELECT user_id, device_id, apple_id, first_seen, last_seen, timezone
        FROM `{self._get_table_id('users')}`
        WHERE user_id = @user_id
        LIMIT 1
        """
        
        parameters = [
            bigquery.ScalarQueryParameter("user_id", "STRING", user_id)
        ]
        
        results = self._execute_query(query, parameters)
        
        if results:
            # Update last_seen timestamp
            update_query = f"""
            UPDATE `{self._get_table_id('users')}`
            SET last_seen = CURRENT_TIMESTAMP(),
                updated_at = CURRENT_TIMESTAMP()
            WHERE user_id = @user_id
            """
            self._execute_query(update_query, parameters)
            
            return results[0]
        else:
            # Create new user
            insert_query = f"""
            INSERT INTO `{self._get_table_id('users')}`
            (user_id, device_id, apple_id, user_agent, ip_address, timezone, first_seen, last_seen, created_at, updated_at)
            VALUES (@user_id, @device_id, @apple_id, @user_agent, @ip_address, @timezone, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())
            """
            
            insert_parameters = [
                bigquery.ScalarQueryParameter("user_id", "STRING", user_id),
                bigquery.ScalarQueryParameter("device_id", "STRING", device_id),
                bigquery.ScalarQueryParameter("apple_id", "STRING", apple_id),
                bigquery.ScalarQueryParameter("user_agent", "STRING", user_agent),
                bigquery.ScalarQueryParameter("ip_address", "STRING", ip_address),
                bigquery.ScalarQueryParameter("timezone", "STRING", timezone_str)
            ]
            
            self._execute_query(insert_query, insert_parameters)
            
            print(f"👤 Created new user: {user_id[:8]}... with device_id: {device_id[:8] if device_id else 'None'}")
            
            return {
                "user_id": user_id,
                "device_id": device_id,
                "apple_id": apple_id,
                "first_seen": datetime.now(timezone.utc),
                "last_seen": datetime.now(timezone.utc),
                "timezone": timezone_str
            }
    
    def get_user_usage(self, user_id: str, usage_date: date = None) -> Dict:
        """Get user's usage for a specific date (defaults to today in ET)"""
        if not usage_date:
            # Use today in Eastern Time (our reset timezone)
            et_tz = pytz.timezone('America/New_York')
            usage_date = datetime.now(et_tz).date()
        
        query = f"""
        SELECT user_id, usage_date, conversion_count, reset_timezone, created_at, updated_at
        FROM `{self._get_table_id('usage_tracking')}`
        WHERE user_id = @user_id AND usage_date = @usage_date
        LIMIT 1
        """
        
        parameters = [
            bigquery.ScalarQueryParameter("user_id", "STRING", user_id),
            bigquery.ScalarQueryParameter("usage_date", "DATE", usage_date)
        ]
        
        results = self._execute_query(query, parameters)
        
        if results:
            return results[0]
        else:
            # Create initial usage record for this date
            insert_query = f"""
            INSERT INTO `{self._get_table_id('usage_tracking')}`
            (user_id, usage_date, conversion_count, reset_timezone, created_at, updated_at)
            VALUES (@user_id, @usage_date, 0, 'America/New_York', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())
            """
            
            self._execute_query(insert_query, parameters)
            
            return {
                "user_id": user_id,
                "usage_date": usage_date,
                "conversion_count": 0,
                "reset_timezone": "America/New_York",
                "created_at": datetime.now(timezone.utc),
                "updated_at": datetime.now(timezone.utc)
            }
    
    def increment_usage(self, user_id: str, usage_date: date = None) -> int:
        """Increment user's conversion count for the date"""
        if not usage_date:
            et_tz = pytz.timezone('America/New_York')
            usage_date = datetime.now(et_tz).date()
        
        # First ensure the record exists
        self.get_user_usage(user_id, usage_date)
        
        # Then increment
        update_query = f"""
        UPDATE `{self._get_table_id('usage_tracking')}`
        SET conversion_count = conversion_count + 1,
            updated_at = CURRENT_TIMESTAMP()
        WHERE user_id = @user_id AND usage_date = @usage_date
        """
        
        parameters = [
            bigquery.ScalarQueryParameter("user_id", "STRING", user_id),
            bigquery.ScalarQueryParameter("usage_date", "DATE", usage_date)
        ]
        
        self._execute_query(update_query, parameters)
        
        # Return updated count
        usage = self.get_user_usage(user_id, usage_date)
        new_count = usage["conversion_count"]
        
        print(f"📊 User {user_id[:8]}... usage incremented to {new_count} for {usage_date}")
        return new_count
    
    def is_user_premium(self, user_id: str) -> bool:
        """Check if user has active premium subscription"""
        query = f"""
        SELECT subscription_id, is_active, subscription_end, auto_renew
        FROM `{self._get_table_id('subscriptions')}`
        WHERE user_id = @user_id 
        AND is_active = TRUE 
        AND (subscription_end IS NULL OR subscription_end > CURRENT_TIMESTAMP())
        ORDER BY created_at DESC
        LIMIT 1
        """
        
        parameters = [
            bigquery.ScalarQueryParameter("user_id", "STRING", user_id)
        ]
        
        results = self._execute_query(query, parameters)
        return len(results) > 0
    
    def create_subscription(self, user_id: str, product_id: str, device_id: str = None,
                           apple_receipt_data: str = None, subscription_days: int = 30) -> str:
        """Create new premium subscription"""
        subscription_id = str(uuid.uuid4())
        subscription_start = datetime.now(timezone.utc)
        subscription_end = subscription_start + timedelta(days=subscription_days)
        
        query = f"""
        INSERT INTO `{self._get_table_id('subscriptions')}`
        (user_id, subscription_id, product_id, device_id, apple_receipt_data, is_active, 
         subscription_start, subscription_end, auto_renew, created_at, updated_at)
        VALUES (@user_id, @subscription_id, @product_id, @device_id, @apple_receipt_data, 
                TRUE, @subscription_start, @subscription_end, TRUE, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP())
        """
        
        parameters = [
            bigquery.ScalarQueryParameter("user_id", "STRING", user_id),
            bigquery.ScalarQueryParameter("subscription_id", "STRING", subscription_id),
            bigquery.ScalarQueryParameter("product_id", "STRING", product_id),
            bigquery.ScalarQueryParameter("device_id", "STRING", device_id),
            bigquery.ScalarQueryParameter("apple_receipt_data", "STRING", apple_receipt_data),
            bigquery.ScalarQueryParameter("subscription_start", "TIMESTAMP", subscription_start),
            bigquery.ScalarQueryParameter("subscription_end", "TIMESTAMP", subscription_end)
        ]
        
        self._execute_query(query, parameters)
        
        print(f"💎 Created premium subscription for user {user_id[:8]}... (expires: {subscription_end.date()})")
        return subscription_id
    
    def log_conversion_event(self, user_id: str, request_text: str, has_image: bool = False,
                            events_found: int = 0, success: bool = True, error_message: str = None,
                            timezone_str: str = None, user_location: str = None, 
                            processing_time_ms: int = None) -> str:
        """Log a conversion event for analytics"""
        event_id = str(uuid.uuid4())
        
        query = f"""
        INSERT INTO `{self._get_table_id('conversion_events')}`
        (event_id, user_id, request_text, has_image, events_found, success, error_message,
         timezone, user_location, processing_time_ms, created_at)
        VALUES (@event_id, @user_id, @request_text, @has_image, @events_found, @success,
                @error_message, @timezone, @user_location, @processing_time_ms, CURRENT_TIMESTAMP())
        """
        
        parameters = [
            bigquery.ScalarQueryParameter("event_id", "STRING", event_id),
            bigquery.ScalarQueryParameter("user_id", "STRING", user_id),
            bigquery.ScalarQueryParameter("request_text", "STRING", request_text),
            bigquery.ScalarQueryParameter("has_image", "BOOL", has_image),
            bigquery.ScalarQueryParameter("events_found", "INT64", events_found),
            bigquery.ScalarQueryParameter("success", "BOOL", success),
            bigquery.ScalarQueryParameter("error_message", "STRING", error_message),
            bigquery.ScalarQueryParameter("timezone", "STRING", timezone_str),
            bigquery.ScalarQueryParameter("user_location", "STRING", user_location),
            bigquery.ScalarQueryParameter("processing_time_ms", "INT64", processing_time_ms)
        ]
        
        self._execute_query(query, parameters)
        return event_id
    
    def log_app_event(self, user_id: str, event_type: str, event_data: Dict = None,
                     device_info: Dict = None, app_version: str = None) -> str:
        """Log app events for analytics and engagement tracking"""
        event_id = str(uuid.uuid4())
        
        query = f"""
        INSERT INTO `{self._get_table_id('app_events')}`
        (event_id, user_id, event_type, event_data, device_info, app_version, created_at)
        VALUES (@event_id, @user_id, @event_type, @event_data, @device_info, @app_version, CURRENT_TIMESTAMP())
        """
        
        parameters = [
            bigquery.ScalarQueryParameter("event_id", "STRING", event_id),
            bigquery.ScalarQueryParameter("user_id", "STRING", user_id),
            bigquery.ScalarQueryParameter("event_type", "STRING", event_type),
            bigquery.ScalarQueryParameter("event_data", "JSON", json.dumps(event_data) if event_data else None),
            bigquery.ScalarQueryParameter("device_info", "JSON", json.dumps(device_info) if device_info else None),
            bigquery.ScalarQueryParameter("app_version", "STRING", app_version)
        ]
        
        self._execute_query(query, parameters)
        return event_id

# Global instance
bigquery_service = None

def get_bigquery_service() -> BigQueryService:
    """Get the global BigQuery service instance"""
    global bigquery_service
    if bigquery_service is None:
        bigquery_service = BigQueryService()
    return bigquery_service