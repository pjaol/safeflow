# Accessibility & Internationalization — Requirements & Roadmap

**Status:** Shipped — v1.1.1 (2026-04-17)  
**Last updated:** 2026-04-17

---

## Overview

This document captures the technical requirements and phased roadmap for two related initiatives:

1. **Accessibility (a11y)** — WCAG 2.1 AA compliance, VoiceOver, Dynamic Type, Reduce Motion
2. **Internationalization (i18n)** — string extraction, locale-aware formatting, RTL layout

Both are planned as post-MVP work. They share some infrastructure (localized accessibility labels), so they should be scheduled together and reviewed as a pair.

---

## Shipped in v1.1.1

### Accessibility
- Full VoiceOver pass: labels, traits, grouping, and focus management across all primary screens
- All icon-only buttons have `.accessibilityLabel`
- Decorative images marked `.accessibilityHidden(true)`
- All animations respect `accessibilityReduceMotion`
- Dynamic Type supported throughout — system font styles, `@ScaledMetric` for metrics
- Increase Contrast respected — foreground colors adapt to `colorSchemeContrast`
- Color-only indicators replaced with icon/text alternatives
- Composite accessibility labels for complex controls (dartboard, phase card, cycle ring)
- Data-accessible chart summaries for WeekRibbonView month/3M modes
- Automated accessibility audit tests added (`AccessibilityAuditTests.swift`)

### Internationalisation
- Full `Localizable.xcstrings` string catalog — all user-visible strings extracted
- Locale-aware date and number formatting throughout
- Shipped in 4 locales: en-US, de-DE, fr-FR, es-MX
- App Store metadata and screenshots localised for all 4 locales
- In-app locale switching available in DEBUG/BETA builds via DebugMenu
- Production builds use iOS system locale (per ADR-002)

### App Store accessibility declarations (publish when v1.1.1 is live)
- VoiceOver ✅
- Voice Control ✅
- Larger Text ✅
- Dark Interface ✅
- Differentiate Without Color Alone ✅
- Sufficient Contrast ✅
- Reduced Motion ✅

---

## Remaining / future work

---

## Future work

### Accessibility
- Custom VoiceOver rotors for content-heavy screens (history calendar, forecast list)
- Assistive Access simplified mode (iOS 18+) — reduced complexity layout
- Full keyboard navigation audit (Full Keyboard Access)
- WCAG 2.1 AA contrast ratio formal audit against all text/background combos in AppTheme

### Internationalisation
- RTL layout support (Arabic, Hebrew) — requires leading/trailing audit across all views
- Additional locales beyond en/de/fr/es — candidates: pt-BR, it, ja
- Pluralisation audit — some strings still use manual `count == 1 ? "" : "s"` patterns
- Translation memory / glossary for health terminology consistency across locales

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
