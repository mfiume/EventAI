"""
Firestore Database Service for EventAI
Handles fast real-time storage of user data, usage tracking, and subscriptions
Replacement for BigQuery to achieve sub-second response times
"""

import os
import hashlib
from datetime import datetime, date, timezone, timedelta
from typing import Dict, Optional, List, Any
from google.cloud import firestore
from google.cloud.exceptions import NotFound
import pytz
import json
import uuid

class FirestoreService:
    def __init__(self):
        # Initialize Firestore client for Native mode database
        # This will use the service account credentials from the environment
        self.client = firestore.Client(project="levelup-467902", database="eventai-native")
        
        # Collection names
        self.users_collection = "users"
        self.usage_collection = "usage_tracking"
        self.subscriptions_collection = "subscriptions"
        self.conversion_events_collection = "conversion_events"
        self.app_events_collection = "app_events"
        self.api_keys_collection = "api_keys"
        
        print(f"🔥 Firestore service initialized for project: levelup-467902")
    
    def get_or_create_user(self, user_id: str, device_id: str = None, apple_id: str = None, 
                          user_agent: str = None, ip_address: str = None, timezone_str: str = None) -> Dict:
        """Get existing user or create new user record"""
        user_ref = self.client.collection(self.users_collection).document(user_id)
        user_doc = user_ref.get()
        
        current_time = datetime.now(timezone.utc)
        
        if user_doc.exists:
            # Update last_seen timestamp
            user_ref.update({
                "last_seen": current_time,
                "updated_at": current_time
            })
            
            user_data = user_doc.to_dict()
            return user_data
        else:
            # Create new user
            user_data = {
                "user_id": user_id,
                "device_id": device_id,
                "apple_id": apple_id,
                "user_agent": user_agent,
                "ip_address": ip_address,
                "timezone": timezone_str,
                "first_seen": current_time,
                "last_seen": current_time,
                "created_at": current_time,
                "updated_at": current_time
            }
            
            user_ref.set(user_data)
            print(f"👤 Created new user: {user_id[:8]}... with device_id: {device_id[:8] if device_id else 'None'}")
            
            return user_data
    
    def get_user_usage(self, user_id: str, usage_date: date = None) -> Dict:
        """Get user's usage for a specific date (defaults to today in ET)"""
        if not usage_date:
            # Use today in Eastern Time (our reset timezone)
            et_tz = pytz.timezone('America/New_York')
            usage_date = datetime.now(et_tz).date()
        
        # Create usage document path: users/{user_id}/usage/{date}
        usage_ref = (self.client.collection(self.users_collection)
                     .document(user_id)
                     .collection("usage")
                     .document(usage_date.isoformat()))
        
        usage_doc = usage_ref.get()
        
        if usage_doc.exists:
            return usage_doc.to_dict()
        else:
            # Create initial usage record for this date
            usage_data = {
                "user_id": user_id,
                "usage_date": usage_date.isoformat(),
                "conversion_count": 0,
                "reset_timezone": "America/New_York",
                "created_at": datetime.now(timezone.utc),
                "updated_at": datetime.now(timezone.utc)
            }
            
            usage_ref.set(usage_data)
            return usage_data
    
    def increment_usage(self, user_id: str, usage_date: date = None) -> int:
        """Increment user's conversion count for the date using atomic transaction"""
        if not usage_date:
            et_tz = pytz.timezone('America/New_York')
            usage_date = datetime.now(et_tz).date()
        
        usage_ref = (self.client.collection(self.users_collection)
                     .document(user_id)
                     .collection("usage")
                     .document(usage_date.isoformat()))
        
        # Use transaction for atomic increment
        @firestore.transactional
        def increment_count(transaction, usage_ref):
            usage_doc = usage_ref.get(transaction=transaction)
            
            if usage_doc.exists:
                current_count = usage_doc.get("conversion_count") or 0
                new_count = current_count + 1
                transaction.update(usage_ref, {
                    "conversion_count": new_count,
                    "updated_at": datetime.now(timezone.utc)
                })
            else:
                # First conversion for this date
                new_count = 1
                usage_data = {
                    "user_id": user_id,
                    "usage_date": usage_date.isoformat(),
                    "conversion_count": new_count,
                    "reset_timezone": "America/New_York",
                    "created_at": datetime.now(timezone.utc),
                    "updated_at": datetime.now(timezone.utc)
                }
                transaction.set(usage_ref, usage_data)
            
            return new_count
        
        # Execute transaction
        transaction = self.client.transaction()
        new_count = increment_count(transaction, usage_ref)
        
        print(f"📊 User {user_id[:8]}... usage incremented to {new_count} for {usage_date}")
        return new_count
    
    def is_user_premium(self, user_id: str) -> bool:
        """Check if user has active premium subscription"""
        current_time = datetime.now(timezone.utc)
        
        # Simplified query - just get active subscriptions and check manually
        # This avoids complex index requirements
        subscriptions = (self.client.collection(self.users_collection)
                        .document(user_id)
                        .collection("subscriptions")
                        .where("is_active", "==", True)
                        .get())
        
        # Check if any subscription is still valid
        for sub in subscriptions:
            sub_data = sub.to_dict()
            subscription_end = sub_data.get("subscription_end")
            if subscription_end and subscription_end > current_time:
                return True
        
        return False
    
    def create_subscription(self, user_id: str, product_id: str, device_id: str = None,
                           apple_receipt_data: str = None, subscription_days: int = 30,
                           apple_transaction_id: str = None, apple_original_transaction_id: str = None) -> str:
        """Create new premium subscription"""
        subscription_id = str(uuid.uuid4())
        subscription_start = datetime.now(timezone.utc)
        subscription_end = subscription_start + timedelta(days=subscription_days)
        
        subscription_data = {
            "subscription_id": subscription_id,
            "user_id": user_id,
            "product_id": product_id,
            "device_id": device_id,
            "apple_receipt_data": apple_receipt_data,
            "apple_transaction_id": apple_transaction_id,
            "apple_original_transaction_id": apple_original_transaction_id,
            "is_active": True,
            "subscription_start": subscription_start,
            "subscription_end": subscription_end,
            "auto_renew": True,
            "created_at": subscription_start,
            "updated_at": subscription_start
        }
        
        # Store in user's subscriptions subcollection
        subscription_ref = (self.client.collection(self.users_collection)
                           .document(user_id)
                           .collection("subscriptions")
                           .document(subscription_id))
        
        subscription_ref.set(subscription_data)
        
        print(f"💎 Created premium subscription for user {user_id[:8]}... (expires: {subscription_end.date()})")
        return subscription_id
    
    def log_conversion_event(self, user_id: str, request_text: str, has_image: bool = False,
                            events_found: int = 0, success: bool = True, error_message: str = None,
                            timezone_str: str = None, user_location: str = None, 
                            processing_time_ms: int = None) -> str:
        """Log a conversion event for analytics"""
        event_id = str(uuid.uuid4())
        
        event_data = {
            "event_id": event_id,
            "user_id": user_id,
            "request_text": request_text,
            "has_image": has_image,
            "events_found": events_found,
            "success": success,
            "error_message": error_message,
            "timezone": timezone_str,
            "user_location": user_location,
            "processing_time_ms": processing_time_ms,
            "created_at": datetime.now(timezone.utc)
        }
        
        # Store in both user's events and global events collection for analytics
        user_event_ref = (self.client.collection(self.users_collection)
                          .document(user_id)
                          .collection("conversion_events")
                          .document(event_id))
        
        global_event_ref = self.client.collection(self.conversion_events_collection).document(event_id)
        
        # Use batch write for consistency
        batch = self.client.batch()
        batch.set(user_event_ref, event_data)
        batch.set(global_event_ref, event_data)
        batch.commit()
        
        return event_id
    
    def log_app_event(self, user_id: str, event_type: str, event_data: Dict = None,
                     device_info: Dict = None, app_version: str = None) -> str:
        """Log app events for analytics and engagement tracking"""
        event_id = str(uuid.uuid4())
        
        app_event_data = {
            "event_id": event_id,
            "user_id": user_id,
            "event_type": event_type,
            "event_data": event_data,
            "device_info": device_info,
            "app_version": app_version,
            "created_at": datetime.now(timezone.utc)
        }
        
        # Store in both user's events and global events collection
        user_event_ref = (self.client.collection(self.users_collection)
                          .document(user_id)
                          .collection("app_events")
                          .document(event_id))
        
        global_event_ref = self.client.collection(self.app_events_collection).document(event_id)
        
        # Use batch write for consistency
        batch = self.client.batch()
        batch.set(user_event_ref, app_event_data)
        batch.set(global_event_ref, app_event_data)
        batch.commit()
        
        return event_id
    
    def get_user_analytics(self, user_id: str, days: int = 30) -> Dict:
        """Get user analytics for the last N days"""
        cutoff_date = datetime.now(timezone.utc) - timedelta(days=days)
        
        # Get recent conversion events
        conversion_events = (self.client.collection(self.users_collection)
                           .document(user_id)
                           .collection("conversion_events")
                           .where("created_at", ">", cutoff_date)
                           .order_by("created_at", direction=firestore.Query.DESCENDING)
                           .get())
        
        # Get recent app events
        app_events = (self.client.collection(self.users_collection)
                     .document(user_id)
                     .collection("app_events")
                     .where("created_at", ">", cutoff_date)
                     .order_by("created_at", direction=firestore.Query.DESCENDING)
                     .get())
        
        return {
            "conversion_events": [event.to_dict() for event in conversion_events],
            "app_events": [event.to_dict() for event in app_events],
            "total_conversions": len(conversion_events),
            "total_app_events": len(app_events)
        }
    
    def migrate_user_from_bigquery(self, bq_user_data: Dict, bq_usage_data: List[Dict] = None, 
                                  bq_subscriptions: List[Dict] = None) -> bool:
        """Migrate a single user's data from BigQuery to Firestore"""
        try:
            user_id = bq_user_data["user_id"]
            
            # 1. Migrate user profile
            user_ref = self.client.collection(self.users_collection).document(user_id)
            user_ref.set(bq_user_data)
            
            # 2. Migrate usage data
            if bq_usage_data:
                batch = self.client.batch()
                for usage in bq_usage_data:
                    usage_date = usage["usage_date"]
                    if isinstance(usage_date, str):
                        usage_date_str = usage_date
                    else:
                        usage_date_str = usage_date.isoformat()
                    
                    usage_ref = (user_ref
                               .collection("usage")
                               .document(usage_date_str))
                    
                    batch.set(usage_ref, usage)
                batch.commit()
            
            # 3. Migrate subscriptions
            if bq_subscriptions:
                batch = self.client.batch()
                for subscription in bq_subscriptions:
                    subscription_ref = (user_ref
                                      .collection("subscriptions")
                                      .document(subscription["subscription_id"]))
                    batch.set(subscription_ref, subscription)
                batch.commit()
            
            print(f"✅ Migrated user {user_id[:8]}... to Firestore")
            return True
            
        except Exception as e:
            print(f"❌ Failed to migrate user {user_id[:8]}...: {e}")
            return False
    
    def validate_api_key(self, api_key: str) -> Dict:
        """Validate API key against Firestore (FAST) - replaces BigQuery validation"""
        if not api_key or not api_key.startswith('eak_'):
            return {"valid": False, "error": "Invalid API key format"}
        
        try:
            # Query Firestore for API key (sub-second response)
            key_ref = self.client.collection(self.api_keys_collection).document(api_key)
            key_doc = key_ref.get()
            
            if not key_doc.exists:
                return {"valid": False, "error": "API key not found"}
            
            key_data = key_doc.to_dict()
            
            # Check if key is active
            if not key_data.get("is_active", True):
                return {"valid": False, "error": "API key is inactive"}
            
            # Check expiration if set
            expires_at = key_data.get("expires_at")
            if expires_at and expires_at < datetime.now(timezone.utc):
                return {"valid": False, "error": "API key has expired"}
            
            # Update last_used timestamp
            key_ref.update({
                "last_used": datetime.now(timezone.utc),
                "usage_count": firestore.Increment(1)
            })
            
            return {
                "valid": True,
                "key_id": api_key,
                "key_name": key_data.get("key_name", "Unknown"),
                "permissions": key_data.get("permissions", ["usage", "convert"]),
                "rate_limit": key_data.get("rate_limit", 1000),
                "free_daily_limit": key_data.get("free_daily_limit"),  # Custom free daily limit
                "premium_daily_limit": key_data.get("premium_daily_limit"),  # Custom premium daily limit
                "environment": key_data.get("environment", "production")
            }
            
        except Exception as e:
            print(f"❌ API key validation error: {e}")
            return {"valid": False, "error": "Validation service error"}
    
    def create_development_api_key(self, key_name: str, free_limit: int = 100, premium_limit: int = 200) -> str:
        """Create a development API key with custom daily limits"""
        import secrets
        
        # Generate secure API key
        key_suffix = secrets.token_hex(32)  # 64 character hex string
        api_key = f"eak_{key_suffix}"
        
        key_data = {
            "key_id": api_key,
            "key_name": key_name,
            "environment": "development",
            "permissions": ["usage", "convert", "subscription", "admin"],
            "rate_limit": 10000,  # Higher rate limit for development
            "free_daily_limit": free_limit,  # Custom free daily limit
            "premium_daily_limit": premium_limit,  # Custom premium daily limit
            "is_active": True,
            "created_at": datetime.now(timezone.utc),
            "expires_at": None,  # No expiration for dev keys
            "last_used": None,
            "usage_count": 0,
            "created_by": "development_system"
        }
        
        # Store in Firestore
        key_ref = self.client.collection(self.api_keys_collection).document(api_key)
        key_ref.set(key_data)
        
        print(f"🔑 Created development API key: {key_name}")
        print(f"   Key: {api_key}")
        print(f"   Free daily limit: {free_limit}")
        print(f"   Premium daily limit: {premium_limit}")
        
        return api_key
    
    def create_api_key(self, key_name: str, permissions: List[str] = None, 
                      rate_limit: int = 1000, expires_days: int = None) -> str:
        """Create a new API key in Firestore"""
        import secrets
        
        # Generate secure API key
        api_key = "eak_" + secrets.token_hex(32)
        
        if permissions is None:
            permissions = ["usage", "convert", "subscription"]
        
        expires_at = None
        if expires_days:
            expires_at = datetime.now(timezone.utc) + timedelta(days=expires_days)
        
        key_data = {
            "key_id": api_key,
            "key_name": key_name,
            "permissions": permissions,
            "rate_limit": rate_limit,
            "is_active": True,
            "created_at": datetime.now(timezone.utc),
            "expires_at": expires_at,
            "last_used": None,
            "usage_count": 0
        }
        
        # Store in Firestore
        key_ref = self.client.collection(self.api_keys_collection).document(api_key)
        key_ref.set(key_data)
        
        print(f"🔑 Created API key: {key_name} ({api_key[:12]}...)")
        return api_key
    
    def migrate_api_keys_from_bigquery(self, bq_service) -> int:
        """Migrate API keys from BigQuery to Firestore"""
        try:
            # Get all API keys from BigQuery
            query = f"""
            SELECT api_key, key_name, permissions, rate_limit, is_active, 
                   created_at, expires_at, last_used, usage_count
            FROM `{bq_service.project_id}.{bq_service.dataset_id}.api_keys`
            ORDER BY created_at DESC
            """
            api_keys = bq_service._execute_query(query)
            
            migrated_count = 0
            batch = self.client.batch()
            
            for key_data in api_keys:
                api_key = key_data["api_key"]
                
                # Convert BigQuery data to Firestore format
                firestore_data = {
                    "key_id": api_key,
                    "key_name": key_data.get("key_name", "Migrated Key"),
                    "permissions": key_data.get("permissions", ["usage", "convert"]),
                    "rate_limit": key_data.get("rate_limit", 1000),
                    "is_active": key_data.get("is_active", True),
                    "created_at": key_data.get("created_at", datetime.now(timezone.utc)),
                    "expires_at": key_data.get("expires_at"),
                    "last_used": key_data.get("last_used"),
                    "usage_count": key_data.get("usage_count", 0)
                }
                
                # Add to batch
                key_ref = self.client.collection(self.api_keys_collection).document(api_key)
                batch.set(key_ref, firestore_data)
                migrated_count += 1
            
            # Commit batch
            batch.commit()
            print(f"✅ Migrated {migrated_count} API keys from BigQuery to Firestore")
            return migrated_count
            
        except Exception as e:
            print(f"❌ Failed to migrate API keys: {e}")
            return 0

# Global instance
firestore_service = None

def get_firestore_service() -> FirestoreService:
    """Get the global Firestore service instance"""
    global firestore_service
    if firestore_service is None:
        firestore_service = FirestoreService()
    return firestore_service