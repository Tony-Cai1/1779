# Telemetry Setup Guide

This guide explains how to set up and use Prometheus and Grafana for monitoring the Library Management System (LMS) API and Kubernetes cluster.

## Overview

The telemetry stack consists of:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Custom Metrics**: API request rates, durations, endpoint usage, and WebSocket connections
- **Cluster Metrics**: CPU, memory, network, and pod usage
- **Node Exporter**: Node-level system metrics

## Prerequisites

- Kubernetes cluster with RBAC enabled
- `kubectl` configured to access your cluster
- Access to create ServiceAccounts, ClusterRoles, and ClusterRoleBindings

## Installation

### 1. Deploy Prometheus

Prometheus will scrape metrics from the LMS API pods and Kubernetes cluster components.

```bash
# Deploy Prometheus configuration
kubectl apply -f k8s/prometheus-configmap.yaml

# Deploy Prometheus server with RBAC
kubectl apply -f k8s/prometheus-deployment.yaml
```

Verify Prometheus is running:
```bash
kubectl get pods -l app=prometheus
kubectl get svc prometheus-service
```

### 2. Deploy Node Exporter (Optional - System Metrics)

Node Exporter collects node-level system metrics (CPU, memory, disk, network).

```bash
# Deploy Node Exporter DaemonSet (runs on each node)
kubectl apply -f k8s/node-exporter-daemonset.yaml
```

Verify Node Exporter is running:
```bash
kubectl get pods -l app=node-exporter
```

### 3. Deploy Grafana

Grafana will connect to Prometheus and provide visualization dashboards.

```bash
# Create Grafana secret (update password in production!)
kubectl apply -f k8s/grafana-secret.yaml

# Deploy Grafana datasources configuration
kubectl apply -f k8s/grafana-datasources.yaml

# Deploy Grafana dashboards configuration
kubectl apply -f k8s/grafana-dashboards.yaml

# Deploy Grafana server
kubectl apply -f k8s/grafana-deployment.yaml
```

Verify Grafana is running:
```bash
kubectl get pods -l app=grafana
kubectl get svc grafana-service
```

### 4. Access the Services

#### Prometheus UI

Get the LoadBalancer IP:
```bash
kubectl get svc prometheus-service
```

Then open `http://<EXTERNAL_IP>:9090` in your browser.

Alternatively, use port-forward for local access:
```bash
kubectl port-forward svc/prometheus-service 9090:9090
```

Then open http://localhost:9090 in your browser.

#### Grafana UI

Get the LoadBalancer IP:
```bash
kubectl get svc grafana-service
```

Or use port-forward:
```bash
kubectl port-forward svc/grafana-service 3000:3000
```

Then open http://localhost:3000 in your browser.

**Default Credentials:**
- Username: `admin`
- Password: `admin123` (change this in production!)

## Viewing Logs

To view logs from your pods, use `kubectl`:

```bash
# View logs from a specific pod
kubectl logs <pod-name>

# Follow logs in real-time
kubectl logs -f <pod-name>

# View logs from all API pods
kubectl logs -l app=lms-api

# View logs from previous container instance
kubectl logs <pod-name> --previous
```

## Metrics Collected

### Application Metrics

The LMS API exposes the following custom metrics:

1. **`lms_api_requests_total`**
   - Total number of API requests
   - Labels: `method`, `endpoint`, `status_code`
   - Example: Track GET /books/ requests with 200 status

2. **`lms_api_request_duration_seconds`**
   - API request duration histogram
   - Labels: `method`, `endpoint`
   - Example: Measure p95 latency for POST /borrow

3. **`lms_api_endpoint_requests_total`**
   - Total requests per endpoint
   - Labels: `endpoint`, `method`
   - Example: Count requests to /books/ vs /borrow

4. **`lms_websocket_connections_active`**
   - Number of active WebSocket connections
   - Gauge metric
   - Example: Monitor admin dashboard connections

5. **FastAPI Instrumentator Metrics**
   - `http_requests_total`: Total HTTP requests
   - `http_request_duration_seconds`: Request duration
   - `http_request_size_bytes`: Request size
   - `http_response_size_bytes`: Response size

### Cluster Metrics

Prometheus automatically collects:

1. **Container Metrics** (via cAdvisor)
   - CPU usage per pod
   - Memory usage per pod
   - Network I/O per pod
   - Disk I/O per pod

2. **Kubernetes Metrics**
   - Pod count by deployment
   - Node CPU and memory usage
   - Resource requests and limits

## Dashboards

### LMS API Metrics Dashboard

Located at: **Dashboards → LMS API Metrics**

This dashboard shows:
- **API Request Rate**: Requests per second by method and endpoint
- **API Request Duration (p95)**: 95th percentile latency
- **Requests by Endpoint**: Breakdown of traffic by endpoint
- **HTTP Status Codes**: Distribution of response codes
- **Active WebSocket Connections**: Real-time WebSocket connection count
- **FastAPI Request Rate**: Overall application request rate
- **API Calls Distribution by Endpoint** (Pie Chart): Percentage breakdown of requests by endpoint
- **API Calls Distribution by HTTP Method** (Pie Chart): Percentage breakdown of requests by method (GET, POST, etc.)
- **API Calls Distribution by Status Code** (Pie Chart): Percentage breakdown of requests by HTTP status code

### Kubernetes Cluster Usage Dashboard

Located at: **Dashboards → Kubernetes Cluster Usage**

This dashboard shows:
- **CPU Usage by Pod**: CPU consumption per pod
- **Memory Usage by Pod**: Memory consumption per pod
- **Network I/O by Pod**: Network traffic per pod
- **Pod Count by Deployment**: Number of pods per deployment
- **Node CPU Usage**: Overall node CPU utilization
- **Node Memory Usage**: Overall node memory utilization

## Creating Pie Charts

Grafana has built-in pie chart visualization support. The dashboard already includes three pie charts, but you can create custom ones:

### How to Create a Custom Pie Chart

1. **Open Grafana** → Go to your dashboard
2. **Add Panel** → Click "Add panel" → "Add visualization"
3. **Select Visualization** → Choose "Pie chart" from the visualization dropdown
4. **Enter PromQL Query** → Use queries like:
   - `sum(rate(lms_api_endpoint_requests_total[5m])) by (endpoint)` - Distribution by endpoint
   - `sum(rate(lms_api_requests_total[5m])) by (method)` - Distribution by HTTP method
   - `sum(rate(lms_api_requests_total[5m])) by (status_code)` - Distribution by status code
5. **Configure Display** → Set legend, tooltip, and pie type in panel options
6. **Save** → Click "Apply" and save the dashboard

### Pie Chart Queries

#### Distribution by Endpoint
```promql
sum(rate(lms_api_endpoint_requests_total[5m])) by (endpoint)
```

#### Distribution by HTTP Method
```promql
sum(rate(lms_api_requests_total[5m])) by (method)
```

#### Distribution by Status Code
```promql
sum(rate(lms_api_requests_total[5m])) by (status_code)
```

#### Distribution by Endpoint and Method (Combined)
```promql
sum(rate(lms_api_requests_total[5m])) by (endpoint, method)
```

#### Top 5 Most Used Endpoints
```promql
topk(5, sum(rate(lms_api_endpoint_requests_total[5m])) by (endpoint))
```

## Querying Metrics

### Prometheus Query Examples

#### API Request Rate (last 5 minutes)
```promql
rate(lms_api_requests_total[5m])
```

#### Request Rate by Endpoint
```promql
sum(rate(lms_api_endpoint_requests_total[5m])) by (endpoint)
```

#### p95 Latency for All Endpoints
```promql
histogram_quantile(0.95, rate(lms_api_request_duration_seconds_bucket[5m]))
```

#### Error Rate (4xx and 5xx)
```promql
sum(rate(lms_api_requests_total{status_code=~"4..|5.."}[5m])) by (status_code)
```

#### Active WebSocket Connections
```promql
lms_websocket_connections_active
```

#### CPU Usage by LMS API Pods
```promql
sum(rate(container_cpu_usage_seconds_total{pod=~"lms-api-.*"}[5m])) by (pod)
```

#### Memory Usage by LMS API Pods
```promql
sum(container_memory_working_set_bytes{pod=~"lms-api-.*"}) by (pod) / 1024 / 1024
```

## Troubleshooting

### Prometheus Not Scraping Metrics

1. Check if Prometheus can discover pods:
   ```bash
   kubectl get pods -l app=lms-api
   ```

2. Verify pod annotations:
   ```bash
   kubectl describe pod <pod-name> | grep prometheus
   ```

3. Check Prometheus targets:
   - Open Prometheus UI → Status → Targets
   - Verify `lms-api` job shows "UP"

4. Check Prometheus logs:
   ```bash
   kubectl logs -l app=prometheus
   ```

### Grafana Not Showing Data

1. Verify Prometheus datasource:
   - Grafana UI → Configuration → Data Sources
   - Test connection to Prometheus

2. Check dashboard queries:
   - Open dashboard → Edit panel
   - Verify query syntax and metric names

3. Check time range:
   - Ensure time range includes when metrics were collected

### Metrics Endpoint Not Accessible

1. Verify metrics endpoint:
   ```bash
   kubectl port-forward <pod-name> 8000:8000
   curl http://localhost:8000/metrics
   ```

2. Check if instrumentator is initialized:
   - Verify `prometheus-fastapi-instrumentator` is in requirements.txt
   - Check application logs for initialization errors

## Production Considerations

### Security

1. **Change Grafana Admin Password**
   ```bash
   # Update k8s/grafana-secret.yaml with a strong password
   kubectl apply -f k8s/grafana-secret.yaml
   kubectl rollout restart deployment/grafana
   ```

2. **Enable Authentication for Prometheus**
   - Consider using Ingress with authentication
   - Or use Prometheus Operator with authentication

3. **Restrict RBAC Permissions**
   - Review Prometheus ClusterRole permissions
   - Use namespace-specific roles if possible

### Performance

1. **Prometheus Retention**
   - Default: 30 days (configured in `prometheus-deployment.yaml`)
   - Adjust based on storage capacity and requirements

2. **Scrape Interval**
   - Default: 15 seconds (configured in `prometheus-configmap.yaml`)
   - Increase for high-volume clusters to reduce load

3. **Resource Limits**
   - Monitor Prometheus and Grafana resource usage
   - Adjust limits in deployment manifests as needed

### High Availability

1. **Prometheus**
   - Consider running multiple Prometheus instances
   - Use Prometheus Operator for easier management
   - Set up remote storage (e.g., Thanos)

2. **Grafana**
   - Run multiple Grafana replicas behind a service
   - Use persistent storage for dashboard configurations
   - Consider Grafana Cloud for managed service

## Updating Dashboards

Dashboards are configured in `k8s/grafana-dashboards.yaml`. To update:

1. Edit the JSON dashboard definitions
2. Apply the updated ConfigMap:
   ```bash
   kubectl apply -f k8s/grafana-dashboards.yaml
   ```
3. Restart Grafana to reload:
   ```bash
   kubectl rollout restart deployment/grafana
   ```

Alternatively, you can:
- Import dashboards directly in Grafana UI
- Export dashboards and update the ConfigMap
- Use Grafana Provisioning API

## Cleanup

To remove all telemetry components:

```bash
# Remove Grafana
kubectl delete -f k8s/grafana-deployment.yaml
kubectl delete -f k8s/grafana-dashboards.yaml
kubectl delete -f k8s/grafana-datasources.yaml
kubectl delete -f k8s/grafana-secret.yaml

# Remove Prometheus
kubectl delete -f k8s/prometheus-deployment.yaml
kubectl delete -f k8s/prometheus-configmap.yaml

# Remove Node Exporter (if deployed)
kubectl delete -f k8s/node-exporter-daemonset.yaml
```

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [FastAPI Prometheus Instrumentator](https://github.com/trallnag/prometheus-fastapi-instrumentator)
- [Node Exporter](https://github.com/prometheus/node_exporter)

