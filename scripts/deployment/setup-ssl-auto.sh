#!/bin/bash
# Automated SSL setup with DuckDNS credentials
# Run this ON the EC2 instance

set -e

DUCKDNS_SUBDOMAIN="fitband-broker"
DUCKDNS_TOKEN="7c2657d9-d82f-4fad-85fc-03fd7d3f6e1d"
DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"

echo "=== SSL Certificate Setup ==="
echo "Domain: ${DOMAIN}"
echo ""

# Get email
read -p "Enter your email for Let's Encrypt: " EMAIL
if [ -z "$EMAIL" ]; then
  echo "Error: Email is required"
  exit 1
fi

# Update DuckDNS
echo ""
echo "Updating DuckDNS..."
CURRENT_IP=$(curl -s https://checkip.amazonaws.com)
UPDATE_URL="https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=${CURRENT_IP}"

UPDATE_RESULT=$(curl -s "${UPDATE_URL}")
if echo "${UPDATE_RESULT}" | grep -q "OK"; then
  echo "✓ DuckDNS updated (IP: ${CURRENT_IP})"
else
  echo "✗ Failed to update DuckDNS"
  echo "  Response: ${UPDATE_RESULT}"
  exit 1
fi

# Wait for DNS propagation (matching working script)
echo ""
echo "Waiting for DNS propagation (30 seconds)..."
sleep 30

# Verify DNS (matching working script format)
RESOLVED_IP=$(dig +short ${DOMAIN} @8.8.8.8 2>/dev/null | tail -1 || echo "")
if [ "$RESOLVED_IP" == "$CURRENT_IP" ]; then
  echo "✓ DNS resolved correctly"
else
  echo "⚠ DNS may not be fully propagated yet"
  echo "  Expected: ${CURRENT_IP}"
  echo "  Resolved: ${RESOLVED_IP}"
  echo "  Continuing anyway (DNS may propagate during certbot validation)..."
fi

# Stop Docker container and ensure port 80 is free
echo ""
echo "Stopping Docker container and ensuring port 80 is free..."
cd ~/fitband-mqtt-broker
sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod down || true

# Kill any process using port 80
sudo lsof -ti :80 | xargs -r sudo kill -9 2>/dev/null || true
sudo fuser -k 80/tcp 2>/dev/null || true
sleep 2

# Install certbot if not installed
if ! command -v certbot &> /dev/null; then
  echo ""
  echo "Installing Certbot..."
  sudo apt-get update -qq
  sudo apt-get install -y certbot
fi

# Get SSL certificate with retries
echo ""
echo "Getting SSL certificate from Let's Encrypt..."
echo "This may take 1-2 minutes..."

MAX_RETRIES=5
RETRY_COUNT=0
WAIT_TIME=60  # Initial wait time

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  # Kill any process on port 80 before each attempt
  sudo lsof -ti :80 | xargs -r sudo kill -9 2>/dev/null || true
  sleep 2
  
  echo "Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES..."
  
  # Run certbot and capture output
  sudo certbot certonly --standalone \
    -d ${DOMAIN} \
    --email ${EMAIL} \
    --agree-tos \
    --non-interactive \
    --preferred-challenges http 2>&1 | tee /tmp/certbot-attempt.log
  
  CERTBOT_EXIT_CODE=${PIPESTATUS[0]}
  
  # Check both exit code and certificate file existence
  if [ $CERTBOT_EXIT_CODE -eq 0 ] && [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]; then
    echo "✓ SSL certificate obtained!"
    break
  else
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
      # For CAA errors, wait longer (exponential backoff)
      if grep -qi "CAA\|SERVFAIL" /tmp/certbot-attempt.log; then
        WAIT_TIME=$((120 * RETRY_COUNT))  # Longer wait for DNS issues: 120s, 240s, 360s, 480s
      else
        WAIT_TIME=$((60 * RETRY_COUNT))   # Normal wait: 60s, 120s, 180s, 240s
      fi
      echo "✗ Certificate request failed. Waiting ${WAIT_TIME} seconds before retry... (attempt $RETRY_COUNT/$MAX_RETRIES)"
      echo ""
      echo "Last error:"
      grep -i "error\|failed\|timeout\|SERVFAIL\|CAA" /tmp/certbot-attempt.log | tail -5 || echo "Check /var/log/letsencrypt/letsencrypt.log"
      echo ""
      
      # Check for specific error types
      if grep -qi "CAA\|SERVFAIL" /tmp/certbot-attempt.log; then
        echo "⚠ CAA DNS lookup failure detected."
        echo "   This is often a temporary DuckDNS issue. Let's Encrypt checks CAA records"
        echo "   before issuing certificates. DuckDNS may need more time to propagate."
        echo "   Waiting longer before retry..."
      fi
      
      echo ""
      echo "Common issues:"
      echo "  - CAA DNS lookup failures: DuckDNS may have temporary DNS issues"
      echo "  - DNS propagation: Wait longer between attempts"
      echo "  - Rate limits: Too many requests in short time"
      sleep ${WAIT_TIME}
      
      # Update DuckDNS IP again before retry (in case it changed)
      CURRENT_IP=$(curl -s https://checkip.amazonaws.com)
      curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=${CURRENT_IP}" > /dev/null
      echo "Updated DuckDNS IP: ${CURRENT_IP}"
    else
      echo "✗ Failed to get certificate after $MAX_RETRIES attempts"
      echo ""
      echo "This is often a temporary DNS issue with DuckDNS. Try:"
      echo "1. Wait 10-15 minutes and run the script again"
      echo "2. Check /var/log/letsencrypt/letsencrypt.log for details"
      echo "3. Verify DNS: dig +short ${DOMAIN} @8.8.8.8"
      exit 1
    fi
  fi
done

# Verify certificate exists before proceeding
if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ] || [ ! -f "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]; then
  echo ""
  echo "✗ Certificate files not found. Cannot proceed with Nginx configuration."
  echo "Certificate path: /etc/letsencrypt/live/${DOMAIN}/"
  echo ""
  echo "Please try running the script again, or check /var/log/letsencrypt/letsencrypt.log"
  exit 1
fi

echo ""
echo "✓ Certificate verified: /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"

# Install Nginx
if ! command -v nginx &> /dev/null; then
  echo ""
  echo "Installing Nginx..."
  sudo apt-get install -y nginx
fi

# Create Nginx config
echo ""
echo "Creating Nginx configuration..."
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
        proxy_read_timeout 86400;
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
sudo ln -sf /etc/nginx/sites-available/fitband-mqtt-broker /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx config
echo ""
echo "Testing Nginx configuration..."
if sudo nginx -t; then
  echo "✓ Nginx configuration is valid"
  sudo systemctl restart nginx
  sudo systemctl enable nginx
  echo "✓ Nginx started"
else
  echo "✗ Nginx configuration error"
  exit 1
fi

# Update Docker to disable HTTPS (Nginx handles it)
echo ""
echo "Updating Docker configuration..."
cd ~/fitband-mqtt-broker
sed -i 's/^ENABLE_HTTPS=.*/ENABLE_HTTPS=false/' .env.prod

# Restart Docker container
echo ""
echo "Starting Docker container..."
sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d
echo "✓ Container started"

# Setup auto-renewal
echo ""
echo "Setting up certificate auto-renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Create renewal hook
sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh > /dev/null <<'SCRIPT'
#!/bin/bash
systemctl reload nginx
SCRIPT
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

# Setup DuckDNS auto-update
echo ""
echo "Setting up DuckDNS auto-update..."
sudo tee /usr/local/bin/update-duckdns.sh > /dev/null <<SCRIPT
#!/bin/bash
TOKEN="${DUCKDNS_TOKEN}"
DOMAIN="${DUCKDNS_SUBDOMAIN}"
CURRENT_IP=\$(curl -s https://checkip.amazonaws.com)
curl -s "https://www.duckdns.org/update?domains=\${DOMAIN}&token=\${TOKEN}&ip=\${CURRENT_IP}" > /dev/null
SCRIPT
sudo chmod +x /usr/local/bin/update-duckdns.sh

# Add to crontab
(crontab -l 2>/dev/null | grep -v update-duckdns.sh; echo "*/5 * * * * /usr/local/bin/update-duckdns.sh >/dev/null 2>&1") | crontab -

echo ""
echo "=== SSL Certificate Setup Complete! ==="
echo ""
echo "Your MQTT Broker is now available at:"
echo "  https://${DOMAIN}"
echo "  https://${DOMAIN}/api (Swagger)"
echo "  https://${DOMAIN}/health"
echo "  wss://${DOMAIN}/ws (WebSocket - valid SSL!)"
echo ""
echo "Test the connection:"
echo "  curl https://${DOMAIN}/health"
echo ""
echo "Update your frontend to use:"
echo "  const socket = io('wss://${DOMAIN}/ws');"
echo "  // No rejectUnauthorized needed - valid SSL certificate!"

