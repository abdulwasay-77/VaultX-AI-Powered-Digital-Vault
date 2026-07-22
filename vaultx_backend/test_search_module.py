"""
Test script for Smart Search Module - OPTIMIZED
Does NOT recreate data each time
"""

import requests
import time

BASE_URL = "http://localhost:8000/api"

def test_search_module():
    print("=" * 60)
    print("TESTING SMART SEARCH MODULE")
    print("=" * 60)
    
    # Step 1: Login
    print("\n1. Logging in...")
    login_response = requests.post(
        f"{BASE_URL}/auth/login",
        json={"master_password": "MyStrongPass123!"}
    )
    
    if login_response.status_code != 200:
        print("   Login failed! Please register first.")
        return
    
    token = login_response.json().get("token")
    headers = {"Authorization": f"Bearer {token}"}
    print(f"   ✅ Login successful!")
    
    # Step 2: Check if test data exists, create only if needed
    print("\n2. Checking test data...")
    check_response = requests.get(f"{BASE_URL}/search?q=Google", headers=headers)
    
    if check_response.status_code == 200:
        data = check_response.json()
        if data['total'] == 0:
            print("   Creating test data (first time only)...")
            # Create passwords
            test_passwords = [
                {"title": "Google Account", "username": "user@gmail.com", "password": "pass123", "tag": "Email"},
                {"title": "Gmail Personal", "username": "personal@gmail.com", "password": "pass456", "tag": "Email"},
                {"title": "Outlook Work", "username": "work@outlook.com", "password": "pass789", "tag": "Work"},
                {"title": "Bank of America", "username": "john.doe", "password": "bankpass", "tag": "Bank"},
                {"title": "Chase Credit Card", "username": "jdoe", "password": "chasepass", "tag": "Bank"},
            ]
            for pwd in test_passwords:
                requests.post(f"{BASE_URL}/passwords", json=pwd, headers=headers)
            
            # Create notes
            test_notes = [
                {"title": "Email Settings", "content": "Configure IMAP for Gmail", "folder": "Work"},
                {"title": "Bank Account Numbers", "content": "Routing: 123456789", "folder": "Finance"},
                {"title": "Passport Renewal", "content": "Need to renew by Dec 2024", "folder": "Personal"},
            ]
            for note in test_notes:
                requests.post(f"{BASE_URL}/notes", json=note, headers=headers)
            print("   Test data created.")
        else:
            print("   Test data already exists.")
    
    # Step 3: Warm up the connection (first query is always slower)
    print("\n3. Warming up database connection...")
    requests.get(f"{BASE_URL}/search?q=warmup", headers=headers)
    time.sleep(0.5)
    
    # Step 4: Test performance (multiple searches with warm connection)
    print("\n4. Testing performance (10 consecutive searches)...")
    test_queries = ["google", "email", "bank", "passport", "work", "account", "gmail", "outlook", "chase", "note"]
    times = []
    
    for query in test_queries:
        start = time.perf_counter()  # More precise than time.time()
        response = requests.get(f"{BASE_URL}/search?q={query}", headers=headers)
        elapsed = (time.perf_counter() - start) * 1000
        if response.status_code == 200:
            times.append(elapsed)
            print(f"   '{query}': {elapsed:.2f}ms")
        else:
            print(f"   '{query}': Failed (Status: {response.status_code})")
    
    if times:
        avg_time = sum(times) / len(times)
        max_time = max(times)
        min_time = min(times)
        print(f"\n   Min: {min_time:.2f}ms")
        print(f"   Max: {max_time:.2f}ms")
        print(f"   Avg: {avg_time:.2f}ms")
        
        if max_time < 200:
            print(f"   ✅ PASSED (Target: <200ms)")
        else:
            print(f"   ❌ FAILED (Target: <200ms)")
    
    print("\n" + "=" * 60)
    print("✅ SEARCH MODULE TESTS COMPLETE!")
    print("=" * 60)


if __name__ == "__main__":
    test_search_module()