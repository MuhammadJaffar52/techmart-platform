# TechMart Platform — Reference Guide

## Technologies Used

| Category | Technologies |
|---|---|
| **Runtime** | Node.js 20 (Express 5), PostgreSQL 16 |
| **Container** | Docker, Docker Compose, .dockerignore, multi-stage builds |
| **Orchestration** | Kubernetes (KIND 1.30, 3 nodes), kubelet, containerd, CoreDNS |
| **K8s Resources** | Namespace, ConfigMap, Secret, Deployment, Service, Ingress, PVC, Kustomize, NetworkPolicy |
| **Packaging** | Helm 3 (Chart.yaml, 8 templates) |
| **CI/CD** | GitHub Actions (lint → build → deploy to KIND) |
| **IaC** | Terraform (Docker provider), Ansible (playbook + inventory) |
| **Monitoring** | Prometheus, Grafana, Loki, Promtail |
| **Security** | K8s NetworkPolicy, non-root containers, RBAC |
| **Chaos** | Chaos Mesh (PodChaos experiment) |
| **Service Mesh** | Istio VirtualService + DestinationRule (canary) |
| **Git** | Git, GitHub, branching strategies |

## What's Running (24 Pods, 4 Namespaces)

### techmart namespace — The App
- `techmart-frontend` — React SPA served by Nginx, product catalog with category filters + live status
- `techmart-api` x2 — Express API with /health, /metrics, full CRUD
- `postgres` — PostgreSQL with schema + 8 seed products

### monitoring namespace — Visualization
- `grafana` — Dashboard UI (auto-configured Prometheus + Loki datasources)
- `prometheus` — Scrapes techmart-api + K8s node/pod metrics
- `loki` — Log storage
- `promtail` — Collects pod logs → Loki

### ingress-nginx — Ingress Controller
- `ingress-nginx-controller` — Routes `/api` → backend, `/` → frontend

### kube-system — K8s infrastructure

## Commands to Check Your Infrastructure

### Layer 1 — Docker Host
```bash
docker ps
docker images | grep techmart
```

### Layer 2 — KIND Cluster
```bash
kind get clusters
kubectl cluster-info
kubectl get nodes -o wide
```

### Layer 3 — All Pods Everywhere
```bash
kubectl get pods -A -o wide
```

### Layer 4 — TechMart App
```bash
kubectl get all -n techmart
kubectl get endpoints -n techmart
kubectl get cm,secret -n techmart
```

### Layer 5 — Monitoring Stack
```bash
kubectl get all -n monitoring
```

### Layer 6 — API Health (inside cluster)
```bash
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/health',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d))})"
```

### Layer 7 — API Metrics
```bash
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/metrics',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d.slice(0,400)))})"
```

### Layer 8 — Prometheus Scrape Check
```bash
kubectl exec -n monitoring deploy/prometheus -- wget -qO- --timeout=3 http://techmart-service.techmart:3000/health
```

### Layer 9 — Grafana Reachability
```bash
kubectl exec -n monitoring deploy/grafana -- wget -qO- --timeout=3 http://prometheus:9090/-/ready
```

### Layer 10 — Port Forwards (for your browser)
```bash
# TechMart Frontend (product catalog UI)
kubectl port-forward -n techmart svc/techmart-frontend-service 8080:80
# → http://localhost:8080

# TechMart API
kubectl port-forward -n techmart svc/techmart-service 3000:3000
# → http://localhost:3000/health
# → http://localhost:3000/api/products
# → http://localhost:3000/api/products/1

# Grafana dashboard
kubectl port-forward -n monitoring svc/grafana 3001:3000
# → http://localhost:3001  (admin/admin)
```

### One-liner — Pod Status Summary
```bash
kubectl get pods -A --sort-by=.metadata.namespace
```

---

## Setup Commands in Sequence (Rebuild from Scratch)

Run these in order on a fresh clone:

```bash
# Prerequisites check
docker --version && kind --version && kubectl version --client && node --version

# Step 1 — Build Docker images
docker build -t techmart-api:latest app/backend
docker build -t techmart-frontend:latest app/frontend

# Step 2 — Create 3-node KIND cluster
kind create cluster --name techmart --config kubernetes/kind-3-node.yaml

# Step 3 — Load images into cluster nodes
kind load docker-image techmart-api:latest --name techmart
kind load docker-image techmart-frontend:latest --name techmart

# Step 4 — Deploy all K8s resources (backend + frontend via Kustomize)
kubectl apply -k kubernetes/

# Step 5 — Wait for postgres
kubectl wait --for=condition=ready --timeout=180s -n techmart pod -l app=postgres

# Step 6 — Deploy Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --for=condition=ready --timeout=180s -n ingress-nginx pod -l app.kubernetes.io/component=controller

# Step 7 — Initialize database schema + seed data
kubectl exec -n techmart deploy/postgres -- psql -U postgres -d techmart -c "$(cat app/backend/db/schema.sql)"
kubectl exec -n techmart deploy/postgres -- psql -U postgres -d techmart -c "$(cat app/backend/db/seed.sql)"

# Step 8 — Deploy monitoring stack
kubectl apply -f monitoring/monitoring-namespace.yaml
kubectl apply -f monitoring/prometheus-config.yaml
kubectl apply -f monitoring/prometheus-deployment.yaml
kubectl apply -f monitoring/grafana-datasources.yaml
kubectl apply -f monitoring/grafana-deployment.yaml
kubectl apply -f monitoring/loki-config.yaml
kubectl apply -f monitoring/loki-deployment.yaml
kubectl apply -f monitoring/promtail-config.yaml
kubectl apply -f monitoring/promtail-deployment.yaml

# Step 9 — Verify all pods are running
kubectl get pods -A --sort-by=.metadata.namespace

# Step 10 — Test API health
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/health',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d))})"

# Step 11 — Test frontend HTML
kubectl exec -n techmart deploy/techmart-frontend -- sh -c "cat /usr/share/nginx/html/index.html | head -3"
```

### Automated (one command)
```bash
bash scripts/setup.sh
```

### Destroy everything
```bash
bash scripts/teardown.sh
```
