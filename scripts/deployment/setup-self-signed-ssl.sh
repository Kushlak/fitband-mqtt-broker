#!/bin/bash

# Setup HTTPS with self-signed certificate that works with WebSocket
# Usage: ./scripts/deployment/setup-self-signed-ssl.sh [instance-ip]

set -e

INSTANCE_IP="${1:-${INSTANCE_IP}}"
INSTANCE_NAME="${INSTANCE_NAME:-fitband-broker-app}"

if [ -z "$INSTANCE_IP" ]; then
  echo "Error: Instance IP required"
  echo "Usage: $0 <instance-ip>"
  echo "Or set INSTANCE_IP environment variable"
  exit 1
fi

echo "🔐 Setting up self-signed SSL certificate for WebSocket on EC2 instance $INSTANCE_IP..."
echo "⚠️  Note: Browsers will show a security warning, but you can accept it for WebSocket to work"

# Generate certificates on the server with proper SAN for IP address
echo "📜 Generating self-signed SSL certificate with IP in SAN..."
ssh -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP << EOF
  cd ~/fitband-mqtt-broker
  
  # Create certs directory and ensure proper ownership
  mkdir -p certs
  sudo chown -R \$USER:\$USER certs 2>/dev/null || true
  chmod 755 certs
  
  # Get the public IP
  PUBLIC_IP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "$INSTANCE_IP")
  
  # Create OpenSSL config file with SAN for IP address
  cat > /tmp/ssl.conf << CONFIG
[req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=State
L=City
O=Fitband
CN=\$PUBLIC_IP

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
IP.1 = \$PUBLIC_IP
DNS.1 = localhost
DNS.2 = *.localhost
CONFIG
  
  # Generate private key
  openssl genrsa -out certs/key.pem 4096
  
  # Generate certificate with SAN
  openssl req -new -x509 \
    -key certs/key.pem \
    -out certs/cert.pem \
    -days 365 \
    -config /tmp/ssl.conf \
    -extensions v3_req
  
  # Clean up
  rm /tmp/ssl.conf
  
  # Set proper permissions
  chmod 600 certs/key.pem
  chmod 644 certs/cert.pem
  
  echo "✅ Certificates generated successfully with IP: \$PUBLIC_IP"
  echo ""
  echo "Certificate details:"
  openssl x509 -in certs/cert.pem -text -noout | grep -A 2 "Subject Alternative Name"
EOF

# Update .env.prod to enable HTTPS
echo "📝 Updating .env.prod to enable HTTPS..."
ssh ubuntu@$INSTANCE_IP << 'EOF'
  cd ~/fitband-mqtt-broker
  
  # Backup existing .env.prod
  cp .env.prod .env.prod.backup 2>/dev/null || true
  
  # Update ENABLE_HTTPS and HTTPS_PORT
  if grep -q "^ENABLE_HTTPS=" .env.prod; then
    sed -i 's/^ENABLE_HTTPS=.*/ENABLE_HTTPS=true/' .env.prod
  else
    echo "ENABLE_HTTPS=true" >> .env.prod
  fi
  
  if grep -q "^HTTPS_PORT=" .env.prod; then
    sed -i 's/^HTTPS_PORT=.*/HTTPS_PORT=443/' .env.prod
  else
    echo "HTTPS_PORT=443" >> .env.prod
  fi
  
  echo "✅ .env.prod updated"
  echo ""
  echo "Current HTTPS settings:"
  grep -E "ENABLE_HTTPS|HTTPS_PORT" .env.prod || echo "Settings added"
EOF

# Ensure docker-compose.prod.yml has certs volume and port 443
echo "🐳 Verifying docker-compose.prod.yml configuration..."
ssh ubuntu@$INSTANCE_IP << 'EOF'
  cd ~/fitband-mqtt-broker
  
  # Check if certs volume exists
  if ! grep -q "certs:" docker-compose.prod.yml; then
    echo "⚠️  Warning: certs volume not found in docker-compose.prod.yml"
    echo "   Make sure docker-compose.prod.yml has:"
    echo "     volumes:"
    echo "       - ./certs:/app/certs:ro"
  fi
  
  # Check if port 443 is exposed
  if ! grep -q "443:443" docker-compose.prod.yml; then
    echo "⚠️  Warning: port 443 not found in docker-compose.prod.yml"
    echo "   Make sure docker-compose.prod.yml has:"
    echo "     ports:"
    echo "       - \"443:443\""
  fi
  
  echo "✅ docker-compose.prod.yml configuration checked"
EOF

# Restart container
echo "🔄 Restarting container..."
ssh ubuntu@$INSTANCE_IP << 'EOF'
  cd ~/fitband-mqtt-broker
  
  sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod down
  sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d
  
  echo "✅ Container restarted"
  
  # Wait a moment for container to start
  sleep 3
  
  # Check if container is running
  if sudo docker ps | grep -q fitband-mqtt-broker; then
    echo "✅ Container is running"
  else
    echo "⚠️  Warning: Container might not be running. Check logs:"
    echo "   sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod logs"
  fi
EOF

echo ""
echo "✅ Self-signed SSL setup complete!"
echo ""
echo "⚠️  IMPORTANT: This is a self-signed certificate"
echo "   - Browsers will show a security warning"
echo "   - You MUST accept the warning for WebSocket to work"
echo "   - In Chrome/Edge: Click 'Advanced' → 'Proceed to [IP] (unsafe)'"
echo "   - In Firefox: Click 'Advanced' → 'Accept the Risk and Continue'"
echo ""
echo "Test HTTPS:"
echo "  curl -k https://$INSTANCE_IP/health"
echo ""
echo "WebSocket URL (after accepting browser warning):"
echo "  wss://$INSTANCE_IP/ws"
echo ""
echo "For production, use Let's Encrypt with a domain name instead."

