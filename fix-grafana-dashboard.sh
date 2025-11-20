#!/bin/bash
# Script to fix Grafana dashboard aggregation issues

set -e

echo "🔧 Fixing Grafana Dashboard Issues..."
echo ""

echo "Step 1: Applying updated Grafana dashboard ConfigMap..."
kubectl apply -f k8s/grafana-dashboards.yaml

echo ""
echo "Step 2: Restarting Grafana pod to reload dashboards..."
kubectl rollout restart deployment/grafana -n default
echo "   Waiting for Grafana to be ready..."
kubectl wait --for=condition=available deployment/grafana --timeout=120s || echo "⚠️  Grafana restart may take longer"

echo ""
echo "Step 3: Checking if metrics are available in Prometheus..."
echo "   Testing if lms_api_requests_total exists..."
POD_NAME=$(kubectl get pods -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POD_NAME" ]; then
    echo "   Prometheus pod found: $POD_NAME"
    echo "   Querying for lms_api_requests_total..."
    kubectl exec -it $POD_NAME -- wget -qO- 'http://localhost:9090/api/v1/query?query=lms_api_requests_total' | head -20 || echo "   ⚠️  Could not query Prometheus"
else
    echo "   ⚠️  Prometheus pod not found"
fi

echo ""
echo "Step 4: Testing suspicious requests metric (will be empty until code is deployed)..."
if [ -n "$POD_NAME" ]; then
    kubectl exec -it $POD_NAME -- wget -qO- 'http://localhost:9090/api/v1/query?query=lms_api_suspicious_requests_total' | head -20 || echo "   ⚠️  Metric doesn't exist yet (normal - needs code deployment)"
fi

echo ""
echo "✅ Done!"
echo ""
echo "📋 Summary:"
echo "   - Dashboard ConfigMap updated"
echo "   - Grafana restarted"
echo ""
echo "📝 Next Steps:"
echo "   1. Check Grafana dashboard - metrics should now be aggregated"
echo "   2. For suspicious requests to show data:"
echo "      - Build and deploy new API image with filtering code"
echo "      - Restart API pods: kubectl rollout restart deployment/lms-api"
echo ""
echo "🔍 To verify metrics in Prometheus UI:"
echo "   kubectl port-forward service/prometheus-service 9090:9090"
echo "   Then open: http://localhost:9090"
echo "   Query: sum without (pod_name, instance, job) (lms_api_requests_total)"

