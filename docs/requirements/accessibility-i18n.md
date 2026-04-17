# Accessibility & Internationalization — Requirements & Roadmap

**Status:** Planning  
**Last updated:** 2026-04-09

---

## Overview

This document captures the technical requirements and phased roadmap for two related initiatives:

1. **Accessibility (a11y)** — WCAG 2.1 AA compliance, VoiceOver, Dynamic Type, Reduce Motion
2. **Internationalization (i18n)** — string extraction, locale-aware formatting, RTL layout

Both are planned as post-MVP work. They share some infrastructure (localized accessibility labels), so they should be scheduled together and reviewed as a pair.

---

## Current State

### What we have
- `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` enabled in project settings (Xcode 15+ string catalogs ready)
- `NSLocalizedString()` already used in model layer enums (`CycleDay.swift`, `CyclePhase.swift`)
- Some VoiceOver patterns done correctly: custom control traits in `DartboardView`, `CategoryStripView`; `reduceMotion` respected in `DartboardView`
- Good color contrast choices documented in `AppTheme.swift` (amber replaces prior gold, contrast ratios noted)

### What's missing
- No `.xcstrings` file — all View strings are hardcoded English
- No locale-aware date/number formatting in most views
- No RTL layout consideration
- Most toolbar/icon buttons missing `.accessibilityLabel`
- Most decorative images not marked `.accessibilityHidden(true)`
- Many animations don't check `reduceMotion`
- Fixed point sizes used throughout (ignores Dynamic Type)

---

## Accessibility (a11y)

### Critical issues

| Issue | Location | Notes |
|---|---|---|
| Icon-only buttons with no label | `HomeView.swift` toolbar (settings, edit logs, forecast, support) | VoiceOver reads "button" only |
| Decorative images not hidden | All view files | Should be `.accessibilityHidden(true)` |
| Ring center count has no context | `CycleRingSummaryCard.swift:158` | `Text("\(totalItemCount)")` — VoiceOver reads a bare number |
| Animation ignores reduceMotion | `CycleRingSummaryCard.swift:150`, `ViewModifiers.swift:27,45`, `HomeView.swift:467` | Add `@Environment(\.accessibilityReduceMotion)` |
| Fixed font sizes | `DartboardView.swift:128`, `CategoryStripView.swift:38`, many others | Hardcoded `.system(size: X)` ignores Dynamic Type |
| Steppers missing context hints | `OnboardingView.swift:205,229` | `.labelsHidden()` used without `.accessibilityLabel` |
| DatePicker missing label | `OnboardingView.swift:179-187` | Same pattern |
| Complex gestures not VoiceOver accessible | `WeekRibbonView`, `DartboardView` | Swipe/tap gestures; need button alternatives |
| Color-only information | `CycleCalendarView`, `ForecastView` | Mood/confidence conveyed by color only |
| Hardcoded pluralization | `CycleRingSummaryCard.swift:173` | `alert\(count == 1 ? "" : "s")` — breaks non-English |

### Phase plan

**Phase 1 — Quick wins (est. 1 week)**
- Add `.accessibilityLabel()` to all icon-only buttons
- Mark decorative images with `.accessibilityHidden(true)`
- Add `.accessibilityHint()` and `.accessibilityLabel()` to Steppers and DatePicker in Onboarding
- Add `reduceMotion` environment check to `CycleRingSummaryCard` and `ViewModifiers`

**Phase 2 — Forms & inputs (est. 1 week)**
- `PinSetupView`: label all `SecureField` inputs, add validation error hints
- `LockView`: accessibility context for locked state
- Improve `CycleRingSummaryCard` ring center: `accessibilityLabel("Day X of your cycle, Y items")`

**Phase 3 — Complex controls (est. 2 weeks)**
- `DartboardView`: provide list-based text alternative for VoiceOver users
- `WeekRibbonView`: add button alternatives for swipe navigation
- `CycleCalendarView`: add table semantics or improve VoiceOver scan order
- Color-only indicators: add pattern fills or icons alongside color in calendar and forecast

**Phase 4 — Dynamic Type (est. 1 week)**
- Audit all `.font(.system(size: X))` calls and replace with relative sizes (`.body`, `.headline`, `.caption`, etc.)
- Test layouts at 200% font scale — fix any clipping or overflow
- AppTheme: define relative size tokens to use consistently

**Phase 5 — Validation (est. 1 week)**
- Run Xcode Accessibility Inspector against all screens
- Full VoiceOver walkthrough of primary user flows
- Add XCUITest accessibility assertions to UI test suite

### Definition of done
- Xcode Accessibility Inspector shows zero critical issues on all primary screens
- Full app flow is navigable with VoiceOver only
- All animations respect `reduceMotion`
- All text scales correctly at max Dynamic Type size without layout breaks
- WCAG 2.1 Level AA contrast ratios validated for all text/background combinations

---

## Internationalization (i18n)

### Scope decision
The initial target is full string extraction + locale-aware formatting, enabling translation to multiple languages. RTL support (Arabic, Hebrew) is a follow-on phase requiring more layout work.

### Critical issues

| Issue | Location | Notes |
|---|---|---|
| No `.xcstrings` file | Project root | All View strings inaccessible to localization |
| ~150+ hardcoded English strings in Views | All view files | See breakdown below |
| `DateFormatter` with hardcoded format patterns | `HomeView.swift:194`, `CycleCalendarView.swift:437,468,494-496,609`, `WeekRibbonView.swift:165-166,510,515`, `CyclePhaseCard.swift:138` | Must use `.formatted()` or locale-aware API |
| Hardcoded English units mixed into strings | `OnboardingView.swift:201,225`, `CycleRingSummaryCard.swift:427` | `"\(n) days"` — "days" not extractable |
| Tip content all hardcoded | `PhaseTipCard.swift:66-110+` | 50+ strings, highest volume single file |
| RTL layout not considered | All views | Uses left/right positioning; needs leading/trailing audit |

### String volume by file (high priority first)

| File | Approx. string count | Notes |
|---|---|---|
| `PhaseTipCard.swift` | 50+ | All tip body content |
| `OnboardingView.swift` | 20+ | Full onboarding flow |
| `SettingsView.swift` | 15+ | All settings labels, alerts |
| `PinSetupView.swift` | 10+ | Setup and entry flows |
| `HomeView.swift` | 12+ | Nav, logging sheet |
| `CycleCalendarView.swift` | 10+ | Legend, empty states |
| `CycleRingSummaryCard.swift` | 10+ | Status strings, badges |
| `WeekRibbonView.swift` | 10+ | Chart legend, day detail |
| `ForecastView.swift` | 8+ | Section headers, legend |
| `GetSupportView.swift` | 5+ | Filter labels, empty states |

### Phase plan

**Phase 1 — Foundation (est. 1 week)**
- Create `Localizable.xcstrings` using Xcode string catalog
- Extract all `Text("…")` strings from View files into catalog
- Establish string key naming convention: `"view.element.description"` (e.g., `"settings.security.requireAuth"`)
- Write a short dev guide for adding new strings correctly

**Phase 2 — Date & number formatting (est. 1 week)**
- Replace all `DateFormatter` instances using hardcoded `dateFormat` patterns with `.formatted()` API
- Replace `"\(n) days"` patterns with `Measurement` or locale-aware unit formatting
- Use `formatted(.number)` for bare integer counts where appropriate
- Test with en_US, en_GB, de_DE, fr_FR, ja_JP locales

**Phase 3 — Pluralization (est. 1 week)**
- Move from manual `count == 1 ? "" : "s"` to Swift string catalog plural forms
- Handle languages with multiple plural categories (e.g., Russian, Arabic have 6 forms)
- Review `CycleRingSummaryCard`, `HomeView`, `CycleCalendarView` for all plural strings

**Phase 4 — RTL layout (est. 2 weeks)**
- Audit all `HStack` alignment and `.padding(.leading/.trailing)` — replace with `.leading`/`.trailing` semantic edges
- Review `DartboardView` and `CategoryStripView` (coordinate-based positioning) for RTL adjustments
- Test with system locale set to Hebrew or Arabic
- Add `environment(\.layoutDirection, .rightToLeft)` preview variant to key views

**Phase 5 — Translation & QA (est. ongoing)**
- Export `.xcstrings` for translation (starting with Spanish, French, German as first targets)
- Test translated builds on device
- Check for string truncation and layout breaks under longer translations (German tends to be ~30% longer)

### Definition of done (Phase 1–4)
- Zero hardcoded English user-visible strings remain in any View file
- All date/number formatting uses locale-aware APIs
- App layout is correct in both LTR and RTL locales
- String catalog is complete and ready for first translation export

---

## Dependencies & risks

| Risk | Mitigation |
|---|---|
| Tip content volume (`PhaseTipCard`) — translating 50+ nuanced health-adjacent strings requires care | Treat tip strings as a separate translation workstream; review with domain knowledge |
| RTL layout changes could break existing LTR layout | Build RTL previews into Xcode alongside LTR from the start |
| Dynamic Type layout breaks at large sizes | Test during implementation, not after |
| Accessibility labels must themselves be localized | Do i18n and a11y label work together in Phase 1 |
| Some strings are rendered only in debug builds | Mark clearly in string catalog; exclude from translation |

---

## Out of scope
- CloudKit or server-based localization delivery (violates on-device-only constraint)
- Right-to-left support in v1 if schedule is tight — defer to explicit RTL milestone
- Accessibility support for watchOS (not yet in scope)
