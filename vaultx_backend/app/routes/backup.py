"""
Backup & Restore Module with Smart Merge
Handles export/import of entire vault as encrypted .vaultx files
"""

import os
import json
import base64
from datetime import datetime
from fastapi import APIRouter, HTTPException, status, Depends, Form
from fastapi.responses import FileResponse
from typing import List, Optional
import hashlib

from app.models.schemas import (
    BackupExportResponse, BackupRestoreResponse,
    BackupHistoryItem, BackupVerifyResponse
)
from app.utils.encryption import encryption_manager
from app.utils.database import db_manager
from app.utils.jwt_handler import jwt_manager
from app.config import config

router = APIRouter()


def get_master_key(user_id: int) -> bytes:
    """Get master encryption key for user (for exporting/importing data)"""
    import os as os_env
    secret = os_env.getenv('ENCRYPTION_SECRET', 'vaultx-encryption-secret-key-2024')
    key_material = f"{secret}_{user_id}".encode()
    return hashlib.pbkdf2_hmac('sha256', key_material, b'fixed_salt', 100000, dklen=32)


def bytes_to_base64(data: bytes) -> str:
    """Convert bytes to base64 string for JSON serialization"""
    return base64.b64encode(data).decode('utf-8')


def base64_to_bytes(data: str) -> bytes:
    """Convert base64 string back to bytes"""
    return base64.b64decode(data)


# ==================== SMART MERGE RESTORE ====================

def smart_merge_passwords(user_id: int, backup_passwords: List[dict]) -> dict:
    """
    Smart merge passwords:
    - Keep existing passwords not in backup
    - Update existing passwords if backup version exists
    - Insert new passwords from backup
    """
    restored = 0
    updated = 0
    
    # Get master key for decryption
    key = get_master_key(user_id)
    
    # Get existing passwords from vault with decrypted values
    existing_query = """
        SELECT id, title, username_encrypted, password_encrypted, iv, url, tag, strength_score
        FROM Passwords WHERE user_id = ?
    """
    existing = db_manager.execute_query(existing_query, (user_id,))
    
    # Create a map of existing passwords using decrypted username as key
    existing_map = {}
    for row in existing:
        try:
            # Decrypt username for comparison
            iv = row[4]  # iv column
            decrypted_username = encryption_manager.decrypt(row[2], key, iv)
            key_value = f"{row[1].lower().strip()}_{decrypted_username.lower().strip()}"
            existing_map[key_value] = {
                'id': row[0],
                'title': row[1],
                'username_encrypted': row[2],
                'password_encrypted': row[3],
                'iv': row[4],
                'url': row[5],
                'tag': row[6],
                'strength_score': row[7]
            }
        except Exception as e:
            print(f"Error decrypting existing password: {e}")
            continue
    
    for pwd in backup_passwords:
        # Use decrypted username from backup (it's plaintext in backup)
        decrypted_username = pwd.get('username_plain', '')
        if not decrypted_username:
            # Fallback: decrypt from backup data
            try:
                decrypted_username = encryption_manager.decrypt(
                    base64_to_bytes(pwd['username_encrypted']), 
                    key, 
                    base64_to_bytes(pwd['iv'])
                )
            except:
                decrypted_username = ''
        
        key_value = f"{pwd['title'].lower().strip()}_{decrypted_username.lower().strip()}"
        
        if key_value in existing_map:
            # Password exists - update it (backup wins)
            update_query = """
                UPDATE Passwords 
                SET username_encrypted = ?, password_encrypted = ?, iv = ?, 
                    url = ?, tag = ?, strength_score = ?
                WHERE id = ? AND user_id = ?
            """
            params = (
                base64_to_bytes(pwd['username_encrypted']),
                base64_to_bytes(pwd['password_encrypted']),
                base64_to_bytes(pwd['iv']),
                pwd.get('url'),
                pwd.get('tag'),
                pwd.get('strength_score', 0),
                existing_map[key_value]['id'],
                user_id
            )
            db_manager.execute_query(update_query, params)
            updated += 1
        else:
            # New password - insert it
            insert_query = """
                INSERT INTO Passwords (
                    user_id, title, username_encrypted, password_encrypted, iv, 
                    url, tag, strength_score, created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, GETDATE())
            """
            params = (
                user_id,
                pwd['title'],
                base64_to_bytes(pwd['username_encrypted']),
                base64_to_bytes(pwd['password_encrypted']),
                base64_to_bytes(pwd['iv']),
                pwd.get('url'),
                pwd.get('tag'),
                pwd.get('strength_score', 0)
            )
            db_manager.execute_query(insert_query, params)
            restored += 1
    
    return {'restored': restored, 'updated': updated}


def smart_merge_documents(user_id: int, backup_documents: List[dict]) -> dict:
    """
    Smart merge documents:
    - Keep existing documents not in backup
    - Update existing documents if backup version exists
    - Insert new documents from backup
    """
    restored = 0
    updated = 0
    
    # Get existing documents
    existing_query = """
        SELECT id, file_name, file_path_encrypted, uploaded_at
        FROM Documents WHERE user_id = ?
    """
    existing = db_manager.execute_query(existing_query, (user_id,))
    
    existing_map = {}
    for row in existing:
        existing_map[row[1].lower().strip()] = {
            'id': row[0],
            'file_path_encrypted': row[2],
            'uploaded_at': row[3]
        }
    
    for doc in backup_documents:
        file_name = doc['file_name'].lower().strip()
        
        if file_name in existing_map:
            # Document exists - update it
            old_file_path = existing_map[file_name]['file_path_encrypted']
            if isinstance(old_file_path, bytes):
                old_file_path = old_file_path.decode('utf-8')
            full_old_path = os.path.join(config.BASE_DIR, old_file_path)
            if os.path.exists(full_old_path):
                os.remove(full_old_path)
            
            update_query = """
                UPDATE Documents 
                SET file_path_encrypted = ?, file_size = ?, file_type = ?,
                    sensitivity_score = ?, iv = ?, category = ?
                WHERE id = ? AND user_id = ?
            """
            params = (
                base64_to_bytes(doc['file_path_encrypted']),
                doc['file_size'],
                doc['file_type'],
                doc['sensitivity_score'],
                base64_to_bytes(doc['iv']),
                doc.get('category'),
                existing_map[file_name]['id'],
                user_id
            )
            db_manager.execute_query(update_query, params)
            updated += 1
        else:
            # New document - insert it
            insert_query = """
                INSERT INTO Documents (
                    user_id, file_name, file_path_encrypted, file_size, file_type,
                    sensitivity_score, iv, category, uploaded_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, GETDATE())
            """
            params = (
                user_id,
                doc['file_name'],
                base64_to_bytes(doc['file_path_encrypted']),
                doc['file_size'],
                doc['file_type'],
                doc['sensitivity_score'],
                base64_to_bytes(doc['iv']),
                doc.get('category')
            )
            db_manager.execute_query(insert_query, params)
            restored += 1
    
    return {'restored': restored, 'updated': updated}


def smart_merge_notes(user_id: int, backup_notes: List[dict]) -> dict:
    """
    Smart merge notes:
    - Keep existing notes not in backup
    - Update existing notes if backup version exists
    - Insert new notes from backup
    """
    restored = 0
    updated = 0
    
    # Get existing notes
    existing_query = """
        SELECT id, title, content_encrypted, iv, folder
        FROM Notes WHERE user_id = ?
    """
    existing = db_manager.execute_query(existing_query, (user_id,))
    
    existing_map = {}
    for row in existing:
        existing_map[row[1].lower().strip()] = {
            'id': row[0],
            'content_encrypted': row[2],
            'iv': row[3],
            'folder': row[4]
        }
    
    for note in backup_notes:
        title = note['title'].lower().strip()
        
        if title in existing_map:
            # Note exists - update it
            update_query = """
                UPDATE Notes 
                SET content_encrypted = ?, iv = ?, folder = ?
                WHERE id = ? AND user_id = ?
            """
            params = (
                base64_to_bytes(note['content_encrypted']),
                base64_to_bytes(note['iv']),
                note.get('folder'),
                existing_map[title]['id'],
                user_id
            )
            db_manager.execute_query(update_query, params)
            updated += 1
        else:
            # New note - insert it
            insert_query = """
                INSERT INTO Notes (
                    user_id, title, content_encrypted, iv, folder, created_at
                )
                VALUES (?, ?, ?, ?, ?, GETDATE())
            """
            params = (
                user_id,
                note['title'],
                base64_to_bytes(note['content_encrypted']),
                base64_to_bytes(note['iv']),
                note.get('folder')
            )
            db_manager.execute_query(insert_query, params)
            restored += 1
    
    return {'restored': restored, 'updated': updated}


# ==================== BACKUP ENDPOINTS ====================

@router.post("/backup/export", response_model=BackupExportResponse)
def export_backup(
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Export entire vault as an encrypted .vaultx file
    """
    key = get_master_key(user_id)
    
    # Get all passwords with decrypted values for backup
    passwords_query = """
        SELECT id, title, username_encrypted, password_encrypted, iv, url, tag, strength_score, created_at
        FROM Passwords WHERE user_id = ?
    """
    passwords_result = db_manager.execute_query(passwords_query, (user_id,))
    
    passwords = []
    if passwords_result:
        for row in passwords_result:
            # Decrypt username to store plaintext in backup (for comparison during restore)
            try:
                decrypted_username = encryption_manager.decrypt(row[2], key, row[4])
            except:
                decrypted_username = ''
            
            passwords.append({
                "title": row[1],
                "username_encrypted": bytes_to_base64(row[2]),
                "password_encrypted": bytes_to_base64(row[3]),
                "iv": bytes_to_base64(row[4]),
                "url": row[5],
                "tag": row[6],
                "strength_score": row[7],
                "created_at": str(row[8]) if row[8] else None,
                "username_plain": decrypted_username  # Store plaintext for restore comparison
            })
    
    # Get all documents
    documents_query = """
        SELECT file_name, file_path_encrypted, file_size, file_type, sensitivity_score, iv, category, uploaded_at
        FROM Documents WHERE user_id = ?
    """
    documents_result = db_manager.execute_query(documents_query, (user_id,))
    
    documents = []
    if documents_result:
        for row in documents_result:
            documents.append({
                "file_name": row[0],
                "file_path_encrypted": bytes_to_base64(row[1]),
                "file_size": row[2],
                "file_type": row[3],
                "sensitivity_score": row[4],
                "iv": bytes_to_base64(row[5]),
                "category": row[6],
                "uploaded_at": str(row[7]) if row[7] else None
            })
    
    # Get all notes
    notes_query = """
        SELECT title, content_encrypted, iv, folder, created_at
        FROM Notes WHERE user_id = ?
    """
    notes_result = db_manager.execute_query(notes_query, (user_id,))
    
    notes = []
    if notes_result:
        for row in notes_result:
            notes.append({
                "title": row[0],
                "content_encrypted": bytes_to_base64(row[1]),
                "iv": bytes_to_base64(row[2]),
                "folder": row[3],
                "created_at": str(row[4]) if row[4] else None
            })
    
    # Create backup data structure
    backup_data = {
        "version": "1.0",
        "exported_at": datetime.now().isoformat(),
        "user_id": user_id,
        "passwords": passwords,
        "documents": documents,
        "notes": notes
    }
    
    # Convert to JSON string
    json_data = json.dumps(backup_data, indent=2)
    
    # Generate random IV for backup encryption
    backup_iv = encryption_manager.generate_iv()
    
    # Encrypt the backup data
    encrypted_data = encryption_manager.encrypt(json_data, key, backup_iv)
    
    # Create .vaultx file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"vaultx_backup_{timestamp}.vaultx"
    backup_path = os.path.join(config.BACKUPS_DIR, backup_filename)
    
    # Write encrypted backup file
    with open(backup_path, 'wb') as f:
        f.write(b"VAULTX_BACKUP_V1\n")
        f.write(backup_iv)
        f.write(encrypted_data)
        f.write(b"\nVAULTX_END")
    
    file_size = os.path.getsize(backup_path)
    
    # Save to backup history
    history_query = """
        INSERT INTO Backups (user_id, backup_file_path, file_size, created_at)
        VALUES (?, ?, ?, GETDATE())
    """
    db_manager.execute_query(history_query, (user_id, backup_path, file_size))
    
    return BackupExportResponse(
        message="Backup created successfully",
        file_path=backup_path,
        file_size=file_size,
        created_at=datetime.now(),
        includes={
            "passwords": len(passwords),
            "documents": len(documents),
            "notes": len(notes)
        }
    )


@router.post("/backup/restore", response_model=BackupRestoreResponse)
def restore_backup(
    backup_file_path: str = Form(...),
    master_password: str = Form(...),
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Restore vault from a .vaultx backup file using SMART MERGE
    - Keeps all existing data
    - Restores missing items from backup
    - Updates existing items with backup version
    - NO DATA LOSS
    """
    # Validate file exists
    if not os.path.exists(backup_file_path):
        raise HTTPException(status_code=404, detail="Backup file not found")
    
    # Read backup file
    with open(backup_file_path, 'rb') as f:
        content = f.read()
    
    # Parse backup file
    try:
        if not content.startswith(b"VAULTX_BACKUP_V1\n"):
            raise ValueError("Invalid backup file format")
        
        header_end = content.find(b"\n") + 1
        iv_start = header_end
        iv = content[iv_start:iv_start + 16]
        
        data_start = iv_start + 16
        signature_start = content.find(b"\nVAULTX_END")
        if signature_start == -1:
            raise ValueError("Invalid backup file: missing signature")
        
        encrypted_data = content[data_start:signature_start]
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid backup file: {str(e)}")
    
    # Get encryption key
    key = get_master_key(user_id)
    
    # Decrypt backup
    try:
        decrypted_data = encryption_manager.decrypt(encrypted_data, key, iv)
        backup_json = json.loads(decrypted_data)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Failed to decrypt backup: {str(e)}")
    
    # Verify this backup belongs to this user
    if backup_json.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Backup belongs to a different user")
    
    # Perform SMART MERGE (not overwrite)
    passwords_result = smart_merge_passwords(user_id, backup_json.get("passwords", []))
    documents_result = smart_merge_documents(user_id, backup_json.get("documents", []))
    notes_result = smart_merge_notes(user_id, backup_json.get("notes", []))
    
    return BackupRestoreResponse(
        message="Backup restored successfully using smart merge",
        restored={
            "passwords": passwords_result['restored'],
            "documents": documents_result['restored'],
            "notes": notes_result['restored'],
            "passwords_updated": passwords_result['updated'],
            "documents_updated": documents_result['updated'],
            "notes_updated": notes_result['updated']
        },
        mode="merge"
    )


@router.get("/backup/history", response_model=List[BackupHistoryItem])
def get_backup_history(
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    List all backup history for the user
    """
    query = """
        SELECT id, backup_file_path, file_size, created_at
        FROM Backups WHERE user_id = ?
        ORDER BY created_at DESC
    """
    results = db_manager.execute_query(query, (user_id,))
    
    history = []
    if results:
        for row in results:
            history.append(BackupHistoryItem(
                id=row[0],
                backup_file_path=row[1],
                file_size=row[2],
                created_at=row[3]
            ))
    
    return history


@router.get("/backup/history/{backup_id}", response_model=BackupHistoryItem)
def get_backup_details(
    backup_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Get details of a specific backup
    """
    query = """
        SELECT id, backup_file_path, file_size, created_at
        FROM Backups WHERE id = ? AND user_id = ?
    """
    result = db_manager.execute_query(query, (backup_id, user_id))
    
    if not result:
        raise HTTPException(status_code=404, detail="Backup record not found")
    
    row = result[0]
    return BackupHistoryItem(
        id=row[0],
        backup_file_path=row[1],
        file_size=row[2],
        created_at=row[3]
    )


@router.delete("/backup/history/{backup_id}", response_model=dict)
def delete_backup_record(
    backup_id: int,
    delete_file: bool = True,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Delete a backup record (and optionally the file)
    """
    # Get backup file path first
    query = "SELECT backup_file_path FROM Backups WHERE id = ? AND user_id = ?"
    result = db_manager.execute_query(query, (backup_id, user_id))
    
    if not result:
        raise HTTPException(status_code=404, detail="Backup record not found")
    
    backup_path = result[0][0]
    
    # Delete from database
    delete_query = "DELETE FROM Backups WHERE id = ? AND user_id = ?"
    rows_affected = db_manager.execute_query(delete_query, (backup_id, user_id))
    
    if rows_affected == 0:
        raise HTTPException(status_code=404, detail="Backup record not found")
    
    # Delete the physical file if requested
    file_deleted = False
    if delete_file and os.path.exists(backup_path):
        os.remove(backup_path)
        file_deleted = True
    
    return {
        "message": "Backup record deleted successfully",
        "file_deleted": file_deleted
    }


@router.post("/backup/verify", response_model=BackupVerifyResponse)
def verify_backup(
    backup_file_path: str = Form(...),
    master_password: str = Form(...),
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Verify a backup file without restoring
    Checks if file is valid and belongs to current user
    """
    if not os.path.exists(backup_file_path):
        return BackupVerifyResponse(valid=False, error="Backup file not found")
    
    with open(backup_file_path, 'rb') as f:
        content = f.read()
    
    try:
        if not content.startswith(b"VAULTX_BACKUP_V1\n"):
            return BackupVerifyResponse(valid=False, error="Invalid backup file format")
        
        signature_start = content.find(b"\nVAULTX_END")
        if signature_start == -1:
            return BackupVerifyResponse(valid=False, error="Missing signature")
        
        header_end = content.find(b"\n") + 1
        iv_start = header_end
        iv = content[iv_start:iv_start + 16]
        
        data_start = iv_start + 16
        encrypted_data = content[data_start:signature_start]
        
        key = get_master_key(user_id)
        decrypted_data = encryption_manager.decrypt(encrypted_data, key, iv)
        backup_json = json.loads(decrypted_data)
        
        # Check if backup belongs to current user
        if backup_json.get("user_id") != user_id:
            return BackupVerifyResponse(valid=False, error="Backup belongs to a different user")
        
        return BackupVerifyResponse(
            valid=True,
            version=backup_json.get("version", "1.0"),
            exported_at=backup_json.get("exported_at"),
            contains={
                "passwords": len(backup_json.get("passwords", [])),
                "documents": len(backup_json.get("documents", [])),
                "notes": len(backup_json.get("notes", []))
            }
        )
    except Exception as e:
        return BackupVerifyResponse(valid=False, error=f"Invalid backup: {str(e)}")


@router.get("/backup/download/{backup_id}")
def download_backup_file(
    backup_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Download a backup file (returns the actual .vaultx file)
    """
    query = "SELECT backup_file_path FROM Backups WHERE id = ? AND user_id = ?"
    result = db_manager.execute_query(query, (backup_id, user_id))
    
    if not result:
        raise HTTPException(status_code=404, detail="Backup record not found")
    
    backup_path = result[0][0]
    
    if not os.path.exists(backup_path):
        raise HTTPException(status_code=404, detail="Backup file not found on disk")
    
    filename = os.path.basename(backup_path)
    
    return FileResponse(
        path=backup_path,
        filename=filename,
        media_type="application/octet-stream"
    )