# TechMart — Error Injection & Troubleshooting Scenarios

> For each scenario: I break it → you diagnose → you fix it.
> Full reference in `documentation/error-reference.md`

---

## Phase 1 — Docker Fundamentals

### Scenario 1: `COPY failed` — wrong build context
**Inject:** Build the Dockerfile from the project root instead of `./app/backend`
```bash
# This will fail — COPY references package*.json relative to context root
docker build -t techmart-api:broken -f app/backend/Dockerfile .
```
**Symptom:** `COPY failed: file not found in build context`
**Fix:** Build from the correct context: `docker build -t techmart-api ./app/backend`

### Scenario 2: Container exits immediately
**Inject:** Change CMD to a short-lived process
```bash
# Edit Dockerfile, replace:
#   CMD ["node", "index.js"]
# with:
#   CMD ["echo", "hello"]
docker build -t techmart-api:exit ./app/backend && docker run techmart-api:exit
```
**Symptom:** Container runs for 0.2 seconds and exits
**Fix:** `CMD` must run a foreground process — restore `["node", "index.js"]`

### Scenario 3: `exec format error` — arch mismatch
**Inject:** Force wrong platform
```bash
docker build --platform=linux/arm64 -t techmart-api:arm ./app/backend
docker run --platform=linux/arm64 techmart-api:arm
```
**Symptom:** `exec /usr/local/bin/node: exec format error`
**Fix:** Match platform to host arch, or use multi-arch images

### Scenario 4: `toomanyrequests` — pull rate limit
**Inject:** Make many sequential pulls
```bash
for i in $(seq 1 200); do docker pull alpine:latest & done; wait
```
**Symptom:** `toomanyrequests: You have reached your pull rate limit`
**Fix:** Add Docker Hub auth, use a mirror, or increase rate limit

### Scenario 5: App can't connect to Postgres
**Inject:** Start backend container without linking to Postgres
```bash
docker run -d --name techmart-api-broken -p 3000:3000 techmart-api:latest
```
**Symptom:** `connect ECONNREFUSED 127.0.0.1:5432`
**Fix:** Use `--network` or Docker Compose to connect containers

---

## Phase 2 — Docker Compose

### Scenario 1: Service never starts — health check missing
**Inject:** Remove `depends_on.condition: service_healthy`
```yaml
# In docker-compose.yml, change:
#   depends_on:
#     postgres:
#       condition: service_healthy
# to:
#   depends_on:
#     - postgres
```
**Symptom:** Backend starts before Postgres is ready → crashes → Compose restart loop
**Fix:** Add `condition: service_healthy` back

### Scenario 2: Env vars not substituting
**Inject:** Remove the `.env` file or misspell a variable name
**Symptom:** Backend connects to wrong DB or defaults
**Fix:** Verify `.env` file exists and matches `docker-compose.yml` references

### Scenario 3: Backend can't reach Postgres by name
**Inject:** Change the Compose service name for Postgres but not the env var
```yaml
# Change postgres -> pg in services, but DB_HOST still says postgres
```
**Symptom:** `getaddrinfo ENOTFOUND postgres`
**Fix:** Keep service names and DB_HOST consistent

### Scenario 4: Port conflict
**Inject:** Run another container on port 3000 first
```bash
docker run -d --name port-stealer -p 3000:80 nginx:alpine
docker compose up  # fails
```
**Symptom:** `port is already allocated`
**Fix:** Stop the conflicting container or change the host port

### Scenario 5: Volume data disappears
**Inject:** Use anonymous volume instead of named
```yaml
# Change:
#   volumes:
#     postgres_data:/var/lib/postgresql/data
# to:
#   volumes:
#     /var/lib/postgresql/data
```
**Symptom:** Data lost on `docker compose down`
**Fix:** Use named volumes for persistent data

---

## Phase 3 — Kubernetes Crash & Runtime

### Scenario 1: `CrashLoopBackOff` — wrong command
**Inject:** Add a bad command to the deployment
```yaml
# In techmart-deployment.yaml, add under containers:
command: ["node", "nonexistent.js"]
kubectl apply -f kubernetes/techmart-deployment.yaml
```
**Symptom:** `CrashLoopBackOff` — pod restarts repeatedly
**Fix:** `kubectl logs --previous pod-name` to see `Error: Cannot find module`
**Restore:** Remove the `command` override

### Scenario 2: `ImagePullBackOff` — bad image tag
**Inject:** Change image tag to non-existent
```yaml
# Change image: techmart-api:latest -> techmart-api:nonexistent
kubectl apply -f kubernetes/techmart-deployment.yaml
```
**Symptom:** `ImagePullBackOff` — pod can't pull image
**Fix:** `kubectl describe pod` shows `manifest unknown`
**Restore:** Change back to `techmart-api:latest`

### Scenario 3: `CreateContainerConfigError` — missing ConfigMap
**Inject:** Delete the ConfigMap
```bash
kubectl delete configmap techmart-config -n techmart
kubectl rollout restart -n techmart deploy/techmart-api
```
**Symptom:** `CreateContainerConfigError` — env var source not found
**Fix:** `kubectl describe pod` shows missing ConfigMap key
**Restore:** Re-apply `kubernetes/techmart-config.yaml`

### Scenario 4: `OOMKilled` — no memory limits
**Inject:** Set extremely low memory limit
```yaml
# In techmart-deployment.yaml:
# resources:
#   limits:
#     memory: "32Mi"  # too low for Node.js
kubectl apply -f kubernetes/techmart-deployment.yaml
```
**Symptom:** `OOMKilled` (exit code 137)
**Fix:** `kubectl top pod -n techmart` shows memory usage
**Restore:** Change back to `256Mi`

### Scenario 5: Pod stuck `Pending` — insufficient CPU
**Inject:** Request more CPU than any node has
```yaml
# In techmart-deployment.yaml:
# resources:
#   requests:
#     cpu: "100"  # 100 cores
kubectl apply -f kubernetes/techmart-deployment.yaml
```
**Symptom:** Pod stays `Pending` — `0/3 nodes available: insufficient cpu`
**Fix:** `kubectl describe pod` shows scheduling failure
**Restore:** Change back to `100m`

---

## Phase 4 — Kubernetes Networking & Probes

### Scenario 1: Service has no endpoints — label mismatch
**Inject:** Change deployment labels but not service selector
```yaml
# In techmart-deployment.yaml, change:
#   matchLabels:
#     app: techmart-api
# to:
#   matchLabels:
#     app: techmart-v2
kubectl apply -f kubernetes/techmart-deployment.yaml
```
**Symptom:** `kubectl get endpoints -n techmart` shows no endpoints
**Fix:** Match deployment `matchLabels` to service `selector`

### Scenario 2: Readiness probe failing — wrong path
**Inject:** Change readiness probe path to `/not-healthy`
```yaml
# Add under containers in deployment:
readinessProbe:
  httpGet:
    path: /not-healthy
    port: 3000
```
**Symptom:** Pod never shows `Ready` (0/1)
**Fix:** `kubectl describe pod` shows probe failing with 404

### Scenario 3: Liveness probe killing the pod — too strict
**Inject:** Set ultra-short failure threshold
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 2
  periodSeconds: 1
  failureThreshold: 1
```
**Symptom:** Pod restarts in a loop (even if app is healthy)
**Fix:** Increase `initialDelaySeconds` and `failureThreshold`

### Scenario 4: `connection refused` — wrong containerPort
**Inject:** Change containerPort to a wrong value
```yaml
ports:
  - containerPort: 8080  # app listens on 3000
```
**Symptom:** `kubectl port-forward` fails, service returns connection refused
**Fix:** Match `containerPort` to app's actual listen port

### Scenario 5: `0/N nodes are available` — taints/tolerations
**Inject:** Taint all worker nodes
```bash
kubectl taint nodes techmart-worker dedicated=production:NoSchedule
kubectl taint nodes techmart-worker2 dedicated=production:NoSchedule
```
**Symptom:** Pod stays `Pending` — `0/3 nodes available: untolerated taint`
**Fix:** Remove taint or add toleration to deployment

---

## Phase 5 — Helm

### Scenario 1: `nil pointer evaluating` — missing values key
**Inject:** Delete a key from `values.yaml` that a template references
**Symptom:** `helm template` fails with `nil pointer evaluating`
**Fix:** Add the missing key back or add default with `default` function

### Scenario 2: YAML parse error — bad indentation
**Inject:** Break template indentation
```yaml
# In a template, change indentation of a field
```
**Symptom:** `helm install` fails with YAML parse error
**Fix:** `helm template --debug` shows the rendered YAML with the error

### Scenario 3: `UPGRADE FAILED: has no deployed releases`
**Inject:** Delete Helm release secret
```bash
kubectl delete secret -n techmart sh.helm.release.v1.techmart.v1
helm upgrade techmart helm/techmart/
```
**Symptom:** `UPGRADE FAILED: has no deployed releases`
**Fix:** `helm history --max 5` shows nothing; re-install

### Scenario 4: Rollback fails — CRD incompatibility
**Inject:** Install a new version that changes a CRD schema, then rollback
**Symptom:** Rollback fails with CRD version error
**Fix:** Manually manage CRD versions, or use `helm rollback --force`

### Scenario 5: `timed out waiting for the condition`
**Inject:** Set deployment to use a non-existent image
```yaml
# In values.yaml:
image:
  repository: techmart-api
  tag: nonexistent
helm upgrade --install --wait techmart helm/techmart/
```
**Symptom:** `timed out waiting for the condition` after --wait timeout
**Fix:** Check pod status with `kubectl describe pod`

---

## Phase 6 — Git Troubleshooting

### Scenario 1: Detached HEAD
**Inject:** Checkout a commit hash instead of a branch
```bash
git checkout 2bf6cde
# make a commit here
```
**Symptom:** Commits exist but no branch points to them
**Fix:** `git reflog` → `git checkout -b rescue-branch`

### Scenario 2: Merge conflict
**Inject:** Create conflicting changes
```bash
git checkout -b feat/conflict
# edit README.md line 1
git commit -am "feat: change header"
git checkout main
# edit same line differently
git merge feat/conflict
```
**Symptom:** `CONFLICT (content): Merge conflict in README.md`
**Fix:** Edit conflicted file, `git add`, `git commit`

### Scenario 3: Force-push recovery
```bash
git reset --hard HEAD~2
git push --force
```
**Symptom:** Lost commits on remote
**Fix:** `git reflog` → `git reset --hard <sha>` → `git push --force-with-lease`

### Scenario 4: Unrelated histories
**Inject:** Init a new repo and try to merge
```bash
git init --bare other-repo
git remote add other ../other-repo
git fetch other
git merge other/main  # --allow-unrelated-histories needed
```
**Fix:** `git merge --allow-unrelated-histories`

---

## Phase 7 — CI/CD (GitHub Actions)

### Scenario 1: Docker build fails in CI
**Inject:** Add a step that requires a secret not in the environment
**Symptom:** CI fails with authentication error
**Fix:** Check `env` context, add missing secret to GitHub repo

### Scenario 2: Secret not found
**Inject:** Reference a secret that doesn't exist in the workflow
```yaml
- name: Login
  run: echo ${{ secrets.NONEXISTENT }}
```
**Symptom:** Empty string or error
**Fix:** Create the secret in GitHub repo settings

### Scenario 3: Job stuck "queued"
**Inject:** Use `runs-on: self-hosted` without any self-hosted runner registered
**Symptom:** Job stays queued indefinitely
**Fix:** Register a self-hosted runner or change label to `ubuntu-latest`

### Scenario 4: Artifact not found
**Inject:** Change artifact name between upload and download
```yaml
# Upload as "docker-image", download as "docker-img"
```
**Symptom:** `Artifact not found` error
**Fix:** Keep names consistent

---

## Phase 8 — Advanced

### Terraform
- **State lock:** Run two `terraform apply` in parallel → lock error
- **Cycle:** Create circular resource dependency
- **Drift:** Manually change a resource, `terraform plan` shows diff

### Ansible
- **SSH unreachable:** Wrong host or SSH key in inventory
- **Become failure:** Missing sudo privileges
- **Vault decrypt:** Wrong vault password

### Prometheus/Grafana
- **Target DOWN:** Scrape target unreachable
- **No data:** Wrong metric name in dashboard
- **Alertmanager not firing:** Route/label mismatch

### Istio
- **Sidecar not injected:** Missing label `sidecar.istio.io/inject: "true"`
- **mTLS handshake:** Cert expired or wrong root CA
- **503 NR/UH:** Upstream cluster has no healthy endpoints
