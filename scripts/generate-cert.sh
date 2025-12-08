#!/bin/bash

# Generate self-signed SSL certificate for development
# Usage: ./scripts/generate-cert.sh

CERT_DIR="certs"
KEY_FILE="$CERT_DIR/key.pem"
CERT_FILE="$CERT_DIR/cert.pem"

echo "Generating self-signed SSL certificate for development..."

# Create certs directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Generate private key and certificate
openssl req -x509 \
  -newkey rsa:4096 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -days 365 \
  -nodes \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

echo ""
echo "✅ Certificate generated successfully!"
echo ""
echo "Files created:"
echo "  - Private key: $KEY_FILE"
echo "  - Certificate: $CERT_FILE"
echo ""
echo "To enable HTTPS, set in your .env file:"
echo "  ENABLE_HTTPS=true"
echo "  HTTPS_PORT=8443"
echo ""
echo "⚠️  This is a self-signed certificate for DEVELOPMENT ONLY!"
echo "    For production, use Let's Encrypt or a proper CA."

