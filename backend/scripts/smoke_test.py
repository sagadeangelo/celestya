import requests
import uuid
import os
import time

# Configuration
BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")

def unique_email():
    return f"user_{uuid.uuid4().hex[:8]}@example.com"

def register(email, password="password123"):
    payload = {
        "email": email,
        "password": password,
        "birthdate": "2000-01-01",
        "name": "Test User"
    }
    r = requests.post(f"{BASE_URL}/auth/register", json=payload)
    if r.status_code != 200:
        print(f"[-] Register failed: {r.text}")
    r.raise_for_status()
    return r.json()

def login(email, password="password123"):
    payload = {
        "username": email,
        "password": password
    }
    r = requests.post(f"{BASE_URL}/auth/login", data=payload)
    if r.status_code != 200:
        print(f"[-] Login failed: {r.text}")
    r.raise_for_status()
    return r.json() # Returns {access_token, token_type, refresh_token}

def scenario_full_flow():
    print("[*] Starting Smoke Test Scenario...")

    # 1. Register User A and User B
    email_a = unique_email()
    email_b = unique_email()
    print(f"[*] Registering {email_a} and {email_b}")
    register(email_a)
    register(email_b)

    # 1b. Manually Verify Users (Bypass Email)
    import sqlite3
    try:
        # DB path might be relative to where script is run. Assuming ./celestya.db exists.
        # If running from backend root, it should be there.
        db_path = "celestya.db"
        if os.path.exists(db_path):
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("UPDATE users SET email_verified=1 WHERE email IN (?, ?)", (email_a, email_b))
            conn.commit()
            conn.close()
            print("[+] Manually verified users in DB for testing.")
        else:
            print(f"[-] DB file not found at {db_path}, verification might fail if login requires it.")
    except Exception as e:
        print(f"[-] DB update failed: {e}")

    # 2. Login
    tokens_a = login(email_a)
    tokens_b = login(email_b)
    headers_a = {"Authorization": f"Bearer {tokens_a['access_token']}"}
    headers_b = {"Authorization": f"Bearer {tokens_b['access_token']}"}

    # Helper to get ID
    def get_me(headers):
        r = requests.get(f"{BASE_URL}/users/me", headers=headers)
        if r.status_code != 200:
            print(f"[-] get_me failed: {r.status_code} {r.text}")
        r.raise_for_status()
        return r.json()

    user_a = get_me(headers_a)
    user_b = get_me(headers_b)
    id_a = user_a["id"]
    id_b = user_b["id"]
    print(f"[*] User A ID: {id_a}, User B ID: {id_b}")

    # 3. Validation: Online Status
    # User B should be online (just logged in)
    print(f"[*] Checking Online Status for User B: {user_b['is_online']}") 

    # 4. User A likes User B
    print("[*] User A likes User B")
    r = requests.post(f"{BASE_URL}/matches/like/{id_b}", headers=headers_a)
    if r.status_code == 200:
        print(r.json())
    else:
        print(f"[-] Like failed: {r.text}")

    # 5. User B likes User A (Match!)
    print("[*] User B likes User A")
    r = requests.post(f"{BASE_URL}/matches/like/{id_a}", headers=headers_b)
    data = r.json()
    if data.get("matched") is True:
        print("[+] Match Confirmed!")
    else:
        print("[-] Expected match but got:", data)

    # 6. Chat: A sends message to B
    print("[*] A sending message to B")
    
    # Explicitly start chat (creates conversation if missing)
    print(f"[*] Starting chat with {id_b}")
    r = requests.post(f"{BASE_URL}/chats/start-with-user/{id_b}", headers=headers_a)
    if r.status_code != 200:
        print(f"[-] Start chat failed: {r.text}")
        return
        
    chat_data = r.json()
    chat_id = chat_data["id"]
    print(f"[*] Chat started. ID: {chat_id}")

    # Now we can verify it appears in LIST
    r = requests.get(f"{BASE_URL}/chats", headers=headers_a)
    chats = r.json()
    if not chats:
        print("[-] No chats found for A (unexpected after start)")
        return
    
    chat_id = chats[0]["id"]
    print(f"[*] Chat ID: {chat_id}")

    msg_payload = {"body": "Hello form smoke test"}
    r = requests.post(f"{BASE_URL}/chats/{chat_id}/messages", headers=headers_a, json=msg_payload)
    if r.status_code == 200:
        print("[+] Message sent")
    else:
        print(f"[-] Send message failed: {r.status_code} {r.text}")

    # 7. Reports: A reports B
    # 7. Reports: A reports B
    print("[*] A reporting B")
    # /reports (POST) { target_user_id, reason }
    r = requests.post(f"{BASE_URL}/reports", headers=headers_a, json={"target_user_id": id_b, "reason": "Spam"})
    if r.status_code == 200:
        print("[+] Report successful")
    else:
        print(f"[-] Report failed: {r.text}")

    # 8. Token Refresh Test
    print("[*] Testing Token Refresh for A")
    # Ensure login actually returned a refresh token now
    if not tokens_a.get("refresh_token"):
         print("[-] No refresh token in login response! Skipping refresh test.")
    else:
        refresh_payload = {"refresh_token": tokens_a["refresh_token"]}
        r = requests.post(f"{BASE_URL}/auth/refresh", json=refresh_payload)
        if r.status_code == 200:
            new_tokens = r.json()
            print(f"[+] Refresh successful. New access token: {new_tokens['access_token'][:10]}...")
            headers_a = {"Authorization": f"Bearer {new_tokens['access_token']}"} # Update header
        else:
            print(f"[-] Refresh failed: {r.text}")

    # 9. Block: A blocks B
    # /reports/block (POST) { target_user_id }
    print("[*] A blocking B")
    r = requests.post(f"{BASE_URL}/reports/block", headers=headers_a, json={"target_user_id": id_b})
    if r.status_code == 200:
        print("[+] Block successful")
    elif r.status_code == 404:
        print("[-] Block endpoint not found (check route)")
    else:
        print(f"[-] Block failed: {r.text}")

    # 10. Strict Block Enforcement:
    # B try to message A -> Should fail 403 or 404
    print("[*] B trying to message A (Who blocked B)")
    r = requests.post(f"{BASE_URL}/chats/{chat_id}/messages", headers=headers_b, json={"body": "Am I blocked?"})
    if r.status_code in [403, 404]:
        print(f"[+] Correctly blocked message ({r.status_code})")
    else:
        print(f"[-] Expected 403/404, got {r.status_code} {r.text}")

    # B try to get chat history -> Should fail 404 (Enumeration prevention)
    print("[*] B trying to get blocks chat history")
    r = requests.get(f"{BASE_URL}/chats/{chat_id}/messages", headers=headers_b)
    if r.status_code == 404:
         print("[+] Correctly hidden chat history (404)")
    else:
         print(f"[-] Expected 404, got {r.status_code}")

    print("[*] Smoke Test Complete")

if __name__ == "__main__":
    try:
        scenario_full_flow()
    except Exception as e:
        print(f"[-] Test crashed: {e}")
