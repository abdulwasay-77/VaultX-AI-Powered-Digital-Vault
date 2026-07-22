"""
Routes module exports
"""

from app.routes.auth import router as auth_router
from app.routes.passwords import router as passwords_router
from app.routes.documents import router as documents_router
from app.routes.notes import router as notes_router
from app.routes.backup import router as backup_router
from app.routes.search import router as search_router

__all__ = [
    'auth_router', 
    'passwords_router', 
    'documents_router', 
    'notes_router',
    'backup_router',
    'search_router'
]