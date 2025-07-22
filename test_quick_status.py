#!/usr/bin/env python3
"""
Quick test to verify the current state
"""

import requests
import sys
import json

def test_endpoints():
    """Test basic endpoints"""
    
    print("=== Quick Status Test ===\n")
    
    # Test 1: GET main page
    try:
        response = requests.get("http://localhost:5000/", timeout=5)
        print(f"1. GET / - Status: {response.status_code}")
        if response.status_code == 200:
            print("   ✓ Main Vue.js app is accessible")
        else:
            print("   ✗ Main page not accessible")
    except Exception as e:
        print(f"   ✗ Error accessing main page: {e}")
    
    # Test 2: GET login page
    try:
        response = requests.get("http://localhost:5000/login", timeout=5)
        print(f"2. GET /login - Status: {response.status_code}")
        if response.status_code == 200:
            print("   ✓ Login page serves Vue.js app")
        else:
            print("   ✗ Login page not accessible")
    except Exception as e:
        print(f"   ✗ Error accessing login page: {e}")
    
    # Test 3: Test captcha API
    try:
        response = requests.get("http://localhost:5000/captcha", timeout=5)
        print(f"3. GET /captcha - Status: {response.status_code}")
        if response.status_code == 200:
            print("   ✓ Captcha API working")
        else:
            print("   ✗ Captcha API not working")
    except Exception as e:
        print(f"   ✗ Error accessing captcha API: {e}")
    
    # Test 4: Direct backend test
    try:
        response = requests.post("http://127.0.0.1:7001/login", 
                               json={"username": "admin", "password": "Admin123456@"}, 
                               timeout=5)
        print(f"4. POST 127.0.0.1:7001/login - Status: {response.status_code}")
        if response.status_code == 200:
            print("   ✓ Backend login works directly")
        else:
            print("   ✗ Backend login failed")
    except Exception as e:
        print(f"   ✗ Error accessing backend directly: {e}")
    
    print("\n=== Test Complete ===")

if __name__ == "__main__":
    test_endpoints()
