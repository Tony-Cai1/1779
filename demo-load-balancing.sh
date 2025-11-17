#!/bin/bash

# Load Balancing and Autoscaling Demo Script
# This script demonstrates load balancing across multiple pods

set -e

echo "=========================================="
echo "Load Balancing and Autoscaling Demo"
echo "=========================================="
echo ""

# Get LoadBalancer external IP
EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
              kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$EXTERNAL_IP" ]; then
  echo "Error: Could not get LoadBalancer IP. Is the service running?"
  exit 1
fi

echo "Application URL: http://$EXTERNAL_IP"
echo ""

# Step 1: Show current pods
echo "=== Step 1: Current Pod Status ==="
kubectl get pods -l app=lms-api
echo ""

# Step 2: Test load balancing with current replicas
echo "=== Step 2: Testing Load Balancing ==="
echo "Sending 20 requests to demonstrate load distribution..."
for i in {1..20}; do
  curl -s http://$EXTERNAL_IP/health > /dev/null
  echo -n "."
done
echo " Done!"
echo ""

# Step 3: Scale up
echo "=== Step 3: Scaling Up ==="
echo "Scaling to 5 replicas..."
kubectl scale deployment lms-api --replicas=5
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=lms-api --timeout=60s || true
echo ""

echo "Current pods after scaling:"
kubectl get pods -l app=lms-api
echo ""

# Step 4: Test load balancing with more replicas
echo "=== Step 4: Testing Load Distribution Across 5 Pods ==="
echo "Sending 30 requests to demonstrate distribution across more pods..."
for i in {1..30}; do
  curl -s http://$EXTERNAL_IP/health > /dev/null
  echo -n "."
done
echo " Done!"
echo ""

# Step 5: Show resource usage (if metrics-server is available)
if kubectl top pods -l app=lms-api 2>/dev/null; then
  echo ""
  echo "=== Resource Usage ==="
  kubectl top pods -l app=lms-api
  echo ""
fi

# Step 6: Scale back down
echo "=== Step 5: Scaling Back Down ==="
echo "Scaling back to 2 replicas..."
kubectl scale deployment lms-api --replicas=2
echo "Waiting for scaling to complete..."
sleep 5
echo ""

echo "Final pod status:"
kubectl get pods -l app=lms-api
echo ""

echo "=========================================="
echo "Demo Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Set up HPA: kubectl apply -f k8s/hpa.yaml"
echo "  2. Generate load: hey -z 2m -c 20 http://$EXTERNAL_IP/health"
echo "  3. Watch autoscaling: kubectl get hpa -w"
echo ""

