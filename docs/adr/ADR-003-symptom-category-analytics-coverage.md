# ADR-003: Symptom Category Analytics Coverage

**Status:** Accepted — gap documented  
**Date:** 2026-04-22  
**Context:** v2 life stage work (feature/v2/life-stage)

---

## Context

The app logs symptoms across 7 dartboard categories. As of v2, not all categories receive equal downstream analytical treatment. This ADR documents the current coverage and the known gaps, so future work can close them deliberately rather than accidentally.

## Current Coverage

| Category | Life stages | Signal engine | Trend chart | Snapshot card | Monthly summary |
|---|---|---|---|---|---|
| Pain | all | ✅ | ❌ | ❌ | ✅ top 3 |
| Energy | all | ✅ | ✅ derived score | ❌ | ✅ top 3 |
| Mood | all | ❌ (by design) | ✅ derived score | ❌ | ✅ top 3 |
| Gut / Body | all | ✅ | ❌ | ❌ | ✅ top 3 |
| Vasomotor | peri + meno | ✅ | ✅ days/month | ✅ | ✅ top 3 |
| Musculoskeletal | peri + meno | ✅ | ❌ | ✅ | ✅ top 3 |
| Intimate Health | meno only | ✅ | ❌ | ✅ | ✅ top 3 |

**Mood exclusion from SignalEngine is intentional** — mood is treated as ambient context rather than a trackable symptom signal, to avoid clinical over-reach.

## Known Gaps

### 1. Pain has no trend visualisation
Pain (cramps, headache, back pain, bloating, breast tenderness) is the most universally logged category across all life stages, but users have no way to see whether their pain is trending better or worse over 3–9 months. The trend chart infrastructure exists and could be extended.

**Impact:** Regular, irregular, and perimenopause users logging consistent pain have no longitudinal view of it.

### 2. Gut / Body has no trend visualisation
Digestive and hormonal indicator symptoms (nausea, bloating, food cravings, appetite changes, discharge changes) are logged but only surface in the monthly top-3 chips. No month-over-month chart.

**Impact:** Lower priority than pain — gut symptoms are less clinically actionable for the target life stages.

### 3. Musculoskeletal has no trend chart
Joint pain and muscle aches are clinically significant for perimenopause and menopause users, appear in the snapshot card, but have no month-over-month trend line.

**Impact:** A user managing joint pain as part of their menopause experience cannot see whether it's improving or worsening over time.

### 4. Intimate Health has no trend chart
Vaginal dryness, urinary urgency, and pain with sex are menopause-only. They appear in the snapshot count but not in the trend history sheet.

**Impact:** These symptoms are often progressive or responsive to treatment (e.g. HRT). Users most likely to act on trend data have the least visibility.

### 5. Sleep metric is thin
The Sleep chart in TrendHistorySheet uses only `insomnia` (a binary logged symptom). Night sweats — the primary cause of disrupted sleep in perimenopause and menopause — are categorised as vasomotor, not sleep. A user with frequent night sweats will show "0 insomnia days" on the Sleep chart despite sleeping poorly.

**Possible fix:** Derive sleep score from `insomnia OR nightSweats`, or collapse the Sleep chart into the Hot Flashes chart with a "incl. night sweats" note.

## Decision

Accept the current coverage as-is for v2 ship. The monthly summary (top 3 symptoms with trend arrows) provides a minimum viable signal for all categories. The gaps above are candidates for a dedicated "Insights" screen in v3.

## Candidates for v3

Ordered by clinical relevance for the target life stages:

1. **Pain trend chart** — affects all life stages, highest user volume
2. **Musculoskeletal trend chart** — perimenopause/menopause specific, high signal value
3. **Sleep metric improvement** — include night sweats in sleep derivation
4. **Intimate Health trend chart** — menopause only, small audience but high actionability
5. **Gut trend chart** — lowest priority

## References

- `Sources/Views/Home/TrendHistorySheet.swift` — current trend chart implementation
- `Sources/Services/Signal/SignalEngine.swift` — signal engine category coverage
- `Sources/Views/Home/LifeStageAdaptiveCards.swift` — snapshot card
- `Sources/Views/Home/MonthlySummaryView.swift` — monthly summary top symptoms
