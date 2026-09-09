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

### `GET /api/patients/:patientId/game-sessions`
- **Calling Service / Page:** `src/services/gameSessionService.js` (`Analytics.jsx`)
- **Purpose:** Fetch historical game session records and cognitive metrics for a specific patient.
- **Headers:** `Authorization: Bearer <token>`
- **Query Parameters (Optional):**
  - `domain`: `memory` | `language` | `attention` (filter by cognitive domain)
  - `limit`: integer (e.g. 50)
  - `from_date`: ISO string
- **Response Shape (200 OK):**
  ```json
  [
    {
      "session_id": "sess_mem_p101_1",
      "patient_profile_id": "p101",
      "game_type": "pair_matching",
      "domain": "memory",
      "session_date": "2026-08-08T10:15:00.000Z",
      "session_duration": 135,
      "status": "completed",
      "difficulty_level": 1,
      "score_normalized": 0.72,
      "correct_match_rate": 0.76,
      "total_flips": 18,
      "time_to_first_correct_match": 4.0,
      "repeat_error_rate": 0.09,
      "completion_time": 135,
      "pairs_count": 4,
      "used_face_name_variant": true,
      "raw_trials": []
    }
  ]
  ```
- **Error Responses:**
  - `401 Unauthorized`: Missing or invalid session token.
  - `404 Not Found`: Patient record not found.

