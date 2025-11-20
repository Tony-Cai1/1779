# Remote Kubernetes Cluster Management Guide

This guide explains how to access and manage your DigitalOcean Kubernetes cluster from other machines.

**Important**: This guide is for **managing the Kubernetes cluster** (viewing logs, scaling, debugging). For **code editing and deployment**, see the workflow below.

## Prerequisites

- DigitalOcean account with an existing Kubernetes cluster
- `doctl` CLI installed on the remote machine (or access to cluster kubeconfig)
- `kubectl` installed on the remote machine

## Step 1: Install Required Tools on Remote Machine

### Install kubectl

**macOS**:
```bash
brew install kubectl
```

**Linux**:
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**Windows**:
```powershell
choco install kubernetes-cli
```

### Install doctl (Optional - if you want to manage clusters)

**macOS**:
```bash
brew install doctl
```

**Linux**:
```bash
cd ~
wget https://github.com/digitalocean/doctl/releases/download/v1.104.0/doctl-1.104.0-linux-amd64.tar.gz
tar xf doctl-1.104.0-linux-amd64.tar.gz
sudo mv doctl /usr/local/bin
```

**Windows**:
Download from [GitHub releases](https://github.com/digitalocean/doctl/releases) or use:
```powershell
choco install doctl
```

## Step 2: Configure Access to Your Cluster

### Option A: Using doctl (Recommended)

If you have `doctl` installed and authenticated:

```bash
# Authenticate doctl (one-time setup)
doctl auth init
# Enter your DigitalOcean API token when prompted

# List your clusters
doctl kubernetes cluster list

# Save kubeconfig for your cluster
doctl kubernetes cluster kubeconfig save lms-cluster

# Verify connection
kubectl get nodes
```

### Option B: Export/Import Kubeconfig Manually

If you don't have `doctl` on the remote machine, you can export the kubeconfig from a machine that has access:

**On the machine with cluster access:**

```bash
# Export the kubeconfig
doctl kubernetes cluster kubeconfig save lms-cluster --save-path ~/lms-cluster-kubeconfig.yaml

# Or get it directly
kubectl config view --flatten > ~/lms-cluster-kubeconfig.yaml
```

**Transfer the kubeconfig file securely to your remote machine:**

```bash
# Option 1: Using SCP
scp user@source-machine:~/lms-cluster-kubeconfig.yaml ~/

# Option 2: Using rsync
rsync -avz user@source-machine:~/lms-cluster-kubeconfig.yaml ~/

# Option 3: Copy contents and paste into a file on remote machine
cat ~/lms-cluster-kubeconfig.yaml
```

**On the remote machine:**

```bash
# Set KUBECONFIG environment variable (temporary)
export KUBECONFIG=~/lms-cluster-kubeconfig.yaml

# Or merge with existing kubeconfig
mkdir -p ~/.kube
cp ~/lms-cluster-kubeconfig.yaml ~/.kube/config
# Or merge: KUBECONFIG=~/.kube/config:~/lms-cluster-kubeconfig.yaml kubectl config view --flatten > ~/.kube/config

# Verify connection
kubectl get nodes
```

### Option C: Download Kubeconfig from DigitalOcean Dashboard

1. Go to [DigitalOcean Control Panel](https://cloud.digitalocean.com/kubernetes/clusters)
2. Click on your cluster (`lms-cluster`)
3. Click "Download Config File" or "Show Config"
4. Save the YAML content to `~/.kube/config` on your remote machine

## Step 3: Verify Cluster Access

Test that you can access the cluster:

```bash
# Check cluster connection
kubectl cluster-info

# List nodes
kubectl get nodes

# List all pods
kubectl get pods --all-namespaces

# Check deployments
kubectl get deployments

# Check services
kubectl get services
```

## Step 4: Test the Deployment

### Check Application Status

```bash
# Get all pods in default namespace
kubectl get pods

# Check API deployment status
kubectl get deployment lms-api

# Check service and get external IP
kubectl get service lms-api-service

# Get the LoadBalancer IP
EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "API available at: http://$EXTERNAL_IP"
```

### Test API Endpoints

```bash
# Set the external IP
EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Health check
curl http://$EXTERNAL_IP/health

# List books
curl http://$EXTERNAL_IP/books/ | head -c 500

# Get single book
curl http://$EXTERNAL_IP/books/1

# Test login
curl -X POST "http://$EXTERNAL_IP/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin1&password=admin123"
```

### View Logs

```bash
# View API logs
kubectl logs -f deployment/lms-api

# View logs from a specific pod
kubectl logs <pod-name>

# View PostgreSQL logs
kubectl logs -f deployment/postgres

# View logs from all pods with a label
kubectl logs -l app=lms-api --tail=50
```

### Check Resource Usage

```bash
# Get resource usage for all pods
kubectl top pods

# Get resource usage for nodes
kubectl top nodes

# Describe a pod to see resource requests/limits
kubectl describe pod <pod-name>
```

## Step 5: Common Management Tasks

### Scale the Deployment

```bash
# Scale API to 3 replicas
kubectl scale deployment lms-api --replicas=3

# Check scaling status
kubectl get deployment lms-api

# Scale back down
kubectl scale deployment lms-api --replicas=2
```

### Update the Deployment

```bash
# Restart deployment (pulls new image if imagePullPolicy is Always)
kubectl rollout restart deployment/lms-api

# Check rollout status
kubectl rollout status deployment/lms-api

# View rollout history
kubectl rollout history deployment/lms-api

# Rollback to previous version
kubectl rollout undo deployment/lms-api
```

### Port Forwarding (for Local Testing)

```bash
# Forward API service to localhost
kubectl port-forward service/lms-api-service 8000:80

# In another terminal, test locally
curl http://localhost:8000/health

# Forward PostgreSQL (for database access)
kubectl port-forward service/postgres 5432:5432
```

### Execute Commands in Pods

```bash
# Get a shell in the API pod
kubectl exec -it deployment/lms-api -- sh

# Execute a command in the pod
kubectl exec deployment/lms-api -- python -c "import sys; print(sys.version)"

# Connect to PostgreSQL
kubectl exec -it deployment/postgres -- psql -U lms_user -d lms_db
```

### Update Configuration

```bash
# Edit ConfigMap
kubectl edit configmap lms-config

# Edit Secret (be careful!)
kubectl edit secret lms-secret

# After editing, restart pods to pick up changes
kubectl rollout restart deployment/lms-api
```

### Debugging

```bash
# Describe a pod to see events and status
kubectl describe pod <pod-name>

# Get events in the namespace
kubectl get events --sort-by='.lastTimestamp'

# Check pod status
kubectl get pods -o wide

# View pod logs with timestamps
kubectl logs deployment/lms-api --timestamps
```

## Step 6: Security Best Practices

### Use Contexts for Multiple Clusters

If you manage multiple clusters:

```bash
# List contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>

# Set default namespace
kubectl config set-context --current --namespace=default
```

### Secure Kubeconfig File

```bash
# Set proper permissions on kubeconfig
chmod 600 ~/.kube/config

# Don't commit kubeconfig to version control
echo ".kube/config" >> .gitignore
```

### Use RBAC for Team Access

If you need to give team members access:

1. Create a service account
2. Create a role with appropriate permissions
3. Bind the role to the service account
4. Generate a kubeconfig for the service account

Example:
```bash
# Create service account
kubectl create serviceaccount readonly-user

# Create role (view-only access)
kubectl create role readonly-role --resource=pods,services,deployments --verb=get,list,watch

# Bind role to service account
kubectl create rolebinding readonly-binding --role=readonly-role --serviceaccount=default:readonly-user
```

## Step 7: Monitoring and Alerts

### Set Up Monitoring

```bash
# Install metrics server (if not already installed)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# View resource metrics
kubectl top nodes
kubectl top pods
```

### Check Cluster Health

```bash
# Get cluster information
kubectl cluster-info

# Check node conditions
kubectl get nodes -o wide

# Check for issues
kubectl get events --field-selector type=Warning
```

## Step 8: Backup and Recovery

### Backup Database

```bash
# Create a database backup
kubectl exec deployment/postgres -- pg_dump -U lms_user lms_db > backup-$(date +%Y%m%d).sql

# Or using port forwarding
kubectl port-forward service/postgres 5432:5432 &
pg_dump -h localhost -U lms_user -d lms_db > backup-$(date +%Y%m%d).sql
```

### Export Kubernetes Resources

```bash
# Export all resources
kubectl get all -o yaml > cluster-backup.yaml

# Export specific resources
kubectl get deployment,service,configmap,secret -o yaml > app-backup.yaml
```

## Troubleshooting

### Cannot Connect to Cluster

```bash
# Check kubeconfig
kubectl config view

# Test cluster connection
kubectl cluster-info

# Verify context
kubectl config current-context

# Check if kubeconfig is valid
kubectl get nodes
```

### Authentication Issues

```bash
# If using doctl, re-authenticate
doctl auth init

# Refresh kubeconfig
doctl kubernetes cluster kubeconfig save lms-cluster
```

### Pod Not Starting

```bash
# Check pod status
kubectl get pods

# Describe pod for details
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

## Quick Reference Commands

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes

# Deployments
kubectl get deployments
kubectl describe deployment lms-api
kubectl rollout restart deployment/lms-api
kubectl scale deployment lms-api --replicas=3

# Pods
kubectl get pods
kubectl get pods -o wide
kubectl logs -f deployment/lms-api
kubectl exec -it <pod-name> -- sh

# Services
kubectl get services
kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Config
kubectl get configmap
kubectl get secret
kubectl edit configmap lms-config

# Debugging
kubectl describe pod <pod-name>
kubectl get events
kubectl top pods
kubectl top nodes
```

## Development Workflow from Any Machine

You can develop and deploy from **any machine** - no SSH required! Here's the workflow:

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd 1779
```

### 2. Edit Code Locally

Edit code on your local machine using any editor. No need to SSH anywhere.

### 3. Build and Push Docker Image

From your local machine:

```bash
# Build the image
docker build -t lms-api:latest .

# Tag for DigitalOcean Container Registry
docker tag lms-api:latest registry.digitalocean.com/lms-registry-1779/lms-api:latest

# Push to registry (requires doctl login or docker login)
doctl registry login  # Or: docker login registry.digitalocean.com
docker push registry.digitalocean.com/lms-registry-1779/lms-api:latest
```

### 4. Deploy to Kubernetes

From your local machine (with kubectl configured):

```bash
# Restart deployment to pull new image
kubectl rollout restart deployment/lms-api

# Or update the deployment
cd k8s
kubectl apply -f deployment.yaml
```

### 5. Commit and Push Code Changes

```bash
git add .
git commit -m "Your changes"
git push
```

**Key Points**:
- ✅ Edit code on **any machine** - just clone the repo
- ✅ Build Docker images on **any machine** - push to shared registry
- ✅ Deploy from **any machine** - configure kubectl once
- ✅ No SSH required - everything uses standard tools (git, docker, kubectl)
- ✅ Team members can work independently from their own machines

## Additional Resources

- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [DigitalOcean Kubernetes Documentation](https://docs.digitalocean.com/products/kubernetes/)
- [Kubernetes Official Documentation](https://kubernetes.io/docs/)

