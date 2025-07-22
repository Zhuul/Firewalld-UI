#!/usr/bin/env python3
import requests
import json

print("=== Firewalld UI Authentication Flow Test ===")
print()

# Step 1: Test login API
print("1. Testing login API...")
login_response = requests.post('http://localhost:5000/login',
                              json={'username': 'admin', 'password': 'Admin123456@'},
                              headers={'Content-Type': 'application/json'})

if login_response.status_code == 200:
    login_data = login_response.json()
    if login_data.get('success'):
        token = login_data['data']['token']
        print(f"✓ Login successful! Token: {token[:20]}...")
        
        # Step 2: Test fingerprint API
        print("\n2. Testing fingerprint API...")
        fingerprint_response = requests.get('http://localhost:5000/api/getPublicKeyFingerprint')
        
        if fingerprint_response.status_code == 200:
            fingerprint_data = fingerprint_response.json()
            if fingerprint_data.get('success'):
                fingerprint = fingerprint_data['data']['publicKeyFingerprint']
                print(f"✓ Fingerprint obtained: {fingerprint}")
                
                # Step 3: Test authenticated access to main app
                print("\n3. Testing authenticated access...")
                app_response = requests.get('http://localhost:5000/',
                                          headers={'Authorization': f'Bearer {token}'})
                
                if app_response.status_code == 200:
                    print("✓ Main app accessible with authentication")
                    print(f"  Content length: {len(app_response.text)} chars")
                    print(f"  Content type: {app_response.headers.get('content-type', 'unknown')}")
                    
                    # Check for Vue.js indicators
                    content_lower = app_response.text.lower()
                    if 'vue' in content_lower or 'chunk-vendors' in content_lower:
                        print("✓ Vue.js application detected")
                    else:
                        print("⚠️  Vue.js indicators not found")
                        
                    # Step 4: Test API calls with both token and fingerprint
                    print("\n4. Testing API with token and fingerprint headers...")
                    api_test = requests.get('http://localhost:5000/api/getPublicKeyFingerprint',
                                          headers={
                                              'Authorization': f'Bearer {token}',
                                              'fingerprint': fingerprint,
                                              'token': token
                                          })
                    
                    if api_test.status_code == 200:
                        print("✓ API accessible with full authentication headers")
                    else:
                        print(f"⚠️  API test failed: {api_test.status_code}")
                    
                else:
                    print(f"✗ Main app access failed: {app_response.status_code}")
            else:
                print(f"✗ Fingerprint API failed: {fingerprint_data.get('message', 'Unknown error')}")
        else:
            print(f"✗ Fingerprint API request failed: {fingerprint_response.status_code}")
    else:
        print(f"✗ Login failed: {login_data.get('message', 'Unknown error')}")
else:
    print(f"✗ Login request failed: {login_response.status_code}")

print("\n=== Test Complete ===")
print("\nIf all tests pass, the login flow should work correctly.")
print("The key was adding the fingerprint data to the Vuex store!")
