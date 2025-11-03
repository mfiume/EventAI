"""
Firestore-based Authentication Service for EventAI
Fast API key validation using Firestore instead of BigQuery
Replaces auth_service.py for 100x faster authentication
"""

from fastapi import HTTPException, Header, Depends
from typing import Optional, Dict, List
from firestore_service import get_firestore_service
from datetime import datetime, timezone
import time

class FirestoreAPIKeyInfo:
    def __init__(self, key_id: str, key_name: str, permissions: List[str], rate_limit: int):
        self.key_id = key_id
        self.key_name = key_name
        self.permissions = permissions
        self.rate_limit = rate_limit
        self.is_valid = True

def require_api_key_firestore(x_api_key: Optional[str] = Header(None)) -> FirestoreAPIKeyInfo:
    """
    Fast API key validation using Firestore (replaces BigQuery-based validation)
    Expected response time: 10-50ms vs 1-5 seconds with BigQuery
    """
    if not x_api_key:
        raise HTTPException(
            status_code=401,
            detail="API key required. Please provide X-API-Key header."
        )
    
    # Get Firestore service
    fs_service = get_firestore_service()
    
    # Validate API key against Firestore (FAST)
    start_time = time.time()
    validation_result = fs_service.validate_api_key(x_api_key)
    validation_time = (time.time() - start_time) * 1000  # Convert to milliseconds
    
    if not validation_result["valid"]:
        print(f"🔑 API key validation failed in {validation_time:.1f}ms: {validation_result['error']}")
        raise HTTPException(
            status_code=401,
            detail="Invalid or inactive API key"
        )
    
    print(f"🔑 API key validated in {validation_time:.1f}ms: {validation_result['key_name']}")
    
    return FirestoreAPIKeyInfo(
        key_id=validation_result["key_id"],
        key_name=validation_result["key_name"],
        permissions=validation_result["permissions"],
        rate_limit=validation_result["rate_limit"]
    )

def optional_api_key_firestore(x_api_key: Optional[str] = Header(None)) -> Optional[FirestoreAPIKeyInfo]:
    """
    Optional API key validation using Firestore
    Returns None if no key provided, validates if key is present
    """
    if not x_api_key:
        return None
    
    try:
        return require_api_key_firestore(x_api_key)
    except HTTPException:
        return None

def check_permission(api_key_info: FirestoreAPIKeyInfo, required_permission: str) -> bool:
    """Check if API key has required permission"""
    return required_permission in api_key_info.permissions

def require_permission(required_permission: str):
    """Decorator to require specific permission"""
    def permission_checker(api_key_info: FirestoreAPIKeyInfo = Depends(require_api_key_firestore)):
        if not check_permission(api_key_info, required_permission):
            raise HTTPException(
                status_code=403,
                detail=f"API key does not have required permission: {required_permission}"
            )
        return api_key_info
    return permission_checker

# Migration helper to add our current iOS API key to Firestore
def setup_initial_api_keys():
    """Setup initial API keys in Firestore for immediate testing"""
    fs_service = get_firestore_service()
    
    # Add current production API keys
    production_keys = [
        {
            "key": "eak_c555ff05f21b61da0cec024f46ba61a0e7da04ca62f2b2d512ee2b15986e5aa8",
            "name": "iOS Production Key",
            "permissions": ["usage", "convert", "subscription"]
        },
        {
            "key": "eak_35c5ffb18435f5668fc93b684f515eb9deca6bafafdd15a8579c182c85bff5cc",
            "name": "Web Production Key", 
            "permissions": ["usage", "convert", "subscription"]
        },
        {
            "key": "eak_bf8b7a059ab93f3156960babcd922c0cc8a9ab834948b4a800353c9d2242795c",
            "name": "Dev Production Key",
            "permissions": ["usage", "convert", "subscription", "admin"],
            "free_daily_limit": 1000,
            "premium_daily_limit": 2000
        },
        {
            "key": "eak_c47d0bde9529f7f254df4a68668c0f74402c89d7daf9c5ae4ed92b9296142b2a",
            "name": "Legacy iOS Key",
            "permissions": ["usage", "convert", "subscription"]
        }
    ]
    
    try:
        for key_info in production_keys:
            api_key = key_info["key"]
            # Check if key already exists
            key_ref = fs_service.client.collection("api_keys").document(api_key)
            key_doc = key_ref.get()
            if not key_doc.exists:
                # Create the API key
                key_data = {
                    "key_id": api_key,
                    "key_name": key_info["name"],
                    "permissions": key_info["permissions"],
                    "rate_limit": 1000,
                    "is_active": True,
                    "created_at": datetime.now(timezone.utc),
                    "expires_at": None,
                    "last_used": None,
                    "usage_count": 0
                }
                
                # Add custom daily limits if specified
                if "free_daily_limit" in key_info:
                    key_data["free_daily_limit"] = key_info["free_daily_limit"]
                if "premium_daily_limit" in key_info:
                    key_data["premium_daily_limit"] = key_info["premium_daily_limit"]
                key_ref.set(key_data)
                print(f"🔑 Added {key_info['name']} to Firestore: {api_key[:12]}...")
            else:
                # Update existing key with new custom limits if they're specified
                existing_data = key_doc.to_dict()
                update_needed = False
                updates = {}
                
                if "free_daily_limit" in key_info and existing_data.get("free_daily_limit") != key_info["free_daily_limit"]:
                    updates["free_daily_limit"] = key_info["free_daily_limit"]
                    update_needed = True
                    
                if "premium_daily_limit" in key_info and existing_data.get("premium_daily_limit") != key_info["premium_daily_limit"]:
                    updates["premium_daily_limit"] = key_info["premium_daily_limit"]
                    update_needed = True
                
                if update_needed:
                    key_ref.update(updates)
                    print(f"🔑 Updated {key_info['name']} with custom limits: {updates}")
                else:
                    print(f"🔑 {key_info['name']} already exists in Firestore")
            
    except Exception as e:
        print(f"❌ Failed to setup initial API keys: {e}")

# For backward compatibility, alias the old names
APIKeyInfo = FirestoreAPIKeyInfo
require_api_key = require_api_key_firestore
optional_api_key = optional_api_key_firestore