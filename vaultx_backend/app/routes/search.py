"""
Smart Search Routes - ULTRA FAST
Title-only search across all vault items
Returns ONLY metadata - no decrypted sensitive data
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from app.models.schemas import SearchResponse, SearchSuggestionsResponse
from app.services.search_engine import search_engine
from app.utils.jwt_handler import jwt_manager

router = APIRouter()


@router.get("/search", response_model=SearchResponse)
def smart_search(
    q: str = Query(..., min_length=1, max_length=200, description="Search query"),
    limit: int = Query(30, ge=1, le=50, description="Max results to return"),
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    ULTRA FAST smart search across all vault items (<50ms)
    
    Searches:
    - Password titles and tags
    - Document file names and categories
    - Note titles and folders
    
    Returns ONLY metadata (no decrypted sensitive data)
    To get full details, use respective detail endpoints:
    - GET /api/passwords/{id}
    - GET /api/documents/{id}
    - GET /api/notes/{id}
    """
    try:
        results = search_engine.search(user_id, q, limit)
        return SearchResponse(**results)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")


@router.get("/search/suggestions", response_model=SearchSuggestionsResponse)
def get_search_suggestions(
    q: str = Query(..., min_length=1, description="Partial query for suggestions"),
    limit: int = Query(10, ge=1, le=20, description="Max suggestions to return"),
    user_id: int = Depends(jwt_manager.get_current_user)
):
    """
    Get ultra-fast search suggestions based on existing titles (<100ms)
    
    Returns matching titles from passwords, documents, and notes
    """
    try:
        suggestions = search_engine.get_suggestions(user_id, q, limit)
        return SearchSuggestionsResponse(suggestions=suggestions)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Suggestions failed: {str(e)}")