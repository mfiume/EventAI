#!/usr/bin/env python3
"""
RevenueCat Webhook Integration for EventAI
Handles subscription status changes from RevenueCat
"""

import os
import hmac
import hashlib
import json
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from fastapi import APIRouter, HTTPException, Request, Header
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import logging
from google.cloud import bigquery

from bigquery_service import get_bigquery_service

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create RevenueCat webhook router
webhook_router = APIRouter(prefix="/api/webhooks", tags=["RevenueCat Webhooks"])

# RevenueCat webhook models
class RevenueCatWebhookEvent(BaseModel):
    event_timestamp_ms: int
    product_id: str
    period_type: str
    purchased_at_ms: int
    expiration_at_ms: Optional[int] = None
    environment: str
    entitlement_id: Optional[str] = None
    entitlement_ids: list = []
    offer_code: Optional[str] = None
    is_family_share: bool = False
    country_code: Optional[str] = None
    app_user_id: str
    original_app_user_id: str

class RevenueCatWebhook(BaseModel):
    api_version: str
    event: RevenueCatWebhookEvent

def verify_webhook_signature(payload: bytes, signature: str, webhook_secret: str) -> bool:
    """Verify RevenueCat webhook signature"""
    if not webhook_secret:
        logger.warning("No webhook secret configured - skipping signature verification")
        return True
    
    try:
        # RevenueCat uses HMAC-SHA256
        expected_signature = hmac.new(
            webhook_secret.encode('utf-8'),
            payload,
            hashlib.sha256
        ).hexdigest()
        
        # Remove 'sha256=' prefix if present
        if signature.startswith('sha256='):
            signature = signature[7:]
        
        return hmac.compare_digest(expected_signature, signature)
    except Exception as e:
        logger.error(f"Error verifying webhook signature: {e}")
        return False

@webhook_router.post("/revenueCat")
async def handle_revenueCat_webhook(
    request: Request,
    x_revenuecat_signature: Optional[str] = Header(None)
):
    """Handle RevenueCat webhook events for subscription changes"""
    try:
        # Get raw payload for signature verification
        payload = await request.body()
        
        # Verify webhook signature
        webhook_secret = os.getenv("REVENUECAT_WEBHOOK_SECRET")
        if webhook_secret and x_revenuecat_signature:
            if not verify_webhook_signature(payload, x_revenuecat_signature, webhook_secret):
                logger.error("Invalid webhook signature")
                raise HTTPException(status_code=401, detail="Invalid signature")
        
        # Parse webhook data
        webhook_data = json.loads(payload.decode('utf-8'))
        logger.info(f"RevenueCat webhook received: {webhook_data.get('event', {}).get('type', 'unknown')}")
        
        # Extract event information
        event = webhook_data.get('event', {})
        event_type = event.get('type')
        app_user_id = event.get('app_user_id')
        product_id = event.get('product_id')
        environment = event.get('environment', 'unknown')
        
        if not app_user_id:
            logger.error("No app_user_id in webhook event")
            return JSONResponse(content={"status": "error", "message": "Missing app_user_id"})
        
        # Initialize BigQuery service
        bq_service = get_bigquery_service()
        
        # Process different event types
        if event_type in ['INITIAL_PURCHASE', 'RENEWAL', 'PRODUCT_CHANGE']:
            await handle_subscription_activation(bq_service, event, app_user_id, product_id, environment)
        
        elif event_type in ['CANCELLATION', 'EXPIRATION', 'BILLING_ISSUE']:
            await handle_subscription_deactivation(bq_service, event, app_user_id, product_id, environment)
        
        elif event_type == 'UNCANCELLATION':
            await handle_subscription_reactivation(bq_service, event, app_user_id, product_id, environment)
        
        else:
            logger.info(f"Unhandled event type: {event_type}")
        
        # Log the webhook event for analytics
        await log_webhook_event(bq_service, webhook_data)
        
        return JSONResponse(content={"status": "success"})
        
    except Exception as e:
        logger.error(f"Error processing RevenueCat webhook: {e}")
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)}
        )

async def handle_subscription_activation(bq_service, event: Dict[str, Any], app_user_id: str, product_id: str, environment: str):
    """Handle subscription activation events"""
    try:
        # Extract subscription details
        purchased_at_ms = event.get('purchased_at_ms', 0)
        expiration_at_ms = event.get('expiration_at_ms')
        
        # Convert timestamps
        purchased_at = datetime.fromtimestamp(purchased_at_ms / 1000, tz=timezone.utc) if purchased_at_ms else datetime.now(timezone.utc)
        expires_at = datetime.fromtimestamp(expiration_at_ms / 1000, tz=timezone.utc) if expiration_at_ms else None
        
        # Calculate subscription length in days
        if expires_at:
            subscription_days = (expires_at - purchased_at).days
        else:
            subscription_days = 30  # Default to 30 days for monthly
        
        # Create or update subscription in BigQuery
        subscription_id = bq_service.create_premium_subscription(
            user_id=app_user_id,
            subscription_days=subscription_days
        )
        
        logger.info(f"✅ Activated premium subscription for user {app_user_id[:8]}... (product: {product_id}, env: {environment})")
        
    except Exception as e:
        logger.error(f"Error activating subscription for {app_user_id}: {e}")

async def handle_subscription_deactivation(bq_service, event: Dict[str, Any], app_user_id: str, product_id: str, environment: str):
    """Handle subscription deactivation events"""
    try:
        # Deactivate subscription in BigQuery
        query = f"""
        UPDATE `{bq_service.project_id}.{bq_service.dataset_id}.subscriptions`
        SET is_active = false, updated_at = CURRENT_TIMESTAMP()
        WHERE user_id = @user_id AND is_active = true
        """
        
        job_config = bq_service.client.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("user_id", "STRING", app_user_id)
            ]
        )
        
        query_job = bq_service.client.query(query, job_config=job_config)
        query_job.result()
        
        logger.info(f"❌ Deactivated premium subscription for user {app_user_id[:8]}... (product: {product_id}, env: {environment})")
        
    except Exception as e:
        logger.error(f"Error deactivating subscription for {app_user_id}: {e}")

async def handle_subscription_reactivation(bq_service, event: Dict[str, Any], app_user_id: str, product_id: str, environment: str):
    """Handle subscription reactivation events (uncancellation)"""
    try:
        # Reactivate subscription in BigQuery
        query = f"""
        UPDATE `{bq_service.project_id}.{bq_service.dataset_id}.subscriptions`
        SET is_active = true, updated_at = CURRENT_TIMESTAMP()
        WHERE user_id = @user_id AND subscription_end > CURRENT_TIMESTAMP()
        """
        
        job_config = bq_service.client.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("user_id", "STRING", app_user_id)
            ]
        )
        
        query_job = bq_service.client.query(query, job_config=job_config)
        result = query_job.result()
        
        if query_job.num_dml_affected_rows > 0:
            logger.info(f"🔄 Reactivated premium subscription for user {app_user_id[:8]}... (product: {product_id}, env: {environment})")
        else:
            logger.warning(f"No active subscription found to reactivate for user {app_user_id[:8]}...")
        
    except Exception as e:
        logger.error(f"Error reactivating subscription for {app_user_id}: {e}")

async def log_webhook_event(bq_service, webhook_data: Dict[str, Any]):
    """Log webhook event to BigQuery for analytics"""
    try:
        event = webhook_data.get('event', {})
        
        # Insert webhook event log
        query = f"""
        INSERT INTO `{bq_service.project_id}.{bq_service.dataset_id}.conversion_events`
        (user_id, event_type, event_data, created_at)
        VALUES (@user_id, @event_type, @event_data, CURRENT_TIMESTAMP())
        """
        
        job_config = bq_service.client.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("user_id", "STRING", event.get('app_user_id', 'unknown')),
                bigquery.ScalarQueryParameter("event_type", "STRING", f"revenueCat_{event.get('type', 'unknown')}"),
                bigquery.ScalarQueryParameter("event_data", "STRING", json.dumps(webhook_data))
            ]
        )
        
        query_job = bq_service.client.query(query, job_config=job_config)
        query_job.result()
        
    except Exception as e:
        logger.error(f"Error logging webhook event: {e}")

@webhook_router.get("/revenueCat/test")
async def test_webhook_endpoint():
    """Test endpoint to verify webhook is accessible"""
    return {
        "status": "healthy",
        "service": "RevenueCat Webhook Handler",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "endpoint": "/api/webhooks/revenueCat"
    }