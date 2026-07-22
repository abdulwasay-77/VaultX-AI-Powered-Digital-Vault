"""
Ultra-Fast Search Engine - Matches any word in title
"""

import time
from typing import List, Dict, Any
from app.utils.database import db_manager


class SearchEngine:
    
    @staticmethod
    def search(user_id: int, query: str, limit: int = 30) -> Dict[str, Any]:
        """Single query per table - matches ANY word in title"""
        start_time = time.perf_counter()
        
        if not query or len(query.strip()) < 1:
            return {
                "query": query,
                "expanded_query": [],
                "results": [],
                "total": 0,
                "took_ms": 0
            }
        
        q = query.strip().lower()
        # Match anywhere in the string, not just beginning
        search_pattern = f"%{q}%"
        
        results = []
        
        # 1. Search Passwords - match ANYWHERE in title or tag
        password_sql = """
            SELECT TOP 30 id, title, tag, created_at, 'password' as type
            FROM Passwords 
            WHERE user_id = ? AND (LOWER(title) LIKE ? OR LOWER(tag) LIKE ?)
            ORDER BY 
                CASE WHEN LOWER(title) = ? THEN 1
                     WHEN LOWER(title) LIKE ? THEN 2
                     ELSE 3 END
        """
        password_rows = db_manager.execute_query(
            password_sql, 
            (user_id, search_pattern, search_pattern, q, f"{q}%")
        )
        
        if password_rows:
            for row in password_rows:
                results.append({
                    "type": "password",
                    "id": row[0],
                    "title": row[1],
                    "tag": row[2],
                    "icon": "🔐",
                    "relevance_score": 80 if row[1].lower().startswith(q) else 60
                })
        
        # 2. Search Documents - match ANYWHERE in file_name
        doc_sql = """
            SELECT TOP 30 id, file_name, category, file_type, 'document' as type
            FROM Documents 
            WHERE user_id = ? AND LOWER(file_name) LIKE ?
            ORDER BY 
                CASE WHEN LOWER(file_name) = ? THEN 1
                     WHEN LOWER(file_name) LIKE ? THEN 2
                     ELSE 3 END
        """
        doc_rows = db_manager.execute_query(doc_sql, (user_id, search_pattern, q, f"{q}%"))
        
        if doc_rows:
            for row in doc_rows:
                results.append({
                    "type": "document",
                    "id": row[0],
                    "title": row[1],
                    "category": row[2],
                    "file_type": row[3],
                    "icon": "📄",
                    "relevance_score": 80 if row[1].lower().startswith(q) else 60
                })
        
        # 3. Search Notes - match ANYWHERE in title
        note_sql = """
            SELECT TOP 30 id, title, folder, 'note' as type
            FROM Notes 
            WHERE user_id = ? AND LOWER(title) LIKE ?
            ORDER BY 
                CASE WHEN LOWER(title) = ? THEN 1
                     WHEN LOWER(title) LIKE ? THEN 2
                     ELSE 3 END
        """
        note_rows = db_manager.execute_query(note_sql, (user_id, search_pattern, q, f"{q}%"))
        
        if note_rows:
            for row in note_rows:
                results.append({
                    "type": "note",
                    "id": row[0],
                    "title": row[1],
                    "folder": row[2],
                    "icon": "📝",
                    "relevance_score": 80 if row[1].lower().startswith(q) else 60
                })
        
        # Sort by relevance
        results.sort(key=lambda x: x["relevance_score"], reverse=True)
        
        # Prepare response
        response_results = []
        for item in results[:limit]:
            result_item = {
                "type": item["type"],
                "id": item["id"],
                "title": item["title"],
                "relevance_score": item["relevance_score"],
                "icon": item["icon"]
            }
            if item["type"] == "password" and item.get("tag"):
                result_item["tag"] = item["tag"]
            elif item["type"] == "document":
                result_item["category"] = item.get("category")
                result_item["file_type"] = item.get("file_type")
            elif item["type"] == "note" and item.get("folder"):
                result_item["folder"] = item["folder"]
            
            response_results.append(result_item)
        
        elapsed_ms = (time.perf_counter() - start_time) * 1000
        
        return {
            "query": query,
            "expanded_query": [query],
            "results": response_results,
            "total": len(response_results),
            "took_ms": round(elapsed_ms, 2)
        }
    
    @staticmethod
    def get_suggestions(user_id: int, partial: str, limit: int = 10) -> List[str]:
        """Get suggestions - matches ANYWHERE in title"""
        if not partial or len(partial.strip()) < 2:
            return []
        
        p = partial.lower().strip()
        pattern = f"%{p}%"
        
        suggestions = set()
        
        # Get from passwords
        pwd_rows = db_manager.execute_query(
            "SELECT DISTINCT TOP 10 title FROM Passwords WHERE user_id = ? AND LOWER(title) LIKE ?",
            (user_id, pattern)
        )
        if pwd_rows:
            for row in pwd_rows:
                if row[0]:
                    suggestions.add(row[0])
        
        # Get from documents
        doc_rows = db_manager.execute_query(
            "SELECT DISTINCT TOP 10 file_name FROM Documents WHERE user_id = ? AND LOWER(file_name) LIKE ?",
            (user_id, pattern)
        )
        if doc_rows:
            for row in doc_rows:
                if row[0]:
                    suggestions.add(row[0])
        
        # Get from notes
        note_rows = db_manager.execute_query(
            "SELECT DISTINCT TOP 10 title FROM Notes WHERE user_id = ? AND LOWER(title) LIKE ?",
            (user_id, pattern)
        )
        if note_rows:
            for row in note_rows:
                if row[0]:
                    suggestions.add(row[0])
        
        return list(suggestions)[:limit]


search_engine = SearchEngine()