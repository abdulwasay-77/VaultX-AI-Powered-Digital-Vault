"""
Password Vault Routes
CRUD operations for password entries with encryption
"""

from fastapi import APIRouter, HTTPException, status, Depends
from typing import List, Dict, Any
from app.models.schemas import (
    PasswordCreateRequest, PasswordUpdateRequest, 
    PasswordResponse, PasswordListItem,
    PasswordStrengthResponse, PasswordGenerateRequest,
    PasswordGenerateResponse, RiskReportResponse
)
from app.services.irbe import password_engine, risk_engine
from app.utils.encryption import encryption_manager
from app.utils.database import db_manager
from app.utils.jwt_handler import jwt_manager
from app.utils.hashing import hash_manager
import hashlib
import os

router = APIRouter()


# ==================== HELPER FUNCTIONS ====================

def get_master_key(user_id: int) -> bytes:
    """
    Get the master encryption key for a user
    In production, this would be derived from master password on login
    For demo, we derive from user_id and a fixed secret
    """
    # Use a combination of user_id and a secret to derive key
    secret = os.getenv('ENCRYPTION_SECRET', 'vaultx-encryption-secret-key-2024')
    key_material = f"{secret}_{user_id}".encode()
    return hashlib.pbkdf2_hmac('sha256', key_material, b'fixed_salt', 100000, dklen=32)


# ==================== PASSWORD CRUD ENDPOINTS ====================

@router.post("/passwords", response_model=dict, status_code=status.HTTP_201_CREATED)
def create_password(
    request: PasswordCreateRequest,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Create a new password entry
    - Encrypts username and password using AES-256
    - Stores strength score from IRBE analysis
    """
    # Validate password exists
    if not request.password:
        raise HTTPException(status_code=400, detail="Password cannot be empty")
    
    # Analyze password strength
    strength = password_engine.analyze_strength(request.password)
    
    # Get encryption key
    key = get_master_key(user_id)
    
    # Generate unique IV for this entry
    iv = encryption_manager.generate_iv()
    
    # Encrypt username and password
    encrypted_username = encryption_manager.encrypt(request.username, key, iv)
    encrypted_password = encryption_manager.encrypt(request.password, key, iv)
    
    # Insert into database - simplified version without OUTPUT
    query = """
        INSERT INTO Passwords (
            user_id, title, username_encrypted, password_encrypted, 
            iv, url, tag, strength_score, risk_flag, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, GETDATE())
    """
    params = (
        user_id, request.title, encrypted_username, encrypted_password,
        iv, request.url, request.tag, strength.score
    )
    
    try:
        # Execute insert
        db_manager.execute_query(query, params)
        
        # Get the inserted ID using a separate SELECT
        id_query = "SELECT MAX(id) FROM Passwords WHERE user_id = ?"
        id_result = db_manager.execute_query(id_query, (user_id,))
        
        new_id = None
        if id_result and len(id_result) > 0 and id_result[0][0]:
            new_id = int(id_result[0][0])
        
        return {
            "message": "Password saved successfully",
            "id": new_id,
            "strength_score": strength.score,
            "strength_category": strength.category
        }
    except Exception as e:
        print(f"Error saving password: {str(e)}")  # For debugging
        raise HTTPException(status_code=500, detail=f"Failed to save password: {str(e)}")

@router.get("/passwords", response_model=List[PasswordListItem])
def list_passwords(
    tag: str = None,
    search: str = None,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    List all password entries for the user
    - Filter by tag if provided
    - Search by title if provided
    """
    query = "SELECT id, title, tag, strength_score, risk_flag, created_at FROM Passwords WHERE user_id = ?"
    params = [user_id]
    
    if tag:
        query += " AND tag = ?"
        params.append(tag)
    
    if search:
        query += " AND title LIKE ?"
        params.append(f"%{search}%")
    
    query += " ORDER BY created_at DESC"
    
    results = db_manager.execute_query(query, tuple(params))
    
    passwords = []
    if results:
        for row in results:
            passwords.append(PasswordListItem(
                id=row[0],
                title=row[1],
                tag=row[2],
                strength_score=row[3],
                risk_flag=bool(row[4]),
                created_at=row[5]
            ))
    
    return passwords


@router.get("/passwords/{password_id}", response_model=PasswordResponse)
def get_password(
    password_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Get a single password entry (decrypted)
    """
    query = """
        SELECT id, title, username_encrypted, password_encrypted, iv, url, tag, strength_score, risk_flag, created_at
        FROM Passwords 
        WHERE id = ? AND user_id = ?
    """
    result = db_manager.execute_query(query, (password_id, user_id))
    
    if not result:
        raise HTTPException(status_code=404, detail="Password entry not found")
    
    row = result[0]
    
    # Get encryption key and decrypt
    key = get_master_key(user_id)
    iv = row[4]  # bytes from database
    
    try:
        username = encryption_manager.decrypt(row[2], key, iv)
        password = encryption_manager.decrypt(row[3], key, iv)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Decryption failed: {str(e)}")
    
    return PasswordResponse(
        id=row[0],
        title=row[1],
        username=username,
        password=password,
        url=row[5],
        tag=row[6],
        strength_score=row[7],
        risk_flag=bool(row[8]),
        created_at=row[9]
    )


@router.put("/passwords/{password_id}", response_model=dict)
def update_password(
    password_id: int,
    request: PasswordUpdateRequest,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Update an existing password entry
    """
    # First check if entry exists
    check_query = "SELECT id FROM Passwords WHERE id = ? AND user_id = ?"
    exists = db_manager.execute_query(check_query, (password_id, user_id))
    
    if not exists:
        raise HTTPException(status_code=404, detail="Password entry not found")
    
    # Build update query dynamically based on what fields are provided
    updates = []
    params = []
    
    if request.title is not None:
        updates.append("title = ?")
        params.append(request.title)
    
    if request.username is not None:
        # Need to re-encrypt with new IV
        key = get_master_key(user_id)
        iv = encryption_manager.generate_iv()
        encrypted_username = encryption_manager.encrypt(request.username, key, iv)
        updates.append("username_encrypted = ?")
        params.append(encrypted_username)
        updates.append("iv = ?")
        params.append(iv)
    
    if request.password is not None:
        # Re-encrypt and update strength score
        key = get_master_key(user_id)
        iv = encryption_manager.generate_iv() 
        encrypted_password = encryption_manager.encrypt(request.password, key, iv)
        updates.append("password_encrypted = ?")
        params.append(encrypted_password)
        updates.append("iv = ?")
        params.append(iv)
        
        # Update strength score
        strength = password_engine.analyze_strength(request.password)
        updates.append("strength_score = ?")
        params.append(strength.score)
    
    if request.url is not None:
        updates.append("url = ?")
        params.append(request.url)
    
    if request.tag is not None:
        updates.append("tag = ?")
        params.append(request.tag)
    
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    # Execute update
    query = f"UPDATE Passwords SET {', '.join(updates)} WHERE id = ? AND user_id = ?"
    params.append(password_id)
    params.append(user_id)
    
    try:
        db_manager.execute_query(query, tuple(params))
        return {"message": "Password updated successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Update failed: {str(e)}")


@router.delete("/passwords/{password_id}", response_model=dict)
def delete_password(
    password_id: int,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Delete a password entry
    """
    query = "DELETE FROM Passwords WHERE id = ? AND user_id = ?"
    rows_affected = db_manager.execute_query(query, (password_id, user_id))
    
    if rows_affected == 0:
        raise HTTPException(status_code=404, detail="Password entry not found")
    
    return {"message": "Password deleted successfully"}


# ==================== IRBE ENDPOINTS ====================

@router.post("/irbe/password-strength", response_model=PasswordStrengthResponse)
def analyze_password_strength(request: dict):
    """
    Real-time password strength analysis
    Called as user types in Flutter
    Expects: {"password": "the_password_to_check"}
    """
    password = request.get("password", "")
    if not password:
        raise HTTPException(status_code=400, detail="Password field required")
    return password_engine.analyze_strength(password)


@router.post("/irbe/password-generate", response_model=PasswordGenerateResponse)
def generate_passwords(request: PasswordGenerateRequest):
    """
    Generate strong password suggestions
    Returns 3 suggestions with strength analysis
    """
    suggestions = password_engine.generate_multiple_suggestions(
        length=request.length,
        use_uppercase=request.use_uppercase,
        use_lowercase=request.use_lowercase,
        use_numbers=request.use_numbers,
        use_symbols=request.use_symbols,
        avoid_ambiguous=request.avoid_ambiguous,
        count=3
    )
    
    # Analyze strength of first suggestion
    strength = password_engine.analyze_strength(suggestions[0])
    
    return PasswordGenerateResponse(
        suggestions=suggestions,
        strength=strength
    )


@router.get("/irbe/risk-report", response_model=RiskReportResponse)
def get_risk_report(
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Get comprehensive security risk report
    Includes weak passwords, reused passwords, and health score
    """
    # Get all passwords
    query = """
        SELECT id, title, password_encrypted, iv, strength_score, tag, created_at
        FROM Passwords 
        WHERE user_id = ?
    """
    results = db_manager.execute_query(query, (user_id,))
    
    if not results:
        return RiskReportResponse(
            health_score=100,
            total_passwords=0,
            weak_passwords=[],
            reused_passwords=[],
            strong_passwords_count=0,
            moderate_passwords_count=0,
            weak_passwords_count=0
        )
    
    # Get weak passwords
    weak_entries = risk_engine.get_weak_passwords(user_id)
    
    # Convert weak entries to PasswordListItem
    weak_passwords = []
    for entry in weak_entries:
        weak_passwords.append(PasswordListItem(
            id=entry['id'],
            title=entry['title'],
            tag=entry.get('tag'),
            strength_score=entry['strength_score'],
            risk_flag=True,
            created_at=entry['created_at']
        ))
    
    # Count by strength category
    strong_count = 0
    moderate_count = 0
    weak_count = 0
    
    for row in results:
        score = row[4]
        if score >= 70:
            strong_count += 1
        elif score >= 40:
            moderate_count += 1
        else:
            weak_count += 1
    
    # Calculate health score
    health_score = risk_engine.calculate_health_score(user_id)
    
    reused_passwords = []
    
    return RiskReportResponse(
        health_score=health_score,
        total_passwords=len(results),
        weak_passwords=weak_passwords,
        reused_passwords=reused_passwords,
        strong_passwords_count=strong_count,
        moderate_passwords_count=moderate_count,
        weak_passwords_count=weak_count
    )


@router.post("/irbe/check-reuse")
def check_password_reuse(
    request: dict,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Check if a password is already used elsewhere in the vault
    Returns list of entries using the same password
    """
    password = request.get("password", "")
    if not password:
        raise HTTPException(status_code=400, detail="Password field required")
    
    # Get all passwords
    query = """
        SELECT id, title, password_encrypted, iv
        FROM Passwords 
        WHERE user_id = ?
    """
    results = db_manager.execute_query(query, (user_id,))
    
    if not results:
        return {"reused": False, "entries": []}
    
    key = get_master_key(user_id)
    matches = []
    
    for row in results:
        try:
            existing_password = encryption_manager.decrypt(row[2], key, row[3])
            if existing_password == password:
                matches.append({
                    "id": row[0],
                    "title": row[1]
                })
        except Exception:
            continue
    
    return {
        "reused": len(matches) > 0,
        "count": len(matches),
        "entries": matches
    }