# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clio Daye (bundle: `com.thevgergroup.safeflow`) is a privacy-first menstrual cycle tracking iOS app. All data is stored exclusively on-device — no server backend, no third-party APIs, no cloud sync. User data never leaves the device.

Current stage: v1.1.1 — accessibility, i18n, and App Store submission complete. v2 roadmap in progress.

## Building

**From Xcode:** Open `safeflow.xcodeproj`. Use the `safeflow` scheme for Release/Debug, `safeflow-Beta` for Beta builds.

**From CLI:**
```bash
# Build (simulator)
xcodebuild -project safeflow.xcodeproj -scheme safeflow \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all unit tests
xcodebuild -project safeflow.xcodeproj -scheme safeflow \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test class or method
xcodebuild -project safeflow.xcodeproj -scheme safeflow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:safeflowTests/CycleStoreTests test

xcodebuild -project safeflow.xcodeproj -scheme safeflow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:safeflowTests/SecurityTests/testPINManagement test
```

## Build Configurations

Three configurations exist — the distinction matters for `#if` guards:

| Config | Swift flag | Debug menu | Test data loader | Signing | Destination |
|---|---|---|---|---|---|
| Debug | `DEBUG` | ✅ | ✅ | Automatic | Local development |
| Beta | `BETA` | ✅ | ✅ | Manual / Distribution | TestFlight |
| Release | _(none)_ | ❌ | ❌ | Manual / Distribution | App Store |

`#if DEBUG || BETA` guards the in-app locale switcher, test data loader, and debug menu. Production strips all of this. Never use `#if DEBUG` alone for things that should also appear in Beta.

## Release Pipeline

Tag pushes to `main` trigger GitHub Actions automatically:

```bash
# App Store release → release.yml → Release config → App Store Connect
git tag v1.1.1 && git push origin v1.1.1

# TestFlight beta → beta.yml → Beta config → TestFlight
git tag v1.2.0-beta.1 && git push origin v1.2.0-beta.1
```

Full flow: PR `release/x.x` → `main`, then tag on `main`. See `docs/BRANCHING.md` and `docs/RELEASE-PIPELINE.md`.

App Store metadata and screenshots are managed separately:
```bash
bundle exec fastlane metadata    # upload localised metadata + screenshots
bundle exec fastlane screenshots # regenerate screenshots (slow — runs UI tests)
```

## Tests

Test plans in `Tests/`:
- `SafeFlowDefault.xctestplan` — unit tests (CI gate)
- `SafeFlowAccessibility.xctestplan` — VoiceOver, Dynamic Type, audit UI tests
- `SafeFlowLocalisation.xctestplan` — locale assertion UI tests

Key test files:
- `UnitTests/CycleStoreTests.swift` — CRUD, predictions, range queries (isolated `UserDefaults` suite)
- `UnitTests/SecurityTests.swift` — PIN, auth state, session timeout
- `UITests/AccessibilityAuditTests.swift` — automated a11y audit per screen
- `UITests/LocalisationUITests.swift` — asserts translated strings render for each locale
- `UITests/SnapshotTests.swift` — App Store screenshot capture (fastlane `screenshots` lane)

UI tests that rely on content use `accessibilityIdentifier` strings (e.g. `"home.cycleRingSummaryCard"`) rather than text, so they don't break across locales.

## Architecture

**Pattern:** SwiftUI + MVVM + Service layer  
**Concurrency:** `async/await` with `@MainActor` and `@globalActor`  
**Min deployment:** iOS 26, portrait only

### App Entry & Navigation

`SafeFlowApp.swift` controls three exclusive states via `@AppStorage` + `@StateObject`:
1. **Onboarding** → `OnboardingView`
2. **Locked** → `LockView`
3. **Unlocked** → `HomeView`

`SecurityService` is initialised asynchronously; a `ProgressView` is shown until it's ready. Locale and onboarding flags are applied in `init()` — before first render — not in `onAppear`.

### Data Layer

- **`CycleStore`** (`Services/Persistence/CycleStore.swift`) — primary data service. CRUD for `CycleDay`, cycle prediction, average cycle length. Uses `PersistenceService`.
- **`PersistenceService`** — `@globalActor`-isolated, serialises `[CycleDay]` as JSON into `UserDefaults` key `"cycleDays"`.
- **`CycleDay`** (`Models/CycleDay.swift`) — core `Codable` struct: `UUID`, `Date`, `FlowIntensity?`, `[Symptom]`, `Mood?`, notes.

`Models/CycleStore.swift` is a near-empty stub — the real implementation is in `Services/Persistence/CycleStore.swift`.

### Security Layer

- **`SecurityService`** (`Services/Security/SecurityService.swift`) — biometric + PIN auth, publishes `isUnlocked`, 10-minute inactivity timeout.
- **`SecurityManager`** (`Services/Security/SecurityManager.swift`) — low-level Keychain ops, 2-minute background timeout. PIN stored under key `"com.thevgergroup.safeflow.pin"`.

### Theme

All visual constants in `Shared/Theme/AppTheme.swift`: pastel blue `#A8DFF7`, soft pink `#FEC8D8`, pale yellow `#FFF5C3`, SF Pro Rounded, corner radius 16. Reusable modifiers in `Shared/Theme/ViewModifiers.swift`.

## Internationalisation (i18n)

Shipped locales: **en-US, de-DE, fr-FR, es-MX**. All strings are in `Sources/Localizable.xcstrings`.

**Critical rule:** Use `Text("Literal string")` for all user-visible text — `Text` auto-promotes string literals to `LocalizedStringKey` and respects `.environment(\.locale, ...)`. Never use `NSLocalizedString` or `String(localized:)` in views — these ignore the SwiftUI locale environment and break in-app locale switching and snapshot tests.

For model types that need a string in non-view contexts (accessibility labels, logging), provide both:
```swift
var localizedName: LocalizedStringKey { "Cramps" }         // use in Text()
var localizedNameString: String { String(localized: "Cramps") } // use in accessibility/sorting
```

In-app locale switching is `#if DEBUG || BETA` only — production uses the iOS system locale. See `docs/adr/ADR-002-i18n-l10n-architecture.md` for the full rationale.

## Accessibility (a11y)

All primary screens have a full VoiceOver pass as of v1.1.1. Key patterns:

- Use `.accessibilityAddTraits()` — never assign `.accessibilityTraits` directly (overwrites existing traits)
- Use `.accessibilityElement(children: .combine)` to group list rows
- Composite labels on complex controls (e.g. dartboard, cycle ring, phase card)
- All animations check `@Environment(\.accessibilityReduceMotion)`
- All decorative images use `.accessibilityHidden(true)`
- Sheet/modal dismissal returns focus to the trigger via `@AccessibilityFocusState`

Automated audit: `UITests/AccessibilityAuditTests.swift` runs per-screen audits. Run these before any PR touching views.

App Store accessibility declarations (published after v1.1.1 goes live): VoiceOver, Voice Control, Larger Text, Dark Interface, Differentiate Without Color Alone, Sufficient Contrast, Reduced Motion.

## Key Constraints

- **No third-party dependencies** — pure Apple frameworks only.
- **No network calls** — no `URLSession`, no external APIs, ever.
- **Privacy-first** — `UserDefaults` + Keychain only. No CloudKit, no iCloud sync.
- **Portrait only** — `UISupportedInterfaceOrientations` is portrait-only.
- **No medication tracking** — deferred until a clinical partner is in place. Do not spec or build.
