# Live Demo Script - 2 Minutes
## Infrastructure & Deployment Presentation

---

## [00:00-00:15] INTRODUCTION

**"Today I'll demonstrate our Library Management System's production infrastructure - a fully containerized, orchestrated, and monitored system running on Kubernetes."**

[ACTION: Show kubectl get pods or ArgoCD UI]

**"Our stack includes: FastAPI backend, PostgreSQL database, Prometheus and Grafana monitoring, and ArgoCD for GitOps deployments."**

---

## [00:15-00:45] DOCKER CONTAINERIZATION & MULTI-CONTAINER

**"Starting with Docker Containerization - all components are containerized."**

[ACTION: Show docker-compose.yml or deployment.yaml]

**"The FastAPI backend uses Python 3.10-slim, PostgreSQL runs on Alpine for minimal footprint, and we use Docker Compose locally with three services: API, database, and seed job."**

**"This is our Multi-Container Architecture - in Kubernetes, we run:**
- **2 replicas of the API deployment** for high availability
- **PostgreSQL with persistent storage**
- **Complete monitoring stack**: Prometheus, Grafana, Loki, Promtail, Node Exporter

**All services communicate via Kubernetes Services and are managed as a unified system."**

[ACTION: Show ArgoCD resource tree or kubectl get deployments]

---

## [00:45-01:10] PERSISTENT STORAGE & STATEFUL DESIGN

**"PostgreSQL uses a PersistentVolumeClaim requesting 10 gigabytes, mounted at the data directory. This ensures data survives all container restarts and redeployments."**

[ACTION: In ArgoCD, click PostgreSQL pod → Show PVC in resource tree OR show kubectl get pvc]

**"This is our Stateful Design - the FastAPI app is stateless, storing all data in PostgreSQL. When API pods restart, they reconnect to the same database with all data intact. When the database pod restarts, Kubernetes reattaches the same persistent volume, preserving all data. This means pod restarts, rolling updates, and even node failures don't result in data loss."**

---

## [01:10-01:30] KUBERNETES ORCHESTRATION & HPA

**"Kubernetes Orchestration handles all deployment and scaling."**

[ACTION: In ArgoCD UI, show application sync status]

**"ArgoCD watches our Git repository and automatically syncs Kubernetes manifests - you can see our application is healthy and synced. All resources are managed declaratively."**

[ACTION: Show resource tree in ArgoCD, highlight HPA]

**"Here's our Horizontal Pod Autoscaler - it automatically scales API pods based on CPU and memory, targeting 50% CPU and 70% memory utilization, scaling between 1 and 5 replicas."**

[ACTION: Show current pod count - kubectl get pods -l app=lms-api OR show in ArgoCD]

**"Let me demonstrate this live - I'll generate load and you'll see pods scale up automatically."**

[ACTION: Run: ./demo-hpa-load.sh OR manually: hey -n 10000 -c 50 -z 30s http://API_URL/health]

**"Watch the pod count increase as CPU utilization rises..."**

[ACTION: Show kubectl get pods -l app=lms-api -w OR watch in ArgoCD/Grafana]

**"The HPA detected high CPU usage and is scaling from 2 to 4 pods. Scale-up happens within 15 seconds, while scale-down uses a 60-second stabilization window to prevent thrashing."**

[ACTION: Show HPA status: kubectl get hpa OR show in Grafana HPA dashboard]

---

## [01:30-02:00] MONITORING & OBSERVABILITY

**"Finally, Monitoring and Observability with Prometheus and Grafana."**

[ACTION: Switch to Grafana UI]

**"This is our Application Metrics dashboard - showing real-time request rates, latency percentiles, and error rates for our API."**

[ACTION: Navigate to Application dashboard, show for 5 seconds]

**"Here's our Kubernetes Cluster dashboard - showing node CPU and memory usage, pod resource consumption, and HPA scaling events happening right now."**

[ACTION: Navigate to Kubernetes dashboard, show for 5 seconds]

**"And our PostgreSQL dashboard - monitoring database connections, query performance, and transaction rates."**

[ACTION: Navigate to PostgreSQL dashboard, show for 5 seconds]

**"We also have Loki for centralized log aggregation from all containers, giving us complete observability across the entire stack."**

---

## [02:00-02:05] CLOSING

**"In summary: Docker containerization, multi-container Kubernetes architecture, PostgreSQL with persistent storage ensuring data durability, GitOps orchestration via ArgoCD, automatic scaling with HPA, and comprehensive monitoring. This is a production-ready, scalable, and observable system. Thank you!"**

---

## KEY DEMO ACTIONS

### Before Demo:
1. Open ArgoCD UI in browser (ready to show)
2. Open Grafana UI in browser (ready to show)
3. Have terminal ready with kubectl commands
4. **Install `hey` load testing tool**: `go install github.com/rakyll/hey@latest` OR download from releases
5. **Get API URL**: `kubectl get service lms-api-service` (LoadBalancer IP) OR set up port-forward
6. **Pre-test HPA**: Ensure HPA is working and pods can scale

### ArgoCD UI (1 minute):
1. Show application list (5s)
2. Click into lms-api application
3. Show sync status: Healthy, Synced (5s)
4. Show resource tree: Deployments, Services, PVC, HPA (15s)
5. Click on PVC to highlight persistent storage (5s)
6. Click on HPA to show autoscaling config (10s)

### Grafana Dashboards (30 seconds):
1. Application Metrics dashboard (5s)
2. Kubernetes Cluster dashboard (5s)
3. PostgreSQL dashboard (5s)
4. HPA scaling metrics (5s)
5. Show real-time updates (10s)

---

## PRACTICE TIMING

Practice reading this script and performing the actions to ensure:
- ✅ Smooth transitions between ArgoCD and Grafana
- ✅ Clear explanations while navigating UI
- ✅ Total time under 2 minutes
- ✅ All key points covered
- ✅ Natural flow and pace

---

## HPA LIVE DEMO SETUP

### Option 1: Automated Script (Recommended)
```bash
# Make sure API is accessible
export API_URL="http://YOUR_LOADBALANCER_IP"
# OR if using port-forward:
# kubectl port-forward service/lms-api-service 8000:80
# export API_URL="http://localhost:8000"

# Run the demo script
./demo-hpa-load.sh
```

### Option 2: Manual Commands
```bash
# Get API URL
API_URL=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# OR use port-forward: kubectl port-forward service/lms-api-service 8000:80

# Show initial state
kubectl get pods -l app=lms-api
kubectl get hpa lms-api-hpa

# Generate load (in one terminal)
hey -n 10000 -c 50 -z 30s "http://${API_URL}/health"

# Watch pods scale (in another terminal)
watch -n 2 'kubectl get pods -l app=lms-api && echo "" && kubectl get hpa lms-api-hpa'
```

### Option 3: Quick Demo (if time is tight)
```bash
# Just show HPA status and explain scaling behavior
kubectl get hpa lms-api-hpa
kubectl get pods -l app=lms-api
# Explain: "HPA will scale when CPU > 50% or Memory > 70%"
```

## BACKUP COMMANDS (if UI fails)

If UI doesn't work, use these kubectl commands:

```bash
# Show all resources
kubectl get pods,services,deployments,pvc,hpa

# Show PVC details
kubectl get pvc postgres-pvc
kubectl describe pvc postgres-pvc

# Show HPA
kubectl get hpa
kubectl describe hpa lms-api-hpa

# Watch pods scaling
kubectl get pods -l app=lms-api -w

# Show deployments
kubectl get deployments
kubectl describe deployment lms-api

# Show persistent volume mount
kubectl get pod -l app=postgres -o jsonpath='{.items[0].spec.volumes}'
```

