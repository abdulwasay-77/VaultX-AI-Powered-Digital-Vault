from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel
from typing import Optional, List
from app.utils.hashing import hash_manager
from app.utils.database import db_manager
from app.utils.jwt_handler import jwt_manager

router = APIRouter()

# ==================== REQUEST MODELS ====================

class RegisterRequest(BaseModel):
    master_password: str
    username: str
    email: str
    pin: Optional[str] = None

class LoginRequest(BaseModel):
    email: str
    master_password: str

class LoginResponse(BaseModel):
    message: str
    user_id: int
    username: str
    token: str

class UserInfoResponse(BaseModel):
    user_id: int
    username: str
    email: str
    created_at: str
    has_passwords: bool
    has_documents: bool
    has_notes: bool

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

class SetPinRequest(BaseModel):
    master_password: str
    new_pin: str

class LoginWithPinRequest(BaseModel):
    email: str
    pin: str

class AccountInfoResponse(BaseModel):
    user_id: int
    username: str
    email: str
    created_at: str
    has_pin: bool

# ==================== ENDPOINTS ====================

@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(request: RegisterRequest):
    # Check if username already exists
    check_query = "SELECT COUNT(*) FROM Users WHERE username = ?"
    result = db_manager.execute_query(check_query, (request.username,))
    
    if result and result[0][0] > 0:
        raise HTTPException(status_code=400, detail="Username already exists")
    
    # Check if email already exists
    check_query = "SELECT COUNT(*) FROM Users WHERE email = ?"
    result = db_manager.execute_query(check_query, (request.email,))
    
    if result and result[0][0] > 0:
        raise HTTPException(status_code=400, detail="Email already exists")
    
    # Validate password strength
    if len(request.master_password) < 8:
        raise HTTPException(status_code=400, detail="Master password must be at least 8 characters")
    
    # Validate username
    if len(request.username) < 3:
        raise HTTPException(status_code=400, detail="Username must be at least 3 characters")
    
    # Validate email
    if "@" not in request.email or "." not in request.email:
        raise HTTPException(status_code=400, detail="Invalid email address")
    
    # Hash master password
    hash_val, salt_hex = hash_manager.hash_master_password(request.master_password)
    
    # Hash PIN if provided
    pin_hash = None
    if request.pin:
        if len(request.pin) != 4 or not request.pin.isdigit():
            raise HTTPException(status_code=400, detail="PIN must be 4 digits")
        pin_hash = hash_manager.hash_pin(request.pin)
    
    # Insert user
    insert_query = """
        INSERT INTO Users (master_password_hash, salt, pin_hash, username, email, created_at)
        VALUES (?, ?, ?, ?, ?, datetime('now'))
    """
    params = (hash_val, salt_hex, pin_hash, request.username, request.email)
    
    try:
        db_manager.execute_query(insert_query, params)
        
        # Get the new user ID
        id_query = "SELECT user_id FROM Users WHERE email = ?"
        id_result = db_manager.execute_query(id_query, (request.email,))
        user_id = id_result[0][0] if id_result else 1
        
        # Create token
        token = jwt_manager.create_token(user_id)
        
        return {
            "message": "Vault created successfully!",
            "user_id": user_id,
            "username": request.username,
            "email": request.email,
            "token": token
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")


@router.post("/login", response_model=LoginResponse)
def login(request: LoginRequest):
    # Find user by email
    query = "SELECT user_id, master_password_hash, salt, username FROM Users WHERE email = ?"
    result = db_manager.execute_query(query, (request.email,))
    
    if not result:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    user_id, stored_hash, stored_salt, username = result[0]
    
    if hash_manager.verify_master_password(request.master_password, stored_hash, stored_salt):
        token = jwt_manager.create_token(user_id)
        return LoginResponse(
            message="Login successful",
            user_id=user_id,
            username=username,
            token=token
        )
    else:
        raise HTTPException(status_code=401, detail="Invalid email or password")


@router.get("/users", response_model=List[UserInfoResponse])
def list_users():
    query = "SELECT user_id, username, email, created_at FROM Users ORDER BY created_at"
    results = db_manager.execute_query(query)
    
    users = []
    if results:
        for row in results:
            user_id = row[0]
            username = row[1]
            email = row[2]
            created_at = str(row[3]) if row[3] else ""
            
            # Check if user has data
            pwd_result = db_manager.execute_query("SELECT COUNT(*) FROM Passwords WHERE user_id = ?", (user_id,))
            doc_result = db_manager.execute_query("SELECT COUNT(*) FROM Documents WHERE user_id = ?", (user_id,))
            note_result = db_manager.execute_query("SELECT COUNT(*) FROM Notes WHERE user_id = ?", (user_id,))
            
            pwd_count = pwd_result[0][0] if pwd_result else 0
            doc_count = doc_result[0][0] if doc_result else 0
            note_count = note_result[0][0] if note_result else 0
            
            users.append(UserInfoResponse(
                user_id=user_id,
                username=username,
                email=email,
                created_at=created_at,
                has_passwords=pwd_count > 0,
                has_documents=doc_count > 0,
                has_notes=note_count > 0,
            ))
    
    return users


@router.post("/verify-pin")
def verify_pin(pin: str, email: str):
    query = "SELECT pin_hash FROM Users WHERE email = ?"
    result = db_manager.execute_query(query, (email,))
    
    if not result or not result[0][0]:
        raise HTTPException(status_code=404, detail="PIN not set up")
    
    if hash_manager.verify_pin(pin, result[0][0]):
        return {"message": "PIN verified", "success": True}
    else:
        raise HTTPException(status_code=401, detail="Invalid PIN")


@router.post("/login-pin", response_model=LoginResponse)
def login_with_pin(request: LoginWithPinRequest):
    """Log in using email + 4-digit PIN instead of master password.
    Verifies the PIN hash and, if correct, issues a full JWT token
    identical to the one returned by /login.
    """
    if len(request.pin) != 4 or not request.pin.isdigit():
        raise HTTPException(status_code=400, detail="PIN must be exactly 4 digits")

    query = "SELECT user_id, username, pin_hash FROM Users WHERE email = ?"
    result = db_manager.execute_query(query, (request.email,))

    if not result:
        raise HTTPException(status_code=401, detail="Invalid email or PIN")

    user_id, username, pin_hash = result[0]

    if not pin_hash:
        raise HTTPException(status_code=404, detail="No PIN set for this account. Please log in with your master password.")

    if not hash_manager.verify_pin(request.pin, pin_hash):
        raise HTTPException(status_code=401, detail="Invalid PIN")

    token = jwt_manager.create_token(user_id)
    return LoginResponse(
        message="Login successful",
        user_id=user_id,
        username=username,
        token=token
    )


# ==================== SETTINGS ====================

@router.get("/me", response_model=AccountInfoResponse)
def get_my_account(user_id: int = Depends(jwt_manager.get_current_user)):
    """Returns the currently logged-in user's own account info —
    used by the Settings screen. Unlike GET /users, this is scoped to
    the authenticated user only."""
    query = "SELECT username, email, created_at, pin_hash FROM Users WHERE user_id = ?"
    result = db_manager.execute_query(query, (user_id,))

    if not result:
        raise HTTPException(status_code=404, detail="User not found")

    username, email, created_at, pin_hash = result[0]
    return AccountInfoResponse(
        user_id=user_id,
        username=username,
        email=email,
        created_at=str(created_at) if created_at else "",
        has_pin=pin_hash is not None
    )


@router.post("/change-password")
def change_password(
    request: ChangePasswordRequest,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """Changes the master password used to log in.

    NOTE ON VAULT DATA: the actual encryption key used for stored
    passwords/notes/documents is derived from user_id + a fixed app
    secret (see get_master_key() in passwords.py/notes.py/documents.py/
    backup.py) rather than from the master password itself. That means
    changing the master password here is a pure authentication update —
    it does NOT require re-encrypting any existing vault data, and none
    of it becomes unreadable as a result of this change.
    """
    query = "SELECT master_password_hash, salt FROM Users WHERE user_id = ?"
    result = db_manager.execute_query(query, (user_id,))

    if not result:
        raise HTTPException(status_code=404, detail="User not found")

    stored_hash, stored_salt = result[0]

    if not hash_manager.verify_master_password(request.current_password, stored_hash, stored_salt):
        raise HTTPException(status_code=401, detail="Current password is incorrect")

    if len(request.new_password) < 8:
        raise HTTPException(status_code=400, detail="New password must be at least 8 characters")

    if request.new_password == request.current_password:
        raise HTTPException(status_code=400, detail="New password must be different from the current password")

    new_hash, new_salt_hex = hash_manager.hash_master_password(request.new_password)

    update_query = "UPDATE Users SET master_password_hash = ?, salt = ? WHERE user_id = ?"
    db_manager.execute_query(update_query, (new_hash, new_salt_hex, user_id))

    return {"message": "Master password updated successfully", "success": True}


@router.post("/pin")
def set_or_change_pin(
    request: SetPinRequest,
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """Sets a new PIN or changes an existing one. Requires the current
    master password to confirm identity — this also sidesteps the
    "forgot PIN" problem, since the PIN can always be reset via the
    master password (which the user must already know to be logged in)."""
    query = "SELECT master_password_hash, salt FROM Users WHERE user_id = ?"
    result = db_manager.execute_query(query, (user_id,))

    if not result:
        raise HTTPException(status_code=404, detail="User not found")

    stored_hash, stored_salt = result[0]

    if not hash_manager.verify_master_password(request.master_password, stored_hash, stored_salt):
        raise HTTPException(status_code=401, detail="Master password is incorrect")

    if len(request.new_pin) != 4 or not request.new_pin.isdigit():
        raise HTTPException(status_code=400, detail="PIN must be 4 digits")

    new_pin_hash = hash_manager.hash_pin(request.new_pin)

    update_query = "UPDATE Users SET pin_hash = ? WHERE user_id = ?"
    db_manager.execute_query(update_query, (new_pin_hash, user_id))

    return {"message": "PIN updated successfully", "success": True}