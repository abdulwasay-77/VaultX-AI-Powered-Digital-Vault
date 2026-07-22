from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes import (
    auth_router, 
    passwords_router, 
    documents_router, 
    notes_router,
    backup_router,
    search_router
)

# Create FastAPI application instance
app = FastAPI(
    title="VaultX API", 
    version="1.0.0", 
    docs_url="/docs",
    description="AI-Powered Encrypted Digital Vault System"
)

# CORS = Cross-Origin Resource Sharing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth_router, prefix="/api/auth", tags=["Authentication"])
app.include_router(passwords_router, prefix="/api", tags=["Passwords", "IRBE"])
app.include_router(documents_router, prefix="/api", tags=["Documents", "IRBE"])
app.include_router(notes_router, prefix="/api", tags=["Notes"])
app.include_router(backup_router, prefix="/api", tags=["Backup"])
app.include_router(search_router, prefix="/api", tags=["Search"])

# Root endpoint
@app.get("/")
def root():
    return {"message": "VaultX API is running", "status": "healthy"}

@app.get("/health")
def health():
    return {"status": "online", "database": "connected"}

from app.utils.database import db_manager

@app.on_event("shutdown")
def shutdown_event():
    """Close database connection on server shutdown"""
    db_manager.close()