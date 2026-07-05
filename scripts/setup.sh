#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="techmart"

echo "============================================"
echo " TechMart Platform — Full Setup"
echo "============================================"

# ─── Prerequisites ──────────────────────────────────
echo ""
echo "[1/8] Checking prerequisites..."

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker required"; exit 1; }
command -v kind >/dev/null 2>&1 || { echo "ERROR: kind required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl required"; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "ERROR: npm required"; exit 1; }

echo "  docker: OK"
echo "  kind:   OK"
echo "  kubectl: OK"
echo "  npm:    OK"

# ─── Install Node deps ──────────────────────────────
echo ""
echo "[2/8] Installing Node.js dependencies..."
cd "$ROOT/app/backend"
npm install --silent
cd "$ROOT"
echo "  Done"

# ─── Build Docker Image ─────────────────────────────
echo ""
echo "[3/8] Building Docker images..."
docker build -t techmart-api:latest "$ROOT/app/backend"
docker build -t techmart-frontend:latest "$ROOT/app/frontend"
echo "  Done"

# ─── Create KIND Cluster ────────────────────────────
echo ""
echo "[4/8] Creating KIND cluster (3 nodes)..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "  Cluster '$CLUSTER_NAME' already exists, skipping"
else
  kind create cluster --name "$CLUSTER_NAME" --config "$ROOT/kubernetes/kind-3-node.yaml"
  echo "  Done"
fi

# ─── Load Images ────────────────────────────────────
echo ""
echo "[5/8] Loading Docker images into KIND..."
kind load docker-image techmart-api:latest --name "$CLUSTER_NAME"
kind load docker-image techmart-frontend:latest --name "$CLUSTER_NAME"
echo "  Done"

# ─── Deploy K8s manifests ───────────────────────────
echo ""
echo "[6/8] Deploying Kubernetes manifests..."
kubectl apply -k "$ROOT/kubernetes/"
echo "  Waiting for postgres to be ready..."
kubectl wait --for=condition=ready --timeout=180s -n techmart pod -l app=postgres
echo "  Done"

# ─── Deploy Ingress Controller ──────────────────────
echo ""
echo "[7/8] Deploying NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml 2>/dev/null || true
kubectl wait --for=condition=ready --timeout=180s -n ingress-nginx pod -l app.kubernetes.io/component=controller 2>/dev/null || true
echo "  Done"

# ─── Initialize Database ────────────────────────────
echo ""
echo "[8/8] Initializing database schema + seed data..."
POD=$(kubectl get pod -n techmart -l app=postgres -o name | head -1)
kubectl exec -n techmart "$POD" -- psql -U postgres -d techmart -c "$(cat "$ROOT/app/backend/db/schema.sql")"
kubectl exec -n techmart "$POD" -- psql -U postgres -d techmart -c "$(cat "$ROOT/app/backend/db/seed.sql")"
echo "  Done"

# ─── Deploy Monitoring ──────────────────────────────
echo ""
echo "[9/9] Deploying monitoring stack..."
kubectl apply -f "$ROOT/monitoring/monitoring-namespace.yaml"
kubectl apply -f "$ROOT/monitoring/prometheus-config.yaml"
kubectl apply -f "$ROOT/monitoring/prometheus-deployment.yaml"
kubectl apply -f "$ROOT/monitoring/grafana-datasources.yaml"
kubectl apply -f "$ROOT/monitoring/grafana-deployment.yaml"
kubectl apply -f "$ROOT/monitoring/loki-config.yaml"
kubectl apply -f "$ROOT/monitoring/loki-deployment.yaml"
kubectl apply -f "$ROOT/monitoring/promtail-config.yaml"
kubectl apply -f "$ROOT/monitoring/promtail-deployment.yaml"
echo "  Waiting for monitoring pods..."
kubectl wait --for=condition=available --timeout=180s -n monitoring deploy/prometheus deploy/grafana deploy/loki 2>/dev/null || true
echo "  Done"

# ─── Verify ──────────────────────────────────────────
echo ""
echo "============================================"
echo " Verification"
echo "============================================"
echo ""
echo "Pods:"
kubectl get pods -A --sort-by=.metadata.namespace
echo ""
echo "API Health:"
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/health',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d))})" 2>/dev/null || echo "  (postgres may still be initializing)"
echo ""
echo "============================================"
echo " Setup Complete!"
echo "============================================"
echo ""
echo " Port forwards (run in separate terminals):"
echo "   kubectl port-forward -n techmart svc/techmart-frontend-service 8080:80"
echo "   kubectl port-forward -n techmart svc/techmart-service 3000:3000"
echo "   kubectl port-forward -n monitoring svc/grafana 3001:3000"
echo ""
echo " Frontend: http://localhost:8080"
echo " API: http://localhost:3000/health"
echo " Grafana: http://localhost:3001  (admin/admin)"
