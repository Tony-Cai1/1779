# Load Balancing and Autoscaling Demo Guide

This guide demonstrates load balancing and autoscaling capabilities of the Library Management System deployed on Kubernetes.

## Prerequisites

- Kubernetes cluster running
- Application deployed (see main README.md)
- LoadBalancer service with external IP
- `kubectl` configured and authenticated

## Step 1: Get Your Application URL

```bash
# Get the LoadBalancer external IP
EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Application URL: http://$EXTERNAL_IP"

# Or if using hostname
EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

## Step 2: Demonstrate Load Balancing

### 2.1 Check Current Pods

```bash
# View running pods (should see 2 replicas by default)
kubectl get pods -l app=lms-api

# Get pod names for testing
kubectl get pods -l app=lms-api -o name
```

### 2.2 Add Pod Hostname to Response (Optional)

To better visualize which pod handles each request, you can temporarily add a `/hostname` endpoint or check logs.

### 2.3 Send Traffic to Test Load Balancing

**Option A: Using curl in a loop**

```bash
# Send 10 requests and see which pods handle them
for i in {1..10}; do
  echo "Request $i:"
  curl -s http://$EXTERNAL_IP/health
  echo ""
  sleep 1
done
```

**Option B: Watch logs from multiple pods**

Open multiple terminals:

```bash
# Terminal 1: Watch first pod logs
POD1=$(kubectl get pods -l app=lms-api -o jsonpath='{.items[0].metadata.name}')
kubectl logs -f $POD1

# Terminal 2: Watch second pod logs  
POD2=$(kubectl get pods -l app=lms-api -o jsonpath='{.items[1].metadata.name}')
kubectl logs -f $POD2

# Terminal 3: Send requests
for i in {1..20}; do
  curl -s http://$EXTERNAL_IP/health > /dev/null
  echo "Sent request $i"
  sleep 0.5
done
```

You should see requests distributed across both pods in the log terminals.

**Option C: Generate Load with Apache Bench**

```bash
# Install Apache Bench if needed (apt-get install apache2-utils on Debian/Ubuntu)
ab -n 100 -c 10 http://$EXTERNAL_IP/health

# Or using hey (install: go install github.com/rakyll/hey@latest)
hey -n 100 -c 10 http://$EXTERNAL_IP/health
```

### 2.4 Verify Traffic Distribution

```bash
# Check request counts per pod (requires metrics server or manual counting from logs)
kubectl top pods -l app=lms-api

# Or manually count from logs
kubectl logs <pod-name> | grep -c "GET /health"
```

## Step 3: Demonstrate Manual Scaling

### 3.1 Scale Up

```bash
# Scale to 3 replicas
kubectl scale deployment lms-api --replicas=3

# Watch pods being created
kubectl get pods -l app=lms-api -w

# Verify all pods are ready
kubectl get pods -l app=lms-api
```

### 3.2 Test Load Distribution Across More Pods

```bash
# Send requests - now distributed across 3 pods
for i in {1..15}; do
  curl -s http://$EXTERNAL_IP/health > /dev/null
  echo "Request $i sent"
done

# Check all pods received traffic
kubectl get pods -l app=lms-api
```

### 3.3 Scale Down

```bash
# Scale back to 2 replicas
kubectl scale deployment lms-api --replicas=2

# Watch pods being terminated
kubectl get pods -l app=lms-api -w
```

### 3.4 Scale Up to Maximum

```bash
# Scale to 5 replicas for demo
kubectl scale deployment lms-api --replicas=5

# Verify all pods are running
kubectl get pods -l app=lms-api
```

## Step 4: Set Up Horizontal Pod Autoscaler (HPA)

### 4.1 Create HPA Resource

Create a file `k8s/hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: lms-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: lms-api
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 15
      selectPolicy: Max
```

### 4.2 Deploy HPA

```bash
kubectl apply -f k8s/hpa.yaml

# Verify HPA is created
kubectl get hpa

# Watch HPA status
kubectl get hpa -w
```

**Note**: HPA requires metrics-server to be installed. For DigitalOcean Kubernetes:

```bash
# Check if metrics-server is installed
kubectl top nodes

# If not installed, DigitalOcean should have it by default, or install:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 4.3 Generate Load to Trigger Autoscaling

**Option A: Using hey or Apache Bench**

```bash
# Generate sustained load (in another terminal)
hey -z 2m -c 20 http://$EXTERNAL_IP/health

# Watch HPA scale up
kubectl get hpa -w
kubectl get pods -l app=lms-api -w
```

**Option B: Using a loop with curl**

```bash
# Generate load for 2 minutes
end=$((SECONDS+120))
while [ $SECONDS -lt $end ]; do
  for i in {1..10}; do
    curl -s http://$EXTERNAL_IP/health > /dev/null &
  done
  wait
  sleep 0.1
done
```

### 4.4 Monitor Autoscaling

```bash
# Terminal 1: Watch HPA
watch -n 1 kubectl get hpa

# Terminal 2: Watch pods
watch -n 1 kubectl get pods -l app=lms-api

# Terminal 3: Watch metrics
watch -n 1 kubectl top pods -l app=lms-api
```

You should see:
- HPA target metrics increase
- New pods being created
- Pod count increase toward maxReplicas

### 4.5 Observe Scale Down

After stopping the load generator:

```bash
# Watch HPA scale down (may take a few minutes due to stabilization window)
kubectl get hpa -w
kubectl get pods -l app=lms-api -w
```

## Step 5: Advanced Demo - Pod Disruption

### 5.1 Simulate Pod Failure

```bash
# Delete a pod to demonstrate automatic replacement
POD_TO_DELETE=$(kubectl get pods -l app=lms-api -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD_TO_DELETE

# Watch new pod being created automatically
kubectl get pods -l app=lms-api -w

# Verify service still works (should get responses from remaining pods)
curl http://$EXTERNAL_IP/health
```

### 5.2 Rolling Update During Load

```bash
# Start load generator in background
hey -z 5m -c 10 http://$EXTERNAL_IP/health &

# Trigger a rolling update (e.g., change image or restart)
kubectl rollout restart deployment/lms-api

# Watch rolling update (pods replace one at a time)
kubectl rollout status deployment/lms-api

# Service remains available during update
watch curl -s http://$EXTERNAL_IP/health
```

## Step 6: Cleanup After Demo

```bash
# Remove HPA (optional, to stop autoscaling)
kubectl delete hpa lms-api-hpa

# Scale back to default
kubectl scale deployment lms-api --replicas=2

# Verify final state
kubectl get pods -l app=lms-api
kubectl get service lms-api-service
```

## Quick Demo Script

Save this as `demo-load-balancing.sh`:

```bash
#!/bin/bash

EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "=== Load Balancing Demo ==="
echo "Application URL: http://$EXTERNAL_IP"
echo ""
echo "Current pods:"
kubectl get pods -l app=lms-api

echo ""
echo "Sending 20 requests..."
for i in {1..20}; do
  curl -s http://$EXTERNAL_IP/health > /dev/null
  echo -n "."
done
echo " Done!"

echo ""
echo "Scaling to 5 replicas..."
kubectl scale deployment lms-api --replicas=5
sleep 5

echo "Current pods:"
kubectl get pods -l app=lms-api

echo ""
echo "Sending 30 requests across 5 pods..."
for i in {1..30}; do
  curl -s http://$EXTERNAL_IP/health > /dev/null
  echo -n "."
done
echo " Done!"

echo ""
echo "Scaling back to 2 replicas..."
kubectl scale deployment lms-api --replicas=2

echo ""
echo "Demo complete!"
```

Make it executable and run:
```bash
chmod +x demo-load-balancing.sh
./demo-load-balancing.sh
```

## Troubleshooting

### HPA Not Scaling

1. **Check metrics-server**:
   ```bash
   kubectl top nodes
   kubectl top pods
   ```

2. **Check HPA events**:
   ```bash
   kubectl describe hpa lms-api-hpa
   ```

3. **Verify resource requests/limits** in deployment.yaml

### LoadBalancer IP Not Assigned

```bash
# Check service status
kubectl describe service lms-api-service

# May take 1-2 minutes on DigitalOcean
```

### Pods Not Receiving Traffic

```bash
# Check service endpoints
kubectl get endpoints lms-api-service

# Verify pod labels match service selector
kubectl get pods --show-labels
kubectl get service lms-api-service -o yaml | grep selector
```

## Tips for Live Demo

1. **Prepare beforehand**: Have all terminals open and commands ready
2. **Use visual tools**: Consider using `watch` or `k9s` for better visualization
3. **Explain each step**: Describe what's happening as pods scale
4. **Show LoadBalancer**: Highlight that traffic is distributed automatically
5. **Demo resilience**: Delete a pod to show automatic recovery
6. **Monitor metrics**: Use `kubectl top` to show resource usage

## Next Steps

- Configure HPA with custom metrics (requests per second, queue depth, etc.)
- Set up Cluster Autoscaler for node-level scaling
- Implement pod disruption budgets for high availability
- Add service mesh (Istio/Linkerd) for advanced traffic management

