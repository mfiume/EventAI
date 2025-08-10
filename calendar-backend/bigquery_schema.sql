-- EventAI BigQuery Database Schema
-- Dataset: eventai (to be created in levelup-467902 project)

-- 1. Users table - track user information and device associations
CREATE TABLE IF NOT EXISTS `levelup-467902.eventai.users` (
    user_id STRING NOT NULL,
    device_id STRING,
    apple_id STRING,
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    user_agent STRING,
    ip_address STRING,
    timezone STRING,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- 2. Usage tracking table - daily conversion counts
CREATE TABLE IF NOT EXISTS `levelup-467902.eventai.usage_tracking` (
    user_id STRING NOT NULL,
    usage_date DATE NOT NULL,
    conversion_count INT64 DEFAULT 0,
    reset_timezone STRING DEFAULT 'America/New_York',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- 3. Subscriptions table - premium subscription management
CREATE TABLE IF NOT EXISTS `levelup-467902.eventai.subscriptions` (
    user_id STRING NOT NULL,
    subscription_id STRING NOT NULL,
    product_id STRING NOT NULL,
    device_id STRING,
    apple_receipt_data STRING,
    is_active BOOLEAN DEFAULT TRUE,
    subscription_start TIMESTAMP,
    subscription_end TIMESTAMP,
    auto_renew BOOLEAN DEFAULT TRUE,
    cancellation_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- 4. Conversion events table - track all AI conversion requests
CREATE TABLE IF NOT EXISTS `levelup-467902.eventai.conversion_events` (
    event_id STRING NOT NULL,
    user_id STRING NOT NULL,
    request_text STRING,
    has_image BOOLEAN DEFAULT FALSE,
    events_found INT64 DEFAULT 0,
    success BOOLEAN DEFAULT FALSE,
    error_message STRING,
    timezone STRING,
    user_location STRING,
    processing_time_ms INT64,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- 5. App events table - track user interactions and engagement
CREATE TABLE IF NOT EXISTS `levelup-467902.eventai.app_events` (
    event_id STRING NOT NULL,
    user_id STRING NOT NULL,
    event_type STRING NOT NULL, -- 'app_open', 'premium_view', 'conversion_attempt', 'subscription_start', etc.
    event_data JSON,
    device_info JSON,
    app_version STRING,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Indexes for performance
-- BigQuery automatically optimizes based on usage patterns, but we can specify clustering

-- Cluster usage_tracking by user_id and usage_date for efficient daily lookups
-- Cluster subscriptions by user_id for fast premium status checks
-- Cluster conversion_events by user_id and created_at for analytics