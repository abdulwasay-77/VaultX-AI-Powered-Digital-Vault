"""
Document Management Routes
Handles upload, storage, preview, and export of encrypted documents
"""

import os
import uuid
from fastapi import APIRouter, HTTPException, status, Depends, File, UploadFile, Form
from fastapi.responses import StreamingResponse
from typing import List, Optional
from io import BytesIO

from app.models.schemas import (
    DocumentUploadResponse, DocumentListItem, DocumentResponse,
    FileSensitivityResponse, DocumentDeleteResponse
)
from app.services.irbe import FileSensitivityClassifier
from app.utils.encryption import encryption_manager
from app.utils.database import db_manager
from app.utils.jwt_handler import jwt_manager
from app.config import config

router = APIRouter()

# Allowed file extensions
ALLOWED_EXTENSIONS = {
    'video': ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm'],
    'audio': ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'],
    'image': ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff', 'webp'],
    'pdf': ['pdf'],
    'document': ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'odt']
}

MAX_FILE_SIZE = 500 * 1024 * 1024  # 100 MB


def get_master_key(user_id: int) -> bytes:
    """Get master encryption key for user"""
    import hashlib
    import os as os_env
    secret = os_env.getenv('ENCRYPTION_SECRET', 'vaultx-encryption-secret-key-2024')
    key_material = f"{secret}_{user_id}".encode()
    return hashlib.pbkdf2_hmac('sha256', key_material, b'fixed_salt', 100000, dklen=32)


def is_file_allowed(filename: str) -> tuple:
    """Check if file type is allowed"""
    ext = filename.split('.')[-1].lower() if '.' in filename else ''
    
    for file_type, extensions in ALLOWED_EXTENSIONS.items():
        if ext in extensions:
            return True, file_type
    
    return False, 'other'


@router.post("/documents/upload", response_model=DocumentUploadResponse)
async def upload_document(
    file: UploadFile = File(...),
    category: str = Form(...),
    delete_original: bool = Form(True),
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Upload, encrypt, and store a document
    Original file is DELETED after encryption (handled by frontend)
    """
    
    # Validate category
    allowed_categories = ['IDs', 'Certificates', 'Contracts', 'Finance', 'Other']
    if category not in allowed_categories:
        raise HTTPException(status_code=400, detail=f"Category must be one of: {', '.join(allowed_categories)}")
    
    # Check file type
    is_allowed, file_type = is_file_allowed(file.filename)
    if not is_allowed:
        raise HTTPException(status_code=400, detail=f"File type not allowed")
    
    # Read file content
    file_content = await file.read()
    file_size = len(file_content)
    
    # Check file size
    if file_size > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail=f"File too large. Max size: {MAX_FILE_SIZE // (1024*1024)} MB")
    
    # IRBE Sensitivity Analysis
    sensitivity = FileSensitivityClassifier.classify_sensitivity(file.filename)
    
    # Get encryption key
    key = get_master_key(user_id)
    
    # Generate unique IV for this file
    iv = encryption_manager.generate_iv()
    
    # Encrypt file content in memory
    encrypted_content = encryption_manager.encrypt(file_content, key, iv)
    
    # Generate unique filename for encrypted storage
    unique_id = str(uuid.uuid4())
    encrypted_filename = f"{unique_id}.encrypted"
    encrypted_file_path = os.path.join(config.UPLOADS_DIR, encrypted_filename)
    
    # Save encrypted file to disk
    with open(encrypted_file_path, 'wb') as f:
        f.write(encrypted_content)
    
    # Store relative path in database
    relative_path = f"uploads/{encrypted_filename}"
    
    # Insert into database
    insert_query = """
        INSERT INTO Documents (
            user_id, file_name, file_path_encrypted, file_size, file_type,
            sensitivity_score, iv, category, uploaded_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, GETDATE())
    """
    params = (
        user_id, file.filename, relative_path.encode('utf-8'), file_size,
        file_type, sensitivity['sensitivity'], iv, category
    )
    
    try:
        # Execute insert
        db_manager.execute_query(insert_query, params)
        
        # Get the inserted ID
        id_query = "SELECT MAX(id) FROM Documents WHERE user_id = ?"
        id_result = db_manager.execute_query(id_query, (user_id,))
        
        document_id = None
        if id_result and len(id_result) > 0 and id_result[0][0]:
            document_id = int(id_result[0][0])
        
        return DocumentUploadResponse(
            id=document_id,
            file_name=file.filename,
            file_size=file_size,
            file_type=file_type,
            sensitivity_score=sensitivity['sensitivity'],
            sensitivity_color=sensitivity['color'],
            sensitivity_reason=sensitivity['reason'],
            category=category,
            message="File uploaded and encrypted successfully",
            original_deleted=False
        )
    except Exception as e:
        # Clean up encrypted file if database insert fails
        if os.path.exists(encrypted_file_path):
            os.remove(encrypted_file_path)
        raise HTTPException(status_code=500, detail=f"Failed to save document: {str(e)}")


@router.get("/documents", response_model=List[DocumentListItem])
def list_documents(
    category: Optional[str] = None,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    List all documents for the user
    Filter by category if provided
    """
    query = """
        SELECT id, file_name, file_size, file_type, sensitivity_score, category, uploaded_at
        FROM Documents WHERE user_id = ?
    """
    params = [user_id]
    
    if category:
        query += " AND category = ?"
        params.append(category)
    
    query += " ORDER BY uploaded_at DESC"
    
    results = db_manager.execute_query(query, tuple(params))
    
    documents = []
    if results:
        for row in results:
            # Get color for sensitivity
            sensitivity = row[4]
            color = "green" if sensitivity == "Low" else "amber" if sensitivity == "Medium" else "red"
            
            documents.append(DocumentListItem(
                id=row[0],
                file_name=row[1],
                file_size=row[2],
                file_type=row[3],
                sensitivity_score=sensitivity,
                sensitivity_color=color,
                category=row[5],
                uploaded_at=row[6]
            ))
    
    return documents


@router.get("/documents/{document_id}", response_model=DocumentResponse)
def get_document_metadata(
    document_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Get document metadata (not the file content)
    """
    query = """
        SELECT id, file_name, file_size, file_type, sensitivity_score, category, uploaded_at
        FROM Documents WHERE id = ? AND user_id = ?
    """
    result = db_manager.execute_query(query, (document_id, user_id))
    
    if not result:
        raise HTTPException(status_code=404, detail="Document not found")
    
    row = result[0]
    
    return DocumentResponse(
        id=row[0],
        file_name=row[1],
        file_size=row[2],
        file_type=row[3],
        sensitivity_score=row[4],
        category=row[5],
        uploaded_at=row[6]
    )


@router.get("/documents/{document_id}/preview")
def preview_document(
    document_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Preview a document (decrypt in memory, stream to client)
    No file is written to disk
    """
    # Get document info
    query = """
        SELECT id, file_name, file_path_encrypted, iv, file_type, sensitivity_score
        FROM Documents WHERE id = ? AND user_id = ?
    """
    result = db_manager.execute_query(query, (document_id, user_id))
    
    if not result:
        raise HTTPException(status_code=404, detail="Document not found")
    
    row = result[0]
    file_name = row[1]
    file_path_encrypted = row[2].decode('utf-8') if isinstance(row[2], bytes) else row[2]
    iv = row[3]
    
    # Get full path to encrypted file
    full_path = os.path.join(config.BASE_DIR, file_path_encrypted)
    
    if not os.path.exists(full_path):
        raise HTTPException(status_code=404, detail="Encrypted file not found on disk")
    
    # Read encrypted file
    with open(full_path, 'rb') as f:
        encrypted_content = f.read()
    
    # Get encryption key
    key = get_master_key(user_id)
    
    # Decrypt in memory (as bytes for files)
    try:
        decrypted_content = encryption_manager.decrypt_to_bytes(encrypted_content, key, iv)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Decryption failed: {str(e)}")
    
    # Determine MIME type for preview
    ext = file_name.split('.')[-1].lower() if '.' in file_name else ''
    mime_types = {
        'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
        'gif': 'image/gif', 'bmp': 'image/bmp', 'webp': 'image/webp',
        'pdf': 'application/pdf', 'txt': 'text/plain',
        'mp4': 'video/mp4', 'mp3': 'audio/mpeg'
    }
    media_type = mime_types.get(ext, 'application/octet-stream')
    
    # Stream decrypted content
    return StreamingResponse(
        BytesIO(decrypted_content),
        media_type=media_type,
        headers={
            "Content-Disposition": f"inline; filename={file_name}"
        }
    )


@router.get("/documents/{document_id}/download")
def download_document(
    document_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Download/Export a document
    Decrypts and sends file for Save Dialog (frontend handles save location)
    """
    # Get document info
    query = """
        SELECT id, file_name, file_path_encrypted, iv, file_size, file_type
        FROM Documents WHERE id = ? AND user_id = ?
    """
    result = db_manager.execute_query(query, (document_id, user_id))
    
    if not result:
        raise HTTPException(status_code=404, detail="Document not found")
    
    row = result[0]
    file_name = row[1]
    file_path_encrypted = row[2].decode('utf-8') if isinstance(row[2], bytes) else row[2]
    iv = row[3]
    
    # Get full path to encrypted file
    full_path = os.path.join(config.BASE_DIR, file_path_encrypted)
    
    if not os.path.exists(full_path):
        raise HTTPException(status_code=404, detail="Encrypted file not found on disk")
    
    # Read encrypted file
    with open(full_path, 'rb') as f:
        encrypted_content = f.read()
    
    # Get encryption key
    key = get_master_key(user_id)
    
    # Decrypt in memory (as bytes for files)
    try:
        decrypted_content = encryption_manager.decrypt_to_bytes(encrypted_content, key, iv)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Decryption failed: {str(e)}")
    
    # Stream for download (frontend will show Save Dialog)
    return StreamingResponse(
        BytesIO(decrypted_content),
        media_type='application/octet-stream',
        headers={
            "Content-Disposition": f"attachment; filename={file_name}"
        }
    )


@router.delete("/documents/{document_id}", response_model=DocumentDeleteResponse)
def delete_document(
    document_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Delete a document from vault
    Removes encrypted file from disk and database record
    """
    # Get document info first
    query = "SELECT file_name, file_path_encrypted FROM Documents WHERE id = ? AND user_id = ?"
    result = db_manager.execute_query(query, (document_id, user_id))
    
    if not result:
        raise HTTPException(status_code=404, detail="Document not found")
    
    file_name = result[0][0]
    file_path_encrypted = result[0][1].decode('utf-8') if isinstance(result[0][1], bytes) else result[0][1]
    
    # Delete from database
    delete_query = "DELETE FROM Documents WHERE id = ? AND user_id = ?"
    rows_affected = db_manager.execute_query(delete_query, (document_id, user_id))
    
    if rows_affected == 0:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Delete encrypted file from disk
    full_path = os.path.join(config.BASE_DIR, file_path_encrypted)
    if os.path.exists(full_path):
        os.remove(full_path)
    
    return DocumentDeleteResponse(
        message="Document deleted successfully",
        id=document_id,
        file_name=file_name
    )


@router.post("/irbe/file-sensitivity", response_model=FileSensitivityResponse)
def analyze_file_sensitivity(request: dict):
    """
    Analyze file sensitivity based on filename
    Called before upload to check if confirmation is needed
    """
    file_name = request.get("file_name", "")
    if not file_name:
        raise HTTPException(status_code=400, detail="file_name field required")
    
    result = FileSensitivityClassifier.classify_sensitivity(file_name)
    return FileSensitivityResponse(
        sensitivity=result['sensitivity'],
        color=result['color'],
        reason=result['reason'],
        requires_confirmation=result['requires_confirmation']
    )