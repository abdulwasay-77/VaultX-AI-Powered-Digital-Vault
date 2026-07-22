"""
Test script for Document Management Module
Run this after starting the server
"""

import requests
import os
import base64

BASE_URL = "http://localhost:8000/api"

def test_document_module():
    print("=" * 60)
    print("TESTING DOCUMENT MANAGEMENT MODULE")
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
    
    # Step 2: Test File Sensitivity Analysis
    print("\n2. Testing File Sensitivity Analysis...")
    
    test_files = [
        "passport_scan.pdf",
        "invoice_123.pdf",
        "vacation_photo.jpg"
    ]
    
    for file_name in test_files:
        sensitivity_response = requests.post(
            f"{BASE_URL}/irbe/file-sensitivity",
            json={"file_name": file_name}
        )
        print(f"   {file_name}: {sensitivity_response.json()}")
    
    # Step 3: Create a test file
    print("\n3. Creating test file...")
    test_file_path = "test_upload.txt"
    with open(test_file_path, "w") as f:
        f.write("This is a test document for VaultX encryption.\n")
        f.write("It contains sensitive information for testing.\n")
        f.write("Line 3 of test content.")
    
    print(f"   Created test file: {test_file_path}")
    
    # Step 4: Upload document
    print("\n4. Uploading document...")
    with open(test_file_path, "rb") as f:
        files = {"file": (test_file_path, f, "text/plain")}
        data = {"category": "Other"}
        
        upload_response = requests.post(
            f"{BASE_URL}/documents/upload",
            files=files,
            data=data,
            headers=headers
        )
    
    if upload_response.status_code == 200:
        doc_data = upload_response.json()
        print(f"   ✅ Upload successful!")
        print(f"   Document ID: {doc_data['id']}")
        print(f"   File Name: {doc_data['file_name']}")
        print(f"   Sensitivity: {doc_data['sensitivity_score']} ({doc_data['sensitivity_color']})")
        print(f"   Reason: {doc_data['sensitivity_reason']}")
        document_id = doc_data['id']
    else:
        print(f"   ❌ Upload failed: {upload_response.text}")
        # Clean up test file
        if os.path.exists(test_file_path):
            os.remove(test_file_path)
        return
    
    # Step 5: List all documents
    print("\n5. Listing all documents...")
    list_response = requests.get(f"{BASE_URL}/documents", headers=headers)
    if list_response.status_code == 200:
        docs = list_response.json()
        print(f"   Found {len(docs)} document(s):")
        for doc in docs:
            print(f"     - {doc['file_name']} ({doc['file_size']} bytes) - {doc['sensitivity_score']}")
    else:
        print(f"   ❌ Failed: {list_response.text}")
    
    # Step 6: Get document metadata
    print(f"\n6. Getting document metadata (ID: {document_id})...")
    metadata_response = requests.get(f"{BASE_URL}/documents/{document_id}", headers=headers)
    if metadata_response.status_code == 200:
        metadata = metadata_response.json()
        print(f"   File: {metadata['file_name']}")
        print(f"   Size: {metadata['file_size']} bytes")
        print(f"   Type: {metadata['file_type']}")
        print(f"   Category: {metadata['category']}")
    else:
        print(f"   ❌ Failed: {metadata_response.text}")
    
    # Step 7: Preview document
    print(f"\n7. Previewing document (ID: {document_id})...")
    preview_response = requests.get(f"{BASE_URL}/documents/{document_id}/preview", headers=headers)
    if preview_response.status_code == 200:
        print(f"   ✅ Preview available!")
        print(f"   Content preview (first 200 chars):")
        content = preview_response.text[:200]
        print(f"   {content}...")
    else:
        print(f"   ❌ Preview failed: {preview_response.text}")
    
    # Step 8: Download document
    print(f"\n8. Downloading document (ID: {document_id})...")
    download_response = requests.get(f"{BASE_URL}/documents/{document_id}/download", headers=headers)
    if download_response.status_code == 200:
        # Save downloaded file
        download_path = "downloaded_test.txt"
        with open(download_path, "wb") as f:
            f.write(download_response.content)
        print(f"   ✅ Downloaded to: {download_path}")
        
        # Verify content matches
        with open(test_file_path, "r") as original:
            original_content = original.read()
        with open(download_path, "r") as downloaded:
            downloaded_content = downloaded.read()
        
        if original_content == downloaded_content:
            print(f"   ✅ Content verification PASSED (files match)")
        else:
            print(f"   ❌ Content verification FAILED")
        
        # Clean up downloaded file
        os.remove(download_path)
    else:
        print(f"   ❌ Download failed: {download_response.text}")
    
    # Step 9: Delete document
    print(f"\n9. Deleting document (ID: {document_id})...")
    delete_response = requests.delete(f"{BASE_URL}/documents/{document_id}", headers=headers)
    if delete_response.status_code == 200:
        print(f"   ✅ Document deleted: {delete_response.json()}")
    else:
        print(f"   ❌ Delete failed: {delete_response.text}")
    
    # Step 10: Verify deletion
    print("\n10. Verifying deletion...")
    verify_response = requests.get(f"{BASE_URL}/documents", headers=headers)
    if verify_response.status_code == 200:
        docs = verify_response.json()
        print(f"   Remaining documents: {len(docs)}")
    
    # Clean up
    if os.path.exists(test_file_path):
        os.remove(test_file_path)
        print("\n   🧹 Cleaned up test files")
    
    print("\n" + "=" * 60)
    print("✅ DOCUMENT MODULE TESTS COMPLETE!")
    print("=" * 60)

if __name__ == "__main__":
    test_document_module()