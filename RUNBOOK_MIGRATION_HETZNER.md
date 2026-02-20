# Runbook: Migration to Hetzner (Phase 1: SQLite Lift & Shift)

## Overview
This runbook details the steps to move the Celestya backend from Fly.io to a Hetzner server while keeping the exact same SQLite database file.

**Goal:** Zero data loss. Minimal downtime.
**Prerequisites:**
- SSH access to both Fly.io (via `fly ssh`) and Hetzner.
- `backend/scripts/export_sqlite.py` deployed on Fly.
- `backend/scripts/import_sqlite.py` ready on local machine or Hetzner.

---

## 1. Preparation (T-Minus 1 Hour)
- [ ] **Verify Backup:** Run a manual backup on Fly.
  ```bash
  fly ssh console -C "python3 backend/scripts/backup_db.py"
  ```
- [ ] **Check Integrity:**
  Ensure `/admin/schema` returns `ok: true`.

- [ ] **Prepare Hetzner Server:**
  - Ensure Docker/Python environment is ready.
  - Create `/data` directory: `mkdir -p /data`

---

## 2. Maintenance Mode (Start Maintenance Window)
- [ ] **Scale Down:** Prevent new writes (concurrency safety).
  ```bash
  fly scale count 1 -a celestya-backend
  ```
- [ ] **(Optional) Stop Traffic:**
  If possible, update load balancer to return 503 or stop the app container completely to ensure absolute lock.
  ```bash
  fly scale count 0 -a celestya-backend
  # WAIT 1 minute for connections to drain
  # Note: To run the export script, we might need one machine up, OR use `fly ssh console` on a suspended machine if volumes allow (usually need a running machine).
  # BETTER STRATEGY: 
  # Leave 1 machine running but block traffic (firewall) OR just rely on `export_sqlite.py` WAL checkpoint.
  # We will assume 1 machine running for the export command.
  ```

---

## 3. Export Data (Fly.io)
- [ ] **Run Export Script:**
  ```bash
  fly ssh console -C "python3 backend/scripts/export_sqlite.py"
  ```
  **Output to capture:**
  - Path: `/data/exports/celestya_export_YYYYMMDD_... .db`
  - SHA256 Hash: `...`

- [ ] **Download Export:**
  Use SFTP or `fly sftp get` to pull the file to your local machine.
  ```bash
  fly sftp get /data/exports/celestya_export_TIMESTAMP.db
  ```

---

## 4. Transfer & Import (Hetzner)
- [ ] **Upload to Hetzner:**
  ```bash
  scp celestya_export_TIMESTAMP.db user@hetzner_ip:/tmp/import.db
  ```

- [ ] **Run Import Script:**
  ```bash
  # Assuming code is deployed at /app
  cd /app
  python3 backend/scripts/import_sqlite.py /tmp/import.db --dest /data/celestya.db
  ```
  **Must see:** `✅ Import successful`

- [ ] **Verify Hash:**
  Check that the hash matches the one from Fly.io.
  ```bash
  sha256sum /data/celestya.db
  ```

---

## 5. Go Live
- [ ] **Start Backdrop Service:**
  Start your Docker container/service on Hetzner.
  
- [ ] **Verify Admin Endpoints:**
  ```bash
  curl -H "X-Admin-Secret: ..." http://localhost:8000/admin/stats
  curl -H "X-Admin-Secret: ..." http://localhost:8000/admin/schema
  ```

- [ ] **Switch DNS:**
  Update your domain (Cloudflare/Namecheap/etc) A records to point to Hetzner IP.

- [ ] **Verify Traffic:**
  Watch logs on Hetzner.

---

## 6. Cleanup (Post-Migration)
- [ ] **Scale Fly to 0:**
  Once confirmed stable (after 1-2 hours), verify no traffic hitting Fly.
  ```bash
  fly scale count 0 -a celestya-backend
  ```

## Rollback Plan
If Import fails or Hetzner server is unstable:
1.  **Do not switch DNS.**
2.  **Scale Fly back up:** `fly scale count 1` (or whatever original count was).
3.  **Investigate logs.**
