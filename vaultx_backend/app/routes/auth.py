from fastapi import APIRouter, HTTPException, status
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
        VALUES (?, ?, ?, ?, ?, GETDATE())
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