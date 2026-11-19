#!/usr/bin/env bash
# ============================================================================
# Zamorin Demo — Tag-based deploy to EC2 via SSM
# Usage: ./scripts/deploy.sh <tag>   e.g. ./scripts/deploy.sh v0.2.0-demo
# Builds the backend image locally on the instance (no ECR needed for demo).
# ============================================================================
set -euo pipefail

TAG="${1:?Usage: $0 <git-tag>  (e.g. v0.2.0-demo)}"
REGION="${AWS_REGION:-ap-south-1}"
INSTANCE_ID="${EC2_INSTANCE_ID:?Set EC2_INSTANCE_ID env var}"

echo "=== Deploying tag $TAG to instance $INSTANCE_ID ==="

# 1. Ensure tag exists locally
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "ERROR: tag '$TAG' does not exist. Create it first: git tag $TAG"
  exit 1
fi

# 2. Checkout the tagged commit
git checkout "$TAG" 2>/dev/null || git checkout "tags/$TAG"

# 3. Trigger deploy on EC2 via SSM (no SSH needed)
echo "--- Triggering deploy via SSM ---"
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    \"cd /home/ubuntu/zamorin-demo && git pull\",
    \"docker compose up -d --build backend\",
    \"sleep 30 && curl -sf http://localhost:4000/health/ready && echo HEALTH_OK || echo HEALTH_FAILED\"
  ]" \
  --region "$REGION" \
  --query "Command.CommandId" --output text)

echo "--- Deploy triggered (Command ID: $COMMAND_ID) ---"
aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --region "$REGION" 2>/dev/null || true
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --region "$REGION" --query "StandardOutputContent" --output text

echo "=== Deploy complete. URL: https://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 | tr '.' '-').sslip.io ==="
