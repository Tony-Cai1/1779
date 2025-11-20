#!/bin/bash
# HPA Load Testing Script for Live Demo
# Generates load to trigger HPA scaling

set -e

# Get API URL
if [ -z "$API_URL" ]; then
    # Try LoadBalancer first
    EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$EXTERNAL_IP" ]; then
        API_URL="http://${EXTERNAL_IP}"
    else
        # Fallback to port-forward
        echo "No LoadBalancer IP found. Using localhost:8000"
        echo "Make sure to run: kubectl port-forward service/lms-api-service 8000:80"
        API_URL="http://localhost:8000"
    fi
fi

echo "=== HPA Load Testing Demo ==="
echo "API URL: $API_URL"
echo ""

# Check if hey is installed
if ! command -v hey &> /dev/null; then
    echo "ERROR: 'hey' is not installed"
    echo "Install with: go install github.com/rakyll/hey@latest"
    echo "Or download from: https://github.com/rakyll/hey/releases"
    exit 1
fi

# Show initial state
echo "Initial pod count:"
kubectl get pods -l app=lms-api --no-headers | wc -l
echo ""

# Show HPA status
echo "HPA Status:"
kubectl get hpa lms-api-hpa
echo ""

# Generate load
echo "Generating load to trigger HPA scaling..."
echo "This will run for 60 seconds with 50 concurrent workers"
echo ""

# Run hey in background and capture PID
hey -n 10000 -c 100 -z 10s "$API_URL/health" > /tmp/hey-output.log 2>&1 &
HEY_PID=$!

# Monitor pods scaling up
echo "Monitoring pod scaling (press Ctrl+C to stop early)..."
echo ""

# Watch pods in real-time
for i in {1..12}; do
    sleep 5
    POD_COUNT=$(kubectl get pods -l app=lms-api --no-headers 2>/dev/null | grep -c Running || echo "0")
    HPA_STATUS=$(kubectl get hpa lms-api-hpa -o jsonpath='{.status.currentReplicas}/{.spec.minReplicas}-{.spec.maxReplicas}' 2>/dev/null || echo "N/A")
    CPU_METRIC=$(kubectl get hpa lms-api-hpa -o jsonpath='{.status.currentMetrics[?(@.type=="Resource")].resource.current.averageUtilization}' 2>/dev/null || echo "N/A")
    
    echo "[$((i*5))s] Pods: $POD_COUNT | HPA: $HPA_STATUS | CPU: ${CPU_METRIC}%"
done

# Stop hey if still running
if kill -0 $HEY_PID 2>/dev/null; then
    kill $HEY_PID 2>/dev/null
fi

echo ""
echo "=== Final Status ==="
echo "Final pod count:"
kubectl get pods -l app=lms-api

echo ""
echo "HPA Status:"
kubectl get hpa lms-api-hpa

echo ""
echo "Load test complete!"
echo "Watch pods scale down after 60 seconds (HPA stabilization window)"


