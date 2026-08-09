"""
Notes Management Routes
Handles CRUD operations for encrypted rich-text notes
Also manages folders with proper database table
"""

from fastapi import APIRouter, HTTPException, status, Depends
from typing import List, Optional
from datetime import datetime

from app.models.schemas import (
    NoteCreateRequest, NoteUpdateRequest, NoteResponse,
    NoteListItem, FolderCreateRequest, FolderResponse,
    FolderListResponse, FolderDeleteRequest
)
from app.utils.encryption import encryption_manager
from app.utils.database import db_manager
from app.utils.jwt_handler import jwt_manager

router = APIRouter()


def get_master_key(user_id: int) -> bytes:
    """Get master encryption key for user"""
    import hashlib
    import os
    secret = os.getenv('ENCRYPTION_SECRET', 'vaultx-encryption-secret-key-2024')
    key_material = f"{secret}_{user_id}".encode()
    return hashlib.pbkdf2_hmac('sha256', key_material, b'fixed_salt', 100000, dklen=32)


# ==================== FOLDER MANAGEMENT (NEW - Using Folders Table) ====================

@router.post("/notes/folders", response_model=FolderResponse, status_code=status.HTTP_201_CREATED)
def create_folder(
    request: FolderCreateRequest,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Create a new folder (stores in Folders table)
    """
    folder_name = request.name.strip()
    
    # Check if folder already exists for this user
    check_query = "SELECT id FROM Folders WHERE user_id = ? AND name = ?"
    existing = db_manager.execute_query(check_query, (user_id, folder_name))
    
    if existing and len(existing) > 0:
        raise HTTPException(status_code=400, detail=f"Folder '{folder_name}' already exists")
    
    # Insert new folder
    insert_query = """
        INSERT INTO Folders (user_id, name, created_at)
        VALUES (?, ?, datetime('now'))
    """
    
    try:
        db_manager.execute_query(insert_query, (user_id, folder_name))
        
        # Get the inserted folder
        get_query = "SELECT id, name, created_at FROM Folders WHERE user_id = ? AND name = ?"
        result = db_manager.execute_query(get_query, (user_id, folder_name))
        
        if result:
            row = result[0]
            return FolderResponse(
                id=row[0],
                name=row[1],
                created_at=row[2]
            )
        else:
            raise HTTPException(status_code=500, detail="Failed to create folder")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create folder: {str(e)}")


@router.get("/notes/folders/all", response_model=FolderListResponse)
def list_folders(
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    List all folders for the user (from Folders table)
    """
    query = """
        SELECT id, name, created_at 
        FROM Folders 
        WHERE user_id = ? 
        ORDER BY name
    """
    results = db_manager.execute_query(query, (user_id,))
    
    folders = []
    if results:
        for row in results:
            folders.append(FolderResponse(
                id=row[0],
                name=row[1],
                created_at=row[2]
            ))
    
    return FolderListResponse(folders=folders)


@router.get("/notes/folders/{folder_id}", response_model=FolderResponse)
def get_folder(
    folder_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Get a single folder by ID
    """
    query = "SELECT id, name, created_at FROM Folders WHERE id = ? AND user_id = ?"
    result = db_manager.execute_query(query, (folder_id, user_id))
    
    if not result:
        raise HTTPException(status_code=404, detail="Folder not found")
    
    row = result[0]
    return FolderResponse(
        id=row[0],
        name=row[1],
        created_at=row[2]
    )


@router.delete("/notes/folders/{folder_name}")
def delete_folder(
    folder_name: str,
    move_to: Optional[str] = None,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Delete a folder (from Folders table)
    Moves notes from deleted folder to another folder or Uncategorized
    """
    folder_name = folder_name.strip()
    
    # Check if folder exists
    check_query = "SELECT id FROM Folders WHERE user_id = ? AND name = ?"
    folder_exists = db_manager.execute_query(check_query, (user_id, folder_name))
    
    if not folder_exists:
        raise HTTPException(status_code=404, detail="Folder not found")
    
    # Determine where to move notes
    target_folder = move_to if move_to and move_to.strip() else None
    
    # Move notes from the deleted folder
    update_query = """
        UPDATE Notes 
        SET folder = ?, updated_at = datetime('now')
        WHERE user_id = ? AND folder = ?
    """
    db_manager.execute_query(update_query, (target_folder, user_id, folder_name))
    
    # Delete the folder from Folders table
    delete_query = "DELETE FROM Folders WHERE user_id = ? AND name = ?"
    db_manager.execute_query(delete_query, (user_id, folder_name))
    
    return {
        "message": f"Folder '{folder_name}' deleted successfully",
        "notes_moved_to": target_folder or "Uncategorized"
    }


# ==================== NOTE CRUD OPERATIONS (Updated with folder validation) ====================

@router.post("/notes", response_model=NoteResponse, status_code=status.HTTP_201_CREATED)
def create_note(
    request: NoteCreateRequest,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Create a new encrypted note
    Automatically creates folder in Folders table if it doesn't exist
    """
    # Validate folder name
    folder = request.folder if request.folder and request.folder.strip() else None
    if folder:
        folder = folder.strip()
        
        # Check if folder exists in Folders table, create if not
        check_query = "SELECT id FROM Folders WHERE user_id = ? AND name = ?"
        existing = db_manager.execute_query(check_query, (user_id, folder))
        
        if not existing or len(existing) == 0:
            # Auto-create the folder
            insert_folder_query = """
                INSERT INTO Folders (user_id, name, created_at)
                VALUES (?, ?, datetime('now'))
            """
            try:
                db_manager.execute_query(insert_folder_query, (user_id, folder))
            except Exception as e:
                # Folder might have been created by another request
                print(f"Note: Folder may already exist: {e}")
    
    # Get encryption key
    key = get_master_key(user_id)
    
    # Generate unique IV for this note
    iv = encryption_manager.generate_iv()
    
    # Encrypt content
    encrypted_content = encryption_manager.encrypt(request.content, key, iv)
    
    # Insert into database
    query = """
        INSERT INTO Notes (user_id, title, content_encrypted, iv, folder, updated_at, created_at)
        VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))
    """
    params = (user_id, request.title, encrypted_content, iv, folder)
    
    try:
        db_manager.execute_query(query, params)
        
        id_query = "SELECT MAX(id) FROM Notes WHERE user_id = ?"
        id_result = db_manager.execute_query(id_query, (user_id,))
        note_id = int(id_result[0][0]) if id_result and id_result[0][0] else None
        
        if note_id is None:
            raise HTTPException(status_code=500, detail="Failed to get note ID")
        
        return NoteResponse(
            id=note_id,
            title=request.title,
            content=request.content,
            folder=folder,
            updated_at=datetime.now(),
            created_at=datetime.now()
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create note: {str(e)}")


@router.get("/notes", response_model=List[NoteListItem])
def list_notes(
    folder: Optional[str] = None,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    List all notes for the user
    Filter by folder if provided
    """
    query = "SELECT id, title, folder, updated_at, created_at FROM Notes WHERE user_id = ?"
    params = [user_id]
    
    if folder:
        if folder == "Uncategorized":
            query += " AND (folder IS NULL OR folder = '')"
        else:
            query += " AND folder = ?"
            params.append(folder)
    
    query += " ORDER BY updated_at DESC"
    
    results = db_manager.execute_query(query, tuple(params))
    
    notes = []
    if results:
        for row in results:
            notes.append(NoteListItem(
                id=row[0],
                title=row[1],
                folder=row[2] if row[2] else None,
                updated_at=row[3],
                created_at=row[4]
            ))
    
    return notes


@router.get("/notes/{note_id}", response_model=NoteResponse)
def get_note(
    note_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Get a single note (decrypted content)
    """
    query = """
        SELECT id, title, content_encrypted, iv, folder, updated_at, created_at
        FROM Notes WHERE id = ? AND user_id = ?
    """
    result = db_manager.execute_query(query, (note_id, user_id))
    
    if not result:
        raise HTTPException(status_code=404, detail="Note not found")
    
    row = result[0]
    iv = row[3]
    encrypted_content = row[2]
    
    key = get_master_key(user_id)
    try:
        decrypted_content = encryption_manager.decrypt(encrypted_content, key, iv)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Decryption failed: {str(e)}")
    
    return NoteResponse(
        id=row[0],
        title=row[1],
        content=decrypted_content,
        folder=row[4] if row[4] else None,
        updated_at=row[5],
        created_at=row[6]
    )


@router.put("/notes/{note_id}", response_model=NoteResponse)
def update_note(
    note_id: int,
    request: NoteUpdateRequest,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Update an existing note
    Re-encrypts content if changed
    """
    check_query = "SELECT id FROM Notes WHERE id = ? AND user_id = ?"
    exists = db_manager.execute_query(check_query, (note_id, user_id))
    
    if not exists:
        raise HTTPException(status_code=404, detail="Note not found")
    
    current_query = "SELECT title, content_encrypted, iv, folder FROM Notes WHERE id = ? AND user_id = ?"
    current = db_manager.execute_query(current_query, (note_id, user_id))
    
    if not current:
        raise HTTPException(status_code=404, detail="Note not found")
    
    current_row = current[0]
    current_title = current_row[0]
    current_encrypted = current_row[1]
    current_iv = current_row[2]
    current_folder = current_row[3]
    
    new_title = request.title if request.title is not None else current_title
    new_folder = request.folder if request.folder is not None else current_folder
    if new_folder and not new_folder.strip():
        new_folder = None
    
    # If folder changed, ensure it exists in Folders table
    if new_folder and new_folder != current_folder:
        check_folder_query = "SELECT id FROM Folders WHERE user_id = ? AND name = ?"
        folder_exists = db_manager.execute_query(check_folder_query, (user_id, new_folder))
        
        if not folder_exists or len(folder_exists) == 0:
            # Create the folder
            insert_folder_query = """
                INSERT INTO Folders (user_id, name, created_at)
                VALUES (?, ?, datetime('now'))
            """
            try:
                db_manager.execute_query(insert_folder_query, (user_id, new_folder))
            except Exception as e:
                print(f"Note: Could not create folder: {e}")
    
    key = get_master_key(user_id)
    
    if request.content is not None:
        new_iv = encryption_manager.generate_iv()
        new_encrypted = encryption_manager.encrypt(request.content, key, new_iv)
        
        update_query = """
            UPDATE Notes 
            SET title = ?, content_encrypted = ?, iv = ?, folder = ?, updated_at = datetime('now')
            WHERE id = ? AND user_id = ?
        """
        params = (new_title, new_encrypted, new_iv, new_folder, note_id, user_id)
    else:
        update_query = """
            UPDATE Notes 
            SET title = ?, folder = ?, updated_at = datetime('now')
            WHERE id = ? AND user_id = ?
        """
        params = (new_title, new_folder, note_id, user_id)
    
    try:
        db_manager.execute_query(update_query, params)
        return get_note(note_id, user_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update note: {str(e)}")


@router.delete("/notes/{note_id}", response_model=dict)
def delete_note(
    note_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Delete a note
    """
    query = "DELETE FROM Notes WHERE id = ? AND user_id = ?"
    rows_affected = db_manager.execute_query(query, (note_id, user_id))
    
    if rows_affected == 0:
        raise HTTPException(status_code=404, detail="Note not found")
    
    return {"message": "Note deleted successfully", "id": note_id}


@router.put("/notes/{note_id}/folder", response_model=dict)
def move_note_to_folder(
    note_id: int,
    request: dict,  # {'folder': 'folder_name'}
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Move a note to a different folder
    """
    folder = request.get('folder', '')
    folder = folder.strip() if folder else None
    
    check_query = "SELECT id FROM Notes WHERE id = ? AND user_id = ?"
    exists = db_manager.execute_query(check_query, (note_id, user_id))
    
    if not exists:
        raise HTTPException(status_code=404, detail="Note not found")
    
    # If moving to a non-empty folder, ensure it exists in Folders table
    if folder:
        check_folder_query = "SELECT id FROM Folders WHERE user_id = ? AND name = ?"
        folder_exists = db_manager.execute_query(check_folder_query, (user_id, folder))
        
        if not folder_exists or len(folder_exists) == 0:
            # Create the folder
            insert_folder_query = """
                INSERT INTO Folders (user_id, name, created_at)
                VALUES (?, ?, datetime('now'))
            """
            try:
                db_manager.execute_query(insert_folder_query, (user_id, folder))
            except Exception as e:
                print(f"Note: Could not create folder while moving note: {e}")
    
    update_query = """
        UPDATE Notes 
        SET folder = ?, updated_at = datetime('now')
        WHERE id = ? AND user_id = ?
    """
    db_manager.execute_query(update_query, (folder, note_id, user_id))
    
    return {
        "message": "Note moved successfully",
        "note_id": note_id,
        "folder": folder or "Uncategorized"
    }