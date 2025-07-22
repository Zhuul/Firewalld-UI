#!/usr/bin/env python3
"""
Test script to simulate the entire login flow including redirect behavior
"""

import requests
import json
import time
from urllib.parse import urljoin

BASE_URL = "http://localhost:5000"
USERNAME = "root"
PASSWORD = "Admin123456@"

def test_login_redirect_flow():
    """Test the complete login and redirect flow"""
    print("=== Testing Login Redirect Flow ===\n")
    
    # Create a session to maintain cookies
    session = requests.Session()
    
    # Step 1: Try to access main page without authentication
    print("1. Accessing main page without authentication...")
    try:
        response = session.get(BASE_URL + "/")
        print(f"   Status: {response.status_code}")
        print(f"   Final URL: {response.url}")
        print(f"   Content length: {len(response.text)}")
        
        if "login" in response.url.lower() or "login" in response.text.lower():
            print("   ✓ Correctly redirected to login page")
        else:
            print("   ✗ Not redirected to login page")
            
    except Exception as e:
        print(f"   ✗ Error: {e}")
    
    print()
    
    # Step 2: Access login page directly
    print("2. Accessing login page directly...")
    try:
        response = session.get(BASE_URL + "/login")
        print(f"   Status: {response.status_code}")
        print(f"   Content length: {len(response.text)}")
        
        if "login" in response.text.lower() and "username" in response.text.lower():
            print("   ✓ Login page served correctly")
        else:
            print("   ✗ Login page not served correctly")
            
    except Exception as e:
        print(f"   ✗ Error: {e}")
    
    print()
    
    # Step 3: Perform login
    print("3. Performing login...")
    try:
        login_data = {
            "username": USERNAME,
            "password": PASSWORD
        }
        
        response = session.post(BASE_URL + "/login", json=login_data)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.text[:200]}...")
        
        if response.status_code == 200:
            result = response.json()
            if result.get("code") == 200:
                token = result.get("data", {}).get("token")
                print(f"   ✓ Login successful! Token: {token[:20]}...")
                
                # Step 4: Try to access main page with token
                print("\n4. Accessing main page with token...")
                
                # Set token in session headers
                session.headers.update({"Authorization": f"Bearer {token}"})
                
                response = session.get(BASE_URL + "/")
                print(f"   Status: {response.status_code}")
                print(f"   Final URL: {response.url}")
                print(f"   Content length: {len(response.text)}")
                
                if response.status_code == 200 and "login" not in response.url.lower():
                    print("   ✓ Main page accessible with token")
                    
                    # Check if Vue.js app is loading
                    if "Vue" in response.text or "vue" in response.text or "assets/js/app" in response.text:
                        print("   ✓ Vue.js application detected")
                    else:
                        print("   ✗ Vue.js application not detected")
                else:
                    print("   ✗ Main page not accessible with token")
                    
            else:
                print(f"   ✗ Login failed: {result}")
        else:
            print(f"   ✗ Login request failed: {response.status_code}")
            
    except Exception as e:
        print(f"   ✗ Error: {e}")
    
    print()
    
    # Step 5: Test what happens with browser simulation
    print("5. Testing browser-like behavior...")
    try:
        # Create a new session to simulate a fresh browser
        browser_session = requests.Session()
        browser_session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        })
        
        # First try to access the main page
        response = browser_session.get(BASE_URL + "/", allow_redirects=True)
        print(f"   Initial access - Status: {response.status_code}, URL: {response.url}")
        
        # If redirected to login, try to login
        if "login" in response.url.lower():
            print("   Redirected to login, performing login...")
            
            login_response = browser_session.post(BASE_URL + "/login", json={
                "username": USERNAME,
                "password": PASSWORD
            })
            
            if login_response.status_code == 200:
                result = login_response.json()
                if result.get("code") == 200:
                    token = result.get("data", {}).get("token")
                    print(f"   Login successful, token: {token[:20]}...")
                    
                    # Now try to access main page again
                    browser_session.headers.update({"Authorization": f"Bearer {token}"})
                    main_response = browser_session.get(BASE_URL + "/")
                    print(f"   After login - Status: {main_response.status_code}, URL: {main_response.url}")
                    
                    if main_response.status_code == 200 and "login" not in main_response.url.lower():
                        print("   ✓ Successfully accessed main page after login")
                    else:
                        print("   ✗ Still redirected to login after authentication")
                else:
                    print(f"   ✗ Login failed: {result}")
            else:
                print(f"   ✗ Login request failed: {login_response.status_code}")
                
    except Exception as e:
        print(f"   ✗ Error: {e}")
    
    print("\n=== Test Complete ===")

if __name__ == "__main__":
    test_login_redirect_flow()
