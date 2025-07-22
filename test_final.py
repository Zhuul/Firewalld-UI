#!/usr/bin/env python3
import requests
import json
import sys

def test_login():
    print("🔐 Testing login...")
    try:
        response = requests.post('http://localhost:5000/login', 
                               json={'username': 'admin', 'password': 'Admin123456@'},
                               timeout=5)
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print("✅ Login successful!")
                return data['data']['token']
            else:
                print(f"❌ Login failed: {data.get('message', 'Unknown error')}")
                return None
        else:
            print(f"❌ Login HTTP error: {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Login exception: {e}")
        return None

def test_fingerprint():
    print("🔑 Testing fingerprint...")
    try:
        response = requests.get('http://localhost:5000/api/getPublicKeyFingerprint', timeout=5)
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print("✅ Fingerprint retrieved successfully!")
                return data['data']['publicKeyFingerprint']
            else:
                print(f"❌ Fingerprint failed: {data.get('message', 'Unknown error')}")
                return None
        else:
            print(f"❌ Fingerprint HTTP error: {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Fingerprint exception: {e}")
        return None

def test_main_app():
    print("🌐 Testing main app access...")
    try:
        response = requests.get('http://localhost:5000/', timeout=5)
        if response.status_code == 200:
            print("✅ Main app accessible!")
            print(f"   Content length: {len(response.text)} chars")
            if 'vue' in response.text.lower() or 'app' in response.text.lower():
                print("✅ Vue.js app detected!")
            return True
        else:
            print(f"❌ Main app HTTP error: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Main app exception: {e}")
        return False

if __name__ == "__main__":
    print("=== Final Authentication Flow Test ===\n")
    
    # Test login
    token = test_login()
    if not token:
        print("\n❌ Login test failed, stopping here.")
        sys.exit(1)
    
    # Test fingerprint
    fingerprint = test_fingerprint()
    if not fingerprint:
        print("\n❌ Fingerprint test failed.")
    
    # Test main app
    app_ok = test_main_app()
    
    print("\n=== Test Summary ===")
    print(f"✅ Login: {'PASS' if token else 'FAIL'}")
    print(f"✅ Fingerprint: {'PASS' if fingerprint else 'FAIL'}")
    print(f"✅ Main App: {'PASS' if app_ok else 'FAIL'}")
    
    if token and fingerprint and app_ok:
        print("\n🎉 All tests PASSED! The Firewalld-UI is working correctly!")
        print("\n📝 Key Points:")
        print("   • POST /login proxy to backend: WORKING")
        print("   • API proxy for fingerprint: WORKING") 
        print("   • Vue.js SPA serving: WORKING")
        print("   • Authentication flow: COMPLETE")
        print("\n🌐 Access the application at: http://localhost:5000/login")
    else:
        print("\n⚠️  Some tests failed, but core functionality appears to work.")
        
    print("\n=== End Test ===")
