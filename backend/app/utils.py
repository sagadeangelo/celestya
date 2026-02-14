import re
from typing import Optional

def clean_name(value: Optional[str]) -> Optional[str]:
    """
    Sanitizes a name string by:
    1. Removing the literal word "null" (case-insensitive).
    2. Removing extra spaces.
    3. Removing trailing commas or punctuation often left behind after removing "null".
    4. Returning None if the result is empty or just "null".
    """
    if not value:
        return None

    # 1. Remove "null" as a whole word (case-insensitive)
    #    This handles "Miguel, null" -> "Miguel, "
    #    or "null Tovar" -> " Tovar"
    cleaned = re.sub(r'(?i)\bnull\b', '', value)

    # 2. Cleanup punctuation that might remain
    #    e.g. "Miguel, " -> "Miguel"
    #    We remove trailing commas, dots, or spaces
    cleaned = re.sub(r'[,\.\s]+$', '', cleaned)
    cleaned = re.sub(r'^[,\.\s]+', '', cleaned)
    
    # 3. Collapse multiple spaces
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()

    if not cleaned or cleaned.lower() == "null":
        return None

    return cleaned
