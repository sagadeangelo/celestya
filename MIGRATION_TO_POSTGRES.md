# Migration to PostgreSQL (Phase 2 Strategy)

## Strategy
We will move from SQLite to PostgreSQL to enable better concurrency, scalability, and managed backup features.

**Approach:** ETL (Extract, Transform, Load) script using SQLAlchemy.
We will **read** from the existing SQLite file and **insert** into the new Postgres database, preserving Primary Keys.

---

## Steps

### 1. Setup Postgres
- Provision Postgres database (Hetzner Managed or Self-Hosted Docker).
- Get `DATABASE_URL`: `postgres://user:pass@host:5432/celestya`

### 2. Prepare Codebase
- Ensure `backend/app/database.py` supports the `postgres://` URL scheme (Completed).
- Ensure `alembic` is configured.
- **Run Migrations:**
  Point `DATABASE_URL` to Postgres and run:
  ```bash
  DATABASE_URL=postgres://... alembic upgrade head
  ```
  *This creates the empty tables in Postgres.*

### 3. Migrate Data
- **Stop Writes:** The app must be in maintenance mode.
- **Run Migration Script:**
  We will use `backend/scripts/migrate_sqlite_to_postgres.py`.
  ```bash
  python3 backend/scripts/migrate_sqlite_to_postgres.py \
    --sqlite /data/celestya.db \
    --postgres postgres://user:pass@host:5432/celestya
  ```

### 4. Verification
- Compare Row Counts (`/admin/stats`).
- Compare specific User IDs.
- Log in with a test user.

### 5. Switch
- Update `DATABASE_URL` env var in the running backend service.
- Restart service.

---

## Data Mapping & Considerations
- **Booleans:** SQLite stores as `0`/`1` (int). Postgres uses `true`/`false`. The script must handle this.
- **JSON:** Some columns (`photo_urls`, `interests`) are stored as TEXT in SQLite but JSONB in Postgres.
- **Timestamps:** Ensure Timezones are preserved (UTC).
