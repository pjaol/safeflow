# ADR-002: Internationalisation & Localisation Architecture

**Date:** 2026-04-14
**Status:** Accepted
**Deciders:** Patrick (product), Claude Code (implementation)
**Languages shipped:** en, de-DE, es-MX, fr-FR

---

## Context

Clio Daye needed in-app language switching for TestFlight testers across de-DE, es-MX, and fr-FR locales, without requiring users to change their device language in Settings. The standard iOS per-app language setting only works if the user navigates to Settings → Clio Daye → Language — too much friction for TestFlight feedback.

---

## Decision

### 1. In-app locale switching via `@AppStorage` + SwiftUI environment

```swift
// SafeFlowApp.swift
@AppStorage("appLanguage") private var appLanguage: String = "en"

WindowGroup {
    ...
}
.environment(\.locale, Locale(identifier: appLanguage.isEmpty ? "en" : appLanguage))
```

A `Picker` in `DebugMenu` writes to `appLanguage`. The SwiftUI locale environment cascades to all child views automatically.

**Key insight:** This only works if all user-visible strings use `LocalizedStringKey` — not `NSLocalizedString` or `String(localized:)`. The latter two resolve at call time using the system/bundle locale and completely ignore `.environment(\.locale, ...)`.

---

## The Core Rule

| API | Respects SwiftUI `.environment(\.locale)` | Use for |
|-----|------------------------------------------|---------|
| `Text("Literal")` | ✅ Yes — `Text` auto-promotes string literals to `LocalizedStringKey` | All user-visible `Text` views |
| `Text(localizedStringKey)` | ✅ Yes | Computed `LocalizedStringKey` values |
| `NSLocalizedString(...)` | ❌ No — uses system locale | Remove entirely |
| `String(localized: ...)` | ❌ No — uses system locale | Only for non-view string contexts (accessibility, logging) |
| `DateFormatter` without `.locale` | ❌ No — uses system locale | Always set `formatter.locale = locale` |
| `.formatted(.dateTime...)` | ❌ No by default | Use `.formatted(.dateTime...locale(locale))` |
| `Calendar.current.weekdaySymbols` | ❌ No — uses system locale | Set `cal.locale = locale` first |

---

## Pattern: `LocalizedStringKey` vs `String` variants

For model types (`Symptom`, `Mood`, `FlowIntensity`, `CyclePhase`, etc.) that need their label in both view and non-view contexts, the pattern is:

```swift
// Use in Text() — respects environment locale
var localizedName: LocalizedStringKey {
    switch self {
    case .cramps: return "Cramps"
    }
}

// Use in string interpolation, accessibility hints, sorting, logging
var localizedNameString: String {
    switch self {
    case .cramps: return String(localized: "Cramps")
    }
}
```

`localizedNameString` won't translate when the SwiftUI environment locale differs from system locale — this is an accepted trade-off for accessibility strings and non-view contexts.

---

## Pattern: `sectionHeader` and helper functions

Functions that return `some View` containing `Text` must accept `LocalizedStringKey`, not `String`:

```swift
// ❌ Wrong — string literal loses LocalizedStringKey identity
private func sectionHeader(_ title: String, ...) -> some View {
    Text(title) // resolves as String, not LocalizedStringKey
}

// ✅ Correct
private func sectionHeader(_ title: LocalizedStringKey, ...) -> some View {
    Text(title) // resolves from xcstrings via SwiftUI environment
}
```

---

## Pattern: `DateFormatter` locale

Every `DateFormatter` must have its locale set explicitly. Use `@Environment(\.locale)` in the view, then pass it to formatters.

```swift
@Environment(\.locale) private var locale

// For locale-aware ordering (e.g. "16. Apr." in German, "Apr. 16" in English)
let f = DateFormatter()
f.locale = locale
f.setLocalizedDateFormatFromTemplate("MMMd")  // NOT f.dateFormat = "MMM d"

// For explicit formats that don't change by locale (internal keys, etc.)
let f = DateFormatter()
f.dateFormat = "yyyy-MM-dd"  // no locale needed — format is fixed
```

`setLocalizedDateFormatFromTemplate` takes the field symbols you want (e.g. `"MMMd"`, `"EEEEMMMd"`) and lets the locale determine ordering and separators. This is always preferable to hardcoding `dateFormat` for display strings.

---

## Pattern: navigation title ternary

Swift's type inference won't automatically unify a ternary over two string literals as `LocalizedStringKey`:

```swift
// ❌ Inferred as String — won't translate
.navigationTitle(condition ? "Edit Log" : "New Log")

// ✅ Explicit LocalizedStringKey
.navigationTitle(condition ? LocalizedStringKey("Edit Log") : LocalizedStringKey("New Log"))
```

---

## Pattern: `\n` in translation strings

SwiftUI `Text(LocalizedStringKey)` renders `\n` in xcstrings values as a real line break. Useful for long translated strings in space-constrained layouts (e.g. dartboard segments):

```json
"Brain Fog": {
  "fr": { "value": "Brouillard\nmental" },
  "es": { "value": "Niebla\nmental" }
}
```

Also remember to increase `.lineLimit` if you do this:
```swift
Text(item.label)
    .lineLimit(2)  // was 1
    .multilineTextAlignment(.center)
```

---

## `Localizable.xcstrings` — the critical structure requirement

Xcode only emits an `en.lproj` folder in the built app bundle if at least one key has an explicit `en` localisation entry. Without `en.lproj`, `Bundle.preferredLocalizations` returns the first alphabetically available lproj (e.g. `fr`) — making the entire app appear in the wrong language on a clean English simulator before any user selection.

**Every key must have an explicit `en` entry:**

```json
"Cramps": {
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Cramps" } },
    "de": { "stringUnit": { "state": "translated", "value": "Krämpfe" } },
    "es": { "stringUnit": { "state": "translated", "value": "Cólicos" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Crampes" } }
  }
}
```

When adding keys in bulk, use a Python script to ensure `en` is always included:

```python
import json

def entry(en, de, es, fr, comment=""):
    e = {"localizations": {
        "en": {"stringUnit": {"state": "translated", "value": en}},
        "de": {"stringUnit": {"state": "translated", "value": de}},
        "es": {"stringUnit": {"state": "translated", "value": es}},
        "fr": {"stringUnit": {"state": "translated", "value": fr}},
    }}
    if comment:
        e["comment"] = comment
    return e

with open('Sources/Localizable.xcstrings') as f:
    data = json.load(f)

data['strings']['New Key'] = entry("New Key", "Neuer Schlüssel", "Nueva clave", "Nouvelle clé")

with open('Sources/Localizable.xcstrings', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
```

---

## Adding a new language

To add a fifth language (e.g. `pt-BR`):

1. **Add to xcstrings** — update the Python helper to include `"pt"` in every `entry()` call, then run it against all existing keys.

2. **Add to `DebugMenu` picker:**
   ```swift
   Text("Português (pt-BR)").tag("pt-BR")
   ```

3. **Add to `SafeFlowApp.swift` locale environment** — no change needed; `Locale(identifier: appLanguage)` handles any BCP-47 tag automatically.

4. **Add to `resources.json`** — research and add locale-appropriate crisis, mental health, and condition-specific organisations with `"region": "BR"` (or relevant country code) and `"languages": ["pt"]`.

5. **Translate `PatternNudgeCard` and `PhaseTipCard` content** — these contain long-form wellness and medical copy that was deferred. These should be reviewed by a native speaker before shipping.

6. **Test on a clean simulator** — create a new simulator to avoid OS-level per-app language overrides bleeding in from previous test sessions (these are stored outside the app container and survive `simctl erase`).

---

## `GetSupportView` — regional resource suppression

When a user's locale maps to a region that has its own crisis or category resources, global (English-language) resources are suppressed to avoid showing English content to non-English users:

- **Crisis section:** if the effective region (selected filter or device locale) has regional crisis entries → show only those, hide global fallbacks (e.g. IAPMD suppressed for DE/FR/MX users who have native-language hotlines).
- **Non-crisis categories:** per-category suppression — if a category has a regional entry, global entries in that same category are hidden.
- **No regional entries exist:** fall back to global resources.

The effective region is derived from `@Environment(\.locale)` (not `Locale.current`) so it tracks the in-app language selection, not the device OS language. iOS region code `GB` is mapped to `UK` to match resource file conventions.

---

## Debugging locale issues

The debug banner (visible in DEBUG and BETA builds) shows:

```
appLanguage: "de-DE" → de-DE
OS AppleLanguages: en-US, en
OS AppleLocale: en_US
Bundle locale: en
```

`Bundle locale: fr` on a clean English device = `en.lproj` missing from the built bundle → add explicit `en` entries to all xcstrings keys.

`Bundle locale: en` with app displaying wrong language = OS-level per-app language override stored in system database. Fix: delete and recreate the simulator (wipe alone is not sufficient).

---

## Files changed in this work

| File | Change |
|------|--------|
| `Sources/App/SafeFlowApp.swift` | `@AppStorage("appLanguage")` + `.environment(\.locale, ...)` + debug banner |
| `Sources/Localizable.xcstrings` | All keys now have explicit `en` entries; translations for de/es/fr across all views |
| `Sources/Models/CycleDay.swift` | `localizedName: LocalizedStringKey` + `localizedNameString: String` for all enums |
| `Sources/Models/CyclePhase.swift` | Same pattern; `import SwiftUI` required for `LocalizedStringKey` |
| `Sources/Views/Debug/DebugMenu.swift` | Inline language `Picker` |
| `Sources/Views/Home/HomeView.swift` | `LogCalendarView` locale-aware weekday symbols and month label; `LogDayFormView` `sectionHeader` takes `LocalizedStringKey`; button labels |
| `Sources/Views/Home/LogDayView.swift` | `sectionHeader` takes `LocalizedStringKey`; navigation title |
| `Sources/Views/Home/WeekRibbonView.swift` | `ChartRange.label: LocalizedStringKey`; all `DateFormatter` instances get `.locale`; `setLocalizedDateFormatFromTemplate` |
| `Sources/Views/Home/CyclePhaseCard.swift` | `DateFormatter` locale; `@Environment(\.locale)` |
| `Sources/Views/Home/ForecastView.swift` | `legendChip` takes `LocalizedStringKey` |
| `Sources/Views/Home/CycleCalendarView.swift` | `legendChip` takes `LocalizedStringKey`; sort uses `localizedNameString` |
| `Sources/Views/Home/CycleRingSummaryCard.swift` | `DetailTab.label`, `badge` take `LocalizedStringKey` |
| `Sources/Views/Home/DartboardViewModel.swift` | `DartboardCategory.label`, `DartboardItem.label` as `LocalizedStringKey` |
| `Sources/Views/Home/DartboardView.swift` | `.lineLimit(2)` for multi-line translated segment labels |
| `Sources/Views/Home/GetSupportView.swift` | `categoryLabel`, `regionLabel`, `FilterChip`, `LinkButton` fully localised; regional resource suppression logic |
| `Sources/Views/Security/LockView.swift` | All button labels translated |
| `Sources/Views/Settings/SettingsView.swift` | All section headers, privacy copy, alerts translated |
| `Resources/Content/resources.json` | DE, FR, MX crisis/health/condition resources added |
