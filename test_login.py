#!/usr/bin/env python3
import requests
import json

# Test login with correct credentials
login_data = {
    "username": "admin",
    "password": "Admin123456@"
}

try:
    print("Testing login with correct credentials...")
    print(f"Data: {json.dumps(login_data)}")
    
    response = requests.post(
        "http://localhost:5000/login",
        json=login_data,
        headers={"Content-Type": "application/json"},
        timeout=10
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response Headers: {dict(response.headers)}")
    print(f"Response Text: {response.text}")
    
    if response.status_code == 200:
        try:
            data = response.json()
            print(f"JSON Response: {json.dumps(data, indent=2)}")
        except json.JSONDecodeError:
            print("Response is not valid JSON")
    
except requests.exceptions.RequestException as e:
    print(f"Request failed: {e}")
except Exception as e:
    print(f"Error: {e}")
