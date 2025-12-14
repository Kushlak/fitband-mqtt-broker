#!/bin/bash
# Quick deployment script for Fitband MQTT Broker on AWS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Fitband MQTT Broker - AWS Deployment ===${NC}"
echo ""

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Error: terraform is not installed${NC}" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}Error: AWS CLI is not installed${NC}" >&2; exit 1; }

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
  echo -e "${YELLOW}terraform.tfvars not found. Creating from example...${NC}"
  cp terraform.tfvars.example terraform.tfvars
  echo -e "${YELLOW}Please edit terraform.tfvars with your configuration before continuing.${NC}"
  echo ""
  read -p "Press Enter to open terraform.tfvars in your editor, or Ctrl+C to cancel..."
  ${EDITOR:-nano} terraform.tfvars
fi

# Initialize Terraform
echo -e "${BLUE}Initializing Terraform...${NC}"
terraform init

# Validate configuration
echo -e "${BLUE}Validating configuration...${NC}"
terraform validate

# Show plan
echo -e "${BLUE}Creating deployment plan...${NC}"
terraform plan

# Confirm deployment
echo ""
echo -e "${YELLOW}Ready to deploy. This will create AWS resources.${NC}"
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Deployment cancelled."
  exit 0
fi

# Apply
echo -e "${BLUE}Deploying infrastructure...${NC}"
terraform apply -auto-approve

# Show outputs
echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
terraform output

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Wait 2-3 minutes for the application to start"
echo "2. Check health: curl http://\$(terraform output -raw ec2_public_ip):8080/health"
echo "3. SSH to instance: \$(terraform output -raw ssh_command)"
echo "4. View logs: ssh to instance, then: sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod logs -f"
echo ""

