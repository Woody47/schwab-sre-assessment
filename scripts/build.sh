#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require docker
IMAGE_REPO="$(terraform -chdir=terraform/core output -raw image_repository)"
TAG="$(git rev-parse --short HEAD 2>/dev/null || date -u +%Y%m%d%H%M%S)"
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
docker build --platform linux/amd64 -t "$IMAGE_REPO:$TAG" app
docker push "$IMAGE_REPO:$TAG"
DIGEST="$(gcloud artifacts docker images describe "$IMAGE_REPO:$TAG" --project "$PROJECT_ID" --format='value(image_summary.digest)')"
[[ "$DIGEST" == sha256:* ]] || { echo 'Failed to resolve image digest'; exit 1; }
mkdir -p .generated
printf '%s@%s\n' "$IMAGE_REPO" "$DIGEST" > .generated/image.txt
printf 'Built immutable image: %s@%s\n' "$IMAGE_REPO" "$DIGEST"
