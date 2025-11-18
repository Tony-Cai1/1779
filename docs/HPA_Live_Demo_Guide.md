# HPA Live Demo Guide
## Why Show Live Pod Scaling?

## ✅ Benefits of Live HPA Demo

1. **Visual Impact**: Seeing pods scale in real-time is much more impressive than just explaining it
2. **Demonstrates Real Functionality**: Shows HPA actually working, not just configured
3. **Engaging**: Audience can watch the scaling happen, making it memorable
4. **Proves Production-Ready**: Shows the system responds to load automatically
5. **Shows Metrics Integration**: Can demonstrate Prometheus metrics updating in Grafana simultaneously

## ⚠️ Considerations

### Timing
- HPA scale-up can take 15-30 seconds to trigger
- Need to balance demo time (2 minutes total) with showing the scaling
- **Solution**: Start load generation early, or show it happening in background

### Reliability
- HPA needs metrics to be available (Prometheus scraping)
- CPU needs to actually increase (may need significant load)
- Pods need time to start (image pull, initialization)
- **Solution**: Pre-test before demo, have backup plan

### Load Generation
- Need to generate enough load to trigger scaling
- `/health` endpoint is lightweight - may need many concurrent requests
- **Solution**: Use 50+ concurrent workers, target for 20-30 seconds

## 🎯 Recommended Demo Flow

### Option 1: Integrated Demo (Recommended for 2-min demo)

**Timing: 20 seconds total**

1. **Show HPA config** (5s):
   - "HPA scales based on CPU and memory"
   - Show current pod count (2 pods)

2. **Start load generation** (2s):
   - Run: `hey -n 5000 -c 50 -z 20s http://API_URL/health &`
   - Run in background so you can continue talking

3. **Show Grafana metrics** (8s):
   - Switch to Grafana
   - Show CPU metrics rising
   - Show HPA metrics dashboard
   - Point out: "CPU is increasing, HPA will scale soon"

4. **Show pods scaling** (5s):
   - Switch back to terminal or ArgoCD
   - Show new pods being created
   - "HPA detected high CPU and is scaling from 2 to 4 pods"

### Option 2: Full Live Demo (If you have 30+ seconds)

**Timing: 30-40 seconds**

1. Show initial state (3s)
2. Start load generation (2s)
3. Watch pods scale in real-time (20s)
4. Show final state and explain (5s)

### Option 3: Pre-recorded or Pre-loaded (Safest)

**Timing: 10 seconds**

1. Pre-generate load before demo starts
2. Show pods already scaled up
3. Explain what happened
4. Show Grafana metrics showing the scaling event

## 📋 Pre-Demo Checklist

### 1. Install `hey`
```bash
# Option 1: Go install
go install github.com/rakyll/hey@latest

# Option 2: Download binary
# Linux:
wget https://github.com/rakyll/hey/releases/download/v0.1.4/hey_linux_amd64
chmod +x hey_linux_amd64
sudo mv hey_linux_amd64 /usr/local/bin/hey

# macOS:
brew install hey
```

### 2. Get API URL
```bash
# Option 1: LoadBalancer
EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export API_URL="http://${EXTERNAL_IP}"

# Option 2: Port-forward (if no LoadBalancer)
kubectl port-forward service/lms-api-service 8000:80 &
export API_URL="http://localhost:8000"
```

### 3. Test HPA Works
```bash
# Quick test - generate light load
hey -n 1000 -c 10 -z 10s "${API_URL}/health"

# Check if pods scale (may take 30-60 seconds)
watch -n 2 'kubectl get pods -l app=lms-api && kubectl get hpa lms-api-hpa'
```

### 4. Verify Metrics
```bash
# Check Prometheus is scraping
kubectl get pods -l app=prometheus

# Check metrics endpoint
curl "${API_URL}/metrics" | grep http_requests_total
```

## 🚀 Demo Commands

### Quick Demo (20 seconds)
```bash
# Terminal 1: Generate load
hey -n 5000 -c 50 -z 20s "${API_URL}/health"

# Terminal 2: Watch pods (run simultaneously)
watch -n 1 'kubectl get pods -l app=lms-api && echo "" && kubectl get hpa lms-api-hpa'
```

### Automated Script
```bash
# Use the provided script
./demo-hpa-load.sh
```

### Manual Step-by-Step
```bash
# 1. Show initial state
kubectl get pods -l app=lms-api
kubectl get hpa lms-api-hpa

# 2. Generate load (in background)
hey -n 10000 -c 50 -z 30s "${API_URL}/health" > /dev/null 2>&1 &

# 3. Watch scaling
kubectl get pods -l app=lms-api -w

# 4. Show HPA status
kubectl get hpa lms-api-hpa -w
```

## 🎬 What to Say During Demo

### As you start load:
**"I'm generating load on the API to trigger autoscaling..."**

### As pods start scaling:
**"Watch as the HPA detects high CPU utilization - you can see new pods being created automatically. The system is scaling from 2 to 4 pods to handle the increased load."**

### Show metrics:
**"In Grafana, you can see the CPU metrics rising, and the HPA responding by increasing replica count. This happens automatically without any manual intervention."**

### Explain the behavior:
**"Scale-up happens quickly - within 15 seconds. Scale-down uses a 60-second stabilization window to prevent thrashing from temporary load spikes."**

## 🔧 Troubleshooting

### HPA Not Scaling?

1. **Check metrics are available**:
   ```bash
   kubectl get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/default/pods" | jq
   ```

2. **Check HPA status**:
   ```bash
   kubectl describe hpa lms-api-hpa
   ```
   Look for: "unable to get metrics" or "no metrics available"

3. **Check Prometheus is scraping**:
   ```bash
   kubectl logs -l app=prometheus | grep "target is down"
   ```

4. **Verify resource requests/limits**:
   ```bash
   kubectl describe deployment lms-api | grep -A 5 "Limits\|Requests"
   ```
   HPA needs resource requests to calculate utilization!

### Not Enough Load?

- Increase concurrent workers: `-c 100` instead of `-c 50`
- Increase duration: `-z 60s` instead of `-z 30s`
- Use a heavier endpoint (if available): `/books/` instead of `/health`

### Pods Not Starting Fast Enough?

- Pre-pull images: `kubectl get pods -l app=lms-api -o yaml | grep image`
- Check node resources: `kubectl top nodes`
- Reduce image size or use cached images

## 💡 Pro Tips

1. **Pre-warm**: Start a light load 30 seconds before demo to warm up metrics
2. **Two terminals**: Use one for load, one for watching
3. **Grafana ready**: Have HPA dashboard open before starting load
4. **Explain while waiting**: Talk about HPA config while pods are scaling
5. **Backup plan**: If live demo fails, show Grafana with historical scaling events

## 📊 What to Show

### In Terminal/ArgoCD:
- Pod count increasing: 2 → 3 → 4 pods
- Pod status changing: Pending → ContainerCreating → Running
- HPA status showing increased replicas

### In Grafana:
- CPU utilization graph rising
- HPA replica count graph showing increase
- Request rate graph showing load
- Pod count metric updating

### In ArgoCD:
- Resource tree showing new pods
- Pod logs showing startup
- Deployment status showing scaling

## ⏱️ Time Management

For a 2-minute demo:
- **20 seconds max** for HPA section
- Start load early (can run in background)
- Show initial state (3s) → Start load (2s) → Show scaling (10s) → Explain (5s)
- If scaling takes too long, show Grafana metrics instead

## ✅ Success Criteria

Demo is successful if:
- [ ] Load generation starts without errors
- [ ] Pods scale up within 30 seconds
- [ ] Can show at least 1 new pod being created
- [ ] HPA status shows increased replicas
- [ ] Can explain what's happening clearly

Even if scaling is slow, you can still:
- Show HPA configuration
- Show metrics in Grafana
- Explain the scaling behavior
- Show historical scaling events

