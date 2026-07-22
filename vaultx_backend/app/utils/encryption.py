import os
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
from app.config import config

class EncryptionManager:
    def __init__(self):
        self.backend = default_backend()
    
    def derive_key(self, master_password: str, salt: bytes) -> bytes:
        """Derive AES-256 key from master password using PBKDF2"""
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=config.KEY_SIZE,
            salt=salt,
            iterations=config.PBKDF2_ITERATIONS,
            backend=self.backend
        )
        return kdf.derive(master_password.encode('utf-8'))
    
    def generate_salt(self) -> bytes:
        return os.urandom(config.SALT_SIZE)
    
    def generate_iv(self) -> bytes:
        return os.urandom(config.IV_SIZE)
    
    def encrypt(self, plaintext, key: bytes, iv: bytes) -> bytes:
        """AES-256-CBC encryption with PKCS7 padding (for strings)"""
        # Convert to bytes if it's a string
        if isinstance(plaintext, str):
            plaintext = plaintext.encode('utf-8')
        elif not isinstance(plaintext, bytes):
            plaintext = str(plaintext).encode('utf-8')
        
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=self.backend)
        encryptor = cipher.encryptor()
        
        pad_length = 16 - (len(plaintext) % 16)
        padded_data = plaintext + bytes([pad_length] * pad_length)
        
        return encryptor.update(padded_data) + encryptor.finalize()
    
    def decrypt(self, encrypted_data: bytes, key: bytes, iv: bytes) -> str:
        """AES-256-CBC decryption returning string (for text data)"""
        if isinstance(encrypted_data, str):
            encrypted_data = encrypted_data.encode('utf-8')
        
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=self.backend)
        decryptor = cipher.decryptor()
        
        decrypted_padded = decryptor.update(encrypted_data) + decryptor.finalize()
        pad_length = decrypted_padded[-1]
        decrypted = decrypted_padded[:-pad_length]
        return decrypted.decode('utf-8')
    
    def decrypt_to_bytes(self, encrypted_data: bytes, key: bytes, iv: bytes) -> bytes:
        """AES-256-CBC decryption returning bytes (for files, images, videos)"""
        if isinstance(encrypted_data, str):
            encrypted_data = encrypted_data.encode('utf-8')
        
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=self.backend)
        decryptor = cipher.decryptor()
        
        decrypted_padded = decryptor.update(encrypted_data) + decryptor.finalize()
        pad_length = decrypted_padded[-1]
        decrypted = decrypted_padded[:-pad_length]
        return decrypted
    
    def encrypt_file(self, file_path: str, key: bytes, iv: bytes, output_path: str) -> None:
        """Encrypt any file type (videos, audio, images, PDFs)"""
        with open(file_path, 'rb') as f:
            plaintext = f.read()
        
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=self.backend)
        encryptor = cipher.encryptor()
        
        pad_length = 16 - (len(plaintext) % 16)
        padded_data = plaintext + bytes([pad_length] * pad_length)
        encrypted = encryptor.update(padded_data) + encryptor.finalize()
        
        with open(output_path, 'wb') as f:
            f.write(encrypted)
    
    def decrypt_file(self, encrypted_path: str, key: bytes, iv: bytes, output_path: str) -> None:
        """Decrypt file back to original"""
        with open(encrypted_path, 'rb') as f:
            encrypted_data = f.read()
        
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=self.backend)
        decryptor = cipher.decryptor()
        
        decrypted_padded = decryptor.update(encrypted_data) + decryptor.finalize()
        pad_length = decrypted_padded[-1]
        decrypted = decrypted_padded[:-pad_length]
        
        with open(output_path, 'wb') as f:
            f.write(decrypted)

encryption_manager = EncryptionManager()