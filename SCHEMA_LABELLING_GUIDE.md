# MongoDB Database & API Schema Labelling Guide
**Repository:** Smriti Kunj (`smriti-kunj`)  
**Scope:** Backend MongoDB Collections & Pydantic Data Contracts  
**Status:** Audit Completed & Guidance Drafted (Zero Codebase Modifications Made)

---

## 1. Executive Summary & Audit Findings

An analysis of the database structure and schema definitions across the repository (`src/backend/app/schemas/` and MongoDB Beanie collection models in `src/backend/app/models/` on the `proto` branch, as well as the initial models in `backend/main.py`) was conducted to evaluate whether schemas, documents, and individual attributes are **labelled**.

### What Does "Labelled" Mean?
In modern MongoDB and FastAPI architectures, database structures and data interchange schemas are considered properly labelled when they possess:
1. **Field-Level Human Labels (`title`):** Human-readable, descriptive labels for UI forms, data dictionaries, and API documentation.
2. **Clinical / Technical Descriptions (`description`):** Clear definitions of what the attribute represents, its business logic, and purpose.
3. **Telemetry & Unit Metadata:** Explicit declarations of units (e.g., milliseconds `ms`, timestamps `UTC ISO 8601`, normalized float ranges `0.0 - 1.0`).
4. **Examples & Validation Constraints:** Permissible values, ranges (`ge`, `le`), format masks, and enum descriptions.
5. **MongoDB Native Collection Validators (`$jsonSchema`):** Database-level schema documentation and validation stored directly in MongoDB.

---

### Audit Scorecard

| File / Component | Target Structures / Models | Current Status | Labels Present | Labels Missing |
| :--- | :--- | :---: | :---: | :---: |
| **`schemas/analytics.py`** | `DriftMetricOut`, `AlertOut` | ❌ **Unlabelled** | 0 fields (0%) | 11 fields (100%) |
| **`schemas/auth.py`** | `UserOut`, `CaregiverOut`, `TokenOut`, `CaregiverRegisterRequest`, `LoginRequest`, `OtpRequestRequest`, `OtpVerifyRequest`, `OtpRequestResponse`, `OtpVerifyResponse`, `LogoutResponse`, `PatientPairStartOut`, `PatientPairCompleteRequest`, `PatientPairCompleteOut` | ❌ **Unlabelled** | 0 fields (0%) | 42 fields (100%) |
| **`schemas/patient.py`** | `EmergencyContact`, `DeviceStatus`, `PatientSummaryOut`, `PatientDetailOut`, `PatientCreateRequest`, `FamilyMemberCreate`, `FamilyMemberOut`, `CustomReminderCreate`, `CustomReminderOut`, `RemindersOut`, `GameSessionOut` | ⚠️ **Partially Labelled** | 3 fields (~5%) *(only in `FamilyMemberCreate`)* | 55+ fields (~95%) |
| **`schemas/sync.py`** | `GameSessionIn`, `VoiceInteractionIn`, `SyncBatchIn`, `SyncBatchOut` | ❌ **Unlabelled** | 0 fields (0%) | 18 fields (100%) |
| **`models/` (MongoDB Beanie Documents)** | `User`, `DevicePairingToken`, `OtpCode`, `RevokedToken`, `GameSession`, `VoiceInteraction`, `DriftMetric`, `Alert`, `BanditArmState`, `FamilyMember`, `PatientReminder` | ❌ **Unlabelled at Field/DB Level** | Collection names defined via `Settings.name`, but 0 field descriptions or `$jsonSchema` validators | All collections lack MongoDB-native field labels and validation descriptions |

> [!IMPORTANT]
> **Summary Finding:** The vast majority (>97%) of all schema fields and database document structures are **currently unlabelled**. While types and basic types hints exist, they lack `title`, `description`, unit definitions, validation constraints, and examples.
> 
> *The only existing labelled fields in the entire repository are three lines in `schemas/patient.py` under `FamilyMemberCreate`:*
> - `name: str = Field(min_length=1, description="Full name of family member")`
> - `relation: str = Field(min_length=1, description="Relationship to patient")`
> - `photoUrl: str = Field(min_length=1, description="Photo data URI or URL")`

---

## 2. File-by-File Gap Analysis

### 2.1 `src/backend/app/schemas/analytics.py`
- **Models:** `DriftMetricOut`, `AlertOut`
- **Missing Information:**
  - `window_days`: No indication of valid evaluation windows (typically 7 or 30 days).
  - `slope`, `intercept`: No description explaining that this represents the Pillar 3 linear-regression cognitive drift trajectory ($\beta_1$ and $\beta_0$).
  - `r_squared`: No range bounds ($0.0 \le R^2 \le 1.0$) or fit reliability description.
  - `alert_type`, `severity`: No enumerations or descriptions for severity levels (`low`, `medium`, `high`) or alert categories (`cognitive_drift`, `anomaly`).

### 2.2 `src/backend/app/schemas/auth.py`
- **Models:** Authentication, registration, OTP 2FA, and tablet pairing contracts.
- **Missing Information:**
  - `role`: No definition of allowable user personas (`caregiver`, `patient`).
  - `region_language`: Missing language code standard (e.g. ISO 639-1: `bn` for Bengali, `as` for Assamese, `mni` for Meitei).
  - `pairing_token` / `pairing_code`: No format or expiration descriptions.
  - `otp`: Has `min_length=4, max_length=8`, but lacks documentation that it is an ephemeral one-time numeric passcode.

### 2.3 `src/backend/app/schemas/patient.py`
- **Models:** Patient roster, medical profiles, family gallery, reminders, and detailed cognitive session metrics.
- **Missing Information:**
  - `GameSessionOut`: Contains over 25 critical cognitive health metrics (e.g., `correct_match_rate`, `total_flips`, `time_to_first_correct_match`, `words_recalled_count`, `response_latency_per_word`, `reaction_time_avg`, `within_session_drift`). **None of these have units (milliseconds vs. seconds), clinical definitions, or valid ranges.**
  - `statusLabel`: Lacks UI presentation guidelines.
  - `EmergencyContact` & `DeviceStatus`: Sub-schemas have raw keys without descriptive titles.

### 2.4 `src/backend/app/schemas/sync.py`
- **Models:** Edge-to-cloud offline sync telemetry payloads (`GameSessionIn`, `VoiceInteractionIn`, `SyncBatchIn`, `SyncBatchOut`).
- **Missing Information:**
  - `client_session_id`: Missing documentation that this is an idempotency key preventing duplicate records during edge retry syncs.
  - `accuracy`, `error_rate`: Unspecified whether scale is $0.0 - 1.0$ or $0 - 100\%$.
  - `avg_latency_ms`: Unit is indicated only in the field suffix, but no description or bounds are provided.
  - `raw_payload`: Unstructured `Dict[str, Any]` without metadata schema definition.

### 2.5 MongoDB Beanie ODM Documents (`src/backend/app/models/`)
- Documents represent the physical collections in MongoDB:
  - `users`, `device_pairing_tokens`, `otp_codes`, `revoked_tokens`, `game_sessions`, `voice_interactions`, `drift_metrics`, `alerts`, `bandit_arm_state`, `family_members`, `patient_reminders`.
- In MongoDB, collections are created implicitly without `$jsonSchema` title/description metadata. External database tools (MongoDB Compass, MongoDB Atlas, ETL pipelines) cannot infer semantic labels without querying application code.

---

## 3. How to Label the Structures (Without Code Changes)

When you are ready to apply labels, follow the four-tier labelling framework detailed below. **No code has been modified**; this section provides the precise specifications and blueprints for future implementation.

### Tier 1: Pydantic Field Labelling (API & Validation Layer)
Use Pydantic's `Field` constructor with:
- `title`: Short human-readable name.
- `description`: Plain English definition of what the field holds and how it is used.
- `examples`: Realistic values demonstrating format.
- `ge`, `le`, `min_length`, `max_length`: Explicit data bounds.
- `json_schema_extra`: Custom metadata such as physical measurement units or UI tags.

#### Example Pattern:
```python
from pydantic import BaseModel, Field

class SampleMetric(BaseModel):
    reaction_time_avg: float = Field(
        ...,
        title="Average Reaction Time",
        description="Mean response latency across all stimulus trials in the session",
        ge=0.0,
        examples=[412.5],
        json_schema_extra={"unit": "ms", "domain": "attention"}
    )
```

### Tier 2: Beanie MongoDB Document Labelling
Add field-level descriptions to the MongoDB `Document` models in `models/`. This generates self-documenting collections in Beanie and allows automated OpenAPI/Swagger generation directly from database entities.

### Tier 3: MongoDB Native Collection `$jsonSchema` Validation
You can label MongoDB collections directly inside MongoDB without modifying any application code. Run a MongoDB script (via `mongosh` or MongoDB Compass) using the `collMod` command to add `$jsonSchema` titles and field descriptions directly to the database engine.

---

## 4. Complete Reference Blueprints for Labelled Schemas

### 4.1 Fully Labelled Blueprint: `schemas/analytics.py`

```python
"""Analytics and cognitive health monitoring response schemas."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class DriftMetricOut(BaseModel):
    """Snapshot of the Pillar 3 linear-regression cognitive drift trajectory."""

    window_days: int = Field(
        ...,
        title="Evaluation Window",
        description="Rolling observation window duration in days (typically 7 or 30 days)",
        examples=[7, 30],
        ge=1,
    )
    slope: float = Field(
        ...,
        title="Regression Slope (Beta 1)",
        description="Cognitive trajectory slope. Negative values denote performance decline; near-zero denotes stability",
        examples=[-0.042],
    )
    intercept: float = Field(
        ...,
        title="Regression Intercept (Beta 0)",
        description="Baseline performance score estimate at the beginning of the observation window",
        examples=[85.4],
    )
    r_squared: Optional[float] = Field(
        None,
        title="Coefficient of Determination (R²)",
        description="Goodness-of-fit indicator for the linear regression trend (0.0 to 1.0)",
        ge=0.0,
        le=1.0,
        examples=[0.88],
    )
    sample_count: int = Field(
        ...,
        title="Sample Count",
        description="Total number of game sessions analyzed within this observation window",
        ge=1,
        examples=[24],
    )
    computed_at: datetime = Field(
        ...,
        title="Computation Timestamp",
        description="UTC timestamp when the drift regression analysis was computed",
    )

    class Config:
        from_attributes = True



class AlertOut(BaseModel):
    """Clinical or operational alert surfaced to caregiver dashboard."""

    alert_type: str = Field(
        ...,
        title="Alert Type",
        description="Category of alert triggered by anomaly detection or drift monitoring",
        examples=["cognitive_drift", "anomaly", "missed_routine"],
    )
    severity: str = Field(
        ...,
        title="Severity Level",
        description="Triaged priority level of the notification",
        examples=["low", "medium", "high"],
    )
    message: str = Field(
        ...,
        title="Alert Message",
        description="Human-readable notification text displayed on the caregiver portal",
        examples=["Significant decline in memory match speed observed over 7 days."],
    )
    resolved: bool = Field(
        ...,
        title="Resolution Status",
        description="Indicates whether a caregiver has acknowledged and resolved the alert",
        examples=[False],
    )
    created_at: datetime = Field(
        ...,
        title="Creation Timestamp",
        description="UTC timestamp when the alert event was triggered",
    )

    class Config:
        from_attributes = True
```

---

### 4.2 Fully Labelled Blueprint: `schemas/sync.py`

```python
"""Edge device offline synchronization request and response contracts."""

from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class GameSessionIn(BaseModel):
    """Cognitive game performance telemetry synced from edge tablet."""

    client_session_id: str = Field(
        ...,
        title="Client Session ID",
        description="Unique UUID generated by client device acting as an idempotency key to prevent duplicate syncs",
        examples=["550e8400-e29b-41d4-a716-446655440000"],
    )
    game_type: str = Field(
        ...,
        title="Game Type Identifier",
        description="Target cognitive exercise module",
        examples=["pattern_matcher", "pair_matching", "word_association", "visual_search"],
    )
    difficulty_level: str = Field(
        ...,
        title="Difficulty Level",
        description="Active difficulty tier or grid configuration during game play",
        examples=["2x2", "3x2", "1", "2"],
    )
    accuracy: float = Field(
        ...,
        title="Accuracy Rate",
        description="Proportion of correct actions to total actions (normalized 0.0 to 1.0)",
        ge=0.0,
        le=1.0,
        examples=[0.85],
    )
    avg_latency_ms: float = Field(
        ...,
        title="Average Latency",
        description="Average response time per user interaction measured in milliseconds",
        ge=0.0,
        examples=[1250.5],
        json_schema_extra={"unit": "ms"},
    )
    error_rate: float = Field(
        ...,
        title="Error Rate",
        description="Ratio of incorrect responses or omissions (normalized 0.0 to 1.0)",
        ge=0.0,
        le=1.0,
        examples=[0.15],
    )
    client_timestamp: datetime = Field(
        ...,
        title="Local Completion Timestamp",
        description="UTC datetime when the session was completed locally on the tablet",
    )
    raw_payload: Optional[Dict[str, Any]] = Field(
        default=None,
        title="Raw Telemetry Payload",
        description="Detailed interaction trial logs, touches, and timing vectors",
    )


class VoiceInteractionIn(BaseModel):
    """Voice check-in transcript telemetry recorded on edge device."""

    client_session_id: str = Field(
        ...,
        title="Client Interaction ID",
        description="Unique idempotency UUID for the voice exchange",
        examples=["6ba7b810-9dad-11d1-80b4-00c04fd430c8"],
    )
    transcript: Optional[str] = Field(
        default=None,
        title="Speech Transcript",
        description="Recognized text transcribed on-device by edge speech-to-text",
        examples=["আমি ভালো আছি, সকালের চা খেয়েছি"],
    )
    language: Optional[str] = Field(
        default="bn",
        title="Language Code",
        description="BCP-47 or ISO-639-1 language identifier",
        examples=["bn", "as", "mni", "en"],
    )
    client_timestamp: datetime = Field(
        ...,
        title="Local Timestamp",
        description="UTC datetime when the voice check-in occurred",
    )


class SyncBatchIn(BaseModel):
    """Batched payload bundle submitted by edge device after network restoration."""

    game_sessions: List[GameSessionIn] = Field(
        default_factory=list,
        title="Game Sessions",
        description="Array of queued game sessions recorded while offline",
    )
    voice_interactions: List[VoiceInteractionIn] = Field(
        default_factory=list,
        title="Voice Interactions",
        description="Array of queued voice interactions recorded while offline",
    )


class SyncBatchOut(BaseModel):
    """Server synchronization acknowledgment and ingestion summary."""

    accepted_game_sessions: int = Field(
        ...,
        title="Accepted Game Sessions",
        description="Count of new game sessions successfully ingested and indexed into MongoDB",
        ge=0,
        examples=[3],
    )
    accepted_voice_interactions: int = Field(
        ...,
        title="Accepted Voice Interactions",
        description="Count of new voice transcripts ingested and queued for NLU analysis",
        ge=0,
        examples=[1],
    )
    alerts_triggered: int = Field(
        ...,
        title="Alerts Triggered",
        description="Number of clinical drift or anomaly alerts generated as a result of this sync batch",
        ge=0,
        examples=[0],
    )
```

---

### 4.3 Fully Labelled Blueprint: `schemas/patient.py`

```python
"""Patient demographic, medical profile, reminder, and game session schemas."""

from typing import Any, Dict, List, Optional, Union
from pydantic import BaseModel, Field


class EmergencyContact(BaseModel):
    """Primary contact details for patient emergency situations."""

    name: str = Field(
        ...,
        title="Contact Full Name",
        description="Full name of primary family member or caregiver contact",
        examples=["Ananya Banerjee"],
    )
    relationship: str = Field(
        ...,
        title="Relationship to Patient",
        description="Family or professional relationship to patient",
        examples=["Daughter", "Son", "Primary Caregiver"],
    )
    phone: str = Field(
        ...,
        title="Phone Number",
        description="Direct telephone contact number including country code if applicable",
        examples=["+91 98765 43210"],
    )


class DeviceStatus(BaseModel):
    """Hardware pairing status and sync diagnostics of the patient's tablet."""

    linked: bool = Field(
        default=True,
        title="Pairing Link Status",
        description="True if a hardware tablet device is currently bonded to this patient profile",
    )
    deviceName: Optional[str] = Field(
        default=None,
        title="Device Hardware Name",
        description="Model or friendly identifier of the patient tablet",
        examples=["Samsung Galaxy Tab A8"],
    )
    deviceId: Optional[str] = Field(
        default=None,
        title="Hardware Device UUID",
        description="Unique hardware fingerprint or installation UUID of the patient app",
        examples=["dev_tab_982341"],
    )
    lastSynced: Optional[str] = Field(
        default=None,
        title="Last Sync Timestamp",
        description="ISO 8601 string of the most recent sync handshake with the backend",
        examples=["2026-09-12T14:30:00Z"],
    )


class PatientSummaryOut(BaseModel):
    """Concise patient summary card for the caregiver roster view."""

    id: str = Field(..., title="Patient ID", description="Unique identifier for patient profile", examples=["p101"])
    name: str = Field(..., title="Patient Full Name", description="Full legal or preferred name", examples=["Debabrata Sen"])
    age: Optional[int] = Field(None, title="Age", description="Patient age in years", ge=0, le=130, examples=[74])
    diagnosis: Optional[str] = Field(None, title="Medical Diagnosis", description="Clinical diagnosis classification", examples=["Mild Cognitive Impairment (MCI)"])
    avatarUrl: Optional[str] = Field(None, title="Avatar Image URL", description="URI pointing to patient profile picture")
    status: str = Field(default="stable", title="Health Status Tag", description="Current clinical evaluation status (stable, attention, critical)", examples=["stable"])
    statusLabel: str = Field(default="Active • Tablet synced", title="UI Status Badge", description="Human-readable status label for display in UI")
    lastCheckIn: Optional[str] = Field(None, title="Last Interaction", description="Readable time elapsed since last patient engagement", examples=["2 hours ago"])
    pairingToken: Optional[str] = Field(None, title="Active Pairing Token", description="One-time pairing code if tablet pairing is currently pending")


class GameSessionOut(BaseModel):
    """Comprehensive cognitive evaluation metrics from a completed game round."""

    session_id: str = Field(..., title="Session UUID", description="Unique session identifier")
    patient_profile_id: str = Field(..., title="Patient Profile ID", description="ID of patient who completed the session", examples=["p101"])
    game_type: str = Field(..., title="Game Identifier", description="Specific game module played", examples=["pair_matching", "word_association", "visual_search"])
    domain: str = Field(..., title="Cognitive Domain", description="Primary cognitive function targeted", examples=["memory", "language", "attention"])
    session_date: str = Field(..., title="Session Date", description="Date string when the session took place", examples=["2026-09-12"])
    session_duration: int = Field(..., title="Session Duration", description="Total elapsed playing time in seconds", ge=0, examples=[185], json_schema_extra={"unit": "seconds"})
    status: str = Field(default="completed", title="Completion Status", description="Whether game was completed or abandoned", examples=["completed", "abandoned"])
    difficulty_level: Union[int, str] = Field(default=1, title="Difficulty Tier", description="Difficulty configuration level", examples=[1, "3x2"])
    score_normalized: float = Field(..., title="Normalized Score", description="Adjusted score scaled between 0.0 and 100.0 based on difficulty algorithm", ge=0.0, le=100.0, examples=[82.5])

    # Domain 1: Memory (Pair Matching)
    correct_match_rate: Optional[float] = Field(None, title="Correct Match Rate", description="Ratio of successful pairs found per card flip attempt (0.0 to 1.0)", ge=0.0, le=1.0)
    total_flips: Optional[int] = Field(None, title="Total Card Flips", description="Total individual card flip interactions during the round", ge=0)
    time_to_first_correct_match: Optional[float] = Field(None, title="Latency to First Match", description="Elapsed time in seconds before discovering the first matching pair", ge=0.0, json_schema_extra={"unit": "seconds"})
    repeat_error_rate: Optional[float] = Field(None, title="Perseverative Error Rate", description="Frequency of re-flipping previously revealed non-matching cards", ge=0.0, le=1.0)
    completion_time: Optional[int] = Field(None, title="Board Completion Time", description="Total time taken to clear the board in seconds", ge=0)
    pairs_count: Optional[int] = Field(None, title="Total Pairs Count", description="Number of matching pairs on the game board", ge=1)
    used_face_name_variant: Optional[bool] = Field(None, title="Face-Name Variant Used", description="True if patient's family photos were used instead of generic icons")

    # Domain 2: Language (Word Association)
    words_recalled_count: Optional[int] = Field(None, title="Recalled Words Count", description="Total valid verbal or typed responses provided", ge=0)
    response_latency_per_word: Optional[List[float]] = Field(None, title="Per-Word Latencies", description="Array of response delays in seconds for each recalled item", json_schema_extra={"unit": "seconds"})
    category_switch_errors: Optional[int] = Field(None, title="Category Switch Errors", description="Number of out-of-category or perseverative language errors", ge=0)
    language_used: Optional[str] = Field(None, title="Language Used", description="Language used for verbal or text prompt", examples=["bn", "en"])
    category_prompt: Optional[str] = Field(None, title="Prompt Category", description="Stimulus category presented to patient", examples=["Fruits", "Animals", "Household Items"])
    round_duration: Optional[int] = Field(None, title="Round Duration Limit", description="Configured countdown duration for the round in seconds")

    # Domain 3: Attention (Visual Search)
    reaction_time_avg: Optional[int] = Field(None, title="Average Target Reaction Time", description="Mean millisecond reaction time when selecting valid targets", ge=0, json_schema_extra={"unit": "ms"})
    reaction_time_variability: Optional[int] = Field(None, title="Reaction Time Variance", description="Standard deviation of reaction times across trials (measure of attention stability)", ge=0, json_schema_extra={"unit": "ms"})
    omission_rate: Optional[float] = Field(None, title="Omission Error Rate", description="Rate of target stimuli missed without a response (0.0 to 1.0)", ge=0.0, le=1.0)
    false_positive_rate: Optional[float] = Field(None, title="False Positive Rate", description="Rate of selecting distractors instead of true targets (0.0 to 1.0)", ge=0.0, le=1.0)
    within_session_drift: Optional[float] = Field(None, title="Intra-Session Vigilance Drift", description="Fatigue indicator: slope of latency degradation from start to end of session")
    trial_count: Optional[int] = Field(None, title="Total Trials Count", description="Number of stimulus presentations in the visual search session", ge=1)

    raw_trials: Optional[List[Dict[str, Any]]] = Field(default_factory=list, title="Raw Trial Records", description="Granular trial-by-trial logs with coordinate and timing metadata")
```

---

## 5. Database-Native Labelling: MongoDB `$jsonSchema` Script

To label and document the structure inside MongoDB itself (without altering any Python code files), execute the following script in `mongosh` or MongoDB Compass. This attaches `$jsonSchema` titles and descriptions directly to the MongoDB collections:

```javascript
// mongosh script to apply field labels and descriptions to collections
use cognitive_assist;

// 1. Label the 'game_sessions' collection
db.runCommand({
  collMod: "game_sessions",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      title: "Game Sessions Collection",
      description: "Pillar 1 and Pillar 3 cognitive health game performance telemetry store",
      required: ["patient_id", "client_session_id", "game_type"],
      properties: {
        _id: {
          bsonType: "binData",
          description: "Binary UUID unique identifier"
        },
        patient_id: {
          description: "Target patient UUID referencing the users collection"
        },
        client_session_id: {
          bsonType: "string",
          description: "Unique idempotency key generated by edge tablet"
        },
        game_type: {
          enum: ["pattern_matcher", "pair_matching", "word_association", "visual_search"],
          description: "Cognitive game module type"
        },
        accuracy: {
          bsonType: "double",
          minimum: 0.0,
          maximum: 1.0,
          description: "Performance accuracy ratio between 0.0 and 1.0"
        },
        avg_latency_ms: {
          bsonType: "double",
          minimum: 0.0,
          description: "Average response latency in milliseconds"
        },
        error_rate: {
          bsonType: "double",
          minimum: 0.0,
          maximum: 1.0,
          description: "Error rate between 0.0 and 1.0"
        },
        client_timestamp: {
          bsonType: "date",
          description: "Timestamp when the session was played on the tablet"
        },
        synced_at: {
          bsonType: "date",
          description: "Server ingestion timestamp"
        }
      }
    }
  },
  validationLevel: "moderate"
});

// 2. Label the 'drift_metrics' collection
db.runCommand({
  collMod: "drift_metrics",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      title: "Drift Metrics Collection",
      description: "Pillar 3 longitudinal linear-regression cognitive drift trends",
      required: ["patient_id", "window_days", "slope", "intercept"],
      properties: {
        patient_id: {
          description: "Target patient UUID"
        },
        window_days: {
          bsonType: "int",
          description: "Evaluation window in days (e.g. 7 or 30)"
        },
        slope: {
          bsonType: "double",
          description: "Beta 1 regression slope of performance over time"
        },
        intercept: {
          bsonType: "double",
          description: "Beta 0 regression baseline intercept"
        },
        r_squared: {
          bsonType: ["double", "null"],
          minimum: 0.0,
          maximum: 1.0,
          description: "R² goodness of fit score"
        },
        computed_at: {
          bsonType: "date",
          description: "Calculation timestamp"
        }
      }
    }
  },
  validationLevel: "moderate"
});
```

---

## 6. Verification and Inspection Checklist

Once you choose to apply the schema labels to the codebase or database:

1. **FastAPI Swagger / OpenAPI Verification:**
   - Start the backend server (`uvicorn app.main:app --reload`).
   - Navigate to `http://localhost:8000/docs` (Swagger UI) or `http://localhost:8000/redoc`.
   - Verify that every request and response schema displays human-readable parameter titles, descriptive summaries, and unit tags.
2. **MongoDB Compass Data Dictionary Verification:**
   - Open MongoDB Compass and select the `cognitive_assist` database.
   - Click on the **Validation** tab for any collection (e.g. `game_sessions`).
   - Verify that the `$jsonSchema` definition renders with all field titles, descriptions, and types.
3. **Beanie ODM Compatibility:**
   - Because Beanie is built on Pydantic, adding `Field(title=..., description=...)` does not alter runtime queries, index creation, or document serialization. It remains 100% backward-compatible.
