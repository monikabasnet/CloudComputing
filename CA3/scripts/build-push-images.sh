#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
for t in aws docker; do command -v "$t" >/dev/null || { echo "Missing $t"; exit 1; }; done
ACCOUNT=$(aws sts get-caller-identity --profile "$CA3_PROFILE" --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$CA3_REGION.amazonaws.com"
TAG="${CA3_IMAGE_TAG:-ca3-rebuild-$(date +%Y%m%d)}"
# Explicit platform supports typical EKS x86 worker nodes from Apple Silicon Macs.
PLATFORM="${CA3_DOCKER_PLATFORM:-linux/amd64}"
read -r -p "Build and push producer/processor images with tag $TAG? Type PUSH-CA3: " reply
[[ "$reply" == PUSH-CA3 ]] || exit 1
aws ecr get-login-password --region "$CA3_REGION" --profile "$CA3_PROFILE" | docker login --username AWS --password-stdin "$REGISTRY"
for app in producer processor; do
  repo="ca2-$app"
  aws ecr describe-repositories --repository-names "$repo" --region "$CA3_REGION" --profile "$CA3_PROFILE" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$repo" --region "$CA3_REGION" --profile "$CA3_PROFILE" >/dev/null
  docker build --platform "$PLATFORM" -t "$REGISTRY/$repo:$TAG" "$ROOT/$app"
  docker push "$REGISTRY/$repo:$TAG"
done
printf 'IMAGE_TAG=%s\nREGISTRY=%s\n' "$TAG" "$REGISTRY"
echo 'NOTE: Deployment image references must be updated explicitly to this tag before rollout.'
