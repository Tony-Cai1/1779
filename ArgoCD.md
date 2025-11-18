# ArgoCD Continuous Deployment Setup

This document describes how to set up ArgoCD for continuous deployment of the Library Management System (LMS) to Kubernetes clusters.

## Overview

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It automatically syncs your Kubernetes manifests from a Git repository to your cluster, ensuring your cluster state matches your Git repository.

### Key Features

- **GitOps**: Single source of truth in Git
- **Automatic Sync**: Automatically deploys changes from Git
- **Self-Healing**: Automatically corrects manual changes in cluster
- **Multi-Environment**: Support for multiple clusters and environments
- **Rollback**: Easy rollback to previous versions
- **Web UI**: Visual dashboard for application status

## Prerequisites

1. **Kubernetes Cluster**: A running Kubernetes cluster (e.g., DigitalOcean Kubernetes)
2. **kubectl**: Configured to access your cluster
3. **Git Repository**: Your application code in a Git repository (GitHub, GitLab, etc.)
4. **Kubernetes Manifests**: YAML files in your repository (already in `k8s/` directory)

## Installation

### Option 1: Install ArgoCD via kubectl (Recommended)

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### Option 2: Install ArgoCD via Helm

```bash
# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer
```

### Verify Installation

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD services
kubectl get svc -n argocd
```

You should see:
- `argocd-server`: ArgoCD API server and UI
- `argocd-repo-server`: Git repository server
- `argocd-application-controller`: Application controller
- `argocd-redis`: Redis cache

## Access ArgoCD

### Get Initial Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

Save this password - you'll need it to log in.
JMh3okaSmljZlDrS

### Access ArgoCD UI

#### Option 1: Port Forward (Local Access)

```bash
# Port forward to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access UI at: https://localhost:8080
# Username: admin
# Password: (from step above)
```

#### Option 2: LoadBalancer (Public Access)

If you installed with LoadBalancer service type:

```bash
# Get LoadBalancer IP
kubectl get svc argocd-server -n argocd

# Access UI at: https://<EXTERNAL-IP>
# Username: admin
# Password: (from step above)
```

#### Option 3: Ingress (Production - Recommended)

**Important**: If you have multiple services (ArgoCD, Grafana, Prometheus, LMS API), using Ingress is **highly recommended** to:
- Reduce costs (one LoadBalancer instead of multiple)
- Centralize SSL/TLS management
- Enable better routing and security

See `k8s/ingress-setup.md` for a complete guide on setting up Ingress for all your services.

For ArgoCD specifically, set up an Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    # WebSocket support for ArgoCD
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
spec:
  rules:
  - host: argocd.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
  tls:
  - hosts:
    - argocd.yourdomain.com
    secretName: argocd-secret
```

**Note**: A complete Ingress configuration for all services (ArgoCD, Grafana, Prometheus, LMS API) is available in `k8s/ingress.yaml`.

### Access ArgoCD CLI

```bash
# Download ArgoCD CLI
# macOS
brew install argocd

# Linux
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Login via CLI
argocd login localhost:8080  # or your LoadBalancer IP
# Username: admin
# Password: (from step above)
```

## Configure ArgoCD Application

### 1. Update Application Manifest

Edit `k8s/argocd-application.yaml` and update:

```yaml
spec:
  source:
    repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO.git  # Update this
    targetRevision: main  # Update to your default branch
    path: k8s  # Path to Kubernetes manifests
```

### 2. Apply ArgoCD Application

```bash
# Apply the ArgoCD Application manifest
kubectl apply -f k8s/argocd-application.yaml

# Verify application was created
kubectl get applications -n argocd

# Check application status
argocd app get lms-api
```

### 3. Sync Application

ArgoCD will automatically sync if `automated` sync is enabled. To manually sync:

```bash
# Via CLI
argocd app sync lms-api

# Via UI
# Go to ArgoCD UI → Click on lms-api → Click "Sync" button
```

## Application Configuration

The ArgoCD Application manifest (`k8s/argocd-application.yaml`) includes:

### Source Configuration

- **repoURL**: Git repository URL
- **targetRevision**: Branch or tag to sync from
- **path**: Directory containing Kubernetes manifests

### Destination Configuration

- **server**: Kubernetes cluster (use `https://kubernetes.default.svc` for same cluster)
- **namespace**: Target namespace for deployment

### Sync Policy

- **automated**: Automatic sync on Git changes
  - **prune**: Delete resources removed from Git
  - **selfHeal**: Auto-sync if cluster drifts from Git
- **syncOptions**: Additional sync options
  - **CreateNamespace**: Create namespace if missing
  - **PruneLast**: Delete resources last

### Health Checks

ArgoCD monitors:
- Service health
- Deployment readiness
- Pod status

## Workflow: CI/CD Integration

### Complete CI/CD Flow

1. **Developer pushes code** → GitHub
2. **GitHub Actions** (CI):
   - Runs tests
   - Builds Docker image
   - Pushes to container registry
3. **Update Kubernetes manifests** (if needed):
   - Update image tag in `deployment.yaml`
   - Commit and push to Git
4. **ArgoCD detects changes**:
   - Polls Git repository (default: every 3 minutes)
   - Detects changes in `k8s/` directory
   - Automatically syncs to cluster
5. **Deployment**:
   - ArgoCD applies updated manifests
   - Kubernetes rolls out new version
   - Health checks verify deployment

### Automated Image Tag Updates

To automatically update image tags after CI builds:

#### Option 1: Update Manifests in CI

Add to `.github/workflows/ci.yml`:

```yaml
- name: Update deployment image tag
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  run: |
    # Update image tag in deployment.yaml
    sed -i "s|image:.*lms-api:.*|image: ${{ env.REGISTRY }}/${{ env.REGISTRY_NAME }}/${{ env.IMAGE_NAME }}:${{ github.sha }}|g" k8s/deployment.yaml
    git config user.name "github-actions"
    git config user.email "github-actions@github.com"
    git add k8s/deployment.yaml
    git commit -m "Update image tag to ${{ github.sha }}" || exit 0
    git push
```

#### Option 2: Use Image Updater (Advanced)

ArgoCD Image Updater automatically updates image tags:

```bash
# Install Image Updater
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

# Configure in Application manifest
```

## Monitoring and Management

### View Application Status

```bash
# Via CLI
argocd app list
argocd app get lms-api
argocd app history lms-api

# Via UI
# Navigate to ArgoCD UI → Applications → lms-api
```

### View Application Logs

```bash
# ArgoCD application controller logs
kubectl logs -n argocd deployment/argocd-application-controller -f

# Application sync logs
argocd app logs lms-api
```

### Rollback

```bash
# Rollback to previous version
argocd app rollback lms-api

# Rollback to specific revision
argocd app rollback lms-api <revision>
```

### Manual Sync

```bash
# Sync application
argocd app sync lms-api

# Sync with specific options
argocd app sync lms-api --prune --force
```

## Multi-Environment Setup

### Development, Staging, Production

Create separate ArgoCD Applications for each environment:

```yaml
# argocd-app-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: lms-api-dev
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO.git
    targetRevision: develop
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: dev

---
# argocd-app-staging.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: lms-api-staging
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO.git
    targetRevision: staging
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: staging

---
# argocd-app-prod.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: lms-api-prod
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    # Require manual sync approval for production
    syncOptions:
      - CreateNamespace=true
```

## Security Best Practices

### 1. Change Default Password

```bash
# Change admin password
argocd account update-password

# Or via CLI
argocd account update-password --account admin
```

### 2. Create Service Accounts

```bash
# Create service account for CI/CD
argocd account create-service-account ci-cd --name ci-cd

# Generate token
argocd account generate-token --account ci-cd
```

### 3. RBAC Configuration

Configure role-based access control:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:org-admin, applications, *, */*, allow
    p, role:org-admin, clusters, get, *, allow
    p, role:org-admin, repositories, get, *, allow
    p, role:org-admin, repositories, create, *, allow
    p, role:org-admin, repositories, update, *, allow
    p, role:org-admin, repositories, delete, *, allow
    g, admins, role:org-admin
```

### 4. Use Private Repositories

For private Git repositories:

```bash
# Add repository credentials
argocd repo add https://github.com/YOUR_USERNAME/YOUR_REPO.git \
  --username YOUR_USERNAME \
  --password YOUR_TOKEN \
  --type git
```

Or use SSH:

```bash
# Add SSH repository
argocd repo add git@github.com:YOUR_USERNAME/YOUR_REPO.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

## Troubleshooting

### Application Stuck in Syncing

```bash
# Check application status
argocd app get lms-api

# Check for errors
argocd app get lms-api --show-operation

# Force refresh
argocd app get lms-api --refresh
```

### Sync Fails

```bash
# Check application events
kubectl describe application lms-api -n argocd

# Check controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check repo server logs
kubectl logs -n argocd deployment/argocd-repo-server
```

### Authentication Issues

```bash
# Verify repository access
argocd repo list

# Test repository connection
argocd repo get https://github.com/YOUR_USERNAME/YOUR_REPO.git
```

### Resource Conflicts

If resources are out of sync:

```bash
# Hard refresh
argocd app sync lms-api --force

# Or delete and recreate
argocd app delete lms-api
kubectl apply -f k8s/argocd-application.yaml
```

## Advanced Features

### Health Checks

Custom health checks in Application manifest:

```yaml
spec:
  healthChecks:
    - apiVersion: v1
      kind: Service
      name: lms-api-service
      namespace: default
    - apiVersion: apps/v1
      kind: Deployment
      name: lms-api
      namespace: default
```

### Sync Windows

Restrict sync to specific times:

```yaml
spec:
  syncPolicy:
    syncWindows:
      - kind: allow
        schedule: '10 1 * * *'  # Allow sync at 1:10 AM
        duration: 1h
        applications:
          - lms-api
```

### Resource Hooks

Run scripts before/after sync:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pre-sync-job
  annotations:
    argocd.argoproj.io/hook: PreSync
spec:
  template:
    spec:
      containers:
      - name: pre-sync
        image: busybox
        command: ['sh', '-c', 'echo Pre-sync hook']
      restartPolicy: Never
```

## Cleanup

To remove ArgoCD:

```bash
# Delete ArgoCD namespace (removes everything)
kubectl delete namespace argocd

# Or uninstall via Helm
helm uninstall argocd -n argocd
```

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ArgoCD CLI Reference](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/)
- [GitOps Principles](https://www.gitops.tech/)

## Next Steps

1. **Set up GitHub Actions**: See [GitHub_Actions.md](GitHub_Actions.md)
2. **Configure notifications**: Set up alerts for sync failures
3. **Set up multi-cluster**: Deploy to multiple Kubernetes clusters
4. **Implement blue-green deployments**: Use ArgoCD for advanced deployment strategies
5. **Monitor with Prometheus**: Integrate ArgoCD metrics with Prometheus

