import enum

class AgeBucket(str, enum.Enum):
    A_18_25 = "18-25"
    B_26_45 = "26-45"
    C_45_75_PLUS = "45-75+"
