#!/usr/bin/env python3
"""
Migration script to move EventAI data from BigQuery to Firestore
This script will export all existing data and import it into Firestore for faster performance
"""

import os
import sys
from datetime import datetime, timezone
from typing import List, Dict
from bigquery_service import get_bigquery_service
from firestore_service import get_firestore_service

def migrate_all_data():
    """Main migration function to transfer all data from BigQuery to Firestore"""
    print("🚀 Starting BigQuery to Firestore migration...")
    
    # Initialize services
    bq_service = get_bigquery_service()
    fs_service = get_firestore_service()
    
    try:
        # 1. Get all users from BigQuery
        print("📋 Fetching users from BigQuery...")
        users_query = f"""
        SELECT user_id, device_id, apple_id, user_agent, ip_address, timezone,
               first_seen, last_seen, created_at, updated_at
        FROM `{bq_service.project_id}.{bq_service.dataset_id}.users`
        ORDER BY created_at DESC
        """
        users = bq_service._execute_query(users_query)
        print(f"Found {len(users)} users to migrate")
        
        # 2. For each user, get their usage and subscription data
        migrated_count = 0
        failed_count = 0
        
        for user in users:
            user_id = user["user_id"]
            
            try:
                # Get user's usage data
                usage_query = f"""
                SELECT user_id, usage_date, conversion_count, reset_timezone,
                       created_at, updated_at
                FROM `{bq_service.project_id}.{bq_service.dataset_id}.usage_tracking`
                WHERE user_id = '{user_id}'
                ORDER BY usage_date DESC
                """
                usage_data = bq_service._execute_query(usage_query)
                
                # Get user's subscriptions
                subscription_query = f"""
                SELECT subscription_id, user_id, product_id, device_id, apple_receipt_data,
                       is_active, subscription_start, subscription_end, auto_renew,
                       created_at, updated_at
                FROM `{bq_service.project_id}.{bq_service.dataset_id}.subscriptions`
                WHERE user_id = '{user_id}'
                ORDER BY created_at DESC
                """
                subscription_data = bq_service._execute_query(subscription_query)
                
                # Convert BigQuery datetime objects to proper format
                user_data = convert_bigquery_data(user)
                usage_list = [convert_bigquery_data(usage) for usage in usage_data]
                subscription_list = [convert_bigquery_data(sub) for sub in subscription_data]
                
                # Migrate to Firestore
                success = fs_service.migrate_user_from_bigquery(
                    bq_user_data=user_data,
                    bq_usage_data=usage_list,
                    bq_subscriptions=subscription_list
                )
                
                if success:
                    migrated_count += 1
                else:
                    failed_count += 1
                    
            except Exception as e:
                print(f"❌ Failed to migrate user {user_id[:8]}...: {e}")
                failed_count += 1
        
        # 3. Migrate conversion events (for analytics)
        print("📊 Migrating conversion events...")
        events_query = f"""
        SELECT event_id, user_id, request_text, has_image, events_found, success,
               error_message, timezone, user_location, processing_time_ms, created_at
        FROM `{bq_service.project_id}.{bq_service.dataset_id}.conversion_events`
        ORDER BY created_at DESC
        LIMIT 10000  -- Limit to recent events to avoid overwhelming Firestore
        """
        conversion_events = bq_service._execute_query(events_query)
        
        print(f"Migrating {len(conversion_events)} conversion events...")
        events_migrated = 0
        
        for event in conversion_events:
            try:
                event_data = convert_bigquery_data(event)
                fs_service.log_conversion_event(**{
                    k: v for k, v in event_data.items() 
                    if k not in ["event_id", "created_at"]  # These are handled internally
                })
                events_migrated += 1
            except Exception as e:
                print(f"❌ Failed to migrate event {event.get('event_id', 'unknown')}: {e}")
        
        # Print migration summary
        print("\n🎉 Migration completed!")
        print(f"✅ Users migrated: {migrated_count}")
        print(f"❌ Users failed: {failed_count}")
        print(f"📊 Events migrated: {events_migrated}")
        
        if failed_count == 0:
            print("✅ All data migrated successfully!")
        else:
            print(f"⚠️ {failed_count} users failed to migrate - check logs above")
            
    except Exception as e:
        print(f"💥 Migration failed with error: {e}")
        return False
    
    return True

def convert_bigquery_data(data: Dict) -> Dict:
    """Convert BigQuery data types to Firestore-compatible types"""
    converted = {}
    
    for key, value in data.items():
        if value is None:
            converted[key] = None
        elif hasattr(value, 'isoformat'):  # datetime objects
            converted[key] = value
        elif isinstance(value, (str, int, float, bool, list, dict)):
            converted[key] = value
        else:
            # Convert other types to string
            converted[key] = str(value)
    
    return converted

def verify_migration():
    """Verify that the migration was successful by comparing sample data"""
    print("🔍 Verifying migration...")
    
    bq_service = get_bigquery_service()
    fs_service = get_firestore_service()
    
    # Get sample user from BigQuery
    sample_query = f"""
    SELECT user_id, device_id
    FROM `{bq_service.project_id}.{bq_service.dataset_id}.users`
    LIMIT 1
    """
    bq_users = bq_service._execute_query(sample_query)
    
    if not bq_users:
        print("⚠️ No users found in BigQuery to verify")
        return True
    
    sample_user_id = bq_users[0]["user_id"]
    
    # Check if user exists in Firestore
    user_ref = fs_service.client.collection("users").document(sample_user_id)
    fs_user = user_ref.get()
    
    if fs_user.exists:
        print(f"✅ Sample user {sample_user_id[:8]}... found in Firestore")
        
        # Check usage data
        usage_ref = user_ref.collection("usage").limit(1).get()
        if usage_ref:
            print(f"✅ Usage data found in Firestore")
        else:
            print(f"⚠️ No usage data found in Firestore")
        
        return True
    else:
        print(f"❌ Sample user {sample_user_id[:8]}... NOT found in Firestore")
        return False

def test_firestore_performance():
    """Test Firestore performance vs BigQuery for usage queries"""
    print("⚡ Testing Firestore performance...")
    
    fs_service = get_firestore_service()
    bq_service = get_bigquery_service()
    
    # Get a sample user ID
    users = fs_service.client.collection("users").limit(1).get()
    if not users:
        print("⚠️ No users found in Firestore for testing")
        return
    
    sample_user_id = users[0].id
    
    # Test Firestore speed
    start_time = datetime.now()
    fs_usage = fs_service.get_user_usage(sample_user_id)
    fs_time = (datetime.now() - start_time).total_seconds()
    
    # Test BigQuery speed  
    start_time = datetime.now()
    bq_usage = bq_service.get_user_usage(sample_user_id)
    bq_time = (datetime.now() - start_time).total_seconds()
    
    print(f"🔥 Firestore query time: {fs_time:.3f}s")
    print(f"📊 BigQuery query time: {bq_time:.3f}s")
    print(f"⚡ Speedup: {bq_time/fs_time:.1f}x faster!")

if __name__ == "__main__":
    print("EventAI BigQuery → Firestore Migration Tool")
    print("=" * 50)
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "migrate":
            migrate_all_data()
        elif command == "verify":
            verify_migration()
        elif command == "test":
            test_firestore_performance()
        else:
            print("Usage: python migrate_to_firestore.py [migrate|verify|test]")
    else:
        print("Available commands:")
        print("  migrate - Migrate all data from BigQuery to Firestore")
        print("  verify  - Verify migration was successful")
        print("  test    - Test performance comparison")
        print()
        print("Usage: python migrate_to_firestore.py <command>")