#!/bin/sh

echo "=== Firewalld UI Status Check ==="
echo

# Check if services are running
echo "1. Checking service status..."
if netstat -tlnp | grep -q ":5000"; then
    echo "✓ Express frontend running on port 5000"
else
    echo "✗ Express frontend NOT running on port 5000"
fi

if netstat -tlnp | grep -q ":7001"; then
    echo "✓ Egg.js backend running on port 7001"
else
    echo "✗ Egg.js backend NOT running on port 7001"
fi

echo

# Check authentication flow
echo "2. Testing authentication flow..."
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/)
if [ "$response" = "302" ]; then
    echo "✓ Unauthenticated requests properly redirected to login"
else
    echo "✗ Unexpected response code: $response"
fi

# Test login API
echo "3. Testing login API..."
login_response=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin"}' http://localhost:5000/login)
if echo "$login_response" | grep -q '"success":true'; then
    echo "✓ Login API working correctly"
    token=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    echo "  Token: ${token:0:50}..."
    
    # Test authenticated access
    auth_response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $token" http://localhost:5000/index)
    if [ "$auth_response" = "200" ]; then
        echo "✓ Authenticated access working"
    else
        echo "✗ Authenticated access failed: $auth_response"
    fi
else
    echo "✗ Login API failed"
fi

echo
echo "=== Testing Instructions ==="
echo "1. Open http://localhost:5000/login in your browser"
echo "2. Login with username: admin, password: admin"
echo "3. You should be redirected to the main dashboard (not the old Chinese login page)"
echo "4. If you see the old Chinese login page, check the browser console for errors"
echo
echo "=== Troubleshooting ==="
echo "If you're still redirected to the old Chinese login page:"
echo "1. Clear your browser cache and localStorage"
echo "2. Try in an incognito/private browsing window"
echo "3. Check browser console for JavaScript errors"
echo "4. Verify the localStorage contains the correct authentication data"
