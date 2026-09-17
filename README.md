# Smriti Kunj (স্মৃতি কুঞ্জ)

**AI-Powered Offline-First Cognitive & Memory Assistance Ecosystem for Elderly Care**

[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688.svg?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.3+-02569B.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![React](https://img.shields.io/badge/React-18-61DAFB.svg?logo=react&logoColor=black)](https://react.dev)
[![MongoDB](https://img.shields.io/badge/MongoDB-Beanie_ODM-47A248.svg?logo=mongodb&logoColor=white)](https://www.mongodb.com)
[![Vite](https://img.shields.io/badge/Vite-5.0+-646CFF.svg?logo=vite&logoColor=white)](https://vitejs.dev)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB.svg?logo=python&logoColor=white)](https://python.org)

---

## 📌 Overview

**Smriti Setu** is an integrated cognitive assistive care ecosystem engineered specifically for individuals living with **Mild Cognitive Impairment (MCI)** and early-stage dementia, coupled with a clinical web dashboard for caregivers and healthcare professionals.

Designed specifically for low-connectivity regions (with initial cultural and linguistic focus on India's North Eastern Region — Assamese, Bengali, Bodo, and English), Smriti Setu operates on an **offline-first** paradigm where edge interactions are guaranteed to execute without lag, queuing telemetry locally and synchronizing seamlessly with cloud backends upon connectivity restoration.

```
                             ┌───────────────────────────────────────┐
                             │        Caregiver Web Dashboard        │
                             │         (React 18 + Vite)             │
                             │  • Roster, Analytics & Drift Trends   │
                             │  • Care Plan & Reminder Scheduling    │
                             │  • XGBoost Patient Risk Grading       │
                             └───────────────────▲───────────────────┘
                                                 │
                                           REST API (JWT)
                                                 │
                                                 ▼
┌────────────────────────────┐       ┌───────────────────────────────────────┐
│     Patient Tablet App     │       │            FastAPI Backend            │
│       (Flutter / Dart)     │       │       (Python 3.11+ / Beanie)         │
│ • Dementia-safe UI (88dp+) │◄─────►│  • 2FA Auth & Pairing Tokens          │
│ • Local SQLite Persistence │ HTTP  │  • Batch Sync & Telemetry Pipeline    │
│ • Multilingual Voice Nav   │ Batch │  • Multi-Armed Bandit Difficulty (P1) │
│ • 3 Cultural Brain Games   │ Sync  │  • Voice Intent Classification (P2)   │
│ • Daily Routine Reminders  │       │  • Longitudinal Drift Regression (P3) │
│ • Emergency SOS Calling    │       │  • XGBoost Risk Assessment Classifier │
└────────────────────────────┘       └───────────────────┬───────────────────┘
                                                         │
                                                  Motor Async Driver
                                                         │
                                                         ▼
                                             ┌───────────────────────┐
                                             │     MongoDB Store     │
                                             │  • Users & Profiles   │
                                             │  • Sessions & Drift   │
                                             │  • Reminders & Alerts │
                                             └───────────────────────┘
```

---

## 🏛️ System Architecture

The platform is structured into three synchronized core layers:

### 1. Patient Edge Application (`src/patient_app`)
- **Framework:** Flutter (Dart 3.3+) with `provider` for reactive state management.
- **Offline Persistence:** `sqflite` local database managing 4 dedicated internal tables:
  - `ActivityDatabaseService`: Game results, voice logs, and outbound sync queue.
  - `ReminderDatabaseService`: Local daily schedules (medications, hydration, meals, custom).
  - `DifficultyDatabaseService`: Adaptive difficulty states and calibrations.
  - `GameSessionRepository`: Comprehensive raw trial telemetry.
- **Accessibility & Dementia Design:** Strictly adheres to [`BRAND_GUIDELINES.md`](./src/docs/BRAND_GUIDELINES.md):
  - Ultra-large touch targets (≥ 88dp) to support fine-motor degradation.
  - Minimum 18px text floor with high-contrast, non-glare color palettes.
  - Warm, non-jarring aesthetics with cultural motifs (Assamese Japi, tea leaves, bell, brass crafts).
- **Multilingual Voice Navigation:** 14-command voice control module (`VoiceNavigationCoordinator`) supporting **Assamese**, **Bengali**, **Bodo**, and **English**, featuring phonetic romanization matching for standard mobile STT engines.
- **Emergency Safety:** Prominent, instant-access SOS Calling (`SosButton`) with audio/visual confirmation and immediate emergency contact dialing.

### 2. Caregiver Clinical Portal (`src/frontend/caregiver_app`)
- **Framework:** React 18, Vite, Tailwind CSS, Lucide icons, and Recharts.
- **Two-Factor Authentication:** Email/password verification combined with 6-digit OTP challenge (`/login` ➔ `/verify-otp`).
- **Patient Roster & Onboarding:** Comprehensive registration (`/patients/new`) capturing clinical diagnoses, lifestyle risk factors, guardian contacts, tablet pairing codes, and family memory assets.
- **Dynamic Care Status:** Live patient categorization (`normal`, `reminder_missed`, `alert`) computed from real-time routine adherence.
- **Care Plan Manager:** Visual schedule editor for medication, hydration, and meal reminders with native alarm synchronization, family memory cards, and sound clips.
- **Cognitive Analytics:** Recharts time-series tracking cognitive stability across 4 domains (Episodic Memory, Working Memory, Language & Semantic, Attention & Processing Speed).
- **Clinical Report Card & Risk Assessment:** XGBoost-powered patient risk evaluation badges (Low, Moderate, High Risk) and printable clinical report cards (`PatientReportCardModal.jsx`).

### 3. Backend & Cloud Infrastructure (`src/backend`)
- **Framework:** Python FastAPI with asynchronous execution (`async def`).
- **Data Layer:** MongoDB via **Motor** and **Beanie ODM** using UUID binary primary keys and automated indexing.
- **Unified Role-Based Auth:** Caregiver credential verification with bcrypt password hashing, email OTP verification, JWT revocation blocklists (`revoked_tokens`), and cryptographic device-pairing tokens for patient tablets.
- **Idempotent Sync Engine:** `/api/sync/batch` ingests batched session logs, updates bandit arm states, calculates drift, and triggers anomaly detection asynchronously.

---

## 🧠 The 3 AI Pillars & Machine Learning Engine

| Pillar | Capability | Technical Implementation | File Reference |
|---|---|---|---|
| **Pillar 1: Dynamic Difficulty Adaptation (DDA)** | Real-time game challenge calibration balancing challenge vs. frustration | Upper Confidence Bound (UCB1) Multi-Armed Bandit algorithm optimizing against the continuous performance metric:<br>$$S = (w_1 \cdot \text{Accuracy}) - (w_2 \cdot \text{Latency}) - (w_3 \cdot \text{ErrorRate})$$<br>Adjusts grid sizes (3x2 to 4x4), timers, and distractor frequencies. | [`src/backend/app/core/bandit.py`](./src/backend/app/core/bandit.py)<br>[`src/backend/app/services/difficulty_service.py`](./src/backend/app/services/difficulty_service.py) |
| **Pillar 2: Conversational Voice AI** | Natural language entity extraction from voice interactions and daily check-ins | Lightweight entity parser extracting structured `{Task, Time, Status}` payloads from transcribed speech; multilingual phonetic mapping for Assamese, Bengali, Bodo, and English. | [`src/backend/app/core/nlu.py`](./src/backend/app/core/nlu.py)<br>[`src/patient_app/lib/services/voice_navigation_service.dart`](./src/patient_app/lib/services/voice_navigation_service.dart) |
| **Pillar 3: Predictive Analytics & Anomaly Detection** | Longitudinal cognitive drift tracking and early decline alerts | Rolling 7-day and 30-day Ordinary Least Squares (OLS) linear regression: $\hat{y} = \beta_0 + \beta_1 x$. Flags negative drift velocity ($\beta_1 < T$) and detects acute anomalies (>25% sudden accuracy drop or hesitation spikes). | [`src/backend/app/core/drift.py`](./src/backend/app/core/drift.py)<br>[`src/backend/app/services/analytics_service.py`](./src/backend/app/services/analytics_service.py) |
| **Pillar 4: Patient Risk Classifier (ML)** | Tri-level clinical risk stratification (Low / Moderate / High Risk) | Supervised Gradient Boosting / XGBoost classifier trained on multi-variate patient feature vectors: `[age, accuracy_rate_pct, reaction_time_ms, drift_slope_7d, active_alert_count]`. | [`src/backend/app/services/risk_model_service.py`](./src/backend/app/services/risk_model_service.py)<br>[`risk_batch_inference.py`](./risk_batch_inference.py) |

---

## 🎮 Culturally Grounded Cognitive Games

| Game | Cognitive Domain | Description & Mechanics | Status |
|---|---|---|---|
| **The Market Trip** | Working Memory & Delayed Recall | Players are shown a culturally contextualized shopping list (vegetables, local spices, household items), engage in a brief distractor task, and reconstruct the list from a visual grid under latency tracking. | ✅ **Live / Functional** (`src/patient_app/lib/games/market_trip/`) |
| **Tap the Target** | Attention & Processing Speed | Rapid target recognition requiring players to tap traditional cultural symbols (Japi, brass bell, tea flower) while filtering out visual distractors. Telemetry captures millisecond-level reaction times and hesitation pauses. | ✅ **Live / Functional** (`src/patient_app/lib/games/tap_target/`) |
| **Pair Matching** | Episodic Memory & Association | Interactive card-flip matching game scaling dynamically across grid sizes (4, 6, 8 pairs). Integrates custom family photo cards uploaded by caregivers to facilitate personal reminiscence. | ✅ **Live / Functional** (`src/patient_app/lib/games/pair_matching/`) |
| **Family & Village Finder** | Semantic Memory & Object Recognition | Identification and naming of familiar domestic and village scene objects. | ⏳ Planned (`src/patient_app/lib/screens/games_screen.dart`) |

---

## 📁 Repository Directory Structure

```
smriti-setu/
├── ARCHITECTURE.md                  # Comprehensive architectural specification & formulas
├── CONTAINER_GUIDE.md               # Detailed Podman & Docker deployment workflows
├── PROJECT_STATUS.md                # Comprehensive audit of implementation states and verification
├── docker-compose.yml               # Multi-container orchestration (Backend + Frontend)
├── run.sh                           # Unified local development runner with multiplexed logs
├── run-docker.sh                    # Containerized stack launcher
├── train_xg.py                      # Training pipeline for the XGBoost patient risk model
├── risk_batch_inference.py          # Standalone inference engine and CLI for patient risk grading
│
├── assets/                          # Design assets, system diagrams, and brand iconography
│
├── src/
│   ├── docs/                        # Specifications, design guides, and API contracts
│   │   ├── BRAND_GUIDELINES.md      # Dementia UI accessibility rules and color tokens
│   │   ├── GAMES_ANALYTICS_README.md# Game telemetry schema and clinical metrics
│   │   ├── API_ENDPOINTS_NEEDED.md  # Backend endpoint catalog and payload specs
│   │   └── START_SERVERS.md         # Quick-start CLI command cheat sheet
│   │
│   ├── backend/                     # FastAPI + MongoDB Backend Service
│   │   ├── Dockerfile & Containerfile
│   │   ├── requirements.txt         # Python dependencies (FastAPI, Beanie, Motor, Scikit-learn)
│   │   ├── app/
│   │   │   ├── main.py              # Application entrypoint, CORS, route mounting
│   │   │   ├── config.py            # Environment settings and algorithm weights
│   │   │   ├── database.py          # Motor client and Beanie ODM initialization
│   │   │   ├── api/routes/          # REST route handlers (auth, caregiver, patients, sync, etc.)
│   │   │   ├── core/                # Core algorithms (bandit, drift, nlu, security, otp, alerts)
│   │   │   ├── models/              # Beanie MongoDB Document models
│   │   │   ├── schemas/             # Pydantic validation schemas
│   │   │   ├── services/            # Domain services (analytics, difficulty, risk model)
│   │   │   └── agents/              # Serialized ML models (xgboost_patient_risk_model.pkl)
│   │   └── tests/                   # Unit test suite for core algorithms
│   │
│   ├── frontend/caregiver_app/      # Caregiver Web Dashboard (React + Vite)
│   │   ├── package.json             # NPM dependencies (React 18, Recharts, Tailwind CSS)
│   │   ├── vite.config.js           # Vite configuration with /api reverse proxy
│   │   ├── tailwind.config.js       # Brand color tokens (cream, terracotta, forest, slate)
│   │   └── src/
│   │       ├── pages/               # Dashboard, Analytics, CarePlan, PatientDetails, Login, etc.
│   │       ├── components/          # Reusable UI components, Modals, and Recharts graphs
│   │       ├── context/             # AuthContext, ThemeContext
│   │       ├── services/            # API client wrappers with local-storage fallback
│   │       └── layouts/             # DashboardLayout, PatientLayout
│   │
│   └── patient_app/                 # Patient Tablet Application (Flutter / Dart)
│       ├── pubspec.yaml             # Flutter dependencies (provider, sqflite, tflite_flutter)
│       ├── analysis_options.yaml    # Linter rules and quality constraints
│       ├── lib/
│       │   ├── main.dart            # Flutter entrypoint and multi-provider bootstrap
│       │   ├── theme/theme.dart     # Dementia-optimized typography & high-contrast theme
│       │   ├── screens/             # HomeScreen, GamesScreen, RemindersScreen, MemoryGallery
│       │   ├── games/               # Cognitive exercises (market_trip, tap_target, pair_matching)
│       │   ├── services/            # SQLite databases, API sync, voice navigation, personalization
│       │   └── widgets/             # SOS Button, Voice Nav Sheet, Mute Toggle
│       └── test/                    # 94+ unit and widget test cases (100% passing)
```

---

## 🚀 Quick Start Guide

### Prerequisites
- **Python:** 3.11+
- **Node.js:** 18+ & npm
- **Flutter SDK:** 3.3+
- **Container Engine:** Podman or Docker
- **Android Debug Bridge (ADB):** For physical device / emulator testing

---

### Option A: Unified Local Development Runner (Recommended)

The project includes an intelligent runner script that launches MongoDB, starts the Vite frontend, boots the FastAPI server, reverses Android ADB ports, and multiplexes all logs with colored tags:

```bash
chmod +x run.sh
./run.sh
```

- **Caregiver Web Dashboard:** [http://localhost:5173](http://localhost:5173)
- **FastAPI Documentation (Swagger):** [http://localhost:8000/docs](http://localhost:8000/docs)
- **FastAPI Health Check:** [http://localhost:8000/health](http://localhost:8000/health)
- **MongoDB:** `mongodb://localhost:27017`

---

### Option B: Step-by-Step Manual Setup

#### 1. Database (MongoDB)
Start a local MongoDB container:
```bash
podman run -d --name mongo-dev -p 27017:27017 mongo:latest
# or if already created:
podman start mongo-dev
```

#### 2. Backend Service (FastAPI)
```bash
cd src/backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Start the API server
uvicorn app.main:app --app-dir . --host 0.0.0.0 --port 8000 --reload
```

#### 3. Caregiver Web Dashboard (React + Vite)
```bash
cd src/frontend/caregiver_app
npm install
npm run dev
```

#### 4. Patient Tablet App (Flutter)
```bash
cd src/patient_app

# Forward backend port to Android tablet over USB:
adb reverse tcp:8000 tcp:8000

# Fetch dependencies and run:
flutter pub get
flutter run
```

---

### Option C: Containerized Deployment (Docker / Podman Compose)

```bash
# Build and run all microservices in the background
podman compose up -d --build
# or with docker:
docker compose up -d --build

# View real-time logs
podman compose logs -f
```
Refer to [`CONTAINER_GUIDE.md`](./CONTAINER_GUIDE.md) for rootless setups and container networking details.

---

## 🧪 Testing & Code Quality

### Patient Tablet App (Flutter)
The patient app maintains a strict standard of 0 linter warnings and comprehensive test coverage:
```bash
cd src/patient_app

# Run static analysis
flutter analyze
# Result: 0 issues found!

# Run full test suite (94+ passing tests)
flutter test
```

### Backend Unit Tests
```bash
cd src/backend
pytest tests/
```

### XGBoost Risk Inference Demo
```bash
python risk_batch_inference.py --demo
```

---

## 🔒 Security & Privacy

- **Zero Third-Party Auth Dependencies:** Completely self-hosted bcrypt password hashing and 2FA OTP generation; no proprietary identity lock-in.
- **Immediate JWT Blacklisting:** `revoked_tokens` Mongo collection ensures immediate invalidation upon logout before natural token expiration.
- **Strict Device Scoping:** Patient tablets hold hardware-tied pairing tokens restricted strictly to `/api/sync/batch` and reminder fetches, isolating caregiver administrative boundaries.
- **Local Data Minimization:** Audio speech transcripts are processed transiently; only structured entity records are queued for transmission.

---

## 📄 License & Attribution

This project is licensed under the terms of the MIT License. See [LICENSE](./LICENSE) for details. Built with care for elderly cognitive independence and caregiver peace of mind.
