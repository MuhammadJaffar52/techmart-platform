#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="techmart"

echo "============================================"
echo " TechMart Platform — Full Teardown"
echo "============================================"

echo ""
echo "WARNING: This will destroy everything!"
read -p "Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

# ─── Option 1: Destroy only namespaces (faster) ────
echo ""
echo "[1/2] Deleting techmart and monitoring namespaces..."
kubectl delete namespace techmart --ignore-not-found --wait=true 2>/dev/null || true
kubectl delete namespace monitoring --ignore-not-found --wait=true 2>/dev/null || true
echo "  Namespaces deleted"

# ─── Option 2: Destroy the entire KIND cluster ─────
echo ""
echo "[2/2] Destroying KIND cluster '$CLUSTER_NAME'..."
kind delete cluster --name "$CLUSTER_NAME"
echo "  Cluster deleted"

echo ""
echo "============================================"
echo " Teardown Complete!"
echo "============================================"
echo ""
echo "To rebuild from scratch:"
echo "  bash scripts/setup.sh"
