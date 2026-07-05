# TechMart Platform — Setup, Teardown & Reproducibility

## Strategy

This project is designed to be **fully reproducible from a single `git clone`**. Every infrastructure component is defined as code:

```
clone repo → run setup.sh → full stack running on KIND
```

No manual steps, no forgotten configs, no hidden state. Destroy and rebuild in minutes.

---

## How to Rebuild from Scratch

### Prerequisites (install once)

| Tool | Version | Check |
|---|---|---|
| Docker | 24+ | `docker --version` |
| KIND | 0.20+ | `kind --version` |
| kubectl | 1.30+ | `kubectl version --client` |
| Node.js | 20+ | `node --version` |
| npm | 10+ | `npm --version` |
| Helm (optional) | 3+ | `helm version` |

### Full automated setup

```bash
git clone https://github.com/MuhammadJaffar52/techmart-platform.git
cd techmart-platform
bash scripts/setup.sh
```

That single command:
1. Checks prerequisites
2. Installs Node.js dependencies
3. Builds the Docker image (multi-stage, non-root, healthcheck)
4. Creates a 3-node KIND cluster (1 control-plane + 2 workers)
5. Loads the Docker image into all nodes
6. Deploys all K8s manifests (Namespace, ConfigMap, Secret, Deployments, Services, Ingress, PVC)
7. Initializes PostgreSQL schema (5 tables) + seed data (8 products)
8. Deploys monitoring stack (Prometheus, Grafana, Loki, Promtail)
9. Verifies API health + pod status

### Manual step-by-step (if you prefer control)

```bash
# 1. Build
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
POD=$(kubectl get pod -n techmart -l app=postgres -o name | head -1)
kubectl exec -n techmart "$POD" -- psql -U postgres -d techmart -c "$(cat app/backend/db/schema.sql)"
kubectl exec -n techmart "$POD" -- psql -U postgres -d techmart -c "$(cat app/backend/db/seed.sql)"

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
```

---

## How to Destroy Everything

### Quick destroy (namespaces only — cluster stays)

```bash
kubectl delete namespace techmart --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found
```

### Full destroy (cluster + all data)

```bash
bash scripts/teardown.sh
```

This deletes both namespaces and the entire KIND cluster. Run `bash scripts/setup.sh` after to rebuild fresh.

---

## Project Architecture

```
techmart-platform/
├── scripts/
│   ├── setup.sh          # One-command rebuild
│   └── teardown.sh       # One-command destroy
├── app/
│   └── backend/          # Node.js Express API
│       ├── index.js      # API server (CRUD + /health + /metrics)
│       ├── Dockerfile    # Multi-stage build
│       ├── .dockerignore
│       ├── package.json
│       └── db/
│           ├── schema.sql
│           └── seed.sql
├── docker/
│   └── docker-compose.yml  # Local dev stack
├── kubernetes/             # K8s manifests (Kustomize)
│   ├── kind-3-node.yaml
│   ├── kustomization.yaml
│   └── techmart-*.yaml
├── helm/techmart/          # Helm chart (8 templates)
├── monitoring/             # Prometheus, Grafana, Loki, Promtail
├── security/               # NetworkPolicy
├── service-mesh/           # Istio VirtualService + DestinationRule
├── chaos-engineering/      # Chaos Mesh PodChaos
├── terraform/              # Docker provider IaC
├── ansible/                # Docker Compose deploy playbook
├── .github/workflows/      # GitHub Actions CI/CD
├── troubleshooting/
│   └── scenarios.md        # 30+ error injection scenarios
├── documentation/
│   └── error-reference.md  # 477-line error guide
└── REFERENCE.md            # Check commands quick reference
```

---

## Key Design Decisions

| Decision | Why |
|---|---|
| **KIND over minikube** | Multi-node, realistic networking, fast startup |
| **Multi-stage Dockerfile** | Smaller images, no build tools in production, non-root user |
| **Kustomize over raw YAML** | DRY, environment overlays possible |
| **Helm chart** | Template reusability, parameterized deployments |
| **Prometheus + Grafana + Loki** | Industry-standard OSS monitoring stack |
| **All config as code** | No manual steps = reproducible infra |
| **Error scenarios in repo** | Lab is self-documenting, no external guides needed |
