# TechMart Platform — DevOps Troubleshooting Lab

> **Purpose:** A hands-on DevOps lab where every component is built from scratch, intentionally broken, diagnosed, and fixed. The TechMart app is the victim — troubleshooting is the skill.

---

## Table of Contents
- [Project Overview](#project-overview)
- [Technologies Used](#technologies-used)
- [Architecture Flow](#architecture-flow)
- [Complete Build Sequence (Step-by-Step with Commands)](#complete-build-sequence-step-by-step-with-commands)
- [What's Running Now](#whats-running-now)
- [How to Check the Infrastructure](#how-to-check-the-infrastructure)
- [How to Rebuild from Scratch](#how-to-rebuild-from-scratch)
- [How to Destroy Everything](#how-to-destroy-everything)
- [Troubleshooting — What to Break](#troubleshooting--what-to-break)
- [Future Roadmap](#future-roadmap)
- [File Structure](#file-structure)

---

## Project Overview

TechMart is an e-commerce platform (Node.js/Express + PostgreSQL) deployed on a 3-node KIND Kubernetes cluster with full monitoring (Prometheus + Grafana + Loki), Helm packaging, CI/CD pipeline, security policies, chaos engineering, and service mesh configs. Every component is defined as code — nothing is manual.

**Why this exists:** This is not just an app. It's a training ground for real-world DevOps scenarios. After building everything, we intentionally inject errors (wrong image tags, missing ConfigMaps, broken probes, tainted nodes) and practice diagnosing/fixing them using the same tools and commands used in production.

---

## Technologies Used

| Category | Technologies | Purpose |
|---|---|---|
| **Runtime** | Node.js 20, Express 5, PostgreSQL 16 | Backend API + database |
| **Container** | Docker, multi-stage builds, .dockerignore | Containerization |
| **Orchestration** | KIND 1.30 (3 nodes), kubelet, containerd, CoreDNS | Local Kubernetes cluster |
| **K8s Resources** | Namespace, ConfigMap, Secret, Deployment, Service, Ingress, PVC, Kustomize, NetworkPolicy | App deployment |
| **Packaging** | Helm 3 (Chart.yaml, 8 templates) | Parameterized K8s deployments |
| **CI/CD** | GitHub Actions (lint → build → deploy to KIND) | Automated pipeline |
| **IaC** | Terraform (Docker provider), Ansible (playbook) | Infra as Code |
| **Monitoring** | Prometheus, Grafana, Loki, Promtail | Metrics + logs + dashboards |
| **Security** | K8s NetworkPolicy, non-root containers, RBAC | Pod security |
| **Chaos** | Chaos Mesh (PodChaos experiment) | Failure injection |
| **Service Mesh** | Istio VirtualService + DestinationRule | Canary deployments |
| **Git** | Git, GitHub, feature branches | Source control |

---

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Repository                        │
│  techmart-platform/                                          │
└─────────────────────┬───────────────────────────────────────┘
                      │ git clone
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   KIND Cluster (techmart)                    │
│                                                              │
│  ┌──────────────────────┐    ┌──────────────────────────┐   │
│  │   techmart namespace │    │    monitoring namespace   │   │
│  │                      │    │                           │   │
│  │  techmart-api x2     │    │  Prometheus ──┐           │   │
│  │     │                │    │       │        │           │   │
│  │     ▼                │    │       ▼        ▼           │   │
│  │  postgres-service ───┼────┼──► Grafana   Loki         │   │
│  │                      │    │       ▲        ▲           │   │
│  │  ConfigMap           │    │       │        │           │   │
│  │  Secret              │    │  promtail──────┘           │   │
│  │  Ingress             │    │  (collects pod logs)       │   │
│  └──────────────────────┘    └──────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                kube-system                            │   │
│  │  control-plane | worker | worker2                     │   │
│  │  CoreDNS, etcd, kube-apiserver, kube-proxy, kindnet   │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

Access:
  Grafana    → port-forward 3001:3000  → http://localhost:3001  (admin/admin)
  Prometheus → port-forward 9090:9090  → http://localhost:9090
  API        → port-forward 3000:3000  → http://localhost:3000/api/products
```

---

## Complete Build Sequence (Step-by-Step with Commands)

This is the exact sequence of steps we followed to build the entire project from scratch. Each step includes the commands used and why.

### Phase 0 — Environment Setup

```bash
# Install core tools
sudo apt update && sudo apt install -y docker.io git curl
sudo snap install kind --classic
curl -LO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs
sudo snap install helm --classic
```

### Phase 1 — Create Project Structure

```bash
# Initialize git repo
mkdir -p techmart-platform && cd techmart-platform
git init
git add . && git commit -m "Initialize TechMart project structure"
```

### Phase 2 — Build Backend API

```bash
# Create Express API with PostgreSQL
mkdir -p app/backend/db
# Created index.js with CRUD for products, users, cart, orders
# Created db/schema.sql (5 tables) and db/seed.sql (8 products)
# Added /health endpoint, /metrics endpoint (prom-client)

# Install dependencies
cd app/backend
npm install express pg prom-client
cd ../..
git add . && git commit -m "feat: backend API, DB schema, seed data, KIND cluster config"
```

### Phase 3 — Dockerize the Application

```bash
# Create multi-stage Dockerfile with non-root user + healthcheck
# file: app/backend/Dockerfile
cat > app/backend/Dockerfile << 'EOF'
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
USER appuser
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1
CMD ["node", "index.js"]
EOF

# Create .dockerignore
echo -e "node_modules\nnpm-debug.log\n.env\n.git\n.gitignore\n*.md" > app/backend/.dockerignore

# Build image
docker build -t techmart-api:latest app/backend
```

### Phase 4 — Create Docker Compose (Local Dev)

```bash
# file: docker/docker-compose.yml (backend + postgres with health checks)
# file: docker/.env (environment variables)

docker compose -f docker/docker-compose.yml up -d
```

### Phase 5 — Create 3-Node KIND Cluster

```bash
# file: kubernetes/kind-3-node.yaml
cat > kubernetes/kind-3-node.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

# Create the cluster
kind create cluster --name techmart --config kubernetes/kind-3-node.yaml

# Verify
kubectl get nodes -o wide
kubectl cluster-info
```

### Phase 6 — Deploy TechMart to Kubernetes

```bash
# Create all K8s manifests:
#   techmart-namespace.yaml    → isolates techmart resources
#   techmart-config.yaml       → ConfigMap (DB_HOST, DB_PORT, DB_NAME, PORT)
#   techmart-secret.yaml       → Secret (DB_USER, DB_PASSWORD - base64)
#   postgres-deployment.yaml   → Postgres + PVC + Service (5432)
#   techmart-deployment.yaml   → API x2 replicas + envFrom ConfigMap/Secret
#   techmart-service.yaml      → ClusterIP on port 3000
#   techmart-ingress.yaml      → Ingress (techmart.local)
#   kustomization.yaml         → Kustomize to apply all at once

# Deploy
kubectl apply -k kubernetes/

# Wait for postgres
kubectl wait --for=condition=ready --timeout=180s -n techmart pod -l app=postgres

# Initialize database
kubectl exec -n techmart deploy/postgres -- psql -U postgres -d techmart -c "$(cat app/backend/db/schema.sql)"
kubectl exec -n techmart deploy/postgres -- psql -U postgres -d techmart -c "$(cat app/backend/db/seed.sql)"

# Load Docker image into KIND cluster nodes
kind load docker-image techmart-api:latest --name techmart

# Restart API with new image
kubectl rollout restart -n techmart deploy/techmart-api
kubectl wait --for=condition=available --timeout=60s -n techmart deploy/techmart-api

# Verify
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/health',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d))})"
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/api/products',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(JSON.parse(d).length+' products'))})"
```

### Phase 7 — Deploy Monitoring Stack

```bash
# Create monitoring namespace + Prometheus config + Deployment + Service
# Prometheus scrapes techmart-service:3000/metrics

# Create Grafana (auto-configured with Prometheus + Loki datasources)

# Create Loki (log storage) + Promtail (log collector DaemonSet)

# Deploy everything
kubectl apply -f monitoring/monitoring-namespace.yaml
kubectl apply -f monitoring/prometheus-config.yaml
kubectl apply -f monitoring/prometheus-deployment.yaml
kubectl apply -f monitoring/grafana-datasources.yaml
kubectl apply -f monitoring/grafana-deployment.yaml
kubectl apply -f monitoring/loki-config.yaml
kubectl apply -f monitoring/loki-deployment.yaml
kubectl apply -f monitoring/promtail-config.yaml
kubectl apply -f monitoring/promtail-deployment.yaml

# Wait for readiness
kubectl wait --for=condition=available --timeout=120s -n monitoring deploy/prometheus deploy/grafana deploy/loki

# Verify
kubectl exec -n monitoring deploy/prometheus -- wget -qO- --timeout=3 http://techmart-service.techmart:3000/health
kubectl exec -n monitoring deploy/grafana -- wget -qO- --timeout=3 http://prometheus:9090/-/ready
```

### Phase 8 — Create Helm Chart

```bash
# file: helm/techmart/
# Chart.yaml, values.yaml, 8 templates (namespace, configmap, secret, deployment, service, ingress, postgres, helpers)
helm lint helm/techmart/
helm template techmart helm/techmart/  # verify rendering
```

### Phase 9 — Create CI/CD Pipeline

```bash
# file: .github/workflows/deploy.yml
# Stages: lint → build (Docker) → deploy to KIND
```

### Phase 10 — Create Supporting Infrastructure

```bash
# Terraform: terraform/main.tf → Docker provider for local infra
# Ansible: ansible/playbook.yml → Docker Compose deploy via SSH
# Security: security/network-policy.yaml → restrict pod traffic
# Chaos: chaos-engineering/experiment.yaml → PodChaos every 5m
# Service Mesh: service-mesh/virtual-service.yaml → Istio 90/10 canary
# Documentation: documentation/error-reference.md → 477-line error guide
# Troubleshooting: troubleshooting/scenarios.md → 30+ error injection scenarios
```

### Phase 11 — Setup Scripts for Full Reproducibility

```bash
# scripts/setup.sh → one-command rebuild
# scripts/teardown.sh → one-command destroy
# SETUP.md → full documentation
# REFERENCE.md → quick reference with all check commands
```

### Phase 12 — Push to GitHub

```bash
git remote add origin https://github.com/MuhammadJaffar52/techmart-platform.git
git add -A && git commit -m "full project"
git push origin main
```

---

## What's Running Now

```
Namespace: techmart
├── techmart-api (x2 replicas)  → Express API on :3000
│   ├── /health                 → DB connectivity check
│   ├── /metrics                → Prometheus metrics (prom-client)
│   ├── /api/products           → CRUD (GET, POST, PUT, DELETE)
│   ├── /api/users              → Register + Login
│   ├── /api/cart               → Cart operations
│   └── /api/orders             → Order placement with DB transactions
└── postgres                    → PostgreSQL 16, 5 tables, 8 seed products

Namespace: monitoring
├── prometheus                  → Scrapes techmart-api + K8s metrics
├── grafana                     → Dashboards (auto-configured datasources)
├── loki                        → Log storage
└── promtail                    → DaemonSet collecting pod logs → Loki

Namespace: kube-system
├── coredns, etcd, kube-apiserver
├── kube-controller-manager, kube-scheduler
├── kube-proxy, kindnet
└── local-path-provisioner
```

---

## How to Check the Infrastructure

### Layer 1 — Docker
```bash
docker ps                    # KIND cluster containers
docker images techmart-api   # The app image
```

### Layer 2 — KIND Cluster
```bash
kind get clusters
kubectl cluster-info
kubectl get nodes -o wide
```

### Layer 3 — All Pods
```bash
kubectl get pods -A --sort-by=.metadata.namespace
```

### Layer 4 — TechMart App
```bash
kubectl get all -n techmart
kubectl get endpoints -n techmart
kubectl get cm,secret -n techmart
```

### Layer 5 — Monitoring
```bash
kubectl get all -n monitoring
```

### Layer 6 — API Health
```bash
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/health',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d))})"
```

### Layer 7 — API Metrics
```bash
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/metrics',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d.slice(0,400)))})"
```

### Layer 8 — Browser Access
```bash
# Terminal 1
kubectl port-forward -n monitoring svc/grafana 3001:3000
# → http://localhost:3001  (admin/admin)

# Terminal 2
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# → http://localhost:9090

# Terminal 3
kubectl port-forward -n techmart svc/techmart-service 3000:3000
# → http://localhost:3000/api/products
```

---

## How to Rebuild from Scratch

### One command
```bash
git clone https://github.com/MuhammadJaffar52/techmart-platform.git
cd techmart-platform
bash scripts/setup.sh
```

### Manual (9 steps)
```bash
# 1. Build image
docker build -t techmart-api:latest app/backend

# 2. Create cluster
kind create cluster --name techmart --config kubernetes/kind-3-node.yaml

# 3. Load image
kind load docker-image techmart-api:latest --name techmart

# 4. Deploy app
kubectl apply -k kubernetes/

# 5. Wait for postgres
kubectl wait --for=condition=ready --timeout=180s -n techmart pod -l app=postgres

# 6. Init DB
kubectl exec -n techmart deploy/postgres -- psql -U postgres -d techmart -c "$(cat app/backend/db/schema.sql)"
kubectl exec -n techmart deploy/postgres -- psql -U postgres -d techmart -c "$(cat app/backend/db/seed.sql)"

# 7. Deploy monitoring
kubectl apply -f monitoring/monitoring-namespace.yaml
kubectl apply -f monitoring/prometheus-config.yaml
kubectl apply -f monitoring/prometheus-deployment.yaml
kubectl apply -f monitoring/grafana-datasources.yaml
kubectl apply -f monitoring/grafana-deployment.yaml
kubectl apply -f monitoring/loki-config.yaml
kubectl apply -f monitoring/loki-deployment.yaml
kubectl apply -f monitoring/promtail-config.yaml
kubectl apply -f monitoring/promtail-deployment.yaml

# 8. Verify
kubectl get pods -A --sort-by=.metadata.namespace

# 9. Test API
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/health',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d))})"
```

---

## How to Destroy Everything

```bash
# Option 1 — Namespaces only (cluster stays)
kubectl delete namespace techmart --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found

# Option 2 — Full destroy
bash scripts/teardown.sh
```

---

## Troubleshooting — What to Break

Every scenario below is documented in `troubleshooting/scenarios.md` with exact commands to inject the error and the fix. Reference errors in `documentation/error-reference.md` (477 lines).

### Docker (Phase 1)
| Scenario | Inject |
|---|---|
| COPY failed | Build from wrong context |
| Container exits | Change CMD to short-lived process |
| exec format error | Force wrong platform arch |
| Pull rate limit | Run 200 sequential pulls |
| Can't reach Postgres | Start container without network link |

### Docker Compose (Phase 2)
| Scenario | Inject |
|---|---|
| Service never starts | Remove health check condition |
| Env vars not found | Delete .env file |
| Backend can't reach DB | Mismatched service names |
| Port conflict | Run nginx on port 3000 first |
| Data disappears | Use anonymous volume |

### Kubernetes Crash (Phase 3)
| Scenario | Inject |
|---|---|
| CrashLoopBackOff | Bad command in Deployment |
| ImagePullBackOff | Non-existent image tag |
| Missing ConfigMap | Delete ConfigMap |
| OOMKilled | Set memory limit to 32Mi |
| Pod stuck Pending | Request 100 CPU cores |

### Kubernetes Networking (Phase 4)
| Scenario | Inject |
|---|---|
| No endpoints | Mismatch labels vs selector |
| Probe failing | Wrong health check path |
| Probe killing pod | Ultra-strict liveness probe |
| Connection refused | Wrong containerPort |
| No nodes available | Taint all workers |

### Helm (Phase 5)
| Scenario | Inject |
|---|---|
| nil pointer | Delete key from values.yaml |
| YAML parse | Break template indentation |
| No deployed releases | Delete Helm secret |
| Rollback fails | CRD schema change |
| Timed out | Use non-existent image |

### Git (Phase 6)
| Scenario | Inject |
|---|---|
| Detached HEAD | Checkout commit hash |
| Merge conflict | Conflicting changes |
| Force-push loss | reset --hard + push --force |

### CI/CD (Phase 7)
| Scenario | Inject |
|---|---|
| Build fails | Missing secret in environment |
| Job stuck queued | self-hosted runner label |
| Artifact not found | Name mismatch |

### Advanced (Phase 8)
| Scenario | Inject |
|---|---|
| Terraform state lock | Parallel apply |
| Ansible SSH fail | Wrong inventory host |
| Prometheus target DOWN | Wrong scrape config |
| Istio sidecar missing | Missing injection label |

---

## Future Roadmap

| Phase | Topic | What We'll Build |
|---|---|---|
| ✅ | **Phase 0** | Workstation setup, tools, first KIND cluster |
| ✅ | **Phase 1-2** | Backend API, Docker, Compose |
| ✅ | **Phase 3-4** | K8s deployment, networking, probes |
| ✅ | **Phase 5** | Helm chart |
| ✅ | **Phase 6** | Git scenarios |
| ✅ | **Phase 7** | CI/CD pipeline |
| ✅ | **Phase 8** | Monitoring (Prometheus, Grafana, Loki) + Advanced (Terraform, Ansible, Security, Chaos, Service Mesh) |
| ⬜ | **Phase 9** | React frontend (multi-stage Nginx build) |
| ⬜ | **Phase 10** | Redis caching + session store |
| ⬜ | **Phase 11** | GitOps (ArgoCD) |
| ⬜ | **Phase 12** | AWS migration (EKS, RDS, ElastiCache) |
| ⬜ | **Phase 13** | Production incident lab (simulated outages) |

---

## File Structure

```
techmart-platform/
├── scripts/
│   ├── setup.sh              # One-command rebuild
│   └── teardown.sh           # One-command destroy
├── app/backend/              # Node.js Express API
│   ├── index.js              # API server (CRUD + /health + /metrics)
│   ├── Dockerfile            # Multi-stage build (non-root, healthcheck)
│   ├── .dockerignore
│   ├── package.json
│   └── db/
│       ├── schema.sql        # 5 tables
│       └── seed.sql          # 8 products
├── docker/
│   └── docker-compose.yml    # Local dev stack
├── kubernetes/               # K8s manifests (Kustomize)
│   ├── kind-3-node.yaml      # KIND cluster config
│   ├── kustomization.yaml
│   ├── techmart-namespace.yaml
│   ├── techmart-config.yaml  # ConfigMap
│   ├── techmart-secret.yaml  # Secret (base64)
│   ├── postgres-deployment.yaml  # Postgres + PVC + Service
│   ├── techmart-deployment.yaml  # API x2 + ConfigMap/Secret refs
│   ├── techmart-service.yaml # ClusterIP :3000
│   └── techmart-ingress.yaml # Ingress
├── helm/techmart/            # Helm chart (8 templates)
├── monitoring/               # Prometheus, Grafana, Loki, Promtail
├── security/                 # NetworkPolicy
├── service-mesh/             # Istio VirtualService + DestinationRule
├── chaos-engineering/        # Chaos Mesh PodChaos
├── terraform/                # Docker provider IaC
├── ansible/                  # Docker Compose deploy playbook
├── cicd/                     # CI/CD pipeline configs
├── .github/workflows/        # GitHub Actions
├── troubleshooting/
│   └── scenarios.md          # 30+ error injection scenarios
├── documentation/
│   └── error-reference.md    # 477-line error guide (K8s, Docker, Helm, Terraform, CI/CD, AWS, Git, Istio, Jenkins, Ansible, Prometheus)
├── SETUP.md                  # Rebuild documentation
├── REFERENCE.md              # Quick reference (tech + commands)
├── AGENTS.md                 # Lab guide (source of truth for sessions)
└── README.md                 # This file
```

---

*Built step by step, component by component. Break it to learn it.*
