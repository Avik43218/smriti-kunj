# Project Status Snapshot — Smriti Kunj

## 1. Project Overview

Smriti Kunj (Caregiver Portal) and Smriti Kunj (Patient Tablet App) comprise an integrated cognitive assistive care ecosystem designed for individuals living with Mild Cognitive Impairment (MCI) and early-stage dementia. The platform provides culturally contextualized cognitive exercises, routine adherence tracking, emergency SOS, and reminiscence tools for elderly patients, coupled with a web-based clinical dashboard enabling caregivers to monitor cognitive stability, manage multi-patient care plans, and track multi-domain longitudinal performance without clinical intrusion.

---

## 2. Architecture Summary

- **Caregiver Web Application (`src/frontend/caregiver_app`):** Built with React 18, Vite, Tailwind CSS, Lucide icons, and Recharts for responsive time-series visualization. Uses React Router DOM for routing, context-based state management (`AuthContext`, `ThemeContext`), and an asynchronous API client with local storage caching for zero-downtime offline previews.
- **Patient Tablet Application (`src/patient_app`):** Built with Flutter (Dart), utilizing Provider for state management and SQLite (`sqflite`) for offline-first local persistence. Adheres to strict dementia accessibility constraints (88dp minimum touch targets, 18px text floor, no dark mode) specified in `src/docs/BRAND_GUIDELINES.md`. Features on-device TFLite dynamic difficulty initialization, offline telemetry queuing, and multi-lingual voice navigation.
- **Backend Service (`src/backend`):** Built with Python FastAPI and Beanie ODM over MongoDB. Implements modular routers for role-based authentication (caregiver password/OTP + patient device pairing tokens), caregiver multi-patient management, care plan customization, batch telemetry synchronization, cognitive drift analytics, multi-armed bandit difficulty progression, and voice intent classification.
- **Shared Session Schema:** Canonical cognitive session envelope (`session_id`, `patient_profile_id`, `game_type`, `domain`, `session_date`, `session_duration`, `status`, `difficulty_level`, `score_normalized`, `game_data`, `raw_trials`) standardized across edge SQLite repositories, API sync payloads, and MongoDB analytics collections.

---

## 3. Caregiver Dashboard Status

*Verified via source scan of `src/frontend/caregiver_app/src/`:*

### Implemented Routes & Pages
- `/login` (`src/frontend/caregiver_app/src/pages/Login.jsx`): Two-phase authentication (password verification followed by 6-digit OTP entry), error handling, and demo-credential autofill.
- `/register` (`src/frontend/caregiver_app/src/pages/Register.jsx`): Caregiver account creation with live password strength scoring.
- `/dashboard` (`src/frontend/caregiver_app/src/pages/Dashboard.jsx`): Multi-patient roster management, live search filtering, care status categorization (`normal`, `reminder_missed`, `alert`), and quick navigation.
- `/patients/new` (`src/frontend/caregiver_app/src/pages/RegisterPatient.jsx`): Comprehensive patient onboarding form (1,100+ lines) collecting personal data, medical diagnoses, lifestyle factors, emergency guardian contacts, device pairing code generation, and initial family memory photos. Persists via `patientService.js` with backend POST and local storage caching.
- `/patients/:id/details` (`src/frontend/caregiver_app/src/pages/PatientDetails.jsx`): Detailed patient medical profile, tablet pairing status, device hardware identifiers, and live compliance summary.
- `/patients/:id/care-plan` & `/care-plan` (`src/frontend/caregiver_app/src/pages/CarePlan.jsx`): Comprehensive management interface for photo memory cards, audio reminiscence clips, daily schedule reminders (medication, hydration, meals, custom activities), compliance tracking, and alarm cancellation confirmation modals.
- `/patients/:id/analytics` (`src/frontend/caregiver_app/src/pages/Analytics.jsx`): Recharts multi-domain cognitive performance trend charts (Episodic Memory, Working Memory, Language & Semantic, Attention & Processing), difficulty progression indicators, and detailed session history tables.

### Component Library (`src/frontend/caregiver_app/src/components/`)
- Form & Controls: `IconButton.jsx`, `OtpInput.jsx`, `PasswordStrengthIndicator.jsx`, `StyledSelect.jsx`, `TimePicker.jsx`, `TopControls.jsx`.
- Navigation & Chrome: `Navbar.jsx`, `Footer.jsx`, `LanguageSelector.jsx`, `NotificationsPanel.jsx`, `ProfilePopover.jsx`, `ProtectedRoute.jsx`, `SettingsDropdown.jsx`.
- Cards & Visuals: `PatientCard.jsx`, `SoundClipCard.jsx`, `LiveBackgroundShader.jsx`.
- Modals: `AlarmOffModal.jsx`, `ConfirmDeleteModal.jsx`.
- Layouts (`src/frontend/caregiver_app/src/layouts/`): `DashboardLayout.jsx`, `PatientLayout.jsx`.

### Service Layer & State Management
- `apiClient.js`: Centralized fetch wrapper handling JWT bearer injection and abort signals.
- `authService.js`: Caregiver authentication and OTP submission with session caching.
- `patientService.js`: Patient roster retrieval, patient registration, and dynamic care status computation based on reminder adherence.
- `carePlanService.js`: Family member memory card CRUD operations.
- `reminderService.js`: Reminder retrieval, category mutation, custom reminder addition, and daily compliance calculation.
- `gameSessionService.js`: Cognitive analytics data retrieval with domain metadata mapping.
- All frontend services incorporate local storage fallback to ensure full interface functionality during offline or standalone evaluation.

---

## 4. Patient App Status

*Verified via source scan of `src/patient_app/lib/`:*

### Implemented Screens (`src/patient_app/lib/screens/`)
- `home_screen.dart`: Primary calm landing interface presenting large high-contrast navigation tiles for Brain Games, Today's Reminders, Memories & Family Gallery, and an emergency Call for Help (SOS) tile. Includes live date/time display and voice command triggering.
- `pairing_screen.dart`: Tablet setup screen for linking the physical device to a caregiver patient profile using a 6-character code (`PAIR-XXXXXX`). Supports offline demo fallback when network is unavailable.
- `games_screen.dart`: Catalog of available cognitive exercises with dynamic difficulty level resolution, localized title/subtitle strings, and launch handlers.
- `reminders_screen.dart`: Daily schedule display grouped into Morning, Afternoon, Evening, and Night, supporting single-tap task completion and synchronization with SQLite.
- `memory_gallery_screen.dart`: Visual and auditory reminiscence gallery with photo expansion and audio clip playback controls.

### Provider & Architecture Services (`src/patient_app/lib/services/`)
- Application State: `SessionService` (authentication and pairing state), `LocaleService` (Assamese, Bengali, Bodo, English language selection), `SpeechRecognitionService` (voice command transcription).
- Data Persistence: `ActivityDatabaseService` (SQLite storage for patient activities and sync queue), `ReminderDatabaseService` (SQLite storage for daily reminders), `DifficultyDatabaseService` (SQLite storage for dynamic difficulty levels and pending adjustments), `GameSessionRepository` (SQLite storage for full game telemetry payloads).
- Networking & Telemetry: `ApiService` (HTTP client with automatic network candidate resolution across localhost, emulator 10.0.2.2, and local LAN IPs), `GameSyncService` (background synchronization worker).
- Interaction & Accessibility: `VoiceNavigationCoordinator` & `VoiceNavigationService` (comprehensive 14-command multilingual voice navigation supporting Home, Sync, SOS/Help, Daily Reminders, Memory Gallery, real-time Language switching across Assamese, Bengali, Bodo, English, cognitive games navigation, and logout; includes phonetic romanization and English speech recognizer compatibility for regional pronunciations), `TtsService` (text-to-speech audio feedback), `BackgroundMusicService` (ambient audio management), `AppColors` & `patientTheme` (`src/patient_app/lib/theme/theme.dart`).

---

## 5. Cognitive Games Status

*Verified via source scan of `src/patient_app/lib/games/` and `src/docs/GAMES_ANALYTICS_README.md`:*

| Game | Cognitive Domain | Implementation State | Verification Findings |
|---|---|---|---|
| **The Market Trip** | Working Memory & Delayed Recall | **Live / Functional** | Implemented under `src/patient_app/lib/games/market_trip/`. Audio/visual prompt lists items to buy; features distractor task interaction, visual recall grid, item bank service (`item_bank_service.dart`), multi-trial latency tracking, and normalized scoring. Launched via `_launchMarketTrip` in `games_screen.dart`. |
| **Tap the Target** | Attention & Processing Speed | **Live / Functional** | Implemented under `src/patient_app/lib/games/tap_target/`. Culturally customized target detection (`target_bank_service.dart` with items like Japi, bell, flower), distractor interference, millisecond-level reaction time and hesitation telemetry, omission and false positive tracking. Launched via `_launchTapTarget` in `games_screen.dart`. |
| **Pair Matching** | Episodic Memory | **Live / Functional** | Implemented under `src/patient_app/lib/games/pair_matching/`. Card-flip matching game (`pair_bank_service.dart`), dynamic grid scaling (4, 6, 8 pairs), flip counters, repeat error calculation, and support for personalized family photo cards. Launched via `_launchPairMatching` in `games_screen.dart`. |
| **Family & Village Finder** | Semantic Memory & Object Recognition | **Stub / Placeholder** | Represented in `src/patient_app/lib/screens/games_screen.dart` as an inactive card (`isLive: false`, `comingSoonLabel: 'Coming soon'`). Full specification documented in `src/docs/GAMES_ANALYTICS_README.md`, but no screen or logic implementation directory exists under `src/patient_app/lib/games/`. |

### Telemetry Pipeline Implementation
- `GameSessionResult` models in `market_trip` and `pair_matching` compute raw latency, accuracy, hesitation events, error bursts, and trial arrays.
- Completed games write records into SQLite via `ActivityDatabaseService.recordGameActivity` and `GameSessionRepository.saveSession`.

---

## 6. Backend / API Status

*Comparison between `src/docs/API_ENDPOINTS_NEEDED.md` and live FastAPI routers in `src/backend/app/api/routes/`:*

| Endpoint | Method | Status | Notes |
|---|---|---|---|
| `/api/auth/register` | POST | **Live** | In `auth.py`. Validates input, creates caregiver user in MongoDB, hashes password. |
| `/api/auth/login` | POST | **Live** | In `auth.py`. Validates password, generates 6-digit OTP code. |
| `/api/auth/request-otp` | POST | **Live** | In `auth.py`. Generates and stores fresh OTP code. |
| `/api/auth/verify-otp` | POST | **Live** | In `auth.py`. Verifies code, issues caregiver JWT session token. |
| `/api/auth/logout` | POST | **Live** | In `auth.py`. Revokes active JWT token. |
| `/api/auth/me` | GET | **Live** | In `auth.py`. Returns active authenticated caregiver user. |
| `/api/auth/patient/pair/start` | POST | **Live** | In `auth.py`. Generates pairing code for patient. |
| `/api/auth/patient/pair` & `/complete` | POST | **Live** | In `auth.py`. Exchanges pairing code for long-lived patient device JWT token. |
| `/api/auth/patient/me` | GET | **Live** | In `auth.py`. Resolves patient profile from device token. |
| `/api/caregiver/patients` | GET | **Live** | In `caregiver.py`. Returns all patients belonging to authenticated caregiver. |
| `/api/caregiver/patients` | POST | **Live** | In `caregiver.py`. Creates patient profile and generates device pairing code. |
| `/api/caregiver/patients/{id}` | GET | **Live** | In `caregiver.py`. Fetches detailed patient profile. |
| `/api/caregiver/patients/{id}` | DELETE | **Live** | In `caregiver.py`. Removes patient record and associated tokens. |
| `/api/caregiver/dashboard/{patient_id}` | GET | **Live** | In `caregiver.py`. Returns summary compliance and alert stats. |
| `/api/patients/{patientId}/family-members` | GET | **Live** | In `patients.py`. Queries MongoDB for patient memory cards. |
| `/api/patients/{patientId}/family-members` | POST | **Live** | In `patients.py`. Creates new photo memory card. |
| `/api/patients/reminders` | GET / POST | **Live** | In `patients.py`. Fetches/updates reminders by pairing code for patient tablet. |
| `/api/patients/{patientId}/reminders` | GET | **Live** | In `patients.py`. Caregiver fetch of categorized patient reminders. |
| `/api/patients/{patientId}/reminders/{category}` | PUT | **Live** | In `patients.py`. Updates medication, hydration, or meals category. |
| `/api/patients/{patientId}/reminders/custom` | POST | **Live** | In `patients.py`. Appends custom reminder item. |
| `/api/patients/{patientId}/game-sessions` | GET | **Live** | In `patients.py`. Queries MongoDB historical game sessions for caregiver analytics charts. |
| `/api/sync/batch` (aliases `/sync/batch`, `/api/sync`) | POST | **Live** | In `sync.py`. Batch ingest endpoint for patient activities and voice records. Updates bandit and checks anomalies. |
| `/api/games/sessions` | POST | **Documented Only / Stubbed at Edge** | Documented in `API_ENDPOINTS_NEEDED.md` §5 and targeted by `GameSyncService.dart`. Not implemented as a standalone route in FastAPI; backend utilizes `/api/sync/batch` for session ingestion. |
| `/api/analytics/patient/{patient_id}/drift` | GET | **Live** | In `analytics.py`. Longitudinal domain drift metrics. |
| `/api/analytics/patient/{patient_id}/alerts` | GET | **Live** | In `analytics.py`. High-priority clinical anomaly alerts. |
| `/api/difficulty/next/{game_type}` | GET | **Live** | In `difficulty.py`. Multi-armed bandit difficulty recommendation. |
| `/api/voice/classify` | POST | **Live** | In `voice.py`. Intent classification for voice transcripts. |

---

## 7. Key Documentation Index

- **Brand Guidelines:** [`src/docs/BRAND_GUIDELINES.md`](file:///home/ghost/smriti-setu/src/docs/BRAND_GUIDELINES.md) — Visual tokens, typography rules, cultural motif governance, and dementia accessibility constraints.
- **Caregiver App Agent Guide:** [`src/frontend/caregiver_app/AGENTS.md`](file:///home/ghost/smriti-setu/src/frontend/caregiver_app/AGENTS.md) — Caregiver portal route structure, design system conventions, and state guidelines.
- **Patient App Agent Guide:** [`src/patient_app/AGENTS.md`](file:///home/ghost/smriti-setu/src/patient_app/AGENTS.md) — Patient tablet constraints (88dp touch targets, 18px text floor), Provider state management, and interaction rules.
- **Cognitive Games & Analytics Reference:** [`src/docs/GAMES_ANALYTICS_README.md`](file:///home/ghost/smriti-setu/src/docs/GAMES_ANALYTICS_README.md) — Scientific rationale, domain mappings, parameters, and telemetry schema for all 4 cognitive exercises.
- **Backend Integration Tracker:** [`src/docs/API_ENDPOINTS_NEEDED.md`](file:///home/ghost/smriti-setu/src/docs/API_ENDPOINTS_NEEDED.md) — Detailed contract specifications, payload structures, and endpoint progress tracking.

---

## 8. Deferred & Known Issues

1. **4th Cognitive Game Deferred:** Game 4 (Family & Village Object Finder / Semantic Memory) is specified in `GAMES_ANALYTICS_README.md` and represented as a placeholder card in `games_screen.dart`, but no game logic or widget implementation exists.
2. **Game Sync Service Discrepancy:**
   - The patient app contains two distinct sync mechanisms:
     1. `ApiService.instance.syncBatchActivities`: Actively wired to `POST /api/sync/batch` (live in backend `sync.py`).
     2. `GameSyncService.instance.syncAll`: Operates on `GameSessionRepository`, but its target endpoint `POST /api/games/sessions` is commented out as a simulated stub because the standalone single-session route does not exist in FastAPI.
3. **Memory Gallery Patient App Integration:** `src/patient_app/lib/screens/memory_gallery_screen.dart` displays hardcoded memory items (`_mockMemories`) instead of fetching live caregiver-uploaded cards from `GET /api/patients/{patientId}/family-members`.
4. **Backend Email Dispatch Stubbed:** `_issue_otp` in `src/backend/app/api/routes/auth.py` logs generated OTP codes to stdout (`[stub email] OTP for ...`) rather than integrating with an SMTP, SES, or SendGrid email transport service.
5. **Base URL IP Configuration in Flutter:** `ApiService.baseUrl` in `src/patient_app/lib/main.dart` defaults to a fixed LAN address (`http://192.168.1.240:8000`). While `candidateBaseUrls` falls back to `localhost` and `10.0.2.2`, testing across variable local networks requires updating this address or injecting it dynamically.
6. **Authentication Flow Documentation Drift:** `API_ENDPOINTS_NEEDED.md` §1 documents `POST /api/auth/login` returning session tokens directly, whereas the actual codebase implements a more secure two-step OTP verification flow (`/login` followed by `/verify-otp`).

---

## 9. Sources Scanned

The following 68 repository files were read and analyzed to generate this snapshot:

### Reference & Documentation Files
- `src/docs/BRAND_GUIDELINES.md`
- `src/frontend/caregiver_app/AGENTS.md`
- `src/patient_app/AGENTS.md`
- `src/docs/GAMES_ANALYTICS_README.md`
- `src/docs/API_ENDPOINTS_NEEDED.md`

### Caregiver Application Source Files
- `src/frontend/caregiver_app/package.json`
- `src/frontend/caregiver_app/tailwind.config.js`
- `src/frontend/caregiver_app/src/App.jsx`
- `src/frontend/caregiver_app/src/main.jsx`
- `src/frontend/caregiver_app/src/index.css`
- `src/frontend/caregiver_app/src/layouts/DashboardLayout.jsx`
- `src/frontend/caregiver_app/src/layouts/PatientLayout.jsx`
- `src/frontend/caregiver_app/src/context/AuthContext.jsx`
- `src/frontend/caregiver_app/src/context/ThemeContext.jsx`
- `src/frontend/caregiver_app/src/pages/Dashboard.jsx`
- `src/frontend/caregiver_app/src/pages/Analytics.jsx`
- `src/frontend/caregiver_app/src/pages/CarePlan.jsx`
- `src/frontend/caregiver_app/src/pages/PatientDetails.jsx`
- `src/frontend/caregiver_app/src/pages/RegisterPatient.jsx`
- `src/frontend/caregiver_app/src/pages/Login.jsx`
- `src/frontend/caregiver_app/src/pages/Register.jsx`
- `src/frontend/caregiver_app/src/components/AlarmOffModal.jsx`
- `src/frontend/caregiver_app/src/components/ConfirmDeleteModal.jsx`
- `src/frontend/caregiver_app/src/components/Footer.jsx`
- `src/frontend/caregiver_app/src/components/IconButton.jsx`
- `src/frontend/caregiver_app/src/components/LanguageSelector.jsx`
- `src/frontend/caregiver_app/src/components/LiveBackgroundShader.jsx`
- `src/frontend/caregiver_app/src/components/Navbar.jsx`
- `src/frontend/caregiver_app/src/components/NotificationsPanel.jsx`
- `src/frontend/caregiver_app/src/components/OtpInput.jsx`
- `src/frontend/caregiver_app/src/components/PasswordStrengthIndicator.jsx`
- `src/frontend/caregiver_app/src/components/PatientCard.jsx`
- `src/frontend/caregiver_app/src/components/ProfilePopover.jsx`
- `src/frontend/caregiver_app/src/components/ProtectedRoute.jsx`
- `src/frontend/caregiver_app/src/components/SettingsDropdown.jsx`
- `src/frontend/caregiver_app/src/components/SoundClipCard.jsx`
- `src/frontend/caregiver_app/src/components/StyledSelect.jsx`
- `src/frontend/caregiver_app/src/components/TimePicker.jsx`
- `src/frontend/caregiver_app/src/components/TopControls.jsx`
- `src/frontend/caregiver_app/src/services/apiClient.js`
- `src/frontend/caregiver_app/src/services/api.js`
- `src/frontend/caregiver_app/src/services/authService.js`
- `src/frontend/caregiver_app/src/services/carePlanService.js`
- `src/frontend/caregiver_app/src/services/gameSessionService.js`
- `src/frontend/caregiver_app/src/services/patientService.js`
- `src/frontend/caregiver_app/src/services/reminderService.js`

### Patient Application Source Files
- `src/patient_app/pubspec.yaml`
- `src/patient_app/lib/main.dart`
- `src/patient_app/lib/theme/theme.dart`
- `src/patient_app/lib/screens/home_screen.dart`
- `src/patient_app/lib/screens/pairing_screen.dart`
- `src/patient_app/lib/screens/games_screen.dart`
- `src/patient_app/lib/screens/reminders_screen.dart`
- `src/patient_app/lib/screens/memory_gallery_screen.dart`
- `src/patient_app/lib/widgets/sos_button.dart`
- `src/patient_app/lib/widgets/voice_nav_button.dart`
- `src/patient_app/lib/widgets/voice_navigation_sheet.dart`
- `src/patient_app/lib/widgets/mute_toggle.dart`
- `src/patient_app/lib/models/patient_activity.dart`
- `src/patient_app/lib/models/patient_session.dart`
- `src/patient_app/lib/models/reminder_item.dart`
- `src/patient_app/lib/services/api_service.dart`
- `src/patient_app/lib/services/session_service.dart`
- `src/patient_app/lib/services/activity_database_service.dart`
- `src/patient_app/lib/services/reminder_database_service.dart`
- `src/patient_app/lib/services/difficulty_database_service.dart`
- `src/patient_app/lib/services/difficulty_service.dart`
- `src/patient_app/lib/services/locale_service.dart`
- `src/patient_app/lib/services/speech_recognition_service.dart`
- `src/patient_app/lib/services/tts_service.dart`
- `src/patient_app/lib/services/voice_navigation_coordinator.dart`
- `src/patient_app/lib/services/voice_navigation_service.dart`
- `src/patient_app/lib/services/background_music_service.dart`
- `src/patient_app/lib/services/app_strings.dart`
- `src/patient_app/lib/games/market_trip/screens/market_trip_game.dart`
- `src/patient_app/lib/games/market_trip/screens/market_trip_game_screen.dart`
- `src/patient_app/lib/games/market_trip/services/item_bank_service.dart`
- `src/patient_app/lib/games/market_trip/models/game_session_result.dart`
- `src/patient_app/lib/games/tap_target/screens/tap_target_game.dart`
- `src/patient_app/lib/games/tap_target/screens/tap_target_game_screen.dart`
- `src/patient_app/lib/games/tap_target/services/target_bank_service.dart`
- `src/patient_app/lib/games/pair_matching/screens/pair_matching_game.dart`
- `src/patient_app/lib/games/pair_matching/screens/pair_matching_game_screen.dart`
- `src/patient_app/lib/games/pair_matching/services/pair_bank_service.dart`
- `src/patient_app/lib/games/pair_matching/models/game_session_result.dart`
- `src/patient_app/lib/games/shared/services/game_session_repository.dart`
- `src/patient_app/lib/games/shared/services/game_sync_service.dart`

### Backend Source Files
- `src/backend/app/main.py`
- `src/backend/app/config.py`
- `src/backend/app/database.py`
- `src/backend/app/api/routes/auth.py`
- `src/backend/app/api/routes/caregiver.py`
- `src/backend/app/api/routes/patients.py`
- `src/backend/app/api/routes/sync.py`
- `src/backend/app/api/routes/analytics.py`
- `src/backend/app/api/routes/difficulty.py`
- `src/backend/app/api/routes/voice.py`
- `src/backend/app/models/user.py`
- `src/backend/app/models/auth.py`
- `src/backend/app/models/care_plan.py`
- `src/backend/app/models/reminder.py`
- `src/backend/app/models/session.py`
- `src/backend/app/models/analytics.py`
- `src/backend/app/schemas/auth.py`
- `src/backend/app/schemas/patient.py`
- `src/backend/app/schemas/sync.py`

---

## 10. Last Updated

**September 12, 2026**
