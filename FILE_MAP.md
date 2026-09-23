# Smriti Setu (Smriti Kunj) — Workspace File Directory & Architecture Map

This document serves as a comprehensive inventory and functional mapping of all primary files across the **Smriti Setu / Smriti Kunj** codebase. It outlines what each file holds, its core purpose, primary exported functions/classes/components, and details how data flows across the system tiers.

---

## 1. System Architecture Overview

The system is designed for elderly individuals with Mild Cognitive Impairment (MCI) and early-stage dementia, along with their caregivers:
- **Patient Tablet App (`src/patient_app`)**: Built with Flutter (Dart). Operates strictly **offline-first** with local SQLite databases (`sqflite`), 88dp+ dementia-accessible touch targets, multilingual voice navigation (Assamese, Bengali, Bodo, English), and culturally adapted cognitive exercises.
- **Backend API (`src/backend`)**: Built with Python FastAPI, Motor, and Beanie ODM over MongoDB. Handles two-phase caregiver authentication (Password + OTP), patient device pairing tokens, batch telemetry synchronization, Multi-Armed Bandit (MAB) dynamic difficulty adaptation, linear regression drift detection, and automated clinical risk grading.
- **Caregiver Web Application (`src/frontend/caregiver_app`)**: Built with React 18, Vite, and Tailwind CSS. Features Recharts data visualizations for longitudinal cognitive metrics, patient onboarding, memory card management, daily schedule compliance tracking, and ML-driven risk alerts.
- **ML & Data Pipeline (`root`)**: Python utilities for training GradientBoosting / XGBoost clinical risk classification models (`train_xg.py`), real-time batch inference (`risk_batch_inference.py`), and MongoDB labeled clinical dataset exports (`mongo_label.py`).

---

## 2. Comprehensive File Inventory & Functional Directory

### 2.1 Backend Service (`src/backend/app`)

#### Core, Server & Configuration
| File Path | Core Purpose | Primary Exported Functions / Classes / Components |
| :--- | :--- | :--- |
| [`src/backend/app/main.py`](file:///home/shreya/smriti-setu/src/backend/app/main.py) | Application entrypoint. Configures FastAPI, CORS middleware, mounts all API route handlers, runs database startup initialization, and serves `/health` and `/ping` probes. | `app`, `on_startup()`, `health()`, `ping()` |
| [`src/backend/app/database.py`](file:///home/shreya/smriti-setu/src/backend/app/database.py) | Async database connection manager. Initializes Motor async MongoDB client and binds Beanie ODM document models. | `init_db()`, `client`, `db` |
| [`src/backend/app/config.py`](file:///home/shreya/smriti-setu/src/backend/app/config.py) | Application configuration loader using Pydantic `BaseSettings`. Loads JWT secret keys, MongoDB URIs, and SMTP email parameters. | `Settings`, `get_settings()` |

#### Core Algorithms & Security (`src/backend/app/core`)
| File Path | Core Purpose | Primary Exported Functions / Classes / Components |
| :--- | :--- | :--- |
| [`src/backend/app/core/security.py`](file:///home/shreya/smriti-setu/src/backend/app/core/security.py) | Security and authorization engine. Handles bcrypt password hashing, JWT generation for Caregiver/Admin/Patient Device roles, and FastAPI security dependencies. | `hash_password()`, `verify_password()`, `create_caregiver_token()`, `create_admin_token()`, `create_patient_device_token()`, `revoke_current_token()`, `get_current_user()`, `require_caregiver()`, `require_admin()`, `require_patient()` |
| [`src/backend/app/core/otp.py`](file:///home/shreya/smriti-setu/src/backend/app/core/otp.py) | Two-factor authentication OTP logic. Generates cryptographically secure 6-digit codes and verifies hashed representations. | `generate_otp()`, `hash_otp()`, `verify_otp_code()` |
| [`src/backend/app/core/bandit.py`](file:///home/shreya/smriti-setu/src/backend/app/core/bandit.py) | **Pillar 1 Dynamic Difficulty Adaptation**. Implements Multi-Armed Bandit (MAB) using Upper Confidence Bound (UCB) to balance exploration vs. exploitation across game difficulties. | `Arm`, `performance_score()`, `select_arm()`, `next_difficulty()` |
| [`src/backend/app/core/drift.py`](file:///home/shreya/smriti-setu/src/backend/app/core/drift.py) | **Pillar 3 Cognitive Drift & Anomaly Detection**. Computes ordinary least squares (OLS) linear regression slopes over rolling 7-day/30-day windows and detects drops exceeding 25%. | `DriftResult`, `compute_drift()`, `detect_anomaly()` |
| [`src/backend/app/core/alerts.py`](file:///home/shreya/smriti-setu/src/backend/app/core/alerts.py) | Alert generation service. Constructs and commits clinical deterioration alerts to MongoDB with timestamp and severity levels. | `raise_alert()` |
| [`src/backend/app/core/nlu.py`](file:///home/shreya/smriti-setu/src/backend/app/core/nlu.py) | **Pillar 2 Voice AI Understanding**. Lightweight rule-based Natural Language Understanding parser mapping transcribed speech to navigational intents and schedule task entities. | `classify()` |

#### Business Services (`src/backend/app/services`)
| File Path | Core Purpose | Primary Exported Functions / Classes / Components |
| :--- | :--- | :--- |
| [`src/backend/app/services/risk_model_service.py`](file:///home/shreya/smriti-setu/src/backend/app/services/risk_model_service.py) | Supervised machine learning inference service. Loads `xgboost_patient_risk_model.pkl` and evaluates patient risk grades (Grade 0 Low, Grade 1 Moderate, Grade 2 High). | `resolve_model_path()`, `get_risk_model()`, `evaluate_patients_risk()` |
| [`src/backend/app/services/difficulty_service.py`](file:///home/shreya/smriti-setu/src/backend/app/services/difficulty_service.py) | Cognitive challenge orchestrator. Evaluates completed game sessions, updates bandit arm rewards, and recommends optimal next challenge parameters. | `update_bandit()`, `recommend_difficulty()` |
| [`src/backend/app/services/analytics_service.py`](file:///home/shreya/smriti-setu/src/backend/app/services/analytics_service.py) | Session data analyzer. Gathers recent game session scores for patients, evaluates longitudinal trends, and triggers anomaly checks. | `run_anomaly_check()` |
| [`src/backend/app/services/email_service.py`](file:///home/shreya/smriti-setu/src/backend/app/services/email_service.py) | Transactional email dispatcher. Formats and sends HTML emails containing 6-digit 2FA login OTPs. | `send_otp_email()` |

#### API Route Handlers (`src/backend/app/api/routes`)
| File Path | Core Purpose | Primary Exported Functions / Endpoints |
| :--- | :--- | :--- |
| [`src/backend/app/api/routes/auth.py`](file:///home/shreya/smriti-setu/src/backend/app/api/routes/auth.py) | Authentication endpoints: caregiver registration, password authentication, OTP request/verification, and patient device pairing code generation/claim. | `POST /register`, `POST /login`, `POST /request-otp`, `POST /verify-otp`, `POST /logout`, `GET /me`, `POST /patient/pair/start`, `POST /patient/pair/complete`, `GET /patient/me` |
| [`src/backend/app/api/routes/caregiver.py`](file:///home/shreya/smriti-setu/src/backend/app/api/routes/caregiver.py) | Caregiver patient management: patient profile creation, roster retrieval, detail views, deletion, and dashboard aggregated stats. | `GET /patients`, `POST /patients/register`, `GET /patients/{id}`, `DELETE /patients/{id}`, `GET /dashboard` |
| [`src/backend/app/api/routes/patients.py`](file:///home/shreya/smriti-setu/src/backend/app/api/routes/patients.py) | Patient care plan and schedule: family memory photos, audio reminiscence clips, daily reminders/alarms, and historical game sessions. | `GET/POST /patients/{id}/family-members`, `GET /patients/{id}/reminders`, `PUT /patients/{id}/reminders/categories/{cat}`, `POST /patients/{id}/reminders/custom`, `GET /patients/{id}/game-sessions` |
| [`src/backend/app/api/routes/sync.py`](file:///home/shreya/smriti-setu/src/backend/app/api/routes/sync.py) | Offline-first synchronization gateway. Ingests batched, compressed session arrays from patient tablets and writes them to MongoDB. | `POST /sync/batch`, `resolve_sync_patient()` |
| [`src/backend/app/api/routes/risk.py`](file:///home/shreya/smriti-setu/src/backend/app/api/routes/risk.py) | Clinical ML risk endpoints. Runs batch prediction over patient cognitive vectors and provides caregiver overview tables with color badges. | `POST /risk/predict`, `GET /risk/overview` |
| [`src/backend/app/api/routes/analytics.py`](file:///home/shreya/smriti-setu/src/backend/app/api/routes/analytics.py) | Analytics endpoints returning linear regression drift trends, domain scores, and unacknowledged alerts. | `GET /analytics/patients/{id}/drift`, `GET /analytics/patients/{id}/alerts` |
| [`src/backend/app/api/routes/difficulty.py`](file:///home/shreya/smriti-setu/src/backend/app/api/routes/difficulty.py) | Difficulty recommendation endpoint allowing edge devices to query the latest MAB bandit difficulty when connected. | `GET /difficulty/{patient_id}/{game_type}/next` |
| [`src/backend/app/api/routes/voice.py`](file:///home/shreya/smriti-setu/src/backend/app/api/routes/voice.py) | Natural language classification endpoint processing transcribed voice commands from edge devices. | `POST /voice/classify` |
| [`src/backend/app/api/routes/admin.py`](file:///home/shreya/smriti-setu/src/backend/app/api/routes/admin.py) | System administrator endpoints for managing caregivers and reassigning patients. | `GET/POST /admin/caregivers`, `PUT/DELETE /admin/caregivers/{id}`, `GET /admin/patients`, `POST /admin/patients/reassign` |

#### MongoDB Document Models (`src/backend/app/models`)
| File Path | Core Purpose | Primary Models / Classes |
| :--- | :--- | :--- |
| [`src/backend/app/models/user.py`](file:///home/shreya/smriti-setu/src/backend/app/models/user.py) | User documents (Caregiver, Admin, Patient) and device pairing verification records. | `User`, `RoleEnum`, `DevicePairingToken` |
| [`src/backend/app/models/session.py`](file:///home/shreya/smriti-setu/src/backend/app/models/session.py) | Canonical cognitive game sessions, raw millisecond trial logs, and voice recall logs. | `GameSession`, `VoiceInteraction` |
| [`src/backend/app/models/reminder.py`](file:///home/shreya/smriti-setu/src/backend/app/models/reminder.py) | Daily medication, hydration, meal, and custom reminders with adherence tracking. | `PatientReminder` |
| [`src/backend/app/models/care_plan.py`](file:///home/shreya/smriti-setu/src/backend/app/models/care_plan.py) | Family member profiles for reminiscence memory cards and personalized pair-matching games. | `FamilyMember` |
| [`src/backend/app/models/analytics.py`](file:///home/shreya/smriti-setu/src/backend/app/models/analytics.py) | Cognitive drift trend metrics, system alerts, and persistent MAB bandit arm states. | `DriftMetric`, `Alert`, `AlertSeverity`, `BanditArmState` |
| [`src/backend/app/models/auth.py`](file:///home/shreya/smriti-setu/src/backend/app/models/auth.py) | Ephemeral OTP codes and revoked JWT token blacklists. | `OtpCode`, `RevokedToken` |

---

### 2.2 Caregiver Web Application (`src/frontend/caregiver_app`)

#### Context & Services (`src/frontend/caregiver_app/src`)
| File Path | Core Purpose | Primary Exported Functions / Components |
| :--- | :--- | :--- |
| [`src/frontend/caregiver_app/src/context/AuthContext.jsx`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/context/AuthContext.jsx) | Global caregiver authentication state provider. Manages JWT storage, active user profile, login status, and logout routines. | `AuthProvider`, `useAuth()` |
| [`src/frontend/caregiver_app/src/context/ThemeContext.jsx`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/context/ThemeContext.jsx) | Global theme provider managing dark/light modes and cultural UI theme variants. | `ThemeProvider`, `useTheme()` |
| [`src/frontend/caregiver_app/src/services/apiClient.js`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/services/apiClient.js) | Centralized HTTP fetch client attaching JWT Bearer headers, parsing responses, and handling 401 unauthenticated redirects. | `apiClient` |
| [`src/frontend/caregiver_app/src/services/authService.js`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/services/authService.js) | Caregiver authentication API service: registers users, verifies passwords, requests OTPs, and verifies 2FA codes. | `register()`, `registerAdmin()`, `login()`, `requestOtp()`, `verifyOtp()`, `logout()` |
| [`src/frontend/caregiver_app/src/services/patientService.js`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/services/patientService.js) | Patient management service: fetches patient rosters, onboard new patients, retrieves profiles, and computes care statuses. | `fetchPatients()`, `registerPatient()`, `getPatientById()`, `deletePatient()`, `updatePatient()`, `CARE_STATUS` |
| [`src/frontend/caregiver_app/src/services/carePlanService.js`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/services/carePlanService.js) | Reminiscence service: fetches and uploads family member photos, descriptions, and audio notes. | `fetchFamilyMembers()`, `addFamilyMember()`, `saveCarePlan()` |
| [`src/frontend/caregiver_app/src/services/reminderService.js`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/services/reminderService.js) | Schedule management service: manages category alarms, custom reminders, and computes daily adherence rates. | `fetchReminders()`, `updateCategoryReminders()`, `addCustomReminder()`, `getTodayComplianceSummary()` |
| [`src/frontend/caregiver_app/src/services/gameSessionService.js`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/services/gameSessionService.js) | Analytics data service: formats cognitive domains, maps game types, and parses session history. | `getGameSessions()`, `formatSessionDate()`, `formatDuration()`, `DOMAINS`, `GAME_TYPES` |
| [`src/frontend/caregiver_app/src/services/riskService.js`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/services/riskService.js) | Machine learning clinical risk service: fetches ML risk levels, badge colors, and recommended clinical actions. | `fetchPatientRiskOverview()`, `RISK_LEVEL_CONFIG` |
| [`src/frontend/caregiver_app/src/services/cacheService.js`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/services/cacheService.js) | Stale-While-Revalidate (SWR) LocalStorage caching layer providing instant UI loading and offline fallback. | `swrFetch()`, `readCache()`, `writeCache()`, `invalidateCache()` |
| [`src/frontend/caregiver_app/src/services/adminService.js`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/services/adminService.js) | System administrative client for managing caregiver accounts and patient ownership transfers. | `getCaregivers()`, `createCaregiver()`, `updateCaregiver()`, `deleteCaregiver()`, `getAllPatients()`, `reassignPatient()` |

#### Pages & Layouts (`src/frontend/caregiver_app/src/pages`)
| File Path | Core Purpose | Primary Exported Component |
| :--- | :--- | :--- |
| [`src/frontend/caregiver_app/src/pages/Login.jsx`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/pages/Login.jsx) | Two-phase authentication screen: password validation followed by 6-digit OTP verification with demo auto-fill. | `Login` (default) |
| [`src/frontend/caregiver_app/src/pages/Register.jsx`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/pages/Register.jsx) | Caregiver sign-up interface featuring live password strength scoring. | `Register` (default) |
| [`src/frontend/caregiver_app/src/pages/Dashboard.jsx`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/pages/Dashboard.jsx) | Central portal landing screen: shows patient cards, search filters, alert statuses, and the clinical risk summary widget. | `Dashboard` (default) |
| [`src/frontend/caregiver_app/src/pages/RegisterPatient.jsx`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/pages/RegisterPatient.jsx) | Comprehensive multi-step patient registration wizard (medical diagnosis, emergency contacts, pairing code generation). | `RegisterPatient` (default) |
| [`src/frontend/caregiver_app/src/pages/PatientDetails.jsx`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/pages/PatientDetails.jsx) | Medical profile view displaying hardware pairing status, emergency guardian contacts, and lifestyle factors. | `PatientDetails` (default) |
| [`src/frontend/caregiver_app/src/pages/CarePlan.jsx`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/pages/CarePlan.jsx) | Interactive care plan editor for reminiscence cards, audio prompts, and daily schedule reminder toggles. | `CarePlan` (default) |
| [`src/frontend/caregiver_app/src/pages/Analytics.jsx`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/pages/Analytics.jsx) | Deep cognitive analytics screen featuring Recharts multi-domain performance curves, drift slopes, and session logs. | `Analytics` (default) |
| [`src/frontend/caregiver_app/src/components/PatientRiskOverviewTable.jsx`](file:///home/shreya/smriti-setu/src/frontend/caregiver_app/src/components/PatientRiskOverviewTable.jsx) | High-level clinical dashboard table rendering XGBoost risk predictions (Grades 0-2) and recommended caregiver actions. | `PatientRiskOverviewTable` (default) |

---

### 2.3 Patient Mobile/Tablet Application (`src/patient_app/lib`)

#### Application Entry & Services (`src/patient_app/lib/services`)
| File Path | Core Purpose | Primary Exported Classes / Components |
| :--- | :--- | :--- |
| [`src/patient_app/lib/main.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/main.dart) | Application initialization. Sets up MultiProvider, initializes databases, configures high-contrast themes, and defines navigation routes. | `main()`, `SmritiKunjApp` |
| [`src/patient_app/lib/services/session_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/session_service.dart) | Application session state. Stores tablet device token, paired patient profile, and pairing status in local device storage. | `SessionService` |
| [`src/patient_app/lib/services/api_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/api_service.dart) | Multi-target HTTP network client. Features automatic candidate IP resolution (localhost, Android emulator `10.0.2.2`, LAN). | `ApiService` |
| [`src/patient_app/lib/services/activity_database_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/activity_database_service.dart) | Local SQLite persistence for patient routine activities, un-synced logs, and emergency SOS triggers. | `ActivityDatabaseService` |
| [`src/patient_app/lib/services/reminder_database_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/reminder_database_service.dart) | Local SQLite persistence for daily medication, hydration, and meal reminders with completion state management. | `ReminderDatabaseService` |
| [`src/patient_app/lib/services/difficulty_database_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/difficulty_database_service.dart) | Local SQLite persistence for cached dynamic difficulty levels and pending adjustment payloads. | `DifficultyDatabaseService` |
| [`src/patient_app/lib/services/difficulty_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/difficulty_service.dart) | On-device dynamic difficulty adaptation engine. Calibrates game parameters locally using clinical heuristics when offline. | `DynamicDifficultyService`, `DifficultyDecision` |
| [`src/patient_app/lib/services/game_personalization_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/game_personalization_service.dart) | Clinical diagnosis recommendation engine. Recommends cognitive exercises based on priority tiers and historical performance. | `GamePersonalizationService` |
| [`src/patient_app/lib/services/locale_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/locale_service.dart) | Regional language state provider supporting Assamese, Bengali, Bodo, and English. | `LocaleService` |
| [`src/patient_app/lib/services/voice_navigation_coordinator.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/voice_navigation_coordinator.dart) | Voice assistant coordinator. Matches speech transcripts to 14 multilingual commands (Home, Sync, SOS, Games, Language switch). | `VoiceNavigationCoordinator` |
| [`src/patient_app/lib/services/device_alarm_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/device_alarm_service.dart) | Schedules and triggers local notifications/alarms for daily caregiver schedule items. | `DeviceAlarmService`, `AlarmTime` |
| [`src/patient_app/lib/services/background_music_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/services/background_music_service.dart) | Manages soothing ambient audio playback across cognitive game screens. | `BackgroundMusicService` |

#### Shared Game Infrastructure (`src/patient_app/lib/games/shared`)
| File Path | Core Purpose | Primary Exported Classes / Components |
| :--- | :--- | :--- |
| [`src/patient_app/lib/games/shared/services/game_session_repository.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/games/shared/services/game_session_repository.dart) | SQLite database repository storing full canonical game session envelopes (`score_normalized`, latency, error bursts, trial arrays). | `GameSessionRepository`, `StoredGameSession` |
| [`src/patient_app/lib/games/shared/services/game_sync_service.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/games/shared/services/game_sync_service.dart) | Background worker that queries SQLite for un-synced game sessions and dispatches them in batched JSON arrays to the cloud. | `GameSyncService` |
| [`src/patient_app/lib/games/shared/models/round_telemetry.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/games/shared/models/round_telemetry.dart) | In-memory telemetry recorder tracking millisecond reaction times, tap coordinates, hesitations, and errors during gameplay. | `RoundTelemetry`, `SessionTelemetrySummary`, `GameTelemetryTracker` |

#### Screens & Mini-Games (`src/patient_app/lib/screens` & `games`)
| File Path | Core Purpose | Primary Exported Classes / Components |
| :--- | :--- | :--- |
| [`src/patient_app/lib/screens/home_screen.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/screens/home_screen.dart) | High-contrast dementia-friendly landing screen with 88dp+ tiles (Brain Games, Daily Reminders, Family Memories, SOS). | `HomeScreen` |
| [`src/patient_app/lib/screens/pairing_screen.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/screens/pairing_screen.dart) | Tablet pairing screen to link the physical device with a caregiver patient profile using a 6-character code. | `PairingScreen` |
| [`src/patient_app/lib/screens/games_screen.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/screens/games_screen.dart) | Cognitive games menu displaying exercise cards, current difficulty badges, and AI personalized recommendations. | `GamesScreen` |
| [`src/patient_app/lib/screens/reminders_screen.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/screens/reminders_screen.dart) | Daily routine adherence screen organizing morning, afternoon, evening, and night tasks with one-tap completion. | `RemindersScreen` |
| [`src/patient_app/lib/screens/memory_gallery_screen.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/screens/memory_gallery_screen.dart) | Reminiscence gallery displaying caregiver-uploaded family photos and playing comforting audio clips. | `MemoryGalleryScreen` |
| [`src/patient_app/lib/games/market_trip/screens/market_trip_game.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/games/market_trip/screens/market_trip_game.dart) | **Working Memory Game**. Presents an audio/text grocery prompt, distractor shape task, and delayed visual recall grid. | `MarketTripGameScreen` |
| [`src/patient_app/lib/games/tap_target/screens/tap_target_game.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/games/tap_target/screens/tap_target_game.dart) | **Attention & Reaction Speed Game**. Presents rapid cycling cultural symbols (Japi, bell, flower) for prompt detection. | `TapTargetGameScreen` |
| [`src/patient_app/lib/games/pair_matching/screens/pair_matching_game.dart`](file:///home/shreya/smriti-setu/src/patient_app/lib/games/pair_matching/screens/pair_matching_game.dart) | **Episodic Memory Game**. Tile-flip matching grid (4, 6, 8 pairs) using cultural crafts or personalized family photo cards. | `PairMatchingGameScreen` |

---

### 2.4 Machine Learning & Data Pipeline Tools (`root`)

| File Path | Core Purpose | Primary Exported Functions / Capabilities |
| :--- | :--- | :--- |
| [`train_xg.py`](file:///home/shreya/smriti-setu/train_xg.py) | Standalone model training script. Loads supervised cognitive datasets, executes stratified train-test splits, trains GradientBoosting/XGBoost, and exports `xgboost_patient_risk_model.pkl`. | Training pipeline entrypoint; saves `.pkl` model artifact |
| [`risk_batch_inference.py`](file:///home/shreya/smriti-setu/risk_batch_inference.py) | Standalone CLI and microservice for patient cognitive risk evaluation. Implements CLI mode (`--input`), demo mode (`--demo`), and FastAPI mode (`--serve`). | `predict_patient_risk()`, `FEATURE_COLUMNS`, `RISK_MAPPING` |
| [`mongo_label.py`](file:///home/shreya/smriti-setu/mongo_label.py) | Clinical research exporter. Reads documents from all MongoDB collections, maps fields to plain-English descriptions, and exports long-format CSVs. | `export_labelled_csv()`, `main()` |

---

## 3. End-to-End Data Flow Architecture

```mermaid
sequenceDiagram
    autonumber
    actor Caregiver as Caregiver (Web App)
    participant Backend as FastAPI Backend & MongoDB
    actor Patient as Patient (Tablet App)
    participant EdgeDB as SQLite (sqflite Edge)
    participant ML as XGBoost & Analytics Engine

    %% 1. Device Pairing
    Caregiver->>Backend: POST /api/caregiver/patients/register
    Backend-->>Caregiver: Returns Patient Profile & 6-Char Pairing Code
    Caregiver->>Patient: Enters Pairing Code on Tablet
    Patient->>Backend: POST /api/auth/patient/pair/complete
    Backend-->>Patient: Issues Long-Lived Patient Device JWT Token

    %% 2. Care Plan Sync
    Caregiver->>Backend: PUT /api/patients/:id/reminders & POST family-members
    Patient->>Backend: GET /api/patients/:id/reminders & family-members
    Backend-->>Patient: Syncs Reminders & Photos
    Patient->>EdgeDB: Caches Reminders & Photos locally

    %% 3. Offline Gameplay & Logging
    Patient->>EdgeDB: Launches Game (e.g. Market Trip, Pair Matching)
    EdgeDB-->>Patient: Loads Cached Difficulty & Assets
    Note over Patient,EdgeDB: Patient plays completely offline.<br/>Reaction times, errors, and trials are tracked.
    Patient->>EdgeDB: Writes Canonical GameSession & Reminder Adherence

    %% 4. Synchronization Pipeline
    Note over Patient,Backend: Network Connectivity Restored
    Patient->>EdgeDB: Queries un-synced session records
    Patient->>Backend: POST /api/sync/batch (Compressed JSON Payload)
    Backend->>Backend: Persists to MongoDB (game_sessions, activities)

    %% 5. AI Adaptations & Risk Grading
    Backend->>ML: Triggers MAB Update (Pillar 1) & Drift Regression (Pillar 3)
    ML->>Backend: Checks >25% drops; raises Alert if anomaly detected
    ML->>Backend: Evaluates XGBoost risk model (Grades 0-2)

    %% 6. Caregiver Monitoring
    Caregiver->>Backend: GET /api/caregiver/dashboard & /api/risk/overview
    Backend-->>Caregiver: Returns Cognitive Drift Slopes, Risk Grade Badge & Alerts
    Caregiver->>Caregiver: Views Recharts Longitudinal Trends & Adjusts Care Plan
```

### Data Flow Phases in Detail

1. **Patient Onboarding & Device Pairing**:
   - The caregiver registers a new patient profile via `RegisterPatient.jsx`, triggering `POST /api/caregiver/patients/register`.
   - The backend creates the `User` and `DevicePairingToken` records in MongoDB and returns a 6-character code (e.g., `ABC123`).
   - The caregiver enters this code into `PairingScreen.dart` on the tablet. `ApiService` calls `POST /api/auth/patient/pair/complete`, which exchanges the code for a persistent device JWT token saved in device storage via `SessionService`.

2. **Care Plan Authoring & Edge Retrieval**:
   - In `CarePlan.jsx`, the caregiver configures medication/meal schedules and uploads family reminiscence photos with voice clips.
   - These persist via `patientService.js` and `carePlanService.js` to MongoDB collections (`patient_reminders`, `family_members`).
   - When the tablet connects to the network, `ApiService` fetches these records and caches them locally in SQLite (`ReminderDatabaseService`).

3. **Offline Interaction & Local Telemetry Recording**:
   - The patient interacts with mini-games (`MarketTripGameScreen`, `TapTargetGameScreen`, `PairMatchingGameScreen`) without needing an internet connection.
   - Dynamic difficulty is adjusted locally by `DynamicDifficultyService` using cached MAB weights or heuristic fallback.
   - Every tap, hesitation, millisecond latency, error burst, and trial outcome is recorded in memory via `RoundTelemetry` and committed to SQLite (`GameSessionRepository` and `ActivityDatabaseService`).

4. **Background Synchronization Queue**:
   - `GameSyncService` runs periodically in the background. When network availability is detected, it extracts pending session envelopes from SQLite.
   - It sends a batched JSON array via `POST /api/sync/batch`.
   - The backend validates the device token, unpacks the payload, and inserts records into MongoDB (`game_sessions`, `patient_activities`, and `patient_reminders`).

5. **AI Adaptation, Drift Analytics & Clinical Risk Stratification**:
   - **Pillar 1 Dynamic Difficulty**: `difficulty_service.py` computes the composite performance score $S = (w_1 \cdot \text{Accuracy}) - (w_2 \cdot \text{Latency}) - (w_3 \cdot \text{Errors})$ and updates the MAB UCB arm weights (`bandit.py`).
   - **Pillar 3 Drift & Anomaly Alerting**: `drift.py` computes ordinary least squares linear regression over rolling 7-day and 30-day windows. If cognitive accuracy drops by $>25\%$ or latency spikes significantly, `alerts.py` generates an active clinical alert.
   - **Machine Learning Risk Model**: `risk_model_service.py` extracts a 5-feature vector (`age`, `accuracy_rate_pct`, `reaction_time_ms`, `drift_slope_7d`, `active_alert_count`) and runs it through `xgboost_patient_risk_model.pkl` to grade clinical risk (Grade 0: Low, Grade 1: Moderate, Grade 2: High).

6. **Caregiver Monitoring & Action**:
   - The caregiver accesses `Dashboard.jsx`, `Analytics.jsx`, and `PatientRiskOverviewTable.jsx`.
   - The frontend reads from `cacheService.js` (SWR caching) and syncs with `/api/caregiver/dashboard`, `/api/analytics/patients/{id}/drift`, and `/api/risk/overview`.
   - Longitudinal trajectories are rendered in Recharts, and actionable color-coded risk alerts guide caregivers to adjust task difficulty or arrange clinical intervention.
