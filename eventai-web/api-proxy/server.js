// EventAI API Proxy - Forwards requests to Cloud Run backend
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 8080;

// Construct backend URL from Cloud Run service name
const CLOUD_RUN_SERVICE = process.env.CLOUD_RUN_SERVICE || 'eventai-api';
const CLOUD_RUN_REGION = process.env.CLOUD_RUN_REGION || 'us-central1';
const GOOGLE_CLOUD_PROJECT = process.env.GOOGLE_CLOUD_PROJECT || 'levelup-467902';

// Use Cloud Run service URL pattern
const BACKEND_URL = `https://${CLOUD_RUN_SERVICE}-${GOOGLE_CLOUD_PROJECT.replace(/[^0-9]/g, '')}.${CLOUD_RUN_REGION}.run.app`;

console.log('🚀 EventAI API Proxy starting...');
console.log('🔗 Cloud Run Service:', CLOUD_RUN_SERVICE);
console.log('🔗 Constructed Backend URL:', BACKEND_URL);

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        service: 'EventAI API Proxy',
        backend: BACKEND_URL,
        timestamp: new Date().toISOString()
    });
});

// Proxy all requests to Cloud Run backend
app.use('/', createProxyMiddleware({
    target: BACKEND_URL,
    changeOrigin: true,
    timeout: 30000,
    proxyTimeout: 30000,
    onProxyReq: (proxyReq, req, res) => {
        console.log(`📡 Proxying ${req.method} ${req.path} -> ${BACKEND_URL}${req.path}`);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log(`📨 Response ${proxyRes.statusCode} for ${req.method} ${req.path}`);
    },
    onError: (err, req, res) => {
        console.error('❌ Proxy error:', err.message);
        res.status(500).json({
            error: 'Backend service unavailable',
            message: err.message,
            timestamp: new Date().toISOString()
        });
    }
}));

app.listen(PORT, () => {
    console.log(`✅ EventAI API Proxy listening on port ${PORT}`);
    console.log(`🔗 Forwarding requests to: ${BACKEND_URL}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('🛑 EventAI API Proxy shutting down...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('🛑 EventAI API Proxy shutting down...');
    process.exit(0);
});