#!/bin/bash

# Firewalld-UI Status Checker

echo "=== Firewalld-UI Status ==="
echo

# Check systemd service status
echo "1. Systemd Service Status:"
sudo systemctl is-active firewalld-ui.service > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✅ firewalld-ui.service is ACTIVE"
    echo "   📊 Service details:"
    sudo systemctl status firewalld-ui.service --no-pager -l | grep -E "Active:|Main PID:|Memory:|CPU:" | sed 's/^/      /'
else
    echo "   ❌ firewalld-ui.service is NOT ACTIVE"
fi
echo

# Check if ports are listening
echo "2. Port Status:"
if netstat -tln 2>/dev/null | grep -q ":5000 "; then
    echo "   ✅ Port 5000 (HTTP Frontend) is LISTENING"
else
    echo "   ❌ Port 5000 (HTTP Frontend) is NOT LISTENING"
fi

if netstat -tln 2>/dev/null | grep -q ":7001 "; then
    echo "   ✅ Port 7001 (Backend) is LISTENING"
else
    echo "   ❌ Port 7001 (Backend) is NOT LISTENING"
fi
echo

# Test HTTP response
echo "3. HTTP Response Test:"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/login 2>/dev/null)
if [ "$HTTP_STATUS" = "200" ]; then
    echo "   ✅ HTTP GET /login returns 200 OK"
else
    echo "   ❌ HTTP GET /login returns $HTTP_STATUS (or connection failed)"
fi
echo

# Quick login API test
echo "4. Login API Test:"
API_RESPONSE=$(curl -s -X POST http://localhost:5000/login -H "Content-Type: application/json" -d '{"username":"admin","password":"test"}' 2>/dev/null)
if echo "$API_RESPONSE" | grep -q '"success":true'; then
    echo "   ✅ Login API returns success"
else
    echo "   ❌ Login API failed or returned error"
fi
echo

echo "=== Quick Commands ==="
echo "• View service status: sudo systemctl status firewalld-ui"
echo "• View live logs: sudo journalctl -u firewalld-ui -f"
echo "• Restart service: sudo systemctl restart firewalld-ui"
echo "• Stop service: sudo systemctl stop firewalld-ui"
echo "• Manual start: ./shell/manual-start.sh"
echo "• Manual stop: ./shell/stop-all.sh"
echo
echo "🌐 Access login page: http://localhost:5000/login"
