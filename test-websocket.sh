#!/bin/bash
# Script to test WebSocket connection to LMS API

set -e

echo "🔌 Testing WebSocket Connection to LMS API"
echo ""

# Get Ingress IP
INGRESS_IP=$(kubectl get ingress lms-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -z "$INGRESS_IP" ]; then
    echo "❌ No Ingress LoadBalancer found"
    echo "   Using port-forward instead..."
    echo ""
    echo "Run this in another terminal first:"
    echo "   kubectl port-forward service/lms-api-service 8000:80"
    echo ""
    read -p "Press Enter when port-forward is ready..."
    WS_URL="ws://localhost:8000/ws/admin"
else
    echo "✅ Found Ingress IP: $INGRESS_IP"
    WS_URL="ws://$INGRESS_IP/ws/admin"
fi

echo ""
echo "📝 Step 1: Getting admin JWT token..."
API_URL="${WS_URL%ws://*}http://${WS_URL#ws://}"
API_URL="${API_URL%/ws/admin*}"

# Get token
echo "   Logging in as admin1..."
TOKEN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=admin1&password=admin123" || echo "")

if [ -z "$TOKEN_RESPONSE" ]; then
    echo "❌ Failed to get token. Is the API accessible?"
    exit 1
fi

TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "")

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "❌ Failed to parse token. Response:"
    echo "$TOKEN_RESPONSE"
    exit 1
fi

echo "✅ Token obtained: ${TOKEN:0:20}..."
echo ""

echo "📡 Step 2: Testing WebSocket connection..."
echo ""
echo "WebSocket URL: ${WS_URL}?token=${TOKEN:0:20}..."
echo ""

# Check if wscat is installed
if command -v wscat &> /dev/null; then
    echo "✅ wscat is installed. Connecting..."
    echo ""
    wscat -c "${WS_URL}?token=${TOKEN}"
else
    echo "⚠️  wscat is not installed"
    echo ""
    echo "Install it with:"
    echo "   npm install -g wscat"
    echo ""
    echo "Or use Python script:"
    cat << 'PYTHON_SCRIPT'
import asyncio
import websockets
import json
import sys

async def test_websocket():
    token = sys.argv[1] if len(sys.argv) > 1 else "YOUR_TOKEN"
    ws_url = f"ws://<INGRESS_IP>/ws/admin?token={token}"
    
    try:
        async with websockets.connect(ws_url) as websocket:
            print("✅ Connected to WebSocket")
            print("Listening for messages...")
            
            # Send a ping
            await websocket.send("ping")
            
            # Listen for messages
            async for message in websocket:
                try:
                    data = json.loads(message)
                    print(f"📨 Received: {json.dumps(data, indent=2)}")
                except json.JSONDecodeError:
                    print(f"📨 Received: {message}")
                    
    except websockets.exceptions.InvalidStatusCode as e:
        print(f"❌ Connection failed: {e}")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    asyncio.run(test_websocket())
PYTHON_SCRIPT
    echo ""
    echo "Python usage:"
    echo "   pip install websockets"
    echo "   python test-websocket.py $TOKEN"
    echo ""
    echo "Or test manually with curl (basic check):"
    echo "   curl -i -N \\"
    echo "     -H 'Connection: Upgrade' \\"
    echo "     -H 'Upgrade: websocket' \\"
    echo "     -H 'Sec-WebSocket-Version: 13' \\"
    echo "     -H 'Sec-WebSocket-Key: test' \\"
    echo "     '${WS_URL}?token=${TOKEN}'"
fi

