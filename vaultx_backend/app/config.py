import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Database - Using localhost (always works regardless of PC name)
    DB_DRIVER = '{ODBC Driver 17 for SQL Server}'
    DB_SERVER = 'localhost'  # Fixed to localhost - no PC name issues
    DB_NAME = 'VaultX_DB'
    DB_TRUSTED_CONNECTION = 'yes'
    
    @property
    def DATABASE_URL(self):
        return f'DRIVER={self.DB_DRIVER};SERVER={self.DB_SERVER};DATABASE={self.DB_NAME};Trusted_Connection={self.DB_TRUSTED_CONNECTION}'
    
    # Security
    SALT_SIZE = 32
    KEY_SIZE = 32
    IV_SIZE = 16
    PBKDF2_ITERATIONS = 100000
    
    # JWT
    SECRET_KEY = os.getenv('SECRET_KEY', 'vaultx-secret-key-2024')
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 30
    
    # Paths (Portable - Relative)
    BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    UPLOADS_DIR = os.path.join(BASE_DIR, 'uploads')
    BACKUPS_DIR = os.path.join(BASE_DIR, 'backups')

config = Config()

# Create directories if they don't exist
os.makedirs(config.UPLOADS_DIR, exist_ok=True)
os.makedirs(config.BACKUPS_DIR, exist_ok=True)