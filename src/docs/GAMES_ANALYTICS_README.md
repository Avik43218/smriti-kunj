# Smriti Kunj — Patient-Side Games & Analytics Reference

This document defines the 3 initial games for the patient-facing Flutter app, the cognitive domains they target, and the analytics parameters each game generates. Use this as the source of truth when building the caregiver dashboard Analytics page (`/patients/:id/analytics`) and when defining the game session JSON schema in `api.js` / `api_service.dart`.

---

## Why these 3 games (scope rationale)

Starting with 3 games covers 3 distinct cognitive domains without overcommitting the build timeline. Each was chosen for:
1. Evidence backing (research-supported effect on the target domain)
2. Ease of localization (Assamese / Bengali / Bodo)
3. Feasibility to build and instrument cleanly in Flutter for a hackathon timeline

Executive function and orientation games are deferred to a later phase — the schema below is written to be domain-agnostic so adding them later won't require restructuring.

---

## Game 1: Pair Matching (Memory Recall)

**Cognitive domain:** Episodic memory

**Concept:** Classic card-flip matching game. Variant: face-name matching using caregiver-uploaded family photos instead of generic icons/cards, for personal relevance and higher engagement.

**Difficulty scaling:** Number of pairs (e.g., 4 → 6 → 8 pairs), grid size, time limit (optional).

### Analytics parameters

| Parameter | Type | Description |
|---|---|---|
| `total_flips` | int | Total card flips taken to complete the round |
| `correct_match_rate` | float (0–1) | Correct matches / total match attempts |
| `time_to_first_correct_match` | seconds | Latency to first successful pair |
| `repeat_error_rate` | float (0–1) | Same pair missed 2+ times — signals encoding failure, not just slow recall |
| `completion_time` | seconds | Total time to finish the round |
| `pairs_count` | int | Difficulty setting used (e.g., 4, 6, 8) |
| `used_face_name_variant` | bool | Whether personal photos were used vs. generic cards |

---

## Game 2: Word Association (Language / Semantic Memory)

**Cognitive domain:** Language and semantic memory

**Concept:** Patient is given a category (e.g., "fruits," "things in a kitchen") and asked to name as many items as possible within a time window (e.g., 60 seconds). Regionalized to Assamese, Bengali, and Bodo vocabulary and categories relevant to Northeast India daily life.

**Difficulty scaling:** Category familiarity/breadth, time window, number of rounds.

### Analytics parameters

| Parameter | Type | Description |
|---|---|---|
| `words_recalled_count` | int | Number of valid words given per category per round |
| `response_latency_per_word` | array[seconds] | Time between each word — flags slowing recall |
| `category_switch_errors` | int | Perseveration — repeating a category or already-said word; an early clinical marker |
| `language_used` | enum | `assamese` \| `bengali` \| `bodo` \| `mizo` \| `khasi` \| `garo` (secondary set) |
| `category_prompt` | string | The category given for that round |
| `round_duration` | seconds | Time window allotted |

---

## Game 3: Visual Search / Reaction-Time Tap (Attention & Processing Speed)

**Cognitive domain:** Attention and processing speed

**Concept:** Patient taps a target item (e.g., "tap the red circle" or "find the odd one out") as it appears among distractors. Simple to build, clean timestamp-based data, low Flutter complexity.

**Difficulty scaling:** Number of distractors, target-appearance interval, visual similarity between target and distractors.

### Analytics parameters

| Parameter | Type | Description |
|---|---|---|
| `reaction_time_avg` | ms | Average time to tap correct target |
| `reaction_time_variability` | ms (std dev) | Often a better early-decline signal than raw average speed |
| `omission_rate` | float (0–1) | Missed targets / total targets shown |
| `false_positive_rate` | float (0–1) | Incorrect taps / total taps |
| `within_session_drift` | float | Performance change from early trials to late trials in the same session — flags fatigue vs. genuine impairment |
| `trial_count` | int | Total number of targets shown in the session |

---

## Shared fields (every game session, all 3 games)

These feed the caregiver dashboard trend lines and should be part of every session record regardless of game type.

| Field | Type | Description |
|---|---|---|
| `session_id` | string | Unique session identifier |
| `patient_profile_id` | string | Links to patient record |
| `game_type` | enum | `pair_matching` \| `word_association` \| `visual_search` |
| `domain` | enum | `memory` \| `language` \| `attention` |
| `session_date` | datetime | When the session occurred |
| `session_duration` | seconds | Total time spent in the game |
| `status` | enum | `completed` \| `abandoned` |
| `difficulty_level` | int/enum | Difficulty at time of play |
| `score_normalized` | float | Score relative to the patient's own rolling baseline (not population norms) |
| `raw_trials` | array[object] | Per-flip / per-word / per-tap event log, for ML-side derived stats later |

---

## Caregiver Dashboard — Analytics Page Recommendations

For `/patients/:id/analytics`, prioritize:

1. **Per-domain trend lines** (memory, language, attention) over time — primary visual, likely a multi-line time series chart
2. **Baseline comparison** — patient's own rolling average, not population norms
3. **Anomaly/flag surfacing** — e.g., a session where reaction-time variability spiked, rather than showing raw session-by-session noise
4. **Session history table** — secondary, more detailed drill-down view

---

## Evidence basis (for documentation / SIH pitch, not implementation)

- Serious games show a modest but real positive effect on cognitive function in dementia patients (pooled effect size 0.34) and also reduce depression.
- Serious games specifically improve attention in cognitively impaired older adults, outperforming both passive intervention and some traditional cognitive training.
- Serious games enhance nonverbal learning better than no-intervention controls.
- Crossword/word-based activities have some of the strongest long-term evidence — one long-running study found word puzzle participation delayed onset of accelerated memory decline by over 2 years; a newer trial found crosswords outperformed computer brain-training games specifically for MCI patients.
- Effects are real but modest — a more recent analysis found brain games weren't more effective than control interventions on some measures. Position this as a support tool, not a treatment, in any documentation.

---

*Last updated: for use alongside PROJECT_BRIEF.md and AGENTS.md context files.*
