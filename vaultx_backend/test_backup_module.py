"""
Test script for Backup & Restore Module
Run this after starting the server
"""

import requests
import os
import json

BASE_URL = "http://localhost:8000/api"

def test_backup_module():
    print("=" * 60)
    print("TESTING BACKUP & RESTORE MODULE")
    print("=" * 60)
    
    # Step 1: Login
    print("\n1. Logging in...")
    login_response = requests.post(
        f"{BASE_URL}/auth/login",
        json={"master_password": "MyStrongPass123!"}
    )
    
    if login_response.status_code != 200:
        print("   Login failed! Registering first...")
        register_response = requests.post(
            f"{BASE_URL}/auth/register",
            json={"master_password": "MyStrongPass123!", "pin": "1234"}
        )
        print(f"   Register response: {register_response.status_code}")
        login_response = requests.post(
            f"{BASE_URL}/auth/login",
            json={"master_password": "MyStrongPass123!"}
        )
    
    if login_response.status_code != 200:
        print(f"   ❌ Login failed: {login_response.text}")
        return
    
    token = login_response.json().get("token")
    headers = {"Authorization": f"Bearer {token}"}
    print(f"   ✅ Login successful!")
    
    # Step 2: Create test data
    print("\n2. Creating test data for backup...")
    
    # Create a password
    pwd_response = requests.post(
        f"{BASE_URL}/passwords",
        json={
            "title": "Backup Test Password",
            "username": "backup_test@example.com",
            "password": "TestPass123!",
            "url": "https://backuptest.com",
            "tag": "Other"
        },
        headers=headers
    )
    print(f"   Created password: {pwd_response.status_code}")
    
    # Create a note
    note_response = requests.post(
        f"{BASE_URL}/notes",
        json={
            "title": "Backup Test Note",
            "content": "This note is for testing backup and restore functionality.",
            "folder": "BackupTest"
        },
        headers=headers
    )
    print(f"   Created note: {note_response.status_code}")
    
    # Step 3: Export backup
    print("\n3. Exporting backup...")
    export_response = requests.post(
        f"{BASE_URL}/backup/export",
        headers=headers
    )
    
    if export_response.status_code == 200:
        backup_data = export_response.json()
        print(f"   ✅ Backup created!")
        print(f"   File path: {backup_data['file_path']}")
        print(f"   File size: {backup_data['file_size']} bytes")
        print(f"   Includes: {backup_data['includes']}")
        backup_path = backup_data['file_path']
    else:
        print(f"   ❌ Export failed: {export_response.text}")
        return
    
    # Step 4: Get backup history
    print("\n4. Getting backup history...")
    history_response = requests.get(
        f"{BASE_URL}/backup/history",
        headers=headers
    )
    
    if history_response.status_code == 200:
        history = history_response.json()
        print(f"   Found {len(history)} backup(s) in history")
        for h in history:
            print(f"     - ID: {h['id']}, Size: {h['file_size']} bytes, Date: {h['created_at']}")
            backup_id = h['id']
    else:
        print(f"   ❌ History failed: {history_response.text}")
    
    # Step 5: Verify backup
    print("\n5. Verifying backup file...")
    verify_response = requests.post(
        f"{BASE_URL}/backup/verify",
        data={"backup_file_path": backup_path},
        headers=headers
    )
    
    if verify_response.status_code == 200:
        verify_data = verify_response.json()
        print(f"   Valid: {verify_data['valid']}")
        if verify_data['valid']:
            print(f"   Version: {verify_data['version']}")
        else:
            print(f"   Error: {verify_data.get('error')}")
    else:
        print(f"   ❌ Verify failed: {verify_response.text}")
    
    # Step 6: Restore from backup (overwrite mode)
    print("\n6. Restoring from backup (overwrite mode)...")
    
    # First, delete existing data to test restore
    print("   Deleting existing notes to test restore...")
    notes_response = requests.get(f"{BASE_URL}/notes", headers=headers)
    if notes_response.status_code == 200:
        for note in notes_response.json():
            requests.delete(f"{BASE_URL}/notes/{note['id']}", headers=headers)
    
    # Now restore
    restore_response = requests.post(
        f"{BASE_URL}/backup/restore",
        data={
            "backup_file_path": backup_path,
            "master_password": "MyStrongPass123!",
            "overwrite": "true"
        },
        headers=headers
    )
    
    if restore_response.status_code == 200:
        restore_data = restore_response.json()
        print(f"   ✅ Restore successful!")
        print(f"   Mode: {restore_data['mode']}")
        print(f"   Restored: {restore_data['restored']}")
    else:
        print(f"   ❌ Restore failed: {restore_response.text}")
    
    # Step 7: Verify restored data
    print("\n7. Verifying restored data...")
    
    # Check passwords
    pwd_list = requests.get(f"{BASE_URL}/passwords", headers=headers)
    if pwd_list.status_code == 200:
        passwords = pwd_list.json()
        print(f"   Passwords after restore: {len(passwords)}")
    
    # Check notes
    note_list = requests.get(f"{BASE_URL}/notes", headers=headers)
    if note_list.status_code == 200:
        notes = note_list.json()
        print(f"   Notes after restore: {len(notes)}")
        for note in notes:
            if note['title'] == "Backup Test Note":
                print(f"   ✅ Backup Test Note found!")
    
    # Step 8: Try restore with wrong password
    print("\n8. Testing restore with wrong password...")
    wrong_restore = requests.post(
        f"{BASE_URL}/backup/restore",
        data={
            "backup_file_path": backup_path,
            "master_password": "WrongPassword123!",
            "overwrite": "true"
        },
        headers=headers
    )
    
    if wrong_restore.status_code == 401:
        print(f"   ✅ Correctly rejected wrong password")
    else:
        print(f"   ⚠️ Wrong password returned: {wrong_restore.status_code}")
    
    # Step 9: Get backup details
    if 'backup_id' in dir():
        print(f"\n9. Getting backup details (ID: {backup_id})...")
        detail_response = requests.get(
            f"{BASE_URL}/backup/history/{backup_id}",
            headers=headers
        )
        
        if detail_response.status_code == 200:
            detail = detail_response.json()
            print(f"   Backup ID: {detail['id']}")
            print(f"   File path: {detail['backup_file_path']}")
            print(f"   Size: {detail['file_size']} bytes")
        else:
            print(f"   ❌ Detail failed: {detail_response.text}")
    
    # Step 10: Delete backup record
    if 'backup_id' in dir():
        print(f"\n10. Deleting backup record (ID: {backup_id})...")
        delete_response = requests.delete(
            f"{BASE_URL}/backup/history/{backup_id}",
            headers=headers
        )
        
        if delete_response.status_code == 200:
            print(f"   ✅ Backup record deleted: {delete_response.json()}")
        else:
            print(f"   ❌ Delete failed: {delete_response.text}")
    
    # Step 11: Verify backup history after deletion
    print("\n11. Verifying backup history after deletion...")
    final_history = requests.get(f"{BASE_URL}/backup/history", headers=headers)
    if final_history.status_code == 200:
        history = final_history.json()
        print(f"   Remaining backups: {len(history)}")
    
    print("\n" + "=" * 60)
    print("✅ BACKUP MODULE TESTS COMPLETE!")
    print("=" * 60)

if __name__ == "__main__":
    test_backup_module()