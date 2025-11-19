# State Persistence Across Container Restarts

## How State is Maintained

This deployment maintains state across container restarts and redeployments through **persistent storage for the PostgreSQL database**. The application itself (FastAPI) is stateless - all data is stored in PostgreSQL.

### Docker Compose Setup

In `docker-compose.yml`, PostgreSQL uses a **named Docker volume**:

```yaml
volumes:
  - lms_db_data:/var/lib/postgresql/data
```

The `lms_db_data` volume persists even when containers are stopped or removed (unless explicitly deleted with `docker-compose down -v`).

### Kubernetes Setup

In `k8s/postgres-deployment.yaml`, PostgreSQL uses a **PersistentVolumeClaim (PVC)**:

```yaml
volumeMounts:
- name: postgres-data
  mountPath: /var/lib/postgresql/data
volumes:
- name: postgres-data
  persistentVolumeClaim:
    claimName: postgres-pvc
```

The PVC (`postgres-pvc`) requests 10Gi of storage and persists data across pod restarts, redeployments, and even pod deletions.

### Architecture

```
┌─────────────────┐
│  FastAPI Pods   │  (Stateless - can be restarted/recreated)
│  (Application)  │
└────────┬────────┘
         │
         │ Connects to
         ▼
┌─────────────────┐
│  PostgreSQL Pod │  (Stateful - data persists)
│   + PVC         │
└─────────────────┘
```

**Key Points:**
- **Application pods** (lms-api) are stateless and can be restarted/recreated without data loss
- **Database pod** (postgres) stores all data in a persistent volume
- When application pods restart, they reconnect to the same database with all existing data
- When the database pod restarts, it mounts the same PVC and retains all data

## Testing State Persistence

### Test 1: Docker Compose - Container Restart

#### Step 1: Start the application and create data

```bash
# Start services
docker-compose up -d

# Wait for services to be ready
sleep 10

# Create a test book via API
curl -X POST "http://localhost:8000/books/" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Book - Persistence",
    "author": "Test Author",
    "isbn": "TEST-PERSIST-001",
    "genre": "Testing"
  }'

# Login and get token (use seeded credentials)
TOKEN=$(curl -s -X POST "http://localhost:8000/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin1&password=admin123" | jq -r '.access_token')

# Create a book with authentication
curl -X POST "http://localhost:8000/books/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "State Persistence Test",
    "author": "Test Author",
    "isbn": "PERSIST-001",
    "genre": "Technical"
  }'

# Verify the book exists
curl "http://localhost:8000/books/" | jq '.[] | select(.isbn == "PERSIST-001")'
```

#### Step 2: Restart containers

```bash
# Restart the API container (database continues running)
docker-compose restart api

# OR restart all containers
docker-compose restart

# Wait for services to be ready
sleep 10
```

#### Step 3: Verify data persists

```bash
# Check that the book still exists
curl "http://localhost:8000/books/" | jq '.[] | select(.isbn == "PERSIST-001")'

# Should return the book data
```

#### Step 4: Test complete container removal (volume persists)

```bash
# Stop and remove containers (but NOT volumes)
docker-compose down

# Start again
docker-compose up -d

# Wait for services
sleep 15

# Verify data still exists
curl "http://localhost:8000/books/" | jq '.[] | select(.isbn == "PERSIST-001")'
```

#### Step 5: Test volume deletion (data loss)

```bash
# Stop and remove containers AND volumes
docker-compose down -v

# Start fresh (data will be lost)
docker-compose up -d

# Wait and verify data is gone
sleep 15
curl "http://localhost:8000/books/" | jq '.[] | select(.isbn == "PERSIST-001")'
# Should return nothing or empty
```

---

### Test 2: Kubernetes - Pod Restart

#### Prerequisites

```bash
# Ensure you're connected to your cluster
kubectl get nodes

# Ensure the application is deployed
kubectl get pods
```

#### Step 1: Create test data

```bash
# Get the service URL (LoadBalancer or port-forward)
# Option A: If using LoadBalancer
EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
API_URL="http://${EXTERNAL_IP}"

# Option B: If using port-forward (run in separate terminal)
# kubectl port-forward service/lms-api-service 8000:80
# API_URL="http://localhost:8000"

# Login and get token
TOKEN=$(curl -s -X POST "${API_URL}/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin1&password=admin123" | jq -r '.access_token')

# Create a test book
curl -X POST "${API_URL}/books/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "K8s Persistence Test",
    "author": "Test Author",
    "isbn": "K8S-PERSIST-001",
    "genre": "Kubernetes"
  }'

# Verify it exists
curl "${API_URL}/books/" | jq '.[] | select(.isbn == "K8S-PERSIST-001")'

# Note the book ID for later
BOOK_ID=$(curl -s "${API_URL}/books/" | jq '.[] | select(.isbn == "K8S-PERSIST-001") | .id')
echo "Created book with ID: $BOOK_ID"
```

#### Step 2: Restart API pods

```bash
# Get current pod names
kubectl get pods -l app=lms-api

# Delete a pod (Kubernetes will recreate it)
kubectl delete pod -l app=lms-api

# Wait for new pod to be ready
kubectl wait --for=condition=ready pod -l app=lms-api --timeout=120s

# Verify pods are running
kubectl get pods -l app=lms-api
```

#### Step 3: Verify data persists after API pod restart

```bash
# Check that the book still exists
curl "${API_URL}/books/" | jq '.[] | select(.isbn == "K8S-PERSIST-001")'

# Should return the same book with the same ID
```

#### Step 4: Restart PostgreSQL pod

```bash
# Get PostgreSQL pod name
kubectl get pods -l app=postgres

# Delete the PostgreSQL pod (it will be recreated)
kubectl delete pod -l app=postgres

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s

# Wait a bit more for PostgreSQL to fully initialize
sleep 10
```

#### Step 5: Verify data persists after database pod restart

```bash
# Check that the book still exists
curl "${API_URL}/books/" | jq '.[] | select(.isbn == "K8S-PERSIST-001")'

# Should still return the book - data persisted!
```

#### Step 6: Test complete redeployment

```bash
# Scale down API deployment
kubectl scale deployment lms-api --replicas=0

# Scale back up
kubectl scale deployment lms-api --replicas=2

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=lms-api --timeout=120s

# Verify data persists
curl "${API_URL}/books/" | jq '.[] | select(.isbn == "K8S-PERSIST-001")'
```

---

### Test 3: Kubernetes - PVC Verification

#### Check PVC status

```bash
# Check PVC exists and is bound
kubectl get pvc postgres-pvc

# Should show STATUS: Bound
```

#### Check volume mount

```bash
# Get PostgreSQL pod name
POSTGRES_POD=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Check volume is mounted
kubectl describe pod $POSTGRES_POD | grep -A 5 "Mounts:"

# Should show /var/lib/postgresql/data mounted from postgres-data
```

#### Verify data in PostgreSQL directly

```bash
# Connect to PostgreSQL
kubectl exec -it $POSTGRES_POD -- psql -U lms_user -d lms_db

# Inside psql, run:
SELECT id, title, isbn FROM books WHERE isbn = 'K8S-PERSIST-001';
\q
```

---

### Test 4: Complete Cluster Scenario

#### Simulate node failure/replacement

```bash
# Get the node where PostgreSQL is running
kubectl get pods -l app=postgres -o wide

# Cordon the node (prevent new pods)
NODE_NAME=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].spec.nodeName}')
kubectl cordon $NODE_NAME

# Delete PostgreSQL pod (will be recreated on another node if available)
kubectl delete pod -l app=postgres

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s

# Verify data persists
curl "${API_URL}/books/" | jq '.[] | select(.isbn == "K8S-PERSIST-001")'

# Uncordon the node
kubectl uncordon $NODE_NAME
```

---

## Automated Test Script

Create a test script to automate the persistence testing:

```bash
#!/bin/bash
# save as: test-persistence.sh

set -e

echo "=== State Persistence Test ==="

# Configuration
if [ -z "$API_URL" ]; then
    # Try to get LoadBalancer IP
    EXTERNAL_IP=$(kubectl get service lms-api-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$EXTERNAL_IP" ]; then
        API_URL="http://${EXTERNAL_IP}"
    else
        API_URL="http://localhost:8000"
        echo "Using localhost:8000 (you may need to port-forward)"
    fi
fi

echo "API URL: $API_URL"

# Test data
TEST_ISBN="AUTO-TEST-$(date +%s)"
TEST_TITLE="Auto Persistence Test $(date)"

echo -e "\n1. Creating test data..."
TOKEN=$(curl -s -X POST "${API_URL}/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin1&password=admin123" | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to get authentication token"
    exit 1
fi

BOOK_RESPONSE=$(curl -s -X POST "${API_URL}/books/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"$TEST_TITLE\",
    \"author\": \"Test Author\",
    \"isbn\": \"$TEST_ISBN\",
    \"genre\": \"Testing\"
  }")

BOOK_ID=$(echo $BOOK_RESPONSE | jq -r '.id')
echo "Created book ID: $BOOK_ID, ISBN: $TEST_ISBN"

echo -e "\n2. Verifying book exists..."
VERIFY1=$(curl -s "${API_URL}/books/" | jq ".[] | select(.isbn == \"$TEST_ISBN\") | .id")
if [ "$VERIFY1" == "$BOOK_ID" ]; then
    echo "✓ Book exists: ID $VERIFY1"
else
    echo "✗ ERROR: Book not found!"
    exit 1
fi

echo -e "\n3. Restarting API pods..."
kubectl delete pod -l app=lms-api
kubectl wait --for=condition=ready pod -l app=lms-api --timeout=120s
sleep 5

echo -e "\n4. Verifying data after API restart..."
VERIFY2=$(curl -s "${API_URL}/books/" | jq ".[] | select(.isbn == \"$TEST_ISBN\") | .id")
if [ "$VERIFY2" == "$BOOK_ID" ]; then
    echo "✓ Book still exists after API restart: ID $VERIFY2"
else
    echo "✗ ERROR: Book lost after API restart!"
    exit 1
fi

echo -e "\n5. Restarting PostgreSQL pod..."
kubectl delete pod -l app=postgres
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s
sleep 10

echo -e "\n6. Verifying data after DB restart..."
VERIFY3=$(curl -s "${API_URL}/books/" | jq ".[] | select(.isbn == \"$TEST_ISBN\") | .id")
if [ "$VERIFY3" == "$BOOK_ID" ]; then
    echo "✓ Book still exists after DB restart: ID $VERIFY3"
else
    echo "✗ ERROR: Book lost after DB restart!"
    exit 1
fi

echo -e "\n=== All persistence tests passed! ==="
echo "Test book ISBN: $TEST_ISBN"
echo "You can clean it up manually if needed"
```

Make it executable and run:

```bash
chmod +x test-persistence.sh
./test-persistence.sh
```

---

## Important Notes

### What Persists
- ✅ All database data (users, books, transactions)
- ✅ Database schema
- ✅ All application state stored in PostgreSQL

### What Doesn't Persist
- ❌ In-memory application state (if any)
- ❌ Logs (unless using log aggregation)
- ❌ Temporary files in containers

### Data Loss Scenarios

**Docker Compose:**
- Data is lost if you run `docker-compose down -v` (removes volumes)
- Data persists if you run `docker-compose down` (keeps volumes)

**Kubernetes:**
- Data is lost if you delete the PVC: `kubectl delete pvc postgres-pvc`
- Data persists across pod restarts, node failures (if storage is network-attached)
- Data may be lost if the underlying storage is deleted (depends on storage class)

### Backup Recommendations

For production, consider:
1. **Regular database backups** using cron jobs or Kubernetes CronJobs
2. **PVC snapshots** (if supported by your storage class)
3. **Database replication** for high availability

---

## Troubleshooting

### Check if PVC is bound

```bash
kubectl get pvc postgres-pvc
```

If STATUS is not "Bound", check:
- Storage class exists
- Sufficient storage available
- Node has storage capacity

### Check volume mount

```bash
kubectl describe pod <postgres-pod-name> | grep -A 10 Mounts
```

### Verify data directory

```bash
POSTGRES_POD=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POSTGRES_POD -- ls -la /var/lib/postgresql/data/pgdata
```

### Check PostgreSQL logs

```bash
kubectl logs -l app=postgres --tail=50
```


