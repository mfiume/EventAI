"""
EventAI API Key Authentication Service
Handles client-based and user-based API keys with rate limiting
"""

import os
import secrets
import hashlib
from datetime import datetime, timedelta
from typing import Optional, Dict, Tuple
from fastapi import HTTPException, Request, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import json
from google.cloud import bigquery

# Models
class APIKeyInfo(BaseModel):
    key_id: str
    key_type: str  # 'client' or 'user'
    client_name: Optional[str] = None
    user_id: Optional[str] = None
    is_active: bool = True
    created_at: datetime
    last_used: Optional[datetime] = None
    rate_limit_per_hour: int = 100
    rate_limit_per_day: int = 1000

class RateLimitInfo(BaseModel):
    requests_per_hour: int
    requests_per_day: int
    hour_window_start: datetime
    day_window_start: datetime

# API Key Authentication Service
class APIKeyService:
    def __init__(self):
        self.bq_client = bigquery.Client()
        self.project_id = os.getenv('GOOGLE_CLOUD_PROJECT', 'levelup-467902')
        self.dataset_id = 'eventai'
        
        # Ensure tables exist
        self._ensure_tables_exist()
        
        # Load predefined client keys from environment
        self._load_client_keys()
    
    def _ensure_tables_exist(self):
        """Create API key and rate limit tables if they don't exist"""
        try:
            # API Keys table
            api_keys_table_id = f"{self.project_id}.{self.dataset_id}.api_keys"
            api_keys_schema = [
                bigquery.SchemaField("key_id", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("key_hash", "STRING", mode="REQUIRED"), 
                bigquery.SchemaField("key_type", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("client_name", "STRING"),
                bigquery.SchemaField("user_id", "STRING"),
                bigquery.SchemaField("is_active", "BOOLEAN", mode="REQUIRED"),
                bigquery.SchemaField("created_at", "TIMESTAMP", mode="REQUIRED"),
                bigquery.SchemaField("last_used", "TIMESTAMP"),
                bigquery.SchemaField("rate_limit_per_hour", "INTEGER"),
                bigquery.SchemaField("rate_limit_per_day", "INTEGER"),
                bigquery.SchemaField("metadata", "JSON")
            ]
            
            table = bigquery.Table(api_keys_table_id, schema=api_keys_schema)
            self.bq_client.create_table(table, exists_ok=True)
            print(f"✅ API keys table ready: {api_keys_table_id}")
            
            # Rate limiting table
            rate_limits_table_id = f"{self.project_id}.{self.dataset_id}.api_rate_limits"
            rate_limits_schema = [
                bigquery.SchemaField("key_id", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("hour_window", "TIMESTAMP", mode="REQUIRED"),
                bigquery.SchemaField("day_window", "TIMESTAMP", mode="REQUIRED"), 
                bigquery.SchemaField("requests_in_hour", "INTEGER"),
                bigquery.SchemaField("requests_in_day", "INTEGER"),
                bigquery.SchemaField("last_request", "TIMESTAMP")
            ]
            
            table = bigquery.Table(rate_limits_table_id, schema=rate_limits_schema)
            self.bq_client.create_table(table, exists_ok=True)
            print(f"✅ Rate limits table ready: {rate_limits_table_id}")
            
        except Exception as e:
            print(f"❌ Error creating API tables: {e}")
    
    def _load_client_keys(self):
        """Load predefined client API keys from environment variables"""
        # iOS App Client Key
        ios_client_key = os.getenv('IOS_CLIENT_API_KEY')
        if ios_client_key:
            self._register_client_key(
                api_key=ios_client_key,
                client_name="EventAI-iOS",
                rate_limit_per_hour=500,  # Higher limits for official client
                rate_limit_per_day=5000
            )
        
        # Web App Client Key (for future use)
        web_client_key = os.getenv('WEB_CLIENT_API_KEY')  
        if web_client_key:
            self._register_client_key(
                api_key=web_client_key,
                client_name="EventAI-Web",
                rate_limit_per_hour=300,
                rate_limit_per_day=2000
            )
        
        # Development/Testing Key
        dev_client_key = os.getenv('DEV_CLIENT_API_KEY')
        if dev_client_key:
            self._register_client_key(
                api_key=dev_client_key,
                client_name="EventAI-Dev",
                rate_limit_per_hour=100,
                rate_limit_per_day=500
            )
    
    def generate_api_key(self) -> str:
        """Generate a cryptographically secure API key"""
        return f"eak_{secrets.token_urlsafe(32)}"  # EventAI Key prefix
    
    def hash_api_key(self, api_key: str) -> str:
        """Create a secure hash of the API key for storage"""
        return hashlib.sha256(api_key.encode()).hexdigest()
    
    def _register_client_key(self, api_key: str, client_name: str, 
                           rate_limit_per_hour: int, rate_limit_per_day: int):
        """Register a client API key in the database"""
        try:
            key_id = f"client_{client_name.lower().replace('-', '_')}"
            key_hash = self.hash_api_key(api_key)
            
            query = f"""
            MERGE `{self.project_id}.{self.dataset_id}.api_keys` AS target
            USING (
                SELECT 
                    @key_id as key_id,
                    @key_hash as key_hash,
                    'client' as key_type,
                    @client_name as client_name,
                    '' as user_id,
                    true as is_active,
                    CURRENT_TIMESTAMP() as created_at,
                    CAST(NULL AS TIMESTAMP) as last_used,
                    @rate_limit_per_hour as rate_limit_per_hour,
                    @rate_limit_per_day as rate_limit_per_day,
                    JSON '{{}}' as metadata
            ) AS source
            ON target.key_id = source.key_id
            WHEN MATCHED THEN
                UPDATE SET 
                    key_hash = source.key_hash,
                    rate_limit_per_hour = source.rate_limit_per_hour,
                    rate_limit_per_day = source.rate_limit_per_day
            WHEN NOT MATCHED THEN
                INSERT ROW
            """
            
            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("key_id", "STRING", key_id),
                    bigquery.ScalarQueryParameter("key_hash", "STRING", key_hash),
                    bigquery.ScalarQueryParameter("client_name", "STRING", client_name),
                    bigquery.ScalarQueryParameter("rate_limit_per_hour", "INTEGER", rate_limit_per_hour),
                    bigquery.ScalarQueryParameter("rate_limit_per_day", "INTEGER", rate_limit_per_day)
                ]
            )
            
            query_job = self.bq_client.query(query, job_config=job_config)
            query_job.result()
            print(f"✅ Registered client key: {client_name}")
            
        except Exception as e:
            print(f"❌ Error registering client key {client_name}: {e}")
    
    async def validate_api_key(self, api_key: str) -> Optional[APIKeyInfo]:
        """Validate an API key and return key information"""
        if not api_key:
            return None
        
        try:
            key_hash = self.hash_api_key(api_key)
            
            query = f"""
            SELECT 
                key_id,
                key_type,
                client_name,
                user_id,
                is_active,
                created_at,
                last_used,
                rate_limit_per_hour,
                rate_limit_per_day
            FROM `{self.project_id}.{self.dataset_id}.api_keys`
            WHERE key_hash = @key_hash AND is_active = true
            """
            
            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("key_hash", "STRING", key_hash)
                ]
            )
            
            query_job = self.bq_client.query(query, job_config=job_config)
            results = list(query_job.result())
            
            if not results:
                return None
            
            row = results[0]
            return APIKeyInfo(
                key_id=row.key_id,
                key_type=row.key_type,
                client_name=row.client_name,
                user_id=row.user_id,
                is_active=row.is_active,
                created_at=row.created_at,
                last_used=row.last_used,
                rate_limit_per_hour=row.rate_limit_per_hour or 100,
                rate_limit_per_day=row.rate_limit_per_day or 1000
            )
            
        except Exception as e:
            print(f"❌ Error validating API key: {e}")
            return None
    
    async def check_rate_limit(self, key_info: APIKeyInfo) -> Tuple[bool, Dict]:
        """Check if the API key is within rate limits"""
        try:
            now = datetime.utcnow()
            hour_window = now.replace(minute=0, second=0, microsecond=0)
            day_window = now.replace(hour=0, minute=0, second=0, microsecond=0)
            
            # Get current usage
            query = f"""
            SELECT 
                requests_in_hour,
                requests_in_day,
                hour_window,
                day_window
            FROM `{self.project_id}.{self.dataset_id}.api_rate_limits`
            WHERE key_id = @key_id 
                AND hour_window = @hour_window
                AND day_window = @day_window
            """
            
            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("key_id", "STRING", key_info.key_id),
                    bigquery.ScalarQueryParameter("hour_window", "TIMESTAMP", hour_window),
                    bigquery.ScalarQueryParameter("day_window", "TIMESTAMP", day_window)
                ]
            )
            
            query_job = self.bq_client.query(query, job_config=job_config)
            results = list(query_job.result())
            
            if results:
                row = results[0]
                requests_in_hour = row.requests_in_hour or 0
                requests_in_day = row.requests_in_day or 0
            else:
                requests_in_hour = 0
                requests_in_day = 0
            
            # Check limits
            hour_limit_exceeded = requests_in_hour >= key_info.rate_limit_per_hour
            day_limit_exceeded = requests_in_day >= key_info.rate_limit_per_day
            
            rate_limit_info = {
                "requests_in_hour": requests_in_hour,
                "requests_in_day": requests_in_day,
                "hour_limit": key_info.rate_limit_per_hour,
                "day_limit": key_info.rate_limit_per_day,
                "hour_remaining": max(0, key_info.rate_limit_per_hour - requests_in_hour),
                "day_remaining": max(0, key_info.rate_limit_per_day - requests_in_day),
                "reset_hour": (hour_window + timedelta(hours=1)).isoformat(),
                "reset_day": (day_window + timedelta(days=1)).isoformat()
            }
            
            return not (hour_limit_exceeded or day_limit_exceeded), rate_limit_info
            
        except Exception as e:
            print(f"❌ Error checking rate limit: {e}")
            # Allow request on error to avoid blocking legitimate traffic
            return True, {}
    
    async def record_api_request(self, key_info: APIKeyInfo):
        """Record an API request for rate limiting"""
        try:
            now = datetime.utcnow()
            hour_window = now.replace(minute=0, second=0, microsecond=0)
            day_window = now.replace(hour=0, minute=0, second=0, microsecond=0)
            
            # Update rate limit counters
            query = f"""
            MERGE `{self.project_id}.{self.dataset_id}.api_rate_limits` AS target
            USING (
                SELECT 
                    @key_id as key_id,
                    @hour_window as hour_window,
                    @day_window as day_window
            ) AS source
            ON target.key_id = source.key_id 
                AND target.hour_window = source.hour_window
                AND target.day_window = source.day_window
            WHEN MATCHED THEN
                UPDATE SET 
                    requests_in_hour = requests_in_hour + 1,
                    requests_in_day = requests_in_day + 1,
                    last_request = CURRENT_TIMESTAMP()
            WHEN NOT MATCHED THEN
                INSERT (key_id, hour_window, day_window, requests_in_hour, requests_in_day, last_request)
                VALUES (@key_id, @hour_window, @day_window, 1, 1, CURRENT_TIMESTAMP())
            """
            
            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("key_id", "STRING", key_info.key_id),
                    bigquery.ScalarQueryParameter("hour_window", "TIMESTAMP", hour_window),
                    bigquery.ScalarQueryParameter("day_window", "TIMESTAMP", day_window)
                ]
            )
            
            query_job = self.bq_client.query(query, job_config=job_config)
            query_job.result()
            
            # Update last_used timestamp for API key
            update_query = f"""
            UPDATE `{self.project_id}.{self.dataset_id}.api_keys`
            SET last_used = CURRENT_TIMESTAMP()
            WHERE key_id = @key_id
            """
            
            update_job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("key_id", "STRING", key_info.key_id)
                ]
            )
            
            update_job = self.bq_client.query(update_query, job_config=update_job_config)
            update_job.result()
            
        except Exception as e:
            print(f"❌ Error recording API request: {e}")

    # Future: User API Key Management
    async def create_user_api_key(self, user_id: str, description: str = "") -> str:
        """Create a new API key for a user (future feature)"""
        try:
            api_key = self.generate_api_key()
            key_id = f"user_{user_id}_{secrets.token_hex(8)}"
            key_hash = self.hash_api_key(api_key)
            
            query = f"""
            INSERT INTO `{self.project_id}.{self.dataset_id}.api_keys`
            (key_id, key_hash, key_type, user_id, is_active, created_at, 
             rate_limit_per_hour, rate_limit_per_day, metadata)
            VALUES (@key_id, @key_hash, 'user', @user_id, true, CURRENT_TIMESTAMP(),
                    50, 200, JSON_OBJECT('description', @description))
            """
            
            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("key_id", "STRING", key_id),
                    bigquery.ScalarQueryParameter("key_hash", "STRING", key_hash),
                    bigquery.ScalarQueryParameter("user_id", "STRING", user_id),
                    bigquery.ScalarQueryParameter("description", "STRING", description)
                ]
            )
            
            query_job = self.bq_client.query(query, job_config=job_config)
            query_job.result()
            
            print(f"✅ Created user API key for user: {user_id}")
            return api_key
            
        except Exception as e:
            print(f"❌ Error creating user API key: {e}")
            raise HTTPException(status_code=500, detail="Failed to create API key")

# Global instance
auth_service = APIKeyService()

# FastAPI Dependencies
security = HTTPBearer(auto_error=False)

async def get_api_key_from_request(request: Request) -> Optional[str]:
    """Extract API key from various sources"""
    # Check Authorization header (Bearer token)
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        return auth_header[7:]
    
    # Check X-API-Key header
    api_key = request.headers.get("X-API-Key")
    if api_key:
        return api_key
    
    # Check query parameter (for testing only)
    api_key = request.query_params.get("api_key")
    if api_key:
        return api_key
    
    return None

async def require_api_key(request: Request) -> APIKeyInfo:
    """Dependency to require and validate API key"""
    api_key = await get_api_key_from_request(request)
    
    if not api_key:
        raise HTTPException(
            status_code=401,
            detail="API key required. Provide via Authorization header (Bearer token) or X-API-Key header.",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    key_info = await auth_service.validate_api_key(api_key)
    if not key_info:
        raise HTTPException(
            status_code=401,
            detail="Invalid or inactive API key",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    # Check rate limits
    allowed, rate_info = await auth_service.check_rate_limit(key_info)
    if not allowed:
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded",
            headers={
                "X-RateLimit-Limit-Hour": str(key_info.rate_limit_per_hour),
                "X-RateLimit-Limit-Day": str(key_info.rate_limit_per_day),
                "X-RateLimit-Remaining-Hour": str(rate_info.get("hour_remaining", 0)),
                "X-RateLimit-Remaining-Day": str(rate_info.get("day_remaining", 0)),
                "X-RateLimit-Reset-Hour": rate_info.get("reset_hour", ""),
                "X-RateLimit-Reset-Day": rate_info.get("reset_day", ""),
                "Retry-After": "3600"
            }
        )
    
    # Record the request
    await auth_service.record_api_request(key_info)
    
    return key_info

async def optional_api_key(request: Request) -> Optional[APIKeyInfo]:
    """Optional API key dependency (for endpoints that work both ways)"""
    try:
        return await require_api_key(request)
    except HTTPException:
        return None