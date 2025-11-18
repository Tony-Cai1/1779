#!/bin/bash
# State Persistence Test Script
# Tests that data persists across container/pod restarts

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
        echo "To port-forward: kubectl port-forward service/lms-api-service 8000:80"
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
    echo "Make sure the database is seeded with admin1/admin123"
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
if [ "$BOOK_ID" == "null" ] || [ -z "$BOOK_ID" ]; then
    echo "ERROR: Failed to create book"
    echo "Response: $BOOK_RESPONSE"
    exit 1
fi

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
kubectl delete pod -l app=lms-api 2>/dev/null || echo "No API pods found (might be using docker-compose)"
kubectl wait --for=condition=ready pod -l app=lms-api --timeout=120s 2>/dev/null || echo "Waiting for API to be ready..."
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
kubectl delete pod -l app=postgres 2>/dev/null || echo "No PostgreSQL pod found (might be using docker-compose)"
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s 2>/dev/null || echo "Waiting for PostgreSQL to be ready..."
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

