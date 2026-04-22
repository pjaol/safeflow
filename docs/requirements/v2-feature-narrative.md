# Clio Daye v2 — Feature Narrative & Roadmap

**Status:** UX review complete — ready for development  
**Last updated:** 2026-04-17  
**Builds on:** PRD-v2.md, roadmap-menopause-v2.md, feedback-v2.md

---

## 1. What problem we're solving

Every major cycle tracker — Flo, Clue, Natural Cycles — is built around one assumption: the user has a regular cycle and wants to know when their next period is coming. That works for roughly 20 years of a person's reproductive life. It fails completely for the other 20.

When cycles start shifting in perimenopause, Clue shows confident predictions that are wrong by two weeks. When someone reaches menopause, Flo still asks for a last period date. When someone is post-partum, every app nags them about a missing period. These aren't UX glitches — they're the product assuming the wrong life stage.

No privacy-first app solves this. That's the gap.

Clio Daye v2 expands from a cycle tracker into a **private longitudinal health narrative system** — starting with reproductive health, but not ending there. The product shift is from recording what happened to telling you what it means, in plain language, on your device, without overclaiming.

---

## 2. Who we're building for

### Existing users (must not be disrupted)

**Maya, 28 — regular cycle user.** Has been using Clio Daye since v1.0. Tracks her cycle, notices PMS patterns, uses the prediction to plan. v2 must feel identical to v1.1 for Maya unless she actively chooses otherwise. Her default life stage is `regular`. Nothing changes except the addition of Daily Wellbeing fields in the log.

### New users v2 is designed for

**Diane, 51 — early perimenopause, arriving from Clue.**  
Has been tracking for 6 years. Her cycles now range 22–55 days. Clue keeps showing confident predictions that are wrong by two weeks. She arrives knowing she's perimenopausal. She doesn't want to be treated as a medical case. She wants:
- Honest history of what's happened, not false predictions about what's coming
- A symptom list that includes hot flashes, night sweats, brain fog, joint pain
- Something she can bring to her GP that isn't just "I feel awful"

**Rosaria, 58 — postmenopausal, new to tracking.**  
Last period at 53. Never tracked. Getting joint pain and brain fog, wants to understand what's hormonal vs what isn't. Has no period data to offer. Every competitor's onboarding dead-ends her. She needs:
- An onboarding path that works without period history
- A home screen with no cycle UI — just symptoms and how she's feeling
- A plain-language summary of what her data shows, even after just a few days

**Alex, 34 — paused cycle, post-partum.**  
8 months post-partum, breastfeeding, no period yet. Used Clio Daye before pregnancy. Wants to come back without being nagged about a missing period. She needs:
- A "paused" mode that stops cycle prediction entirely
- Simple mood and energy logging while her body recovers
- A frictionless path back to cycle tracking when she's ready

---

## 3. The value shift

| v1 | v2 |
|---|---|
| Recording: log what happened | Recording + interpreting + telling you what it means |
| Cycle-centric: built for the reproductive phase | Life-stage adaptive: useful from first period to postmenopause |
| Prediction-first home screen | Sensemaking-first: here's what's been happening |
| Fixed symptom set (pain, energy, mood, body) | Expanded taxonomy gated by life stage |
| One onboarding path | Branching onboarding by goal and life stage |
| Support content for cycle conditions | Support content for all life stages |

---

## 4. Core design principles for v2

These extend the v1 principles. All v1 principles carry forward unchanged.

**Life stage is user-declared, never inferred.**  
The app never infers perimenopause, menopause, pregnancy, or post-partum status from data patterns. The user sets their life stage. The app may surface a gentle, dismissible prompt — *"Your cycles have been variable lately — you can update your life stage in Settings anytime"* — but never changes the setting without explicit user confirmation. This is a privacy principle, a safety principle, and a trauma-aware design principle.

**Unexpected bleeding is always accepted, never refused.**  
If a user in "menopause" or "paused" stage logs flow, the app accepts it without friction. It then surfaces contextually appropriate information based on what was logged and the declared life stage. It may offer a life stage update prompt, but this is dismissible and never persistent.

**The app only tells you what your data actually shows.**  
Pattern surfacing in "Your Month" and on the home screen is arithmetic and observation on the user's own data — counts, frequencies, comparisons, and co-occurrence — stated in plain language. The app does not use ML inference, does not predict future states from symptom patterns, and does not claim to know more than the data shows. The line:

| Safe to say | Not safe to say |
|---|---|
| "Hot flashes on 18 of 30 days" | "Your hot flashes are worsening" |
| "More frequent than last month" | "This suggests a hormonal shift" |
| "Sleep was poor on most high-stress days" | "Stress is causing your sleep problems" |
| "Bleeds have been further apart recently" | "You're entering late perimenopause" |

The rule: if the user could verify the statement by looking at their own calendar or log history, it's safe to say.

**Menopause and paused are non-cycle products, not degraded cycle modes.**  
These stages share infrastructure with the cycle tracker but are conceptually distinct. The menopause home is a symptom and pattern system. The paused home is a mood and energy tracker. No cycle framing appears on either — not even subtly. Bleed history data is available on pull (in the calendar, in "Your Month" if flow was logged) but never pushed onto the screen unprompted.

**Bleeding in perimenopause is a signal, not a structure.**  
In regular cycles, bleeding is a clock — it anchors the UI and drives prediction. In perimenopause, bleeding becomes an event in a noisy system. It still matters clinically and psychologically, but it no longer reliably structures time. The perimenopause home replaces "Day N of cycle / next period expected..." with history: *"Last bleed: 32 days ago. Your bleeds have ranged 22–55 days apart."* The information is preserved; the illusion of predictive structure is not.

**Honest uncertainty scales with life stage.**  
Confident prediction language is appropriate for regular cycles. History-first language is appropriate for perimenopause. No forecast at all is appropriate for menopause. The app's language tracks actual predictive reliability — it never implies "predictable, just less precise" when the reality is "not reliably predictable at all."

**Red flags surface, never sink.**  
Postmenopausal bleeding and certain perimenopause bleeding patterns warrant clinical attention. These must be surfaced clearly and without alarm — not buried in tips. They are non-diagnostic: *"postmenopausal bleeding is always worth a conversation with your doctor"*, not *"this could indicate something serious."*

**Value on day one, regardless of data.**  
Rosaria, arriving with no historical data, gets meaningful value in her first session: relevant symptom logging, life-stage appropriate tips, support resources. "Your Month" surfaces something useful even from 3–5 days of logs, not just after weeks of accumulation.

---

## 5. Screen-by-screen plan

### 5.1 Onboarding

**Current:** 4 linear pages — Privacy → Know Your Cycle → Security → Cycle Setup.

**v2:** Insert life stage branch at page 1. Page order:

```
Page 0: Privacy First (unchanged)
Page 1: What brings you here? (NEW — branches the rest)
Page 2: Security (unchanged)
Page 3: Cycle Setup OR Life Stage Setup (conditional on page 1 answer)
```

**Page 1 — "What brings you here?"**

Four tappable cards. Each sets life stage and routes to the appropriate page 3:

| Selection | Sets | Routes to |
|---|---|---|
| Track my cycle | `stage = regular` | Existing cycle setup — unchanged |
| My cycles are shifting | `stage = perimenopause` | Abbreviated cycle setup: last period date only, no length steppers |
| I'm in menopause | `stage = menopause` | Symptom priority setup (see below) |
| Taking a break | `stage = paused` | Paused sub-context question (see below) |

**"My cycles are shifting" — perimenopause abbreviated setup (page 3):**

One field only: last period date picker. Contextual note below the picker:  
*"We'll use your period history to spot patterns. Predictions aren't reliable when cycles are variable, so we focus on what's actually happened."*  
Button: "Continue"  
Skip: "I don't remember" — skips date entirely and goes to page 4 (Security)

**"I'm in menopause" — symptom priority setup (page 3):**

Heading: *"What would you like to track?"*  
Instruction: *"Choose what matters most to you. You can change this anytime."*

Six checkbox options (multi-select, any combination valid):
- Hot flashes
- Sleep quality
- Mood
- Joint pain
- Brain fog
- Energy

Button: "Continue" (always enabled — zero selection is valid, defaults to all categories visible)  
Skip link: "Skip for now" — skips to page 4 with all categories visible

**Symptom label → data model mapping:**

| Onboarding UI label | Maps to | Data layer |
|---|---|---|
| Hot flashes | `DartboardCategory.vasomotor` → `Symptom.hotFlashes` | `CycleDay.symptoms` |
| Sleep quality | `WellbeingLevel` field | `CycleDay.sleepQuality` |
| Mood | `DartboardCategory.mood` | `CycleDay.mood` |
| Joint pain | `DartboardCategory.musculoskeletal` → `Symptom.jointPain` | `CycleDay.symptoms` |
| Brain fog | `DartboardCategory.energy` → `Symptom.brainFog` | `CycleDay.symptoms` |
| Energy | `WellbeingLevel` field | `CycleDay.energyLevel` |

Selection on this page stores nothing to CycleDay. It only affects which `DartboardCategory` entries are shown in the CategoryStrip on first launch — stored as `UserDefaults` key `"menopauseSymptomPriority": [String]`. If the user skips, all categories are shown.

**"Taking a break" — paused sub-context (page 1b, before page 2 Security):**

Single question, two large buttons:  
*"What's going on?"*  
- **"Recovering"** (postpartum / breastfeeding)  
- **"Not tracking right now"**

Stores to `UserDefaults` key `"pausedContext"`: `"recovering"` or `"not_tracking"`.  
No skip — both options are always valid. Tapping either goes directly to page 2 (Security).

**Paused context usage — copy that changes based on `pausedContext`:**

| Surface | `recovering` | `not_tracking` |
|---|---|---|
| Page 1b confirmation (below buttons) | *"We'll skip period tracking while you recover. Log how you feel when you can."* | *"We'll skip period tracking for now. Log how you feel whenever you like."* |
| First-run home card | *"Cycle tracking paused. Log how you feel when you can. Switch back anytime."* | *"Cycle tracking paused. Just log how you feel. Switch back anytime."* |
| Paused tip pool | Draws from `life_stage = paused, context = recovering` tips | Draws from `life_stage = paused` tips (all) |

**"Taking a break" onboarding page 3:**

Full-screen confirmation.  
Heading: *"Here's what to expect"*  
Body: *(uses `pausedContext` variant — see above)*  
- *"Period tracking and predictions are paused."*
- *"Log your mood, energy, and symptoms when you want to."*
- *"Switch back to cycle tracking anytime in Settings."*  
Button: "Get started"

"Skip for now" remains available on all paths, defaulting to `stage = regular`.

**Existing users (v1.1.1 → v2.0 upgrade):** Never see the new onboarding. Life stage defaults to `regular` silently on first v2.0 launch. A one-time hint card appears in Settings above the "Your Experience" section: *"New in v2: Life Stage lets you personalise Clio Daye to where you are. Tap to learn more."* Dismissed with a single tap, never shown again. Stored in `UserDefaults` key `"lifeStageHintDismissed"`.

**VoiceOver:** Page count announced dynamically — "page 3 of 3" when cycle setup is skipped, "page 4 of 4" when it is shown.

**Existing users:** Never see the new onboarding. The life stage page only runs on first install.

---

### 5.2 Settings — Life Stage

New section at the top of SettingsView, above Security:

```
Your Experience
  Life Stage →   [Perimenopause]
```

`LifeStagePickerView` — simple list, checkmark on selected stage. Context note: *"This changes what Clio Daye shows you. Your stored data is never affected."*

| Stage | User-facing label | One-line description |
|---|---|---|
| `regular` | Regular cycles | Periods come roughly on schedule |
| `irregular` | Irregular cycles | Periods vary — predictions show a wider range |
| `perimenopause` | Perimenopause | Cycles are changing — history and symptoms take priority |
| `menopause` | Menopause | Periods have stopped — symptoms and summaries are the main view |
| `paused` | Cycle paused | Post-partum, breastfeeding, or taking a break |

No inference. No suggestions based on data. No persistent prompting.

---

### 5.3 Home Screen

The scroll zones (Pulse → Summary Card → Forecast → Calendar) are structurally unchanged. Content inside each zone is life-stage aware.

#### Regular / Irregular (unchanged from v1.1)
- **Pulse:** Dartboard symptom ring + flow slider below, as today
- **Summary card:** Cycle ring, day number, phase, prediction range
- **Forecast:** Next period prediction window
- **Calendar:** Cycle history with bleed dots
- **Your Month card:** *"Your Month: April →"* at the bottom of the scroll (new for all stages — see §5.6)

#### Perimenopause
- **Pulse:** Dartboard unchanged; CategoryStrip gains Vasomotor and Joints categories (§5.4)
- **Summary card:** Cycle ring replaced with a bleed history card: *"Last bleed: 32 days ago. Your bleeds have ranged 22–55 days apart."* No day counter. No "next period expected." Phase card suppressed.
- **Forecast zone:** Replaced with a temporary stabilisation notice when applicable (see §5.5) — otherwise empty
- **Calendar:** Unchanged — historical bleed and symptom record remains valuable
- **Your Month card:** At bottom of scroll

#### Menopause
- **Pulse:** Dartboard and CategoryStrip unchanged as the symptom tracker. Flow slider present but visually secondary — labelled *"Log unexpected bleeding"*
- **Summary card:** **Symptom Snapshot** — *"This week: hot flashes on 4 days, sleep fair-to-poor, mood mostly stable."* Driven from recent logs. No cycle content.
- **Forecast zone:** Hidden entirely. No time-since-last-bleed on the home screen. Bleed history is available in the calendar and in "Your Month" if the user logged flow — but it is not surfaced unprompted.
- **Calendar:** Symptom heatmap — days coloured by overall symptom burden. Bleed events visible as a secondary indicator for days on which flow was logged, without cycle framing.
- **Your Month card:** At bottom of scroll

#### Paused
- **Pulse:** Dartboard unchanged. Flow slider present but secondary.
- **Summary card:** *"Cycle tracking paused. Logging how you feel."* One link: "Resume cycle tracking" → opens life stage picker.
- **Forecast + Calendar:** Hidden
- **Your Month card:** At bottom of scroll (mood and energy focus)

---

### 5.4 Log Day — Expanded symptom taxonomy

**New universal top section — Daily Wellbeing (all stages):**

Three fields before flow and symptoms. Designed for near-zero friction:

- Sleep quality (0–4: poor → excellent)
- Energy level (0–4: depleted → high)  
- Stress level (0–4: calm → high)

**Progressive fill pattern:** Yesterday's logged values are pre-selected in a visually secondary state (greyed, not confirmed). One tap confirms them. Adjust if different. Tapping Save without interacting with them is always valid — they remain as yesterday's value if confirmed, or unlogged if untouched.

These are the universal data layer that powers "Your Month" across all life stages. They are never mandatory, always visible.

**Flow section:**
- Regular / Irregular / Perimenopause: prominent, as today
- Menopause / Paused: available but secondary; labelled *"Log unexpected bleeding"*

**Dartboard category expansion — life-stage gated:**

| Category | Shown for | Contents |
|---|---|---|
| Pain | All (existing) | cramps, headache, bloating, breast tenderness, back pain, mittelschmerz |
| Energy | All (existing) | fatigue, insomnia, high energy, brain fog |
| Mood | All (existing) | energized, happy, calm, neutral, anxious, sad |
| Body | All (existing) | food cravings, nausea, appetite changes, discharge changes, acne |
| **Vasomotor** | Perimenopause, Menopause | hot flashes (none / 1–2 / 3–5 / 6+), night sweats (none / mild / moderate / severe), chills |
| **Joints** | Perimenopause, Menopause | joint pain, muscle aches, exercise recovery |
| **Intimate health** | Menopause only (opt-in, trust ramp) | vaginal dryness, urinary urgency, pain with sex ("not applicable" option) |

The Intimate Health category is not a settings toggle. It is introduced contextually after a few sessions for menopause-stage users via a warm, dismissible card: *"Some people find it useful to track intimate health symptoms. This is completely optional and stored on your device like everything else."* It can be turned off in Settings once enabled. It surfaces in "Your Month" only when opted in.

**Existing users on `regular` stage:** Never see the new categories. Log is identical to v1.1.

---

### 5.5 Unexpected Bleeding and Perimenopause Patterns

#### Unexpected bleeding — handling by stage

When flow is logged and the declared life stage is `menopause` or `paused`:

1. Accept the log without friction — no blocking dialog
2. Save normally
3. Surface a contextually appropriate, one-time, dismissible card after save

**Menopause → red flag (non-alarming):**
> *"You've logged some bleeding. Bleeding after menopause is always worth mentioning to your doctor — it's often benign, but warrants a check."*  
> [Get Support] [Dismiss]

**Paused → cycle returning prompt:**
> *"Looks like your cycle might be returning. Would you like to switch back to cycle tracking?"*  
> [Update Life Stage] [Not yet]

**Perimenopause, gap >60 days → informational only:**
> *"Your cycle returned after a longer gap — that's common at this stage."*  
> [Dismiss]

The app never: changes life stage automatically, repeats the prompt on subsequent logs in the same event, uses alarming language, or suggests a diagnosis.

#### Temporary stabilisation in perimenopause

Perimenopause is not a smooth decline — hormones fluctuate unevenly, which can produce periods of apparent cycle regularity followed by renewed variability. This is clinically common and worth surfacing honestly.

**Detection:** Rolling SD over the last 3–4 cycles is meaningfully lower than the SD over the prior 6-cycle window.

**Where it surfaces:** "Your Month" → What we noticed section only. Never on the home screen. Never as a forecast adjustment.

**Language:**
> *"Your recent cycles have been closer together than before — 28, 31, and 27 days compared to a range of 22–55. In perimenopause, cycles can stabilise for a time before changing again."*

**What the app does not do:** Tighten the prediction window. Describe this as "returning to regular." Imply permanence.

**Internal rule:** Stability is a trend, not a state.

---

### 5.6 "Your Month" — Plain-language data mirror

**Name:** Your Month  
**Internal/code name:** `MonthlySummary`  
**Ships in:** v2.0 — thin version from day one, deepens as data accumulates

**What it is:** A plain-language mirror of what the user's own data shows. Not a dashboard. Not ML inference. Arithmetic and observation on logged data — counts, frequencies, comparisons, co-occurrence — stated clearly so the user doesn't have to do the maths themselves.

The user could verify every statement by looking at their own logs. That's the test: if it fails that test, it doesn't belong in "Your Month."

**How it's accessed:** A card at the bottom of the home scroll — *"Your Month: April →"* — opens a full-screen sheet. Accessible from the calendar area too.

**Graceful scaling with data density:**

| Data available | What it shows |
|---|---|
| 3–5 days | *"You've logged 5 days so far. Sleep has been mostly poor. Hot flashes on 4 of those days."* |
| 1–2 weeks | Frequency patterns: *"Sleep has been mostly poor. Hot flashes most days. Stress was high mid-week."* |
| 3–4 weeks | Temporal patterns and co-occurrence: *"Hot flashes were more frequent in the second half of the month. Sleep was poor on almost every day with high stress."* |
| 2+ months | Comparative: *"Hot flashes increased compared to last month. Sleep quality was similar."* |

**Structure of a full month view:**

Each section uses a `.subheadline` header so users can scan the structure before reading detail. Prose is broken into single-sentence lines with whitespace between them — not paragraph blocks. This matters at large Dynamic Type sizes where dense prose loses its hierarchy.

*What happened* — frequency counts for the top logged symptoms and wellbeing fields. Always present regardless of data density.
> "Hot flashes on 18 of 30 days."  
> "Sleep was poor or very poor on 14 days."  
> "Mood was mostly calm or neutral."

*What we noticed* — co-occurrence and temporal patterns, only surfaced when sufficient data exists. Always observational, never causal.
> "Sleep was poor on most days with high stress."  
> "Hot flashes were more frequent in weeks 2 and 3."

*Your cycles* (regular / irregular / perimenopause only)
> "2 cycles this month."  
> "Average length: 30 days. Your last 3 ranged from 28 to 33 days."

*Temporary stabilisation notice* (perimenopause only, when detected — see §5.5)

*Worth mentioning to your doctor* — red flags only, when applicable. Non-alarming, non-diagnostic.

> **Implementation note:** Use `.subheadline` for section headers. Line spacing: `1.5×` at default text size, `1.2×` at Accessibility sizes (XXL+). Single-sentence lines separated by `.padding(.bottom, 2)` — not paragraph blocks. Verify full view at XXL Dynamic Type before merging Task #20.

**Language rules:**
- Always observational: "we noticed," "tended to," "on most days" — never "caused by," "means," "suggests a condition"
- Always hedged when appropriate: "may be associated," "often but not always"
- Never implies the app knows more than the user's logged data shows
- Validates without pathologising — acknowledges the experience without labelling it

**Content focus by life stage:**

| Stage | Primary focus |
|---|---|
| Regular | Cycle summary, PMS pattern, energy and mood across phases |
| Irregular | Cycle variability, symptom patterns, what tracked with how you felt |
| Perimenopause | Bleed history, symptom clusters, vasomotor + sleep relationship, stabilisation notices |
| Menopause | Symptom frequencies, vasomotor intensity week by week, sleep quality, intimate health (if opted in) |
| Paused | Mood and energy week by week, simple and brief |

---

### 5.7 Support Content — Life stage aware

**Current state:** Resources filtered by country and contextual signal tags. All content is cycle-condition focused (PCOS, endometriosis, PMDD, OB/GYN). Tips keyed to cycle phases only.

**v2 changes:**

**New resource categories in resources.json:**
- `menopause_support` — The Menopause Society, NICE NG23 (patient version), ACOG menopause resources
- `perimenopause` — perimenopause-specific orgs, "is this perimenopause?" information
- `intimate_health` — GSM resources (surfaced only when Intimate Health module is opted in)

**New resource tags:**
`perimenopause | menopause | hot_flashes | night_sweats | brain_fog | joint_pain | vasomotor | sleep | intimate_health`

**Life-stage contextual surfacing:**
`activeTags` augmented by life stage:
- `perimenopause` → `perimenopause`, `vasomotor`, `brain_fog`, `sleep`
- `menopause` → `menopause`, `hot_flashes`, and `intimate_health` if opted in
- `paused` → `mental_health`, `mood`

**New tip content — life-stage keyed:**

`ContentTip` gains a `life_stage` field alongside `phase`. When life stage is `perimenopause`, `menopause`, or `paused`, `PhaseTipCard` draws from life-stage tips.

Example tips (all require clinical review before shipping):

*Perimenopause:*
- "Cycle variability is the hallmark of early perimenopause — irregular timing is expected, not a problem to fix."
- "Hot flashes often peak at night. A cooler room, breathable bedding, and a small fan can reduce disruption."
- "Brain fog around perimenopause is documented and real. Short lists, written reminders, and protecting sleep all help."

*Menopause:*
- "Vaginal dryness is common after menopause and very treatable — it's not something to just accept."
- "Joint pain can be a menopause symptom that many people don't expect. If it's new, it's worth mentioning."
- "Logging symptoms consistently gives you real data to bring to a GP appointment, not just memory."

*Paused:*
- "There's nothing to track but how you feel today. Rest is data too."
- "Mood and energy shifts while breastfeeding or post-partum are common and real. You're not imagining them."

---

### 5.8 LifeStageGuideView — Explanation at the moment of change

**The principle:** Explanation arrives when the change happens, not in a help section the user has to go looking for. When Diane switches to perimenopause and the period prediction disappears, she needs to understand that's the app being honest with her — not a bug.

`LifeStageGuideView` is a full-screen sheet that replaces the bare picker. It has three parts:

#### Part 1 — The picker with stage descriptions

Each stage is a tappable card, not a list row. Each card carries a brief, plain-language description written from the user's perspective — answering "why would I choose this?" before they have to ask:

**Regular cycles**
> *"Periods come roughly on schedule. The app predicts your next period and tracks where you are in your cycle each day."*

**Irregular cycles**
> *"Your cycle varies and predictions aren't always reliable. The app shows a wider range and tracks patterns over time."*

**Perimenopause**
> *"Your cycles are shifting. We track what's actually happened instead of guessing what's next, and add hot flashes, brain fog, and joint pain to your tracker."*

**Menopause**
> *"Periods have stopped. The app focuses on how you feel each day and what patterns emerge over time."*

**Cycle paused**
> *"Post-partum, breastfeeding, or taking a break. The app skips period tracking and logs how you feel. Switch back anytime."*

> **Dynamic Type note (implementation):** Cards stack vertically. At XXL body size the entire list must be scrollable and each description must fit in 2 sentences max. Verify layout at XXL before merging Task #9.

#### Part 2 — Confirmation sheet with specific change list

When a user selects a stage different from their current one, a sheet slides up explaining the specific changes before confirming. This is the "why X is not here" moment — proactive, not reactive.

**Switching to Perimenopause:**
> **Here's what changes:**
> - Predictions → your bleed history *(more honest when cycles vary)*
> - New symptom categories: hot flashes, night sweats, brain fog, joint pain
> - Your phase card is removed *(phase framing doesn't apply when cycles are irregular)*
> - Your logged data stays exactly as it is
>
> *You can switch back anytime.*

**Switching to Menopause:**
> **Here's what changes:**
> - Cycle tracking and predictions are removed from your home screen
> - Your home screen shows how you've been feeling this week
> - Your calendar switches to a symptom view *(logged bleeds are still there)*
> - The flow tracker stays, labelled differently — tap it if you notice any bleeding
> - "Your Month" summarises your patterns in plain language each month
> - If you log any bleeding, the app will prompt you to mention it to your doctor
> - Your logged data stays exactly as it is
>
> *You can switch back anytime.*

**Switching to Paused:**
> **Here's what changes:**
> - Period tracking and predictions are paused
> - Your calendar is hidden while tracking is paused
> - The app logs mood, energy, and how you're feeling each day
> - The flow tracker is still available if you need it
> - Your logged data stays exactly as it is
>
> *Resume cycle tracking anytime from here or from Settings.*

**Switching to Regular (from any non-regular stage):**
> **Here's what changes:**
> - Cycle tracking and predictions are turned back on
> - The app will use any bleed data you've logged to start rebuilding your cycle picture
> - Hot flash and joint pain categories stay available in your log

> **Dynamic Type note (implementation):** Confirm/Cancel buttons must remain visible without scrolling at XXL body size. If bullet count causes overflow at XXL, use `.footnote` for the parenthetical notes rather than inline body text.

#### Part 3 — First-run home card after switching

A one-time, dismissible card appears at the top of the home scroll after a life stage change — above the Pulse. It confirms the switch and highlights the most important change in one sentence:

| Switched to | Card text |
|---|---|
| Perimenopause | *"Predictions are gone — because they'd be wrong. Your bleed history is your reference now. Hot flashes and joint pain are in your log."* |
| Menopause | *"Cycle tracking is off. Your home screen shows how you've been feeling. Log symptoms as normal — your data is still here."* |
| Paused | *"Cycle tracking paused. Just log how you feel. Switch back anytime in Settings."* |
| Regular | *"Cycle tracking is back on. Log a period when it arrives and predictions will start again."* |

One-time per transition. Dismissed with a single tap. Never shown again.

#### Navigation

- **From Settings:** "Your Experience → Life Stage" navigates to `LifeStageGuideView` as a full-screen sheet
- **From onboarding:** The "What brings you here?" page uses the picker portion of `LifeStageGuideView` directly — without the confirmation sheet (no existing stage to diff against)
- **Accessibility:** Confirmation sheet change list is a grouped accessibility element, announced as a list on VoiceOver. Confirm button is the last element in focus order.

---

### 5.9 UX considerations — user age and the design language

v2 significantly shifts the age distribution of users. v1 skews younger (Maya, 28). v2 adds a meaningful cohort of users in their 40s, 50s, and 60s. The question is whether the visual design needs to shift with them.

**Short answer: the core design language holds. Three targeted adjustments matter.**

The current design — SF Pro Rounded, pastel palette, dartboard ring, card-based scroll — is clean and functional, not juvenile. It does not read as "for teenagers." The rounded font and soft colours are accessibility and legibility choices as much as aesthetic ones. They work as well for Diane at 51 as for Maya at 28. Do not change the palette, the typography family, or the overall feel.

What does change slightly for older users is the practical ergonomic context:

**1. Tap target discipline is more important**  
Younger users tolerate smaller targets. The 44×44pt minimum we already enforce is correct — but it should be treated as a genuine minimum, not a target to optimise against. Any interactive element in new v2 screens (life stage cards, confirmation sheet buttons, daily wellbeing fields) should be built with generous tap areas from the start.

**2. Information density should favour legibility over compactness**  
The dartboard segment labels are already at the edge of comfortable readability at default text size — this is fine for v1's primary user. For v2 screens (particularly `LifeStageGuideView`, `MonthlySummaryView`, and the confirmation sheet) prefer a slightly more open layout and `.body` / `.subheadline` text styles over `.caption` where there's a choice. Dynamic Type handles the rest.

**3. The confirmation sheet and "Your Month" are read-heavy by design — that requires care**  
These are the two surfaces where users are reading prose, not tapping. The existing card style (white/secondary background, rounded corners, 16pt padding) is appropriate. The one addition: a slightly higher line-height or more generous paragraph spacing in "Your Month" prose sections than we'd use for a short tip card. This is a single `.lineSpacing()` modifier, not a redesign.

**What to explicitly not do:**
- Do not change the colour palette to be "warmer" or "more mature" — the current pastels are calm and legible, not cutesy
- Do not add complexity to navigation thinking this age group needs more explicit hierarchy — they use iPhone natively; the card-scroll pattern is familiar
- Do not use smaller type "to fit more in" on summary screens — the people most likely to have Dynamic Type enabled are exactly this cohort

**The accessibility work already done in v1.1.1 — Dynamic Type, VoiceOver, Increase Contrast — is the best thing we could have done for this user group.** v2 benefits directly from it without additional design work.

---

## 6. What existing users experience

**On update from v1.1.1 to v2.0:**
- Default life stage is `regular` — set silently on first launch of v2.0
- Home screen: identical. Maya sees no difference except the "Your Month" card at the bottom of the scroll, which is immediately useful even with existing data.
- Log Day: Daily Wellbeing fields (sleep, energy, stress) appear at the top of the log. The only visible addition for a `regular` user. Existing flow and symptom sections unchanged beneath them.
- New symptom categories (Vasomotor, Joints, Intimate Health) do not appear for `regular` stage.
- Settings: "Life Stage" section at the top. Ignorable.

**On new install (v2.0):** Maya-equivalent users select "Track my cycle" on the new page 1 and get the same onboarding as v1.1.1.

**Existing data:** Completely unaffected. All historical CycleDay records remain valid. Life stage changes never touch stored data.

---

## 7. Build order

### Pre-development: UI/UX review gate

Before any v2.0 screens are built, conduct a focused UI/UX review of this document and the current app against four questions:

1. **Flow clarity:** Does each user path (onboarding → life stage selection → home) have a clear, unambiguous next action at every step? Walk through each persona (Maya, Diane, Rosaria, Alex) end to end.
2. **Explanation completeness:** Does the confirmation sheet copy for each stage transition cover the changes that matter most to that user? Are there any changes that happen silently without explanation?
3. **Information hierarchy:** On new screens (`LifeStageGuideView`, `MonthlySummaryView`, Symptom Snapshot card) is the most important information at the top? Does the layout hold at the three largest Dynamic Type sizes?
4. **Tone consistency:** Does the language across onboarding, confirmation sheets, home cards, and "Your Month" feel like one voice? Review against the existing `PhaseTipCard` and `InsightCard` copy for consistency.

Output: a short written review noting any gaps before implementation begins. This review replaces the risk of discovering UX problems during development.

---

### v2.0 — Life Stage Foundation + Sensemaking First Version
*Target: Q2 2026. Branch: `feature/v2/life-stage`*

1. **`LifeStage` enum + persistence** — `UserDefaults` key `"lifeStage"`, default `regular`
2. **`LifeStageGuideView`** — full-screen sheet with stage cards (descriptions), confirmation sheet (change list per transition), first-run home card after switching; replaces bare picker in Settings and feeds onboarding page 1
3. **Settings integration** — "Your Experience" section at top of SettingsView linking to `LifeStageGuideView`
4. **Onboarding branch** — new page 1 using `LifeStageGuideView` picker portion, paused sub-context question, conditional cycle setup, dynamic VoiceOver page count
4. **Daily Wellbeing fields** — sleep, energy, stress at top of `LogDayFormView` and `LogDayView`, all stages, with progressive fill pattern
5. **Dartboard category expansion** — `vasomotor` and `musculoskeletal` categories, gated by life stage; `intimateHealth` category gated by life stage + trust ramp opt-in
6. **Flow slider adaptation** — secondary presentation and label change for `menopause` and `paused` stages
7. **Unexpected bleeding handling** — `CycleStore` detects flow logged on `menopause`/`paused` stage → one-time contextual card
8. **Home screen content adaptation** — bleed history card (perimenopause), Symptom Snapshot card (menopause), paused home card; "Your Month" entry card on all stages
9. **"Your Month" — thin version** — `MonthlySummaryView` with graceful data-density scaling; surfaces from 3 days of data; covers all life stages
10. **Support content** — new resource categories and tags in `resources.json`, life-stage tags in `GetSupportView.activeTags`, life-stage tip entries in `tips.json`

### v2.1 — Pattern Depth + Clinical Utility
*Target: Q3 2026*

11. **"Your Month" — full version** — temporal patterns, co-occurrence, comparative to prior month, temporary stabilisation detection
12. **Perimenopause-aware forecasting** — forecast replaced with bleed history view; ovulation estimate suppressed when cycle SD > 7 days
13. **Intervention tracking v1** — log start/stop of HRT, supplements, lifestyle changes; appears in "Your Month"
14. **Intimate Health module** — trust ramp introduction for menopause-stage users; full opt-in and opt-out flow; surfaces in "Your Month" if opted in
15. **Content delivery architecture** — design versioned on-device content updates decoupled from app releases; required before content iteration becomes painful across 4 locales

### v2.2 — Retention & Platform
*Target: Q4 2026*

16. **Widget** — symptom summary / cycle phase / days since last log
17. **Logging reminders** — life-stage aware copy, auto-suppressed when already logged
18. **Symptom severity trend view** — 30/60/90-day trajectory charts for individual symptoms

---

## 8. Content production notes

Tips and resources are bundled JSON — every change requires an app release. This is manageable for v2.0 but will bottleneck iteration by v2.1 given 4 locales and ongoing clinical review cycles.

**Content delivery architecture** is a v2.1 design task. Goal: decouple content cadence from app releases. The on-device constraint rules out server-driven delivery, but versioned bundled content updates (downloaded and applied on-device, signed, no health data involved) are worth evaluating.

**Clinical review requirement:** All perimenopause and menopause tip copy, red-flag guidance text, and intimate health content must be reviewed by a menopause specialist or OB/GYN before shipping. The REQ-001 content safety audit process must be extended to cover all new life-stage content. This is a hard dependency for v2.0 — schedule the review before content writing begins.

---

## 9. Open questions

1. **Daily Wellbeing progressive fill:** Yesterday's values pre-selected in a secondary visual state feels right — but does "confirmed if not changed" or "unlogged if not tapped" create better data quality? Recommendation: unlogged if not tapped — cleaner data, no false-accuracy from auto-carry-forward.

2. **"Your Month" minimum data threshold:** Surface immediately with any data (3+ days), or hold until a meaningful minimum (7 days)? Recommendation: 3 days, with honest framing — *"You've logged 3 days so far. Here's what we can see already."*

3. **Perimenopause bleed history wording:** *"Your bleeds have ranged 22–55 days apart"* is accurate — does it feel grounding or alarming to a new user seeing it for the first time? Needs a content review pass before shipping.

4. **Intimate Health trust ramp timing:** After how many logged sessions does the opt-in card appear? Recommendation: after 7 consecutive days of logging in menopause stage — enough to establish trust, not so long it never appears.

5. **Clinical reviewer:** Who reviews the perimenopause/menopause tip copy and red-flag language before v2.0 ships? Must be identified and scheduled before content writing begins.

6. **Paused — time-based return prompt:** Currently, the only trigger for "your cycle might be returning" is logging flow. Should there be a time-based gentle prompt after e.g. 6 months? Recommendation: user-initiated only, for now. Erring toward user control feels right for trauma-aware design.
