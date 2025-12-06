# HPA Optimization Changes for Better Scaling Demo

## Changes Made

### 1. HPA Threshold Adjustments (`k8s/hpa.yaml`)
- **CPU threshold**: Reduced from 50% → **30%**
- **Memory threshold**: Reduced from 70% → **50%**

**Rationale**: Lower thresholds make scaling trigger more easily during demos, showing the autoscaling capability more effectively.

### 2. Load Test Endpoint Change (`demo-hpa-load.sh`)
- **Old endpoint**: `/health` (lightweight, just returns `{"status": "ok"}`)
- **New endpoint**: `/books` (database query via `crud.list_books(db)`)
- **Concurrency**: Increased from 100 → **150** workers
- **Total requests**: Increased from 20,000 → **30,000**

**Rationale**: The `/books` endpoint performs actual database queries, consuming more CPU and memory resources. This generates realistic load that will push pods over the 30% CPU threshold, triggering HPA scaling.

### 3. Deployment Initial Replicas (`k8s/deployment.yaml`)
- **Replica count**: Reduced from 2 → **1**

**Rationale**: Starting with 1 replica (matching HPA minReplicas) allows the demo to show the full scaling journey from 1 → 5 replicas.

## Expected Behavior

With these changes, when you run `./demo-hpa-load.sh`:

1. **Start**: 1 replica running
2. **15-30 seconds**: CPU usage rises above 30% as database queries accumulate
3. **30-45 seconds**: HPA scales to 3-4 replicas (doubling every 15s per policy)
4. **45-60 seconds**: Should reach 5 replicas (maxReplicas)

## Scaling Policy Reminder

From `hpa.yaml`:
```yaml
scaleUp:
  stabilizationWindowSeconds: 0
  policies:
  - type: Percent
    value: 100        # Double the pods
    periodSeconds: 15 # Every 15 seconds
  - type: Pods
    value: 2          # Or add 2 pods
    periodSeconds: 15
  selectPolicy: Max   # Choose the more aggressive policy
```

This means scaling can happen quickly: 1 → 2 → 4 → 5 (hitting max)

## How to Apply Changes

```bash
# Apply the updated HPA configuration
kubectl apply -f k8s/hpa.yaml

# If you want to reset the deployment to 1 replica immediately
kubectl apply -f k8s/deployment.yaml

# Or scale it manually
kubectl scale deployment lms-api --replicas=1

# Run the optimized load test
./demo-hpa-load.sh
```

## Monitoring

Watch the scaling in real-time:
```bash
watch -n 2 'kubectl get pods -l app=lms-api && echo "" && kubectl get hpa lms-api-hpa'
```

## Reverting to Conservative Settings

If you want production-safe settings after the demo:
- CPU: 50% (was 30%)
- Memory: 70% (was 50%)
- Initial replicas: 2 (was 1)

