#!/bin/bash
# Helper script to run Terraform with AWS credentials from current session

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Export AWS credentials from current session
echo "Exporting AWS credentials from current session..."
eval $(aws configure export-credentials --format env)

# Verify credentials are set
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "Error: Failed to export AWS credentials"
  echo "Make sure you're logged in: aws sso login (if using SSO)"
  exit 1
fi

echo "✓ AWS credentials exported"
echo "  Access Key: ${AWS_ACCESS_KEY_ID:0:10}..."
echo "  Region: ${AWS_DEFAULT_REGION:-us-east-1}"
echo ""

# Run terraform with the provided command
terraform "$@"

