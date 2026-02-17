import requests
import os
import json

# Force usage of the PROD URL
API_URL = "https://celestya-backend.fly.dev"

print(f"--- CHECKING REMOTE BACKEND: {API_URL} ---")

# 1. Check Root (Public Health Check)
print("\n1. CHECKING ROOT (/) ...")
try:
    r = requests.get(f"{API_URL}/")
    print(f"STATUS: {r.status_code}")
    try:
        data = r.json()
        print("RESPONSE JSON:", json.dumps(data, indent=2))
        
        if "deployment_check" in data:
            print(f"✅ DEPLOYMENT VERIFIED: {data['deployment_check']}")
        else:
            print("⚠️ WARNING: deployment_check field MISSING. Old version?")
            
    except:
        print("RESPONSE TEXT:", r.text)
except Exception as e:
    print(f"ROOT FAILED: {e}")

# 2. Check /matches/suggested (Requires Auth, so just check 401 to ensure route exists)
print("\n2. CHECKING /matches/suggested (Expect 401) ...")
try:
    r = requests.get(f"{API_URL}/matches/suggested")
    print(f"STATUS: {r.status_code} (401 is GOOD here)")
except Exception as e:
    print(f"REQ FAILED: {e}")

print("\n--- END CHECK ---")

