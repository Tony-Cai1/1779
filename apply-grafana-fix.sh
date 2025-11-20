#!/bin/bash
# Script to apply Grafana dashboard changes and ensure they're picked up

set -e

echo "📝 Step 1: Committing Grafana dashboard changes to Git..."
cd /home/pistach/Documents/code/MEng_Fall/Cloud/1779
git add k8s/grafana-dashboards.yaml
git commit -m "Fix Grafana dashboards: aggregate metrics across pods to remove duplicates" || echo "⚠️  No changes to commit or already committed"

echo ""
echo "📤 Step 2: Pushing to Git (you may need to push manually)..."
echo "   Run: git push origin <your-branch>"
echo ""

echo "🔄 Step 3: Syncing via ArgoCD..."
echo "   Option A: Wait for auto-sync (if enabled)"
echo "   Option B: Manual sync via ArgoCD UI or CLI:"
echo "      argocd app sync lms-api"
echo ""

echo "🔄 Step 4: Restarting Grafana pod to reload ConfigMap..."
kubectl rollout restart deployment/grafana -n default
echo "   Waiting for Grafana to be ready..."
kubectl wait --for=condition=available deployment/grafana --timeout=120s || echo "⚠️  Grafana restart may take longer"
echo ""

echo "✅ Done! Grafana should now show aggregated metrics."
echo "   Access Grafana and refresh the dashboard to see the changes."

