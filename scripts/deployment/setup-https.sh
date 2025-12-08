#!/bin/bash

# Setup HTTPS with self-signed certificate on EC2 instance
# Usage: ./scripts/deployment/setup-https.sh [instance-ip]

set -e

INSTANCE_IP="${1:-${INSTANCE_IP}}"
INSTANCE_NAME="${INSTANCE_NAME:-fitband-broker-app}"

if [ -z "$INSTANCE_IP" ]; then
  echo "Error: Instance IP required"
  echo "Usage: $0 <instance-ip>"
  echo "Or set INSTANCE_IP environment variable"
  exit 1
fi

echo "🔐 Setting up HTTPS on EC2 instance $INSTANCE_IP..."

# Generate certificates on the server
echo "📜 Generating self-signed SSL certificate..."
ssh -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP << 'EOF'
  cd ~/fitband-mqtt-broker
  
  # Create certs directory
  mkdir -p certs
  
  # Generate self-signed certificate
  openssl req -x509 \
    -newkey rsa:4096 \
    -keyout certs/key.pem \
    -out certs/cert.pem \
    -days 365 \
    -nodes \
    -subj "/C=US/ST=State/L=City/O=Fitband/CN=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'localhost')"
  
  # Set proper permissions
  chmod 600 certs/key.pem
  chmod 644 certs/cert.pem
  
  echo "✅ Certificates generated successfully"
EOF

# Update .env.prod to enable HTTPS
echo "📝 Updating .env.prod to enable HTTPS..."
ssh ubuntu@$INSTANCE_IP << 'EOF'
  cd ~/fitband-mqtt-broker
  
  # Backup existing .env.prod
  cp .env.prod .env.prod.backup
  
  # Update ENABLE_HTTPS and HTTPS_PORT
  sed -i 's/^ENABLE_HTTPS=.*/ENABLE_HTTPS=true/' .env.prod
  sed -i 's/^HTTPS_PORT=.*/HTTPS_PORT=443/' .env.prod
  
  echo "✅ .env.prod updated"
  echo ""
  echo "Current HTTPS settings:"
  grep -E "ENABLE_HTTPS|HTTPS_PORT" .env.prod
EOF

# Update docker-compose.prod.yml to mount certs and expose port 443
echo "🐳 Updating docker-compose.prod.yml..."
ssh ubuntu@$INSTANCE_IP << 'EOF'
  cd ~/fitband-mqtt-broker
  
  # Backup docker-compose.prod.yml
  cp docker-compose.prod.yml docker-compose.prod.yml.backup
  
  # Check if certs volume already exists
  if ! grep -q "certs:" docker-compose.prod.yml; then
    # Add certs volume mount and port 443
    # Using sed to add volume mount after environment section
    sed -i '/environment:/a\    volumes:\n      - ./certs:/app/certs:ro' docker-compose.prod.yml
    
    # Add port 443 mapping
    sed -i 's|"8080:8080"|"8080:8080"\n      - "443:443"|' docker-compose.prod.yml
  fi
  
  echo "✅ docker-compose.prod.yml updated"
EOF

# Restart container
echo "🔄 Restarting container..."
ssh ubuntu@$INSTANCE_IP << 'EOF'
  cd ~/fitband-mqtt-broker
  
  sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod down
  sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d
  
  echo "✅ Container restarted"
EOF

echo ""
echo "✅ HTTPS setup complete!"
echo ""
echo "⚠️  This is a self-signed certificate - browsers will show security warnings"
echo "   For production, use Let's Encrypt with a domain name"
echo ""
echo "Test HTTPS:"
echo "  curl -k https://$INSTANCE_IP/health"
echo ""
echo "Or in browser (accept the security warning):"
echo "  https://$INSTANCE_IP/health"

