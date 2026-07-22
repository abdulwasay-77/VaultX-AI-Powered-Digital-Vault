"""
Test script for Notes Management Module
Run this after starting the server
"""

import requests
import json

BASE_URL = "http://localhost:8000/api"

def test_notes_module():
    print("=" * 60)
    print("TESTING NOTES MANAGEMENT MODULE")
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
    
    # Step 2: Create a note
    print("\n2. Creating a note...")
    create_response = requests.post(
        f"{BASE_URL}/notes",
        json={
            "title": "Meeting Notes",
            "content": "This is a **test note** with:\n- Bullet point 1\n- Bullet point 2\n\n## Subheading\nRegular text here.",
            "folder": "Work"
        },
        headers=headers
    )
    
    if create_response.status_code == 201:
        note_data = create_response.json()
        print(f"   ✅ Note created!")
        print(f"   ID: {note_data['id']}")
        print(f"   Title: {note_data['title']}")
        print(f"   Folder: {note_data['folder']}")
        note_id = note_data['id']
    else:
        print(f"   ❌ Create failed: {create_response.text}")
        return
    
    # Step 3: Create another note in different folder
    print("\n3. Creating another note...")
    create_response2 = requests.post(
        f"{BASE_URL}/notes",
        json={
            "title": "Shopping List",
            "content": "Milk, Eggs, Bread, Butter",
            "folder": "Personal"
        },
        headers=headers
    )
    
    if create_response2.status_code == 201:
        note_data2 = create_response2.json()
        print(f"   ✅ Second note created! ID: {note_data2['id']}")
        note_id2 = note_data2['id']
    else:
        print(f"   ❌ Create failed: {create_response2.text}")
    
    # Step 4: Create third note without folder
    print("\n4. Creating note without folder...")
    create_response3 = requests.post(
        f"{BASE_URL}/notes",
        json={
            "title": "Quick Idea",
            "content": "This is a random idea I had.",
            "folder": None
        },
        headers=headers
    )
    
    if create_response3.status_code == 201:
        note_data3 = create_response3.json()
        print(f"   ✅ Third note created! ID: {note_data3['id']}")
        note_id3 = note_data3['id']
    else:
        print(f"   ❌ Create failed: {create_response3.text}")
    
    # Step 5: List all notes
    print("\n5. Listing all notes...")
    list_response = requests.get(f"{BASE_URL}/notes", headers=headers)
    if list_response.status_code == 200:
        notes = list_response.json()
        print(f"   Found {len(notes)} note(s):")
        for note in notes:
            print(f"     - {note['title']} (Folder: {note['folder'] or 'Uncategorized'})")
    else:
        print(f"   ❌ List failed: {list_response.text}")
    
    # Step 6: Filter notes by folder
    print("\n6. Filtering notes by folder 'Work'...")
    filter_response = requests.get(f"{BASE_URL}/notes?folder=Work", headers=headers)
    if filter_response.status_code == 200:
        notes = filter_response.json()
        print(f"   Found {len(notes)} note(s) in Work folder:")
        for note in notes:
            print(f"     - {note['title']}")
    else:
        print(f"   ❌ Filter failed: {filter_response.text}")
    
    # Step 7: Get single note
    print(f"\n7. Getting note ID {note_id}...")
    get_response = requests.get(f"{BASE_URL}/notes/{note_id}", headers=headers)
    if get_response.status_code == 200:
        note = get_response.json()
        print(f"   Title: {note['title']}")
        print(f"   Folder: {note['folder']}")
        print(f"   Content preview: {note['content'][:100]}...")
        print(f"   Updated: {note['updated_at']}")
    else:
        print(f"   ❌ Get failed: {get_response.text}")
    
    # Step 8: Update note
    print(f"\n8. Updating note ID {note_id}...")
    update_response = requests.put(
        f"{BASE_URL}/notes/{note_id}",
        json={
            "title": "Updated Meeting Notes",
            "content": "This content has been UPDATED!\nNew information here.",
            "folder": "Important"
        },
        headers=headers
    )
    if update_response.status_code == 200:
        updated = update_response.json()
        print(f"   ✅ Note updated!")
        print(f"   New title: {updated['title']}")
        print(f"   New folder: {updated['folder']}")
    else:
        print(f"   ❌ Update failed: {update_response.text}")
    
    # Step 9: List all folders
    print("\n9. Listing all folders...")
    folders_response = requests.get(f"{BASE_URL}/notes/folders/all", headers=headers)
    if folders_response.status_code == 200:
        folders = folders_response.json()
        print(f"   Folders: {folders.get('folders', [])}")
    else:
        print(f"   ❌ Folders list failed: {folders_response.text}")
    
    # Step 10: Move note to different folder
    print(f"\n10. Moving note ID {note_id2} to 'Archive' folder...")
    move_response = requests.put(
        f"{BASE_URL}/notes/{note_id2}/folder",
        json={"folder": "Archive"},
        headers=headers
    )
    if move_response.status_code == 200:
        print(f"   ✅ Note moved: {move_response.json()}")
    else:
        print(f"   ❌ Move failed: {move_response.text}")
    
    # Step 11: Delete a note
    print(f"\n11. Deleting note ID {note_id3}...")
    delete_response = requests.delete(f"{BASE_URL}/notes/{note_id3}", headers=headers)
    if delete_response.status_code == 200:
        print(f"   ✅ Note deleted: {delete_response.json()}")
    else:
        print(f"   ❌ Delete failed: {delete_response.text}")
    
    # Step 12: Verify deletion
    print("\n12. Verifying deletion...")
    verify_response = requests.get(f"{BASE_URL}/notes", headers=headers)
    if verify_response.status_code == 200:
        notes = verify_response.json()
        print(f"   Remaining notes: {len(notes)}")
    
    print("\n" + "=" * 60)
    print("✅ NOTES MODULE TESTS COMPLETE!")
    print("=" * 60)

if __name__ == "__main__":
    test_notes_module()