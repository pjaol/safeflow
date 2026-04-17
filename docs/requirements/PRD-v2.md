# Clio Daye v2 — Product Requirements Document

**Version:** 0.3 (draft)
**Status:** In review
**Date:** 2026-04-10
**Builds on:** PRD v1.0 (2026-03-29), roadmap-menopause-v2.md, accessibility-i18n.md

---

## Table of Contents

1. [What v2 Is](#1-what-v2-is)
2. [What v1 Left Unfinished](#2-what-v1-left-unfinished)
3. [New User Personas](#3-new-user-personas)
4. [Product Principles (updated)](#4-product-principles-updated)
5. [Feature Roadmap](#5-feature-roadmap)
6. [Detailed Specifications](#6-detailed-specifications)
7. [Data Model Changes](#7-data-model-changes)
8. [Algorithm Changes](#8-algorithm-changes)
9. [Privacy & Regulatory](#9-privacy--regulatory)
10. [Success Metrics](#10-success-metrics)
11. [Out of Scope](#11-out-of-scope)

---

## 1. What v2 Is

v1 shipped a privacy-first cycle tracker for people with regular-to-moderately-irregular periods. It does one thing well: private, honest cycle tracking for the reproductive phase of life.

**v2 expands the product to be useful across the full range of cycle experiences** — from a first-time tracker in their 20s to someone in perimenopause where cycles have become unpredictable, to someone who has already reached menopause and whose primary needs have nothing to do with period prediction.

The expansion has two tracks that ship in parallel:

**Track A — Make v1 better for existing users**
Track A ships independently as **v1.1** before v2.0. See §5 for rationale.
- Accessibility (VoiceOver, Dynamic Type, Reduce Motion)
- Internationalization (string extraction, locale-aware formatting)
- Post-launch bug fixes absorbed from `release/1.x`

**Track B — Life-stage expansion**
- Life-stage settings (user-declared: regular / irregular / perimenopause / menopause / paused)
- Expanded symptom taxonomy covering vasomotor, sleep, cognition, genitourinary
- Symptom-first home screen mode for menopause stage
- Red-flag guidance (non-diagnostic, clinically reviewed)
- Adaptive onboarding that branches by goal and life stage

**What v2 is NOT:**
- A diagnostic tool
- A contraceptive method
- An ML inference engine (that is v3 territory)
- A cloud product

---

## 2. What v1 Left Unfinished

These items were either deferred at v1 launch or are directly motivated by the menopause expansion research. They inform v2 scope.

### Unfinished from PRD v1.0 roadmap

| Item | v1 Status | v2 Plan |
|---|---|---|
| Cycle mode system (regular / irregular / perimenopause / paused) | Backlog §12 — not built | P0 in v2 |
| Widgets | v0.4 item — not built | P1 in v2 |
| Smart notifications | v0.4 item — not built | P1 in v2 |
| Data export (PDF + CSV) | v1.0 item — not built | **Cancelled** — see §1 privacy rationale |
| BBT logging | v0.5 item — not built | Defer to v3 |
| Cervical mucus tracking | v0.5 item — not built | Defer to v3 |
| OPK result logging | v0.5 item — not built | Defer to v3 |
| Partner/support sharing | v1.0 item — not built | **Cancelled** — see §1 privacy rationale |
| Medication logging | Post-v1.0 — explicitly deferred | Defer (requires clinical partner) |
| Accessibility (a11y) | Not shipped | **Ships in v1.1** — see accessibility-i18n.md |
| Internationalization (i18n) | Not shipped | **Ships in v1.1** — see accessibility-i18n.md |

### Problems identified post-launch

- **No cold-start experience for late-stage users.** Someone who installs the app already in menopause hits an onboarding that asks for their last period start date. That question has no good answer if it was 3 years ago.
- **Home screen breaks for irregular/long cycles.** "Day 67" and perpetual overdue state are not useful UI states.
- **Symptom set is cycle-centric.** The 15 current symptoms are almost all menstrual (cramps, mittelschmerz, breast tenderness). Hot flashes, night sweats, brain fog, joint pain, and sleep quality — the dominant concerns of peri/menopause — are absent.
- **No immediate value for new users without historical data.** Every insight and ML-adjacent feature (drift detection, summaries, effect estimation) requires weeks of logged data. Users in a new life stage need value on day one.

---

## 3. New User Personas

These extend the four personas in PRD v1.0. The v1 personas (Maya, Jordan, Sam, Priya) remain valid.

**Persona 5 — Diane, 51 (Early perimenopause, arrives knowing)**
Has been tracking with Clue for 6 years. Recently noticed her cycles are ranging from 22 to 55 days. Clue keeps showing confident predictions that are wildly wrong. Heard about Clio Daye's privacy stance. Comes in knowing she's perimenopausal but doesn't want an app that treats her as a medical case. Wants honest uncertainty, symptom tracking that includes hot flashes and sleep, and something she can show her GP.

**Persona 6 — Rosaria, 58 (Postmenopausal, new to tracking)**
Had her last period at 53. Never tracked. Started getting joint pain and brain fog and wants to understand what's hormonal vs what isn't. Has no period data to offer. Needs an app that doesn't assume she has cycles. Her primary need is symptom logging over time and a way to bring structured data to a GP appointment.

**Persona 7 — Alex, 34 (Paused cycle — post-partum)**
8 months post-partum, breastfeeding, no period yet. Was using Clio Daye before pregnancy. Wants to come back to the app without it nagging her about a missing period or inferring pregnancy. Just wants to log mood and energy while her cycle returns.

---

## 4. Product Principles (updated)

All v1 principles carry forward unchanged. The following are added for v2:

**8. Life stage is user-declared, never inferred.**
The app never infers perimenopause, menopause, pregnancy, or post-partum status from data. The user sets their life stage. This is a privacy principle, a safety principle, and a trauma-aware design principle. An app that says "you might be pregnant" or "this looks like perimenopause" can cause harm.

**9. Value on day one, regardless of data.**
Every new user — including someone arriving in menopause with no logged history — must get meaningful value within their first session. This means curated content, validated information, and useful UI that doesn't depend on historical logs.

**10. Honest uncertainty scales with life stage.**
As cycles become less predictable, the app's confidence language scales down accordingly. "Your period is expected April 12–16" is appropriate for a regular-cycle user. "Cycles may be irregular — see the symptom view for what we know" is appropriate for perimenopause. Silence (no prediction shown) is appropriate for menopause.

**11. Red flags surface, not sink.**
Certain symptom patterns warrant clinical attention. The app must surface these clearly and without alarm — not bury them in settings. This applies across all life stages but is especially critical for postmenopausal bleeding and certain patterns of heavy bleeding in perimenopause.

---

## 5. Feature Roadmap

### Why v1.1 ships before v2.0

Track A (accessibility and i18n) is independent of Track B (life-stage expansion). The accessibility audit (`accessibility-i18n.md`) identified ~6 weeks of work; i18n string extraction is a further 1–2 weeks. Track B is 3–4 months of work. Waiting to ship Track A as part of v2.0 would:

- Delay VoiceOver and Dynamic Type support for existing users by 3–4 months unnecessarily
- Mean all new v2 screens are built before the string catalog exists, requiring i18n to be retrofitted across them
- Bundle a large accessibility fix with a major feature release, making regression harder to isolate

v1.1 ships Track A clean. v2.0 then builds on a codebase that is already accessible and localisation-ready.

---

### v1.1 — Quality & Accessibility
*No new features. Existing app, properly accessible and internationalised.*

**Branch:** `release/1.1` off `main`

**Accessibility (Phase 1–4 from accessibility-i18n.md)**
- [ ] VoiceOver: `.accessibilityLabel()` on all icon-only buttons (toolbar, navigation)
- [ ] VoiceOver: `.accessibilityHidden(true)` on all decorative images
- [ ] VoiceOver: `.accessibilityLabel()` and `.accessibilityHint()` on Steppers and DatePicker in Onboarding
- [ ] VoiceOver: contextual label on `CycleRingSummaryCard` ring centre count
- [ ] Reduce Motion: `@Environment(\.accessibilityReduceMotion)` added to `CycleRingSummaryCard`, `ViewModifiers`, `HomeView` animations
- [ ] Dynamic Type: replace all hardcoded `.font(.system(size: X))` calls with relative sizes (`.body`, `.headline`, `.caption`, etc.)
- [ ] Dynamic Type: test and fix all layouts at max font scale
- [ ] VoiceOver: improved navigation hints on `DartboardView` and `WeekRibbonView`
- [ ] Accessibility Inspector: zero critical issues on all primary screens

**Internationalisation (Phase 1–2 from accessibility-i18n.md)**
- [ ] Create `Localizable.xcstrings` string catalog
- [ ] Extract all hardcoded `Text("…")` strings from all View files into catalog
- [ ] Replace all `DateFormatter` instances using hardcoded `dateFormat` patterns with `.formatted()` API
- [ ] Replace all `"\(n) days"` / `"\(n) mo"` patterns with locale-aware unit formatting
- [ ] Establish string key naming convention (`"view.element.description"`) and document in CLAUDE.md

**Post-launch patches**
- [ ] Absorb all merged fixes from `release/1.x`

**Definition of done for v1.1:**
- Xcode Accessibility Inspector: zero critical issues on HomeView, OnboardingView, SettingsView, LockView, LogDayView
- Full primary user flow navigable with VoiceOver only (tested on device)
- All text scales without layout breaks at the three largest Dynamic Type sizes
- Zero hardcoded English strings remain in any View file
- All date and number formatting uses locale-aware APIs
- Unit tests pass; no regressions

---

### v2.0 — Life Stage Foundation
*Must-have: the minimum set that makes Clio Daye useful beyond the reproductive-phase user.*

**Branch:** `feature/v2/*` → `main`

**Prerequisite:** v1.1 merged to `main` before v2.0 work begins on any shared View files. New v2 screens are written localisation-ready and accessible from day one.

- [ ] Life-stage settings screen (user-declared: Regular / Irregular / Perimenopause / Menopause / Paused)
- [ ] Adaptive onboarding branch: "Are you currently having periods?" routes to cycle-setup or symptom-setup path
- [ ] Expanded symptom taxonomy: vasomotor (hot flashes, night sweats), sleep quality, cognitive clarity, musculoskeletal pain
- [ ] Symptom-first home screen mode (default for Menopause stage)
- [ ] Red-flag guidance layer (non-diagnostic; rule-based; clinically reviewed copy)
- [ ] Perimenopause-aware forecasting: prediction confidence degrades as cycle variability increases; suppress ovulation estimate when variability is high
- [ ] In-app appointment summary view (read-only; no share/export — see §6.6)

### v2.1 — Clinical Utility
*The features that make Clio Daye worth bringing to a GP appointment.*

- [ ] Intervention tracking v1: log start/stop of HRT, nonhormonal medications, supplements, lifestyle changes
- [ ] "What changed" monthly summary v1: top 3 changes vs prior 30 days, red-flag check, uncertainty-framed language
- [ ] GSM symptom module (opt-in; separate lock): vaginal dryness, pain with sex, urinary symptoms
- [ ] i18n: RTL layout support

### v2.2 — Habit & Platform
*Retention and platform features that reinforce daily use.*

- [ ] Home screen widget: cycle phase / symptom summary / days since last log
- [ ] Logging reminders: conditional recurring nudge (suppressed automatically when user has already logged; interval and time configurable; life-stage aware copy)
- [ ] Period supply reminder: settings UI for the existing supply reminder (currently on but unconfigurable)
- [ ] Phase-contextual tip cards for perimenopause and menopause stages (parallel to existing cycle phase tips)
- [ ] Symptom severity trend view: 30/60/90-day trajectory charts for individual symptoms

---

## 6. Detailed Specifications

### 6.1 Life-Stage Settings

**Location:** Settings → "Your Cycle" section (new, above Security)

**Options (user-declared, single select):**

| Stage | Label | Description shown to user |
|---|---|---|
| `regular` | Regular cycles | Periods come roughly on schedule. Predictions and phase tracking are on. |
| `irregular` | Irregular cycles | Periods vary a lot. Predictions will show a wider range. |
| `perimenopause` | Perimenopause | Cycles are changing. Predictions are approximate; symptom tracking is prioritised. |
| `menopause` | Menopause | Periods have stopped. Symptom tracking and monthly summaries are the main view. |
| `paused` | Cycle paused | Post-partum, breastfeeding, or medically paused. No predictions or nudges. |

**Behaviour by stage:**

| Feature | Regular | Irregular | Perimenopause | Menopause | Paused |
|---|---|---|---|---|---|
| Day counter | Yes | Yes (suppressed if overdue >14d) | No | No | No |
| Phase card | Yes | Yes | Simplified (no ovulation) | No | No |
| Period prediction | Yes, with range | Yes, wider range | Approximate, high uncertainty shown | No | No |
| Ovulation estimate | Yes | Suppressed if σ > 7d | No | No | No |
| Fertile window | Yes | Suppressed if σ > 7d | No | No | No |
| Variability nudge | Yes | Once per 6 cycles max | Suppressed | Suppressed | Suppressed |
| Symptom-first home | Optional | Optional | Optional | Default | Optional |
| VMS/sleep/cognition symptoms | Available | Available | Prominent | Prominent | Available |

**Key principle:** Stage is set by the user. The app never auto-switches stage based on data. It may surface a gentle, dismissible prompt — e.g., "Your cycles have been variable lately. You can update your cycle settings anytime." — but never changes the setting without user confirmation.

**Change flow:** Settings → Your Cycle → tap stage → confirmation sheet with a one-line explanation of what changes → confirm. No irreversible action; user can change back freely.

---

### 6.2 Adaptive Onboarding

Current onboarding is a 4-page linear flow ending in cycle seed data collection. v2 branches at page 2.

**New page 2 question:** "Are you currently having periods?"

- **Yes, regularly** → current Page 3 (cycle setup: last period date, period length, cycle length)
- **Yes, but they're irregular** → abbreviated cycle setup (last period date only; skip length steppers; defaults to wide prediction range)
- **Not currently / rarely** → life-stage setup (select from perimenopause / menopause / paused; skip cycle seed data)
- **I'd rather skip** → skip to home (same as current "skip for now")

**For the "not currently" path:**
- Replace cycle seed data page with a symptom priorities page
- "What would you like to track?" — multi-select: Hot flashes / Sleep / Mood / Joint pain / Brain fog / Other
- Selected items are surfaced in the home screen symptom quick-log on first open
- Onboarding completes with a home screen showing the symptom-first layout, not the phase card

**Cold-start experience for menopause users:**
- Home screen shows: today's symptom log (prominent), a 30-day calendar of logged symptoms (empty but ready), and a "What to expect from Clio Daye" education card
- No phase card, no prediction, no overdue state
- First education card: "Clio Daye learns from what you log. After a few weeks, you'll see patterns and trends." — sets expectations without false promises

---

### 6.3 Expanded Symptom Taxonomy

The current 15 symptoms are retained. New symptoms are additive to the `Symptom` enum (backward-compatible Codable).

**New symptoms — Vasomotor category (new category)**
| Raw value | Display | Input type |
|---|---|---|
| `hotFlash` | Hot flash | Presence + severity (mild / moderate / severe) |
| `nightSweats` | Night sweats | Presence + severity (mild / moderate / severe) |

**New symptoms — Sleep category (new category)**
| Raw value | Display | Input type |
|---|---|---|
| `poorSleep` | Poor sleep | Presence |
| `insomniaDifficultFalling` | Can't fall asleep | Presence |
| `insomniaDifficultStaying` | Waking during night | Presence |

**New daily fields (not symptoms — separate daily metrics)**
| Field | Type | Range | Note |
|---|---|---|---|
| `sleepQuality` | `Int?` | 0–4 | 0 = very poor, 4 = excellent |
| `cognitiveClarity` | `Int?` | 0–4 | 0 = severe fog, 4 = sharp |

**New symptoms — Musculoskeletal category**
| Raw value | Display |
|---|---|
| `jointPain` | Joint pain |
| `musclePain` | Muscle pain |
| `exerciseRecovery` | Poor recovery |

**Genitourinary (GSM) module — opt-in, separate lock**

Stored as a separate `GSMDay` record (not embedded in `CycleDay`) to allow independent deletion and module-level access control.

| Field | Type | Range |
|---|---|---|
| `vaginalDryness` | `Int?` | 0–3 |
| `painWithSex` | `Int?` | 0–3; includes "not applicable" |
| `urinaryUrgency` | `Int?` | 0–3 |
| `recurrentUTI` | `Bool?` | flag only |

The GSM module requires a second authentication step (PIN or biometric) to open, separate from the main app lock. It can be enabled or disabled in Settings and deleted independently of all other data.

---

### 6.4 Symptom-First Home Screen

When life stage is set to Menopause (or manually enabled in any stage), the home screen reorganises:

**Primary zone — Today's symptoms**
- Large quick-log cards for the top 3 symptoms the user has logged most frequently (or their onboarding selections if no history yet)
- Severity picker inline (for VMS symptoms)
- Sleep quality and cognitive clarity as horizontal sliders below

**Secondary zone — 30-day trend**
- Compact heat-map view: one row per tracked symptom, 30 columns for days, colour intensity = severity/presence
- Replaces the cycle forecast grid for menopause stage users

**Tertiary zone — Monthly summary card**
- "Last 30 days at a glance" — text summary, rule-based, max 3 bullets
- Appears after user has 14+ days of logged data
- Links to full summary view

**What is removed from this layout:**
- Phase card (hidden for menopause stage)
- Period prediction (hidden)
- Fertile window (hidden)
- Cycle day counter (hidden)

The flow log (dartboard / flow slider) remains accessible via the Edit Logs sheet but is not on the primary home screen for menopause-stage users. It is still functional — postmenopausal bleeding should be loggable and will trigger a red-flag prompt.

---

### 6.5 Red-Flag Guidance

**Scope:** Non-diagnostic. The app does not diagnose. It surfaces patterns that clinical guidelines identify as warranting evaluation and prompts the user to seek care.

**Trigger conditions (rule-based, clinically reviewed):**

| Trigger | Stage | Prompt |
|---|---|---|
| Any flow logged when life stage = Menopause | Menopause | "Bleeding after menopause should always be evaluated by a doctor. This is usually benign, but it's important to rule out other causes." |
| Flow logged as Heavy for 3+ consecutive days | Any | "Heavy bleeding lasting several days can sometimes need attention. If this is unusual for you, it may be worth mentioning to a doctor." |
| `hotFlash` logged as severe for 7+ consecutive days | Peri / Meno | "Frequent severe hot flashes can significantly affect quality of life. There are effective options — it may be worth discussing with a healthcare provider." |
| `poorSleep` logged for 10+ of last 14 days | Any | "Prolonged sleep disruption can affect your health. If this is new or worsening, it's worth raising with a doctor." |

**Prompt design:**
- Appears as a dismissible card in the monthly summary view, not as a modal or alert
- Never alarmist language. Always: "may be worth," "it's usually benign but," "there are options"
- Every prompt includes a "Dismiss" and a "Learn more" action (links to curated, static in-app content — no external URLs)
- User can suppress a category of prompts for 90 days ("don't remind me about this")
- All copy is reviewed by a clinical advisor before shipping

**What the app never does:**
- Never says "you may have cancer" or names specific conditions
- Never recommends specific treatments or dosages
- Never fires a red-flag prompt as a push notification (too alarming out of context)

---

### 6.6 Data Export and Partner Sharing — Cancelled

**Decision:** All data export features (clinical PDF, raw CSV/JSON) and partner/support sharing are cancelled across all versions. This is a privacy decision, not a resource decision.

**Rationale:**

The app's core promise is that data never leaves the device. Any export mechanism — regardless of how carefully it is implemented — creates a vector for that promise to be broken:

- A PDF shared to Mail or AirDrop can be forwarded, subpoenaed, or accessed by anyone with the recipient device. Once the file leaves the app's sandbox, Clio Daye has no control over it.
- A CSV in the Files app is visible to any other app with Files access.
- "Partner sharing" — even via on-device QR code — creates a copy of intimate health data on a second device. That device may not be trusted, encrypted, or under the user's full control.
- In a post-Dobbs legal environment, a shared export containing period logs is a liability for the user that Clio Daye should not create.

The clinical value of "bring this to your GP" can be served by a different mechanism that keeps data on-device: an **in-app summary view** that the user can show on their screen during an appointment. No file is created, no data leaves the device, and the user has full control over what is visible.

**What replaces export in v2.1:**

- **In-app appointment summary view** — a read-only, full-screen display of symptom timeline, top symptoms, and bleeding history formatted for showing to a clinician. Accessed from Settings or the monthly summary card. No share button. No file generation.
- **Red-flag guidance** remains (§6.5) — this surfaces "seek care" prompts in-app without creating any shareable artefact.

**Items permanently removed from scope:**
- Clinical conversation export (PDF)
- Raw data export (CSV/JSON)
- Partner/support sharing (QR code or any other mechanism)

These items must not be added back in any future version without a full privacy review and an explicit decision documented in this PRD.

---

### 6.7 Perimenopause-Aware Forecasting

The current algorithm treats cycle variability as an uncertainty quantifier for prediction range width. v2 adds behaviour changes that trigger at high variability thresholds.

**New thresholds:**

| Condition | Threshold | Behaviour change |
|---|---|---|
| High variability | σ > 7 days | Suppress ovulation estimate and fertile window; widen prediction range; show "cycles are variable" label instead of phase name |
| Amenorrhea run | ≥ 60 days since last non-spotting flow | Suppress period prediction entirely; show "It's been X days since your last period" with no inference language |
| Stage = Perimenopause | User-declared | All of the above regardless of computed variability |

**Algorithm behaviour for high-variability / perimenopause:**
- Weighted recency average continues to run (still useful as a rough anchor)
- Prediction range halfwidth = max(7, ceil(σ)) — minimum 7-day window
- Prediction label changes from "Expected April 8–12" to "Period likely sometime around April 10 (±7 days)"
- Fertile window: hidden (anovulatory cycles make it meaningless and potentially harmful if acted on)
- Ovulation estimate: hidden

These changes are purely presentational — the underlying prediction engine keeps computing. The changes prevent the UI from implying accuracy the model cannot deliver.

---

### 6.8 Widgets (v2.2)

**Small widget (2×2):**
- Cycle phase name + icon (regular stage) OR top symptom today (menopause stage)
- Days until next period OR days since last log
- No health data on lock screen (widget is home screen only by default; user can enable lock screen widget with an explicit consent step)

**Medium widget (2×4):**
- Phase card summary (regular stage) OR 7-day symptom trend (menopause stage)
- Log Today button (deep-links to quick-log)

**No health data in widget previews.** Widget placeholder shows generic "Track your cycle" text, not real data. This prevents health data appearing in App Library or screenshots.

---

### 6.9 Logging Reminders (v2.2)

#### Overview

All notification scheduling is local — `UNUserNotificationCenter` with `UNCalendarNotificationTrigger`. No server, no Background App Refresh, no push infrastructure. iOS delivers the notifications independently of whether the app is running.

The notification service already exists (`NotificationService.swift`) and handles the period supply reminder. Logging reminders are a second, parallel notification type added to the same service.

#### The conditional suppression pattern

At fire time the app is not running and cannot check whether the user has logged today. The solution is to manage this at schedule time:

1. When the app opens or any log is saved, **cancel all pending logging reminders and reschedule a fresh batch** of 8 future reminders starting from `today + interval`.
2. This means a log saved today implicitly suppresses today's reminder (it was either already fired, or it gets cancelled and rescheduled forward).
3. If the user never opens the app, the pre-scheduled batch fires on schedule — up to 8 nudges covering ~16–24 days depending on interval.

After 8 notifications without an app open, the batch is exhausted. A generic low-frequency "come back" notification is not added — if a user hasn't opened in 3+ weeks, a notification is unlikely to re-engage them and may be annoying.

#### Default interval by life stage

| Life stage | Default interval | Rationale |
|---|---|---|
| Regular | Every 2 days | Period can start any day; missing 2 consecutive days loses the period-start signal |
| Irregular | Every 2 days | Same; irregular users have more to gain from consistent logging |
| Perimenopause | Every 3 days | Symptom trends tolerate a day gap; reduce pressure |
| Menopause | Every 3 days | No cycle anchor; symptom trends are the goal |
| Paused | Every 3 days | Mood/energy logging; no urgency |

#### User configuration

Settings → Notifications (new section):

| Setting | Options | Default |
|---|---|---|
| Logging reminders | On / Off | On |
| Remind me every | Every day / Every 2 days / Every 3 days | Per life stage |
| Reminder time | Time picker | 8:00 PM |
| Period supply reminder | On / Off | On (exposes existing behaviour) |

Changing any setting immediately cancels all pending logging reminders and reschedules with the new parameters.

#### Notification copy

Copy is determined at **schedule time** (not fire time) based on the user's current cycle state and life stage. It is baked into each `UNMutableNotificationContent` in the batch.

| Context | Title | Body |
|---|---|---|
| During predicted period window | "How's your period going?" | "Log flow or symptoms — takes 5 seconds." |
| 1–3 days before predicted period | "Period coming up" | "Log how you're feeling so we can track the lead-up." |
| Perimenopause stage | "How are you feeling?" | "Log today to keep your symptom pattern up to date." |
| Menopause stage | "How are you feeling?" | "A quick log helps build your symptom picture." |
| Paused stage | "How are you feeling?" | "Log your mood or energy — takes 5 seconds." |
| Generic (no prediction, regular stage) | "Time to log" | "A quick check-in helps Clio Daye learn your pattern." |

All 8 notifications in a batch use the same copy (computed once at schedule time). If the cycle state changes significantly between app opens, the next reschedule picks up the new context.

#### Trigger points for reschedule

| Event | Action |
|---|---|
| App moves to foreground | Cancel all pending logging reminders → reschedule batch |
| User saves any log (flow, symptom, mood, notes) | Cancel all pending logging reminders → reschedule batch from today + interval |
| User changes reminder interval in Settings | Cancel all → reschedule with new interval |
| User changes reminder time in Settings | Cancel all → reschedule with new time |
| User changes life stage | Cancel all → reschedule with new default interval and copy context |
| User toggles reminders off | Cancel all; do not reschedule |
| Cycle prediction updates (new period logged) | Cancel all → reschedule (supply reminder also rescheduled here already) |

#### Notification IDs

```
safeflow.loggingReminder.0   ← soonest
safeflow.loggingReminder.1
...
safeflow.loggingReminder.7   ← furthest out (~16–24 days)

safeflow.supplyReminder      ← existing; unchanged
```

Using indexed IDs allows cancelling the full batch by known identifier without querying pending requests.

#### What this feature does not do

- No daily fixed-time notification regardless of logging status — this is the single most common cause of notification-driven churn in health apps
- No notification content that reveals health data on the lock screen — title and body contain no cycle phase, flow, or symptom information
- No notification fired within 2 hours of the previous one (minimum gap enforced at schedule time)
- No badge count — the app does not use the badge to indicate "you haven't logged"

#### Implementation notes for engineering

`NotificationService` gains three new methods alongside the existing supply reminder methods:

```swift
func scheduleLoggingReminders(
    from startDate: Date,
    intervalDays: Int,
    preferredHour: Int,
    context: LoggingReminderContext
) async

func cancelAllLoggingReminders() async

// Called by CycleStore.addOrUpdateDay — same call site as rescheduleSupplyReminder()
func rescheduleLoggingReminders(cycleStore: CycleStore) async
```

`rescheduleLoggingReminders` reads the user's interval and time preferences from `UserDefaults`, determines the correct `LoggingReminderContext` from the cycle store's current state, and calls `scheduleLoggingReminders`. It is safe to call frequently — it always cancels before rescheduling.

`LoggingReminderContext` is a simple enum:

```swift
enum LoggingReminderContext {
    case duringPeriod
    case beforePeriod       // within 3 days of predicted earliest
    case perimenopause
    case menopause
    case paused
    case generic
}
```

Context is resolved in priority order: duringPeriod → beforePeriod → life stage → generic.

---

## 7. Data Model Changes

All changes are additive and backward-compatible. Existing `CycleDay` records decode correctly; new fields are absent (nil) in old records.

### 7.1 CycleDay additions

```swift
struct CycleDay: Identifiable, Codable {
    // existing fields unchanged
    let id: UUID
    let date: Date
    var flow: FlowIntensity?
    var symptoms: Set<Symptom>
    var mood: Mood?
    var notes: String?

    // new in v2.0
    var sleepQuality: Int?         // 0–4; nil = not logged
    var cognitiveClarity: Int?     // 0–4; nil = not logged
}
```

### 7.2 Symptom enum additions

```swift
enum Symptom: String, Codable, CaseIterable {
    // existing 15 cases unchanged
    // ...

    // new in v2.0 — vasomotor
    case hotFlash
    case nightSweats

    // new in v2.0 — sleep
    case poorSleep
    case insomniaDifficultFalling
    case insomniaDifficultStaying

    // new in v2.0 — musculoskeletal
    case jointPain
    case musclePain
    case exerciseRecovery
}
```

### 7.3 VMS severity (new)

Severity on VMS symptoms is stored separately from presence. Rather than embedding severity in `Symptom`, it is stored as a companion dictionary on `CycleDay`:

```swift
struct CycleDay: Identifiable, Codable {
    // ...
    var symptomSeverity: [String: Int]?   // raw value of Symptom → severity 0–3
}
```

This keeps the `Symptom` enum simple and avoids a combinatorial explosion of enum cases.

### 7.4 Life stage preference

```swift
enum LifeStage: String, Codable {
    case regular
    case irregular
    case perimenopause
    case menopause
    case paused
}
```

Stored in `UserDefaults` under `"lifeStage"`. Not in `CycleDay` — it is a user preference, not a per-day record.

### 7.5 CycleSeedData additions

```swift
struct CycleSeedData: Codable, Equatable {
    // existing
    let lastPeriodStartDate: Date
    let typicalPeriodLength: Int
    let typicalCycleLength: Int

    // new in v2.0
    var lifeStage: LifeStage            // from onboarding branch
    var primarySymptoms: [String]?      // raw values; user's onboarding selections
}
```

### 7.6 GSMDay (new, separate store)

```swift
struct GSMDay: Identifiable, Codable {
    let id: UUID
    let date: Date
    var vaginalDryness: Int?       // 0–3
    var painWithSex: Int?          // 0–3; separate "not applicable" flag
    var painWithSexNA: Bool
    var urinaryUrgency: Int?       // 0–3
    var recurrentUTI: Bool?
    var notes: String?
}
```

Persisted independently under key `"gsmDays"` in `UserDefaults`. Deletable independently via Settings → Privacy → Delete GSM data.

### 7.7 Intervention (new, v2.1)

```swift
struct Intervention: Identifiable, Codable {
    let id: UUID
    let name: String
    var category: InterventionCategory
    var startDate: Date
    var endDate: Date?
    var notes: String?
}

enum InterventionCategory: String, Codable {
    case hormoneTherapy
    case nonHormonalRx
    case supplement
    case lifestyle
    case vaginalTreatment
    case other
}
```

Daily adherence is stored as a flag in `CycleDay`:

```swift
// in CycleDay
var interventionAdherence: [UUID: Bool]?   // interventionId → taken today
```

---

## 8. Algorithm Changes

### 8.1 Perimenopause-aware confidence degradation

The prediction engine gains a `confidenceLevel` output alongside its existing predictions:

```
confidenceLevel = .high    // σ ≤ 3 days
confidenceLevel = .moderate // σ 4–7 days
confidenceLevel = .low      // σ > 7 days OR life stage = perimenopause
confidenceLevel = .none     // life stage = menopause OR amenorrhea ≥ 60 days
```

UI uses confidence level to:
- Determine which prediction label copy to show
- Determine whether to show ovulation/fertile window
- Determine the minimum halfWidth for prediction ranges

### 8.2 Amenorrhea tracking

New computed property on `CycleStore`:

```swift
func daysSinceLastFlow() -> Int?
// Returns days since the last non-spotting flow day.
// Returns nil if no flow ever logged.
```

Used by:
- Phase card (shows "It's been X days since your last period" for perimenopause/menopause stages)
- Red-flag guardrail (60-day threshold)
- Prediction suppression logic

### 8.3 No new ML

The v2 prediction engine is still rule-based and deterministic. On-device statistical inference (drift detection, clustering, intervention effect estimation) is explicitly deferred to v3. The reason: these methods require 3–6 months of richer data (including the new symptom fields added in v2) before they can produce meaningful output. Building them in v2 would ship features that don't work yet.

---

## 9. Privacy & Regulatory

All v1 hard constraints carry forward unchanged (zero network, no third-party SDKs, no CloudKit, local notifications only).

### Additional constraints for v2

**GSM module:**
- Requires explicit opt-in (not shown unless user enables it in Settings)
- Requires a second authentication step to open (additional PIN or biometric prompt, separate from app unlock)
- Deletion is independent of all other data
- Export is excluded from clinical export by default; user must explicitly include it

**Intervention tracking:**
- No dosage recommendations, no drug interaction checks
- Category labels are descriptive, not prescriptive (e.g., "Hormone therapy" not "HRT 1mg estradiol")
- Free text notes field is the user's own and is not parsed or analysed

**Red-flag guidance:**
- All copy is reviewed by a clinical advisor before shipping
- Language reviewed against FDA guidance on clinical decision support — outputs are "patient-facing wellness information" not "clinical decision support software"
- No condition names, no diagnostic language, no treatment recommendations

**No export surface:**
- No file export of any kind (PDF, CSV, JSON) — see §6.6 for rationale
- The in-app appointment summary view (§6.6) must not include a share button or any mechanism to save content outside the app sandbox

**Updated privacy manifest:**
- `PrivacyInfo.xcprivacy` must be updated before v2.0 ships to reflect new data types (sleep quality, cognitive clarity, GSM fields)
- App Store privacy nutrition label must be re-reviewed

---

## 10. Success Metrics

### North Star (unchanged from v1)
**7-day logging streak rate at Day 30.** Target: 35%.

### v2-specific metrics

| Metric | Target | Notes |
|---|---|---|
| Life-stage settings adoption | >40% of users set a non-default stage | Measures whether the feature is discoverable |
| Symptom logging coverage (new taxonomy) | >30% of logs include ≥1 new symptom | Hot flash, sleep, cognition, musculoskeletal |
| Appointment summary view usage | >10% of active users open the summary view | Measures clinical utility of the on-screen alternative |
| Menopause-stage Day 30 retention | ≥25% | Baseline; this cohort had no product before v2 |
| Red-flag prompt dismissal rate | <80% dismiss without "Learn more" | High dismissal = alarm fatigue; adjust copy |
| Onboarding completion (new branch) | >70% for non-period path | Measures cold-start onboarding quality |
| Logging reminder opt-out rate | <25% turn reminders off | High opt-out = wrong interval or irrelevant copy |
| Logging reminder suppression rate | >60% of scheduled reminders cancelled before firing | Measures whether conditional logic is working — high suppression = users logging before nudge fires |
| Day 14 retention lift (reminder vs no-reminder cohort) | +5pp | Leading indicator of habit formation |
| Accessibility: VoiceOver flow completion | All primary flows navigable | Validated in internal testing |

### Privacy verification (every release, unchanged)
- [ ] Network proxy test: zero outbound connections
- [ ] Binary analysis: no new third-party SDKs
- [ ] `PrivacyInfo.xcprivacy`: accurate and complete
- [ ] App Store nutrition label: reviewed and accurate
- [ ] GSM module: second-auth gate verified
- [ ] Confirm no file export path exists anywhere in codebase (PDFKit, FileManager writes to shared containers, UIActivityViewController with health data)

---

## 11. Out of Scope for v2

The following are explicitly deferred:

- **On-device ML inference** (drift detection, symptom clustering, intervention effect estimation) — requires v2 data to accumulate first; planned for v3
- **BBT logging, cervical mucus, OPK** — still deferred; not part of the life-stage expansion
- **Population benchmarking** — requires privacy-preserving aggregate infrastructure; v3+
- **Cloud sync or backup** — fundamentally incompatible with privacy model
- **Any data export** (PDF, CSV, JSON) — cancelled; see §6.6
- **Partner or support sharing** — cancelled; see §6.6
- **Android** — iOS-only
- **Medication dosage tracking** — requires clinical partner; see project memory note
- **Contraceptive efficacy claims** — will never be in scope
- **FHIR or health record integration** — out of scope and triggers HIPAA exposure as a business associate
- **Automatic life-stage inference from data** — deferred to v3; v2 is user-declared only

---

*PRD v2 draft — Clio Daye — 2026-04-10*
