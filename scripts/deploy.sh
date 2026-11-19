#!/usr/bin/env bash
# ============================================================================
# Zamorin Demo — Tag-based deploy to EC2 via ECR + SSM
# Usage: ./scripts/deploy.sh <tag>   e.g. ./scripts/deploy.sh v0.1.0-demo
# ============================================================================
set -euo pipefail

TAG="${1:?Usage: $0 <git-tag>  (e.g. v0.1.0-demo)}"
REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/zamorin-demo"
INSTANCE_ID="${EC2_INSTANCE_ID:?Set EC2_INSTANCE_ID env var}"

echo "=== Deploying tag $TAG to instance $INSTANCE_ID ==="

# 1. Ensure tag exists locally
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "ERROR: tag '$TAG' does not exist. Create it first: git tag $TAG"
  exit 1
fi

# 2. Checkout the tagged commit
git checkout "$TAG" 2>/dev/null || git checkout "tags/$TAG"

# 3. Build + push image to ECR
echo "--- Authenticating to ECR ---"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

echo "--- Building image ---"
docker build -t zamorin-demo .

echo "--- Pushing to ECR ---"
docker tag zamorin-demo:latest "$ECR_REPO:$TAG"
docker tag zamorin-demo:latest "$ECR_REPO:latest"
docker push "$ECR_REPO:$TAG"
docker push "$ECR_REPO:latest"

# 4. Trigger deploy on EC2 via SSM (no SSH needed)
echo "--- Triggering deploy via SSM ---"
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    \"aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com\",
    \"cd /home/ubuntu/zamorin-demo && git pull\",
    \"IMAGE_TAG=$TAG docker compose pull backend\",
    \"IMAGE_TAG=$TAG docker compose up -d --no-deps backend\",
    \"sleep 20 && curl -sf http://localhost:4000/health/ready && echo HEALTH_OK || echo HEALTH_FAILED\"
  ]" \
  --region "$REGION" \
  --query "Command.CommandId" --output text)

echo "--- Deploy triggered (Command ID: $COMMAND_ID) ---"
aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --region "$REGION" 2>/dev/null || true
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --region "$REGION" --query "StandardOutputContent" --output text

echo "=== Deploy complete. URL: https://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 | tr '.' '-').sslip.io ==="
