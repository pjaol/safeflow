# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SafeFlow is a privacy-first menstrual cycle tracking iOS app. All data is stored exclusively on-device — no server backend, no third-party APIs, no cloud sync. User data never leaves the device.

Current stage: 0.1-alpha MVP.

## Project Structure

```
safeflow/                    ← repo root (this directory)
├── safeflow.xcodeproj/
├── Sources/                 ← All app source code
│   ├── App/
│   ├── Models/
│   ├── Services/
│   ├── Shared/
│   ├── Utilities/
│   └── Views/
└── Tests/
    ├── UnitTests/
    └── UITests/
```

## Building

**From Xcode:** Open `safeflow.xcodeproj`. Build with Cmd+B, run with Cmd+R.

**From CLI (xcodebuild):**
```bash
# Build for simulator
xcodebuild -project safeflow.xcodeproj \
  -scheme safeflow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Run unit tests
xcodebuild -project safeflow.xcodeproj \
  -scheme safeflow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test

# Run a single test class
xcodebuild -project safeflow.xcodeproj \
  -scheme safeflow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:safeflowTests/CycleStoreTests \
  test

# Run a single test method
xcodebuild -project safeflow.xcodeproj \
  -scheme safeflow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:safeflowTests/SecurityTests/testPINManagement \
  test
```

## Architecture

**Pattern:** SwiftUI + MVVM + Service layer
**Concurrency:** `async/await` with `@MainActor` and `@globalActor` for thread safety
**Min deployment:** iOS (portrait only, full screen required)

### App Entry & Navigation Flow

`SafeFlowApp.swift` controls three exclusive states using `@AppStorage` + `@StateObject`:
1. **Onboarding** (first launch) → `OnboardingView`
2. **Locked** → `LockView`
3. **Unlocked** → `HomeView`

`SecurityService` is created asynchronously at startup, injected via `@EnvironmentObject`.

### Data Layer

- **`CycleStore`** (`Services/Persistence/CycleStore.swift`) — the primary data service. Handles all CRUD for `CycleDay` records, cycle prediction logic, and average cycle length calculation. Uses `PersistenceService` for storage.
- **`PersistenceService`** — `@globalActor`-isolated service that serializes `[CycleDay]` as JSON into `UserDefaults` under key `"cycleDays"`.
- **`CycleDay`** (`Models/CycleDay.swift`) — the core `Codable` struct with `UUID`, `Date`, `FlowIntensity?`, `[Symptom]`, `Mood?`, and notes.

There is a near-empty `Models/CycleStore.swift` (12 lines) separate from the real `Services/Persistence/CycleStore.swift` — the latter is what matters.

### Security Layer

- **`SecurityService`** (`Services/Security/SecurityService.swift`, 239 lines) — high-level authentication orchestrator. Manages biometric (Face ID/Touch ID via LocalAuthentication) and PIN auth. Publishes `isUnlocked` state. Enforces a 10-minute inactivity timeout.
- **`SecurityManager`** (`Services/Security/SecurityManager.swift`, 128 lines) — low-level keychain operations for PIN storage/retrieval. Listens to app lifecycle notifications. Enforces a 2-minute background timeout.
- PIN is stored in iOS Keychain under `"com.thevgergroup.safeflow.pin"`.

### Theme

All visual constants live in `Shared/Theme/AppTheme.swift`:
- **Colors:** Pastel Blue (`#A8DFF7`), Soft Pink (`#FEC8D8`), Pale Yellow (`#FFF5C3`)
- **Typography:** SF Pro Rounded, system rounded design
- **Metrics:** Corner radius 16, button radius 25, standard spacing 20

Reusable `ViewModifier`s are in `Shared/Theme/ViewModifiers.swift`.

### Debug Builds

`Views/Debug/DebugMenu.swift` and `Views/Debug/TestCaseRunner.swift` are compiled only in `DEBUG` configuration. They provide data reset, onboarding reset, and test case execution.

## Tests

Tests live in `Tests/`:
- `UnitTests/CycleStoreTests.swift` — 5 tests covering add/update/delete, range queries, predictions. Uses an isolated `UserDefaults` suite (not the real store) for test isolation.
- `UnitTests/SecurityTests.swift` — 4 tests covering PIN management, auth state, auth requirements, session timeout.
- `UITests/safeflowUITests.swift` — basic launch/integration tests.

## Key Design Constraints

- **No third-party dependencies** — pure Apple frameworks only (SwiftUI, LocalAuthentication, Security framework for Keychain).
- **No network calls anywhere** — the app has no `URLSession` usage, no external APIs.
- **Privacy-first data model** — `UserDefaults` + Keychain only. No CloudKit, no iCloud sync.
- **Portrait only** — `UISupportedInterfaceOrientations` is portrait-only; `UIRequiresFullScreen: true`.
