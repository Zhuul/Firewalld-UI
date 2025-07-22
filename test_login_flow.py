#!/usr/bin/env python3
import requests
import json

# Test the complete login flow
print("=== Testing Login Flow ===")

# Step 1: Get the login page
print("1. Getting login page...")
response = requests.get('http://localhost:5000/login')
print(f"Login page status: {response.status_code}")
if response.status_code == 200:
    print("✓ Login page served successfully")
else:
    print("✗ Failed to get login page")

# Step 2: Perform login
print("\n2. Performing login...")
login_data = {
    'username': 'admin',
    'password': 'Admin123456@'
}

response = requests.post('http://localhost:5000/login', 
                        json=login_data,
                        headers={'Content-Type': 'application/json'})

print(f"Login status: {response.status_code}")
if response.status_code == 200:
    data = response.json()
    if data.get('success'):
        token = data['data']['token']
        print(f"✓ Login successful! Token: {token[:50]}...")
        
        # Step 3: Test accessing dashboard with token
        print("\n3. Testing dashboard access with token...")
        
        # Test with Authorization header
        response = requests.get('http://localhost:5000/index',
                               headers={'Authorization': f'Bearer {token}'})
        print(f"Dashboard (with header) status: {response.status_code}")
        
        # Test with query parameter
        response = requests.get(f'http://localhost:5000/index?token={token}')
        print(f"Dashboard (with query) status: {response.status_code}")
        
        # Step 4: Test root access
        print("\n4. Testing root access...")
        response = requests.get('http://localhost:5000/',
                               headers={'Authorization': f'Bearer {token}'})
        print(f"Root access status: {response.status_code}")
        if response.status_code == 200:
            content_type = response.headers.get('content-type', '')
            if 'text/html' in content_type:
                print("✓ HTML content served (likely Vue.js app)")
                # Check if it's the login page or the main app
                if '登录' in response.text or 'Login' in response.text[:1000]:
                    print("⚠️  Still getting login content")
                else:
                    print("✓ Main app content served")
            else:
                print(f"Content-Type: {content_type}")
        
    else:
        print(f"✗ Login failed: {data.get('message')}")
else:
    print(f"✗ Login request failed: {response.status_code}")
    try:
        print(f"Response: {response.text}")
    except:
        pass

print("\n=== Test Complete ===")
