# SafeFlow — Product Requirements Document

**Version:** 1.0
**Status:** Draft
**Date:** 2026-03-29
**Author:** Product / Engineering

---

## Table of Contents

1. [Product Vision](#1-product-vision)
2. [Strategic Context](#2-strategic-context)
3. [User Research & Personas](#3-user-research--personas)
4. [Current State Assessment](#4-current-state-assessment)
5. [Product Principles](#5-product-principles)
6. [Feature Roadmap](#6-feature-roadmap)
7. [Detailed Feature Specifications](#7-detailed-feature-specifications)
8. [Algorithm Specification](#8-algorithm-specification)
9. [Data Model Evolution](#9-data-model-evolution)
10. [Privacy & Legal Framework](#10-privacy--legal-framework)
11. [Success Metrics](#11-success-metrics)
12. [Out of Scope](#12-out-of-scope)

---

## 1. Product Vision

**SafeFlow is the cycle tracking app for people who have decided they will never trust another app with this data.**

Every major cycle tracking app has either been caught sharing intimate health data with advertisers (Flo, $56M settlement in 2025), requires a cloud account, or treats users as a data asset. SafeFlow's entire reason to exist is the opposite: your data never leaves your device, full stop — no account, no server, no subpoena surface.

That privacy guarantee only matters if the app is worth using. The v2+ vision is to be the most useful, most honest, and most enjoyable cycle tracking experience available on iOS — while maintaining the architectural constraint that no user data ever touches a network.

**One-line pitch:** The cycle tracking app that actually earns your trust — because it can never betray it.

---

## 2. Strategic Context

### The Market Moment

The Dobbs decision (2022) and the subsequent Flo Health settlement ($56M, 2025) have created a genuine window for a privacy-first competitor. Approximately 73% of period tracking apps share personal health data with third parties. As of 2025, 16 major apps explicitly state in their privacy policies that they may comply with law enforcement subpoenas. This is not a theoretical concern — abortion prosecutions are actively underway in restrictive states.

Users are aware of this. Search volume for "private period tracker" and "period app no cloud" has grown materially post-Dobbs. There is a growing segment of users who will choose the privacy-first option even if it has fewer features, because the alternative is unacceptable.

### Competitive Positioning

| App | Privacy | Prediction Quality | UX | Price |
|---|---|---|---|---|
| **Flo** | Poor (settled $56M) | Good | Good | Freemium |
| **Clue** | Moderate (EU servers) | Good | Good | Freemium |
| **Apple Health** | Good (on-device) | Basic | Generic | Free |
| **Natural Cycles** | Good | Excellent (FDA-cleared) | Functional | $99/yr |
| **Drip / Euki** | Excellent (on-device) | Poor | Poor | Free |
| **SafeFlow (target)** | Excellent (on-device) | Great | Excellent | Free/Premium |

**The gap SafeFlow fills:** Privacy-first + genuinely good predictions + a daily experience people actually want. No one owns this position today.

### Legal & Regulatory Context

- **HIPAA does not apply** to period tracking apps. SafeFlow is not a covered entity.
- **California CMIA (effective Jan 1, 2024)** and **Washington My Health My Data Act** effectively treat cycle tracking apps as health care providers in those states. SafeFlow's on-device architecture is compliant by design.
- **On-device storage is the strongest available legal protection.** If SafeFlow holds zero server-side user data, there is nothing to subpoena.
- **Do not make any contraceptive efficacy claim.** This triggers FDA Class II medical device regulation (Natural Cycles pathway: 15,000-person clinical trial required). SafeFlow is a wellness tracking tool.
- **No third-party SDKs with network access.** One analytics SDK or crash reporter with user identifiers would invalidate the entire privacy claim. This is a hard architectural constraint.

---

## 3. User Research & Personas

### Why People Track

- **Cycle awareness (61%):** Understanding their body, predicting periods, managing symptoms
- **Trying to conceive (TTC):** Timing intercourse, identifying fertile window
- **Avoiding pregnancy (underreported):** Using cycle data alongside other methods
- **Health monitoring:** Identifying PCOS, endometriosis, perimenopause patterns, discussing with doctors

### Why People Stop Tracking

1. Inaccurate predictions — especially for irregular cycles
2. Logging fatigue — too many steps, no payoff visible
3. Data privacy concerns — discovered their data was sold
4. App assumes who they are — heteronormative language, pregnancy-push UX
5. No insight loop — they log but never learn anything from it

### Primary Personas

**Persona 1 — Maya, 28 (Privacy Refuser)**
Works in tech, heard about the Flo settlement. Was using Clue but uncomfortable with EU server storage. Wants to understand her cycle, gets irregular periods (25–34 day range), finds single-date predictions useless. Will pay for something that works and doesn't surveil her. Frustrated by condescending "floral" app aesthetics.

**Persona 2 — Jordan, 32 (TTC, 6 months in)**
Actively trying to conceive. Using OPK strips. Wants to know her fertile window. Frustrated that most free apps give a generic ±3 day estimate. Willing to log BBT if it helps. Privacy-conscious because she doesn't want her fertility journey tracked by advertisers.

**Persona 3 — Sam, 24 (Daily habit builder)**
Just wants to know when her period is coming and log symptoms for her doctor. Not a data nerd. Needs the daily logging to take 10 seconds or she won't do it. Wants the app to feel good to open, not clinical.

**Persona 4 — Priya, 44 (Perimenopause transition)**
Cycles becoming irregular, 40–60 day range. Existing apps constantly show error states or nonsensical predictions. Wants a tool that honestly says "we have high uncertainty" instead of confidently predicting wrong dates. Needs a specialist mode that acknowledges her situation.

---

## 4. Current State Assessment

### What v0.1-alpha Has

- On-device storage (UserDefaults + Keychain) — correct foundation
- PIN + Face ID/Touch ID authentication
- Basic cycle logging: flow intensity, 5 symptoms, 5 moods, notes
- Simple moving average prediction
- Calendar view
- Recent logs list

### What's Broken or Inadequate

**Algorithm:**
- Equal-weight moving average — recent cycles should matter more
- Returns a single date with no uncertainty window — clinically misleading for irregular cycles
- 3-day gap rule for period detection is fragile (spotting can trigger false period start)
- Never uses the luteal phase constant (≈14 days) for ovulation estimation
- Ignores all symptom and mood data entirely

**Test data:**
- `irregular_cycle.csv` contains impossible dates ("Jan 35") — parser produces wrong results
- `irregular_cycle.csv` has `"stressed"` as a mood value — not in the enum
- Only 3 test scenarios; no coverage of: <2 periods, very short/long cycles, perimenopause, post-pregnancy return
- No test for the prediction range (only point predictions tested)

**Daily logging UX:**
- Form-based entry: 6+ interactions for a basic log
- Segmented pickers and toggle switches on gray backgrounds — clinical, not personal
- 5 symptoms is inadequate (no back pain, acne, discharge, energy, libido, temperature)
- 5 moods is inadequate and generic — doesn't reflect the real emotional range of cycle phases
- No differentiation between "period day" (the primary signal) and the richer symptom/mood layer

**Home screen:**
- Shows "Next Period Prediction" but no cycle phase context — user doesn't know where they are *today*
- No fertile window or ovulation estimate
- No insights from logged data
- Prediction card shows a single date with no range

**Onboarding:**
- 3 pages but collects nothing useful — doesn't ask when last period was, which means the app is blind on first use
- Security setup is prominent; cycle setup is absent

---

## 5. Product Principles

1. **Privacy is non-negotiable, not a feature.** No network calls. No third-party SDKs. No analytics. The architecture enforces the promise.

2. **Log in 5 seconds or lose the habit.** The most common daily action — marking a period day — must be 1–2 taps from the home screen. Full symptom/mood detail is available but never required.

3. **Honest over precise.** Show a prediction range, not a false single date. Tell high-variability users their predictions are less certain. Never claim more accuracy than the data supports.

4. **Phase context over countdown.** "Day 18 of your cycle — ovulation likely in the past 2 days" is more useful than "your period is in 10 days." Help users understand where they are, not just what's coming.

5. **Insight closes the loop.** Logging only builds a habit if it returns value. Show patterns back to users. Connect their symptoms to their cycle phase. Make the data work for them.

6. **Inclusive by default.** No assumption of pregnancy desire, no assumption of partnership, no gender-normative language that excludes trans and non-binary users.

7. **Never make a contraceptive claim.** This protects users (who should not rely on this app for contraception) and protects SafeFlow (avoids FDA Class II device pathway).

---

## 6. Feature Roadmap

### v0.2 — Foundation Fix (Current sprint target)
*Make the core loop work well before adding anything new.*

- [ ] Quick-log flow: period start / ongoing / no period in 2 taps from home screen
- [ ] Cycle phase display on home screen (menstrual / follicular / ovulatory / luteal)
- [ ] Prediction range instead of single date ("Expected March 12–16")
- [ ] Weighted recency in prediction algorithm
- [ ] Onboarding cycle setup: ask for last period start date
- [ ] Fix test datasets (impossible dates, invalid enum values)
- [ ] Accessibility identifiers on all interactive elements
- [ ] Richer mood options (10 options, emoji-forward)

### v0.3 — Cycle Intelligence
*Add the features that make SafeFlow meaningfully better than Apple's built-in.*

- [ ] Fertile window estimation (follicular phase calculation: cycle length − 14)
- [ ] Ovulation prediction display
- [ ] Prediction confidence indicator (regular vs. irregular cycle users)
- [ ] Expanded symptom tracking (15 symptoms across 4 categories)
- [ ] Symptom-to-phase correlation insights ("You often log cramps on Day 1")
- [ ] Cycle statistics view: average length, variability, shortest/longest
- [ ] Population prior for new users (<3 cycles: show 29-day default with disclaimer)

### v0.4 — Daily Experience
*Make the app genuinely enjoyable to open every day.*

- [ ] Redesigned home screen with cycle phase visualization
- [ ] Phase-contextual content cards ("Follicular phase: energy typically rises this week")
- [ ] Smart notification: conditional reminder only if user hasn't logged today
- [ ] Widget: cycle phase + days until next period (no health data on lock screen)
- [ ] Recent trend display: last 3 cycles at a glance
- [ ] Export: generate PDF/CSV of cycle data for sharing with healthcare provider

### v0.5 — Advanced Tracking
*For power users and specific health goals.*

- [ ] BBT logging (manual entry; no hardware integration required for v1)
- [ ] Cervical mucus tracking (educational framing, not contraceptive)
- [ ] Spotting distinct from period flow (separate from FlowIntensity)
- [ ] Irregular cycle mode: wider prediction windows, explicit uncertainty messaging
- [ ] Perimenopause mode: adjusted parameters, longer cycle support (up to 60 days)
- [ ] PCOS-aware mode: flags extremely long/absent cycles without alarming
- [ ] OPK result logging (positive/negative LH test)

### v1.0 — Full Product
*The complete experience that competes head-to-head with Clue/Flo on features while winning on privacy.*

- [ ] Cycle journal: free-form daily notes with phase tagging
- [ ] Health report: shareable summary for OB/GYN appointments
- [x] ~~Partner/support sharing (on-device generated QR code, no cloud, time-limited)~~ — CANCELLED 2026-04-10, see PRD-v2 §6.6
- [ ] Cycle history: multi-year visualization
- [ ] Medication/supplement logging (birth control, vitamins)
- [ ] Premium tier (optional, no feature gating on core tracking)

---

## 7. Detailed Feature Specifications

### 7.1 Quick Log (v0.2 Priority)

**Problem:** The current flow requires opening a form sheet, selecting from segmented pickers, and tapping save. This is 6+ interactions for the most common action: marking a period day.

**Solution:** A persistent quick-action area on the home screen.

**Spec:**

The home screen shows a cycle phase card at the top. Within that card, or immediately below it, is a "Log Today" area with three large, tap-target-optimized buttons:

- **"Period started"** — marks today as Day 1 of a new period with Light flow. Opens optional detail sheet.
- **"Still flowing"** — marks today as an ongoing period day, inheriting last day's flow intensity. One tap, done.
- **"No period"** — explicitly marks today as a non-period day. Optional: opens feeling/symptom quick-pick.

Tapping any of these completes a valid log in one tap. The full detail form (flow intensity, symptoms, moods, notes) is accessible from the resulting log card if the user wants to add more.

**Flow for "Still flowing":**
1. User taps "Still flowing"
2. Haptic confirmation
3. Log card updates to show today's entry
4. Done — no sheet, no form

**Flow for "Period started":**
1. User taps "Period started"
2. Optional bottom sheet slides up: "How heavy?" with 4 large buttons (Spotting / Light / Medium / Heavy)
3. User taps flow or dismisses (defaults to Light)
4. Done

**Design guidance:**
- Buttons should be large, rounded, and use the app's color system — not gray toggle switches
- The three states should feel like cards, not a form
- Consider using SF Symbols with labels: `drop.fill` for flow, `checkmark.circle` for no period

---

### 7.2 Cycle Phase Display (v0.2 Priority)

**Problem:** The home screen shows a future date but nothing about today.

**Solution:** Replace the "Next Period Prediction" card header with a cycle phase display that answers "where am I today?"

**Phase calculation:**

Given: predicted cycle length C, last period start date D, today T.

```
days_since_period_start = days between D and T

if days_since_period_start < period_length (default 5):
    phase = Menstrual
    display = "Day {days_since_period_start + 1} of your period"

else if days_since_period_start < (C - 16):
    phase = Follicular
    display = "Follicular phase · Day {days_since_period_start + 1}"

else if days_since_period_start < (C - 12):
    phase = Ovulatory
    display = "Ovulation window · Day {days_since_period_start + 1}"

else:
    phase = Luteal
    display = "Luteal phase · Day {days_since_period_start + 1}"
```

**Display:**

The phase card shows:
- Phase name and cycle day number (large, prominent)
- A simple cycle arc/ring visualization showing position in the cycle
- Sub-text: one relevant phase characteristic ("Energy typically rises during the follicular phase")
- Days until next period (smaller, secondary)
- Prediction range: "Next period expected April 8–12"

**Phase characteristics copy (one line per phase):**

| Phase | Copy |
|---|---|
| Menstrual | "Rest if you can. Your body is doing real work." |
| Follicular | "Energy typically builds. Good time for new projects." |
| Ovulatory | "Often the highest-energy point of your cycle." |
| Luteal | "Energy may dip toward the end of this phase." |

These are factual, evidence-based, and non-prescriptive. They are not personalized medical advice.

---

### 7.3 Prediction Range (v0.2 Priority)

**Problem:** A single predicted date creates false precision and erodes trust when wrong.

**Solution:** Show a range based on individual cycle variability.

**Spec:**

If the user has ≥ 3 cycles of data:
- Calculate the standard deviation of their cycle lengths (σ)
- Prediction range = predicted date ± ceil(σ / 2) days
- Display: "Expected April 8–12" (5-day window for σ = 4 days)

If the user has 2 cycles:
- Use a fixed ±3 day range (conservative default)
- Display: "Expected April 8–14 · Building accuracy"

If the user has < 2 cycles:
- Use the population mean (29 days) as the cycle length
- Display: "Expected around April 10 · Estimated from typical cycles · Log more periods for personalized predictions"

**Variability indicator:**

For high-variability users (σ > 7 days, matching population 1 SD):
- Show a wider range
- Add a note: "Your cycles vary — this is a wider estimate than average"
- Never hide the uncertainty or show a false single date

---

### 7.4 Richer Mood Tracking (v0.2)

**Problem:** 5 generic moods (happy, neutral, sad, anxious, irritable) don't capture the real emotional texture of cycle phases.

**Solution:** Expand to 12 moods with emoji, organized by valence.

**New mood options:**

| Mood | Emoji | When it peaks |
|---|---|---|
| Energized | ⚡️ | Follicular / Ovulatory |
| Happy | 😊 | Follicular |
| Confident | 💪 | Ovulatory |
| Calm | 😌 | Early Luteal |
| Focused | 🎯 | Follicular |
| Neutral | 😐 | Any |
| Foggy | 🌫️ | Menstrual / Late Luteal |
| Tired | 😴 | Menstrual / Late Luteal |
| Sensitive | 🥺 | Late Luteal |
| Anxious | 😰 | Late Luteal |
| Irritable | 😤 | Late Luteal / PMS |
| Sad | 😢 | Late Luteal / PMS |

**UX:** Display as a 4-column grid of emoji + label buttons. Tap to select (single select). Much faster and more expressive than a segmented picker. No gray form background — use a card with the pale yellow from the theme.

---

### 7.5 Expanded Symptom Tracking (v0.3)

**Problem:** 5 symptoms is far below the clinical and competitive standard (Clue tracks 200+; even a focused tracker should handle 15–20).

**Solution:** 15 symptoms organized into 4 categories. Multi-select.

**Categories and symptoms:**

**Flow & Physical**
- Cramps (existing)
- Back pain
- Headache (existing)
- Bloating (existing)
- Breast tenderness (existing)
- Acne / skin changes

**Energy & Wellbeing**
- Fatigue (existing)
- Insomnia / poor sleep
- High energy
- Brain fog

**Appetite**
- Food cravings
- Nausea
- Appetite changes

**Cycle Indicators** *(visible only when not in period)*
- Discharge changes
- Mid-cycle cramp (mittelschmerz — possible ovulation indicator)

**UX:** Symptom picker as a horizontally-scrolling tab across the 4 categories, with symptom chips (rounded rectangle buttons) in each category. Tapped = filled/selected. Not toggle switches.

---

### 7.6 Fertile Window & Ovulation (v0.3)

**Algorithm:** Estimated ovulation day = last period start + (average cycle length − 14).
Fertile window = ovulation day − 5 through ovulation day.

**Display:**
- On the cycle arc visualization: a distinct color zone for the fertile window
- On the calendar: a distinct color or pattern for fertile window days
- Phase card text during fertile window: "Fertile window · Ovulation likely around [date]"

**Critical disclaimer (always visible when fertile window is shown):**
> "This estimate is for cycle awareness only. Do not use this app for contraception or family planning without speaking to a healthcare provider."

This disclaimer is non-negotiable. It protects users and keeps SafeFlow outside FDA medical device regulation.

---

### 7.7 Onboarding Cycle Setup (v0.2)

**Problem:** Current onboarding collects security preferences but no cycle data. The app is completely blind on first launch.

**Solution:** Add a fourth onboarding page: "Let's set up your cycle."

**Page 4 — Cycle Setup:**

"When did your last period start?"
→ Date picker (wheel or calendar; default: 28 days ago)

"How long does your period usually last?"
→ Stepper: 3 / 4 / 5 / 6 / 7 days (default: 5)

"How long is your cycle usually? (first day of period to first day of next period)"
→ Stepper or slider: 21–45 days (default: 28)
→ Sub-text: "Don't know? Leave as 28 — we'll learn from your data."

"Skip for now" remains an option but is de-emphasized.

**What this enables:**
- Immediate cycle phase display on Day 1
- A reasonable first prediction before any data is logged
- Reduces the "app feels empty" first-launch problem

---

### 7.8 Smart Notification (v0.4)

**Spec:** A single daily notification, conditional on whether the user has already logged today.

- Fires at a user-configurable time (default: 8pm)
- **Does not fire** if the user has already logged today
- During the predicted period window (3 days before through 7 days after predicted start): "Period expected soon — want to log today?"
- Outside period window: "How are you feeling today?" (generic)
- During logged period: "Still flowing? Tap to log." with an inline iOS notification action

**What we do not do:**
- No daily fixed-time notifications regardless of logging status (drives churn)
- No push notification infrastructure (everything is local notifications — `UNUserNotificationCenter`)
- No server-side trigger — all scheduling is done on-device, recalculated when predictions update

---

### 7.9 Data Export — CANCELLED (2026-04-10)

> **This feature is cancelled and must not be implemented.** Any export mechanism — PDF, CSV, or partner sharing — creates a path for intimate health data to leave the device and enter environments Clio Daye cannot control. In a post-Dobbs legal environment this is an unacceptable risk to users. The in-app appointment summary view (PRD v2 §6.6) is the on-screen alternative that delivers clinical value without creating a file. See PRD-v2.md §6.6 for full rationale.

### 7.9 Data Export (v1.0) — original spec, superseded

Users should be able to export their data in two formats:

**Healthcare export (PDF):**
- Last 6–12 months of cycle data
- Average cycle length and variability
- Symptom frequency by phase
- Mood patterns
- Formatted for sharing with a gynecologist or GP
- Generated entirely on-device using PDFKit; no upload

**Raw export (CSV/JSON):**
- Full CycleDay records
- Useful for backup or import to another app
- Encrypted ZIP optionally protected by PIN

---

## 8. Algorithm Specification

### Current Algorithm (v0.1)

Simple moving average of all historical cycle lengths, equal weights. Returns single predicted date. Requires ≥ 2 completed periods.

**Problems:** Equal weighting ignores recency. No uncertainty quantification. 3-day gap rule for period detection is fragile. Never uses luteal phase constant.

---

### Target Algorithm (v0.2 — Weighted Recency + Range)

**Period detection improvement:**

A period start requires:
- A day with `flow != nil` that is either the first recorded flow day, OR
- Follows a gap of > 3 days from the last flow day, AND
- Is not isolated (the day itself or the next day also has flow)

This prevents single-day spotting from being counted as a period start.

**Weighted moving average:**

Given N completed cycle lengths [c₁, c₂, ..., cₙ] ordered oldest to newest:

```
weights = [1, 2, 3, ..., N]  (linear recency weighting)
weighted_average = sum(cᵢ × wᵢ) / sum(wᵢ)
```

Use the last 6 cycles maximum. Older cycles are dropped, not down-weighted to zero — this prevents a single anomalous cycle from having permanent influence.

**Population prior for new users:**

If fewer than 2 completed periods exist, use population mean of 29.1 days as the cycle length. Display this explicitly to the user: "Based on typical cycles · Log more periods for personalized predictions."

**Prediction range:**

If ≥ 3 cycles: range = ±ceil(σ/2) where σ = standard deviation of the last 6 cycle lengths.
If 2 cycles: range = ±3 days (conservative fixed).
If < 2 cycles: range = ±5 days (population σ approximation).

**Ovulation estimate:**

```
estimated_ovulation = last_period_start + (predicted_cycle_length - 14)
fertile_window_start = estimated_ovulation - 5
fertile_window_end = estimated_ovulation
```

The luteal phase is treated as a constant 14 days, consistent with clinical research showing luteal phase variability is low (SD ≈ 1–2 days) compared to follicular phase variability.

---

### Future Algorithm (v0.5+ — Symptom-Aware)

Once users have logged symptoms across multiple cycles, introduce:

**Phase-symptom correlation:**
- For each symptom, calculate the average cycle day it appears across all logged cycles
- Display back: "You typically log cramps on Days 1–2 of your period"
- This is insight display, not prediction input

**Symptom-based early warning (v0.5):**
- If a user consistently logs specific symptoms (e.g., breast tenderness, irritability) 2–3 days before flow starts, track the average lead time
- Incorporate this into period prediction as a soft signal: "Based on your symptom pattern, your period may start in 2 days"

**BBT-aware prediction (v0.5, requires BBT logging):**
- Post-ovulation temperature rise retrospectively confirms ovulation
- Use confirmed ovulation day to back-calculate that cycle's actual luteal phase length
- This produces a per-user luteal phase estimate more accurate than the 14-day constant

---

### Algorithm Test Coverage (Required)

The following test scenarios must be covered before any algorithm change ships:

| Scenario | Cycles | Expected Behavior |
|---|---|---|
| Regular 28-day | 3+ | Prediction within ±1 day, narrow range |
| Regular but short (21-day) | 3+ | Ovulation day ≈ Day 7 |
| Regular but long (35-day) | 3+ | Ovulation day ≈ Day 21 |
| Irregular (22–34 day range) | 4+ | Wide range shown, uncertainty communicated |
| Sparse (1 logged period) | 1 | Population prior used, explicitly disclosed |
| New user (0 periods) | 0 | Population prior, no prediction shown |
| Single-day spotting mid-cycle | 2+ | Spotting NOT counted as period start |
| Post-pregnancy return | Special | First cycle after gap treated as new baseline |
| Very long cycle (45–60 days) | 2+ | Perimenopause mode; no false "not enough data" error |

---

## 9. Data Model Evolution

### Current Model (v0.1)

```swift
struct CycleDay {
    let id: UUID
    let date: Date
    var flow: FlowIntensity?      // light, medium, heavy, spotting
    var symptoms: Set<Symptom>    // 5 options
    var mood: Mood?               // 5 options
    var notes: String?
}
```

### v0.2 Target Model

```swift
enum FlowIntensity: String, Codable, CaseIterable {
    case spotting, light, medium, heavy
    // no change — order fixed to light→heavy for UI
}

enum Symptom: String, Codable, CaseIterable {
    // existing 5
    case cramps, headache, fatigue, bloating, breastTenderness
    // new in v0.2
    case backPain, acne, insomnia, highEnergy, brainFog
    case foodCravings, nausea, appetiteChanges
    case dischargeChanges, mittelschmerz
}

enum Mood: String, Codable, CaseIterable {
    case energized, happy, confident, calm, focused
    case neutral
    case foggy, tired, sensitive, anxious, irritable, sad
}
```

**Migration:** `CycleDay` stores symptoms as `Set<Symptom>` and mood as `Mood?`. Adding new enum cases is additive and backward compatible for Codable serialization — existing stored values decode correctly, new values simply aren't present in old records.

### v0.3 Additions

```swift
struct CycleDay {
    // existing fields...
    var cervicalMucus: CervicalMucusType?  // dry, sticky, creamy, eggWhite
    var isSpotting: Bool                    // distinct from flow (mid-cycle spotting)
    var temperatureCelsius: Double?         // BBT in Celsius, nil if not logged
    var opkResult: OPKResult?              // positive, negative, nil
}

enum CervicalMucusType: String, Codable {
    case dry, sticky, creamy, eggWhite
}

enum OPKResult: String, Codable {
    case negative, positive
}
```

### CycleStore New Methods (v0.2)

```swift
// Returns the predicted cycle phase for today
func currentPhase() -> CyclePhase

// Returns the fertile window as a date range, or nil if insufficient data
func fertileWindow() -> DateInterval?

// Returns estimated ovulation date
func estimatedOvulationDate() -> Date?

// Returns prediction as a range, not a single date
func predictNextPeriodRange() -> (earliest: Date, latest: Date)?

// Returns per-user cycle variability (standard deviation of cycle lengths)
func cycleVariability() -> Double?

// Returns average symptom occurrence by cycle day (for insight display)
func symptomPatterns() -> [Symptom: Double]  // symptom → average cycle day
```

---

## 10. Privacy & Legal Framework

### Hard Architectural Constraints (Non-Negotiable)

These are not features — they are the foundation of SafeFlow's entire value proposition. They must be verified at every release.

1. **Zero network calls.** No URLSession usage anywhere in the app. No third-party SDKs that make network calls. Verify with a proxy/network monitor before each release.

2. **No third-party analytics or crash reporting.** MetricKit (Apple's on-device, privacy-preserving performance framework) is acceptable. Firebase, Mixpanel, Amplitude, Crashlytics, Sentry — none of these.

3. **No CloudKit or iCloud sync.** Even Apple's own sync service creates a server-side copy of data.

4. **No app review or rating prompts via third-party SDKs.** Use `SKStoreReviewController` (Apple-native, no data leaves device).

5. **Local notifications only.** `UNUserNotificationCenter` — all notification scheduling on-device, no push notification server.

### User-Facing Privacy Commitments

The privacy page in onboarding should clearly state:

- All data is stored on this device only
- SafeFlow has no servers, no accounts, no cloud storage
- We cannot access your data — it is physically impossible
- Deleting the app permanently deletes all data
- We will never sell your data because we never have it

### Legal Disclaimer (Required)

The following disclaimer must appear in Settings and in the onboarding fertility window section:

> "SafeFlow is a wellness tracking app, not a medical device. Cycle predictions are estimates based on historical data. Do not use SafeFlow for contraception or reproductive health decisions without consulting a qualified healthcare provider."

### Export & Deletion

- **Export:** User-initiated only, generates local file, never uploads
- **Deletion:** Deleting the app deletes all data. Provide an explicit "Delete all data" option in Settings as well (for users who want to delete before reselling a device).
- **Backup:** Not provided — this is by design. If users want backup, they can use iOS's encrypted device backup (which encrypts the UserDefaults store). Document this in the FAQ.

---

## 11. Success Metrics

### North Star

**7-day logging streak rate at Day 30** — the percentage of users who, at day 30 after install, have logged at least 7 of the last 7 days. This metric directly captures whether the app has become a daily habit. Target: 35% (vs. typical fitness app 12% Day 14 retention).

### Engagement Metrics

| Metric | v0.2 Target | v1.0 Target |
|---|---|---|
| Day 1 retention | 70% | 80% |
| Day 30 retention | 30% | 45% |
| 7-day streak at Day 30 | 20% | 35% |
| Average logs per active user per week | 3 | 5 |
| Onboarding completion rate | 75% | 85% |
| Logs with ≥ 1 symptom | 40% | 55% |

*Note: All engagement metrics are measured on-device via MetricKit or a privacy-preserving local counter. No individual-level data leaves the device. Aggregate metrics only, if reported at all.*

### Quality Metrics

| Metric | Definition | Target |
|---|---|---|
| Prediction accuracy | % of actual period starts within predicted range | >70% for regular-cycle users |
| False period starts | Days where spotting triggered incorrect period start | <5% of logged spotting days |
| Crash-free sessions | Standard iOS stability metric | >99.5% |

### Privacy Verification (Every Release)

- [ ] Network proxy test: zero outbound connections during any user flow
- [ ] App binary analysis: no third-party SDKs with network entitlements
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`): accurate and complete
- [ ] App Store privacy nutrition label: reviewed and accurate

---

## 12. Out of Scope

The following are explicitly not in scope for any version planned here. They would require architectural changes that compromise the privacy model or are outside the product focus:

- **Cloud sync / multi-device support.** Fundamentally incompatible with the privacy model.
- **Social / community features.** Same reason.
- **Contraceptive efficacy claims.** Requires FDA clinical trial pathway.
- **BBT hardware integration** (Oura Ring, etc.). Requires network/Bluetooth data handling that needs careful scoping (v0.5 consideration only for manual BBT entry).
- **AI/ML on-device inference** (Foundation Models / Core ML). Possible future direction for symptom pattern analysis but not planned.
- **Android version.** iOS-only for the foreseeable future.
- **Prescription or medical record integration.** Outside scope and potentially triggers HIPAA as a business associate.

---

---

## 12. Cycle Mode Backlog (Post-v1.0)

These items emerged from the "Day 43 / Late label" design discussion (2026-04-01). They are not in scope for v0.x or v1.0 but should be designed together as a cohesive "cycle mode" system before implementation.

### 12.1 Cycle Mode Setting

A single opt-in in onboarding and Settings that adapts the entire prediction + insight layer:

| Mode | Behaviour |
|------|-----------|
| **Regular** | Current behaviour. Day counter, predictions, variability nudges. |
| **Irregular** | Suppress day counter when overdue. Widen prediction range. Suppress repeated variability nudges (fire at most once per 6 cycles). Surface GP/irregular resources proactively. |
| **Perimenopause** | Suppress day counter entirely. Suppress all variability nudges. Replace prediction with "cycles may be irregular" copy. Surface perimenopause-specific resources. |
| **Not currently cycling** | Post-partum, breastfeeding amenorrhea, medically induced pause. Suppress predictions entirely. Keep symptom/mood logging. No nudges about missing periods. |

### 12.2 Design Principles for Cycle Mode

- **User-declared, not inferred.** The app never infers mode from data. The user sets it. This avoids pregnancy inference, perimenopause inference, and any associated regulatory/trauma risk.
- **Easily changeable.** One tap in Settings to switch mode. No friction, no confirmation dialogs.
- **No pregnancy inference, ever.** Clio Daye does not prompt users to take a test, infer pregnancy from a missed period, or change UI in response to a late cycle beyond widening the prediction range.
- **"Cycle pause" for grief-aware contexts.** Users post-miscarriage or post-loss may want to keep logging symptoms without cycle predictions running. Cycle pause is the mechanism — opt-in, no explanation required.

### 12.3 Immediate Fix Already Applied (v0.3)

The "· Late" label added to `CyclePhaseCard` was removed before shipping. The day counter now returns `nil` when beyond average cycle length, and the card shows the phase name only — no inference language. This is the correct minimal behaviour until cycle modes are implemented.

---

*PRD v1.0 — SafeFlow — 2026-03-29 | Section 12 added 2026-04-01*
