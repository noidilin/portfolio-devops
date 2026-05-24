#!/usr/bin/env bash
#
# Deploys the video-streaming microservice to Kubernetes using Kustomize.
#
# Environment variables:
#
#   CONTAINER_REGISTRY - The hostname of your container registry.
#   VERSION            - The image tag to deploy.
#   KUSTOMIZE_OVERLAY  - Optional overlay path. Defaults to ../k8s/overlays/prod.
#
# Usage:
#
#   CONTAINER_REGISTRY=<registry> VERSION=<tag> ./infra/scripts/deploy.sh
#

set -euo pipefail

: "${CONTAINER_REGISTRY:?CONTAINER_REGISTRY is required}"
: "${VERSION:?VERSION is required}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OVERLAY=${KUSTOMIZE_OVERLAY:-"$SCRIPT_DIR/../k8s/overlays/prod"}
IMAGE="$CONTAINER_REGISTRY/video-streaming:$VERSION"
WORK_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cp -R "$SCRIPT_DIR/../k8s" "$WORK_DIR/k8s"
OVERLAY_COPY="$WORK_DIR/k8s/overlays/$(basename "$OVERLAY")"

cd "$OVERLAY_COPY"
kustomize edit set image "video-streaming=$IMAGE"
kustomize build . | kubectl apply -f -
kubectl rollout status deployment/video-streaming
