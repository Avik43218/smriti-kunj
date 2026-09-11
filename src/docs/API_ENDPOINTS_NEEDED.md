# API Endpoints Needed — Backend Integration Tracker

This document tracks all backend interactions proposed by the Caregiver App.
As stub functions are added to `src/services/`, they must be documented here.

---

## 1. Authentication

### `POST /api/auth/login`
- **Calling Service / Page:** `src/services/authService.js` (`Login.jsx`)
- **Purpose:** Authenticate caregiver credentials and establish session.
- **Request Body:**
  ```json
  {
    "email": "caregiver@example.com",
    "password": "user_password"
  }
  ```
- **Response Shape (200 OK):**
  ```json
  {
    "token": "mock_jwt_token_string",
    "caregiver": {
      "id": "cg_101",
      "name": "Dr. Sarah",
      "email": "caregiver@example.com"
    }
  }
  ```
- **Error Responses:**
  - `401 Unauthorized`: Invalid email or password.
  - `422 Unprocessable Entity`: Validation failure.

### `POST /api/auth/register`
- **Calling Service / Page:** `src/services/authService.js` (`Register.jsx`)
- **Purpose:** Register a new caregiver account and immediately return session token and caregiver profile.
- **Request Body:**
  ```json
  {
    "name": "Dr. Sarah Jenkins",
    "email": "sarah.jenkins@example.com",
    "password": "secure_password_123"
  }
  ```
- **Response Shape (200 OK / 201 Created):**
  ```json
  {
    "token": "mock_jwt_token_string",
    "caregiver": {
      "id": "cg_103",
      "name": "Dr. Sarah Jenkins",
      "email": "sarah.jenkins@example.com"
    }
  }
  ```
- **Error Responses:**
  - `400 Bad Request`: Password too short or invalid parameters.
  - `409 Conflict`: Email already registered.
  - `422 Unprocessable Entity`: Validation failure.

### `POST /api/auth/logout`
- **Calling Service / Page:** `src/services/authService.js` (`NavSidebar.jsx` / user profile menu)
- **Purpose:** Invalidate current authentication token / session.
- **Headers:** `Authorization: Bearer <token>`
- **Response Shape (200 OK):**
  ```json
  {
    "message": "Logged out successfully"
  }
  ```

### `POST /api/auth/patient/pair`
- **Calling Service / Page:** `src/patient_app/lib/services/api_service.dart` (`PairingScreen.dart`)
- **Purpose:** Register and pair a patient tablet using the pair code generated during registration. Links the device hardware and issues a long-lived JWT.
- **Request Body:**
  ```json
  {
    "pairing_code": "PAIR-891234",
    "device_id": "DEV-M10-8842",
    "device_name": "Smriti Kunj Patient Tablet"
  }
  ```
- **Response Shape (200 OK):**
  ```json
  {
    "patient_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "patient_code": "p101",
    "patient_name": "Aarav Sharma",
    "caregiver_id": "3fa85f64-5717-4562-b3fc-2c963f66afa7",
    "token": {
      "access_token": "patient_device_jwt_token",
      "token_type": "bearer",
      "expires_at": "2027-09-09T08:58:00Z"
    },
    "region_language": "bn",
    "emergency_contact": {
      "name": "Priya Sharma",
      "relationship": "Daughter (Primary Guardian)",
      "phone": "+91 98765 43210"
    },
    "diagnosis": "Mild Cognitive Impairment (MCI)",
    "status": "stable"
  }
  ```
- **Error Responses:**
  - `400 Bad Request`: Pairing code is missing or empty.
  - `404 Not Found`: Invalid or expired pairing code.

### `GET /api/auth/patient/me`
- **Calling Service / Page:** `src/patient_app/lib/services/api_service.dart`
- **Purpose:** Fetch current authenticated patient profile and emergency contact using device token.
- **Headers:** `Authorization: Bearer <token>`
- **Response Shape (200 OK):** Same shape as `PatientPairCompleteOut`.

---

## 2. Patient Roster & Management

### `GET /api/caregiver/patients`
- **Calling Service / Page:** `src/services/patientService.js` (`Dashboard.jsx`)
- **Purpose:** Fetch list of all patients assigned to the logged-in caregiver.
- **Headers:** `Authorization: Bearer <token>`
- **Response Shape (200 OK):**
  ```json
  [
    {
      "id": "p101",
      "name": "Aarav Sharma",
      "age": 72,
      "diagnosis": "Mild Cognitive Impairment",
      "avatarUrl": null,
      "status": "stable",
      "statusLabel": "Active • Tablet synced",
      "lastCheckIn": "Today, 10:30 AM"
    },
    {
      "id": "p102",
      "name": "Maya Sen",
      "age": 68,
      "diagnosis": "Early Stage Alzheimer's",
      "avatarUrl": null,
      "status": "attention",
      "statusLabel": "Check-in pending",
      "lastCheckIn": "Yesterday, 6:15 PM"
    }
  ]
  ```
- **Error Responses:**
  - `401 Unauthorized`: Missing or invalid session token.

### `GET /api/caregiver/patients/:id`
- **Calling Service / Page:** `src/services/patientService.js` (`PatientDetails.jsx`)
- **Purpose:** Fetch detailed profile, emergency contact, and pairing status for a specific patient.
- **Headers:** `Authorization: Bearer <token>`
- **Response Shape (200 OK):**
  ```json
  {
    "id": "p101",
    "name": "Aarav Sharma",
    "age": 72,
    "gender": "Male",
    "dateOfBirth": "March 14, 1954",
    "healthIssue": "Mild Cognitive Impairment (MCI) • Early-stage memory recall decline • Hypertension",
    "avatarUrl": null,
    "status": "stable",
    "statusLabel": "Active • Tablet synced",
    "lastCheckIn": "Today, 10:30 AM",
    "emergencyContact": {
      "name": "Priya Sharma",
      "relationship": "Daughter (Primary Guardian)",
      "phone": "+91 98765 43210"
    },
    "deviceStatus": {
      "linked": true,
      "deviceName": "Lenovo Tab M10 Plus (Patient Unit 1)",
      "deviceId": "DEV-M10-8842",
      "lastSynced": "Today, 10:30 AM"
    }
  }
  ```
- **Error Responses:**
  - `401 Unauthorized`: Missing or invalid session token.
  - `404 Not Found`: Patient not found or unauthorized access.

---

## 3. Care Plan & Customization — Memory Gallery

### `GET /api/patients/:patientId/family-members`
- **Calling Service / Page:** `src/services/carePlanService.js` (`CarePlan.jsx`)
- **Purpose:** Retrieve all family member photo memory cards for a specific patient.
- **Headers:** `Authorization: Bearer <token>`
- **Response Shape (200 OK):**
  ```json
  [
    {
      "id": "fam_1",
      "patientId": "p1",
      "name": "Zara Begum",
      "relation": "Granddaughter",
      "photoUrl": "data:image/svg+xml;..."
    }
  ]
  ```

### `POST /api/patients/:patientId/family-members`
- **Calling Service / Page:** `src/services/carePlanService.js` (`CarePlan.jsx`)
- **Purpose:** Create a new family member memory card for a patient.
- **Headers:** `Authorization: Bearer <token>`
- **Request Body:**
  ```json
  {
    "name": "Zara Begum",
    "relation": "Granddaughter",
    "photoUrl": "data:image/jpeg;base64,..."
  }
  ```
- **Response Shape (201 Created):**
  ```json
  {
    "id": "fam_101",
    "patientId": "p1",
    "name": "Zara Begum",
    "relation": "Granddaughter",
    "photoUrl": "data:image/jpeg;base64,..."
  }
  ```
- **Error Responses:**
  - `400 Bad Request`: Missing required fields (`name`, `relation`, `photoUrl`).

---

## 4. Care Plan — Health & Wellness Reminders

### `GET /api/patients/:patientId/reminders`
- **Calling Service / Page:** `src/services/reminderService.js` (`CarePlan.jsx`)
- **Purpose:** Retrieve all Health & Wellness reminders (Medication, Hydration, Meals, Custom) for a patient.
- **Headers:** `Authorization: Bearer <token>`
- **Response Shape (200 OK):**
  ```json
  {
    "medication": [
      { "id": "med_1", "label": "Morning Dose", "time": "8:00 AM" }
    ],
    "hydration": {
      "id": "hyd_1",
      "label": "Hourly Water Intake",
      "schedule": "8 AM–8 PM",
      "status": "Active"
    },
    "meals": [
      { "id": "meal_1", "label": "Breakfast", "time": "8:30 AM" }
    ],
    "custom": [
      { "id": "cust_1", "label": "Evening Walk & Stretch", "time": "5:00 PM", "frequency": "Daily" }
    ]
  }
  ```

### `PUT /api/patients/:patientId/reminders/:category`
- **Calling Service / Page:** `src/services/reminderService.js` (`CarePlan.jsx`)
- **Purpose:** Update existing labels/times for a category (`medication`, `hydration`, `meals`).
- **Headers:** `Authorization: Bearer <token>`
- **Request Body:** Updated array or object for that category.
- **Response Shape (200 OK):** Returns updated category payload.

### `POST /api/patients/:patientId/reminders/custom`
- **Calling Service / Page:** `src/services/reminderService.js` (`CarePlan.jsx`)
- **Purpose:** Add a one-off custom reminder for a patient.
- **Headers:** `Authorization: Bearer <token>`
- **Request Body:**
  ```json
  {
    "label": "Evening Walk & Stretch",
    "time": "5:00 PM",
    "frequency": "Daily"
  }
  ```
- **Response Shape (201 Created):**
  ```json
  {
    "id": "cust_101",
    "label": "Evening Walk & Stretch",
    "time": "5:00 PM",
    "frequency": "Daily"
  }
  ```

---

## 5. Cognitive Game Sessions & Analytics

> **Note:** The schemas below use a nested `game_data` envelope (proposed contract pending backend confirmation).
> Shared fields (`session_id`, `patient_profile_id`, `game_type`, `domain`, `session_date`, `session_duration`, `status`, `difficulty_level`, `score_normalized`, `raw_trials`) are top-level, while game-specific metrics live inside `game_data`.

### `POST /api/games/sessions`
- **Calling Service / App:** `src/patient_app/lib/games/shared/services/game_sync_service.dart` (Patient App)
- **Purpose:** Upload completed or abandoned cognitive game sessions from the patient tablet local queue to the backend.
- **Headers:** `Authorization: Bearer <token>`, `Content-Type: application/json`
- **Request Body (Nested Envelope):**
  ```json
  {
    "session_id": "mt_1725816312000",
    "patient_profile_id": "p101",
    "game_type": "market_trip",
    "domain": "working_memory",
    "session_date": "2026-09-10T10:15:00.000Z",
    "session_duration": 87.4,
    "status": "completed",
    "difficulty_level": 1,
    "score_normalized": 0.85,
    "game_data": {
      "items_prompted_count": 3,
      "items_recalled_correct": 3,
      "recall_accuracy": 1.0,
      "false_selection_count": 0,
      "time_to_complete_recall": 12.3,
      "distractor_task_completed": true,
      "delay_duration": 30.0,
      "prompt_language": "english",
      "telemetry": {
        "latency": {
          "avg_ms": 412.5,
          "median_ms": 395.0,
          "min_ms": 320.0,
          "max_ms": 850.0,
          "variability_ms": 45.2,
          "p90_ms": 620.0
        },
        "accuracy": {
          "overall_rate": 0.850,
          "total_rounds": 20,
          "correct_count": 17,
          "error_count": 3
        },
        "hesitation": {
          "hesitation_events_count": 2,
          "total_hesitation_ms": 3200.0,
          "avg_hesitation_ms": 1600.0,
          "hesitation_ratio": 0.120,
          "initial_hesitation_ms": 1450.0
        },
        "error_burst": {
          "max_consecutive_errors": 2,
          "error_burst_count": 1,
          "burst_errors_count": 2,
          "error_burst_rate": 0.667,
          "burst_detected": true
        },
        "rounds": [
          {
            "round_index": 1,
            "timestamp": "2026-09-10T10:15:00.000Z",
            "event_type": "target_hit",
            "latency_ms": 425.0,
            "accuracy": 1.0,
            "hesitation": { "hesitation_ms": 0.0, "is_hesitation": false },
            "error_burst": { "is_error": false, "consecutive_errors": 0, "is_error_burst": false }
          }
        ]
      }
    },
    "raw_trials": [
      {
        "round_index": 1,
        "event_type": "target_hit",
        "latency_ms": 425.0,
        "accuracy": 1.0,
        "hesitation": { "hesitation_ms": 0.0, "is_hesitation": false },
        "error_burst": { "is_error": false, "consecutive_errors": 0, "is_error_burst": false }
      }
    ]
  }
  ```

#### `game_data` schemas by `game_type`:

All games include the standard `telemetry` JSON object (`latency`, `accuracy`, `hesitation`, `error_burst`, `rounds`) along with domain-specific metrics:

1. **`market_trip` (`working_memory`):**
   ```json
   {
     "items_prompted_count": 3,
     "items_recalled_correct": 3,
     "recall_accuracy": 1.0,
     "false_selection_count": 0,
     "time_to_complete_recall": 12.3,
     "distractor_task_completed": true,
     "delay_duration": 30.0,
     "prompt_language": "english",
     "telemetry": { ... }
   }
   ```

2. **`tap_target` (`attention`):**
   ```json
   {
     "reaction_time_avg": 412.5,
     "reaction_time_variability": 38.2,
     "omission_rate": 0.05,
     "false_positive_rate": 0.02,
     "within_session_drift": 12.4,
     "trial_count": 15,
     "target_item_type": "japi",
     "telemetry": { ... }
   }
   ```

3. **`pair_matching` (`episodic_memory`):**
   ```json
   {
     "total_flips": 18,
     "correct_match_rate": 0.76,
     "time_to_first_correct_match": 4.0,
     "repeat_error_rate": 0.09,
     "completion_time": 135.0,
     "pairs_count": 4,
     "used_face_name_variant": false,
     "telemetry": { ... }
   }
   ```

- **Response Shape (200 OK / 201 Created):**
  ```json
  {
    "success": true,
    "session_id": "mt_1725816312000",
    "synced_at": "2026-09-10T10:15:02.000Z"
  }
  ```
- **Error Responses:**
  - `400 Bad Request`: Validation failure on envelope or game_data payload.
  - `401 Unauthorized`: Missing or expired patient auth token.

---

### `GET /api/patients/:patientId/game-sessions`
- **Calling Service / Page:** `src/services/gameSessionService.js` (`Analytics.jsx` - Caregiver Web)
- **Purpose:** Fetch historical game session records and cognitive metrics for a specific patient.
- **Headers:** `Authorization: Bearer <token>`
- **Query Parameters (Optional):**
  - `domain`: `working_memory` | `episodic_memory` | `semantic_memory` | `attention`
  - `game_type`: `market_trip` | `tap_target` | `pair_matching`
  - `limit`: integer (e.g. 50)
  - `from_date`: ISO string
- **Response Shape (200 OK):**
  ```json
  [
    {
      "session_id": "pm_1725816312000",
      "patient_profile_id": "p101",
      "game_type": "pair_matching",
      "domain": "episodic_memory",
      "session_date": "2026-08-08T10:15:00.000Z",
      "session_duration": 135.0,
      "status": "completed",
      "difficulty_level": 1,
      "score_normalized": 0.72,
      "game_data": {
        "total_flips": 18,
        "correct_match_rate": 0.76,
        "time_to_first_correct_match": 4.0,
        "repeat_error_rate": 0.09,
        "completion_time": 135.0,
        "pairs_count": 4,
        "used_face_name_variant": false
      },
      "raw_trials": []
    }
  ]
  ```
- **Error Responses:**
  - `401 Unauthorized`: Missing or invalid session token.
  - `404 Not Found`: Patient record not found.


