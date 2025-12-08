#!/bin/bash
# Get production Let's Encrypt certificate after rate limit expires
# Run this after waiting for rate limit to clear

set -e

DOMAIN="fitband-broker.duckdns.org"
EMAIL="lesionhib@gmail.com"

echo "Getting production SSL certificate for ${DOMAIN}..."
echo ""

# Kill any process on port 80
sudo lsof -ti :80 | xargs -r sudo kill -9 2>/dev/null || true
sleep 2

# Get certificate
sudo certbot certonly --standalone \
  -d ${DOMAIN} \
  --email ${EMAIL} \
  --agree-tos \
  --non-interactive \
  --preferred-challenges http

if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
  echo ""
  echo "✅ Production certificate obtained!"
  echo ""
  echo "Now run the rest of the setup:"
  echo "  cd ~"
  echo "  ./setup-ssl-auto.sh"
  echo ""
  echo "Or manually configure Nginx and restart Docker."
else
  echo "❌ Certificate not found. Check /var/log/letsencrypt/letsencrypt.log"
  exit 1
fi

