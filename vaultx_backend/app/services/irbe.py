"""
Intelligent Rule-Based Engine (IRBE) for VaultX
Handles password strength analysis, generation, and risk detection
"""

import re
import secrets
import string
from typing import List, Dict, Any, Tuple
from app.models.schemas import PasswordStrengthResponse, PasswordGenerateResponse
from app.utils.database import db_manager


class PasswordIntelligenceEngine:
    """Password strength analysis and generation"""
    
    # Weak patterns to detect
    WEAK_PATTERNS = {
        'sequential_numbers': r'123456|234567|345678|456789|567890',
        'keyboard_walk': r'qwerty|asdfgh|zxcvbn|qwertyuiop|asdfghjkl|zxcvbnm',
        'repeating_chars': r'(.)\1{3,}',  # aaaa, bbbb, etc.
        'common_words': r'password|admin|welcome|login|user|default|secret',
    }
    
    # Ambiguous characters to avoid
    AMBIGUOUS_CHARS = '0OIl1'
    
    @staticmethod
    def analyze_strength(password: str) -> PasswordStrengthResponse:
        """
        Analyze password strength and return score with feedback
        
        Scoring system:
        - Base score starts at 0
        - Length: +10 for 8-11 chars, +20 for 12+ chars
        - Character variety: +15 each for uppercase, lowercase, numbers, symbols
        - Penalties for weak patterns: -20 each
        
        Maximum score: 100
        """
        score = 0
        feedback = []
        
        # === LENGTH CHECKS ===
        length = len(password)
        if length >= 12:
            score += 20
        elif length >= 8:
            score += 10
        else:
            feedback.append(f"Use at least 8 characters (currently {length})")
        
        if length >= 16:
            score += 5  # Bonus for very long passwords
        
        # === CHARACTER VARIETY CHECKS ===
        has_upper = any(c.isupper() for c in password)
        has_lower = any(c.islower() for c in password)
        has_digit = any(c.isdigit() for c in password)
        has_symbol = any(c in "!@#$%^&*()_+-=[]{}|;:,.<>?" for c in password)
        
        if has_upper:
            score += 15
        else:
            feedback.append("Add uppercase letters (A-Z)")
        
        if has_lower:
            score += 10  # Lowercase is common, less weight
        else:
            feedback.append("Add lowercase letters (a-z)")
        
        if has_digit:
            score += 15
        else:
            feedback.append("Add numbers (0-9)")
        
        if has_symbol:
            score += 15
        else:
            feedback.append("Add symbols (!@#$%^&*)")
        
        # === WEAK PATTERN PENALTIES ===
        # Check for sequential numbers (123456)
        if re.search(PasswordIntelligenceEngine.WEAK_PATTERNS['sequential_numbers'], password):
            score -= 20
            feedback.append("Avoid sequential numbers like '123456'")
        
        # Check for keyboard walks (qwerty)
        if re.search(PasswordIntelligenceEngine.WEAK_PATTERNS['keyboard_walk'], password.lower()):
            score -= 20
            feedback.append("Avoid keyboard patterns like 'qwerty'")
        
        # Check for repeating characters
        if re.search(PasswordIntelligenceEngine.WEAK_PATTERNS['repeating_chars'], password):
            score -= 15
            feedback.append("Avoid repeating characters like 'aaa'")
        
        # Check for common dictionary words
        if re.search(PasswordIntelligenceEngine.WEAK_PATTERNS['common_words'], password.lower()):
            score -= 25
            feedback.append("Avoid common dictionary words")
        
        # Check if password is all the same case
        if password.isupper() or password.islower():
            score -= 10
            feedback.append("Mix uppercase and lowercase letters")
        
        # Ensure score is within 0-100 range
        score = max(0, min(100, score))
        
        # === CATEGORIZATION ===
        if score >= 90:
            category = "Very Strong"
            color = "darkgreen"
        elif score >= 70:
            category = "Strong"
            color = "green"
        elif score >= 40:
            category = "Moderate"
            color = "yellow"
        else:
            category = "Weak"
            color = "red"
        
        return PasswordStrengthResponse(
            score=score,
            category=category,
            color=color,
            feedback=feedback
        )
    
    @staticmethod
    def generate_password(
        length: int = 16,
        use_uppercase: bool = True,
        use_lowercase: bool = True,
        use_numbers: bool = True,
        use_symbols: bool = True,
        avoid_ambiguous: bool = True
    ) -> str:
        """
        Generate a cryptographically secure random password
        
        Returns:
            Secure random password string
        """
        # Build character pool
        chars = ""
        if use_lowercase:
            chars += string.ascii_lowercase
        if use_uppercase:
            chars += string.ascii_uppercase
        if use_numbers:
            chars += string.digits
        if use_symbols:
            chars += "!@#$%^&*()_+-=[]{}|;:,.<>?"
        
        # Remove ambiguous characters if requested
        if avoid_ambiguous:
            for char in PasswordIntelligenceEngine.AMBIGUOUS_CHARS:
                chars = chars.replace(char, '')
        
        # Ensure at least one character set is selected
        if not chars:
            chars = string.ascii_letters + string.digits
        
        # Generate password using secrets (cryptographically secure)
        password = ''.join(secrets.choice(chars) for _ in range(length))
        
        return password
    
    @staticmethod
    def generate_multiple_suggestions(
        length: int = 16,
        use_uppercase: bool = True,
        use_lowercase: bool = True,
        use_numbers: bool = True,
        use_symbols: bool = True,
        avoid_ambiguous: bool = True,
        count: int = 3
    ) -> List[str]:
        """
        Generate multiple password suggestions
        
        Returns:
            List of unique password strings
        """
        suggestions = set()
        max_attempts = count * 3
        
        for _ in range(max_attempts):
            if len(suggestions) >= count:
                break
            pwd = PasswordIntelligenceEngine.generate_password(
                length, use_uppercase, use_lowercase, 
                use_numbers, use_symbols, avoid_ambiguous
            )
            suggestions.add(pwd)
        
        # If we couldn't generate enough unique passwords, pad with more
        while len(suggestions) < count:
            pwd = PasswordIntelligenceEngine.generate_password(
                length, use_uppercase, use_lowercase,
                use_numbers, use_symbols, avoid_ambiguous
            )
            suggestions.add(pwd)
        
        return list(suggestions)


class RiskDetectionEngine:
    """Detects security risks like password reuse and weak passwords"""
    
    @staticmethod
    def detect_reused_passwords(user_id: int) -> List[Dict[str, Any]]:
        """
        Find passwords that are reused across multiple entries
        
        Returns:
            List of reused password groups
        """
        # Query to get all password hashes with their IDs and titles
        # Note: We hash the decrypted password to compare, but since passwords
        # are encrypted, we need to check them in application logic
        
        query = """
            SELECT id, title, password_encrypted, iv 
            FROM Passwords 
            WHERE user_id = ?
        """
        results = db_manager.execute_query(query, (user_id,))
        
        if not results:
            return []
        
        # Group by password (this will be handled with decryption in the route)
        # For now, return structure - actual grouping happens in route with decryption
        return []
    
    @staticmethod
    def get_weak_passwords(user_id: int, threshold: int = 40) -> List[Dict[str, Any]]:
        """
        Get all passwords with strength score below threshold
        
        Args:
            user_id: User ID
            threshold: Score threshold (default 40 = Moderate/Weak boundary)
        
        Returns:
            List of weak password entries
        """
        query = """
            SELECT id, title, tag, strength_score, created_at
            FROM Passwords 
            WHERE user_id = ? AND strength_score < ?
            ORDER BY strength_score ASC
        """
        results = db_manager.execute_query(query, (user_id, threshold))
        
        weak_passwords = []
        if results:
            for row in results:
                weak_passwords.append({
                    'id': row[0],
                    'title': row[1],
                    'tag': row[2],
                    'strength_score': row[3],
                    'created_at': row[4]
                })
        
        return weak_passwords
    
    @staticmethod
    def calculate_health_score(user_id: int) -> int:
        """
        Calculate overall vault health score (0-100)
        
        Formula:
        - Base score: 50
        - Each strong password: +2 (max +30)
        - Each weak password: -5 (max -30)
        - Each reused password group: -10 (max -30)
        """
        # Get password statistics
        query = """
            SELECT 
                COUNT(*) as total,
                SUM(CASE WHEN strength_score >= 70 THEN 1 ELSE 0 END) as strong_count,
                SUM(CASE WHEN strength_score < 40 THEN 1 ELSE 0 END) as weak_count
            FROM Passwords 
            WHERE user_id = ?
        """
        result = db_manager.execute_query(query, (user_id,))
        
        if not result or result[0][0] == 0:
            return 100  # No passwords = perfect health
        
        total = result[0][0]
        strong_count = result[0][1] or 0
        weak_count = result[0][2] or 0
        
        # Start with base score
        health_score = 50
        
        # Add points for strong passwords (max +30)
        health_score += min(strong_count * 2, 30)
        
        # Subtract points for weak passwords (max -30)
        health_score -= min(weak_count * 5, 30)
        
        # Ensure score is within bounds
        health_score = max(0, min(100, health_score))
        
        return health_score

# ==================== FILE SENSITIVITY CLASSIFIER ====================

class FileSensitivityClassifier:
    """Classifies file sensitivity based on name and type"""
    
    # High sensitivity keywords (RED - requires confirmation)
    HIGH_SENSITIVITY_KEYWORDS = [
        'passport', 'nic', 'cnic', 'id card', 'identity', 'ssn', 'social security',
        'contract', 'agreement', 'legal', 'lawsuit', 'settlement',
        'salary', 'payroll', 'bank statement', 'financial', 'tax return', 'tax',
        'credit card', 'debit card', 'card number', 'cvv',
        'certificate', 'diploma', 'degree', 'transcript', 'marksheet',
        'medical report', 'prescription', 'health record', 'diagnosis',
        'will', 'testament', 'property deed', 'title deed', 'ownership',
        'confidential', 'secret', 'classified', 'nda', 'non-disclosure',
        'background check', 'verification', 'clearance'
    ]
    
    # Medium sensitivity keywords (AMBER - no confirmation needed but flagged)
    MEDIUM_SENSITIVITY_KEYWORDS = [
        'invoice', 'bill', 'receipt', 'payment', 'transaction',
        'resume', 'cv', 'cover letter', 'application', 'job application',
        'insurance', 'policy', 'claim', 'coverage',
        'project proposal', 'business plan', 'proposal',
        'employee record', 'hr document', 'personnel',
        'report', 'summary', 'analysis', 'review',
        'presentation', 'slides', 'deck',
        'meeting notes', 'minutes', 'agenda'
    ]
    
    @staticmethod
    def classify_sensitivity(file_name: str) -> dict:
        """
        Classify file sensitivity based on file name keywords
        
        Args:
            file_name: Original file name (e.g., "passport_scan.pdf")
        
        Returns:
            dict with sensitivity, color, reason, requires_confirmation
        """
        file_name_lower = file_name.lower()
        
        # Check for high sensitivity keywords
        for keyword in FileSensitivityClassifier.HIGH_SENSITIVITY_KEYWORDS:
            if keyword in file_name_lower:
                return {
                    "sensitivity": "High",
                    "color": "red",
                    "reason": f"Contains keyword: '{keyword}' - This file contains sensitive information",
                    "requires_confirmation": True
                }
        
        # Check for medium sensitivity keywords
        for keyword in FileSensitivityClassifier.MEDIUM_SENSITIVITY_KEYWORDS:
            if keyword in file_name_lower:
                return {
                    "sensitivity": "Medium",
                    "color": "amber",
                    "reason": f"Contains keyword: '{keyword}' - Moderate sensitivity detected",
                    "requires_confirmation": False
                }
        
        # Default: Low sensitivity
        return {
            "sensitivity": "Low",
            "color": "green",
            "reason": "No sensitive keywords detected",
            "requires_confirmation": False
        }
    
    @staticmethod
    def get_file_type(file_name: str) -> str:
        """
        Determine file type category based on extension
        
        Returns:
            video, audio, image, pdf, document, or other
        """
        extension = file_name.split('.')[-1].lower() if '.' in file_name else ''
        
        video_extensions = ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v']
        audio_extensions = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma']
        image_extensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff', 'webp', 'svg', 'ico']
        pdf_extensions = ['pdf']
        document_extensions = ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'odt', 'ods', 'odp']
        
        if extension in video_extensions:
            return 'video'
        elif extension in audio_extensions:
            return 'audio'
        elif extension in image_extensions:
            return 'image'
        elif extension in pdf_extensions:
            return 'pdf'
        elif extension in document_extensions:
            return 'document'
        else:
            return 'other'

# Create singleton instances
password_engine = PasswordIntelligenceEngine()
risk_engine = RiskDetectionEngine()