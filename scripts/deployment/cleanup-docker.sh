#!/bin/bash
# Clean up Docker resources on EC2 to free disk space

set -e

KEY_PATH="${AWS_KEY_PATH:-$HOME/.ssh/fitband-broker-key.pem}"
INSTANCE_NAME="${INSTANCE_NAME:-fitband-mqtt-broker}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== Cleaning up Docker resources ===${NC}"
echo ""

# Get instance details
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
  echo -e "${YELLOW}No running instance found${NC}"
  exit 1
fi

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo -e "${GREEN}Instance: ${PUBLIC_IP}${NC}"
echo ""

# Cleanup
ssh -i ${KEY_PATH} -o StrictHostKeyChecking=no ubuntu@${PUBLIC_IP} << 'EOF'
echo "Before cleanup:"
df -h / | grep -E "Filesystem|/$"

echo ""
echo "Cleaning up Docker..."
sudo docker system prune -a -f --volumes
sudo docker builder prune -a -f

echo ""
echo "Cleaning package cache..."
sudo apt-get clean
sudo apt-get autoclean

echo ""
echo "After cleanup:"
df -h / | grep -E "Filesystem|/$"
EOF

echo ""
echo -e "${GREEN}✓ Cleanup complete${NC}"

