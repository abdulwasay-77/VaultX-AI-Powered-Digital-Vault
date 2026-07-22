"""
Pydantic schemas for request/response validation
All data shapes are defined here
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime


# ==================== PASSWORD SCHEMAS ====================

class PasswordCreateRequest(BaseModel):
    """Request model for creating a new password entry"""
    title: str = Field(..., min_length=1, max_length=200, description="Entry title")
    username: str = Field(..., min_length=1, description="Username/Email")
    password: str = Field(..., min_length=1, description="Password")
    url: Optional[str] = Field(None, max_length=500, description="Website URL")
    tag: Optional[str] = Field(None, max_length=50, description="Category tag")
    
    @validator('tag')
    def validate_tag(cls, v):
        if v:
            allowed_tags = ['Bank', 'Social', 'Work', 'Email', 'Shopping', 'Other']
            if v not in allowed_tags:
                raise ValueError(f'Tag must be one of: {", ".join(allowed_tags)}')
        return v


class PasswordUpdateRequest(BaseModel):
    """Request model for updating an existing password entry"""
    title: Optional[str] = Field(None, max_length=200)
    username: Optional[str] = None
    password: Optional[str] = None
    url: Optional[str] = Field(None, max_length=500)
    tag: Optional[str] = Field(None, max_length=50)


class PasswordResponse(BaseModel):
    """Response model for a single password entry (decrypted)"""
    id: int
    title: str
    username: str
    password: str
    url: Optional[str]
    tag: Optional[str]
    strength_score: int
    risk_flag: bool
    created_at: datetime


class PasswordListItem(BaseModel):
    """Response model for password list (without decrypted data)"""
    id: int
    title: str
    tag: Optional[str]
    strength_score: int
    risk_flag: bool
    created_at: datetime


# ==================== IRBE SCHEMAS ====================

class PasswordStrengthResponse(BaseModel):
    """IRBE password strength analysis result"""
    score: int = Field(..., ge=0, le=100, description="Strength score 0-100")
    category: str = Field(..., description="Weak/Moderate/Strong/Very Strong")
    color: str = Field(..., description="Red/Yellow/Green/DarkGreen")
    feedback: List[str] = Field(default_factory=list, description="Improvement suggestions")


class PasswordGenerateRequest(BaseModel):
    """Request model for password generator"""
    length: int = Field(16, ge=8, le=64, description="Password length")
    use_uppercase: bool = Field(True, description="Include A-Z")
    use_lowercase: bool = Field(True, description="Include a-z")
    use_numbers: bool = Field(True, description="Include 0-9")
    use_symbols: bool = Field(True, description="Include !@#$%^&*")
    avoid_ambiguous: bool = Field(True, description="Avoid 0, O, l, 1")


class PasswordGenerateResponse(BaseModel):
    """Response model for password generator"""
    suggestions: List[str] = Field(..., description="3 password suggestions")
    strength: PasswordStrengthResponse


class ReusedPasswordInfo(BaseModel):
    """Information about a reused password"""
    password_hash: str
    entries: List[dict]  # List of {id, title}


class RiskReportResponse(BaseModel):
    """Complete risk report for the vault"""
    health_score: int = Field(..., ge=0, le=100)
    total_passwords: int
    weak_passwords: List[PasswordListItem]
    reused_passwords: List[dict]  # List of {password_hash, entries, count}
    strong_passwords_count: int
    moderate_passwords_count: int
    weak_passwords_count: int

# ==================== DOCUMENT SCHEMAS ====================

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field


class DocumentUploadRequest(BaseModel):
    """Request model for document upload"""
    category: str = Field(..., description="IDs, Certificates, Contracts, Finance, Other")
    delete_original: bool = Field(True, description="Delete original file after encryption")
    
    @validator('category')
    def validate_category(cls, v):
        allowed = ['IDs', 'Certificates', 'Contracts', 'Finance', 'Other']
        if v not in allowed:
            raise ValueError(f'Category must be one of: {", ".join(allowed)}')
        return v


class DocumentUploadResponse(BaseModel):
    """Response after uploading a document"""
    id: int
    file_name: str
    file_size: int
    file_type: str
    sensitivity_score: str
    sensitivity_color: str
    sensitivity_reason: str
    category: str
    message: str
    original_deleted: bool


class DocumentListItem(BaseModel):
    """Document list item (without encrypted data)"""
    id: int
    file_name: str
    file_size: int
    file_type: str
    sensitivity_score: str
    sensitivity_color: str
    category: str
    uploaded_at: datetime


class DocumentResponse(BaseModel):
    """Full document response for preview/download"""
    id: int
    file_name: str
    file_size: int
    file_type: str
    sensitivity_score: str
    category: str
    uploaded_at: datetime


class FileSensitivityResponse(BaseModel):
    """IRBE file sensitivity analysis result"""
    sensitivity: str
    color: str
    reason: str
    requires_confirmation: bool


class DocumentDeleteResponse(BaseModel):
    """Response after deleting a document"""
    message: str
    id: int
    file_name: str


# ==================== NOTES SCHEMAS ====================

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field, validator


class NoteCreateRequest(BaseModel):
    """Request model for creating a new note"""
    title: str = Field(..., min_length=1, max_length=200, description="Note title")
    content: str = Field(default="", description="Note content (rich text)")
    folder: Optional[str] = Field(None, max_length=100, description="Folder name")
    
    @validator('title')
    def validate_title(cls, v):
        if not v or not v.strip():
            raise ValueError('Title cannot be empty')
        return v.strip()


class NoteUpdateRequest(BaseModel):
    """Request model for updating a note"""
    title: Optional[str] = Field(None, max_length=200)
    content: Optional[str] = None
    folder: Optional[str] = Field(None, max_length=100)


class NoteResponse(BaseModel):
    """Response model for a single note (decrypted)"""
    id: int
    title: str
    content: str
    folder: Optional[str]
    updated_at: datetime
    created_at: datetime


class NoteListItem(BaseModel):
    """Response model for note list (without decrypted content)"""
    id: int
    title: str
    folder: Optional[str]
    updated_at: datetime
    created_at: datetime


class FolderCreateRequest(BaseModel):
    """Request model for creating a folder"""
    name: str = Field(..., min_length=1, max_length=100)
    
    @validator('name')
    def validate_name(cls, v):
        return v.strip()


class FolderListResponse(BaseModel):
    """Response model for folder list"""
    folders: List[str]


class MoveNoteRequest(BaseModel):
    """Request model for moving a note to a different folder"""
    folder: str = Field(..., max_length=100)


# ==================== BACKUP SCHEMAS ====================

from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field


class BackupExportResponse(BaseModel):
    """Response after exporting backup"""
    message: str
    file_path: str
    file_size: int
    created_at: datetime
    includes: Dict[str, int]  # passwords, documents, notes counts


class BackupRestoreRequest(BaseModel):
    """Request model for restoring backup"""
    master_password: str = Field(..., description="Master password to decrypt backup")
    overwrite: bool = Field(True, description="True=overwrite existing, False=merge")


class BackupRestoreResponse(BaseModel):
    """Response after restoring backup"""
    message: str
    restored: Dict[str, int]  # passwords, documents, notes restored
    mode: str  # overwrite or merge


class BackupHistoryItem(BaseModel):
    """Backup history list item"""
    id: int
    backup_file_path: str
    file_size: int
    created_at: datetime


class BackupVerifyResponse(BaseModel):
    """Response after verifying backup file"""
    valid: bool
    version: Optional[str] = None
    exported_at: Optional[datetime] = None
    contains: Optional[Dict[str, int]] = None
    error: Optional[str] = None

# ==================== SEARCH SCHEMAS ====================

from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class SearchResultItem(BaseModel):
    """Single search result item (metadata only, no decrypted data)"""
    type: str = Field(..., description="password, document, or note")
    id: int = Field(..., description="Item ID for fetching full details")
    title: str = Field(..., description="Display title")
    relevance_score: float = Field(..., description="0-100 relevance score")
    icon: str = Field(..., description="🔐 📄 📝")
    
    # Optional fields based on type
    tag: Optional[str] = None
    category: Optional[str] = None
    sensitivity: Optional[str] = None
    file_type: Optional[str] = None
    folder: Optional[str] = None


class SearchResponse(BaseModel):
    """Search response (fast, no decrypted data)"""
    query: str
    expanded_query: List[str] = Field(..., description="Synonyms used for search")
    results: List[SearchResultItem]
    total: int
    took_ms: float = Field(..., description="Search time in milliseconds")


class SearchSuggestionsResponse(BaseModel):
    """Search suggestions response"""
    suggestions: List[str]


# Add this after existing imports (around line 10)

class RegisterRequest(BaseModel):
    master_password: str
    username: str
    email: str
    pin: Optional[str] = None

class UserInfoResponse(BaseModel):
    user_id: int
    username: str
    email: str
    created_at: str
    has_passwords: bool
    has_documents: bool
    has_notes: bool

class SwitchUserRequest(BaseModel):
    user_id: int
    master_password: str


# ==================== FOLDER SCHEMAS (ADD THIS) ====================

class FolderCreateRequest(BaseModel):
    """Request model for creating a new folder"""
    name: str = Field(..., min_length=1, max_length=100, description="Folder name")
    
    @validator('name')
    def validate_name(cls, v):
        v = v.strip()
        if not v:
            raise ValueError('Folder name cannot be empty')
        if len(v) > 100:
            raise ValueError('Folder name too long (max 100 characters)')
        return v


class FolderResponse(BaseModel):
    """Response model for folder"""
    id: int
    name: str
    created_at: datetime


class FolderListResponse(BaseModel):
    """Response model for folder list"""
    folders: List[FolderResponse]


class FolderDeleteRequest(BaseModel):
    """Request model for deleting a folder"""
    move_to: Optional[str] = Field(None, description="Folder to move notes to (empty for Uncategorized)")