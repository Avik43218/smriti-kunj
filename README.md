# Smriti Kunj (স্মৃতি কুঞ্জ / स्मृति कुंज)

**AI-Powered, Offline-First Cognitive & Memory Assistance Ecosystem for Mild Cognitive Impairment (MCI) and Dementia Care**

[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688.svg?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.3+-02569B.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![React](https://img.shields.io/badge/React-18-61DAFB.svg?logo=react&logoColor=black)](https://react.dev)
[![MongoDB](https://img.shields.io/badge/MongoDB-Beanie_ODM-47A248.svg?logo=mongodb&logoColor=white)](https://www.mongodb.com)
[![Vite](https://img.shields.io/badge/Vite-5.0+-646CFF.svg?logo=vite&logoColor=white)](https://vitejs.dev)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB.svg?logo=python&logoColor=white)](https://python.org)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)

---

## 📌 Overview

**Smriti Kunj** is an integrated cognitive assistive care ecosystem engineered specifically for individuals living with **Mild Cognitive Impairment (MCI)** and early-stage dementia, coupled with a web-based clinical dashboard for caregivers, family members, and healthcare administrators.

Built specifically to serve low-connectivity regions (with cultural and linguistic localization for India's North Eastern Region — **Assamese**, **Bengali**, **Bodo**, and **English**), Smriti Kunj operates on a strict **offline-first** architecture. Patients interact with an accessible tablet interface that persists all sessions, routines, and telemetry locally, synchronizing asynchronously with the cloud backend whenever network connectivity is available.

---

## 🏛️ System Architecture

```
                             ┌────────────────────────────────────────────────────────┐
                             │               Caregiver & Admin Web Portal             │
                             │                  (React 18 + Vite + Tailwind)          │
                             │  • Multi-Patient Roster & Care Status Categorization   │
                             │  • Care Plan, Medication & Routine Alarm Management    │
                             │  • Recharts Multi-Domain Cognitive Stability Trends    │
                             │  • XGBoost Patient Risk Grading & Printable Report Card│
                             │  • Admin Portal: Caregiver Accounts & Audit Logging    │
                             └───────────────────────────▲────────────────────────────┘
                                                         │
                                                   REST API (JWT)
                                                         │
                                                         ▼
┌──────────────────────────────────────┐       ┌──────────────────────────────────────────────────────┐
│          Patient Tablet App          │       │                    FastAPI Backend                   │
│           (Flutter / Dart)           │       │                (Python 3.11+ / Beanie)               │
│ • Dementia Accessibility (88dp+ / 18px+)◄─────► • 2FA Caregiver Auth (OTP) & Device Pairing Tokens    │
│ • 4 Local SQLite Edge Repositories   │ HTTP  │ • Idempotent Batch Telemetry Ingestion (/sync/batch) │
│ • 3 Cultural Cognitive Brain Games   │ Batch │ • Dynamic Difficulty Adaptation (UCB1 Bandit - P1)   │
│ • Multilingual Voice Nav (4 Langs)   │ Sync  │ • Multilingual NLU & Phonetic Entity Parsing (P2)    │
│ • Time-Bucket Daily Reminders        │       │ • Longitudinal Drift Regression & Alert Engine (P3)  │
│ • Instant SOS Dialer & Fallback      │       │ • XGBoost Machine Learning Risk Classifier (P4)      │
│ • Family Reminiscence Photo Gallery  │       │ • Cross-Caregiver Administration & Audit Logging     │
└──────────────────────────────────────┘       └──────────────────────────┬───────────────────────────┘
                                                                          │
                                                                   Motor Async Driver
                                                                          │
                                                                          ▼
                                                               ┌──────────────────────┐
                                                               │    MongoDB Store     │
                                                               │ • Users & Patients   │
                                                               │ • Telemetry Sessions │
                                                               │ • Reminders & Cards  │
                                                               │ • Drift & Audit Logs │
                                                               └──────────────────────┘
```

---

## 📱 Implemented Features: Patient Tablet Application (`src/patient_app`)

The patient application is built with Flutter and engineered specifically to remove cognitive burden, eliminate confusing menus, and support elderly individuals experiencing cognitive and fine-motor decline:

### 1. Dementia-Centric Accessible Interface
* **Rigorous Accessibility Standards:** Minimum **88dp touch targets** to accommodate fine-motor tremors, a strict minimum **18px font floor**, high-contrast typography, and single-level flat navigation.
* **Warm, Non-Glare Palette:** Gentle terracotta, calming cream, forest green, and slate tones designed to minimize sensory agitation (no harsh dark mode or blinding neon elements).
* **Calm Home Dashboard (`home_screen.dart`):** Large single-tap tiles for Brain Games, Today's Reminders, Memories Gallery, Profile Status, and Emergency Call for Help (SOS).
* **Ambient Calming Audio:** Integrated background music player (`BackgroundMusicService` / `MuteToggle`) providing soothing instrumental soundscapes with an instant mute control.

### 2. Device Pairing & QR Onboarding
* **Dual Pairing Modalities (`pairing_screen.dart`):**
  * **6-Character Code Entry:** Direct manual entry of the caregiver-generated pairing code.
  * **Integrated Camera QR Scanner (`qr_scanner_screen.dart`):** Built-in barcode/QR scanner that decodes deep links (`smritikunj://pair?code=...`) or web URLs generated by the caregiver portal.
* **Instant Token Exchange:** Exchanging the code via `/api/auth/patient/pair` stores a long-lived, scoped device token in local secure storage.
* **Offline Demo Mode:** Allows clinical evaluators and users to test all tablet features even without active internet connectivity.

### 3. Three (3) Implemented Cognitive Games
All exercises are culturally grounded in North Eastern regional motifs and capture granular telemetry on every trial:

| Game | Cognitive Domain | Mechanics & Clinical Focus | File Location |
|---|---|---|---|
| **The Market Trip** | Working Memory & Delayed Recall | Players observe a culturally contextualized shopping list (local vegetables, regional spices, traditional kitchenware), engage in an interactive distractor phase to prevent rehearsal, and reconstruct the list from an expanded recall grid under latency tracking. | [`src/patient_app/lib/games/market_trip/`](./src/patient_app/lib/games/market_trip/) |
| **Tap the Target** | Attention & Processing Speed | Rapid visual discrimination task requiring players to tap traditional cultural symbols (Assamese Japi, brass bell, tea flower, conch shell) while ignoring visual distractors. Telemetry captures millisecond reaction times, hesitation intervals, omission errors, and false taps. | [`src/patient_app/lib/games/tap_target/`](./src/patient_app/lib/games/tap_target/) |
| **Pair Matching** | Episodic Memory & Association | Interactive card-flip matching scaling dynamically across grid sizes (4, 6, and 8 pairs). Incorporates caregiver-uploaded **family member photo cards** to stimulate personal reminiscence alongside traditional cultural artifact pairs. Computes flip counts, repeat errors, and recall efficiency. | [`src/patient_app/lib/games/pair_matching/`](./src/patient_app/lib/games/pair_matching/) |

### 4. Daily Routine & Medication Reminders (`reminders_screen.dart`)
* **Time-of-Day Categorization:** Tasks grouped into Morning, Afternoon, Evening, and Night.
* **Supported Task Types:** Medication schedules (with exact dosages and instructions), Hydration check-ins, Meals, and Custom daily activities.
* **One-Tap Task Completion:** Simplified check-off with celebratory visual cues.
* **Native Device Alarms:** Scheduled via native platform alarms (`DeviceAlarmService`) synchronized from caregiver schedules.
* **Local SQLite Caching:** Operates completely offline via `ReminderDatabaseService`.

### 5. Family Memories & Reminiscence Gallery (`memory_gallery_screen.dart`)
* **High-Contrast Photo Cards:** Displays familiar faces, family members, pets, and ancestral homes with large labels and relationship tags (e.g., "Granddaughter Priyam", "Home in Tezpur").
* **Audio Reminiscence Clips:** In-card playback controls for voice recordings from loved ones and ambient hometown sounds.
* **Modal View:** Fullscreen viewing mode with pinch-to-zoom and pan for detailed inspection.

### 6. Multilingual Voice Navigation
* **4 Supported Languages:** Native speech recognition and prompt delivery across **Assamese**, **Bengali**, **Bodo**, and **English**.
* **14 Distinct Voice Commands:** Hands-free navigation covering Home, Reminders, Brain Games, Memories, Help/SOS, Sync Data, Language Switching, and Profile viewing.
* **Phonetic Romanization Engine (`VoiceNavigationService`):** Matches regional pronunciations and accents against phonetic romanized dictionaries, ensuring high recognition accuracy even on standard mobile speech-to-text engines.
* **Voice Feedback Overlay:** Visual microphone button and overlay bottom sheet providing real-time transcribed speech feedback.

### 7. Emergency Safety & SOS Calling (`SosButton` & `profile_status_screen.dart`)
* **Instant-Access SOS Button:** Prominent red high-contrast SOS button accessible across the application.
* **Accidental Trigger Guard:** 3-second visual countdown confirmation modal before launching calls.
* **Native Dialer Launch:** Automatically opens the device dialer with the primary guardian's phone number.
* **Wi-Fi-Only Tablet Fallback:** For tablets without cellular SIM cards, displays the guardian's name and contact number prominently on screen with a single-tap dialer intent.
* **Patient Profile Status Screen:** Read-only screen presenting patient identity, caregiver details, and direct emergency dial buttons.

### 8. Offline-First Edge Persistence & Synchronization
* **4 Internal SQLite Repositories:**
  * `ActivityDatabaseService`: Queues completed activities, voice logs, and synchronization flags.
  * `ReminderDatabaseService`: Stores daily schedules locally.
  * `DifficultyDatabaseService`: Maintains current game challenge parameters and calibration history.
  * `GameSessionRepository`: Caches raw multi-trial telemetry payloads.
* **Automatic Batch Ingestion:** The background sync worker automatically flushes queued sessions to `/api/sync/batch` when network connectivity is restored.
* **Clinical Recommendation Engine (`GamePersonalizationService`):** Evaluates patient medical diagnosis (mapped across 7 priority tiers) and historical performance to personalize game selection and difficulty.

---

## 💻 Implemented Features: Caregiver & Admin Web Portal (`src/frontend/caregiver_app`)

The caregiver web application is built with React 18, Vite, Tailwind CSS, Lucide icons, and Recharts, providing a full clinical management suite:

### 1. Two-Factor Authentication & Access Control
* **Two-Phase Login (`Login.jsx`):** Email/password verification followed by a 6-digit OTP challenge (`/login` ➔ `/verify-otp`). Includes demo credentials autofill for quick testing.
* **Registration with Password Strength (`Register.jsx`):** Caregiver onboarding with live password strength scoring (length, uppercase, lowercase, numbers, special characters).
* **Role-Based Routing:** Dynamic routing differentiating between Caregiver and Platform Admin accounts via `AuthContext` and `ProtectedRoute`.
* **Token Invalidation:** Secure JWT session storage with immediate revocation on logout via the backend token blacklist.

### 2. Caregiver Dashboard (`Dashboard.jsx`)
* **Multi-Patient Roster:** Renders all patients assigned to the caregiver with live search filtering by name, diagnosis, or patient code.
* **Live Care Status Categorization:** Real-time adherence indicators:
  * 🟢 `normal`: Routine adherence on schedule.
  * 🟡 `reminder_missed`: One or more scheduled reminders missed today.
  * 🔴 `alert`: Critical reminder skipped or cognitive decline alert triggered.
* **Quick Patient Overview Cards:** Single-click navigation to Patient Details, Care Plan, and Analytics.
* **System Summary Metrics:** Total patients, pending routine checks, and active anomaly alerts.

### 3. Comprehensive Patient Onboarding (`RegisterPatient.jsx`)
* **Multi-Step Clinical Form:**
  * **Demographics:** Full name, age, gender, primary language, and blood group.
  * **Clinical Diagnoses:** Classification (MCI, Early Alzheimer's, Vascular Dementia, Frontotemporal, Lewy Body), clinical stage, diagnosis year, and primary physician.
  * **Lifestyle & Risk Factors:** Sleep quality, physical activity level, social engagement, hearing/visual aids.
  * **Emergency Guardian Contacts:** Multi-contact management with names, relationships, phone numbers, and primary contact toggles.
  * **Device Pairing Generation:** Automatic generation of a unique 6-character tablet pairing code and pairing QR code.
  * **Initial Family Memories:** Uploading initial family photos, names, and relationship descriptors.

### 4. Patient Profile & Device Management (`PatientDetails.jsx`)
* **Complete Clinical Dossier:** View and verify demographic details, medical diagnoses, lifestyle factors, and emergency contacts.
* **Hardware & Pairing Status:** Live tablet status, last synchronization timestamp, device identifier, and pairing code.
* **Interactive QR Code Generator (`PairingQrPanel.jsx`):** Displays the pairing QR code directly in the browser with one-click **PNG / SVG image download** for printing or direct scanning.

### 5. Care Plan & Schedule Management (`CarePlan.jsx`)
* **Daily Routine Editor:** Manage schedules across Medication, Hydration, Meals, and Custom tasks.
* **Medication Detail Configuration:** Configure medication names, dosages, time pickers, and patient instructions.
* **Alarm Synchronization Controls:** Toggle device alarms with an explicit safety confirmation modal (`AlarmOffModal.jsx`).
* **Family Memory Card CRUD:** Upload, edit, view, and delete family member photos with custom relationship labels.
* **Audio Reminiscence Clips (`SoundClipCard.jsx`):** Upload and manage voice recordings and ambient audio tracks for the patient tablet.
* **Adherence Progress:** Real-time completion progress tracking across daily tasks.

### 6. Cognitive Analytics & Longitudinal Drift (`Analytics.jsx`)
* **Multi-Domain Time-Series Visualization (Recharts):**
  * **Episodic Memory Score Trend**
  * **Working Memory Score Trend**
  * **Attention & Processing Speed Trend**
  * **Language & Semantic Score Trend**
* **Cognitive Domain Radar Chart:** Holistic visual profile of patient cognitive strengths and decline vectors.
* **Adaptive Challenge Progression:** Tracks game difficulty level adjustments over time.
* **Granular Session History Table:** Comprehensive audit table displaying completed game sessions, normalized scores, average reaction time (in milliseconds), hesitation pause counts, error rates, and duration.
* **Printable Clinical Report Card (`PatientReportCardModal.jsx`):** Exportable and printable multi-page clinical report card summarizing patient adherence, domain trends, and cognitive risk profile for physician consultations.

### 7. Platform Administration Portal (`src/frontend/caregiver_app/src/pages/admin/`)
* **Admin Dashboard (`AdminDashboard.jsx`):** Platform-wide metrics, total registered patients, active caregiver count, paired devices, and unassigned/orphan patient counters.
* **Caregiver Management (`ManageCaregivers.jsx`):** List all registered caregivers, create new caregiver accounts, update active/inactive status, and securely generate temporary reset passwords.
* **All Patients Oversight (`AllPatients.jsx`):** Centralized registry of all patients across all caregivers with tools to assign and reassign patients between caregivers.
* **Security Audit Logs (`AdminAuditLogs.jsx`):** Real-time administrative audit trail tracking caregiver account creations, password resets, patient reassignments, and system events with timestamps and actor details.

---

## ⚙️ Implemented Features: Backend & AI Engine (`src/backend`)

The backend is built with Python 3.11+, FastAPI, and MongoDB (via Motor and Beanie ODM):

### 1. Asynchronous RESTful API Layer
* **Authentication Router (`auth.py`):** User registration, password verification, OTP generation and verification, JWT issuance, session termination, token blacklisting (`revoked_tokens` collection), and patient tablet pairing token exchange.
* **Caregiver Router (`caregiver.py`):** Patient roster management, patient registration, profile retrieval, patient deletion, and dashboard status calculation.
* **Patients Router (`patients.py`):** Memory cards CRUD, daily routine reminders CRUD (with category filtering for medication, hydration, meals, and custom tasks), and historical game session queries.
* **Admin Router (`admin.py`):** Caregiver administration, high-entropy password generation, cross-caregiver patient reassignment, and audit log querying.
* **Sync Router (`sync.py`):** High-throughput idempotent ingestion endpoint (`/api/sync/batch` and `/api/sync`) processing edge session batches, voice logs, and telemetry arrays.
* **Analytics Router (`analytics.py`):** Longitudinal drift trend calculation and clinical alert retrieval.
* **Difficulty Router (`difficulty.py`):** Adaptive game parameter recommendations.
* **Risk Router (`risk.py`):** Real-time machine learning inference for patient risk grading.
* **Voice Router (`voice.py`):** Intent classification for transcribed speech.

### 2. Four (4) AI & Machine Learning Pillars

| Pillar | Technical Implementation | Purpose | File Location |
|---|---|---|---|
| **Pillar 1: Dynamic Difficulty Adaptation (DDA)** | **Upper Confidence Bound (UCB1) Multi-Armed Bandit** algorithm optimizing challenge levels against a continuous composite performance metric:<br>$$S = (w_1 \cdot \text{Accuracy}) - (w_2 \cdot \text{Latency}) - (w_3 \cdot \text{ErrorRate})$$ | Dynamically scales grid sizes (4, 6, 8 pairs), target appearance durations, and distractor frequencies to prevent frustration while stimulating cognitive plasticity. | [`src/backend/app/core/bandit.py`](./src/backend/app/core/bandit.py)<br>[`src/backend/app/services/difficulty_service.py`](./src/backend/app/services/difficulty_service.py) |
| **Pillar 2: Multilingual NLU & Phonetic Entity Parser** | Lightweight entity parser extracting structured `{intent, task, time, status}` payloads from voice check-ins; phonetic romanization engine for regional speech. | Translates spoken voice interactions across Assamese, Bengali, Bodo, and English into structured adherence and navigation events. | [`src/backend/app/core/nlu.py`](./src/backend/app/core/nlu.py)<br>[`src/backend/app/api/routes/voice.py`](./src/backend/app/api/routes/voice.py) |
| **Pillar 3: Predictive Drift Analytics & Anomaly Detection** | **Rolling 7-day and 30-day Ordinary Least Squares (OLS) Linear Regression** ($\hat{y} = \beta_0 + \beta_1 x$) combined with statistical variance tracking. | Detects negative drift velocity ($\beta_1 < T$) across cognitive domains and triggers urgent clinical alerts when acute drops (>25% performance decline or severe reaction time spikes) occur. | [`src/backend/app/core/drift.py`](./src/backend/app/core/drift.py)<br>[`src/backend/app/services/analytics_service.py`](./src/backend/app/services/analytics_service.py) |
| **Pillar 4: XGBoost Patient Risk Grading** | Supervised **Gradient Boosting / XGBoost Classifier** trained on patient feature vectors: `[age, accuracy_rate_pct, reaction_time_ms, drift_slope_7d, active_alert_count]`. Serialized model: `xgboost_patient_risk_model.pkl`. | Classifies patients into **Low Risk**, **Moderate Risk**, or **High Risk** clinical tiers with actionable care recommendations. Includes batch inference CLI and training pipeline. | [`src/backend/app/services/risk_model_service.py`](./src/backend/app/services/risk_model_service.py)<br>[`risk_batch_inference.py`](./risk_batch_inference.py)<br>[`train_xg.py`](./train_xg.py) |

### 3. Data Schema & Clinical Label Exporter (`mongo_label.py`)
* Standardized canonical session envelope (`session_id`, `patient_profile_id`, `game_type`, `domain`, `session_date`, `session_duration`, `status`, `difficulty_level`, `score_normalized`, `game_data`, `raw_trials`).
* Standalone data tool (`mongo_label.py`) that exports MongoDB collections into human-readable CSV formats annotated with clinical titles, descriptions, units, and cognitive domains.

---

## 📁 Repository Directory Structure

```
SIH-PS003/
├── ARCHITECTURE.md                  # System architecture specifications & clinical formulas
├── CONTAINER_GUIDE.md               # Podman & Docker multi-container deployment guide
├── PROJECT_STATUS.md                # Comprehensive component audit & verification report
├── docker-compose.yml               # Production multi-service orchestration
├── run.sh                           # Unified local runner with multiplexed colored logging
├── run-docker.sh                    # Containerized stack deployment script
├── train_xg.py                      # Synthetic data generator & XGBoost risk model trainer
├── risk_batch_inference.py          # Standalone CLI for patient risk inference & demonstration
├── mongo_label.py                   # MongoDB clinical schema label exporter to CSV
├── export_patient_analytics.py      # Convenience launcher for patient analytics export
│
├── assets/                          # Design assets, system diagrams, and brand iconography
│
├── src/
│   ├── docs/                        # Architecture, branding, and API documentation
│   │   ├── BRAND_GUIDELINES.md      # Dementia UI accessibility rules and color tokens
│   │   ├── GAMES_ANALYTICS_README.md# Game telemetry schema and clinical metrics
│   │   ├── API_ENDPOINTS_NEEDED.md  # Backend endpoint catalog and payload specs
│   │   └── START_SERVERS.md         # Quick-start CLI command cheat sheet
│   │
│   ├── backend/                     # FastAPI + MongoDB Backend Service
│   │   ├── requirements.txt         # Python dependencies (FastAPI, Beanie, Motor, Scikit-learn, XGBoost)
│   │   ├── Dockerfile & Containerfile
│   │   ├── app/
│   │   │   ├── main.py              # Application entrypoint, CORS, route mounting, /health & /ping
│   │   │   ├── config.py            # Environment settings and algorithm weights
│   │   │   ├── database.py          # Motor client and Beanie ODM initialization
│   │   │   ├── api/routes/          # REST route handlers (auth, admin, caregiver, patients, sync, risk, etc.)
│   │   │   ├── core/                # Core algorithms (bandit, drift, nlu, security, otp, alerts)
│   │   │   ├── models/              # Beanie MongoDB Document models (User, GameSession, Reminder, Alert, etc.)
│   │   │   ├── schemas/             # Pydantic request and response schemas
│   │   │   ├── services/            # AnalyticsService, DifficultyService, RiskModelService
│   │   │   └── agents/              # Serialized ML models (xgboost_patient_risk_model.pkl)
│   │   ├── scripts/                 # Maintenance scripts (migrate_user_roles.py, export_patient_analytics.py)
│   │   └── tests/                   # Pytest test suite (11 test modules covering endpoints, auth, admin, etc.)
│   │
│   ├── frontend/caregiver_app/      # Caregiver & Admin Web Dashboard (React 18 + Vite)
│   │   ├── package.json             # Dependencies (React 18, Vite, Recharts, Tailwind CSS, Lucide icons)
│   │   ├── vite.config.js           # Vite configuration with /api reverse proxy
│   │   ├── tailwind.config.js       # Brand color palette (cream, terracotta, forest green, slate)
│   │   └── src/
│   │       ├── pages/               # Dashboard, Analytics, CarePlan, PatientDetails, RegisterPatient, Login, etc.
│   │       │   └── admin/           # AdminDashboard, ManageCaregivers, AllPatients, AdminAuditLogs
│   │       ├── components/          # Reusable UI components, Modals, Recharts graphs, QR generator
│   │       ├── context/             # AuthContext, ThemeContext
│   │       ├── services/            # API client wrappers with local-storage fallback
│   │       └── layouts/             # DashboardLayout, PatientLayout
│   │
│   └── patient_app/                 # Patient Tablet Application (Flutter / Dart)
│       ├── pubspec.yaml             # Flutter dependencies (provider, sqflite, qr_code_scanner, audioplayers)
│       ├── analysis_options.yaml    # Linter configuration (0 warnings / clean analysis)
│       ├── lib/
│       │   ├── main.dart            # Flutter entrypoint and multi-provider bootstrap
│       │   ├── theme/theme.dart     # Dementia-optimized typography, 88dp touch targets & color tokens
│       │   ├── screens/             # HomeScreen, GamesScreen, RemindersScreen, MemoryGallery, PairingScreen, QrScanner
│       │   ├── games/               # Cognitive exercises (market_trip, tap_target, pair_matching)
│       │   ├── services/            # SQLite databases, API sync, voice navigation, personalization
│       │   ├── utils/               # QR parser (deep links smritikunj://pair and URLs)
│       │   └── widgets/             # SOS Button, Voice Nav Sheet, Mute Toggle, App Background
│       └── test/                    # 94 passing unit, widget, and personalization tests
```

---

## 🚀 Quick Start Guide

### Prerequisites
* **Python:** 3.11+
* **Node.js:** 18+ & npm
* **Flutter SDK:** 3.3+
* **Container Engine:** Podman or Docker
* **Android Debug Bridge (ADB):** For physical tablet / emulator testing

---

### Option A: Unified Local Development Runner (Recommended)

The repository includes a development runner script (`run.sh`) that launches MongoDB via Podman, starts the Vite frontend dev server, boots the FastAPI uvicorn server, configures Android ADB port forwarding, and multiplexes all logs with colored tags:

```bash
chmod +x run.sh
./run.sh
```

**Service Endpoints:**
* **Caregiver Web Dashboard:** [http://localhost:5173](http://localhost:5173)
* **FastAPI Swagger Documentation:** [http://localhost:8000/docs](http://localhost:8000/docs)
* **FastAPI Health Check:** [http://localhost:8000/health](http://localhost:8000/health)
* **MongoDB:** `mongodb://localhost:27017`

---

### Option B: Step-by-Step Manual Setup

#### 1. MongoDB Database
Start a local MongoDB container:
```bash
podman run -d --name mongo-dev -p 27017:27017 mongo:latest
# or with docker:
docker run -d --name mongo-dev -p 27017:27017 mongo:latest
```

#### 2. FastAPI Backend Service
```bash
cd src/backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Start the API server with live reloading
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

#### 3. Caregiver Web Dashboard (React + Vite)
```bash
cd src/frontend/caregiver_app
npm install
npm run dev
```

#### 4. Patient Tablet Application (Flutter)
```bash
cd src/patient_app

# Forward the backend port over USB to your Android tablet:
adb reverse tcp:8000 tcp:8000

# Install dependencies and launch the app:
flutter pub get
flutter run
```

---

### Option C: Containerized Deployment (Docker / Podman Compose)

```bash
# Build and launch all containerized services in the background:
docker compose up -d --build
# or using podman compose:
podman compose up -d --build

# Monitor live container logs:
docker compose logs -f
```

Refer to [`CONTAINER_GUIDE.md`](./CONTAINER_GUIDE.md) for rootless setups and container networking details.

---

## 🧪 Testing & Code Quality

### Patient Tablet App (Flutter)
* **Static Analysis:** Maintains a clean linter standard with **0 issues**:
  ```bash
  cd src/patient_app
  flutter analyze
  ```
* **Test Suite (94 Passing Tests):**
  ```bash
  cd src/patient_app
  flutter test
  ```
  Covers diagnosis-to-game prioritization (`game_personalization_test.dart`), multilingual voice command parsing across Assamese, Bengali, and English (`voice_navigation_service_test.dart`), SOS emergency button and dialer safety flows (`sos_button_dialer_test.dart`), QR code parsing (`qr_parser_test.dart`), and smoke testing (`widget_test.dart`).

### Backend Service (Pytest)
```bash
cd src/backend
pytest tests/
```
Covers authentication and OTP lifecycle, role-based access control, caregiver patient operations, patient reminders, administrative endpoints, sync flow, and the XGBoost risk model.

### Standalone Machine Learning Risk Inference Demo
Evaluate the XGBoost risk grading model from the command line:
```bash
python risk_batch_inference.py --demo
```

---

## 🔒 Security & Privacy Architecture

* **Zero Third-Party Identity Lock-in:** Fully self-hosted bcrypt password hashing and 2FA OTP verification without external identity vendor lock-in.
* **Immediate JWT Revocation:** Dedicated `revoked_tokens` MongoDB collection ensures tokens are blacklisted immediately upon logout.
* **Strict Hardware-Scoped Device Tokens:** Patient tablets hold dedicated pairing tokens restricted strictly to batch synchronization and reminder queries, preventing access to administrative caregiver endpoints.
* **Transient Voice Processing:** Audio inputs are processed ephemerally on-device; only structured intent payloads are queued for transmission.

---

## 📄 License & Attribution

This project is licensed under the terms of the **Apache License 2.0**. See [LICENSE](./LICENSE) for details. Developed with care for elderly cognitive independence and caregiver peace of mind.
