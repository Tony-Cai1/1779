# Library Management System (LMS)

A FastAPI-based Library Management System with PostgreSQL database, supporting user authentication, book management, and borrowing/returning functionality.

## Features

- **User Authentication**: JWT-based authentication with admin and member roles
- **Book Management**: CRUD operations for books (admin only)
- **Borrowing System**: Members can borrow and return books
- **Transaction Tracking**: Track all borrowing transactions with status (borrowed, returned, overdue)
- **WebSocket Support**: Real-time updates for admin dashboard
- **RESTful API**: Full REST API with OpenAPI documentation

## Prerequisites

- Python 3.10+
- Docker and Docker Compose (for local development)
- DigitalOcean account ([sign up here](https://www.digitalocean.com/))
- DigitalOcean CLI (`doctl`) installed and authenticated
- `kubectl` installed
- Docker installed (for building and pushing images)

## Local Development

### Using Docker Compose

1. **Start the services**:
   ```bash
   docker-compose up -d
   ```

2. **Seed the database** (runs automatically):
   ```bash
   docker-compose run seed
   ```

3. **Access the API**:
   - API: http://localhost:8000
   - API Documentation: http://localhost:8000/docs
   - Health Check: http://localhost:8000/health

4. **Stop the services**:
   ```bash
   docker-compose down
   ```

### Manual Setup

1. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Set up PostgreSQL**:
   - Create a database named `lms_db`
   - Update environment variables in `.env` or export them:
     ```bash
     export DB_USER=lms_user
     export DB_PASSWORD=lms_password
     export DB_HOST=localhost
     export DB_PORT=5432
     export DB_NAME=lms_db
     export SECRET_KEY=your-secret-key-here
     ```

3. **Run database migrations**:
   ```bash
   psql -U lms_user -d lms_db -f schema.sql
   ```

4. **Seed the database**:
   ```bash
   python seed.py
   ```

5. **Run the API**:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

## Building Docker Image

### For DigitalOcean Container Registry (DOCR)

1. **Create a registry** (if not already created):
   ```bash
   # Registry names must be globally unique - use a unique name!
   # Option 1: With timestamp suffix
   doctl registry create lms-registry-1779-$(date +%s | tail -c 5)
   
   # Option 2: Check existing registry
   doctl registry get
   
   doctl registry login
   ```

2. **Build the image**:
   ```bash
   docker build -t lms-api:latest .
   ```

3. **Tag for DOCR**:
   ```bash
   # Get your registry name
   REGISTRY_NAME=$(doctl registry get --format Name --no-header | head -n1)
   docker tag lms-api:latest registry.digitalocean.com/${REGISTRY_NAME}/lms-api:latest
   ```

4. **Push to DOCR**:
   ```bash
   docker push registry.digitalocean.com/${REGISTRY_NAME}/lms-api:latest
   ```

### For Other Registries

1. **Build the image**:
   ```bash
   docker build -t lms-api:latest .
   ```

2. **Tag for your registry**:
   ```bash
   docker tag lms-api:latest your-registry/lms-api:latest
   ```

3. **Push to registry**:
   ```bash
   docker push your-registry/lms-api:latest
   ```

## Kubernetes Deployment on DigitalOcean

This guide walks you through deploying the Library Management System to DigitalOcean Kubernetes (DOKS).

### Prerequisites Setup

#### 1. Install DigitalOcean CLI (doctl)

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

#### 2. Authenticate doctl

```bash
# Generate a personal access token at https://cloud.digitalocean.com/account/api/tokens
doctl auth init
```

Enter your DigitalOcean API token when prompted.

#### 3. Install kubectl

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

### Step 1: Set Up DigitalOcean Container Registry (DOCR)

#### 1.1 Create a Container Registry

**Important**: Registry names must be globally unique across all DigitalOcean accounts. If you get a "name already exists" error, use a unique name.

```bash
# Create a registry with a unique name (add your username, timestamp, or random suffix)
# Option 1: Use a timestamp suffix
doctl registry create lms-registry-1779
# NOTE: current registry name is lms-registry-1779, using this for all the occurances below.

# Option 2: Use your username or a unique identifier
# doctl registry create lms-registry-1779-yourusername

# Option 3: Check if a registry already exists
doctl registry get

# Login to the registry
doctl registry login
```

**Note**: Remember your registry name - you'll need it when updating Kubernetes manifests!

#### 1.2 Build and Push Docker Image

```bash
# Build the Docker image
docker build -t lms-api:latest .

# Tag the image for DOCR
# Replace 'lms-registry-1779' with your registry name if different
docker tag lms-api:latest registry.digitalocean.com/lms-registry-1779/lms-api:latest

# Push to DOCR
docker push registry.digitalocean.com/lms-registry-1779/lms-api:latest
```

**Note**: DOCR registry names are lowercase and may have a region prefix. Check your registry URL:
```bash
doctl registry get
```

### Step 2: Create DigitalOcean Kubernetes Cluster

#### 2.1 Create DOKS Cluster

```bash
# Create a Kubernetes cluster
# Available regions: nyc1, sfo3, ams3, sgp1, lon1, fra1, tor1, blr1, etc.
doctl kubernetes cluster create lms-cluster \
  --region tor1 \
  --node-pool "name=worker-pool;size=s-2vcpu-4gb;count=2;auto-scale=true;min-nodes=1;max-nodes=4"
```

#### 2.2 Configure kubectl

```bash
# Save cluster kubeconfig
doctl kubernetes cluster kubeconfig save lms-cluster

# Verify connection
kubectl get nodes
```

You should see your worker nodes listed.

### Step 3: Configure Kubernetes Manifests

#### 3.1 Update Image References

Update the Docker image path in the Kubernetes manifests to use your DOCR registry:

```bash
# Get your registry name
REGISTRY_NAME=$(doctl registry get --format Name --no-header | head -n1)

# Update deployment.yaml
sed -i "s|your-registry/lms-api:latest|registry.digitalocean.com/${REGISTRY_NAME}/lms-api:latest|g" k8s/deployment.yaml

# Update job-seed.yaml
sed -i "s|your-registry/lms-api:latest|registry.digitalocean.com/${REGISTRY_NAME}/lms-api:latest|g" k8s/job-seed.yaml
```

Or manually edit:
- `k8s/deployment.yaml`: Change `image: your-registry/lms-api:latest` to `image: registry.digitalocean.com/YOUR_REGISTRY/lms-api:latest`
- `k8s/job-seed.yaml`: Same change

#### 3.2 Configure Image Pull Secrets

DOKS needs credentials to pull from DOCR:

```bash
# Get your registry name
REGISTRY_NAME=$(doctl registry get --format Name --no-header | head -n1)

# Create image pull secret
doctl registry kubernetes-manifest | kubectl apply -f -
```

This creates a `registry-{registry-name}` secret that will be used automatically.

#### 3.3 Update Deployment to Use Image Pull Secret

Edit `k8s/deployment.yaml` and add `imagePullSecrets` to the pod spec:

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
      - name: registry-{your-registry-name}
      containers:
      - name: api
        # ... rest of config
```

Or use this command to add it automatically:

```bash
# Get registry name
REGISTRY_NAME=$(doctl registry get --format Name --no-header | head -n1)
SECRET_NAME="registry-${REGISTRY_NAME}"

# Add imagePullSecrets to deployment.yaml (requires yq or manual edit)
# Manual edit: Add under spec.template.spec:
#   imagePullSecrets:
#   - name: registry-{your-registry-name}
```

#### 3.4 Update Secrets

**Important**: Update production secrets before deploying:

```bash
# Generate a secure secret key
openssl rand -hex 32

# Edit k8s/secret.yaml and update:
# - DB_PASSWORD: Use a strong password
# - SECRET_KEY: Use the generated key from above
```

Edit `k8s/secret.yaml`:
```yaml
stringData:
  DB_PASSWORD: "your-secure-db-password"  # Change this!
  SECRET_KEY: "your-generated-secret-key"  # Change this!
```

### Step 4: Deploy to Kubernetes

#### 4.1 Deploy Using Automated Script

```bash
cd k8s
./deploy.sh
```

To also seed the database with sample data (admin user, members, books):
```bash
cd k8s
./deploy.sh --seed
```

This script will:
1. Create ConfigMap and Secret
2. Deploy PostgreSQL (database schema is created automatically via init script)
3. Wait for PostgreSQL to be ready
4. Deploy the API
5. Create LoadBalancer service
6. Optionally seed the database with sample data (if `--seed` flag is used)

**Note**: The database schema (tables) is created automatically by PostgreSQL's init script. The seed job only populates sample data (users, books, transactions) for testing purposes.

#### 4.2 Manual Deployment (Alternative)

If you prefer manual control:

```bash
# 1. Create ConfigMap and Secret
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# 2. Deploy PostgreSQL
kubectl apply -f k8s/postgres-deployment.yaml

# 3. Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s

# 4. Deploy the API
kubectl apply -f k8s/deployment.yaml

# 5. Create Service
kubectl apply -f k8s/service.yaml

# 6. (Optional) Seed the database with sample data
# This creates test users, books, and transactions
kubectl apply -f k8s/job-seed.yaml
```

### Step 5: Access Your Application

#### 5.1 Get LoadBalancer IP

DigitalOcean automatically provisions a LoadBalancer. Get the external IP:

```bash
# Watch until EXTERNAL-IP is assigned
kubectl get service lms-api-service -w
```

Or get it directly:
```bash
EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "API available at: http://$EXTERNAL_IP"
```

#### 5.2 Test the Deployment

```bash
# Health check
curl http://$EXTERNAL_IP/health

# API documentation
open http://$EXTERNAL_IP/docs
```

### Step 6: Verify Deployment

```bash
# Check all pods are running
kubectl get pods

# Check services
kubectl get services

# View API logs
kubectl logs -f deployment/lms-api

# Check PostgreSQL logs
kubectl logs -f deployment/postgres
```

### Troubleshooting

#### Image Pull Errors

If pods fail with `ImagePullBackOff`:

1. **Verify image exists in DOCR**:
   ```bash
   doctl registry repository list-tags lms-api
   ```

2. **Check image pull secret**:
   ```bash
   kubectl get secrets | grep registry
   kubectl describe pod <pod-name> | grep -A 5 "Events"
   ```

3. **Recreate image pull secret**:
   ```bash
   doctl registry kubernetes-manifest | kubectl apply -f -
   ```

#### Database Connection Issues

1. **Check PostgreSQL is running**:
   ```bash
   kubectl get pods -l app=postgres
   kubectl logs deployment/postgres
   ```

2. **Verify ConfigMap**:
   ```bash
   kubectl get configmap lms-config -o yaml
   ```

3. **Test connection from API pod**:
   ```bash
   kubectl exec -it deployment/lms-api -- sh
   # Inside pod:
   pg_isready -h postgres -p 5432 -U lms_user
   ```

#### LoadBalancer Not Getting IP

DigitalOcean LoadBalancers usually provision within 1-2 minutes. If it's taking longer:

```bash
# Check service status
kubectl describe service lms-api-service

# Check for errors
kubectl get events --sort-by='.lastTimestamp'
```

### Cleanup

To delete all resources and avoid charges:

```bash
# Delete Kubernetes cluster (this deletes everything)
doctl kubernetes cluster delete lms-cluster

# Delete container registry (optional)
doctl registry delete lms-registry-1779
```

### Cost Optimization

- **Development**: Use 1 node with `s-1vcpu-2gb` size (~$12/month)
- **Production**: Start with 2 nodes, enable auto-scaling
- **Container Registry**: First 500MB storage is free, then $0.02/GB/month

### Additional Resources

- [DigitalOcean Kubernetes Documentation](https://docs.digitalocean.com/products/kubernetes/)
- [DOCR Documentation](https://docs.digitalocean.com/products/container-registry/)
- [doctl CLI Reference](https://docs.digitalocean.com/reference/doctl/)
- **[Remote Cluster Management Guide](REMOTE_ACCESS.md)** - How to access and manage the cluster from other machines

## Testing

### API Testing

#### 1. Health Check

```bash
curl http://your-api-url/health
```

Expected response:
```json
{"status": "ok"}
```

#### 2. Create Admin User (if not seeded)

First, you need to create an admin user. Since this requires admin privileges, you can:

- Use the seed job (recommended)
- Or temporarily modify the endpoint to allow unauthenticated creation for initial setup

#### 3. Login as Admin

```bash
curl -X POST "http://your-api-url/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin1&password=admin123"
```

Expected response:
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

Save the `access_token` for subsequent requests.

#### 4. List Books

```bash
curl http://your-api-url/books/
```

#### 5. Get a Single Book by ID

```bash
# Get book with ID 1 (includes availability status)
curl http://your-api-url/books/1
```

This returns the book details including:
- Book information (title, author, ISBN, genre, shelf location)
- Availability status (`available: true/false`)
- Book ID

#### 6. Create a Book (Admin Only)

```bash
curl -X POST "http://your-api-url/books/" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Book",
    "author": "Test Author",
    "isbn": "1234567890",
    "genre": "Fiction",
    "shelf_location": "A1"
  }'
```

#### 7. Borrow a Book (Member)

First, login as a member:
```bash
curl -X POST "http://your-api-url/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=member1&password=member123"
```

Then borrow a book:
```bash
curl -X POST "http://your-api-url/borrow" \
  -H "Authorization: Bearer MEMBER_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "book_id": 1,
    "days": 14
  }'
```

#### 8. Return a Book

```bash
curl -X POST "http://your-api-url/return" \
  -H "Authorization: Bearer MEMBER_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "book_id": 1
  }'
```

#### 9. List My Transactions

```bash
curl "http://your-api-url/me/transactions" \
  -H "Authorization: Bearer MEMBER_ACCESS_TOKEN"
```

#### 10. Admin: List All Transactions

```bash
curl "http://your-api-url/admin/transactions" \
  -H "Authorization: Bearer ADMIN_ACCESS_TOKEN"
```

### WebSocket Testing

Connect to the admin WebSocket endpoint:

```bash
# Using wscat (install: npm install -g wscat)
wscat -c "ws://your-api-url/ws/admin?token=YOUR_ADMIN_TOKEN"
```

You should receive real-time updates when books are borrowed or returned.

### Automated Testing Script

Create a test script `test_api.sh`:

```bash
#!/bin/bash

API_URL="http://your-api-url"
ADMIN_USER="admin1"
ADMIN_PASS="admin123"
MEMBER_USER="member1"
MEMBER_PASS="member123"

echo "Testing Health Check..."
curl -s "$API_URL/health" | jq

echo -e "\nTesting Admin Login..."
ADMIN_TOKEN=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER&password=$ADMIN_PASS" | jq -r '.access_token')

echo "Admin Token: ${ADMIN_TOKEN:0:20}..."

echo -e "\nTesting List Books..."
curl -s "$API_URL/books/" | jq '.[0:3]'

echo -e "\nTesting Create Book..."
curl -s -X POST "$API_URL/books/" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Book",
    "author": "Test Author",
    "isbn": "TEST123",
    "genre": "Testing"
  }' | jq

echo -e "\nTesting Member Login..."
MEMBER_TOKEN=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$MEMBER_USER&password=$MEMBER_PASS" | jq -r '.access_token')

echo "Member Token: ${MEMBER_TOKEN:0:20}..."

echo -e "\nTesting Borrow Book..."
curl -s -X POST "$API_URL/borrow" \
  -H "Authorization: Bearer $MEMBER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"book_id": 1, "days": 14}' | jq

echo -e "\nTesting List My Transactions..."
curl -s "$API_URL/me/transactions" \
  -H "Authorization: Bearer $MEMBER_TOKEN" | jq '.[0:2]'

echo -e "\nAll tests completed!"
```

Make it executable and run:
```bash
chmod +x test_api.sh
./test_api.sh
```

## Monitoring and Debugging

### Check Pod Status

```bash
kubectl get pods
kubectl describe pod <pod-name>
```

### View Logs

```bash
# API logs
kubectl logs -f deployment/lms-api

# PostgreSQL logs
kubectl logs -f deployment/postgres

# Seed job logs
kubectl logs job/lms-seed
```

### Check Services

```bash
kubectl get services
kubectl describe service lms-api-service
```

### Port Forward for Local Testing

```bash
# Forward API service to localhost
kubectl port-forward service/lms-api-service 8000:80

# Forward PostgreSQL (for debugging)
kubectl port-forward service/postgres 5432:5432
```

### Database Access

```bash
# Get PostgreSQL pod name
kubectl get pods -l app=postgres

# Connect to PostgreSQL
kubectl exec -it <postgres-pod-name> -- psql -U lms_user -d lms_db
```

## Troubleshooting

### API Pods Not Starting

1. **Check pod status**:
   ```bash
   kubectl get pods
   kubectl describe pod <pod-name>
   ```

2. **Check logs**:
   ```bash
   kubectl logs <pod-name>
   ```

3. **Verify database connectivity**:
   - Ensure PostgreSQL is running: `kubectl get pods -l app=postgres`
   - Check ConfigMap and Secret: `kubectl get configmap lms-config -o yaml`
   - Verify environment variables: `kubectl exec <pod-name> -- env | grep DB_`

### Database Connection Issues

1. **Verify PostgreSQL service**:
   ```bash
   kubectl get service postgres
   ```

2. **Test connection from API pod**:
   ```bash
   kubectl exec -it <api-pod-name> -- sh
   # Inside pod
   pg_isready -h postgres -p 5432 -U lms_user
   ```

3. **Check PostgreSQL logs**:
   ```bash
   kubectl logs -f deployment/postgres
   ```

### Secret Key Issues

If authentication fails, verify the SECRET_KEY is set correctly:

```bash
kubectl get secret lms-secret -o jsonpath='{.data.SECRET_KEY}' | base64 -d
```

### Image Pull Errors

If pods fail with `ImagePullBackOff`:

1. Verify image exists in registry
2. Check image pull secrets if using private registry
3. Update image pull policy if needed

## Default Credentials (from seed.py)

**Note**: These credentials are only available if you ran the seed job with `./deploy.sh --seed` or manually applied `k8s/job-seed.yaml`.

After seeding, you can use these credentials:

- **Admin**: `admin1` / `admin123`
- **Members**: `member1` through `member20` / `member123`

**⚠️ IMPORTANT**: Change these passwords in production!

## API Endpoints

- `GET /health` - Health check
- `POST /auth/login` - User login
- `POST /users/` - Create user (admin only)
- `GET /books/` - List all books
- `GET /books/{book_id}` - Get a single book by ID (includes availability status)
- `POST /books/` - Create book (admin only)
- `PUT /books/{book_id}` - Update book (admin only)
- `DELETE /books/{book_id}` - Delete book (admin only)
- `POST /borrow` - Borrow a book (member)
- `POST /return` - Return a book (member)
- `GET /me/transactions` - List my transactions (member)
- `GET /admin/transactions` - List all transactions (admin)
- `WS /ws/admin` - WebSocket for admin updates

Full API documentation available at `/docs` endpoint.

## Project Structure

```
.
├── app/
│   ├── main.py          # FastAPI application
│   ├── models.py        # SQLAlchemy models
│   ├── schemas.py       # Pydantic schemas
│   ├── crud.py          # Database operations
│   ├── auth.py          # Authentication logic
│   └── db.py            # Database configuration
├── k8s/                 # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── postgres-deployment.yaml
│   └── job-seed.yaml
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── schema.sql
└── seed.py
```

## License

[Add your license here]

## Contributing

[Add contributing guidelines here] 