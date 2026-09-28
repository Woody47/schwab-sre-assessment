#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
require() { command -v "$1" >/dev/null || { echo "Missing command: $1" >&2; exit 1; }; }
for tool in gcloud terraform kubectl python3; do require "$tool"; done
PROJECT_ID="$(terraform -chdir=terraform/core output -raw project_id)"
context() {
  local cluster="$1" zone
  case "$cluster" in primary) zone=us-central1-a;; secondary) zone=us-east1-b;; *) return 1;; esac
  gcloud container clusters get-credentials "sre-$cluster" --zone "$zone" --project "$PROJECT_ID" >/dev/null
  CONTEXT="gke_${PROJECT_ID}_${zone}_sre-${cluster}"
}
