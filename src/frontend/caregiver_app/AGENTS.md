# AGENTS.md — Caregiver App (React + Tailwind)

Read `../../docs/BRAND_GUIDELINES.md` in full before writing any UI. This file adds
rules specific to this app's structure and pages.

---

## 1. Design tokens
- Use only tokens defined in `tailwind.config.js` (`bg-terracotta`, `text-ink`, `bg-alert`, etc.)
- Never use arbitrary values (`bg-[#123456]`) or inline `style={{ color: ... }}` for brand colors/typography
- `alert` (`#C1272D`) is reserved for the patient app's SOS state — do not reuse it for
  destructive/delete actions here; use a distinct red variant for those or a plain
  neutral + icon insteadGraphs + history for the selected patient
- This app is NOT under the patient app's dementia-accessibility constraints (no 18px
  floor, no 88dp touch targets required) — use standard modern dashboard density and
  the normal Tailwind type scale
- Dark mode is allowed here (unlike the patient app) — if added, implement via Tailwind's
  `dark:` variant, not a separate theme file

## 2. Backend integration
- Never call an API directly from a component. Route everything through `src/services/api.js`
- No real backend exists yet. Every new backend interaction:
  1. Gets a named stub function in `api.js` (e.g. `fetchPatientSummary()`, `saveReminder()`)
     returning realistic mock data
  2. Gets logged in `../../docs/API_ENDPOINTS_NEEDED.md` (method, calling page, purpose, request/response shape)
  3. Gets a `// BACKEND-TODO: see ../../docs/API_ENDPOINTS_NEEDED.md` comment at the stub
- Never invent a "final" contract — these are proposals, not commitments, until the backend team reviews them

## 3. App structure — three pages

| Route | Page | Purpose |
|---|---|---|
| `/` | Home / Dashboard | Patient overview — see multi-patient rule below |
| `/analytics` | Analytics | Graphs + history for the selected patient |
| `/customization` | Customization | Reminders, contacts, emergency numbers |

**Multi-patient rule (important — this is the actual data model):** one caregiver can
manage multiple patients (`caregiverId` → many `patientProfileId`s). The Home page is
NOT a single-patient page — it needs a patient switcher/selector at the top (dropdown
or tab strip), and every page (`Home`, `Analytics`, `Customization`) reflects whichever
patient is currently selected. Build this selector first, before any patient-detail UI,
so nothing gets hardcoded to "the one patient."

- **Home:** patient switcher + summary cards (recent activity, upcoming reminders, last
  check-in, SOS/alert status if any triggered)
- **Analytics:** chart(s) of activity/mood/exercise trends over time + a history table/list
  below. Use `recharts` for charts, wrapped in `ResponsiveContainer` — never a fixed pixel
  height on the chart's parent div
- **Customization:** forms for reminders (CRUD), contacts (CRUD), emergency numbers —
  every form needs validation state and a disabled/loading state on its submit button

## 4. Component organization
- `src/components/` — shared, reusable pieces (PatientSwitcher, StatCard, NavSidebar,
  ChartWrapper, ReminderForm, ContactCard)
- `src/pages/` — one file per route above, composed from `src/components/`
- Don't build one-off inline JSX blocks inside a page for something reusable — extract
  to `src/components/` if it appears more than once (e.g. a card style used on both
  Home and Analytics)

## 5. "Modern" look — concrete rules, not vibes
- Generous whitespace, soft shadows (`shadow-sm`/`shadow-md`), rounded corners (`rounded-card`
  per config), avoid dense/cluttered stacking of information
- Consistent grid: use Tailwind's `grid`/`flex` utilities, not fixed pixel layouts
- Icons: use `lucide-react` consistently — don't mix icon styles/sources across pages
- Consider `shadcn/ui` primitives (buttons, dropdowns, cards) for consistent, modern
  component behavior rather than hand-rolling each one differently per page

## 6. Rules to keep the UI from breaking
- **Never use fixed pixel widths** for page containers — use `w-full`, `max-w-*`, `flex`, `grid`
- **Every data-fetching page needs three states, always:** loading (skeleton, not a blank
  screen), empty (e.g. "No reminders yet — add one" not a blank list), and error
  (a real message, not a silent failure)
- **Test every list/card with:** exactly 1 patient, 6+ patients, a patient name 30+
  characters long, and a patient with zero history/analytics data yet
- **Truncate or wrap long text** (`truncate`, `line-clamp-*`) on names/labels — never let
  text overflow a card and break the layout
- **Charts must be responsive** — verify they don't collapse to 0 height or overflow their
  container on window resize or on mobile widths
- **Mobile-first breakpoints** (`sm`/`md`/`lg`) — a caregiver may check this dashboard on
  a phone, not just desktop

## 7. Merge checklist (in addition to the shared one in BRAND_GUIDELINES.md)
- [ ] Patient switcher works and every page respects the selected patient
- [ ] Tested with 1 patient and with many patients
- [ ] Tested with an empty state (new caregiver, no data yet)
- [ ] Charts responsive — checked at mobile width
- [ ] All new backend calls routed through `src/services/api.js` and logged in
      `../../docs/API_ENDPOINTS_NEEDED.md`

## Scope Discipline
- Only create or modify files explicitly listed in the current task/prompt.
- Never refactor, restyle, or "improve" existing files that weren't part of the stated task, even if you notice something that could be better — flag it as a suggestion instead.
- If a task seems to require touching a file outside the stated scope, STOP and ask before proceeding.

## Standing Assumptions (don't restate these per-task)
- Always verify light/dark mode correctness — no need to ask for this per prompt.
- Always use existing design tokens/patterns — already covered above.
- Only touch files relevant to the current task.
