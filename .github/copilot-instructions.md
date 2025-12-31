# Copilot / AI Agent Instructions for Celestya 🚀

## Quick summary
- Celestya is a small Flutter mobile client + FastAPI backend (Python). The backend lives in `backend/` and the Flutter app in `celestya/` and `lib/`.
- Primary flows: user registration → email verification → login → upload profile photo → request matches.

## Key files & components 🔧
- Backend
  - `backend/app/main.py` — FastAPI app and routers registration
  - `backend/routes/*` — `auth.py`, `users.py`, `matches.py` (main endpoints)
  - `backend/app/security.py` — JWT and token helpers (see `create_access_token`, `hash_token`)
  - `backend/app/emailer.py` — sends verification email (prints link to console when SMTP not configured)
  - `backend/.env.example` — important env vars (SECRET_KEY, DATABASE_URL, MEDIA_ROOT, PUBLIC_BASE_URL, ALLOWED_ORIGINS)
  - DB: default SQLite `celestya.db` (see `backend/app/database.py`)

- Flutter (client)
  - `lib/services/api_client.dart` — **API_BASE is hardcoded** to `http://127.0.0.1:8000` (change here for env/config)
  - `lib/services/auth_api.dart` — login (form-encoded) & register (JSON)
  - `lib/services/users_api.dart` — `GET /users/me`, `POST /users/me/photo` (multipart)
  - `lib/screens/` — UI screens (Login currently uses TEMP navigation and is not wired to `AuthApi` yet)

## Important behavioral details (do not change lightly) ⚠️
- Authentication:
  - `/auth/login` expects `application/x-www-form-urlencoded` with `username` and `password` and returns `{"access_token": ...}`.
  - `/auth/register` expects JSON and returns an `access_token` but logins are blocked until email verification (`email_verified` enforced in backend).
  - Access token encoding/decoding is in `backend/app/security.py` (JWT with `SECRET_KEY` env var).
- Email verification:
  - If SMTP env is unset, `emailer.send_email()` will print the verification HTML to the console instead of failing — useful for local development.
- Media/files:
  - Static `MEDIA_ROOT` (env var) is served at `GET /media/<filename>` via `FastAPI StaticFiles`.
- Flutter storage & headers:
  - `ApiClient._headers` reads `auth_token` from `SharedPreferences`. Ensure any UI wiring saves token under key `'auth_token'`.

## Dev / run commands ✅
- Backend (Windows example):
  - cd into `backend`
  - python -m venv .venv
  - .venv\Scripts\activate
  - pip install -r requirements.txt
  - export/set env vars (see `.env.example`) — e.g. `SECRET_KEY`, `PUBLIC_BASE_URL` and `MEDIA_ROOT`
  - run: `uvicorn app.main:app --reload --port 8000`

- Flutter (client):
  - cd into `celestya`
  - `flutter pub get`
  - `flutter run` (or run from your IDE)

## Typical agent tasks & concrete example fixes 💡
- Wire login in `lib/screens/login_screen.dart` to call `AuthApi.login(...)`, store returned token in `SharedPreferences` as `auth_token`, then navigate to `/app`. (Currently `_login()` only navigates after a delay.)
- Remove hardcoded `ApiClient.API_BASE` and add a small env/config wrapper (e.g., use `--dart-define` or a `Config` class) so mobile can point at different backend hosts during development.
- Add a small test or script that registers a new user, fetches console output for the verification link (when SMTP is unset), hits `/auth/verify-email?token=...` and then logs in — good warmup E2E test for CI.

## Conventions & style notes 📝
- Code comments and UI strings are in Spanish; prefer Spanish in quick messages and PR descriptions unless asked otherwise.
- Security: tokens for email verification are saved as SHA-256 hashes (`email_verification_token_hash`) — the plain token is sent in the email link but only the hash is stored.
- Keep API contract expectations (form-encoded for login, JSON for register) intact unless updating both backend and client.

## Integration points & things to watch 🧭
- `PUBLIC_BASE_URL` controls the verification link generation (`backend/routes/auth.py`). When running in containers or remote dev machines, make sure this points to where the client (or developer) can reach the backend.
- CORS is configured via `ALLOWED_ORIGINS` env var in `backend/app/main.py`.
- Be cautious changing `SECRET_KEY` and migration behavior for production data.

---

If you'd like, I can:
1) Implement a quick patch wiring login to `AuthApi` and saving `auth_token` (small PR), or
2) Add a `Config` wrapper to the Flutter app to externalize `API_BASE`.

Please tell me which of those (or other items) you want prioritized, or point out any missing area you'd like documented or exemplified. ✅