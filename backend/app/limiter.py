from slowapi import Limiter
from slowapi.util import get_remote_address
import os

# Create the limiter instance
# Use in-memory storage by default (good for single instance/MVP)
# If scaling horizontally, switch to Redis backend via storage_uri
redis_url = os.getenv("REDIS_URL", "memory://")
limiter = Limiter(key_func=get_remote_address, storage_uri=redis_url)

# Default limits can be set here if needed, but per-route is preferred
# limiter = Limiter(key_func=get_remote_address, default_limits=["200 per day", "50 per hour"])

# Define standard limits
LIMIT_AUTH = "5/minute"  # Login/Register attempts
LIMIT_CHAT = "60/minute" # 1 msg/sec burst
LIMIT_PHOTO = "10/minute" # avoid spamming photo uploads
