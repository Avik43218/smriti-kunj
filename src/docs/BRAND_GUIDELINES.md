# Brand & Design Guidelines
**Status:** v0.1 — Aug 27, 2026
**Applies to:** Patient app (Flutter) + Caregiver app (React/Tailwind)

This is the single source of truth for how the product looks and feels. It exists so the visual system stays identical **no matter who writes the code** — you, your teammate, or any AI tool (Stitch, GLM-5.3, Antigravity, Cursor, Claude, etc.).

**The one hard rule:** if a value (color, size, spacing, radius) isn't already defined in this doc or the two token files below, **don't invent one — ask first.** Every visual inconsistency in a multi-person, multi-AI project traces back to someone quietly picking their own hex code.

---

## 0. Source-of-truth files

| App | File | Export to use |
|---|---|---|
| Patient (Flutter) | `lib/theme/theme.dart` | `patientTheme` |
| Caregiver (React) | `tailwind.config.js` | `theme.extend.colors` / `fontFamily` |

Any token change happens **in these two files first**, then gets reflected in this document in the same commit/PR. Nobody edits a screen to "just fix the color" locally.

---

## 1. Color tokens

| Token | Hex | Use | Never use for |
|---|---|---|---|
| `cream` | `#FBF5EA` | App background | Buttons, alerts |
| `surface` | `#FFFDF8` | Cards, sheets | Full-screen backgrounds |
| `ink` | `#2E2A24` | Primary text | Backgrounds |
| `ink-soft` | `#6B625A` | Secondary/meta text | Primary body text |
| `terracotta` | `#B5562F` | Primary buttons, brand color, CTAs | SOS, error states |
| `terracotta-dark` | `#8C3F20` | Pressed/hover state | Base fills |
| `gold` | `#C9962C` | Accents, highlights, progress, badges | Primary CTA |
| `sage` | `#6E8C6A` | "Calm / done / safe" states only | Buttons, warnings |
| `alert-red` | `#C1272D` | **SOS/emergency control only** | Anything else, ever |
| `border` | `#E4D9C4` | Dividers, outlines | Text, icons |
| `status-good` | `sage` (existing) | Stable / on-track patient status | New hex — reuse existing token |
| `status-attention` | `gold` (existing) | Needs-review status, upcoming tasks | New hex — reuse existing token |
| `status-urgent` | `#8C2C24` | Missed dose, urgent flag — caregiver dashboard ONLY | SOS control (that stays `alert-red`) |
| `status-info` | `#2C4A6E` | Neutral data highlights, chart lines, links, secondary badges | Primary buttons (stays `terracotta`) |

Rationale: `status-good`/`status-attention` reuse existing tokens rather than adding new ones — sage and gold already carry these meanings per Section 1. `status-info` is new: a deep blue pulled from the Meitei mayek naibi color set (Higok), where each color in that system denoted a specific clan meaning, not decoration — same principle applied here to give the dashboard a real semantic color instead of default Tailwind blue.

**Rule:** `alert-red` is reserved. If it starts showing up on a "delete" button or a form-validation error, that's a bug in the implementation, not a design choice — flag it.

**Rule:** no pure white (`#FFFFFF`) or pure black (`#000000`) anywhere in the patient app.

---

## 2. Typography

**Font:** Noto Sans family (`Noto Sans`, `Noto Sans Bengali`, `Noto Sans Devanagari` — covers Assamese/Bengali and Bodo with matched metrics; Latin covers English/Mizo/Khasi/Garo).

| Style | Size | Weight | Line height | Where |
|---|---|---|---|---|
| Display | 32px | 700 | 1.3 | Greetings |
| Headline | 26px | 600 | 1.35 | Screen titles |
| Body-Large | 22px | 400 | 1.5 | Primary content |
| Body-Min | **18px** | 400 | 1.5 | Absolute floor — patient app |
| Button | 20px | 500 | 1.2 | All buttons |

**Rules:**
- Nothing below 18px on the patient app, ever, no exceptions for "minor" labels.
- No Light/Thin weights on the patient app.
- No italics, no all-caps, no serif fonts.
- Caregiver app uses the standard Tailwind scale (`text-sm`–`text-2xl`) with the same font family — no need to inherit the oversized patient scale.

---

## 3. Spacing, radius, touch targets

- Grid: 8pt base (4/8/16/24/32/48/64)
- Touch targets: **88×88dp minimum** on patient app, 16–24dp gap between adjacent ones
- Corner radius: **20dp** patient app · **8–12px** caregiver app
- Shadows: subtle only (2–4dp blur, ~8% opacity) — no harsh drop shadows

---

## 4. Components

**Buttons**
- One primary button per screen, full-width, 88dp min height, `terracotta` fill
- Icon + word label always — never icon-only
- Secondary = outlined, never a second competing filled button

**SOS**
- Fixed position, same corner, every single screen of the patient app
- `alert-red`, circular, 96dp, always labeled "Help"
- Never nested behind a menu or a scroll

**Cards**
- `surface` background, 20dp radius, 24dp padding
- One idea per card — no card with two competing actions

**Navigation**
- Default: no persistent nav bar — single home → one task → back to home
- If unavoidable: max 3 bottom tabs, icon + label

**Confirmations**
- Plain-language buttons stating the consequence ("Yes, call Priya" / "Go back")
- No X-only dismiss, no countdown timers, no time pressure anywhere

---

## 5. Cultural motifs — governed, not free-form

Reference set: **Gamosa** (Assam, everyday/hospitality symbol), **Meitei geometric borders / sun-moon motifs** (Manipur), **Puanchei color-story only** (Mizoram), **Risa border-stripe idea only** (Tripura).

**Allowed:**
- Thin line-art border versions of the above, used only in: splash screen, onboarding, photo-frame widgets
- Caregiver-set "heritage accent" at onboarding (Assamese/Manipuri/Mizo/Tripuri) that swaps the border motif + one home-screen photo frame

**Never:**
- Motifs inside buttons or behind body text
- Full/dense weave reproductions anywhere in functional UI
- Tawlhlohpuan, Saihlo, or Thangchhuah (Mizo, warrior/hero-restricted), Manipuri temple textiles, or full Risa pattern reproduction — status/ceremony-restricted, not for casual reuse
- Any new motif added without a quick check against this section first

**Newly allowed (caregiver app only):**
- Risa-inspired stripe: a 3px top border on patient cards, alternating `status-info` / `status-attention` / `status-urgent` depending on state — structural indicator, not a fill or background pattern
- Meitei double-line border (2px + 2px, 2px gap) for focus/selected states, replacing default box-shadow focus ring

Still governed by existing rules: no motif inside buttons, none behind body text, no dense weave reproduction.
---

## 6. Two apps, one brand

| | Shared | Allowed to differ |
|---|---|---|
| Color tokens | Same hex values | Caregiver app may use a neutral gray scale (e.g. Tailwind `slate`) for its own chrome alongside the brand colors |
| Font family | Same (Noto Sans family) | Type scale size (patient is oversized, caregiver is standard) |
| Radius | Same shape language (rounded, warm) | Exact radius value (20dp vs 8–12px) |
| Dark mode | — | Caregiver app may offer a dark-mode toggle; **patient app stays light-only, always** |

---

## 7. Instructions for AI coding agents

Paste this block into `AGENTS.md` / `GEMINI.md` / `.cursorrules` in **both** repos:

```
# Design System Rules — read before writing any UI code
This project has one canonical design system: /docs/BRAND_GUIDELINES.md

1. Flutter: import and reuse `patientTheme` from lib/theme/theme.dart.
   Never define a new ThemeData, never use raw Color(0x...) values,
   never hardcode font sizes.
2. React: use only the tokens defined in tailwind.config.js
   (e.g. bg-terracotta, text-ink). Never use arbitrary values like
   bg-[#123456] or inline style="color:" for brand colors/typography.
3. `alert-red` (#C1272D) is reserved for the SOS/emergency control ONLY.
   Never use it for any other warning, error, or destructive action.
4. Minimum touch target on the patient app is 88x88dp.
   Minimum body text size on the patient app is 18px. Do not go below these.
5. No icon-only buttons on the patient app — always icon + word label.
6. Do not add new cultural motifs, patterns, or imagery without checking
   Section 5 of BRAND_GUIDELINES.md first.
7. If a screen needs a value that isn't already a token in
   theme.dart / tailwind.config.js, stop and ask rather than inventing one.
```

---

## 8. Merge checklist (human or AI — check before opening a PR)

- [ ] All colors reference tokens — no hardcoded hex anywhere
- [ ] No text below 18px on the patient app
- [ ] All touch targets ≥88×88dp on the patient app
- [ ] No icon-only buttons introduced
- [ ] `alert-red` appears nowhere except the SOS control
- [ ] No motif/pattern placed inside a button or behind body text
- [ ] Screen tested with at least one non-Latin string (Assamese/Bengali/Bodo sample text) to confirm no clipping or overflow
- [ ] No new timers/countdowns added to patient-facing flows

---

## 9. Changing this document

Token or rule changes are made **here first**, in the same PR as the corresponding change to `theme.dart` / `tailwind.config.js` — never as a silent one-off inside a feature branch. If you're not sure whether something counts as a "change" vs. "just this screen," treat it as a change and update this file.

---

## Changelog

- **v0.1 — Aug 27, 2026:** Initial design system — colors, type, spacing, components, cultural motif governance, AI agent rules.
- **v0.2 — Sep 3, 2026:** Added caregiver-only status tokens (status-urgent, status-info) and Risa/Meitei structural treatments for cards and focus states.
