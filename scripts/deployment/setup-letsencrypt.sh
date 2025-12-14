#!/bin/bash
# Setup Let's Encrypt SSL certificate for Fitband MQTT Broker
# This script sets up Nginx as reverse proxy with SSL termination
# Run this ON the EC2 instance via SSH

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Let's Encrypt SSL Certificate Setup ===${NC}"
echo ""

# Check if running on server
if [ ! -f /etc/os-release ] || ! grep -q "Ubuntu\|Debian" /etc/os-release; then
  echo -e "${YELLOW}This script should be run on an Ubuntu/Debian server${NC}"
  echo "SSH into your EC2 instance first:"
  echo "  ssh -i ~/.ssh/your-key.pem ubuntu@44.207.29.42"
  exit 1
fi

# Get domain information
echo "Choose your domain option:"
echo "1) DuckDNS (free, quick setup)"
echo "2) Your own domain"
read -p "Enter choice [1-2]: " DOMAIN_CHOICE

if [ "$DOMAIN_CHOICE" == "1" ]; then
  read -p "DuckDNS subdomain (e.g., fitband-broker): " DUCKDNS_SUBDOMAIN
  read -sp "DuckDNS token (get from https://www.duckdns.org): " DUCKDNS_TOKEN
  echo ""
  DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
  
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
  RESOLVED_IP=$(dig +short ${DOMAIN} @8.8.8.8 2>/dev/null | tail -1 || echo "")
  if [ "$RESOLVED_IP" == "$CURRENT_IP" ]; then
    echo -e "${GREEN}✓ DNS resolved correctly${NC}"
  else
    echo -e "${YELLOW}⚠ DNS propagation may be incomplete${NC}"
    echo "  Expected: ${CURRENT_IP}"
    echo "  Resolved: ${RESOLVED_IP}"
    echo "  Continuing anyway..."
  fi
  
  # Save DuckDNS token for auto-update
  DUCKDNS_TOKEN_SAVE="$DUCKDNS_TOKEN"
  DUCKDNS_SUBDOMAIN_SAVE="$DUCKDNS_SUBDOMAIN"
else
  read -p "Your domain name (e.g., broker.example.com): " DOMAIN
  if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain name is required${NC}"
    exit 1
  fi
  
  echo -e "${YELLOW}Make sure your domain points to this server's IP:${NC}"
  CURRENT_IP=$(curl -s https://checkip.amazonaws.com)
  echo "  ${CURRENT_IP}"
  echo ""
  read -p "Press Enter when DNS is configured..."
  DUCKDNS_TOKEN_SAVE=""
  DUCKDNS_SUBDOMAIN_SAVE=""
fi

read -p "Your email (for Let's Encrypt): " EMAIL

echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Domain: ${DOMAIN}"
echo "  Email: ${EMAIL}"
echo ""

# Stop Docker container temporarily (port 443 must be free)
echo -e "${BLUE}Stopping Docker container temporarily...${NC}"
cd ~/fitband-mqtt-broker
sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod down || true

# Install Certbot
echo ""
echo -e "${BLUE}Installing Certbot...${NC}"
sudo apt-get update -qq
sudo apt-get install -y certbot

# Get SSL certificate
echo ""
echo -e "${BLUE}Getting SSL certificate from Let's Encrypt...${NC}"
echo -e "${YELLOW}Note: Port 80 must be accessible from internet${NC}"

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
  echo "Make sure:"
  echo "  1. Port 80 is open in security group"
  echo "  2. Domain DNS points to this server"
  exit 1
fi

# Install Nginx
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

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect all other traffic to HTTPS
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

    # WebSocket endpoint
    location /ws {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400; # 24 hours for WebSocket connections
        proxy_buffering off;
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
echo -e "${BLUE}Enabling Nginx site...${NC}"
sudo ln -sf /etc/nginx/sites-available/fitband-mqtt-broker /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx config
echo ""
echo -e "${BLUE}Testing Nginx configuration...${NC}"
if sudo nginx -t; then
  echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
  sudo systemctl restart nginx
  sudo systemctl enable nginx
  echo -e "${GREEN}✓ Nginx started${NC}"
else
  echo -e "${RED}✗ Nginx configuration error${NC}"
  exit 1
fi

# Update docker-compose to disable HTTPS (Nginx handles it)
echo ""
echo -e "${BLUE}Updating Docker configuration...${NC}"
sed -i 's/^ENABLE_HTTPS=.*/ENABLE_HTTPS=false/' .env.prod
echo -e "${GREEN}✓ Docker configured for HTTP (Nginx handles SSL)${NC}"

# Restart Docker container (HTTP only, on port 8080)
echo ""
echo -e "${BLUE}Starting Docker container...${NC}"
sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d
echo -e "${GREEN}✓ Container started${NC}"

# Setup auto-renewal
echo ""
echo -e "${BLUE}Setting up certificate auto-renewal...${NC}"
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
echo -e "${GREEN}✓ Auto-renewal configured${NC}"

# Create renewal hook to reload Nginx
sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh > /dev/null <<'SCRIPT'
#!/bin/bash
systemctl reload nginx
SCRIPT
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

# Setup DuckDNS auto-update (if using DuckDNS)
if [ -n "$DUCKDNS_TOKEN_SAVE" ]; then
  echo ""
  echo -e "${BLUE}Setting up DuckDNS auto-update...${NC}"
  sudo tee /usr/local/bin/update-duckdns.sh > /dev/null <<SCRIPT
#!/bin/bash
TOKEN="${DUCKDNS_TOKEN_SAVE}"
DOMAIN="${DUCKDNS_SUBDOMAIN_SAVE}"
CURRENT_IP=\$(curl -s https://checkip.amazonaws.com)
curl -s "https://www.duckdns.org/update?domains=\${DOMAIN}&token=\${TOKEN}&ip=\${CURRENT_IP}" > /dev/null
SCRIPT
  sudo chmod +x /usr/local/bin/update-duckdns.sh
  
  # Add to crontab (update every 5 minutes)
  (crontab -l 2>/dev/null | grep -v update-duckdns.sh; echo "*/5 * * * * /usr/local/bin/update-duckdns.sh >/dev/null 2>&1") | crontab -
  echo -e "${GREEN}✓ DuckDNS auto-update configured${NC}"
fi

echo ""
echo -e "${GREEN}=== SSL Certificate Setup Complete! ===${NC}"
echo ""
echo -e "${GREEN}Your MQTT Broker is now available at:${NC}"
echo "  https://${DOMAIN}"
echo "  https://${DOMAIN}/api (Swagger)"
echo "  https://${DOMAIN}/health"
echo "  wss://${DOMAIN}/ws (WebSocket - valid SSL!)"
echo ""
echo -e "${YELLOW}Test the connection:${NC}"
echo "  curl https://${DOMAIN}/health"
echo ""
echo -e "${YELLOW}Update your frontend to use:${NC}"
echo "  const socket = io('wss://${DOMAIN}/ws');"
echo "  // No need for rejectUnauthorized: false anymore!"
echo ""

