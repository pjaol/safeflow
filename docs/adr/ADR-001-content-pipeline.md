# ADR-001: Data-Driven Content Pipeline

**Date:** 2026-03-31
**Status:** Accepted
**Deciders:** Patrick (product), Claude Code (implementation)

---

## Context

All educational content in Clio Daye — phase tips, pattern nudges, severity signals, and population norms — is currently hardcoded in Swift source files. This creates three problems:

1. **Authoring friction**: adding or editing a tip requires a Swift code change, recompile, and App Store release
2. **No trigger logic**: tips are selected by simple daily rotation with no awareness of the user's actual symptoms, cycle patterns, or data maturity
3. **No path to scale**: the current approach breaks down at 50+ content items and cannot support a resource directory, contextual educational cards, or "who to contact" features

Clio Daye has a hard architectural constraint: **no network calls, no cloud sync, all data on-device only**. Any content pipeline must work entirely offline.

---

## Decision

Adopt a **CSV → JSON → bundled Swift** content pipeline with a flat trigger DSL.

### Pipeline overview

```
Content/*.csv          ← author-facing source of truth (Google Sheets / Numbers)
    ↓ scripts/csv_to_json.py
Resources/Content/*.json   ← committed output, bundled in the app target
    ↓ ContentLoader (Swift)
ContentEvaluator           ← replaces hardcoded logic in PhaseTipCard, CycleNudge, etc.
```

All steps are local. No backend, no network, no external services at authoring or runtime.

### Content types

| File | Purpose |
|---|---|
| `tips.csv` | Phase tips shown on PhaseTipCard — rotating, contextual |
| `nudges.csv` | Pattern nudges and comfort suggestions — triggered, dismissible |
| `signals.csv` | Severity signals — triggered by escalating patterns |
| `insights.csv` | Population norms paired with symptom/phase combinations |
| `resources.csv` | Bundled support directory — organisations, helplines, condition resources |

### Trigger DSL

Each content item carries flat trigger fields. No expression parser — every field is an independent AND condition. This is intentional: health content targeting rules must be trivially auditable.

```
phase              — menstrual | follicular | ovulatory | luteal | any
symptoms_any       — comma-separated symptom IDs; show if user logged any of these
symptoms_all       — comma-separated symptom IDs; show only if user logged all
cycle_count_min    — integer; gate until this many complete cycles exist
mood               — mood ID; show if dominant mood in phase matches
severity_signal    — signal ID; show only when this signal is active
dismissible        — true | false
priority           — high | medium | low
```

A `ContentEvaluator` service evaluates all items against current `CycleStore` state and returns filtered, ranked results. It replaces the scattered trigger logic currently in `PhaseTipCard.swift`, `PatternNudgeCard.swift`, and `SymptomPatternEngine.swift`.

### Supplemental resource links

Resources in `resources.csv` include URLs and phone numbers. When a user taps a resource link, the app opens it via `UIApplication.shared.open()` — the network call is made by Safari/the OS, not by Clio Daye. This is consistent with the privacy architecture: **user health data never leaves the device**; the user choosing to visit a website is a separate action under their control.

All resource descriptions are original writing by the Clio Daye team. Names, URLs, and phone numbers are facts and are not subject to copyright. No third-party health content is reproduced verbatim.

### Update strategy

Content updates ship with each app release. The CSV → JSON conversion step touches zero Swift code, so a content-only release can be submitted to the App Store with minimal review risk. Apple's expedited review is available for factual health content corrections and is typically granted within hours.

---

## Consequences

### Good
- Non-engineers can author and review content in a spreadsheet
- Trigger logic is data-driven and auditable per item
- Adding 50 new tips requires editing a CSV, not touching Swift
- The pipeline supports localisation: add a `locale` column and filter at load time
- Open source readers can audit every content decision in the CSV files
- `source` and `citation` fields make health claim provenance transparent

### Bad
- Content updates still require an App Store release (accepted — consistent with no-network constraint)
- The conversion script adds one manual step before committing new content (`make content`)
- Existing hardcoded content must be migrated (done as part of this ADR's implementation)

### Neutral
- `ContentEvaluator` adds a new service layer but removes more scattered logic than it adds

---

## Alternatives considered

**Keep hardcoding in Swift**: Rejected. Doesn't scale past ~20 items and requires engineer involvement for every content edit.

**Remote config (Firebase, CloudKit)**: Rejected. Violates the no-network architectural constraint.

**Core Data with bundled store**: Rejected. Significant complexity for read-only content under 500 records; JSON in memory is sufficient.

**Plist instead of JSON**: Viable but JSON is more portable, easier to diff in git, and readable in any text editor without Xcode.

**Full expression language for triggers (JSONLogic, CEL)**: Rejected. Health content targeting rules have implicit regulatory implications. A flat field grammar is trivially auditable; a general expression language is not.
