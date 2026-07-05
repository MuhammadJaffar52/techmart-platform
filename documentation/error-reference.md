# DevOps Error Reference Guide (Extended)
### Kubernetes · Docker · Helm · Terraform · CI/CD · AWS · Git · Istio · Jenkins · Ansible · Prometheus/Grafana

A deep field reference for errors, root causes, and diagnostics across the stack.

---

## 1. Kubernetes

### Image / Container Startup
| Error | Common Cause |
|---|---|
| `ImagePullBackOff` | Retrying failed pull — wrong tag, private registry auth missing |
| `ErrImagePull` | Bad image name, registry unreachable, image doesn't exist |
| `ErrImageNeverPull` | `imagePullPolicy: Never` but image not on node |
| `InvalidImageName` | Malformed image reference |
| `CreateContainerConfigError` | Missing ConfigMap/Secret key referenced by container |
| `CreateContainerError` | Bad volume mount, invalid runtime config |
| `ImageInspectError` | Corrupted local image cache on node |
| `RegistryUnavailable` | DNS/network issue reaching registry |
| `ErrImagePullBackOff` with 401/403 | imagePullSecret missing or expired token |
| `manifest unknown` | Tag doesn't exist in registry (typo or not pushed) |

### Crash / Runtime
| Error | Common Cause |
|---|---|
| `CrashLoopBackOff` | App crash, bad entrypoint, missing dependency, failing probe |
| `OOMKilled` (exit 137) | Container exceeded memory limit |
| `Error` (exit 1) | App-level unhandled exception |
| `ContainerCannotRun` | Bad command path, permission denied |
| `DeadlineExceeded` | Job exceeded `activeDeadlineSeconds` |
| `RunContainerError` | Runtime failed during container creation (cgroup, seccomp) |
| `StartError` | Container start hook failed |
| `Non-zero exit code (127)` | Command/binary not found in image |
| `Non-zero exit code (126)` | Command found but not executable |
| `Init:Error` / `Init:CrashLoopBackOff` | Init container failing before main container starts |
| `Init:0/1` stuck | Init container hanging, often waiting on a dependency that's not ready |

### Scheduling
| Error | Common Cause |
|---|---|
| `Pending` (stuck) | Check `describe pod` events |
| `Insufficient cpu` / `Insufficient memory` | No node has enough free resources |
| `FailedScheduling` | Taint/toleration, nodeSelector, affinity mismatch |
| `Unschedulable` | Node cordoned, or no matching toleration |
| `TooManyPods` | Node at pod capacity limit |
| `node(s) had volume node affinity conflict` | PV zone doesn't match pod's scheduled zone |
| `0/N nodes are available` | Combination of taints/resources/affinity all failing at once |
| `PodToleratesNodeTaints` failure | Missing toleration for a control-plane or custom taint |
| `FailedMount` / `FailedAttachVolume` | PVC not bound, RWO volume attached elsewhere |
| `Multi-Attach error for volume` | RWO PVC referenced by pods on two different nodes |
| `ProvisioningFailed` (PVC) | StorageClass misconfigured or provisioner unavailable |

### Networking
| Error | Common Cause |
|---|---|
| `NetworkNotReady` | CNI plugin not initialized on node |
| `FailedCreatePodSandBox` | CNI failed to set up pod network namespace |
| DNS resolution failures (`NXDOMAIN`) | CoreDNS misconfig, upstream resolver issue |
| `dial tcp: i/o timeout` between pods | NetworkPolicy blocking traffic, or wrong service port |
| `no endpoints available for service` | Selector mismatch between Service and pod labels |
| `connection refused` (Service) | App not actually listening on the configured containerPort |
| kube-proxy iptables errors | Stale iptables rules after node/network changes |
| `x509: certificate signed by unknown authority` | Internal CA not trusted by client, common with webhooks |

### Probes, Termination & Cluster-Level
| Error | Common Cause |
|---|---|
| Readiness probe failed | Pod running but excluded from Service endpoints |
| Liveness probe failed | Restart triggered — can cascade to CrashLoopBackOff |
| Startup probe failed | App takes longer to boot than `failureThreshold * periodSeconds` |
| `Terminating` (stuck) | Finalizer not removed, or SIGTERM ignored until force kill |
| `NodeLost` / `NodeNotReady` | Node unreachable, kubelet not reporting heartbeat |
| `FailedGetResourceMetric` (HPA) | metrics-server not installed or not scraping properly |
| `admission webhook denied the request` | Webhook policy (OPA/Gatekeeper, Kyverno) blocked the object |
| `etcdserver: request timed out` | etcd overloaded or disk I/O too slow on control plane |
| `the server was unable to return a response` (API) | API server overloaded or briefly unavailable |
| `Too many requests, please try again later` | Client-side rate limiting from API server |
| `forbidden: User cannot ... resource` | RBAC Role/ClusterRole missing permission |

**Diagnose:**
```bash
kubectl get pods -o wide
kubectl describe pod <name>
kubectl logs <name> [-c container] [--previous]
kubectl get events --sort-by='.lastTimestamp'
kubectl top pod / kubectl top node
kubectl auth can-i <verb> <resource> --as=<user>
```

---

## 2. Docker

### Daemon / Connection Errors
| Error | Common Cause |
|---|---|
| `Cannot connect to the Docker daemon at unix:///var/run/docker.sock` | Docker daemon not running |
| `permission denied while trying to connect to the Docker daemon socket` | User not in `docker` group — needs sudo or group membership |
| `dial unix docker.sock: connect: connection refused` | Daemon crashed or not started |
| `Error response from daemon: dial tcp: lookup ... no such host` | DNS resolution failing inside daemon context |
| `context deadline exceeded` (daemon) | Daemon overloaded or hung |
| `Error starting daemon: pid file found, ensure docker is not running` | Stale PID file from an unclean shutdown |

### Build Errors
| Error | Common Cause |
|---|---|
| `COPY failed: file not found in build context` | Wrong build context path, or file excluded by `.dockerignore` |
| `failed to solve: process "/bin/sh -c ..." did not complete successfully` | The actual RUN command failed — check output above this line |
| `failed to solve with frontend dockerfile.v0` | Syntax error in Dockerfile |
| `no such file or directory` during COPY/ADD | Path typo, or file not present at build time |
| `exec format error` | Architecture mismatch — building/running ARM image on x86 host or vice versa |
| `failed to fetch metadata` | BuildKit cache corruption |
| `unknown instruction:` | Dockerfile directive misspelled |
| `pull access denied, repository does not exist or may require authorization` | Base image name wrong, or private and not logged in |
| `failed to authorize: authentication required` | `docker login` not run for private registry |
| `toomanyrequests: You have reached your pull rate limit` | Docker Hub anonymous pull limit hit |
| Build cache not invalidating when it should | Layer depends on external state (e.g. `apt update`) not tracked by Docker |
| Build cache invalidating too often | Files that change often (like source code) placed too early in Dockerfile |
| `failed to compute cache key` | Corrupted BuildKit cache — needs `docker builder prune` |

### Runtime / Container Start Errors
| Error | Common Cause |
|---|---|
| `OCI runtime create failed: exec: "...": executable file not found in $PATH` | ENTRYPOINT/CMD binary doesn't exist in the image |
| `OCI runtime create failed: ... permission denied` | Binary not executable, or `--user` lacks rights |
| `standard_init_linux.go:228: exec user process caused: exec format error` | Wrong CPU architecture for the image |
| Container exits immediately (code 0) | No long-running foreground process — CMD backgrounds itself or finishes instantly |
| `Error response from daemon: driver failed programming external connectivity` | Port already in use, or iptables rule conflict |
| `port is already allocated` | Another container/process is bound to that host port |
| Container restarts in a loop | App crashing — check `docker logs`, same root causes as CrashLoopBackOff |
| `OOMKilled: true` (in `docker inspect`) | Container hit its `--memory` limit |
| `rpc error: code = Unknown desc = ...` | Low-level containerd/runc failure — check daemon logs |
| `the container name "..." is already in use` | Stale container from a previous run not removed |
| `Error: No such container` | Referenced container already removed or never existed |

### Volume / Storage Errors
| Error | Common Cause |
|---|---|
| `no space left on device` | Disk full — unpruned images, containers, volumes, build cache |
| `invalid mount config for type "bind": bind source path does not exist` | Host path in `-v`/`volumes:` doesn't exist |
| `Error mounting volume: permission denied` | SELinux/AppArmor context or host directory permissions |
| Volume data disappears after restart | Used `docker run` without `-v` (anonymous, ephemeral layer) instead of a named volume |
| `Error response from daemon: volume is in use` | Trying to remove a volume still attached to a container |

### Networking Errors
| Error | Common Cause |
|---|---|
| `network ... not found` | Referenced Docker network was removed or never created |
| `Error response from daemon: Pool overlaps with other one on this address space` | Custom network subnet conflicts with existing network |
| Containers can't reach each other by name | Not on the same user-defined bridge network (default bridge doesn't do DNS) |
| Containers can't reach the internet | Host iptables/firewall blocking, or DNS not configured in daemon |
| `Error response from daemon: endpoint ... not found` | Container disconnected from network unexpectedly |

### Compose-Specific Errors
| Error | Common Cause |
|---|---|
| `ERROR: for <service> Cannot start service: OCI runtime create failed` | Same as above — bad entrypoint in compose-defined service |
| `service "..." depends on undefined service` | Typo in `depends_on`, or service removed but still referenced |
| `Version in "./docker-compose.yml" is unsupported` | Compose file version incompatible with installed Compose/Docker version |
| Env vars not substituting in compose file | Missing `.env` file, or wrong variable syntax (`${VAR}` vs `$VAR`) |
| `ERROR: Service '...' failed to build` | Build context/Dockerfile path wrong relative to compose file location |

**Diagnose:**
```bash
docker logs <container>
docker logs --previous <container>      # only if container was restarted by a supervisor
docker inspect <container>              # check State, OOMKilled, ExitCode
docker events                           # live stream of daemon-level events
docker system df                        # disk usage breakdown
docker system prune -a --volumes        # reclaim space (destructive — check first)
docker build --progress=plain --no-cache .
docker network inspect <network>
journalctl -u docker.service            # daemon-level errors on Linux
```

---

## 3. Helm

| Error | Common Cause |
|---|---|
| `Error: UPGRADE FAILED: has no deployed releases` | Prior release stuck in `failed`/`pending` state |
| `Error: another operation (install/upgrade/rollback) is in progress` | Previous Helm operation didn't complete/release lock |
| `Error: YAML parse error` | Bad indentation in values.yaml or template |
| `Error: template: ... nil pointer evaluating` | Referencing a values key that doesn't exist |
| `Error: found in Chart.yaml, but missing in charts/ directory` | Dependency not fetched — needs `helm dependency update` |
| `Error: INSTALLATION FAILED: cannot re-use a name that is still in use` | Release name conflict |
| `Error: unable to build kubernetes objects from release manifest` | Invalid manifest generated from templating |
| Rollback fails | Target revision's CRDs/resources no longer compatible with cluster state |
| `Error: timed out waiting for the condition` | `--wait` flag set but resources never became ready |

**Diagnose:**
```bash
helm status <release>
helm history <release>
helm get manifest <release>
helm template . --debug
helm rollback <release> <revision>
```

---

## 4. Terraform

| Error | Common Cause |
|---|---|
| `Error: state lock` | Another apply/plan running, or stale lock (DynamoDB/S3 backend) |
| `Error acquiring the state lock` | Crashed process didn't release lock |
| `Error: Provider produced inconsistent result after apply` | Provider bug or resource changed outside Terraform |
| `Error: Resource already exists` | Created outside TF — needs `terraform import` |
| `Error: Cycle` | Circular dependency between resources/modules |
| `Error: Invalid count argument` | `count`/`for_each` depends on value unknown until apply |
| `Error: Reference to undeclared resource` | Typo, or missing module output |
| Drift on plan | Manual out-of-band changes |
| `Error: context deadline exceeded` | Provider API timeout / throttling |
| `Error: Unsupported argument` | Provider version mismatch |
| `Backend configuration changed` | Backend edited without `terraform init -reconfigure` |
| `Error: Failed to install provider` | Registry unreachable, or version constraint unsatisfiable |
| `Error: Inconsistent conditional result types` | Ternary expression returning mismatched types |
| `Error: Duplicate resource` | Same resource address defined twice (often after a bad merge) |
| `Error: Module not installed` | Forgot `terraform init` after adding a module |
| `Error: Unsupported attribute` (`.this is not a valid ...`) | Output/attribute renamed in a provider upgrade |
| State drift after manual `terraform state rm` | Resource removed from state but still exists in cloud |
| `Error: value depends on resource attributes that cannot be determined until apply` | Same as invalid count/for_each — needs `-target` or restructuring |

**Diagnose:**
```bash
terraform plan -detailed-exitcode
terraform state list
terraform state show <resource>
terraform force-unlock <lock-id>
terraform import <resource> <id>
TF_LOG=DEBUG terraform apply
terraform validate
```

---

## 5. CI/CD Pipelines (GitHub Actions / GitLab CI / CircleCI / Azure DevOps)

| Error | Common Cause |
|---|---|
| `exit code 1` (generic) | Underlying command failed — check step logs |
| Pipeline stuck "queued" | No available runners, or runner tags don't match job |
| `permission denied` on runner | Missing execute bit, or runner user lacks rights |
| Cache miss / stale cache | Cache key changed, or restored after dependent step |
| Secret/variable not found | Not scoped to the branch/environment running the job |
| `YAML syntax error` | Indentation or duplicate keys |
| Artifact not found downstream | Not uploaded in prior stage, or path mismatch |
| Flaky test failures | Race conditions, shared test state, ordering |
| Docker-in-Docker failures | Missing `privileged: true`, DinD service not started |
| Registry rate-limited | Too many pulls in short time |
| `fatal: could not read Username for 'https://github.com'` | Missing/expired token for private repo checkout |
| Job exceeds time limit / killed | Default timeout too short for the workload |
| Matrix build partial failures | One matrix leg has an environment-specific bug, not the pipeline itself |
| Self-hosted runner goes offline mid-job | Resource exhaustion (disk/memory) on the runner host |
| `Error: Process completed with exit code 137` in runner | Runner OOM-killed the job |
| Webhook not triggering pipeline | Webhook misconfigured, secret mismatch, or firewall blocking |
| Branch protection blocks merge despite green pipeline | Required check name mismatch after pipeline rename |
| Environment approval stuck | Required reviewer hasn't approved deployment gate |

**Diagnose:**
- Enable debug/verbose logging (`ACTIONS_STEP_DEBUG=true`, `CI_DEBUG_TRACE=true`)
- Inspect runner/agent logs separately from job logs
- Reproduce the failing step locally in the same container image

---

## 6. AWS

| Error | Common Cause |
|---|---|
| `AccessDenied` | IAM policy missing action/resource, or explicit Deny |
| `UnauthorizedOperation` | Insufficient IAM permissions |
| `Throttling` / `RequestLimitExceeded` | API rate limits — needs backoff/retry |
| `InsufficientInstanceCapacity` | No capacity for instance type in that AZ |
| `LimitExceededException` | Account/service quota reached |
| `InvalidParameterValue` | Wrong region, AMI, or subnet reference |
| `DependencyViolation` | Deleting a resource still referenced elsewhere |
| ELB/ALB `502` | Unhealthy targets, or target closing connection unexpectedly |
| ELB/ALB `503` | No healthy targets registered |
| ELB/ALB `504` | Target too slow to respond within idle timeout |
| CloudFormation `CREATE_FAILED` | Check stack events — IAM, quota, dependency order |
| CloudFormation `ROLLBACK_COMPLETE` | Stack failed and rolled back — must delete before recreating |
| CloudFormation `UPDATE_ROLLBACK_FAILED` | Manual intervention needed — resource stuck mid-rollback |
| ECS task stuck `PENDING` | No cluster capacity, or can't pull image |
| ECS task `STOPPED` (exit 1) | App crash — check CloudWatch Logs |
| ECS `CannotPullContainerError` | ECR permissions or VPC endpoint/NAT missing for image pull |
| S3 `403 Forbidden` | Bucket policy, IAM policy, or Block Public Access |
| S3 `SlowDown` | Request rate exceeded on a prefix |
| RDS `CannotCreateDBInstance` | Subnet group misconfig, storage/instance quota |
| RDS `Storage full` | Autoscaling storage disabled or max threshold hit |
| Lambda `Task timed out` | Function exceeded configured timeout |
| Lambda `ENOMEM` | Memory allocation too low |
| Lambda `Unable to import module` | Missing dependency in deployment package/layer |
| VPC `Unsupported: does not exist in AZ` | Instance type not available in that AZ |
| Route53 health check failing | Endpoint unreachable, wrong health check path/port |
| IAM `MalformedPolicyDocument` | Invalid JSON or unsupported policy syntax |
| KMS `AccessDeniedException` | Key policy doesn't grant the calling principal decrypt/encrypt |
| Secrets Manager `ResourceNotFoundException` | Wrong secret ARN, or secret in different region |
| Auto Scaling group not scaling | CloudWatch alarm misconfigured, or cooldown period too long |

**Diagnose:**
```bash
aws sts get-caller-identity
aws cloudtrail lookup-events
aws cloudformation describe-stack-events --stack-name <name>
aws logs tail /aws/lambda/<fn> --follow
aws ecs describe-tasks --cluster <c> --tasks <task-id>
```

---

## 7. Git

| Error | Common Cause |
|---|---|
| `fatal: refusing to merge unrelated histories` | No common commit ancestor between repos/branches |
| `CONFLICT (content): Merge conflict` | Same lines changed in both branches |
| `fatal: not a git repository` | Outside a repo, or `.git` missing/corrupted |
| `error: failed to push some refs` | Remote has commits you don't have locally |
| `fatal: Authentication failed` | Expired token/credentials, SSH key not loaded |
| `detached HEAD state` | Checked out a commit/tag directly |
| `no upstream branch` | Never set with `git push -u origin <branch>` |
| `your local changes would be overwritten` | Uncommitted changes conflict with incoming operation |
| `fatal: bad object` | Corrupted `.git` objects |
| Large file push rejected | Exceeds host's size limit — needs Git LFS |
| `Permission denied (publickey)` | SSH key not registered, or wrong key in use |
| `fatal: unable to access ... Could not resolve host` | DNS/network issue, or wrong remote URL |
| `error: cannot lock ref` | Stale lock file in `.git/refs`, often from an interrupted operation |
| `warning: LF will be replaced by CRLF` | Line-ending mismatch (`core.autocrlf` config) |
| `fatal: sha1 information is lacking / object corrupt` | Repo corruption — needs re-clone or `git fsck --full` |
| Submodule not initialized | Forgot `git submodule update --init --recursive` |
| `fatal: This operation must be run in a work tree` | Ran a work-tree command from inside `.git` directory |
| Rebase stuck mid-conflict | Unresolved conflicts blocking `git rebase --continue` |
| Force-push overwrote teammate's commits | `--force` used instead of `--force-with-lease` |

**Diagnose:**
```bash
git status
git log --oneline --graph --all
git fsck
git remote -v
ssh -T git@github.com
git reflog   # recover "lost" commits
```

---

## 8. Istio

| Error | Common Cause |
|---|---|
| `UF,URX` in access logs | Upstream connection failure — pod not ready, wrong port |
| `503 UH` (Upstream unhealthy) | No healthy endpoints for destination |
| `503 NR` (No route) | No matching VirtualService/route |
| `503 UO` | Circuit breaker/outlier detection ejected the host |
| `504 UT` | Upstream request timeout |
| Sidecar not injected | Namespace missing `istio-injection=enabled` label |
| mTLS handshake failure | PeerAuthentication mismatch (STRICT vs PERMISSIVE) |
| `Config Not Effective` (istioctl analyze) | Conflicting/overlapping VirtualServices or DestinationRules |
| Traffic not splitting per weights | DestinationRule subsets missing/mislabeled |
| Envoy `CrashLoopBackOff` | Bad proxy config pushed via istiod, or resource limits too low |
| Ingress Gateway `404` | Gateway/VirtualService host mismatch |
| `RBAC: access denied` | AuthorizationPolicy blocking the request |
| Slow startup / traffic loss on deploy | Missing `holdApplicationUntilProxyStarts`, sidecar not ready before app receives traffic |
| istiod `unable to build resource` | Invalid CRD or webhook validation failure |
| Certificate expiry causing outages | Istio CA root cert or workload cert not rotated in time |

**Diagnose:**
```bash
istioctl analyze
istioctl proxy-status
istioctl proxy-config routes <pod>
istioctl proxy-config cluster <pod>
kubectl logs <pod> -c istio-proxy
```

---

## 9. Jenkins

| Error | Common Cause |
|---|---|
| `Pipeline script returned exit code 1` | Underlying shell step failed |
| Agent offline / stuck queue | No matching label, or agent disconnected |
| `Permission denied` on workspace | Ownership mismatch between builds/agents |
| `groovy.lang.MissingPropertyException` | Undefined variable in Jenkinsfile |
| `java.lang.OutOfMemoryError` | JVM heap too small on controller/agent |
| Credentials not found | Wrong ID, or scoped to wrong folder/domain |
| Webhook not triggering build | Misconfigured webhook, firewall blocking Jenkins URL |
| Build stuck in queue | Executors exhausted, or throttling plugin |
| `Failed to connect to repository` | Wrong URL, missing SSH key/credentials |
| Plugin compatibility errors after upgrade | Core upgraded ahead of plugin versions |
| `No such DSL method` in pipeline | Missing plugin providing that step, or typo |
| `Script not yet approved` | Groovy sandbox restriction pending admin approval |
| Agent JNLP connection refused | Firewall blocking agent port, or wrong controller URL |
| Disk space alert on controller | Old builds/artifacts not cleaned up |
| Pipeline hangs indefinitely | Waiting on manual input step, or a deadlocked shared resource lock |

**Diagnose:**
- Manage Jenkins → System Log
- Manage Nodes → individual agent logs
- `docker logs jenkins` (if containerized)
- Script Console for ad-hoc Groovy diagnostics

---

## 10. Ansible

| Error | Common Cause |
|---|---|
| `UNREACHABLE!` | SSH connectivity — wrong host, key, or firewall |
| `permission denied` (become) | Wrong `become` config or sudo password required |
| `Missing sudo password` | `become: true` without `--ask-become-pass` |
| `couldn't resolve module/action` | Module typo, or collection not installed |
| `the field 'hosts' is required` | Inventory group mismatch |
| Idempotency failures | Module doesn't natively support check-before-change |
| `Timeout waiting for privilege escalation prompt` | Slow sudo response, wrong become method |
| YAML parsing errors | Whitespace-sensitive indentation issues |
| Handler never runs | Task didn't report "changed", or handler name mismatch |
| Variable undefined | Missing `vars`, wrong scope, Jinja2 typo |
| `Failed to lock apt for exclusive operation` | Another package manager process running concurrently |
| `MODULE FAILURE` with no clear message | Python interpreter mismatch on target host |
| Fact gathering timeout | Target host slow/unreachable during `setup` module run |
| `ERROR! the playbook ... could not be found` | Wrong path or working directory |
| Vault decryption failure | Wrong vault password file/ID |

**Diagnose:**
```bash
ansible-playbook site.yml -vvv
ansible all -m ping -i inventory
ansible-playbook site.yml --check --diff
ansible-inventory -i inventory --list
ansible-vault view secrets.yml
```

---

## 11. Prometheus / Grafana

| Error | Common Cause |
|---|---|
| `context deadline exceeded` (scrape) | Target too slow to respond within scrape timeout |
| Target shows `DOWN` | App not exposing `/metrics`, wrong port, or firewall |
| `out of order sample` | Clock skew, or duplicate scrape configs for same target |
| `too many open files` | File descriptor limit hit under high scrape/series load |
| High cardinality warning | Label combinations exploding (e.g., unique user ID as label) |
| Alertmanager not firing | Alert rule expression never true, or route/matcher mismatch |
| Alertmanager notification fails | Wrong webhook URL, or receiver misconfigured |
| Grafana `No data` | Wrong data source, time range outside retention, or query error |
| Grafana `502 Bad Gateway` from data source | Prometheus unreachable from Grafana pod/host |
| PromQL query too expensive / times out | Overly broad range vector or missing aggregation |
| TSDB corruption on restart | Unclean shutdown mid-write, WAL replay failure |

**Diagnose:**
```bash
curl http://<target>:9090/metrics
promtool check config prometheus.yml
promtool check rules alerts.yml
```

---

## General Debugging Principles Across All Tools

1. **Read the actual error, not just the status.** Verbose/debug flags exist everywhere (`-vvv`, `--debug`, `TF_LOG=DEBUG`) — use them before guessing.
2. **Check the layer below.** App → container → node → network → cloud provider. Most "mystery" failures are one layer down from the visible symptom.
3. **Diff against known-good state.** Terraform drift, Git conflicts, and Ansible idempotency issues are all "what changed since it last worked."
4. **Rate limits and quotas masquerade as random failures.** AWS throttling, Docker Hub pull limits, CI runner exhaustion often look like flaky bugs.
5. **Logs first, restart second.** Restarting before capturing logs destroys your evidence (`--previous` for crashed pods, `docker logs` before `docker rm`).
6. **Version skew is a frequent silent cause.** Terraform providers, Helm charts, Jenkins plugins, and Istio/K8s version mismatches all produce confusing errors that look unrelated to versioning.

---

*Error messages, exit codes, and diagnostics evolve with tool versions — treat this as a map for pattern-matching, and cross-check exact wording against current docs for whatever version you're running.*
