"""
Test script for Password Vault Module
Run this after starting the server
"""

import requests
import json

BASE_URL = "http://localhost:8000/api"

def test_password_module():
    print("=" * 50)
    print("TESTING PASSWORD VAULT MODULE")
    print("=" * 50)
    
    # Step 1: Login (use existing user or register new)
    print("\n1. Testing Login...")
    login_response = requests.post(
        f"{BASE_URL}/auth/login",
        json={"master_password": "MyStrongPass123!"}
    )
    
    if login_response.status_code != 200:
        print("   Login failed! Trying to register first...")
        
        # Register new user
        register_response = requests.post(
            f"{BASE_URL}/auth/register",
            json={"master_password": "MyStrongPass123!", "pin": "1234"}
        )
        print(f"   Register response: {register_response.status_code}")
        if register_response.status_code == 201:
            print(f"   Register success: {register_response.json()}")
            token = register_response.json().get("token")
        else:
            print(f"   Register failed: {register_response.text}")
            return
        
        # Try login again
        login_response = requests.post(
            f"{BASE_URL}/auth/login",
            json={"master_password": "MyStrongPass123!"}
        )
    
    if login_response.status_code == 200:
        token = login_response.json().get("token")
        print(f"    Login successful!")
        print(f"   Token: {token[:50]}...")
    else:
        print(f"    Login failed: {login_response.text}")
        return
    
    headers = {"Authorization": f"Bearer {token}"}
    
    # Step 2: Test Password Strength Analysis
    print("\n2. Testing Password Strength Analysis...")
    
    weak_password = "123456"
    strength_response = requests.post(
        f"{BASE_URL}/irbe/password-strength",
        json={"password": weak_password}
    )
    print(f"   Weak password '{weak_password}': {strength_response.json()}")
    
    strong_password = "T#9mK!v2Xq$8pYz@w"
    strength_response = requests.post(
        f"{BASE_URL}/irbe/password-strength",
        json={"password": strong_password}
    )
    print(f"   Strong password: {strength_response.json()}")
    
    # Step 3: Test Password Generator
    print("\n3. Testing Password Generator...")
    gen_response = requests.post(
        f"{BASE_URL}/irbe/password-generate",
        json={"length": 16, "use_uppercase": True, "use_numbers": True, "use_symbols": True}
    )
    print(f"   Generated passwords: {gen_response.json()}")
    
    # Step 4: Create a Password Entry
    print("\n4. Creating Password Entry...")
    create_response = requests.post(
        f"{BASE_URL}/passwords",
        json={
            "title": "Google Account",
            "username": "john.doe@gmail.com",
            "password": "MySecurePass123!",
            "url": "https://google.com",
            "tag": "Email"
        },
        headers=headers
    )
    print(f"   Create response status: {create_response.status_code}")
    print(f"   Create response: {create_response.json()}")
    
    if create_response.status_code == 201:
        password_id = create_response.json().get("id")
        print(f"    Created password with ID: {password_id}")
        
        # Step 5: List All Passwords
        print("\n5. Listing All Passwords...")
        list_response = requests.get(f"{BASE_URL}/passwords", headers=headers)
        print(f"   Status: {list_response.status_code}")
        if list_response.status_code == 200:
            print(f"   Found {len(list_response.json())} passwords")
            for pwd in list_response.json():
                print(f"     - {pwd['title']} (Score: {pwd['strength_score']})")
        
        # Step 6: Get Single Password
        print(f"\n6. Getting Password ID {password_id}...")
        get_response = requests.get(f"{BASE_URL}/passwords/{password_id}", headers=headers)
        if get_response.status_code == 200:
            data = get_response.json()
            print(f"   Title: {data['title']}")
            print(f"   Username: {data['username']}")
            print(f"   URL: {data['url']}")
            print(f"   Strength Score: {data['strength_score']}")
        else:
            print(f"   Failed: {get_response.text}")
        
        # Step 7: Get Risk Report
        print("\n7. Getting Risk Report...")
        risk_response = requests.get(f"{BASE_URL}/irbe/risk-report", headers=headers)
        if risk_response.status_code == 200:
            print(f"   Health Score: {risk_response.json()['health_score']}")
            print(f"   Total Passwords: {risk_response.json()['total_passwords']}")
            print(f"   Strong: {risk_response.json()['strong_passwords_count']}")
            print(f"   Moderate: {risk_response.json()['moderate_passwords_count']}")
            print(f"   Weak: {risk_response.json()['weak_passwords_count']}")
        else:
            print(f"   Failed: {risk_response.text}")
        
        # Step 8: Delete Password
        print(f"\n8. Deleting Password ID {password_id}...")
        delete_response = requests.delete(f"{BASE_URL}/passwords/{password_id}", headers=headers)
        print(f"   Delete response: {delete_response.json()}")
    else:
        print("    Failed to create password entry")
        print(f"   Error details: {create_response.text}")
    
    print("\n" + "=" * 50)
    print(" Password Module Tests Complete!")
    print("=" * 50)

if __name__ == "__main__":
    test_password_module()