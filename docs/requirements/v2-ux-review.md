# v2 UI/UX Review

**Status:** Complete — 2026-04-17  
**Gates:** All implementation tasks (#8–#23)  
**Reviewer:** Claude Code

---

## Summary

The spec is ~61% implementation-ready. Tone is consistent throughout. The principal gaps are a missing copy spec for Rosaria's onboarding page 3, an unresolved data-model mapping for that page, two confirmation sheets that omit meaningful visual changes, and Dynamic Type stress failures in three screens. All blockers are copy/spec work — no architectural rethinks needed.

---

## 1. Flow Clarity

### Maya, 28 — Regular (existing user upgrading to v2)

Flow is clean. Default `regular` applied silently; home screen is identical except for the "Your Month" entry card.

**Gap (low):** When Maya opens Settings for the first time after upgrade, a new "Your Experience" section appears with no prior context. She may ignore it without understanding it's new functionality.  
**Fix:** One-time hint card: *"See something new? Life Stage lets you personalise Clio Daye to where you are in your reproductive health."*

---

### Diane, 51 — Perimenopause (new user)

**Gap 1 (HIGH — blocks onboarding):** The "My cycles are changing" card on onboarding page 1 has no copy in the narrative. Diane needs to understand why she should select it.  
**Fix:** *"Your cycles are shifting. We focus on what's actually happening instead of guessing what's next — and add hot flashes, brain fog, and joint pain to your tracker."*

**Gap 2 (medium):** Onboarding page 3 shows the abbreviated cycle setup (last period date only, no length steppers) with no explanation of why the steppers are absent.  
**Fix:** Add contextual note: *"We'll use your period history to spot patterns. Predictions are less reliable here, so we focus on what's actually happened."*

**Gap 3 (medium):** The bleed history card position on the perimenopause home screen is unspecified. If it's below the fold, Diane may never see her most relevant context.  
**Fix:** Spec the card above or inline with PulseView. Add a one-time explanatory card after first switch: *"Bleeding patterns are the data we track now — not predictions. Variability at this stage is normal."*

---

### Rosaria, 58 — Postmenopausal (new user)

**Gap 1 (CRITICAL — blocks implementation):** Onboarding page 3 for menopause is described as "Symptom priority setup: 'What would you like to track?' multi-select" but has no heading copy, no instruction copy, no button label, no skip behaviour, and no definition of what "nothing selected" defaults to.

**Gap 2 (CRITICAL — blocks data-model integration):** The symptom list in that onboarding step (hot flashes, sleep, mood, joint pain, brain fog) does not map to the `Symptom` enum or `SymptomCategory` cases. "Sleep" specifically is ambiguous — is it a `WellbeingLevel` field or a `Symptom`? This must be resolved before the onboarding → log integration is built.  
**Required:** A mapping table: UI label → Symptom enum case (or WellbeingLevel field).

**Gap 3 (medium):** The Symptom Snapshot card on the menopause home screen requires week-level data aggregation. If Rosaria has just installed the app, what does the card show on day 1?  
**Fix:** Define a minimum-data threshold (e.g. 1 day logged) and a fallback string: *"Log a few days to see your weekly summary here."*

---

### Alex, 34 — Paused/postpartum (new user)

**Gap 1 (medium — blocks copy logic):** Onboarding page 1b captures "Recovering" vs "Not tracking right now" as a sub-context for copy tone. The narrative never specifies which strings change based on this context — confirmation sheet, tips, or home card.  
**Fix:** Specify explicitly which copy nodes read from paused context. Minimum viable: one copy variant per context in the confirmation sheet and in the relevant tip category.

**Gap 2 (low):** The flow slider is present in paused mode but secondary. Alex sees it on the home screen with no explanation of why it's there if tracking is paused.  
**Fix:** Add to the paused confirmation sheet: *"The flow tracker is still available if you need it."*

---

## 2. Explanation Completeness

Each confirmation sheet was checked against the actual app changes per stage.

### Perimenopause — missing from confirmation sheet

| Change | Currently explained? | Fix |
|---|---|---|
| Phase card disappears | No | Add: *"Your phase card is removed — phase framing doesn't apply when cycles are irregular."* |
| Forecast replaced by stabilisation notice | No | Add: *"If your cycles briefly settle, you'll see a note — but it won't drive predictions."* |

### Menopause — missing from confirmation sheet

| Change | Currently explained? | Fix |
|---|---|---|
| Calendar transforms to symptom heatmap; bleed events shown secondary | No | Add: *"Your calendar switches to a symptom view. Any logged bleeds are still there."* |
| Flow slider re-labelled "Log unexpected bleeding" | No | Add: *"The flow tracker stays, labelled differently — tap it if you notice any bleeding."* |

### Paused — missing from confirmation sheet

| Change | Currently explained? | Fix |
|---|---|---|
| Calendar hidden | No | Add: *"Your calendar is hidden while tracking is paused."* |
| Flow slider present (secondary) | No | See Alex gap 2 above. |
| "Your Month" surfaces in mood/energy-only mode | No | Add: *"Your Month will show your mood and energy patterns instead of cycle data."* |

### Regular (switching back) — no gaps.

---

## 3. Information Hierarchy at Large Dynamic Type

All three screens tested at default, Large (+3), XL (+4), XXL (+5).

### LifeStageGuideView — Stage Picker Cards

**Failure at XXL:** Cards stack vertically. At XXL body size (~21pt), 5 cards at ~180pt each = ~900pt total. On an iPhone SE (812pt height), fewer than 1.5 cards fit without scrolling. The picker should feel like a scannable discrete choice — not a scroll view.

**Fix:** Condense all card descriptions to 1–2 sentences. Current perimenopause description is 3 sentences and 2 em-dash explanations; condense to:  
*"Your cycles are shifting. We focus on what's actually happened and add hot flashes, brain fog, and joint pain to your tracker."*

Condensed targets for all cards:

| Card | Current (sentences) | Target |
|---|---|---|
| Regular | 2 | ✓ keep |
| Irregular | 2 | ✓ keep |
| Perimenopause | 3 | ↓ to 2 |
| Menopause | 2 | ✓ keep |
| Paused | 3 | ↓ to 2 |

### LifeStageGuideView — Confirmation Sheet Bullets

**Failure at XXL:** Bullets with em-dash explanations each wrap to 3–4 lines at XXL. Three bullets fill most of the sheet, burying the Confirm/Cancel buttons below the fold without scrolling.

**Fix:** Shorten bullets; move explanation to a sub-line or use `.caption` style:

```
Before:
- Period predictions are replaced with your bleed history — because predictions aren't honest when cycles are variable

After:
- Predictions → your bleed history  (more honest when cycles vary)
```

Confirm/Cancel must remain visible without scrolling at XXL.

### MonthlySummaryView

**Failure at XXL:** Multiple prose sections at body size + generous line spacing = mandatory full-page scroll. Information hierarchy flattens; user can't scan structure.

**Fix:**
- Use `.subheadline` (or equivalent) for section headers: "What Happened", "What We Noticed", etc.
- Break dense paragraph sentences into single-sentence lines with whitespace between
- Keep line spacing at 1.5x for default/large; drop to 1.2x at XXL to recover space while maintaining legibility
- Prototype at XXL before writing final implementation

### Symptom Snapshot Card (Menopause Home) — PASS

Single sentence; wraps to 2–3 lines at XXL but remains readable and focal. No changes needed.

---

## 4. Tone Consistency

Overall: **consistent**. The v1.1 voice — warm, direct, non-clinical, validating — holds across all new copy.

**One minor fix:**  
Perimenopause onboarding card: *"Cycles are changing"* reads slightly clinical. Warm to *"Your cycles are shifting"* (same meaning; more personal register).

All other copy areas — confirmation sheets, first-run cards, unexpected bleeding cards, "Your Month" language rules, support tips, red flag language, stabilisation notice — pass without changes.

---

## Blocking Issues

All four resolved in `v2-feature-narrative.md` on 2026-04-17. Implementation is unblocked.

| # | Blocker | Resolution |
|---|---|---|
| B1 | Rosaria onboarding page 3 copy | Full copy spec added to §5.1 |
| B2 | Symptom label → data model mapping | Mapping table added to §5.1; `"menopauseSymptomPriority"` UserDefaults key defined |
| B3 | Paused sub-context copy usage | Copy variant table added to §5.1 |
| B4 | LifeStageGuideView Dynamic Type overflow | Card descriptions condensed; confirmation bullets shortened; implementation notes added to §5.8 |

---

## Remaining Gaps (resolve before ship, not before dev)

- Diane: bleed history card — spec placement on perimenopause home (above PulseView recommended)
- Rosaria: Symptom Snapshot minimum-data fallback: *"Log a few days to see your weekly summary here."*
- All new screens: manual XXL Dynamic Type test pass before PR merge
- Clinical review of perimenopause/menopause tip copy before v2.0 ship (per §8 of narrative)

---

## Implementation Readiness

**Ready to build (no blockers):**
- LifeStage enum + persistence (Task #8)
- Confirmation sheet structure (content gaps to be filled before Task #9 completes)
- Home first-run cards (all copy complete)
- Unexpected bleeding handling (copy + logic complete)
- CycleDay Daily Wellbeing fields (Task #12)
- Symptom model expansion — vasomotor, musculoskeletal (Task #14; intimateHealth needs B2 resolved)
- Support tips & resources content (Task #19)

**Blocked:**
- Onboarding branch (Task #11) — needs B1, B2, B3
- LifeStageGuideView (Task #9) — needs B4 (layout spec + XXL test)
- DartboardViewModel (Task #15) — needs B2 (intimateHealth category depends on symptom mapping)

---

*v2-feature-narrative.md is the authoritative spec. This review surfaces gaps only — it does not replace that document.*
