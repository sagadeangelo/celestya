import os
from sqlalchemy.orm import Session
from app.models import User, UserVerification
from datetime import datetime

# --- CONFIGURATION ---
REVIEWER_USER_EMAIL = "reviewer.user@celestya.app"
REVIEWER_ADMIN_EMAIL = "reviewer.admin@celestya.app"

def is_reviewer(email: str) -> bool:
    """Returns True if the email is exactly one of the known reviewer accounts."""
    if not email:
        return False
    return email in [REVIEWER_USER_EMAIL, REVIEWER_ADMIN_EMAIL]

def is_reviewer_admin(email: str) -> bool:
    """Returns True ONLY for the admin reviewer account."""
    if not email:
        return False
    return email == REVIEWER_ADMIN_EMAIL

def get_dummy_admin_verifications() -> list:
    """
    Returns a mocked list of verification requests safe for Google Play.
    No real names, emails, IPs, or photos are exposed.
    """
    return [
        {
            "id": 9991,
            "user_id": "review-mock-1",
            "selfie_photo_key": "mock/selfie1.jpg",
            "selfie_photo_url": "https://via.placeholder.com/300x400.png?text=Dummy+Real+Selfie",
            "profile_photo_key": "mock/profile1.jpg",
            "profile_photo_url": "https://via.placeholder.com/300x400.png?text=Dummy+Profile+Photo",
            "status": "pending_review",
            "submitted_at": datetime.utcnow().isoformat(),
            "reviewed_at": None,
            "rejection_reason": None,
            "user": {
                "name": "Alex Reviewer",
                "email": "alex.dummy@example.com",
                "bio": "Mock verification profile 1."
            }
        },
        {
            "id": 9992,
            "user_id": "review-mock-2",
            "selfie_photo_key": "mock/selfie2.jpg",
            "selfie_photo_url": "https://via.placeholder.com/300x400.png?text=Dummy+Real+Selfie+2",
            "profile_photo_key": "mock/profile2.jpg",
            "profile_photo_url": "https://via.placeholder.com/300x400.png?text=Dummy+Profile+Photo+2",
            "status": "pending_review",
            "submitted_at": datetime.utcnow().isoformat(),
            "reviewed_at": None,
            "rejection_reason": None,
            "user": {
                "name": "Sarah Tester",
                "email": "sarah.dummy@example.com",
                "bio": "Mock verification profile 2."
            }
        },
    ]
