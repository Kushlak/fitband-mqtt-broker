# Deployment Scripts

Utility scripts for deploying and managing the Fitband MQTT Broker.

## Structure

```
scripts/
├── deployment/          # Deployment scripts
│   ├── deploy-to-aws.sh            # Deploy app to AWS EC2
│   ├── setup-https-duckdns.sh      # Setup HTTPS with Let's Encrypt + DuckDNS
│   ├── setup-nginx-http.sh         # Setup Nginx reverse proxy (HTTP)
│   ├── check-status.sh             # Check service status
│   └── cleanup-docker.sh           # Clean up Docker resources
│
├── utils/               # Utility scripts
│   ├── test-websocket.js           # Test WebSocket connection
│   └── generate-hmac.js            # Generate HMAC signatures
│
└── generate-cert.sh     # Generate self-signed SSL certificate (development)
```

## Quick Start

### Development (Local)

```bash
# Generate self-signed certificate
npm run generate-cert

# Test WebSocket connection
node scripts/utils/test-websocket.js
```

### Production (AWS)

```bash
# 1. Deploy to AWS EC2
./scripts/deployment/deploy-to-aws.sh

# 2. Setup HTTPS with Let's Encrypt
ssh -i ~/.ssh/fitband-broker-key.pem ubuntu@<EC2_IP>
cd /home/ubuntu/fitband-mqtt-broker
sudo ./scripts/deployment/setup-https-duckdns.sh

# 3. Check status
./scripts/deployment/check-status.sh
```

## Environment Variables

See `env.example` for required environment variables.

### Development
```bash
ENABLE_HTTPS=true
HTTPS_PORT=8443
HTTP_PORT=8080
DATABASE_URL=postgresql://...
```

### Production
```bash
NODE_ENV=production
ENABLE_HTTPS=false  # Nginx handles HTTPS
HTTP_PORT=8080
DATABASE_URL=postgresql://...
API_KEY=your-secure-api-key
```

## Security

All scripts follow security best practices:
- HMAC authentication for devices
- TLS/HTTPS encryption in production
- API key authentication for HTTP endpoints
- Regular certificate renewal via Certbot

