# AGENTS.md — Patient App (Flutter + Dart)

Read `../../docs/BRAND_GUIDELINES.md` in full before writing any UI. This file adds
rules specific to this app's structure, constraints, and pages.

App name: **Smriti Kunj**. Use it wherever a product name is contextually appropriate
(splash screen, headers, about text).

---

## 1. Design tokens
- Use ONLY colors/styles defined in `lib/theme/theme.dart` (`AppColors.*`, `patientTheme`)
  — never hardcode a `Color(0xFF...)` directly in a widget, never use inline `TextStyle`
  overrides for brand colors/fonts. If a needed value isn't in `theme.dart`, STOP and ask
  instead of inventing or approximating one.
- `AppColors.alertRed` is reserved for SOS/emergency states ONLY — never reuse for
  destructive actions, warnings, or decoration.
- Fonts: `NotoSans` with Bengali/Devanagari fallback, as configured in `patientTheme` —
  do not introduce other fonts.
- **No dark mode on this app** (unlike the caregiver dashboard) — this is a deliberate
  accessibility decision, not an oversight. Do not add theme-switching logic here.

## 2. Accessibility constraints — NON-NEGOTIABLE
This app is used by elderly patients, many with cognitive impairment. These are hard
rules, not guidelines:
- **Minimum touch target: 88dp** (already encoded in `patientTheme`'s `ElevatedButtonThemeData`
  — `minimumSize: Size(double.infinity, 88)`). Any new interactive element (buttons, icons,
  tappable cards) must meet or exceed this.
- **Minimum text size: 18px** (`bodyMedium` in the text theme is the floor — never go smaller
  for any user-facing text, including captions/labels).
- **One primary decision per screen** — never present multiple competing actions/choices
  on a single screen. If a screen needs more than one action, make one visually dominant
  and clearly primary.
- **Recognition over recall** — use icons + labels together, not icon-only or text-only.
  Never rely on the user remembering a prior screen's state or instructions.
- **No time pressure by default** — avoid auto-advancing screens, disappearing content, or
  countdown timers outside of the games themselves (where timing is the mechanic).
- **Generous spacing** — err on the side of more whitespace between interactive elements
  to prevent mis-taps.

## 3. State management
- Use **Provider** for all shared/app-level state (current patient session, game progress,
  reminder data). Don't introduce Riverpod, Bloc, or GetX — consistency matters more than
  any one being "better" for a hackathon timeline.
- Local widget-only state (e.g. a single screen's temporary UI state) can use plain
  `setState` — don't over-engineer trivial cases into Provider.

## 4. Backend integration
- Never call an API directly from a widget. Route everything through `lib/services/api_service.dart`.
- No real backend exists yet for most patient-side features. Every new backend interaction:
  1. Gets a named stub function in `api_service.dart` (e.g. `submitGameSession()`,
     `fetchReminders()`) returning realistic mock data matching the schema in
     `docs/GAMES_ANALYTICS_README.md` where applicable
  2. Gets logged in `../../docs/API_ENDPOINTS_NEEDED.md` (method, calling screen, purpose,
     request/response shape)
  3. Gets a `// BACKEND-TODO: see ../../docs/API_ENDPOINTS_NEEDED.md` comment at the stub
- Game session data MUST follow the shared schema fields defined in
  `docs/GAMES_ANALYTICS_README.md` exactly (field names/types) — this is what the caregiver
  Analytics page consumes, so drift here breaks that integration silently.

## 5. App structure
| Screen | Purpose |
|---|---|
| Home | Simple, calm landing screen — large icons for: Games, Reminders, Family/Memories, SOS |
| Game screens (x3) | One per game in `docs/GAMES_ANALYTICS_README.md` — Pair Matching, Word Association, Visual Search |
| Reminders | Read-only display of today's reminders (caregiver sets these via the dashboard) with a simple "mark done" action |
| Family/Memories | View photos and play familiar sounds uploaded by the caregiver |
| SOS | Always accessible (persistent button or prominent home tile) — triggers an alert, no confirmation friction |

## 6. Component organization
- `lib/screens/` — one file per screen above
- `lib/widgets/` — shared reusable pieces (BigActionButton, GameCard, ReminderTile)
- `lib/services/` — `api_service.dart`, `game_session_service.dart`
- `lib/models/` — data models matching backend/mock shapes (Reminder, FamilyMember, GameSession)
- `lib/theme/theme.dart` — source of truth, already established

## 7. Rules to keep the UI from breaking
- Every screen needs loading and error states — no blank screens, no silent failures.
- Test with a very long name/label (family member names, reminder text) — text must wrap
  or truncate gracefully, never overflow.
- Test on at least two device sizes (small phone, larger tablet) — this app may run on
  tablets per the hardware pairing model.
- Games must handle being backgrounded/interrupted (e.g. a call comes in) without losing
  session data ungracefully — save progress incrementally where feasible.

## 8. Scope Discipline
- Only create or modify files explicitly listed in the current task/prompt.
- Never refactor, restyle, or "improve" existing files outside the stated task — flag it
  as a suggestion instead.
- If a task seems to require touching a file outside the stated scope, STOP and ask first.

## Standing Assumptions (don't restate these per-task)
- Always verify against the 88dp touch target / 18px text floor — no need to ask per prompt.
- Always use existing theme.dart tokens — already covered above.
- Only touch files relevant to the current task.