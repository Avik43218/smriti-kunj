# Cognitive Assist — Backend

FastAPI + MongoDB backend for the AI-Powered Cognitive & Memory Assistance
Platform described in `ARCHITECTURE.md`. Implements the **Backend & Cloud
Infrastructure**, **Sync & Queue Layer (receiving side)**, and all **3 AI
Pillars**, wired end-to-end against a real (if minimal) data model.

Data layer: **Motor** (async Mongo driver) + **Beanie** (Pydantic-based ODM)
— every route is `async def` and talks to MongoDB directly through Document
classes, no separate session/repository layer needed.

## Layout

```
app/
  main.py                 FastAPI app, router registration, CORS, startup (init_db)
  config.py                 Settings (env-driven): Mongo URL/DB name, JWT secret/expiry, algorithm weights/thresholds
  database.py                Motor client + Beanie init, registers every Document model

  models/                    Beanie Documents (== the MongoDB schema)
    user.py                    User (unified caregiver/patient), DevicePairingToken
    session.py                  GameSession, VoiceInteraction  (what edge devices sync up)
    analytics.py                 DriftMetric, Alert, BanditArmState
    auth.py                       OtpCode (login 2FA challenges), RevokedToken (logout blacklist)

  schemas/                   Pydantic request/response models (auth, sync, analytics)

  core/                       The actual "3 Pillars" algorithms — pure logic, DB-agnostic
    bandit.py                    Pillar 1: UCB1 multi-armed bandit + performance score S + threshold rules
    nlu.py                        Pillar 2: intent/entity extraction from STT transcripts
    drift.py                      Pillar 3: linear-regression cognitive drift + anomaly detection
    security.py                   Password hashing (bcrypt) + JWT issuance/verification/revocation, role-based dependencies
    otp.py                         Email-OTP generation + verification (caregiver login's 2nd factor)
    alerts.py                     Alert persistence (+ TODO hook for push/email/SMS dispatch)

  services/                   Glue between API routes and core/ algorithms + DB
    difficulty_service.py        Reads/updates bandit arm state per patient+game
    analytics_service.py          Runs drift + anomaly checks after each sync batch

  api/routes/
    auth.py                       Mounted at /api/auth — /register, /login, /request-otp, /verify-otp, /logout, /me, /patient/pair/start, /patient/pair/complete
    sync.py                        POST /sync/batch  — the edge app's batched upload endpoint
    difficulty.py                  GET /difficulty/next/{game_type}  — Pillar 1
    voice.py                       POST /voice/classify  — Pillar 2 (debug/direct-test route)
    analytics.py                   GET /analytics/patient/{id}/drift|alerts  — Pillar 3
    caregiver.py                    GET /caregiver/patients, /caregiver/dashboard/{id}  (Mongo aggregation pipeline)

tests/test_core.py          Pure-logic unit tests for all 3 pillars (no DB/network required)
requirements.txt
.env.example
```

## MongoDB schema notes

- Every collection uses a `uuid.UUID` primary key (stored as BSON binary),
  not the Mongo-default ObjectId — keeps IDs consistent across services and
  easy to pass around in URLs/JSON.
- References between collections (`patient_id`, `caregiver_id`) are plain
  UUID fields, not Beanie `Link[]`s — simpler to reason about at this scale,
  and avoids extra round-trips. Fetch related docs with a second query
  (see `_ensure_own_patient` in `api/routes/analytics.py`).
- Indexes are declared right on the Document classes (`Indexed(...)`, or a
  `Settings.indexes` list for compound ones like `BanditArmState`'s
  `(patient_id, game_type, arm_key)` uniqueness constraint) and are created
  automatically by `init_beanie()` on startup.
- `caregiver.dashboard()` uses a real `$group`/`$dateToString` aggregation
  pipeline instead of pulling every session into Python — worth keeping an
  eye on as an example pattern for any other rollup endpoint you add.

## How this maps to the architecture diagram

- **Backend & Cloud Infrastructure** box → `app/main.py`, `database.py`,
  `api/routes/caregiver.py` (Caregiver Portal API — pair this with any
  frontend charting library).
- **Sync & Queue Layer** (client-side background sync manager / payload
  queueing) → the *receiving* half lives in `api/routes/sync.py`: idempotent
  ingestion keyed on `client_session_id`, timestamp-based writes.
- **Pillar 1 / 2 / 3** boxes → `core/bandit.py`, `core/nlu.py`, `core/drift.py`,
  invoked from `services/` right after a sync batch lands.
- **Alerts** feedback arrow → `core/alerts.py` + `analytics_service.py`,
  surfaced through `api/routes/analytics.py` to the Caregiver Portal.
- **Authentication** (unified role-based, self-hosted) →
  `core/security.py`, `core/otp.py` + `models/user.py`, `models/auth.py`.
  Diverges from the Firebase/Auth0 suggestion in `ARCHITECTURE.md` by
  design — credentials (bcrypt password hashes) are stored directly in the
  `users` collection instead of an external identity provider.

## Caregiver auth flow

Routes are mounted at `/api/auth` to match a provided frontend client
(`authService.js`). Caregiver login is **two-factor** — password, then an
email OTP — because that client only ever persists a token after
`verifyOtp()`, never after `login()`:

1. `POST /api/auth/register` — creates the account (bcrypt-hashed password). No token yet.
2. `POST /api/auth/login` — validates the password and sends a 6-digit OTP to the caregiver's email (stubbed to a log line — wire up a real provider before production). Still no token.
3. `POST /api/auth/request-otp` — resends the code ("Didn't get it?"). Always returns a generic message so it can't be used to enumerate registered emails.
4. `POST /api/auth/verify-otp` — checks the code (max attempts + expiry enforced) and, only here, issues the session: `{ "token": "<jwt>", "caregiver": {...} }`.
5. `POST /api/auth/logout` — records the token's `jti` in a `revoked_tokens` collection so it stops being accepted immediately, even before it naturally expires.

Patient auth is unchanged: a caregiver starts a pairing at
`/api/auth/patient/pair/start`, the tablet redeems it at
`/api/auth/patient/pair/complete` and is issued its own long-lived device
token — no password, no OTP.

**Known trade-off:** `/request-otp` only takes an email (no password), so
it can be called to (re)send a code without proving password knowledge
first. That's intentional for the resend UX, but means the real
authentication guarantee rests entirely on OTP secrecy + rate limiting
(currently just a max-attempts counter per code). Add per-email/per-IP
rate limiting on `/login` and `/request-otp` before production.

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env
# edit .env: MONGODB_URL, MONGODB_DB_NAME, JWT_SECRET_KEY

# either run MongoDB locally...
docker run -d -p 27017:27017 --name cognitive-assist-mongo mongo:7
# ...or point MONGODB_URL at an Atlas connection string.

uvicorn app.main:app --reload
```

Collections and indexes are created automatically on startup via
`init_beanie()` — no separate migration step needed for a Mongo schema
this shape, since it's schemaless at the DB level (Beanie/Pydantic enforce
structure at the application layer).

## What's stubbed vs. real

| Component | Status |
|---|---|
| UCB1 bandit (Pillar 1) | Real algorithm, in-memory-testable |
| Performance score S, threshold grid scaling | Real, matches the formula in ARCHITECTURE.md |
| Linear regression drift + anomaly detection (Pillar 3) | Real (numpy), thresholds are tunable via `config.py` |
| NLU intent/entity extraction (Pillar 2) | Keyword-matching placeholder — swap `core/nlu.py` for a trained/cloud classifier; the STT/VAD/TTS pipeline itself runs on-device per the architecture, this module only handles the transcript the edge app sends up |
| Password hashing + JWT auth (self-hosted) | Real — bcrypt hashing, JWT issuance/verification, no external provider. Rotate `JWT_SECRET_KEY` and put it behind a secrets manager before production |
| Email-OTP 2FA + logout revocation | Real logic (generation, hashing, expiry, attempt limits, JWT blacklist) — OTP delivery itself is a stubbed `print()` in `api/routes/auth.py`, swap for a real email provider |
| Alert dispatch (push/email/SMS) | Persisted to Mongo; dispatch is a `# TODO` in `core/alerts.py` |
| Drift/anomaly recompute cadence | Runs synchronously after every sync batch — fine at pilot scale; move to a scheduled worker (Celery beat / APScheduler) once patient volume grows |

## Not built here (client-side, per the diagram)

Flutter/React Native app, local SQLite/IndexedDB schema, background sync
worker isolate, on-device VAD/STT/TTS, and the accessibility UI — all live
in the edge app repo, not this backend.

## Tests

```bash
pytest tests/
```

Covers the bandit's explore/exploit behavior, the performance-score formula,
threshold-based difficulty adaptation, drift detection on synthetic
declining vs. stable score series, anomaly detection, NLU entity
extraction, password hashing + JWT issuance (including per-token `jti`s),
and OTP generation/hashing/verification — all without needing a database or
network connection. (`get_current_user`'s DB lookup, and the `/auth/*`
route handlers themselves, are the pieces that need a live Mongo instance
to exercise end-to-end.)
