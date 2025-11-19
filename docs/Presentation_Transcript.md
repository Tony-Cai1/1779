# Infrastructure & Deployment Demo Transcript
node-exporter → Prometheus → Grafana
Pod Logs → Promtail → Loki → Grafana

## 2-Minute Live Demo Script

---

## [00:00-00:15] Introduction & Overview

"Good [morning/afternoon]. I'll demonstrate our Library Management System's cloud infrastructure and deployment architecture. We've built a production-ready, scalable system using Docker, Kubernetes, and a comprehensive observability stack."

[Show high-level architecture diagram or kubectl get pods]

"Our stack includes: a FastAPI backend, PostgreSQL database, Prometheus and Grafana for monitoring, and ArgoCD for GitOps-based deployments running on Kubernetes."

---

## [00:15-00:45] Docker Containerization & Multi-Container Architecture

### Docker Containerization

"First, **Docker Containerization**. All application components are containerized."

[Show docker-compose.yml or Dockerfile]

"Our FastAPI backend is containerized using a multi-stage Docker build, running Python 3.10. We use Docker Compose locally for development with three services: the API container, PostgreSQL database container, and a seed job container for initial data."

"The backend exposes port 8000, connects to PostgreSQL, and follows best practices with health checks and dependency management. The database container uses PostgreSQL 16 Alpine for minimal footprint."

### Multi-Container Architecture

"This brings us to **Multi-Container Architecture**. In production, we deploy to Kubernetes with multiple services working together:"

[Show kubectl get deployments]

"We have:
- **lms-api deployment**: 2 replicas of the FastAPI backend
- **postgres deployment**: Single PostgreSQL instance with persistent storage
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Loki**: Log aggregation
- **Promtail**: Log collection daemon
- **Node Exporter**: Node-level metrics

All services communicate through Kubernetes services and are managed as a cohesive unit."

---

## [00:45-01:10] PostgreSQL with Persistent Storage & Stateful Design

### PostgreSQL with Persistent Storage

"**PostgreSQL uses persistent storage** to ensure data survives container restarts and redeployments."

[Show postgres-deployment.yaml or kubectl get pvc]

"In Kubernetes, we use a PersistentVolumeClaim requesting 10 gigabytes. The PVC is bound to a persistent volume and mounted at `/var/lib/postgresql/data` in the PostgreSQL container. This persists all database data, including users, books, and transactions."

"Similarly, in Docker Compose, we use a named Docker volume `lms_db_data` that persists even when containers stop."

### Stateful Design Explanation

"This is our **Stateful Design**. Here's how we maintain state across restarts:"

[Show kubectl describe pod postgres | grep -A 5 Mounts]

"The FastAPI application is **stateless**—all application state lives in PostgreSQL. When API pods restart, they reconnect to the same database with all data intact. When the PostgreSQL pod restarts, Kubernetes reattaches the same persistent volume, preserving all data."

"This means:
- ✅ Pod restarts don't lose data
- ✅ Rolling updates maintain data integrity
- ✅ Node failures preserve data (with network-attached storage)
- ✅ Complete redeployments retain user data

We can verify this by restarting pods and confirming data persistence."

---

## [01:10-01:30] Kubernetes Orchestration & HPA

### Kubernetes Orchestration

"**Kubernetes Orchestration** handles deployment, scaling, and service management."

[Show ArgoCD UI - switch to browser]

"This is ArgoCD, our GitOps deployment tool. ArgoCD watches our Git repository and automatically syncs Kubernetes manifests. You can see our application is healthy and synced with Git."

[Click on lms-api application in ArgoCD]

"Here we see the deployment status: all resources are synced, showing our API deployment with 2 replicas, the PostgreSQL deployment, services, and HPA configuration."

[Show kubectl get hpa]

"Speaking of HPA—**Horizontal Pod Autoscaling**. Our API deployment scales automatically based on CPU and memory usage:"

[Highlight HPA configuration or kubectl describe hpa]

"HPA monitors CPU utilization targeting 50% and memory utilization targeting 70%. It scales between 1 and 5 replicas:
- Scale up: Up to 100% increase every 15 seconds, or 2 pods at a time
- Scale down: Maximum 50% decrease per minute with a 60-second stabilization window

This ensures optimal resource utilization and handles traffic spikes automatically."

---

## [01:30-02:00] Monitoring & Observability

"Finally, **Monitoring and Observability** using Prometheus and Grafana."

[Switch to Grafana dashboard]

### Grafana Dashboards

"This is our Grafana monitoring dashboard. We have several pre-configured dashboards:"

[Navigate through Grafana dashboards]

1. **Application Metrics**: 
   - Request rates, latency percentiles
   - Error rates and response times
   - Real-time API performance

2. **Kubernetes Cluster Metrics**:
   - Node CPU, memory, disk usage
   - Pod resource consumption
   - HPA scaling events

3. **PostgreSQL Metrics**:
   - Database connections, query performance
   - Transaction rates and lock statistics

4. **Loki Logs Dashboard**:
   - Centralized log aggregation from all pods
   - Searchable, filtered application logs

### Monitoring Stack

"Our monitoring stack includes:
- **Prometheus**: Scrapes metrics from our API pods via `/metrics` endpoint, node exporters, and cAdvisor
- **Grafana**: Visualizes metrics with custom dashboards
- **Loki**: Aggregates logs from all containers
- **Promtail**: Collects logs from each node as a DaemonSet

All metrics are scraped every 15 seconds, providing real-time visibility into our infrastructure."

---

## [02:00-02:05] Summary & Closing

"In summary, we've demonstrated:

✅ **Docker containerization** of all components
✅ **Multi-container architecture** with orchestrated services
✅ **PostgreSQL with persistent storage** ensuring data durability
✅ **Kubernetes orchestration** with automated deployments via ArgoCD
✅ **Horizontal Pod Autoscaling** for dynamic scaling
✅ **Comprehensive monitoring** with Prometheus, Grafana, and Loki
✅ **Stateful design** that maintains data across restarts

This infrastructure provides a production-ready, scalable, and observable system. Thank you!"

---

## Demo Checklist & Key Points

### Before Demo:
- [ ] ArgoCD UI accessible and showing healthy sync
- [ ] Grafana dashboards loaded and showing data
- [ ] At least 2 API pods running
- [ ] HPA active
- [ ] Sample data exists (for state persistence example)

### During Demo - ArgoCD UI:
- Show application list
- Click into lms-api application
- Show resource tree (Deployments, Services, PVC, HPA)
- Show sync status and health indicators
- Point out Git repository connection

### During Demo - Grafana:
- Show Application Metrics dashboard
- Show Kubernetes Cluster dashboard
- Show PostgreSQL dashboard
- Show HPA scaling metrics
- Show real-time metric updates

### Key Talking Points:
1. **Emphasize GitOps**: ArgoCD syncs from Git automatically
2. **Highlight persistence**: Show PVC in ArgoCD resource tree
3. **Show scalability**: Point out HPA and multiple replicas
4. **Demonstrate observability**: Real-time metrics in Grafana
5. **State persistence**: Mention how PVC ensures data survives restarts

### Quick Commands Reference:
```bash
# Show pods
kubectl get pods

# Show HPA
kubectl get hpa

# Show PVC
kubectl get pvc

# Show deployments
kubectl get deployments

# Show services
kubectl get services
```

