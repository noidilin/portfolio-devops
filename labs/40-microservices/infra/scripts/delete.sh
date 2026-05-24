#!/usr/bin/env bash
#
# Deletes the video-streaming Kubernetes resources from a Kustomize overlay.
#
# Environment variables:
#
#   KUSTOMIZE_OVERLAY - Optional overlay path. Defaults to ../k8s/overlays/prod.
#
# Usage:
#
#   ./infra/scripts/delete.sh
#

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OVERLAY=${KUSTOMIZE_OVERLAY:-"$SCRIPT_DIR/../k8s/overlays/prod"}

kubectl delete -k "$OVERLAY"
