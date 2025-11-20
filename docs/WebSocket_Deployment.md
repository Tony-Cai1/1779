# WebSocket Deployment Guide

## Overview

The LMS API includes WebSocket support for real-time admin dashboard updates. The WebSocket endpoint is `/ws/admin` and requires JWT authentication.

## Architecture

```
Client → Ingress (NGINX) → Service → Pod → FastAPI WebSocket Handler
```

## WebSocket Endpoint

- **Path**: `/ws/admin`
- **Protocol**: WebSocket (ws:// or wss://)
- **Authentication**: JWT token as query parameter
- **Authorization**: Admin role required

## Connection URL

### Via Ingress (Production)
```
ws://<INGRESS_IP>/ws/admin?token=<JWT_TOKEN>
wss://<INGRESS_IP>/ws/admin?token=<JWT_TOKEN>  # If using TLS
```

### Via Port Forward (Development)
```
ws://localhost:8000/ws/admin?token=<JWT_TOKEN>
```

## NGINX Ingress Configuration

The Ingress controller has been configured with WebSocket support:

```yaml
annotations:
  nginx.ingress.kubernetes.io/websocket-services: "lms-api-service"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "3600"
```

### Key Annotations Explained

1. **`websocket-services`**: Tells NGINX to upgrade HTTP connections to WebSocket for specified services
2. **`proxy-read-timeout`**: Maximum time (seconds) to read response from backend (1 hour)
3. **`proxy-send-timeout`**: Maximum time (seconds) to send request to backend (1 hour)
4. **`proxy-connect-timeout`**: Maximum time (seconds) to establish connection (1 hour)

## Testing WebSocket Connection

### 1. Get Admin JWT Token

```bash
# Login as admin
curl -X POST "http://<API_URL>/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin1&password=admin123"

# Save the access_token from response
export WS_TOKEN="<access_token>"
```

### 2. Test with wscat (CLI Tool)

Install wscat:
```bash
npm install -g wscat
```

Connect:
```bash
# Via Ingress
wscat -c "ws://<INGRESS_IP>/ws/admin?token=$WS_TOKEN"

# Via port-forward (run kubectl port-forward first)
wscat -c "ws://localhost:8000/ws/admin?token=$WS_TOKEN"
```

### 3. Test with Python

```python
import asyncio
import websockets
import json

async def test_websocket():
    token = "YOUR_JWT_TOKEN"
    uri = f"ws://<INGRESS_IP>/ws/admin?token={token}"
    
    async with websockets.connect(uri) as websocket:
        print("Connected to WebSocket")
        
        # Listen for messages
        async for message in websocket:
            data = json.loads(message)
            print(f"Received: {data}")
            
            # Send a ping
            await websocket.send("ping")

asyncio.run(test_websocket())
```

### 4. Test with JavaScript (Browser)

```javascript
const token = 'YOUR_JWT_TOKEN';
const wsUrl = `ws://<INGRESS_IP>/ws/admin?token=${token}`;
const ws = new WebSocket(wsUrl);

ws.onopen = () => {
    console.log('WebSocket connected');
    ws.send('ping');
};

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('Received:', data);
};

ws.onerror = (error) => {
    console.error('WebSocket error:', error);
};

ws.onclose = () => {
    console.log('WebSocket closed');
};
```

## WebSocket Message Format

### Receiving Messages

The WebSocket sends book update events when books are borrowed or returned:

```json
{
  "event": "book_update",
  "book_id": 1,
  "title": "Example Book",
  "available": false,
  "genre": "Fiction",
  "shelf_location": "A1"
}
```

### Sending Messages

Currently, the server accepts any text message (used as keep-alive ping).

## Troubleshooting

### Connection Refused

**Problem**: Cannot connect to WebSocket

**Solutions**:
1. Verify Ingress IP is correct:
   ```bash
   kubectl get ingress lms-ingress
   ```

2. Check if WebSocket annotations are applied:
   ```bash
   kubectl get ingress lms-ingress -o yaml | grep websocket
   ```

3. Test HTTP endpoint first:
   ```bash
   curl http://<INGRESS_IP>/health
   ```

### 401 Unauthorized

**Problem**: Authentication fails

**Solutions**:
1. Verify token is valid:
   ```bash
   # Decode JWT token (check expiry, role)
   echo "YOUR_TOKEN" | cut -d. -f2 | base64 -d | jq
   ```

2. Ensure admin role:
   ```bash
   # Login with admin credentials
   curl -X POST "http://<API_URL>/auth/login" \
     -d "username=admin1&password=admin123"
   ```

3. Check token in URL:
   ```
   ws://<IP>/ws/admin?token=<VALID_TOKEN>
   ```

### Connection Drops Immediately

**Problem**: WebSocket connects then disconnects

**Solutions**:
1. Check pod logs:
   ```bash
   kubectl logs -f deployment/lms-api
   ```

2. Verify NGINX timeouts are sufficient:
   ```bash
   kubectl get ingress lms-ingress -o yaml | grep timeout
   ```

3. Check for firewall/security group rules blocking WebSocket

### NGINX 502 Bad Gateway

**Problem**: Ingress returns 502 error

**Solutions**:
1. Verify service is running:
   ```bash
   kubectl get pods -l app=lms-api
   ```

2. Check service endpoints:
   ```bash
   kubectl get endpoints lms-api-service
   ```

3. Test service directly (port-forward):
   ```bash
   kubectl port-forward service/lms-api-service 8000:80
   # Then test: ws://localhost:8000/ws/admin?token=...
   ```

## Monitoring

WebSocket connections are tracked in Prometheus:

```promql
lms_websocket_connections_active
```

View in Grafana dashboard: "LMS API Metrics" → "Active WebSocket Connections"

## Security Considerations

1. **Use WSS (WebSocket Secure)** in production:
   - Enable TLS in Ingress
   - Use `wss://` protocol

2. **Token Expiry**: JWT tokens expire - clients need to reconnect with new token

3. **Rate Limiting**: Consider rate limiting WebSocket connections per IP

4. **Connection Limits**: Monitor active connections to prevent resource exhaustion

## Deployment Checklist

- [x] WebSocket endpoint implemented (`/ws/admin`)
- [x] Ingress configured with WebSocket support
- [x] Timeout settings configured (1 hour)
- [x] Authentication/authorization implemented
- [x] Metrics tracking active connections
- [ ] TLS/SSL enabled (for production)
- [ ] Rate limiting configured (optional)
- [ ] Connection limits set (optional)

## Next Steps

1. **Enable TLS**: Configure cert-manager for HTTPS/WSS
2. **Load Testing**: Test with multiple concurrent WebSocket connections
3. **Monitoring Alerts**: Set up alerts for high connection counts
4. **Client SDK**: Create reusable WebSocket client library

