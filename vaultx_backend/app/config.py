import os
import sys
from dotenv import load_dotenv

load_dotenv()


def _writable_base_dir():
    """Where user data (db, uploads, backups) lives.
    - Normal dev run: vaultx_backend/ (two levels up from this file)
    - Compiled .exe (PyInstaller): the folder the .exe itself sits in,
      NOT the temp extraction folder, so data survives between runs."""
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _bundled_resource_dir():
    """Where read-only bundled files (like sqlite_schema.sql) live.
    - Normal dev run: same as writable dir
    - Compiled .exe: PyInstaller's temp extraction folder (sys._MEIPASS)"""
    if getattr(sys, 'frozen', False):
        return sys._MEIPASS
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Config:
    # Database - SQLite, a single portable file (no server/install needed)
    DB_PATH = os.getenv('DB_PATH', os.path.join(_writable_base_dir(), 'data', 'vaultx.db'))

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
    BASE_DIR = _writable_base_dir()
    RESOURCE_DIR = _bundled_resource_dir()
    UPLOADS_DIR = os.path.join(BASE_DIR, 'uploads')
    BACKUPS_DIR = os.path.join(BASE_DIR, 'backups')

config = Config()

# Create directories if they don't exist
os.makedirs(config.UPLOADS_DIR, exist_ok=True)
os.makedirs(config.BACKUPS_DIR, exist_ok=True)
os.makedirs(os.path.dirname(config.DB_PATH), exist_ok=True)