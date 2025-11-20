# Demo Quick Reference Card
## 2-Minute Live Demo - Key Talking Points

---

## Timeline Breakdown

| Time | Section | Key Points | Actions |
|------|---------|------------|---------|
| 0:00-0:15 | Intro | Overview of stack | Show kubectl get pods |
| 0:15-0:45 | Docker + Multi-Container | Containerization, services | Show docker-compose or ArgoCD |
| 0:45-1:10 | Persistent Storage + Stateful | PVC, data persistence | Show PVC in ArgoCD |
| 1:10-1:30 | K8s + HPA | Orchestration, autoscaling | Show ArgoCD UI, HPA metrics |
| 1:30-2:00 | Monitoring | Grafana dashboards | Navigate Grafana dashboards |

---

## 1. Docker Containerization (30 seconds)

### Talking Points:
- ✅ All components containerized using Docker
- ✅ FastAPI backend: Python 3.10-slim base image
- ✅ PostgreSQL: postgres:16-alpine (minimal footprint)
- ✅ Docker Compose for local dev with 3 services (api, db, seed)

### Show:
- Dockerfile (if accessible)
- `kubectl get pods` or ArgoCD UI showing containerized services

---

## 2. Multi-Container Architecture (30 seconds)

### Talking Points:
- ✅ Multiple services working together in Kubernetes
- ✅ API deployment (2 replicas), PostgreSQL, monitoring stack
- ✅ Services communicate via Kubernetes Services
- ✅ Health checks and dependency management

### Show:
- `kubectl get deployments` or ArgoCD resource tree
- List all services: API, DB, Prometheus, Grafana, Loki

---

## 3. PostgreSQL with Persistent Storage (25 seconds)

### Talking Points:
- ✅ PostgreSQL uses PersistentVolumeClaim (10Gi)
- ✅ Mounted at `/var/lib/postgresql/data`
- ✅ Data survives pod restarts, redeployments, node failures
- ✅ Docker Compose uses named volume `lms_db_data`

### Show:
- In ArgoCD: Click PostgreSQL pod → Show PVC in resource tree
- Or: `kubectl get pvc postgres-pvc`
- Or: `kubectl describe pod postgres | grep Mounts`

---

## 4. Stateful Design Explanation (20 seconds)

### Talking Points:
- ✅ FastAPI is stateless - all data in PostgreSQL
- ✅ API pods reconnect to same database on restart
- ✅ Database pod reattaches same PVC on restart
- ✅ Complete data persistence across all restarts

### Show:
- Explain architecture: Stateless API → Stateful DB
- Point to PVC in ArgoCD or show persistent volume mount

---

## 5. Kubernetes Orchestration (20 seconds)

### Talking Points:
- ✅ Deployed to Kubernetes cluster
- ✅ ArgoCD for GitOps - watches Git repo
- ✅ Automatic sync of Kubernetes manifests
- ✅ All resources managed declaratively

### Show:
- **ArgoCD UI**: Application list → Click lms-api
- Show sync status: Healthy, Synced
- Show resource tree: Deployments, Services, PVC, HPA, ConfigMaps

---

## 6. HPA - Horizontal Pod Autoscaling (20 seconds)

### Talking Points:
- ✅ Automatically scales API pods based on CPU/Memory
- ✅ CPU target: 50% utilization
- ✅ Memory target: 70% utilization
- ✅ Scales 1-5 replicas
- ✅ Fast scale-up (15s), gradual scale-down (60s)

### Show - LIVE DEMO:
1. **Show initial state** (3s):
   - `kubectl get pods -l app=lms-api` OR show in ArgoCD
   - Show current pod count (should be 2)

2. **Generate load** (5s):
   - Run: `hey -n 5000 -c 50 -z 20s http://API_URL/health`
   - OR use: `./demo-hpa-load.sh`

3. **Watch pods scale** (10s):
   - `kubectl get pods -l app=lms-api -w` OR watch in ArgoCD/Grafana
   - Point out pods being created: "Watch as new pods are created..."
   - Show HPA status: `kubectl get hpa` showing increased replicas

4. **Explain scaling** (2s):
   - "HPA detected high CPU and scaled from 2 to 4 pods automatically"

### Alternative (if time is tight):
- Just show HPA config and explain behavior
- Show Grafana HPA dashboard with historical scaling events

---

## 7. Monitoring & Observability (30 seconds)

### Talking Points:
- ✅ Prometheus: Metrics collection from all pods
- ✅ Grafana: Visualization dashboards
- ✅ Loki: Log aggregation
- ✅ Real-time monitoring of application, cluster, and database

### Show Grafana Dashboards:
1. **Application Metrics** (5s):
   - Request rates, latency
   - Error rates

2. **Kubernetes Cluster** (5s):
   - Node CPU/Memory
   - Pod resource usage
   - HPA scaling events

3. **PostgreSQL** (5s):
   - DB connections
   - Query performance

4. **Loki Logs** (5s):
   - Centralized logs from all pods

---

## Key Demo Actions Checklist

### Before Demo:
- [ ] Open ArgoCD UI in browser tab
- [ ] Open Grafana UI in browser tab
- [ ] Terminal ready with kubectl
- [ ] **Install `hey`**: `go install github.com/rakyll/hey@latest` OR download binary
- [ ] **Get API URL**: LoadBalancer IP or set up port-forward
- [ ] **Test HPA**: Run a quick load test to ensure scaling works
- [ ] Verify all services are running

### During Demo:
- [ ] Show ArgoCD application list
- [ ] Click into lms-api application
- [ ] Highlight PVC in resource tree
- [ ] Show HPA configuration
- [ ] Switch to Grafana
- [ ] Navigate through 2-3 dashboards
- [ ] Show real-time metrics updating

---

## One-Liner Summary

"Dockerized FastAPI and PostgreSQL running on Kubernetes with persistent storage, orchestrated via ArgoCD GitOps, autoscaled with HPA, and monitored with Prometheus, Grafana, and Loki - ensuring state persistence and production-ready observability."

---

## Backup Points (if time permits)

- **Ingress**: Show ingress configuration for external access
- **ConfigMaps/Secrets**: Show configuration management
- **Health Checks**: Liveness and readiness probes
- **Resource Limits**: CPU/Memory requests and limits
- **Network Policies**: (if configured)
- **Backup Strategy**: (if configured)

---

## Troubleshooting Quick Fixes

If something doesn't work:

1. **ArgoCD not synced**: Click "Sync" button
2. **Grafana no data**: Check Prometheus is scraping
3. **HPA not visible**: `kubectl get hpa`
4. **PVC not bound**: `kubectl describe pvc postgres-pvc`
5. **Pods not running**: `kubectl get pods` and check events

