#!/bin/bash
# Check deployment status on AWS EC2

set -e

KEY_PATH="${AWS_KEY_PATH:-$HOME/.ssh/fitband-broker-key.pem}"
INSTANCE_NAME="${INSTANCE_NAME:-fitband-mqtt-broker}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Checking Fitband MQTT Broker Status ===${NC}"
echo ""

# Get instance details
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
  echo -e "${RED}No running instance found${NC}"
  exit 1
fi

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo -e "${GREEN}Instance: ${INSTANCE_ID}${NC}"
echo -e "${GREEN}Public IP: ${PUBLIC_IP}${NC}"
echo ""

# Check SSH key
if [ ! -f "$KEY_PATH" ]; then
  echo -e "${RED}SSH key not found at: ${KEY_PATH}${NC}"
  exit 1
fi

# Get status from server
ssh -i ${KEY_PATH} -o StrictHostKeyChecking=no ubuntu@${PUBLIC_IP} << 'EOF'
set -e

echo "=== Docker Containers ==="
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers running"

echo ""
echo "=== Disk Usage ==="
df -h / | grep -E "Filesystem|/$"

echo ""
echo "=== Nginx Status ==="
if systemctl is-active --quiet nginx; then
  echo -e "\033[0;32m✓ Nginx is running\033[0m"
  sudo systemctl status nginx --no-pager | head -5
else
  echo -e "\033[0;31m✗ Nginx is not running\033[0m"
fi

echo ""
echo "=== Application Logs (last 20 lines) ==="
if [ -d "fitband-mqtt-broker" ]; then
  cd fitband-mqtt-broker
  sudo docker-compose logs --tail=20 2>/dev/null || echo "No logs available"
fi

echo ""
echo "=== Health Check ==="
curl -s http://localhost:8080/health || echo "Health check failed"
EOF

echo ""
echo -e "${GREEN}✓ Status check complete${NC}"

