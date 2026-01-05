"""
Password Service

Provides secure password hashing using bcrypt with configurable work factor.
"""

import bcrypt
import secrets
import hashlib
from typing import Optional


class PasswordService:
    """Handles password hashing and verification using bcrypt."""

    # Work factor for bcrypt (12 is recommended for 2024+)
    # Higher = more secure but slower
    WORK_FACTOR = 12

    # Minimum password requirements
    MIN_LENGTH = 8
    MAX_LENGTH = 128  # Prevent DoS via long passwords

    @classmethod
    def hash_password(cls, password: str) -> str:
        """
        Hash a password using bcrypt.

        Args:
            password: The plaintext password to hash

        Returns:
            The bcrypt hash as a string

        Raises:
            ValueError: If password doesn't meet requirements
        """
        cls._validate_password(password)

        # Encode password to bytes
        password_bytes = password.encode('utf-8')

        # Generate salt and hash
        salt = bcrypt.gensalt(rounds=cls.WORK_FACTOR)
        hash_bytes = bcrypt.hashpw(password_bytes, salt)

        return hash_bytes.decode('utf-8')

    @classmethod
    def verify_password(cls, password: str, hash_str: str) -> bool:
        """
        Verify a password against a bcrypt hash.

        Args:
            password: The plaintext password to verify
            hash_str: The bcrypt hash to verify against

        Returns:
            True if the password matches, False otherwise
        """
        if not password or not hash_str:
            return False

        try:
            password_bytes = password.encode('utf-8')
            hash_bytes = hash_str.encode('utf-8')
            return bcrypt.checkpw(password_bytes, hash_bytes)
        except (ValueError, TypeError):
            return False

    @classmethod
    def _validate_password(cls, password: str) -> None:
        """
        Validate password meets minimum requirements.

        Args:
            password: The password to validate

        Raises:
            ValueError: If password doesn't meet requirements
        """
        if not password:
            raise ValueError("Password cannot be empty")

        if len(password) < cls.MIN_LENGTH:
            raise ValueError(f"Password must be at least {cls.MIN_LENGTH} characters")

        if len(password) > cls.MAX_LENGTH:
            raise ValueError(f"Password cannot exceed {cls.MAX_LENGTH} characters")

    @classmethod
    def check_password_strength(cls, password: str) -> dict:
        """
        Check password strength and return feedback.

        Args:
            password: The password to check

        Returns:
            Dictionary with strength score and suggestions
        """
        score = 0
        suggestions = []

        if len(password) >= 8:
            score += 1
        else:
            suggestions.append("Use at least 8 characters")

        if len(password) >= 12:
            score += 1

        if len(password) >= 16:
            score += 1

        if any(c.isupper() for c in password):
            score += 1
        else:
            suggestions.append("Add uppercase letters")

        if any(c.islower() for c in password):
            score += 1
        else:
            suggestions.append("Add lowercase letters")

        if any(c.isdigit() for c in password):
            score += 1
        else:
            suggestions.append("Add numbers")

        if any(c in "!@#$%^&*()_+-=[]{}|;:,.<>?" for c in password):
            score += 1
        else:
            suggestions.append("Add special characters")

        # Map score to strength level
        if score <= 2:
            strength = "weak"
        elif score <= 4:
            strength = "fair"
        elif score <= 5:
            strength = "good"
        else:
            strength = "strong"

        return {
            "score": score,
            "max_score": 7,
            "strength": strength,
            "suggestions": suggestions
        }

    @staticmethod
    def generate_reset_token() -> str:
        """
        Generate a secure random token for password reset.

        Returns:
            A 32-character hex token
        """
        return secrets.token_hex(32)

    @staticmethod
    def hash_token(token: str) -> str:
        """
        Hash a token (e.g., reset token) for storage.
        Uses SHA-256 for fast comparison.

        Args:
            token: The token to hash

        Returns:
            The SHA-256 hash of the token
        """
        return hashlib.sha256(token.encode('utf-8')).hexdigest()

    @staticmethod
    def verify_token(token: str, hash_str: str) -> bool:
        """
        Verify a token against its hash.

        Args:
            token: The plaintext token
            hash_str: The SHA-256 hash to verify against

        Returns:
            True if the token matches, False otherwise
        """
        return secrets.compare_digest(
            hashlib.sha256(token.encode('utf-8')).hexdigest(),
            hash_str
        )
