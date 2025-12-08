#!/bin/bash
# Deploy Fitband MQTT Broker to AWS EC2

set -e

KEY_PATH="${AWS_KEY_PATH:-$HOME/.ssh/fitband-broker-key.pem}"
INSTANCE_NAME="${INSTANCE_NAME:-fitband-broker-app}"
INSTANCE_IP="${INSTANCE_IP:-}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Deploying Fitband MQTT Broker to AWS EC2 ===${NC}"

# Get branch to deploy (default to current branch, or use first argument)
DEPLOY_BRANCH="${1:-$(git branch --show-current 2>/dev/null || echo 'main')}"
GIT_REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")

if [ -z "$GIT_REPO_URL" ]; then
  echo -e "${RED}Error: Could not detect git remote URL${NC}"
  echo "Usage: ./deploy-to-aws.sh <branch-name>"
  exit 1
fi

echo -e "${GREEN}Deploying branch: ${DEPLOY_BRANCH}${NC}"
echo -e "${GREEN}Repository: ${GIT_REPO_URL}${NC}"
echo ""

# Get instance details
if [ -n "$INSTANCE_IP" ]; then
  # Use provided IP directly
  PUBLIC_IP="$INSTANCE_IP"
  echo -e "${GREEN}Using provided IP: ${PUBLIC_IP}${NC}"
else
  # Find instance by tag
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo "")

  if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
    echo -e "${YELLOW}No running instance found with tag Name=${INSTANCE_NAME}${NC}"
    echo "Either:"
    echo "  1. Set INSTANCE_IP environment variable: INSTANCE_IP=44.207.29.42 ./deploy-to-aws.sh"
    echo "  2. Create an EC2 instance with tag Name=${INSTANCE_NAME}"
    exit 1
  fi

  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
  
  echo -e "${GREEN}Found instance: ${INSTANCE_ID}${NC}"
fi

echo -e "${GREEN}Public IP: ${PUBLIC_IP}${NC}"
echo ""

# Check SSH key
if [ ! -f "$KEY_PATH" ]; then
  echo -e "${RED}SSH key not found at: ${KEY_PATH}${NC}"
  echo "Set AWS_KEY_PATH environment variable or create the key"
  exit 1
fi

# Deploy using git on server
echo -e "${BLUE}Setting up code on server...${NC}"
ssh -i ${KEY_PATH} -o StrictHostKeyChecking=no ubuntu@${PUBLIC_IP} << GIT_SETUP
set -e
cd /home/ubuntu

# Clone or update repository
if [ -d "fitband-mqtt-broker" ] && [ -d "fitband-mqtt-broker/.git" ]; then
  echo "Updating existing repository..."
  cd fitband-mqtt-broker
  git fetch origin
else
  echo "Cloning repository..."
  rm -rf fitband-mqtt-broker
  git clone ${GIT_REPO_URL} fitband-mqtt-broker
  cd fitband-mqtt-broker
fi

# Checkout branch
echo "Checking out branch: ${DEPLOY_BRANCH}"
git checkout ${DEPLOY_BRANCH} || git checkout -b ${DEPLOY_BRANCH} origin/${DEPLOY_BRANCH}
git pull origin ${DEPLOY_BRANCH} || git reset --hard origin/${DEPLOY_BRANCH}

echo ""
echo "Current branch:"
git branch --show-current
echo "Latest commit:"
git log -1 --oneline
GIT_SETUP

echo ""

# Copy production .env if exists locally
if [ -f ".env.prod" ]; then
  echo -e "${BLUE}Copying .env.prod to server...${NC}"
  scp -i ${KEY_PATH} -o StrictHostKeyChecking=no .env.prod ubuntu@${PUBLIC_IP}:/home/ubuntu/fitband-mqtt-broker/.env.prod
  echo -e "${GREEN}✓ .env.prod copied${NC}"
elif [ -f "env.example" ]; then
  echo -e "${YELLOW}Warning: .env.prod not found locally${NC}"
  echo "Please create .env.prod from env.example"
fi

echo ""

# Deploy application
echo -e "${BLUE}Deploying application...${NC}"
ssh -i ${KEY_PATH} -o StrictHostKeyChecking=no ubuntu@${PUBLIC_IP} << EOF
set -e
cd /home/ubuntu/fitband-mqtt-broker

# Check for .env.prod
if [ ! -f ".env.prod" ]; then
  echo -e "${RED}ERROR: .env.prod not found!${NC}"
  echo "Create .env.prod with production configuration"
  exit 1
fi

# Check disk space
echo "=== Checking disk space ==="
DISK_USAGE=\$(df -h / | tail -1 | awk '{print \$5}' | sed 's/%//')
echo "Disk usage: \${DISK_USAGE}%"

if [ "\$DISK_USAGE" -gt 80 ]; then
  echo "Disk usage high. Cleaning up Docker..."
  sudo docker system prune -a -f --volumes || true
fi

echo ""
echo "Stopping existing containers..."
sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod down 2>/dev/null || true

echo ""
echo "Building containers..."
sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod build

echo ""
echo "Running database migrations..."
sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod run --rm app npx prisma migrate deploy --schema=./prisma/schema.prisma || echo "Migration may have failed, continuing..."

echo ""
echo "Starting containers..."
sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d

echo "Waiting for services..."
sleep 10

echo ""
echo "Container status:"
sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod ps

echo ""
echo "Recent logs:"
sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod logs --tail=30
EOF

echo ""
echo -e "${GREEN}✓ Deployment complete!${NC}"
echo ""
echo -e "${BLUE}Service available at:${NC}"
echo "  http://${PUBLIC_IP}:8080/health"
echo "  http://${PUBLIC_IP}:8080/api (Swagger)"
echo "  ws://${PUBLIC_IP}:8080/ws (WebSocket)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Setup HTTPS: ./scripts/deployment/setup-https-duckdns.sh"
echo "2. Check status: ./scripts/deployment/check-status.sh"
echo ""

