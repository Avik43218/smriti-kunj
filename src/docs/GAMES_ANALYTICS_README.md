# Smriti Kunj — Patient-Side Games & Analytics Reference

This document defines the 4 initial games for the patient-facing Flutter app, the cognitive domains they target, and the analytics parameters each game generates. Use this as the source of truth when building the caregiver dashboard Analytics page (`/patients/:id/analytics`) and when defining the game session JSON schema in `api.js` / `api_service.dart`.

---

## Why these 4 games (scope rationale)

4 games covering 4 distinct cognitive domains, each independently evidence-backed rather than variations on the same underlying task. Each was chosen for:
1. Evidence backing (research-supported effect on the target domain)
2. Ease of cultural/regional localization (Assamese / Bengali / Bodo, regional imagery)
3. Feasibility to build and instrument cleanly in Flutter for a hackathon timeline

Games section (Executive function, orientation) beyond these 4 is deferred — schema is written domain-agnostic so adding more later won't require restructuring.

---

## Game 1: The Market Trip (Working Memory & Delayed Recall)

**Cognitive domain:** Working memory / delayed recall

**Concept:** Audio prompt lists items to buy, in the patient's native language (e.g., "Today we need bamboo shoots, ginger, and mustard oil"). A brief unrelated distractor task follows (e.g., a 10-second tap/watering interaction). Patient is then shown a set of visual item cards and selects the ones that were on the list.

**Dynamic difficulty:**
- **Easy:** 2 items, instant recall (no distractor), visually distinct item cards
- **Medium:** 3–4 items, short distractor delay, some visually similar distractors
- **Hard:** 6–8 items, longer distractor delay, visually/semantically similar decoy items
- Adaptation driver: recall accuracy over the last N sessions — item count and delay scale up after consistent high accuracy, scale down after repeated false selections

### Analytics parameters

| Parameter | Type | Description |
|---|---|---|
| `items_prompted_count` | int | Number of items in the prompt list |
| `items_recalled_correct` | int | Correctly selected items |
| `recall_accuracy` | float (0–1) | Correct selections / items prompted |
| `false_selection_count` | int | Items selected that were never prompted (intrusion errors) |
| `time_to_complete_recall` | seconds | Time from recall phase start to submission |
| `distractor_task_completed` | bool | Whether the distractor step was engaged with |
| `delay_duration` | seconds | Time between end of prompt and start of recall phase |
| `prompt_language` | enum | `assamese` \| `bengali` \| `bodo` \| `mizo` \| `khasi` \| `garo` |

---

## Game 2: Pair Matching (Episodic Memory)

**Cognitive domain:** Episodic memory

**Concept:** Classic card-flip matching game. Variant: face-name matching using caregiver-uploaded family photos instead of generic icons, for personal relevance and higher engagement.

**Dynamic difficulty:**
- Pair count scales (e.g., 4 → 6 → 8 pairs) and grid size increases based on rolling `correct_match_rate`
- `repeat_error_rate` spikes trigger a temporary difficulty step-down rather than an immediate step-up, to avoid compounding frustration

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

## Game 3: Family & Village Object Finder (Semantic Memory / Recognition)

**Cognitive domain:** Semantic memory, object/face recognition

**Concept:** Caregiver uploads 4–5 photos of close family members and household/cultural items (spectacles, tea flask, keys, traditional Japi). App presents 3 photos and asks e.g. "Which one is your grandson Rohan?" or "Where did you leave your reading glasses?"

**Dynamic difficulty:**
- Number of options shown scales (2 → 3 → 4) as accuracy improves
- Visual similarity between the correct answer and distractors increases at higher levels
- Adjusts presentation frequency of a specific person/object based on error rate for that specific item — if a specific relative is consistently misidentified, frequency for that item increases (for reinforcement) and the caregiver dashboard is flagged for a potential face-recognition (prosopagnosia) drift

### Analytics parameters

| Parameter | Type | Description |
|---|---|---|
| `total_prompts` | int | Number of identification prompts in the session |
| `correct_identifications` | int | Correct selections |
| `identification_accuracy` | float (0–1) | Correct / total prompts |
| `repeat_misidentification_flag` | bool | Same specific person/object misidentified 2+ times across recent sessions |
| `misidentified_target_id` | string \| null | ID of the specific person/object repeatedly missed, if flagged |
| `avg_response_time` | seconds | Average time to respond per prompt |
| `prompt_type` | enum | `family_member` \| `household_item` |
| `options_shown_count` | int | Difficulty setting — number of photo options presented |

---

## Game 4: Tap the Target (Attention & Processing Speed)

**Cognitive domain:** Attention, processing speed, response inhibition

**Concept:** Patient taps a designated target (customizable to something culturally relevant, e.g. a specific fruit or object) as it appears among visually similar distractors. No visible timer or speed pressure shown to the patient — reaction time is captured silently.

**Dynamic difficulty:**
- Number of distractors and their visual similarity to the target increase with performance
- Target-appearance interval shortens gradually based on rolling `reaction_time_avg`
- A rise in `omission_rate` or `false_positive_rate` triggers a difficulty step-down before a step-up is considered, prioritizing avoiding frustration over pure progression

### Analytics parameters

| Parameter | Type | Description |
|---|---|---|
| `reaction_time_avg` | ms | Average time to tap correct target |
| `reaction_time_variability` | ms (std dev) | Often a better early-decline signal than raw average speed |
| `omission_rate` | float (0–1) | Missed targets / total targets shown |
| `false_positive_rate` | float (0–1) | Incorrect taps / total taps |
| `within_session_drift` | float | Performance change from early to late trials in the same session — flags fatigue vs. genuine impairment |
| `trial_count` | int | Total number of targets shown in the session |
| `target_item_type` | string | The culturally-customized target used for that session (e.g. `japi`, `orange`, `bamboo_hat`) |

---

## Shared fields (every game session, all 4 games)

These feed the caregiver dashboard trend lines and should be part of every session record regardless of game type.

| Field | Type | Description |
|---|---|---|
| `session_id` | string | Unique session identifier |
| `patient_profile_id` | string | Links to patient record |
| `game_type` | enum | `market_trip` \| `pair_matching` \| `object_recognition` \| `visual_search` |
| `domain` | enum | `working_memory` \| `episodic_memory` \| `semantic_memory` \| `attention` |
| `session_date` | datetime | When the session occurred |
| `session_duration` | seconds | Total time spent in the game |
| `status` | enum | `completed` \| `abandoned` |
| `difficulty_level` | int/enum | Difficulty at time of play |
| `score_normalized` | float | Score relative to the patient's own rolling baseline (not population norms) |
| `raw_trials` | array[object] | Per-selection / per-flip / per-prompt / per-tap event log, for ML-side derived stats later |

---

## Caregiver Dashboard — Analytics Page Recommendations

For `/patients/:id/analytics`, prioritize:

1. **Per-domain trend lines** (working memory, episodic memory, semantic memory, attention) over time — primary visual, 4-card grid of individual time-series charts (2x2 on desktop, stacked on mobile)
2. **Baseline comparison** — patient's own rolling average, not population norms
3. **Anomaly/flag surfacing** — e.g. a `repeat_misidentification_flag` or a reaction-time-variability spike, surfaced distinctly rather than buried in raw session noise
4. **Session history table** — secondary, more detailed drill-down view across all 4 game types

---

## Evidence basis (for documentation / SIH pitch, not implementation)

- Serious games show a modest but real positive effect on cognitive function in dementia patients (pooled effect size 0.34) and also reduce depression.
- Serious games specifically improve attention in cognitively impaired older adults, outperforming both passive intervention and some traditional cognitive training.
- Personalized/personal-photo-based recognition tasks show measurably higher engagement and better recall detail than generic-image equivalents in dementia populations.
- Go/No-Go and visual search-type attention tasks reliably track cognitive decline severity (commission errors, reaction-time variability) across unimpaired, MCI, and early-AD groups.
- Crossword/word-based activities have some of the strongest long-term evidence in the literature generally — worth noting as a limitation/comparison point, not a reason to avoid game-based approaches.
- Effects are real but modest — position this as a support and monitoring tool, not a treatment, in any documentation.

---

*Last updated: reflects the 4 finalized patient-side games (Market Trip, Pair Matching, Family & Village Object Finder, Tap the Target), replacing the earlier 3-game draft. For use alongside PROJECT_BRIEF.md and AGENTS.md context files.*
