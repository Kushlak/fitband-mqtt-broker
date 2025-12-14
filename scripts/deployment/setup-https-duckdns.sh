#!/bin/bash
# Setup HTTPS with DuckDNS and Let's Encrypt for Fitband MQTT Broker
# Run this ON the EC2 instance

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== HTTPS Setup with DuckDNS ===${NC}"
echo ""

# Check if running on server
if [ ! -f /etc/os-release ] || ! grep -q "Ubuntu\|Debian" /etc/os-release; then
  echo -e "${YELLOW}This script should be run on an Ubuntu/Debian server${NC}"
  echo "SSH into your EC2 instance first"
  exit 1
fi

# Get inputs
read -p "DuckDNS subdomain (e.g., fitband-broker): " DUCKDNS_SUBDOMAIN
read -sp "DuckDNS token: " DUCKDNS_TOKEN
echo ""
read -p "Your email (for Let's Encrypt): " EMAIL

DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"

echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Domain: ${DOMAIN}"
echo "  Email: ${EMAIL}"
echo ""

# Update DuckDNS
echo -e "${BLUE}Updating DuckDNS...${NC}"
CURRENT_IP=$(curl -s https://checkip.amazonaws.com)
UPDATE_URL="https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=${CURRENT_IP}"

if curl -s "${UPDATE_URL}" | grep -q "OK"; then
  echo -e "${GREEN}✓ DuckDNS updated (IP: ${CURRENT_IP})${NC}"
else
  echo -e "${RED}✗ Failed to update DuckDNS${NC}"
  exit 1
fi

# Wait for DNS propagation
echo -e "${BLUE}Waiting for DNS propagation (30 seconds)...${NC}"
sleep 30

# Verify DNS
RESOLVED_IP=$(dig +short ${DOMAIN} @8.8.8.8 | tail -1)
if [ "$RESOLVED_IP" == "$CURRENT_IP" ]; then
  echo -e "${GREEN}✓ DNS resolved correctly${NC}"
else
  echo -e "${YELLOW}⚠ DNS propagation may be incomplete${NC}"
  echo "  Expected: ${CURRENT_IP}"
  echo "  Resolved: ${RESOLVED_IP}"
fi

# Install Certbot
echo ""
echo -e "${BLUE}Installing Certbot...${NC}"
sudo apt-get update -qq
sudo apt-get install -y certbot python3-certbot-nginx

# Stop services on port 80 temporarily
echo ""
echo -e "${BLUE}Stopping services for certificate generation...${NC}"
sudo systemctl stop nginx 2>/dev/null || true

# Get SSL certificate
echo ""
echo -e "${BLUE}Getting SSL certificate from Let's Encrypt...${NC}"
sudo certbot certonly --standalone \
  -d ${DOMAIN} \
  --email ${EMAIL} \
  --agree-tos \
  --non-interactive \
  --preferred-challenges http

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ SSL certificate obtained${NC}"
else
  echo -e "${RED}✗ Failed to get SSL certificate${NC}"
  exit 1
fi

# Install Nginx if not installed
if ! command -v nginx &> /dev/null; then
  echo -e "${BLUE}Installing Nginx...${NC}"
  sudo apt-get install -y nginx
fi

# Create Nginx config
echo ""
echo -e "${BLUE}Creating Nginx configuration...${NC}"
sudo tee /etc/nginx/sites-available/fitband-mqtt-broker > /dev/null <<EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # WebSocket upgrade support
    location /ws/ {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400; # 24 hours for WebSocket connections
    }

    # HTTP API
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
EOF

# Enable site
echo -e "${BLUE}Enabling site...${NC}"
sudo ln -sf /etc/nginx/sites-available/fitband-mqtt-broker /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx config
echo ""
echo -e "${BLUE}Testing Nginx configuration...${NC}"
if sudo nginx -t; then
  echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
  sudo systemctl restart nginx
  sudo systemctl enable nginx
  echo -e "${GREEN}✓ Nginx restarted${NC}"
else
  echo -e "${RED}✗ Nginx configuration error${NC}"
  exit 1
fi

# Setup auto-renewal
echo ""
echo -e "${BLUE}Setting up certificate auto-renewal...${NC}"
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
echo -e "${GREEN}✓ Auto-renewal configured${NC}"

# Create DuckDNS update script
echo ""
echo -e "${BLUE}Creating DuckDNS auto-update script...${NC}"
sudo tee /usr/local/bin/update-duckdns.sh > /dev/null <<SCRIPT
#!/bin/bash
TOKEN="${DUCKDNS_TOKEN}"
DOMAIN="${DUCKDNS_SUBDOMAIN}"
CURRENT_IP=\$(curl -s https://checkip.amazonaws.com)
curl -s "https://www.duckdns.org/update?domains=\${DOMAIN}&token=\${TOKEN}&ip=\${CURRENT_IP}" > /dev/null
SCRIPT

sudo chmod +x /usr/local/bin/update-duckdns.sh

# Add to crontab (update every 5 minutes)
(crontab -l 2>/dev/null | grep -v update-duckdns.sh; echo "*/5 * * * * /usr/local/bin/update-duckdns.sh >/dev/null 2>&1") | crontab -
echo -e "${GREEN}✓ DuckDNS auto-update configured${NC}"

echo ""
echo -e "${GREEN}=== HTTPS Setup Complete! ===${NC}"
echo ""
echo -e "${GREEN}Your MQTT Broker is now available at:${NC}"
echo "  https://${DOMAIN}"
echo "  https://${DOMAIN}/api (Swagger)"
echo "  https://${DOMAIN}/health"
echo "  wss://${DOMAIN}/ws (WebSocket)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the API:"
echo "   curl https://${DOMAIN}/health"
echo ""
echo "2. Test WebSocket:"
echo "   node scripts/utils/test-websocket.js wss://${DOMAIN}/ws"
echo ""
echo "3. Update your simulator/frontend to use:"
echo "   WS_URL=https://${DOMAIN}"
echo ""

