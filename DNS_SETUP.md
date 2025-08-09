# EventAI DNS Setup Instructions

## Overview
EventAI backend is now deployed on Google Cloud Run with a load balancer and SSL certificate. You need to configure DNS records to point `eventai.leveluplife.app` to the load balancer.

## DNS Records to Add

Add these DNS records in your `leveluplife.app` DNS provider:

### A Records for HTTPS (Primary)
```
Name: eventai
Type: A
Value: 34.8.118.152
TTL: 300
```

### A Records for HTTP (Redirect)
```
Name: eventai  
Type: A
Value: 34.149.19.131
TTL: 300
```

**Note**: You may need to set up both records or consult with your DNS provider about how to handle both HTTP and HTTPS traffic to the same subdomain.

## Alternative: CNAME Record (if supported by your DNS provider)

If your DNS provider supports CNAME records for subdomains, you could potentially use:
```
Name: eventai
Type: CNAME
Value: ghs.googlehosted.com
TTL: 300
```

## SSL Certificate Status

The SSL certificate for `eventai.leveluplife.app` is currently being provisioned. You can check its status with:

```bash
gcloud compute ssl-certificates describe event-ai-ssl-cert --global
```

The certificate will be automatically provisioned once the DNS records are configured and propagated (may take 24-48 hours).

## Verification Steps

1. **Add DNS Records**: Configure the DNS records above
2. **Wait for Propagation**: DNS changes can take up to 48 hours to propagate
3. **Check SSL Status**: Monitor SSL certificate provisioning
4. **Test Domain**: Once DNS propagates, test:
   - https://eventai.leveluplife.app/health
   - https://eventai.leveluplife.app/

## Current Status

✅ Google Cloud Load Balancer configured  
✅ SSL certificate requested  
✅ Backend services connected to Cloud Run  
🔄 DNS configuration needed  
🔄 SSL certificate provisioning (pending DNS)  

## Troubleshooting

- **SSL Certificate Stuck in PROVISIONING**: Ensure DNS records point to the correct IP addresses
- **502 Bad Gateway**: Backend service may still be starting up
- **Domain Not Resolving**: Check DNS propagation with `dig eventai.leveluplife.app`

## Final URLs

Once DNS is configured:
- **Production API**: https://eventai.leveluplife.app
- **Health Check**: https://eventai.leveluplife.app/health
- **API Docs**: https://eventai.leveluplife.app/docs

The iOS app should be configured to use `https://eventai.leveluplife.app` as the base URL.