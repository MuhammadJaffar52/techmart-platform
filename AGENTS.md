# TechMart — DevOps Troubleshooting Lab

> **Purpose:** A hands-on lab for learning how to break, diagnose, and fix real infrastructure issues. The TechMart app is just something to break — the real product is the troubleshooting skills you build.

---

## 1. What We Have (Infrastructure)

| Component | Status | Details |
|---|---|---|
| **Backend API** | ✅ Deployed on KIND | Node.js/Express on port 3000 — CRUD for products, users, cart, orders. Health at `/health` |
| **PostgreSQL** | ✅ Deployed on KIND | 5 tables (`products`, `users`, `cart_items`, `orders`, `order_items`) + 8 seed products |
| **Dockerfile** | ✅ Multi-stage | `app/backend/Dockerfile` — node:20-alpine, non-root user, healthcheck, .dockerignore |
| **Docker Compose** | ✅ Built | `docker/docker-compose.yml` — backend + postgres with health checks, named volumes |
| **KIND cluster** | ✅ Running | `techmart` — 1 control-plane + 2 workers |
| **K8s manifests** | ✅ Deployed | `kubernetes/` — Namespace, ConfigMap, Secret, Deployment (x2), Service (x2), Ingress, PVC, Kustomize |
| **Helm chart** | ✅ Built | `helm/techmart/` — Chart.yaml, values.yaml, 8 templates, ready to install |
| **CI/CD** | ✅ Built | `.github/workflows/deploy.yml` — lint → build → deploy to KIND |
| **Terraform** | ✅ Built | `terraform/main.tf` — Docker provider for local infra |
| **Ansible** | ✅ Built | `ansible/playbook.yml` — deploy with Docker Compose via SSH |
| **Monitoring** | ✅ Built | `monitoring/prometheus.yml` + `monitoring/dashboard.json` |
| **Security** | ✅ Built | `security/network-policy.yaml` |
| **Chaos Eng.** | ✅ Built | `chaos-engineering/experiment.yaml` — PodChaos experiment |
| **Service Mesh** | ✅ Built | `service-mesh/virtual-service.yaml` — Istio VirtualService + DestinationRule |
| **Error reference** | ✅ Committed | `documentation/error-reference.md` — 477 lines covering the full stack |
| **Troubleshooting** | ✅ Built | `troubleshooting/scenarios.md` — 30+ error injection scenarios across all 8 phases |

### Git State
```
123f034 — docs: add full DevOps error reference guide
4319b42 — feat: backend API, DB schema, seed data, KIND cluster config
2bf6cde — Initialize TechMart project structure

Modified:  AGENTS.md, documentation/error-reference.md
Untracked: app/backend/Dockerfile
```

---

## 2. How This Lab Works

1. **Pick a phase** from the curriculum below — each builds on the previous
2. **I introduce an error** — misconfigured image, bad YAML, wrong port, missing secret
3. **You diagnose it** using the tools and commands in the error reference
4. **You fix it** — then we move to the next harder scenario

The app is the victim. Troubleshooting is the skill.

---

## 3. Troubleshooting Curriculum

### Phase 1 — Docker Fundamentals
**Goal:** Break and fix Docker builds and container runs.

| # | Scenario | What You'll Learn |
|---|---|---|
| 1 | `COPY failed` — wrong build context | Build context, `.dockerignore` |
| 2 | Container exits immediately on start | ENTRYPOINT/CMD, foreground processes |
| 3 | `exec format error` — arch mismatch | Multi-arch builds, `--platform` |
| 4 | `toomanyrequests` — pull rate limit | Registry auth, image pull policies |
| 5 | App can't connect to Postgres | Container networking, `--link`, `--network` |

**Tools:** `docker build`, `docker run`, `docker logs`, `docker inspect`, `docker ps`

### Phase 2 — Docker Compose
**Goal:** Multi-service orchestration failures.

| # | Scenario | What You'll Learn |
|---|---|---|
| 1 | Service never starts — health check missing | `depends_on`, healthcheck |
| 2 | Env vars not substituting | `.env` file, variable precedence |
| 3 | Backend can't reach Postgres by name | Compose network DNS, service names |
| 4 | Port conflict — "port is already allocated" | Host port mapping, port ranges |
| 5 | Volume data disappears on restart | Named vs anonymous volumes |

**Tools:** `docker compose up`, `docker compose logs`, `docker compose ps`, `docker compose down -v`

### Phase 3 — Kubernetes Crash & Runtime
**Goal:** Deploy the app to KIND and break it.

| # | Scenario | What You'll Learn |
|---|---|---|
| 1 | `CrashLoopBackOff` — wrong command in Deployment | Pod spec, `command` vs `args` |
| 2 | `ImagePullBackOff` — bad image tag | Image naming, pull policies |
| 3 | `CreateContainerConfigError` — missing ConfigMap | ConfigMaps, envFrom, volume mounts |
| 4 | `OOMKilled` — no memory limits set | Resource requests/limits, `kubectl top` |
| 5 | Pod stuck `Pending` — insufficient CPU | Resource quotas, node resources |

**Tools:** `kubectl describe pod`, `kubectl logs --previous`, `kubectl get events`, `kubectl top`

### Phase 4 — Kubernetes Networking & Probes
**Goal:** Make the app reachable — or not.

| # | Scenario | What You'll Learn |
|---|---|---|
| 1 | Service has no endpoints — label mismatch | Selectors, labels, endpoints |
| 2 | Readiness probe failing — wrong path | Probe types, paths, periods |
| 3 | Liveness probe killing the pod — too strict | Failure threshold, startup probe |
| 4 | `connection refused` — wrong containerPort | Port spec, Service port vs targetPort |
| 5 | `0/N nodes are available` — taints/tolerations | Node taints, tolerations, nodeSelector |

**Tools:** `kubectl get endpoints`, `kubectl describe svc`, `kubectl port-forward`, `kubectl exec`

### Phase 5 — Helm
**Goal:** Template and release failures.

| # | Scenario | What You'll Learn |
|---|---|---|
| 1 | `nil pointer evaluating` — missing values key | Values hierarchy, defaults |
| 2 | YAML parse error — bad indentation | Template syntax, `helm template --debug` |
| 3 | `UPGRADE FAILED: has no deployed releases` | Release state, rollback, `--history-max` |
| 4 | Rollback fails — CRD incompatibility | Resource versioning, CRD lifecycle |
| 5 | `timed out waiting for the condition` | `--wait`, readiness, hooks |

**Tools:** `helm install`, `helm upgrade`, `helm rollback`, `helm template --debug`, `helm history`

### Phase 6 — Git Troubleshooting
**Goal:** Recover from common Git messes.

| # | Scenario | What You'll Learn |
|---|---|---|
| 1 | Detached HEAD — lost commits | `git reflog`, `git cherry-pick`, `git branch` |
| 2 | Merge conflict — can't rebase | Conflict resolution, `git mergetool` |
| 3 | Force-push recovery — overwritten branch | `git reflog`, `git reset`, `git push --force-with-lease` |
| 4 | `refusing to merge unrelated histories` | `--allow-unrelated-histories`, repo init |
| 5 | Large file blocked by remote | Git LFS, `git filter-branch`, `BFG` |

**Tools:** `git reflog`, `git log --graph`, `git fsck`, `git rebase`, `git merge`

### Phase 7 — CI/CD (GitHub Actions)
**Goal:** Pipeline debugging.

| # | Scenario | What You'll Learn |
|---|---|---|
| 1 | Docker build fails in CI but works locally | Build context, runner env differences |
| 2 | Secret not found — wrong scope | Secrets, environments, repo vs org |
| 3 | Job stuck "queued" — no runners | Runner labels, self-hosted runners |
| 4 | Artifact not found in next job | `actions/upload-artifact`, paths, retention |
| 5 | `exit code 137` — OOM in runner | Resource limits, `ACTIONS_STEP_DEBUG` |

**Tools:** `act` (local run), `ACTIONS_STEP_DEBUG=true`, runner logs

### Phase 8 — Advanced (As Needed)
| Topic | Scenarios |
|---|---|
| **Terraform** | State lock, cycle, drift, provider version mismatch, `terraform import` |
| **Ansible** | SSH unreachable, become failures, idempotency, vault decryption |
| **Prometheus/Grafana** | Target DOWN, high cardinality, Alertmanager not firing, "No data" |
| **Istio** | Sidecar not injected, mTLS handshake, 503 NR/UH, Envoy CrashLoopBackOff |
| **Jenkins** | Agent offline, credentials not found, plugin compatibility, sandbox restrictions |
| **AWS** | AccessDenied, ECS task stuck PENDING, S3 403, Lambda timeout |

---

## 4. Progress Tracking

| Phase | Topic | Status |
|---|---|---|
| 1 | Docker Fundamentals | ✅ Infra built, scenarios ready |
| 2 | Docker Compose | ✅ Infra built, scenarios ready |
| 3 | K8s Crash & Runtime | ✅ Infra built + deployed, scenarios ready |
| 4 | K8s Networking & Probes | ✅ Infra built + deployed, scenarios ready |
| 5 | Helm | ✅ Infra built, scenarios ready |
| 6 | Git Troubleshooting | ✅ Repo history + branches ready, scenarios ready |
| 7 | CI/CD (GitHub Actions) | ✅ Pipeline built, scenarios ready |
| 8 | Advanced (Terraform/Ansible/Prometheus/Istio/Jenkins/AWS) | ✅ Scaffolding built, scenarios ready |

---

## 5. Troubleshooting Scenarios (Ready to Run)

### Docker
- `ImagePullBackOff` — wrong image tag
- Container exits immediately — bad CMD/ENTRYPOINT
- `CrashLoopBackOff` in K8s — app crashes on startup
- Port conflicts — two containers fighting for same host port
- `COPY failed` — wrong build context path

### Kubernetes
- Pod stuck `Pending` — insufficient resources / taints
- `CreateContainerConfigError` — missing ConfigMap or Secret
- Readiness probe failing — app not responding on correct path
- `CrashLoopBackOff` — missing env vars or DB connection
- `0/N nodes are available` — scheduling constraints
- Service has no endpoints — label selector mismatch

### Docker Compose
- Service depends_on but never starts — health check missing
- Env vars not substituting — missing `.env` file
- Network isolation — frontend can't reach backend

### Helm
- `nil pointer evaluating` — missing values key
- YAML parse error — bad indentation in template
- `UPGRADE FAILED: has no deployed releases` — stuck release

### CI/CD (GitHub Actions)
- Pipeline fails with exit code 1 — find the failing step
- Secret not found — wrong scope
- Docker build fails in CI but works locally — context issue

### AWS (when configured)
- `AccessDenied` — IAM policy debugging
- ECS task stuck `PENDING` — capacity or image pull
- S3 `403 Forbidden` — bucket policy investigation

### Git
- Detached HEAD — how to recover
- Merge conflict — resolve and continue
- Force-push recovery — `git reflog` rescue

---

## 6. Diagnostic Mindset

```
1. What's the exact error?      → Read it literally, don't guess
2. What layer is it in?         → App → Container → Node → Network → Cloud
3. What changed since it worked? → Git diff, config diff, deployment history
4. What logs exist?             → Check before restarting anything
5. Can I reproduce it?          → Same inputs = same outputs
6. Is it a rate limit/quota?    → AWS throttling, Docker Hub pulls, K8s API limits
7. Is it version skew?          → Provider versions, Helm/K8s compat, plugin versions
```

---

## 7. Error Reference Guide

Full reference in `documentation/error-reference.md` (477 lines). Quick index:

| Section | Covered |
|---|---|
| Kubernetes | Image/Container, Crash/Runtime, Scheduling, Networking, Probes, Cluster-Level |
| Docker | Daemon, Build, Runtime, Volumes, Networking, Compose |
| Helm | Install/Upgrade/Rollback, Templating, Dependencies |
| Terraform | State, Provider, Cycle, Drift, Import |
| CI/CD | Runner, Cache, Secrets, Dind, Artifacts, Rate Limits |
| AWS | IAM, ELB, ECS, S3, RDS, Lambda, CloudFormation |
| Git | Merge, Auth, Detached HEAD, Reflog Recovery |
| Istio | mTLS, Traffic Split, Sidecar, Authz, Gateway |
| Jenkins | Pipeline, Agent, Credentials, Plugins, Sandbox |
| Ansible | SSH, Become, Idempotency, YAML, Vault |
| Prometheus/Grafana | Scrape, Cardinality, Alertmanager, Query Performance |

---

## 8. General Debugging Principles

1. **Read the actual error, not just the status.** Verbose/debug flags exist everywhere (`-vvv`, `--debug`, `TF_LOG=DEBUG`) — use them before guessing.
2. **Check the layer below.** App → container → node → network → cloud provider. Most "mystery" failures are one layer down from the visible symptom.
3. **Diff against known-good state.** Terraform drift, Git conflicts, and Ansible idempotency issues are all "what changed since it last worked."
4. **Rate limits and quotas masquerade as random failures.** AWS throttling, Docker Hub pull limits, CI runner exhaustion often look like flaky bugs.
5. **Logs first, restart second.** Restarting before capturing logs destroys your evidence (`--previous` for crashed pods, `docker logs` before `docker rm`).
6. **Version skew is a frequent silent cause.** Terraform providers, Helm charts, Jenkins plugins, and Istio/K8s version mismatches all produce confusing errors that look unrelated to versioning.

---

*Error messages, exit codes, and diagnostics evolve with tool versions — treat the reference as a map for pattern-matching, and cross-check exact wording against current docs for whatever version you're running.*
