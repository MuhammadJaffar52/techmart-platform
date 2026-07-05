# TechMart Platform — DevOps Learning Blueprint

> **Purpose:** Single source of truth for the entire project. Any new chat reads this file to know exactly where we are and what to do next.

---

## 1. Project Overview

TechMart is a **e-commerce platform** used as a learning vehicle for production-grade DevOps. We start with a simple Node.js/PostgreSQL app and evolve it through 15 phases — from local development all the way to AWS production with GitOps, monitoring, service mesh, chaos engineering, and incident response.

**Stack:** Node.js (Express) + PostgreSQL + React (later) + Redis (later)  
**Goal:** Build, containerize, orchestrate, deploy, observe, secure, and operate like a real team.

---

## 2. What We Have Done (Session 1)

| Item | File | Status |
|---|---|---|
| Skeleton repo created | `2bf6cde` | ✅ Committed |
| Backend API (Express) | `app/backend/index.js` | ✅ Built, not committed |
| DB schema (5 tables) | `app/backend/db/schema.sql` | ✅ Built, not committed |
| Seed data (8 products) | `app/backend/db/seed.sql` | ✅ Built, not committed |
| package.json (express + pg) | `app/backend/package.json` | ✅ Built, not committed |
| 3-node KIND cluster config | `kubernetes/kind-3-node.yaml` | ✅ Built, not committed |
| AGENTS.md (this file) | `AGENTS.md` | ✅ Updated |
| README.md (checklist) | `README.md` | ✅ Modified |

**NOT committed yet** — all app/ and kubernetes/ files are untracked.

---

## 3. Complete Roadmap (15 Phases)

```
Phase 0: Foundation & Environment Setup ........ ~80% done
Phase 1: Build TechMart Application ............ ~20% done (backend only)
Phase 2: Docker Mastery ........................   0% done
Phase 3: Docker Compose ........................   0% done
Phase 4: Kubernetes Fundamentals ...............   0% done
Phase 5: Helm ..................................   0% done
Phase 6: CI/CD (GitHub Actions) ...............   0% done
Phase 7: GitOps (ArgoCD) ......................   0% done
Phase 8: Observability (Prometheus/Grafana) ...   0% done
Phase 9: Security ..............................   0% done
Phase 10: Service Mesh (Istio) ................   0% done
Phase 11: Production Engineering ..............   0% done
Phase 12: Chaos Engineering ...................   0% done
Phase 13: AWS Migration ........................   0% done
Phase 14: Terraform ............................   0% done
Phase 15: Production Incident Lab .............   0% done
```

---

## 4. Detailed Phase Breakdown

### Phase 0 — Foundation (~80% complete)

**Done:**
- Ubuntu setup, VS Code, Git, Docker Engine, Docker Compose, KIND, kubectl, Helm, Node.js, npm, PostgreSQL client, Redis CLI, curl, jq, yq, Make, Terraform, AWS CLI, GitHub CLI
- Docker verification (daemon, CLI, compose, buildx, hello-world)
- KIND single-node cluster created, API server & system pods verified
- Git repo initialized, README created

**Remaining:**
- [ ] Create 3-node KIND cluster (config already written)
- [ ] Delete single-node cluster
- [ ] Verify node communication
- [ ] Documentation structure (`documentation/` folder)
- [ ] Git branching strategy document
- [ ] Advanced logging / systemd / production troubleshooting (Linux)
- [ ] Feature branches, PRs, merge strategies, tags, releases (Git)

---

### Phase 1 — TechMart Application (~20% done)

**Done:**
- [x] Backend Express API (CRUD for products, users, cart, orders)
- [x] PostgreSQL schema + seed data

**To do (with DevOps context):**
- [ ] Redis integration (caching, session store) — learn container networking
- [ ] React frontend (Docker multi-stage build later)
- [ ] Environment-based config (12-factor app)
- [ ] Structured logging (winston/pino)
- [ ] Health check endpoints (already done — `/health`)
- [ ] Graceful shutdown handling

**DevOps lessons embedded:**
- Frontend will teach us Nginx + static file serving
- Redis will teach us caching patterns + container linking
- Config management will teach us env vars vs config files vs secrets

---

### Phase 2 — Docker Mastery

**Learning path (tell me what to do, I do it):**

1. Write `Dockerfile` for backend
   - Understand layers, caching, `COPY` vs `ADD`
   - Multi-stage builds (dev vs prod)
   - Image size optimization (`docker-slim`, Alpine)
2. Write `Dockerfile` for frontend (React)
   - Multi-stage: build with Node, serve with Nginx
3. Container security
   - Non-root user, read-only rootfs, no shell in prod
4. Docker networking
   - Bridge, host, overlay, macvlan
5. Docker volumes & bind mounts
   - Named volumes for Postgres data persistence
   - Bind mounts for hot-reload in dev
6. Docker troubleshooting lab
   - Inspect, logs, exec, stats, events
   - Common failure scenarios

**Files to create:** `docker/Dockerfile.backend`, `docker/Dockerfile.frontend`, `docker/.dockerignore`

---

### Phase 3 — Docker Compose

**Learning path:**

1. Write `docker-compose.yml` for full stack
   - `backend`, `frontend`, `postgres`, `redis`
2. Service dependencies & health checks
3. Environment variables (`.env` file)
4. Networks (frontend vs backend tier isolation)
5. Volumes (Postgres data persistence)
6. `depends_on` with health checks
7. Scaling (multiple backend replicas)
8. Compose profiles (dev vs prod)
9. Troubleshooting compose networks

**Files to create:** `docker/docker-compose.yml`, `docker/docker-compose.override.yml`, `docker/.env`

---

### Phase 4 — Kubernetes Fundamentals

**Prerequisite:** 3-node KIND cluster running.

**Learning path (each concept = create a real YAML for TechMart):**

1. **Pods** — Run backend as a Pod (not Deployment yet)
2. **ConfigMaps & Secrets** — DB config, API keys
3. **Deployments** — Replace Pod with Deployment (rolling updates)
4. **Services** — ClusterIP, NodePort, LoadBalancer
5. **Persistent Volumes & PVCs** — Postgres data
6. **StatefulSets** — Postgres with stable identity
7. **Ingress** — Route `/api/*` to backend, `/` to frontend
8. **Probes** — Liveness, readiness, startup for backend
9. **Resource limits & requests** — CPU/memory
10. **HPA** — Auto-scale backend based on CPU
11. **RBAC** — Service accounts for app pods
12. **Network Policies** — Restrict pod-to-pod traffic

**Files to create:** `kubernetes/base/`, `kubernetes/overlays/` (kustomize)

---

### Phase 5 — Helm

- Create a Helm chart for TechMart
- Values file for dev/staging/prod
- Template functions, named templates, dependencies
- Package and deploy with Helm

**Files to create:** `helm/techmart/`

---

### Phase 6 — CI/CD (GitHub Actions)

- Pipeline: lint → test → build → push → deploy
- Docker image build & push to Docker Hub / GHCR
- Deploy to KIND cluster in CI
- Branch-based environments (dev, staging, prod)
- Security scanning (Trivy)

**Files to create:** `.github/workflows/`

---

### Phase 7 — GitOps (ArgoCD)

- Install ArgoCD on KIND cluster
- Define TechMart app in a Git repo
- Sync policies, auto-heal, self-heal
- Rollback strategies

**Files to create:** `gitops/`

---

### Phase 8 — Observability

- Prometheus metrics from Express app (`prom-client`)
- Grafana dashboards
- Loki for log aggregation
- Tempo for tracing (OpenTelemetry)
- Alerting rules

**Files to create:** `monitoring/`

---

### Phase 9 → 15

Details TBD as we approach each phase. General progression:
- **Security** — Trivy, OPA/Gatekeeper, Falco
- **Service Mesh** — Istio, mTLS, traffic splitting
- **Production Engineering** — Backup, DR, capacity planning
- **Chaos Engineering** — Chaos Mesh, Litmus
- **AWS** — EKS, RDS, ElastiCache
- **Terraform** — IaC for all AWS resources
- **Incident Lab** — Simulated outages, on-call rotation

---

## 5. Recommended Order of Execution

```
Step 1:  Commit current work (app, kubernetes config)
Step 2:  Phase 0 — Create 3-node KIND cluster
Step 3:  Phase 1 — Finish the app (Redis, frontend later)
Step 4:  Phase 2 — Docker (Dockerfile for backend)
Step 5:  Phase 3 — Docker Compose (full stack)
Step 6:  Phase 4 — Kubernetes (deploy to KIND)
Step 7:  Phase 5 — Helm
Step 8:  Phase 6 — CI/CD
Step 9:  Phase 7 — GitOps
Step 10: Phase 8 — Observability
...and so on
```

---

## 6. Session Context (for new chats)

**Last session:** Built the backend API (`app/backend/index.js`), DB schema, and seed data. Created 3-node KIND config. Nothing is committed yet.

**Next action:** User and agent will discuss whether to commit first, finish Phase 0 (3-node cluster), or jump into Docker.

**Communication style:** Agent guides but does NOT execute. Tells user what file to create, what to write, why it matters. User does the work. This is a learn-by-doing DevOps lab.

---

## 7. Branching Strategy (proposed)

```
main         — Production-ready, protected
├── dev      — Integration branch
├── feat/*   — Feature branches
└── fix/*    — Bugfix branches
```

PR → dev → main flow. Tags for releases (`v1.0.0`, `v2.0.0`).
