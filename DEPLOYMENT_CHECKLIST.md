# Deployment Checklist & Operations

## 1. Scale & Persistence Configuration (CRITICAL)
Fly.io treats local disks as ephemeral unless a Volume is mounted manually.
To avoid data loss (splitting brain or ephemeral filesystem):

- [ ] **Scale to 1 Instance Only:** (SQLite restriction)
  ```bash
  fly scale count 1 -a celestya-backend
  ```
- [ ] **Verify Volume Mount:**
  Ensure `fly.toml` has:
  ```toml
  [mounts]
  source = "celestya_data"
  destination = "/data"
  ```

## 2. Validation after Deploy
Run these commands locally or ssh into the machine to verify persistence.

### Option A: Via Admin Endpoint (Recommended)
Requires `ADMIN_SECRET` to be set in Fly secrets.
```bash
curl -H "X-Admin-Secret: YOUR_SECRET_HERE" https://celestya-backend.fly.dev/admin/stats
```
**Expected Output:**
- `db_path_resolved`: should be `/data/celestya.db`
- `db_exists`: true
- `backup_count`: number of backups available

### Option B: SSH Verification
```bash
fly ssh console -a celestya-backend
python3 scripts/verify_db_path.py
```

## 3. Backups
Backups are stored in `/data/backups/` and rotated automatically (last 7 days).

### Manual Backup Run
```bash
fly ssh console -a celestya-backend
python3 scripts/backup_db.py
```
*Logs will indicate if R2 upload was attempted/successful.*

### Restore (Emergency)
1. SSH into machine.
2. Stop app process (or just ensure no writes).
3. `cp /data/backups/celestya_TIMESTAMP.db /data/celestya.db`
4. Restart machine: `fly machine restart`

## 4. Environment Variables
Ensure these are set in Fly:
- `ENV`: `production`
- `ADMIN_SECRET`: (Secure Random String)
- `DATABASE_URL`: `sqlite:////data/celestya.db` (Now enforced by code, but good to have)

### Optional (R2 Backups)
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET_NAME`
- `R2_ENDPOINT_URL`
