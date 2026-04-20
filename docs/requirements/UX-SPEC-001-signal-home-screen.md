# UX-SPEC-001 — Signal Card and Stage-Adaptive Home Screen

**Status:** Draft — ready for review  
**Feature:** SignalCard + home screen content adaptation for peri/meno stages  
**Depends on:** v2-feature-narrative.md §5.3, SignalEngine (Sources/Services/Signal/SignalEngine.swift)  
**Blocks:** SignalCard view implementation, HomeView stage-adaptive content

---

## 1. Context

The v2 home screen must tell a different story for each life stage. For regular/irregular users, the existing home (PulseView → phase card → forecast → calendar) is unchanged. For perimenopause and menopause users, the narrative shifts from "where am I in my cycle?" to "what's been happening and what does it mean?"

The SignalEngine already computes this. SignalCard is its voice on screen — the one component that turns `SignalResult` into a plain-language observation the user can read in under 10 seconds.

This spec covers:
- SignalCard visual design and copy spec
- Home screen scroll order per life stage
- Component-level behaviour changes (what's shown, what's hidden, what changes label)
- State handling (learning state, no baseline, edge cases)
- Interaction model
- Dynamic Type and accessibility requirements

---

## 2. Current Home Screen (reference baseline)

From screenshots and HomeView.swift — the actual current scroll order for a regular user:

```
PulseView
  ├── CategoryStripView (left)        ← category selector
  ├── DartboardView (segments)        ← symptom/mood logging
  └── FlowStepSlider                  ← flow intensity

PhaseCard / ForecastView              ← "Ovulation Window, Day 15"
CycleRingSummaryCard header
CycleCalendarView                     ← period + fertile bar chart
```

Nav bar: 🐞 ⚙️ (leading) — "Clio Daye" title — 📄 📅 ❤️ (trailing)

---

## 3. SignalCard — Visual Design

### 3.1 Card anatomy

```
┌─────────────────────────────────────────┐
│  ●  This month                          │  ← header row
│                                         │
│  Hot flashes on 18 days — more than     │  ← primary sentence
│  any month so far.                      │
│                                         │
│  ↑ Sleep getting worse   ↓ Stress high  │  ← trend pills (2 max)
│                                         │
│  Tap to see your full month  →          │  ← footer link
└─────────────────────────────────────────┘
```

**Card dimensions:** Full-width card, standard 16pt horizontal margin, standard AppTheme corner radius (16pt), standard card background (secondary fill, matches existing BleedHistoryCard/SymptomSnapshotCard style).

**Header row:**
- Left: filled circle (8pt), colour-coded by month character (see §3.2)
- Left text: `"This month"` — `.caption` weight `.semibold`, `AppTheme.Colors.mediumGrayText`
- Right: nothing (no chevron on header — interaction is on footer link)

**Primary sentence:**
- `.body` / SF Pro Rounded
- `AppTheme.Colors.deepGrayText`
- Max 2 lines — if the sentence truncates at 2 lines it must be rewritten, not truncated
- The sentence is the most important thing on the card. It must stand alone.

**Trend pills:**
- Horizontal stack, max 2 pills
- Each pill: system image (`arrow.up`, `arrow.down`, `minus`) + short label
- Pill style: `.caption2`, background `AppTheme.Colors.secondaryBackground.opacity(0.6)`, corner radius 8
- Colour: escalating = `AppTheme.Colors.softPink.opacity(0.8)`, improving = `AppTheme.Colors.accentBlue.opacity(0.8)`, stable = `AppTheme.Colors.mediumGrayText.opacity(0.4)`
- Only shown when signal has trend data; omitted entirely (not placeholder) if no trends

**Footer link:**
- `"Tap to see your full month →"` — `.caption`, `AppTheme.Colors.accentBlue`
- Taps to `MonthlySummaryView` (not yet built; placeholder for v2.0)
- If `MonthlySummaryView` does not exist: footer link is hidden

---

### 3.2 Month character → accent colour

The coloured dot on the header communicates the overall direction of the month at a glance.

| MonthCharacter | Dot colour | Meaning shown |
|---|---|---|
| `.notablyHarder` | `AppTheme.Colors.softPink` | harder month |
| `.slightlyHarder` | `AppTheme.Colors.softPink.opacity(0.6)` | slightly harder |
| `.comparable` | `AppTheme.Colors.mediumGrayText.opacity(0.5)` | similar month |
| `.slightImprovement` | `AppTheme.Colors.accentBlue.opacity(0.6)` | improving |
| `.notableImprovement` | `AppTheme.Colors.accentBlue` | notably better |
| `.noComparison` | clear / no dot | (no dot shown) |

**Rule:** Colour provides supplementary information — the primary sentence must convey the same meaning in words. Never rely on the dot alone.

---

### 3.3 Learning state

When `SignalEngine` returns `.learning(daysLogged:)`, the card shows a distinct placeholder:

```
┌─────────────────────────────────────────┐
│  Building your picture                  │  ← heading, .subheadline semibold
│                                         │
│  Keep logging. After 7 days Signal      │  ← .body
│  will show you what's happening.        │
│                                         │
│  ████████░░░░░░░░  N of 7 days          │  ← progress bar + count
└─────────────────────────────────────────┘
```

- Progress bar: filled up to `daysLogged / 7`, `AppTheme.Colors.accentBlue`, background `secondaryBackground`, height 4pt, corner radius 2pt
- `"N of 7 days"` — `.caption`, `mediumGrayText`
- No trend pills, no footer link

---

### 3.4 Copy templates — primary sentence by stage and scenario

The primary sentence is assembled from `SignalResult` by a `SignalCardFormatter` (a pure function/struct — not a view). These templates are the canonical copy. All phrasing must match the "safe to say" column in v2-feature-narrative.md §4.

**Early perimenopause:**

| Scenario | Primary sentence |
|---|---|
| Dominant symptom escalating | `"[Symptom] on [N] days this month — more than before."` |
| Dominant symptom new | `"[Symptom] appeared this month for the first time."` |
| Dominant symptom stable (high burden) | `"[Symptom] on [N] days — similar to recent months."` |
| No dominant symptom | `"[N] days logged. Your patterns are building."` |
| Month notably harder | `"A harder month than your recent baseline."` |
| Month notably improving | `"This month was easier than your recent baseline."` |

**Late perimenopause:**

| Scenario | Primary sentence |
|---|---|
| Dominant symptom high burden | `"[Symptom] on [N] of [total] days this month."` |
| Multiple symptoms prominent | `"[Symptom A] and [Symptom B] were your most frequent symptoms."` |
| Sleep consistently poor | `"Sleep has been poor most days."` |

**Menopause — improving arc:**

| Scenario | Primary sentence |
|---|---|
| Dominant symptom improving | `"[Symptom] is less frequent — [N] days vs [baseline avg] in earlier months."` |
| Sleep improving | `"Sleep quality has been trending better."` |
| Month notably better | `"This is your best month so far."` |

**Menopause — symptoms returning:**

| Scenario | Primary sentence |
|---|---|
| Dominant symptom escalating | `"[Symptom] returned this month — [N] days, up from a quieter period."` |
| Month notably harder | `"A harder month after a quieter period."` |

**Formatting rules for templates:**
- `[Symptom]` = the localised display name of the dominant symptom (e.g. "Hot flashes", "Night sweats")
- `[N]` = integer day count, no decimal
- `[baseline avg]` = rounded integer ("about [N]" if the value is not a whole number)
- Never say "significantly", "worrying", "alarming", "suggests", "indicates", "causes"
- Never name a condition ("this could be perimenopause" — forbidden)
- Sentences must be verifiable from the user's own log

**Trend pill labels:**

| Trend | Symptom pill label | Wellbeing pill label |
|---|---|---|
| `.escalating` | `"↑ [Symptom] more often"` | `"↓ [Field] getting worse"` |
| `.improving` | `"↓ [Symptom] less often"` | `"↑ [Field] improving"` |
| `.stable` | omit (stable = unremarkable, no pill) | omit |
| `.new` | `"New: [Symptom]"` | — |
| `.resolved` | omit | — |

Wellbeing field labels: sleep → `"Sleep"`, energy → `"Energy"`, stress → `"Stress"`.  
Note: stress polarity is inverted — lower stress = better. Pill for escalating stress reads `"↑ Stress high"` (higher = worse). Pill for improving stress reads `"↓ Stress lower"`.

---

## 4. Home Screen Scroll Order — Per Stage

### 4.1 Regular / Irregular (unchanged)

```
PulseView
  ├── CategoryStripView
  ├── DartboardView
  └── FlowStepSlider
PhaseCard (ForecastView)
CycleRingSummaryCard
CycleCalendarView
```

No SignalCard. No changes from v1.1.1.

---

### 4.2 Early Perimenopause

```
PulseView
  ├── CategoryStripView        (+ Vasomotor, Joints categories when built)
  ├── DartboardView
  └── FlowStepSlider           ← KEEP (periods still happening)
SignalCard                     ← NEW, below PulseView
BleedHistoryCard               ← existing component, replaces PhaseCard
CycleRingSummaryCard           ← KEEP but suppress fertile window bars
CycleCalendarView
```

**BleedHistoryCard position:** immediately below SignalCard, above calendar. This is the "when did it last happen" context the user needs alongside the signal narrative.

**ForecastView / PhaseCard:** hidden. The phase card ("Ovulation Window, Day 15") assumes a reliable cycle and is removed for perimenopause — per v2-feature-narrative.md §4: *"Bleeding in perimenopause is a signal, not a structure."*

**CycleRingSummaryCard:** retained but the fertile/ovulation segment colouring should be suppressed (not the whole card). This is a future refinement — for the first build, the card can remain as-is.

---

### 4.3 Late Perimenopause

```
PulseView
  ├── CategoryStripView        (+ Vasomotor, Joints categories when built)
  ├── DartboardView
  └── FlowStepSlider           ← keep, visually secondary (weight to be resolved)
SignalCard                     ← PRIMARY — this is the narrative
BleedHistoryCard               ← present if any flow logged in last 90 days; hidden otherwise
MonthlySummaryView card        ← "Your Month: [month] →" entry card
CycleCalendarView              ← symptoms/flow bars remain valuable as log
```

**ForecastView / CycleRingSummaryCard:** hidden for late perimenopause.

**SignalCard weight:** At late perimenopause stage, SignalCard is the primary content. The visual hierarchy should reflect this — generous top padding (20pt above card, vs 12pt standard).

---

### 4.4 Menopause

```
PulseView
  ├── CategoryStripView        (+ Vasomotor, Joints; Intimate Health when opted in)
  ├── DartboardView
  └── FlowStepSlider           ← KEEP, labelled "Log unexpected bleeding" (future §5.6 change)
SignalCard                     ← PRIMARY
MonthlySummaryView card        ← "Your Month: [month] →"
CycleCalendarView              ← symptom heatmap mode (future change); bleed events secondary
```

**ForecastView / CycleRingSummaryCard / BleedHistoryCard:** all hidden.

**CycleCalendarView:** for now, shows existing calendar unchanged. Symptom heatmap mode is a v2.1 change.

---

### 4.5 Paused

```
PulseView
  ├── CategoryStripView
  ├── DartboardView
  └── FlowStepSlider           ← present (secondary)
PausedSummaryCard              ← existing component, unchanged
MonthlySummaryView card
[No calendar]
```

**SignalCard:** not shown for paused. SignalEngine's peri/meno analysis is not meaningful without a declared active stage.

---

## 5. Component Visibility Matrix

| Component | regular | irregular | early peri | late peri | menopause | paused |
|---|---|---|---|---|---|---|
| PulseView (dartboard) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| FlowStepSlider | ✅ | ✅ | ✅ | ✅ | ✅ (secondary) | ✅ (secondary) |
| SignalCard | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| PhaseCard / ForecastView | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| BleedHistoryCard | ❌ | ❌ | ✅ | if flow ≤90d | ❌ | ❌ |
| PausedSummaryCard | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| CycleRingSummaryCard | ✅ | ✅ | ✅ (simplified) | ❌ | ❌ | ❌ |
| MonthlySummaryView card | future | future | future | ✅ | ✅ | ✅ |
| CycleCalendarView | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

"future" = entry card shown but taps to placeholder; not a v2.0 gate for signal.

---

## 6. SignalCard — HomeView Integration

### 6.1 Where SignalEngine is called

`HomeView` is the integration point. It already has access to `cycleStore` and the life stage. `SignalEngine.compute(...)` is a pure synchronous function — it can be called in a computed property or a `.task` modifier.

**Data source:**
- `current`, `previous`, `baseline` — derived from `cycleStore.getAllDays()` sliced by month
- `stage` — from `@AppStorage(LifeStage.defaultsKey)`
- `cycleLengths` — from `cycleStore` (existing `calculateCycleLengths()` or equivalent)

**Recalculation:** on `cycleStore.objectWillChange` — same pattern as existing `DartboardViewModel.loadFromStore()`.

### 6.2 Reference month

"Current" = the most recently logged month. "Previous" = the month before. "Baseline" = the two months before that.

This must be computed relative to the most-recent log date, not `Date()`, so:
- A user who hasn't logged in 3 weeks still sees a meaningful signal from their last active month
- A user just starting in the middle of a month sees the current partial month as "current"

Implementation note: `SignalEngine` already accepts `[CycleDay]` slices — the HomeView is responsible for computing the correct slices.

### 6.3 Refresh cadence

Recompute on:
- `cycleStore.objectWillChange` (new log saved)
- `.onAppear` (each time home screen is shown)

No background refresh needed — computation is synchronous and fast (sub-millisecond on current dataset sizes).

---

## 7. Accessibility

**SignalCard:**
- The entire card is a single accessible element with `.accessibilityElement(children: .ignore)` on the container
- `.accessibilityLabel` = primary sentence + trend pills combined as natural language, e.g.: *"This month: Hot flashes on 18 days, more than before. Sleep getting worse. Stress high."*
- `.accessibilityHint` = `"Double-tap to open your monthly summary"`
- `.accessibilityAddTraits(.isButton)` — the whole card is tappable
- Month character dot: `.accessibilityHidden(true)` — conveyed by the primary sentence

**Learning state:**
- `.accessibilityLabel` = `"Building your picture. [N] of 7 days logged."`
- Not a button — no hint, no `.isButton` trait

**Trend pills:**
- Hidden from VoiceOver (content folded into card label)

---

## 8. Interaction Model

**Tap anywhere on SignalCard:** opens `MonthlySummaryView` as a sheet.  
- If `MonthlySummaryView` is not yet built: tap is inert (no action, no feedback). The footer link is hidden in this state.

**Learning state card:** not tappable.

**No long-press, no swipe actions.**

---

## 9. Edge Cases

| Case | Behaviour |
|---|---|
| `SignalEngine` returns `.learning` | Show learning state card |
| `SignalEngine` returns `.ready` but `dominantSymptoms` is empty | Primary sentence from `monthCharacter` only |
| `monthCharacter == .noComparison` and no dominant symptoms | Show: `"[N] days logged this month."` — no dot, no pills |
| User switches life stage mid-month | Recompute immediately; card updates without animation |
| User in menopause logs unexpected bleeding | SignalCard unchanged; unexpected bleeding card handled separately (existing `UnexpectedBleedingCard`) |
| First day of new month | "Current" month has 1 day — likely returns `.learning`; learning card shown |

---

## 10. What Is NOT in This Spec

These are out of scope for the initial SignalCard build and tracked elsewhere:

- `MonthlySummaryView` full content (v2-feature-narrative.md §5.6)
- Symptom category expansion (Vasomotor, Joints, Intimate Health) — separate task
- FlowStepSlider label change to "Log unexpected bleeding" for meno/paused — separate task
- CycleCalendarView symptom heatmap mode — v2.1
- Clinical export — v2.1
- `BleedHistoryCard` — already exists; verify it works for peri stage
- `LifeStageGuideView` (confirmation sheet, first-run cards) — separate task

---

## 11. Build Order

1. `SignalCardFormatter` — pure struct, takes `SignalResult` → `(headline: String, pills: [TrendPill], monthCharacter: MonthCharacter)`. Testable without a view.
2. `SignalCard` view — consumes `SignalCardFormatter` output; two visual states (learning / ready)
3. `HomeView` wiring — add `SignalEngine.compute(...)` call; add `SignalCard` conditional on life stage
4. Update stage-visibility logic in `HomeView` — hide/show components per §5 matrix
5. Snapshot tests — add `SignalCard` to `SnapshotTests.swift` with each life stage scenario

---

*v2-feature-narrative.md and v2-ux-review.md remain the authoritative product spec. This document specifies the visual and interaction design layer that bridges requirements to implementation.*
