#!/bin/bash

# Deployment script for Library Management System on Kubernetes
# Usage: ./deploy.sh [--skip-postgres] [--seed]

set -e

SKIP_POSTGRES=false
RUN_SEED=false  # Changed: seeding is now opt-in, not opt-out

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-postgres)
      SKIP_POSTGRES=true
      shift
      ;;
    --seed)
      RUN_SEED=true  # Opt-in flag to run seeding
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--skip-postgres] [--seed]"
      echo "  --skip-postgres: Skip PostgreSQL deployment (use external DB)"
      echo "  --seed: Run database seeding job (creates sample data)"
      exit 1
      ;;
  esac
done

echo "🚀 Deploying Library Management System to Kubernetes..."

# Step 1: Create ConfigMap
echo "📝 Creating ConfigMap..."
kubectl apply -f configmap.yaml

# Step 2: Create Secret
echo "🔐 Creating Secret..."
kubectl apply -f secret.yaml

# Step 3: Deploy PostgreSQL (if not skipped)
if [ "$SKIP_POSTGRES" = false ]; then
  echo "🐘 Deploying PostgreSQL..."
  kubectl apply -f postgres-deployment.yaml
  
  echo "⏳ Waiting for PostgreSQL to be ready..."
  kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s || {
    echo "❌ PostgreSQL failed to start. Check logs with: kubectl logs -f deployment/postgres"
    exit 1
  }
  echo "✅ PostgreSQL is ready!"
else
  echo "⏭️  Skipping PostgreSQL deployment (using external database)"
fi

# Step 4: Deploy API
echo "🚀 Deploying API..."
kubectl apply -f deployment.yaml

# Step 5: Create Service
echo "🌐 Creating Service..."
kubectl apply -f service.yaml

# Step 6: Wait for API to be ready
echo "⏳ Waiting for API to be ready..."
kubectl wait --for=condition=available deployment/lms-api --timeout=300s || {
  echo "❌ API deployment failed. Check logs with: kubectl logs -f deployment/lms-api"
  exit 1
}
echo "✅ API is ready!"

# Step 7: Seed database (if requested)
if [ "$RUN_SEED" = true ]; then
  echo "🌱 Seeding database with sample data..."
  kubectl apply -f job-seed.yaml
  
  echo "⏳ Waiting for seed job to complete..."
  kubectl wait --for=condition=complete job/lms-seed --timeout=300s || {
    echo "⚠️  Seed job may have failed. Check logs with: kubectl logs job/lms-seed"
  }
  echo "✅ Database seeded with sample data!"
  echo "   Default credentials: admin1/admin123, member1-20/member123"
else
  echo "⏭️  Skipping database seeding (use --seed flag to populate sample data)"
fi

# Step 8: Get service endpoint
echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📊 Deployment Status:"
kubectl get pods -l app=lms-api
kubectl get service lms-api-service

echo ""
echo "🔗 Service Endpoint:"
EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$EXTERNAL_IP" ]; then
  echo "   Service is being provisioned. Check status with: kubectl get service lms-api-service"
else
  echo "   http://$EXTERNAL_IP"
fi

echo ""
echo "📝 Useful commands:"
echo "   View API logs: kubectl logs -f deployment/lms-api"
echo "   Port forward: kubectl port-forward service/lms-api-service 8000:80"
echo "   Check pods: kubectl get pods"
echo "   Check services: kubectl get services"

