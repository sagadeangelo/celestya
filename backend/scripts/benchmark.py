import time
import requests
import statistics
import os

BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")
# Valid user credentials for testing
EMAIL = "user1@example.com" 
PASSWORD = "password123"

def benchmark_endpoint(method, url, payload=None, headers=None, runs=10):
    times = []
    print(f"[*] Benchmarking {method} {url} ({runs} runs)...")
    for i in range(runs):
        start = time.time()
        try:
            if method == "POST":
                r = requests.post(url, json=payload, data=payload if 'username' in payload else None, headers=headers)
            else:
                r = requests.get(url, headers=headers)
            r.raise_for_status()
            duration = (time.time() - start) * 1000
            times.append(duration)
            # print(f"    Run {i+1}: {duration:.2f}ms")
        except Exception as e:
            print(f"    Run {i+1}: FAILED ({e})")
    
    if not times:
        return 0
    
    avg_time = statistics.mean(times)
    p95_time = statistics.quantiles(times, n=20)[-1] if len(times) >= 20 else max(times)
    
    print(f"    --> Avg: {avg_time:.2f}ms | Max: {max(times):.2f}ms")
    return avg_time

def main():
    print(f"Target: {BASE_URL}")
    
    # 0. Setup User
    print("[*] Setting up benchmark user...")
    register_payload = {
        "email": EMAIL,
        "password": PASSWORD,
        "name": "Benchmark User",
        "birthdate": "1990-01-01"
    }
    # Try register (ignore if exists, assuming password matches or we catch 400/409)
    try:
        rr = requests.post(f"{BASE_URL}/auth/register", json=register_payload)
        if rr.status_code == 200:
            print("[+] Registered benchmark user.")
            # Verify email manually if needed (or assume loose verification for now)
            # For simplicity in local env, we might need to manually verify if login requires it.
            # But let's try login first.
    except Exception as e:
        print(f"[-] Register error: {e}")

    # 0b. Manually Verify User
    import sqlite3
    try:
        db_path = "celestya.db"
        if os.path.exists(db_path):
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("UPDATE users SET email_verified=1 WHERE email=?", (EMAIL,))
            conn.commit()
            conn.close()
            print("[+] Manually verified benchmark user in DB.")
        else:
            print("[-] DB file not found, verification skipped.")
    except Exception as e:
        print(f"[-] DB Update failed: {e}")

    # 1. Login
    login_payload = {"username": EMAIL, "password": PASSWORD}
    auth_times = []
    token = None
    
    # Run login benchmark
    # Note: Login effectively "writes" (updates last_login), so be careful running too many times if limiter is strict.
    # We'll do 5 runs.
    print("[*] Benchmarking /auth/login (5 runs)...")
    for _ in range(5):
        start = time.time()
        r = requests.post(f"{BASE_URL}/auth/login", data=login_payload)
        if r.status_code == 200:
            auth_times.append((time.time() - start) * 1000)
            token = r.json()["access_token"]
        else:
            print(f"Login failed: {r.status_code}")
    
    if auth_times:
        print(f"    --> Avg Login: {statistics.mean(auth_times):.2f}ms")
    else:
        print("[-] Login completely failed. Cannot proceed.")
        return

    headers = {"Authorization": f"Bearer {token}"}

    # 2. Suggested Matches
    benchmark_endpoint("GET", f"{BASE_URL}/matches/suggested", headers=headers, runs=10)

    # 3. Chats (List)
    benchmark_endpoint("GET", f"{BASE_URL}/chats/experiments", headers=headers, runs=10) # Using experiments or main chats endpoint if widely available

    # 4. User Profile (Me)
    benchmark_endpoint("GET", f"{BASE_URL}/users/me", headers=headers, runs=10)

if __name__ == "__main__":
    main()
