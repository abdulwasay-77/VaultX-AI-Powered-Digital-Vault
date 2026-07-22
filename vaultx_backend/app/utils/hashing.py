import hashlib
import secrets
from passlib.context import CryptContext
from app.config import config

# Use sha256_crypt instead of bcrypt (no 72-byte limit, no bcrypt issues)
pwd_context = CryptContext(schemes=["sha256_crypt"], deprecated="auto")

class HashManager:
    @staticmethod
    def hash_master_password(password: str, salt: bytes = None) -> tuple:
        """Hash master password with PBKDF2"""
        if salt is None:
            salt = secrets.token_bytes(config.SALT_SIZE)
        
        key = hashlib.pbkdf2_hmac(
            'sha256',
            password.encode('utf-8'),
            salt,
            config.PBKDF2_ITERATIONS,
            dklen=32
        )
        
        hash_hex = key.hex()
        salt_hex = salt.hex()
        
        return hash_hex, salt_hex
    
    @staticmethod
    def verify_master_password(password: str, stored_hash_hex: str, stored_salt_hex: str) -> bool:
        """Verify master password against stored hash"""
        salt = bytes.fromhex(stored_salt_hex)
        
        computed_key = hashlib.pbkdf2_hmac(
            'sha256',
            password.encode('utf-8'),
            salt,
            config.PBKDF2_ITERATIONS,
            dklen=32
        )
        
        return computed_key.hex() == stored_hash_hex
    
    @staticmethod
    def hash_pin(pin: str) -> str:
        """Hash PIN using sha256_crypt (no 72-byte limit)"""
        return pwd_context.hash(pin)
    
    @staticmethod
    def verify_pin(pin: str, hashed_pin: str) -> bool:
        """Verify PIN against stored hash"""
        return pwd_context.verify(pin, hashed_pin)
    
    @staticmethod
    def generate_totp_secret() -> str:
        """Generate secret for 2FA (future use)"""
        return secrets.token_hex(20)

hash_manager = HashManager()