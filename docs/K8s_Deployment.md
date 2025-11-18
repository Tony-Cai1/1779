# Kubernetes Deployment Guide

This directory contains Kubernetes manifests for deploying the Library Management System.

## Files

- `configmap.yaml` - Non-sensitive configuration (database host, port, etc.)
- `secret.yaml` - Sensitive data (passwords, secret keys) - **UPDATE BEFORE DEPLOYING**
- `deployment.yaml` - API application deployment
- `service.yaml` - LoadBalancer service for external access
- `postgres-deployment.yaml` - PostgreSQL database deployment (optional if using managed DB)
- `job-seed.yaml` - Optional one-time job to seed the database with sample data
- `deploy.sh` - Automated deployment script

## Quick Start

### Prerequisites

1. **Update secrets**: Edit `secret.yaml` with production values:
   ```bash
   # Generate a secure secret key
   openssl rand -hex 32
   ```

2. **Update image registry**: Edit `deployment.yaml` and `job-seed.yaml`:
   - Replace `your-registry/lms-api:latest` with your actual image registry

### Deploy Everything

```bash
cd k8s
./deploy.sh
```

This will deploy the application without seeding. The database schema (tables) is created automatically by PostgreSQL's init script.

### Deploy With Sample Data Seeding

To populate the database with test users, books, and transactions:

```bash
cd k8s
./deploy.sh --seed
```

### Deploy Without PostgreSQL (Using External DB)

```bash
./deploy.sh --skip-postgres
```

You can combine flags:
```bash
./deploy.sh --skip-postgres --seed  # Use external DB and seed it
```

## Manual Deployment Steps

If you prefer to deploy manually:

```bash
# 1. Create ConfigMap and Secret
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml

# 2. Deploy PostgreSQL (optional)
kubectl apply -f postgres-deployment.yaml
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s

# 3. Deploy API
kubectl apply -f deployment.yaml

# 4. Create Service
kubectl apply -f service.yaml

# 5. (Optional) Seed database with sample data
kubectl apply -f job-seed.yaml
```

## DigitalOcean Specific Notes

### Image Pull Secrets

When using DigitalOcean Container Registry (DOCR), you need to configure image pull secrets:

1. **Create the image pull secret**:
   ```bash
   doctl registry kubernetes-manifest | kubectl apply -f -
   ```

2. **Update the secret name in manifests**:
   - The secret name format is `registry-{registry-name}`
   - Update `k8s/deployment.yaml` and `k8s/job-seed.yaml` to use your registry secret name
   - Example: If your registry is `lms-registry`, the secret name is `registry-lms-registry`

3. **Verify the secret exists**:
   ```bash
   kubectl get secrets | grep registry
   ```

### Using External Database (Optional)

If you want to use DigitalOcean Managed Database instead of the in-cluster PostgreSQL:

1. **Create a managed PostgreSQL database** in DigitalOcean dashboard

2. **Get connection details** and update ConfigMap:
   ```bash
   kubectl edit configmap lms-config
   # Update DB_HOST to your managed database host
   ```

3. **Update the secret** with the managed database password:
   ```bash
   kubectl edit secret lms-secret
   # Update DB_PASSWORD
   ```

4. **Deploy without PostgreSQL**:
   ```bash
   ./deploy.sh --skip-postgres
   ```

## Updating Secrets

To update secrets after initial deployment:

```bash
# Edit secret.yaml with new values
kubectl apply -f secret.yaml

# Restart pods to pick up new secrets
kubectl rollout restart deployment/lms-api
```

## Scaling

Scale the API deployment:

```bash
kubectl scale deployment lms-api --replicas=3
```

## Rolling Updates

Update the image:

```bash
# Update deployment.yaml with new image tag
kubectl apply -f deployment.yaml

# Or patch directly
kubectl set image deployment/lms-api api=your-registry/lms-api:v2.0.0
```

## Troubleshooting

### View Logs

```bash
# API logs
kubectl logs -f deployment/lms-api

# PostgreSQL logs
kubectl logs -f deployment/postgres

# Seed job logs
kubectl logs job/lms-seed
```

### Check Pod Status

```bash
kubectl get pods
kubectl describe pod <pod-name>
```

### Debug Database Connection

```bash
# Get API pod name
API_POD=$(kubectl get pod -l app=lms-api -o jsonpath='{.items[0].metadata.name}')

# Test database connection
kubectl exec $API_POD -- sh -c 'pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER'
```

### Port Forward for Testing

```bash
# Forward API to localhost
kubectl port-forward service/lms-api-service 8000:80

# Forward PostgreSQL (for debugging)
kubectl port-forward service/postgres 5432:5432
```

## Cleanup

To remove all resources:

```bash
kubectl delete -f .
```

Or delete specific resources:

```bash
kubectl delete deployment lms-api
kubectl delete service lms-api-service
kubectl delete deployment postgres
kubectl delete pvc postgres-pvc
kubectl delete configmap lms-config
kubectl delete secret lms-secret
```

