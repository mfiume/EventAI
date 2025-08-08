# Domain Setup for EventAI

This document explains how to configure the subdomain `eventai.leveluplife.app` to route to the Google Cloud Run service.

## Prerequisites

- Access to `leveluplife.app` domain DNS management
- Google Cloud Run service deployed (`eventai-api`)
- Google Cloud Console access

## Steps

### 1. Deploy the Backend Service

First, deploy the backend to Google Cloud Run:

```bash
cd calendar-backend
./deploy.sh
```

This will create a service at: `https://eventai-api-[PROJECT-HASH].us-central1.run.app`

### 2. Add Custom Domain Mapping in Google Cloud

1. Go to Google Cloud Console → Cloud Run
2. Select the `eventai-api` service
3. Click the "Manage Custom Domains" tab
4. Click "Add Mapping"
5. Enter domain: `eventai.leveluplife.app`
6. Select the `eventai-api` service
7. Click "Continue"

Google will provide DNS records to configure.

### 3. Configure DNS Records

Add these DNS records in your `leveluplife.app` DNS provider:

**Type: CNAME**
- Name: `eventai`
- Value: `ghs.googlehosted.com`
- TTL: 300

**Alternative: Type A Records**
If CNAME doesn't work, use these A records:
- Name: `eventai`
- Values: 
  - `216.239.32.21`
  - `216.239.34.21`
  - `216.239.36.21`
  - `216.239.38.21`

### 4. SSL Certificate

Google will automatically provision an SSL certificate for the domain. This may take a few minutes to propagate.

### 5. Verify Setup

Test the domain mapping:

```bash
# Health check
curl https://eventai.leveluplife.app/health

# API info
curl https://eventai.leveluplife.app/

# Test conversion
curl -X POST https://eventai.leveluplife.app/convert \
  -H "Content-Type: application/json" \
  -d '{"text": "Team meeting tomorrow at 2pm", "timezone": "America/New_York"}'
```

### 6. Update iOS App Configuration

Once the domain is working, update the iOS app's `Config.xcconfig`:

```
API_BASE_URL = https:/$()/eventai.leveluplife.app
```

## Troubleshooting

### Domain Not Resolving

1. Check DNS propagation: `dig eventai.leveluplife.app`
2. Verify DNS records are correct
3. Wait for propagation (can take up to 48 hours)

### SSL Certificate Issues

1. Ensure domain is pointing to Google servers
2. Wait for automatic certificate provisioning
3. Check Google Cloud Console for certificate status

### Service Unavailable

1. Verify Cloud Run service is running
2. Check service logs in Google Cloud Console
3. Ensure environment variables are set correctly

## DNS Record Example

```
# Add these records to leveluplife.app DNS:

Name: eventai
Type: CNAME  
Value: ghs.googlehosted.com
TTL: 300
```

## Final URLs

- **Production API**: `https://eventai.leveluplife.app`
- **Health Check**: `https://eventai.leveluplife.app/health`
- **API Docs**: `https://eventai.leveluplife.app/docs` (FastAPI auto-docs)

The iOS app will use `https://eventai.leveluplife.app` as the base URL for all API calls.