# Monitoring Architecture - Data Flow

## Overview

Your monitoring stack has **two separate data pipelines**:

1. **Metrics Pipeline**: For numerical metrics (CPU, memory, request rates, etc.)
2. **Logs Pipeline**: For log aggregation and search

These pipelines are **independent** and serve different purposes.

---

## Metrics Pipeline (Prometheus Stack)

### Data Flow:
```
node-exporter → Prometheus → Grafana
     ↓              ↓
  (exposes      (scrapes &
   metrics)      stores)
```

### Components:

1. **node-exporter** (DaemonSet)
   - **Purpose**: Collects node-level metrics (CPU, memory, disk, network)
   - **How it works**: Runs on each node, exposes metrics on port 9100
   - **Data format**: Prometheus metrics format (HTTP endpoint `/metrics`)
   - **Does NOT send data** - it only **exposes** data via HTTP

2. **Prometheus** (Deployment)
   - **Purpose**: Metrics collection and storage
   - **How it works**: **Scrapes** (pulls) metrics from multiple sources:
     - node-exporter (node metrics)
     - lms-api pods (application metrics via `/metrics` endpoint)
     - Kubernetes API server
     - Kubernetes nodes
     - Kubernetes pods (cAdvisor metrics)
   - **Scrape interval**: Every 15 seconds
   - **Storage**: Time-series database

3. **Grafana** (Deployment)
   - **Purpose**: Visualization and dashboards
   - **How it works**: Queries Prometheus to display metrics
   - **Data source**: Prometheus

### Key Point:
**node-exporter does NOT send data to Promtail.** It exposes metrics that Prometheus scrapes.

---

## Logs Pipeline (Loki Stack)

### Data Flow:
```
Pod Logs → Promtail → Loki → Grafana
   ↓          ↓        ↓
(hostPath) (collects  (stores)
           & sends)   logs)
```

### Components:

1. **Promtail** (DaemonSet)
   - **Purpose**: Log collection agent
   - **How it works**: 
     - Runs on each node
     - Reads logs from `/var/log/pods` and `/var/lib/docker/containers`
     - Discovers pods via Kubernetes API
     - **Pushes** logs to Loki
   - **Data format**: Log lines with labels (pod name, namespace, container, etc.)

2. **Loki** (Deployment)
   - **Purpose**: Log aggregation and storage
   - **How it works**: Receives logs from Promtail via HTTP API
   - **Storage**: Indexed log storage (similar to Prometheus but for logs)

3. **Grafana** (same instance)
   - **Purpose**: Log visualization and search
   - **How it works**: Queries Loki to display logs
   - **Data source**: Loki (in addition to Prometheus)

### Key Point:
**Promtail collects logs from pods, NOT from node-exporter.**

---

## Complete Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    METRICS PIPELINE                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────┐ │
│  │ node-exporter│──────▶│  Prometheus  │──────▶│ Grafana  │ │
│  │ (DaemonSet)  │ scrape│  (scrapes)  │ query │(dashboards)│
│  │ Port: 9100   │       │              │       │          │ │
│  └──────────────┘       └──────────────┘       └──────────┘ │
│         │                        ▲                            │
│         │                        │                            │
│         │              ┌─────────┴─────────┐                │
│         │              │                   │                │
│         │         ┌────▼────┐        ┌────▼────┐           │
│         │         │ lms-api │        │ k8s API │           │
│         │         │  pods   │        │ server  │           │
│         │         │ /metrics│        │         │           │
│         │         └─────────┘        └─────────┘           │
│                                                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     LOGS PIPELINE                           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────┐ │
│  │ Pod Logs     │──────▶│   Promtail   │──────▶│   Loki   │ │
│  │ /var/log/pods│ read │ (DaemonSet)  │ push │ (stores) │ │
│  │              │       │             │       │          │ │
│  └──────────────┘       └──────────────┘       └────┬─────┘ │
│                                                       │       │
│                                                       │ query │
│                                                       ▼       │
│                                                ┌──────────┐ │
│                                                │ Grafana  │ │
│                                                │(log view) │ │
│                                                └──────────┘ │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Common Misconception

### ❌ Incorrect:
```
node-exporter → Promtail → Loki
```

### ✅ Correct:
```
Metrics: node-exporter → Prometheus → Grafana
Logs:    Pod Logs → Promtail → Loki → Grafana
```

---

## Why Two Separate Pipelines?

1. **Different Data Types**:
   - **Metrics**: Numerical time-series data (CPU %, request rate, etc.)
   - **Logs**: Text-based event data (error messages, application logs)

2. **Different Use Cases**:
   - **Metrics**: "What is the current CPU usage?" "How many requests per second?"
   - **Logs**: "What error occurred?" "What did the application log?"

3. **Different Storage**:
   - **Prometheus**: Optimized for time-series metrics (efficient for numerical queries)
   - **Loki**: Optimized for log storage and search (efficient for text queries)

4. **Different Collection Methods**:
   - **Metrics**: Pull-based (Prometheus scrapes)
   - **Logs**: Push-based (Promtail pushes to Loki)

---

## How They Work Together

Both pipelines feed into **Grafana**, which provides a unified view:

- **Grafana Dashboards**: Show metrics from Prometheus
- **Grafana Explore**: Search logs from Loki
- **Correlation**: You can correlate metrics and logs (e.g., see logs when CPU spikes)

---

## Configuration Details

### node-exporter → Prometheus

**In `prometheus-configmap.yaml`**:
```yaml
scrape_configs:
  - job_name: 'node-exporter'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: node-exporter
      - source_labels: [__meta_kubernetes_pod_ip]
        action: replace
        target_label: __address__
        replacement: $1:9100
```

**How it works**:
1. Prometheus discovers pods with label `app=node-exporter`
2. Prometheus scrapes `http://<pod-ip>:9100/metrics` every 15 seconds
3. Metrics are stored in Prometheus time-series database

### Promtail → Loki

**In `promtail-configmap.yaml`**:
```yaml
clients:
  - url: http://loki-service:3100/loki/api/v1/push

scrape_configs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
```

**How it works**:
1. Promtail discovers pods via Kubernetes API
2. Promtail reads log files from `/var/log/pods`
3. Promtail pushes logs to Loki at `http://loki-service:3100/loki/api/v1/push`
4. Logs are stored in Loki with labels (pod, namespace, container, etc.)

---

## Summary

| Component | Purpose | Data Type | Direction | Destination |
|-----------|---------|-----------|-----------|-------------|
| **node-exporter** | Node metrics | Metrics | Expose (HTTP) | Prometheus (scrapes) |
| **Prometheus** | Metrics storage | Metrics | Scrape (pull) | Grafana (queries) |
| **Promtail** | Log collection | Logs | Push | Loki |
| **Loki** | Log storage | Logs | Receive (push) | Grafana (queries) |
| **Grafana** | Visualization | Both | Query | User (dashboards) |

**Key Takeaway**: node-exporter and Promtail are **completely separate** - one handles metrics, the other handles logs. They don't communicate with each other.


