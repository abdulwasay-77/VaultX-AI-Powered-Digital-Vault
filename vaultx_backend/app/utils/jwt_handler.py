"""
JWT (JSON Web Token) Handler for VaultX
Manages user authentication tokens after login
"""

from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from fastapi import HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.config import config

# Security scheme for Bearer tokens
security = HTTPBearer()


class JWTManager:
    """Handles JWT token creation and verification"""
    
    @staticmethod
    def create_token(user_id: int) -> str:
        """
        Create a new JWT token for authenticated user
        
        Args:
            user_id: Database user ID
        
        Returns:
            Encoded JWT token string
        """
        # Set expiration time
        expire = datetime.utcnow() + timedelta(minutes=config.ACCESS_TOKEN_EXPIRE_MINUTES)
        
        # Token payload (data to encode)
        payload = {
            "user_id": user_id,
            "exp": expire,
            "iat": datetime.utcnow(),  # Issued at time
            "type": "access"
        }
        
        # Encode token
        token = jwt.encode(
            payload, 
            config.SECRET_KEY, 
            algorithm=config.ALGORITHM
        )
        
        # FIX: python-jose 3.x returns bytes instead of string
        # Convert to string if necessary
        if isinstance(token, bytes):
            token = token.decode('utf-8')
        
        return token
    
    @staticmethod
    def verify_token(token: str) -> Optional[int]:
        """
        Verify JWT token and extract user_id
        
        Args:
            token: JWT token string
        
        Returns:
            user_id if valid, None if invalid
        """
        try:
            # Decode and verify token
            payload = jwt.decode(
                token, 
                config.SECRET_KEY, 
                algorithms=[config.ALGORITHM]
            )
            
            # Extract user_id
            user_id = payload.get("user_id")
            
            # Check if token is expired
            exp = payload.get("exp")
            if exp and datetime.utcnow() > datetime.fromtimestamp(exp):
                return None
            
            return user_id
            
        except JWTError as e:
            print(f"JWT Verification error: {e}")
            return None
    
    @staticmethod
    def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> int:
        """
        Dependency for FastAPI routes to get current authenticated user
        
        Usage: 
            @router.get("/protected")
            def protected_route(user_id: int = Depends(jwt_manager.get_current_user)):
                # user_id is the authenticated user
        
        Raises:
            HTTPException 401 if token invalid
        """
        token = credentials.credentials
        user_id = JWTManager.verify_token(token)
        
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        return user_id


# Create singleton instance
jwt_manager = JWTManager()