# Clio Daye

A privacy-first menstrual cycle tracking app for iPhone.

**Your data never leaves your device.** No accounts, no cloud sync, no analytics, no third-party SDKs. Everything is stored locally using iOS standard storage.

---

## Features

- **Cycle tracking** — log flow, symptoms, and mood each day
- **Cycle ring** — visual arc showing your position in the current cycle
- **Phase awareness** — menstrual, follicular, ovulatory, and luteal phase guidance
- **Predictions** — next period estimate with confidence range based on your personal history
- **Forecast** — multi-cycle calendar view with fertile window estimates
- **Insights** — personalised pattern recognition across your logged cycles
- **Symptom dartboard** — quick visual logging of pain, energy, mood, and gut symptoms
- **History heat map** — scrollable calendar of your logged days
- **Health nudges** — non-alarmist pattern signals (high variability, escalating cramps, PMDD pattern, overdue cycle)
- **Privacy lock** — Face ID, Touch ID, or PIN gate
- **No subscription** — free, forever

---

## Privacy

Clio Daye is built on a simple principle: your health data belongs to you.

- All data is stored on-device only (iOS UserDefaults + Keychain)
- No server, no API calls, no cloud sync
- No analytics or tracking SDKs — zero third-party code
- Full data deletion in one tap (Settings → Delete All My Data)
- Open source so you can verify these claims yourself

[Full privacy policy →](PRIVACY.md)

---

## Requirements

- iOS 17.5+
- iPhone (portrait only)

---

## Building

```bash
# Clone the repo
git clone https://github.com/pjaol/safeflow.git
cd safeflow/safeflow

# Open in Xcode
open safeflow.xcodeproj
```

Build with **Cmd+B**, run with **Cmd+R**. No dependencies to install — pure Apple frameworks only (SwiftUI, LocalAuthentication, Security).

### Run tests

```bash
xcodebuild -project safeflow.xcodeproj \
  -scheme safeflow \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

---

## Architecture

| Layer | Details |
|---|---|
| UI | SwiftUI, MVVM |
| Concurrency | async/await, @MainActor |
| Storage | UserDefaults (cycle data), iOS Keychain (PIN) |
| Predictions | Pure stateless `CyclePredictionEngine` struct — fully unit tested |
| Content | JSON-driven nudges, tips, insights, signals — no hardcoded copy |
| Security | `SecurityService` (biometric + PIN) + `SecurityManager` (keychain ops) |
| Debug | `#if DEBUG` gated debug menu with 7 test scenarios |

No third-party dependencies. No network layer. No HealthKit.

---

## Project structure

```
safeflow/
├── Sources/
│   ├── App/                  # Entry point, navigation
│   ├── Models/               # CycleDay, CyclePhase, etc.
│   ├── Services/
│   │   ├── Content/          # ContentEvaluator, JSON loaders
│   │   ├── Persistence/      # CycleStore, CyclePredictionEngine
│   │   ├── Security/         # SecurityService, SecurityManager
│   │   └── TestData/         # Test data loader (debug only)
│   ├── Shared/Theme/         # AppTheme, colours, metrics
│   └── Views/                # All SwiftUI views
├── Resources/
│   ├── Content/              # nudges.json, tips.json, signals.json, insights.json
│   └── TestData/             # CSV scenarios for debug testing
└── Tests/
    ├── UnitTests/            # CyclePredictionEngineTests, CycleStoreTests, SecurityTests
    └── UITests/
```

---

## Clio Advisor

This project uses a bespoke design review process called the **Clio Advisor** — a set of lenses applied to every feature before it ships:

1. **Cycle science** — clinically accurate, body-neutral language
2. **Inclusion** — designed for irregular cycles, diverse users, and accessibility needs
3. **Trauma-informed UX** — no surveillance patterns, no dismissible health information, gradual disclosure
4. **Femtech ethics** — no contraceptive claims, no monetisation of health data, no dark patterns

---

## Roadmap

- v0.2 ✅ — Prediction engine, symptom insights, forecast view, onboarding
- v0.3 — Data export (CSV), partner/doctor sharing (opt-in, explicit consent)
- v1.0 — App Store release

---

## Contributing

Issues and pull requests are welcome. Please read the [privacy policy](PRIVACY.md) to understand the data constraints before proposing features that involve networking or third-party services — those will not be accepted.

---

## License

MIT
