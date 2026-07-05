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

## What's Running (21 Pods, 3 Namespaces)

### techmart namespace — The App
- `techmart-api` x2 — Express API with /health, /metrics, full CRUD
- `postgres` — PostgreSQL with schema + 8 seed products

### monitoring namespace — Visualization
- `grafana` — Dashboard UI (auto-configured Prometheus + Loki datasources)
- `prometheus` — Scrapes techmart-api + K8s node/pod metrics
- `loki` — Log storage
- `promtail` — Collects pod logs → Loki

### kube-system — K8s infrastructure

## Commands to Check Your Infrastructure

### Layer 1 — Docker Host
```bash
docker ps
docker images techmart-api
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
# Grafana dashboard
kubectl port-forward -n monitoring svc/grafana 3001:3000
# → http://localhost:3001  (admin/admin)

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# → http://localhost:9090

# TechMart API
kubectl port-forward -n techmart svc/techmart-service 3000:3000
# → http://localhost:3000/health
# → http://localhost:3000/api/products
# → http://localhost:3000/api/products/1
```

### One-liner — Pod Status Summary
```bash
kubectl get pods -A --sort-by=.metadata.namespace
```
