#!/bin/bash
# Test deployed Fitband MQTT Broker
# Usage: ./test-deployment.sh [server-ip]

set -e

SERVER_IP="${1:-44.207.29.42}"
BASE_URL="http://${SERVER_IP}:8080"
WS_URL="ws://${SERVER_IP}:8080"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Testing Fitband MQTT Broker Deployment ===${NC}"
echo -e "Server: ${SERVER_IP}"
echo ""

# Test 1: Health endpoint
echo -e "${BLUE}1. Testing health endpoint...${NC}"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/health" || echo -e "\n000")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -1)
BODY=$(echo "$HEALTH_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✓ Health check passed${NC}"
  echo "  Response: $BODY"
else
  echo -e "${RED}✗ Health check failed (HTTP $HTTP_CODE)${NC}"
  echo "  Response: $BODY"
fi
echo ""

# Test 2: API endpoint
echo -e "${BLUE}2. Testing API endpoint...${NC}"
API_RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api" || echo -e "\n000")
API_HTTP_CODE=$(echo "$API_RESPONSE" | tail -1)

if [ "$API_HTTP_CODE" = "200" ] || [ "$API_HTTP_CODE" = "301" ] || [ "$API_HTTP_CODE" = "302" ]; then
  echo -e "${GREEN}✓ API endpoint accessible${NC}"
else
  echo -e "${YELLOW}⚠ API endpoint returned HTTP $API_HTTP_CODE${NC}"
fi
echo ""

# Test 3: WebSocket connection (basic)
echo -e "${BLUE}3. Testing WebSocket endpoint...${NC}"
echo -e "${YELLOW}  (Run WebSocket test separately with test-websocket.js)${NC}"
echo "  Command: node scripts/utils/test-websocket.js ${BASE_URL}"
echo ""

# Test 4: Container status (if SSH available)
echo -e "${BLUE}4. Container status check...${NC}"
echo -e "${YELLOW}  SSH to server and run: sudo docker ps${NC}"
echo ""

# Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✓ Application is running!${NC}"
  echo ""
  echo -e "${BLUE}Access URLs:${NC}"
  echo "  Health:    ${BASE_URL}/health"
  echo "  API:       ${BASE_URL}/api"
  echo "  WebSocket: ${WS_URL}/ws"
else
  echo -e "${RED}✗ Application may not be running correctly${NC}"
  echo "  Check logs: ssh to server, then: sudo docker logs fitband-mqtt-broker"
fi

