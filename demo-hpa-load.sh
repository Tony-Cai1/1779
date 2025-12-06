#!/bin/bash
# HPA Load Testing Script for Live Demo
# Generates load to trigger HPA scaling

set -e

# Get API URL
if [ -z "$API_URL" ]; then
    # Try LoadBalancer first (for services with type=LoadBalancer)
    EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$EXTERNAL_IP" ]; then
        API_URL="http://${EXTERNAL_IP}"
    else
        # Try Ingress (nip.io)
        INGRESS_IP=$(kubectl get ingress lms-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$INGRESS_IP" ]; then
            API_URL="http://api.${INGRESS_IP}.nip.io"
            echo "Using Ingress URL: $API_URL"
        else
            # Fallback to port-forward
            echo "No LoadBalancer or Ingress IP found. Using localhost:8000"
            echo "Make sure to run: kubectl port-forward service/lms-api-service 8000:80"
            API_URL="http://localhost:8000"
        fi
    fi
fi

echo "=== HPA Load Testing Demo ==="
echo "API URL: $API_URL"
echo ""

# Test connection first
echo "Testing API connection..."
if ! curl -s -f "$API_URL/health" > /dev/null; then
    echo "ERROR: Cannot reach API at $API_URL"
    echo "Please check:"
    echo "  1. Ingress is configured correctly"
    echo "  2. Pods are running: kubectl get pods -l app=lms-api"
    echo "  3. Service exists: kubectl get svc lms-api-service"
    exit 1
fi
echo "✓ API is reachable"
echo ""

# Check if hey is installed
if ! command -v hey &> /dev/null; then
    echo "ERROR: 'hey' is not installed"
    echo "Install with: go install github.com/rakyll/hey@latest"
    echo "Or download from: https://github.com/rakyll/hey/releases"
    exit 1
fi

# Show initial state
INITIAL_PODS=$(kubectl get pods -l app=lms-api --no-headers 2>/dev/null | grep -c Running || echo "0")
echo "Initial pod count: $INITIAL_PODS"
echo ""

# Show HPA status
echo "HPA Status:"
kubectl get hpa lms-api-hpa
echo ""

# Generate load
echo "Generating load to trigger HPA scaling..."
echo "This will run for 60 seconds with 40 concurrent workers"
echo "Target endpoint: mix of /health (75%) and /books/ (25%)"
echo "Target: Scale pods to handle increased CPU/memory load"
echo ""

# Run multiple hey instances for mixed load
# Main load on /health (30 workers) - keeps pods busy without overwhelming
# Rate limit: ~100 requests/second to avoid 503s
hey -c 30 -q 100 -z 60s "$API_URL/health" > /tmp/hey-health-output.log 2>&1 &
HEY_PID1=$!

# Some load on /books/ (10 workers) - adds database load
# Rate limit: ~30 requests/second for database queries
hey -c 10 -q 30 -z 60s "$API_URL/books/" > /tmp/hey-books-output.log 2>&1 &
HEY_PID2=$!

HEY_PID=$HEY_PID1

# Monitor pods scaling up
echo "Monitoring pod scaling (press Ctrl+C to stop early)..."
echo ""

# Watch pods in real-time
for i in {1..12}; do
    sleep 5
    POD_COUNT=$(kubectl get pods -l app=lms-api --no-headers 2>/dev/null | grep -c Running || echo "0")
    HPA_CURRENT=$(kubectl get hpa lms-api-hpa -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo "N/A")
    HPA_MIN=$(kubectl get hpa lms-api-hpa -o jsonpath='{.spec.minReplicas}' 2>/dev/null || echo "N/A")
    HPA_MAX=$(kubectl get hpa lms-api-hpa -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || echo "N/A")
    # Extract CPU and Memory metrics from HPA
    CPU_METRIC=$(kubectl get hpa lms-api-hpa -o jsonpath='{.status.currentMetrics[?(@.type=="Resource" && @.resource.name=="cpu")].resource.current.averageUtilization}' 2>/dev/null || echo "N/A")
    MEM_METRIC=$(kubectl get hpa lms-api-hpa -o jsonpath='{.status.currentMetrics[?(@.type=="Resource" && @.resource.name=="memory")].resource.current.averageUtilization}' 2>/dev/null || echo "N/A")
    
    # If jsonpath doesn't work, try alternative method
    if [ "$CPU_METRIC" = "N/A" ] || [ -z "$CPU_METRIC" ]; then
        HPA_JSON=$(kubectl get hpa lms-api-hpa -o json 2>/dev/null)
        CPU_METRIC=$(echo "$HPA_JSON" | grep -A 3 '"name": "cpu"' | grep averageUtilization | grep -o '[0-9]*' | head -1 || echo "N/A")
        MEM_METRIC=$(echo "$HPA_JSON" | grep -A 3 '"name": "memory"' | grep averageUtilization | grep -o '[0-9]*' | head -1 || echo "N/A")
    fi
    
    echo "[$((i*5))s] Pods: $POD_COUNT (HPA: $HPA_CURRENT/$HPA_MIN-$HPA_MAX) | CPU: ${CPU_METRIC}% | Memory: ${MEM_METRIC}%"
    
    # Show if scaling occurred
    if [ "$POD_COUNT" -gt "$INITIAL_PODS" ]; then
        echo "  → Scaling detected! Pods increased from $INITIAL_PODS to $POD_COUNT"
    fi
done

# Stop hey processes if still running
if kill -0 $HEY_PID1 2>/dev/null; then
    kill $HEY_PID1 2>/dev/null
fi
if kill -0 $HEY_PID2 2>/dev/null; then
    kill $HEY_PID2 2>/dev/null
fi

echo ""
echo "=== Final Status ==="
echo "Final pod count:"
kubectl get pods -l app=lms-api

echo ""
echo "HPA Status:"
kubectl get hpa lms-api-hpa

echo ""
echo "=== Load Test Summary ==="
if [ -f /tmp/hey-health-output.log ]; then
    echo "Health endpoint statistics:"
    tail -20 /tmp/hey-health-output.log | grep -E "(Total:|Requests/sec|Response time)" || tail -5 /tmp/hey-health-output.log
fi
if [ -f /tmp/hey-books-output.log ]; then
    echo ""
    echo "Books endpoint statistics:"
    tail -20 /tmp/hey-books-output.log | grep -E "(Total:|Requests/sec|Response time)" || tail -5 /tmp/hey-books-output.log
fi

echo ""
echo "Load test complete!"
echo "HPA will scale down pods after load decreases (stabilization window ~5 minutes)"
echo ""
echo "To watch scaling in real-time:"
echo "  watch -n 2 'kubectl get pods -l app=lms-api && kubectl get hpa lms-api-hpa'"


