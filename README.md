<div align="center">

# TechMart Platform 🛒

**A production-grade DevOps lab running on Kubernetes — fully automated, fully breakable.**

[![KIND](https://img.shields.io/badge/KIND-3%20Node-blue?style=flat&logo=kubernetes)](https://kind.sigs.k8s.io)
[![Node](https://img.shields.io/badge/Node.js-20-green?style=flat&logo=node.js)](https://nodejs.org)
[![Postgres](https://img.shields.io/badge/PostgreSQL-16-blue?style=flat&logo=postgresql)](https://postgresql.org)
[![Docker](https://img.shields.io/badge/Docker-MultiStage-blue?style=flat&logo=docker)](https://docker.com)
[![Helm](https://img.shields.io/badge/Helm-3-blue?style=flat&logo=helm)](https://helm.sh)
[![Prometheus](https://img.shields.io/badge/Prometheus-Grafana-orange?style=flat&logo=prometheus)](https://prometheus.io)
[![License](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

---

**For managers:** Read the 30-second summary below.  
**For developers:** Run `bash scripts/setup.sh` and you're live.  
**For learners:** Break things on purpose — scenarios included.

</div>

---

## 📋 30-Second Executive Summary

| What | Status |
|---|---|
| Full SPA frontend + Node.js API + PostgreSQL (28 products) | ✅ Running on Kubernetes |
| Deployed on a 3-node KIND cluster | ✅ 1 control-plane + 2 workers |
| Full monitoring stack (Prometheus, Grafana, Loki) | ✅ All integrated |
| 30+ intentional error scenarios to practice troubleshooting | ✅ Ready to use |
| Clone → one script → everything running | ✅ `bash scripts/setup.sh` |
| Destroy everything in one command | ✅ `bash scripts/teardown.sh` |

**Why this project exists:** It's a training lab disguised as an e-commerce app. Every component is defined as code. We build it, then break it on purpose, then practice fixing it — exactly like real production incidents.

---

## 🚀 Quick Start (for beginners)

```bash
git clone https://github.com/MuhammadJaffar52/techmart-platform.git
cd techmart-platform
bash scripts/setup.sh
```

That's it (takes ~5 minutes). The script builds all Docker images, creates a 3-node Kubernetes cluster, deploys the full stack (frontend + API + database + monitoring + ingress controller), seeds 28 products, and verifies everything is healthy.

### To access everything:

```bash
# Terminal 1 — Full app (frontend + API through Ingress)
kubectl port-forward --address 0.0.0.0 -n ingress-nginx svc/ingress-nginx-controller 8090:80
# → http://localhost:8090  (products, cart, orders all work)

# Terminal 2 — API (direct)
kubectl port-forward -n techmart svc/techmart-service 3000:3000
# → http://localhost:3000/api/products

# Terminal 3 — Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000
# → http://localhost:3001  (admin/admin)
```

### To destroy everything:

```bash
bash scripts/teardown.sh
```

---

## 🧱 What's Inside

### The App
| Component | What it does | Endpoints |
|---|---|---|
| **techmart-frontend** | Full SPA (Nginx) | 6 pages: Home, Products, Services, Contact, Cart, Orders — 28 products, live API integration |
| **techmart-api** (x2 pods) | Node.js/Express CRUD API | `/health`, `/metrics`, `/api/products`, `/api/users`, `/api/cart`, `/api/orders` |
| **postgres** | PostgreSQL 16 database | 5 tables, 28 seed products |

### The Infrastructure
| Layer | Technology | Purpose |
|---|---|---|
| Container | Docker (multi-stage build, non-root user, healthcheck) | Package the app |
| Cluster | KIND (3 nodes: 1 control-plane + 2 workers) | Local Kubernetes |
| K8s Resources | Namespace, ConfigMap, Secret, Deployment, Service, Ingress, PVC, Kustomize | Run the app |
| Monitoring | Prometheus + Grafana + Loki + Promtail | Metrics + logs + dashboards |
| Packaging | Helm 3 (Chart.yaml + 8 templates) | Parameterized deployments |
| CI/CD | GitHub Actions (lint → build → deploy) | Automated pipeline |
| IaC | Terraform (Docker provider) + Ansible (playbook) | Infrastructure as Code |
| Security | NetworkPolicy, non-root containers, RBAC | Pod security |
| Chaos | Chaos Mesh (PodChaos experiment) | Failure injection |
| Service Mesh | Istio VirtualService + DestinationRule | Canary deployments |

### The Troubleshooting Lab
| Phase | Topic | # Scenarios |
|---|---|---|
| 1 | Docker Fundamentals | 5 |
| 2 | Docker Compose | 5 |
| 3 | Kubernetes Crash & Runtime | 5 |
| 4 | Kubernetes Networking & Probes | 5 |
| 5 | Helm | 5 |
| 6 | Git Troubleshooting | 4 |
| 7 | CI/CD (GitHub Actions) | 4 |
| 8 | Advanced (Terraform, Ansible, Prometheus, Istio) | 6+ |

All scenarios in [`troubleshooting/scenarios.md`](troubleshooting/scenarios.md) with exact commands to inject each error. Reference errors in [`documentation/error-reference.md`](documentation/error-reference.md) (477 lines).

---

## 🎯 Current Status (What's Running)

```
📦 24 pods across 4 namespaces:

techmart/             monitoring/           ingress-nginx       kube-system/
├── techmart-api x2   ├── prometheus        └── controller      ├── coredns x2
├── postgres          ├── grafana                               ├── etcd
├── techmart-frontend ├── loki                                  ├── kube-apiserver
                      ├── promtail                              ├── kube-controller-manager
                                                                ├── kube-scheduler
                                                                ├── kube-proxy x3
                                                                ├── kindnet x3
                                                                └── local-path-provisioner
```

---

## 📁 Project Structure (One Glance)

```
techmart-platform/
├── scripts/              → setup.sh + teardown.sh
├── app/backend/          → Node.js API + Dockerfile + DB schema
├── app/frontend/         → React SPA (index.html) + Nginx Dockerfile
├── kubernetes/           → All K8s manifests (Kustomize)
├── helm/techmart/        → Helm chart (8 templates)
├── monitoring/           → Prometheus, Grafana, Loki, Promtail
├── docker/               → Docker Compose for local dev
├── troubleshooting/      → 30+ error injection scenarios
├── documentation/        → 477-line error reference
├── security/             → NetworkPolicy
├── service-mesh/         → Istio configs
├── chaos-engineering/    → PodChaos experiment
├── terraform/            → Docker provider IaC
├── ansible/              → Docker Compose deploy playbook
├── .github/workflows/    → CI/CD pipeline
└── SETUP.md              → Full setup/teardown documentation
```

Every file is defined as code. No manual steps. Clone and run.

---

## 🔍 How to Check the Infrastructure

```bash
# 1. Docker
docker ps && docker images | grep -E "techmart-(api|frontend)"

# 2. KIND cluster
kind get clusters && kubectl get nodes -o wide

# 3. All pods
kubectl get pods -A --sort-by=.metadata.namespace

# 4. TechMart app
kubectl get all -n techmart && kubectl get endpoints -n techmart

# 5. Monitoring
kubectl get all -n monitoring

# 6. Ingress
kubectl get ingress -n techmart

# 7. API health
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/health',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d))})"

# 8. API products count
kubectl exec -n techmart deploy/techmart-api -- node -e "const h=require('http');h.get('http://localhost:3000/api/products',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(JSON.parse(d).length+' products'))})"

# 9. Frontend HTML
kubectl exec -n techmart deploy/techmart-frontend -- sh -c "cat /usr/share/nginx/html/index.html | head -3"

# 10. Prometheus scraping
kubectl exec -n monitoring deploy/prometheus -- wget -qO- --timeout=3 http://techmart-service.techmart:3000/health
```

---

## 🧹 Clean Up

```bash
# Quick (keep cluster, delete apps)
kubectl delete namespace techmart --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found

# Full (delete cluster + everything)
bash scripts/teardown.sh
```

---

## 🛣️ What's Next (Roadmap)

| Phase | Topic | Status |
|---|---|---|
| 0 | Environment & workstation setup | ✅ Complete |
| 1–4 | Backend API, Docker, K8s deployment, Networking | ✅ Complete |
| 5 | Helm chart | ✅ Complete |
| 6–8 | Git, CI/CD, Monitoring + Advanced (Terraform, Ansible, Security, Chaos, Service Mesh) | ✅ Complete |
| 9 | React frontend with Nginx | ✅ Complete |
| 10 | Redis caching + session store | ⬜ Planned |
| 11 | GitOps (ArgoCD) | ⬜ Planned |
| 12 | AWS migration (EKS, RDS, ElastiCache) | ⬜ Planned |
| 13 | Production incident lab (simulated outages) | ⬜ Planned |

---

## 📚 Learn More

| File | What's in it |
|---|---|
| [`SETUP.md`](SETUP.md) | Full setup/teardown guide with architecture diagram |
| [`REFERENCE.md`](REFERENCE.md) | Quick command reference for checking infra |
| [`troubleshooting/scenarios.md`](troubleshooting/scenarios.md) | 30+ error injection scenarios with fixes |
| [`documentation/error-reference.md`](documentation/error-reference.md) | 477-line error guide for the full stack |
| [`AGENTS.md`](AGENTS.md) | Lab session guide for the troubleshooting curriculum |

---

<div align="center">

**Built component by component. Break it to learn it.**

</div>
