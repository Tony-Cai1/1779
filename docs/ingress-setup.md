# Ingres Setup Guide

This guide explains how to set up Ingress for all your services (LMS API, Grafana, Prometheus, ArgoCD) to replace multiple LoadBalancers with a single, cost-effective solution.

## Quick Start (Using nip.io - No Domain Required)

**For development/testing, use nip.io - it's free and requires no setup!**

1. Install Ingress Controller (Step 1)
2. Update services to ClusterIP (Step 3)
3. Get your Ingress IP and use `k8s/ingress-nipio-example.yaml` (Step 4, Option A)
4. Deploy and access via `http://api.YOUR_IP.nip.io` (Steps 5-6)

**Skip Step 2 (cert-manager) - it's only needed for real domains with SSL!**

## Why Use Ingress?

### Current Setup (Without Ingress)
- **LMS API**: 1 LoadBalancer ($10-20/month)
- **Grafana**: 1 LoadBalancer ($10-20/month)
- **Prometheus**: 1 LoadBalancer ($10-20/month)
- **ArgoCD**: 1 LoadBalancer ($10-20/month)
- **Total**: ~$40-80/month

### With Ingress
- **Ingress Controller**: 1 LoadBalancer ($10-20/month)
- **All services**: Route through Ingress (free)
- **Total**: ~$10-20/month
- **Savings**: ~$30-60/month

### Additional Benefits
- ✅ Centralized SSL/TLS management
- ✅ Path-based and hostname-based routing
- ✅ Better security (rate limiting, authentication)
- ✅ Easier to manage multiple services
- ✅ Production-ready setup

## Prerequisites

1. **Kubernetes cluster** with kubectl access
2. **Domain name** (optional - only needed for production with SSL):
   - For development/testing: Use **nip.io** (free, no setup required)
   - For production: Use a real domain name for SSL/TLS certificates

## Step 1: Install NGINX Ingress Controller

### For DigitalOcean Kubernetes

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s
```

### Alternative: Using Helm

```bash
# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### Verify Installation

```bash
# Check Ingress Controller pods
kubectl get pods -n ingress-nginx

# Get LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

## Step 2: Install cert-manager (Optional - Only for Real Domains with SSL)

**Skip this step if using nip.io!** cert-manager is only needed when using real domain names with SSL/TLS certificates.

If you plan to use a real domain name (e.g., `api.yourdomain.com`) with HTTPS, install cert-manager:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=300s
```

### Create ClusterIssuer for Let's Encrypt

```bash
# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # Change this!
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

**Important**: Update the email address in the ClusterIssuer!

## Step 3: Update Services to ClusterIP

Change all your LoadBalancer services to ClusterIP so they're only accessible through Ingress.

### Update LMS API Service

```bash
# Edit service.yaml
kubectl patch svc lms-api-service -p '{"spec":{"type":"ClusterIP"}}'
```

Or manually edit `k8s/service.yaml`:
```yaml
spec:
  type: ClusterIP  # Changed from LoadBalancer
```

### Update Grafana Service

```bash
# Edit grafana-deployment.yaml service section
kubectl patch svc grafana-service -p '{"spec":{"type":"ClusterIP"}}'
```

Or edit `k8s/grafana-deployment.yaml`:
```yaml
spec:
  type: ClusterIP  # Changed from LoadBalancer
```

### Update Prometheus Service

```bash
# Edit prometheus-deployment.yaml service section
kubectl patch svc prometheus-service -p '{"spec":{"type":"ClusterIP"}}'
```

Or edit `k8s/prometheus-deployment.yaml`:
```yaml
spec:
  type: ClusterIP  # Changed from LoadBalancer
```

### ArgoCD Service

ArgoCD service is typically already ClusterIP, but verify:
```bash
kubectl get svc argocd-server -n argocd
```

## Step 4: Configure Ingress

### Option A: Using nip.io (Recommended for Development/Testing)

**This is the easiest option - no domain registration needed!**

1. **Get your Ingress LoadBalancer IP**:
   ```bash
   # Get Ingress LoadBalancer IP
   INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   echo "Ingress IP: $INGRESS_IP"
   ```

2. **Use the nip.io example file**:
   ```bash
   # Copy the example file
   cp k8s/ingress-nipio-example.yaml k8s/ingress-nipio.yaml
   
   # Replace 123.45.67.89 with your actual IP
   sed -i "s/123.45.67.89/$INGRESS_IP/g" k8s/ingress-nipio.yaml
   ```

   Or manually edit `k8s/ingress-nipio-example.yaml` and replace `123.45.67.89` with your Ingress IP.

3. **Your services will be accessible at**:
   - `http://api.YOUR_IP.nip.io`
   - `http://grafana.YOUR_IP.nip.io`
   - `http://prometheus.YOUR_IP.nip.io`
   - `http://argocd.YOUR_IP.nip.io`

   **Note**: nip.io automatically resolves any subdomain containing an IP to that IP address.

### Option B: Using Real Domain Names (Production)

**Only use this if you have a real domain name and want SSL/TLS certificates.**

1. **Update `k8s/ingress.yaml`** with your domain names:
   ```yaml
   - host: api.yourdomain.com
   - host: grafana.yourdomain.com
   - prometheus.yourdomain.com
   - argocd.yourdomain.com
   ```

2. **Point DNS records** to Ingress LoadBalancer IP:
   ```bash
   # Get Ingress LoadBalancer IP
   INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   echo "Ingress IP: $INGRESS_IP"
   ```

   Create DNS A records in your domain registrar:
   - `api.yourdomain.com` → `INGRESS_IP`
   - `grafana.yourdomain.com` → `INGRESS_IP`
   - `prometheus.yourdomain.com` → `INGRESS_IP`
   - `argocd.yourdomain.com` → `INGRESS_IP`

3. **Make sure cert-manager is installed** (Step 2) for automatic SSL certificates.

## Step 5: Deploy Ingress

### For nip.io (Recommended)

```bash
# Apply nip.io Ingress configuration
kubectl apply -f k8s/ingress-nipio.yaml

# Verify Ingress
kubectl get ingress

# Check Ingress details
kubectl describe ingress lms-ingress
```

### For Real Domain Names

```bash
# Apply Ingress configuration
kubectl apply -f k8s/ingress.yaml

# Verify Ingress
kubectl get ingress

# Check Ingress details
kubectl describe ingress lms-ingress
```

## Step 6: Verify Access

### With nip.io (Recommended for Testing)

```bash
# Get your Ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test API
curl http://api.$INGRESS_IP.nip.io/health

# Test Grafana (in browser)
open http://grafana.$INGRESS_IP.nip.io

# Test Prometheus (in browser)
open http://prometheus.$INGRESS_IP.nip.io

# Test ArgoCD (in browser)
open http://argocd.$INGRESS_IP.nip.io
```

**Example**: If your IP is `157.230.123.45`, access:
- `http://api.157.230.123.45.nip.io`
- `http://grafana.157.230.123.45.nip.io`
- `http://prometheus.157.230.123.45.nip.io`
- `http://argocd.157.230.123.45.nip.io`

### With Real Domain Names (Production)

```bash
# Test API
curl https://api.yourdomain.com/health

# Test Grafana (in browser)
open https://grafana.yourdomain.com

# Test Prometheus
open https://prometheus.yourdomain.com

# Test ArgoCD
open https://argocd.yourdomain.com
```

## Advanced Configuration

### Path Rewriting for Grafana

If using paths instead of subdomains, Grafana needs path rewriting:

```yaml
- host: yourdomain.com
  http:
    paths:
    - path: /grafana
      pathType: Prefix
      backend:
        service:
          name: grafana-service
          port:
            number: 3000
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
        nginx.ingress.kubernetes.io/configuration-snippet: |
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
```

### Basic Authentication (Optional)

Add basic auth to protect Prometheus:

```bash
# Create auth file
htpasswd -c auth prometheus
# Enter password when prompted

# Create secret
kubectl create secret generic prometheus-basic-auth \
  --from-file=auth \
  -n default

# Add annotation to Ingress
nginx.ingress.kubernetes.io/auth-type: basic
nginx.ingress.kubernetes.io/auth-secret: prometheus-basic-auth
nginx.ingress.kubernetes.io/auth-realm: 'Prometheus Authentication Required'
```

### Rate Limiting

Already configured in `ingress.yaml`:
```yaml
nginx.ingress.kubernetes.io/limit-rps: "100"
```

Adjust as needed per service.

## Troubleshooting

### Ingress Not Working

```bash
# Check Ingress Controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check Ingress resource
kubectl describe ingress lms-ingress

# Check services
kubectl get svc
```

### SSL Certificate Issues (Only for Real Domains)

If using real domains and having SSL issues:

```bash
# Check cert-manager
kubectl get certificates
kubectl describe certificate lms-tls-secret

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

**Note**: SSL/TLS doesn't work with nip.io - use HTTP only.

### DNS Not Resolving

For nip.io, DNS should work automatically. If it doesn't:

```bash
# Test nip.io resolution
nslookup api.157.230.123.45.nip.io

# Should return: 157.230.123.45
```

For real domains:

```bash
# Verify DNS records
dig api.yourdomain.com

# Test with curl
curl -v https://api.yourdomain.com/health
```

### Services Not Accessible

```bash
# Verify services are ClusterIP
kubectl get svc

# Test service endpoints
kubectl get endpoints

# Port forward to test service directly
kubectl port-forward svc/lms-api-service 8000:80
curl http://localhost:8000/health
```

## Security Considerations

1. **Keep Prometheus Internal**: Consider not exposing Prometheus publicly. Use port-forward for access:
   ```bash
   kubectl port-forward svc/prometheus-service 9090:9090
   ```

2. **Use Authentication**: Add basic auth or OAuth for sensitive services

3. **Network Policies**: Restrict access between services

4. **TLS Only**: Force HTTPS redirect (only for real domains with cert-manager)

## Cost Comparison

### Before (Multiple LoadBalancers)
- LMS API: $12/month
- Grafana: $12/month
- Prometheus: $12/month
- ArgoCD: $12/month
- **Total: $48/month**

### After (Single Ingress)
- Ingress Controller: $12/month
- **Total: $12/month**
- **Savings: $36/month ($432/year)**

## Next Steps

1. **Update ArgoCD Application**: Include `ingress.yaml` in your ArgoCD sync
2. **Monitor**: Set up alerts for Ingress controller
3. **Backup**: Document your Ingress configuration
4. **Optimize**: Fine-tune rate limits and timeouts

## Additional Resources

- [NGINX Ingress Controller Docs](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Docs](https://cert-manager.io/docs/)
- [Kubernetes Ingress Docs](https://kubernetes.io/docs/concepts/services-networking/ingress/)

