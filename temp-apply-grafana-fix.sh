#!/bin/bash
# Temporary workaround: Apply Grafana dashboard changes without committing to Git
# WARNING: ArgoCD will revert these changes if selfHeal is enabled!
# This is only for testing. For permanent changes, commit to Git.

set -e

echo "⚠️  WARNING: This is a temporary workaround."
echo "   ArgoCD will revert these changes if selfHeal is enabled."
echo "   For permanent changes, commit to Git instead."
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo ""
echo "📝 Step 1: Temporarily disabling ArgoCD self-heal for ConfigMaps..."
kubectl patch application lms-api -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false}}}}' || {
    echo "⚠️  Could not disable self-heal. You may need to do this manually in ArgoCD UI."
    echo "   Or the application might be in a different namespace."
}

echo ""
echo "📦 Step 2: Applying updated Grafana dashboard ConfigMap..."
kubectl apply -f k8s/grafana-dashboards.yaml

echo ""
echo "🔄 Step 3: Restarting Grafana pod to reload ConfigMap..."
kubectl rollout restart deployment/grafana -n default
echo "   Waiting for Grafana to be ready..."
kubectl wait --for=condition=available deployment/grafana --timeout=120s || echo "⚠️  Grafana restart may take longer"

echo ""
echo "✅ Done! Grafana should now show aggregated metrics."
echo ""
echo "⚠️  REMINDER: Re-enable self-heal in ArgoCD when done testing:"
echo "   kubectl patch application lms-api -n argocd --type merge -p '{\"spec\":{\"syncPolicy\":{\"automated\":{\"selfHeal\":true}}}}'"
echo ""
echo "   Or commit the changes to Git for a permanent solution."

