# REQ-002 — App Store Compliance Review

| Field    | Value                        |
|----------|------------------------------|
| Doc ID   | REQ-002                      |
| Version  | 1.0                          |
| Date     | 2026-04-01                   |
| Status   | Draft                        |
| Authors  | App Store Compliance Review  |

---

## Executive Summary

This document records the findings of an App Store compliance review of the Clio Daye iOS app ahead of initial submission. Four blockers must be resolved before the app can be submitted without rejection risk, covering a missing hosted privacy policy, the absence of a user-accessible data deletion mechanism, specific medication dosing language that constitutes medical advice, and an unconfigured App Privacy nutrition label. Five high-priority items are also required before submission, addressing fertile window disclaimers, a PMDD tip that implies a clinical characterisation, and missing App Store Connect metadata. All findings are mapped to the relevant Apple guidelines and include explicit acceptance criteria.

---

## Before You Submit — Checklist

Complete every item on this list before triggering App Store review.

**Blockers**
- [ ] AS-B1 — Host a privacy policy at a stable public URL and enter it in App Store Connect
- [ ] AS-B2 — Add a user-accessible "Delete All My Data" button to SettingsView
- [ ] AS-B3 — Remove ibuprofen dosing instruction from nudges.json and tips.json
- [ ] AS-B4 — Complete the App Privacy questionnaire in App Store Connect

**High Priority**
- [ ] AS-H1 — Add fertile window disclaimer to ForecastView and CycleCalendarView
- [ ] AS-H2 — Update tip.luteal.pmdd body copy to remove clinical characterisation
- [ ] AS-H3 — Prepare App Store screenshots (iPhone 6.7" required)
- [ ] AS-H4 — Configure a support URL in App Store Connect
- [ ] AS-H5 — Review App Store description; remove any mention of unbuilt features

---

## Full Requirements

### Blockers — Must Fix Before Submission

| ID    | Priority | Guideline                        | Title                                     | Description                                                                                                                                                                                                                                                                                                                                                | Acceptance Criteria                                                                                                                                                                                                                                                                                                                                        |
|-------|----------|----------------------------------|-------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| AS-B1 | Blocker  | App Store Connect req., 5.1.1   | No hosted privacy policy URL              | Apple requires a publicly accessible URL to a privacy policy for any app that collects health data. The in-app PrivacyView text does not substitute for a hosted policy. Without a live URL entered in App Store Connect, the submission will be rejected before it reaches human review.                                                                   | A privacy policy is hosted at a stable public URL (e.g. `https://cliodaye.com/privacy` or GitHub Pages). The policy covers: what data is collected (on-device cycle data, PIN); where it is stored (on-device only, no servers); data retention and deletion (user-controlled, 1-tap delete); no third-party sharing; contact information. URL is entered in App Store Connect before submission. |
| AS-B2 | Blocker  | 5.1.1                            | No user-accessible "Delete All Data" in Settings | `CycleStore.clearAllData()` exists but is only reachable from the DEBUG menu. Apple specifically checks for a user-accessible deletion mechanism in health apps. The feature must be available to all users in production builds.                                                                                                                           | A destructive "Delete All My Data" button added to SettingsView, guarded by an alert confirmation stating the action cannot be undone. On confirmation, the action calls `cycleStore.clearAllData()` and resets `hasCompletedOnboarding` to `false`. Must be accessible in all build configurations, not only DEBUG. **Files affected:** `Sources/Views/Settings/SettingsView.swift` |
| AS-B3 | Blocker  | 1.4.1                            | Ibuprofen dosing guidance constitutes medical advice | `nudge.comfort.crampsHeavy` body advises ibuprofen taken with food at the first sign of pain (not after pain peaks). `tip.menstrual.ibuprofen` gives explicit medication timing instruction. Apple treats specific medication timing advice as medical advice under guideline 1.4.1, which can cause rejection.                                              | All references to ibuprofen timing instruction removed from `nudges.json` and `tips.json`. Replaced with: "Over-the-counter pain relief may help — your pharmacist can advise on what's suitable for you." Heat/warm compress suggestions in the same nudge may remain. **Files affected:** `Resources/Content/nudges.json`, `Resources/Content/tips.json` (source of truth: `Content/clio_content.xlsx`) |
| AS-B4 | Blocker  | App Store Connect requirement    | App Privacy nutrition label not configured | Every app must complete Apple's App Privacy questionnaire before submission. Based on the codebase, the correct declarations are: Health & Fitness (menstrual cycle dates, flow, symptoms) — Data Not Linked to You — App Functionality; Sensitive Info (mood data, free-text notes) — Data Not Linked to You — App Functionality. No "Data Used to Track You" declarations are needed. | App Privacy questionnaire completed in App Store Connect with the declarations above before submission. `NSUserTrackingUsageDescription` must NOT be added to the app. |

---

### High Priority — Required Before Submission

| ID    | Priority      | Guideline      | Title                                            | Description                                                                                                                                                                                                                                                              | Acceptance Criteria                                                                                                                                                                                                                                                                                                      |
|-------|---------------|----------------|--------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| AS-H1 | High          | 5.1.3          | Fertile window displayed without disclaimer      | ForecastView and CycleCalendarView display a fertile window. Apple reviewers of cycle tracking apps specifically look for implicit contraceptive claims. Displaying a fertile window without a disclaimer can trigger a 5.1.3 rejection even without explicit contraceptive language. | A clearly visible disclaimer appears near the fertile window in both ForecastView and wherever the fertile window is surfaced: "The fertile window shown is an estimate for cycle awareness only. Clio Daye is not a contraceptive method and cannot predict fertility with certainty." Disclaimer must be in-context, not only in the privacy policy. **Files affected:** `Sources/Views/Home/ForecastView.swift`, `Sources/Views/Home/CycleCalendarView.swift` |
| AS-H2 | High          | 5.1.3, 1.4.1   | PMDD tip characterises a medical condition       | `tip.luteal.pmdd` body states "that pattern is called PMDD and is treatable." This characterises a specific mental health condition and implies a prognosis without a healthcare professional, which reviewers flag under 5.1.3 as the app providing medical information without a clinical credential. | Tip body updated to: "If mood symptoms in the second half of your cycle significantly affect your daily life, it's worth discussing with your doctor — there are recognised patterns they can help you understand." The phrases "called PMDD" and "is treatable" must be removed from the tip body. **Files affected:** `Resources/Content/tips.json` (source: `Content/clio_content.xlsx` tips sheet) |
| AS-H3 | High          | App Store Connect requirement | App Store screenshots not prepared       | Screenshots are required for at least the iPhone 6.7" size class (iPhone 16 Pro Max) before submission. The app is currently in alpha with no screenshots prepared.                                                                                                      | At least 3 screenshots for iPhone 6.7" produced, showing: (1) Home dashboard, (2) Logging/PulseView, (3) Phase tip or Forecast view. An optional iPhone 5.5" set may also be provided. An App Preview video is optional but recommended given the custom dartboard UI. |
| AS-H4 | High          | App Store Connect required field | No support URL configured               | A support URL is a required field in App Store Connect. The app currently has no support page or contact URL prepared.                                                                                                                                                    | A support URL exists and is entered in App Store Connect before submission. This can be as minimal as a GitHub Issues page or a contact email hosted at `cliodaye.com/support`. |
| AS-H5 | High          | 2.3.1          | App description must not reference unbuilt features | Data export is referenced in the PRD as a v0.4/v1.0 feature with no user-accessible UI in the current build. The App Store description must only describe functionality present in the submitted binary; describing absent features is a violation of guideline 2.3.1.   | App Store description reviewed against the actual feature set before submission. No mention of data export, BBT logging, widgets, or any other feature not present in the submitted binary. |

---

### Medium Priority

| ID    | Priority | Guideline | Title                                                           | Description                                                                                                                                                                                                                                                                                  | Acceptance Criteria                                                                                                                                                                                                                                                                     |
|-------|----------|-----------|-----------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| AS-M1 | Medium   | —         | macOS entitlements present in iOS entitlements file             | The `.entitlements` file contains `com.apple.security.app-sandbox` and `com.apple.security.files.user-selected.read-only`, which are macOS-specific entitlements. These have no effect on iOS but may be flagged by Apple's automated binary analysis during review.                         | Both macOS-specific entitlement keys removed from `safeflow.entitlements`.                                                                                                                                                                                                              |
| AS-M2 | Medium   | 5.1.1     | In-app privacy policy claims "encrypted at rest" — needs verification | PrivacyView states that data is encrypted at rest. UserDefaults is backed by a plist with `NSFileProtectionCompleteUntilFirstUserAuthentication` by default — the data is not encrypted while the device is unlocked. This makes the current claim inaccurate.                               | Either (a) upgrade data protection to `NSFileProtectionComplete` and verify the accuracy of the claim, or (b) update the in-app privacy copy to accurately state: "Your data is protected by iOS data protection and is only accessible while your device is unlocked."                  |
| AS-M3 | Medium   | Accessibility | Accessibility gaps in custom log UI                          | PulseView's dartboard logger is a custom gesture-driven UI. Custom-drawn interactive views must have explicit `accessibilityLabel`, `accessibilityHint`, and `accessibilityAction` declarations for VoiceOver. CycleCalendarView heat map cells also lack accessibility labels.               | VoiceOver pass completed on PulseView, DartboardView, and CycleCalendarView. Each interactive element has an `accessibilityLabel` stating its purpose and current state. Heat map cells read as "Date: [date], [logged/not logged]".                                                     |

---

### Low Priority / Informational

| ID    | Priority    | Guideline | Title                              | Description                                                                                                                                                                                                                                          | Acceptance Criteria                                                                                                                                                      |
|-------|-------------|-----------|------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| AS-L1 | Low / Info  | —         | Bundle ID contains old app name "safeflow" | Bundle ID `com.thevgergroup.safeflow` cannot be changed after the first App Store submission. The name mismatch is acceptable and carries no compliance risk. Documented here to prevent accidental changes.                                          | No action required. Bundle ID is locked after first submission. This entry serves as the formal record of that decision.                                                 |
| AS-L2 | Low / Info  | App Store Connect requirement | App Store metadata not configured | Required fields not yet set in App Store Connect: copyright ("© 2026 The Vger Group" or equivalent), keywords (up to 100 chars — do NOT include competitor app names), age rating (4+), subtitle (optional: "Private Cycle Tracker"), content rights declaration. | All required App Store Connect metadata fields completed before submitting for review. Keyword field must not include competitor app names.                              |
| AS-L3 | Low / Info  | —         | Version and build numbers          | `CFBundleShortVersionString = 1.0`, `CFBundleVersion = 1`. Valid for first submission. `CFBundleVersion` must be incremented with every resubmission attempt, including after a rejection.                                                           | Version matches the App Store Connect record. Build number incremented before each submission attempt.                                                                   |

---

## What the App Gets Right

The following items are correctly implemented and must be preserved. Do not change any of these.

| Item | Notes |
|------|-------|
| No `NSUserTrackingUsageDescription` | ATT is not needed given the app's data model. Do not add this key. |
| `NSFaceIDUsageDescription` present and well-worded | Compliant as written. |
| No HealthKit entitlement | Correct for the current on-device architecture. Do not add a HealthKit entitlement. |
| `UIRequiresFullScreen = true` | Correctly set. |
| Portrait-only orientation | Correctly set. |
| Severity signal wording ("worth discussing with a doctor") | This phrasing is App Store safe. Do not change it. |
| GetSupportView disclaimer ("Clio Daye does not share your data with them") | Exactly the language guideline 5.1.3 expects. Do not change it. |
| Local notifications only | No remote push entitlement needed; correctly absent. |
| Debug menu guarded with `#if DEBUG` | Will not be visible to App Store reviewers. |
| No third-party SDKs | Eliminates an entire class of ATT, GDPR, and data broker compliance concerns. |

---

## How to Action

Work is split into three parallel tracks. Tracks 2 and 3 can begin immediately without engineering involvement.

### Track 1 — Code Changes (engineer)

| Finding | Action |
|---------|--------|
| AS-B2   | Add a "Delete All My Data" destructive button with alert confirmation to `Sources/Views/Settings/SettingsView.swift`. Call `cycleStore.clearAllData()` and reset `hasCompletedOnboarding`. Must be present in production builds. |
| AS-H1   | Add the fertile window disclaimer string to `Sources/Views/Home/ForecastView.swift` and `Sources/Views/Home/CycleCalendarView.swift` (or wherever the fertile window is rendered), positioned in-context near the window display. |
| AS-M1   | Remove `com.apple.security.app-sandbox` and `com.apple.security.files.user-selected.read-only` from `safeflow.entitlements`. |
| AS-M2   | Audit the data protection class for the UserDefaults-backed store and either upgrade to `NSFileProtectionComplete` or update the privacy copy in PrivacyView to remove the "encrypted at rest" claim. |
| AS-M3   | Complete a VoiceOver pass on PulseView, DartboardView, and CycleCalendarView. Add `accessibilityLabel`, `accessibilityHint`, and `accessibilityAction` to all interactive elements. |

### Track 2 — Content Pipeline Changes (edit clio_content.xlsx, then run `make content`)

| Finding | Action |
|---------|--------|
| AS-B3   | In the `nudges` sheet: update `nudge.comfort.crampsHeavy` to remove the ibuprofen timing instruction. In the `tips` sheet: update `tip.menstrual.ibuprofen` to remove the dosing guidance. Replace both with: "Over-the-counter pain relief may help — your pharmacist can advise on what's suitable for you." |
| AS-H2   | In the `tips` sheet: update `tip.luteal.pmdd` body to: "If mood symptoms in the second half of your cycle significantly affect your daily life, it's worth discussing with your doctor — there are recognised patterns they can help you understand." Remove "called PMDD" and "is treatable". |

### Track 3 — External / Operational

| Finding | Action | Owner |
|---------|--------|-------|
| AS-B1   | Write and host a privacy policy at a stable public URL. Enter the URL in App Store Connect under App Information before submission. | Legal / ops |
| AS-B4   | Complete the App Privacy questionnaire in App Store Connect with the declarations specified in AS-B4. Do not add `NSUserTrackingUsageDescription`. | App Store Connect admin |
| AS-H3   | Capture at least 3 screenshots at iPhone 6.7" resolution: (1) Home dashboard, (2) PulseView/logging, (3) Phase tip or Forecast. Upload to App Store Connect. | Designer / QA |
| AS-H4   | Create a support URL (e.g. `cliodaye.com/support` or a GitHub Issues link) and enter it in App Store Connect. | Ops |
| AS-H5   | Draft the App Store description. Cross-reference against the binary feature set. Remove any mention of data export, BBT logging, widgets, or other unbuilt features. | Product |
| AS-L2   | Complete all remaining App Store Connect metadata: copyright, keywords (no competitor names), age rating (4+), subtitle, content rights declaration. | App Store Connect admin |

---

## Related Documents

| Document | Description |
|----------|-------------|
| `docs/requirements/REQ-001-content-safety-audit.md` | Clio Advisor content and safety audit |
| `PRD.md` | Product Requirements Document |
| `docs/adr/ADR-001-content-pipeline.md` | Content pipeline architecture decision |
| `CLAUDE.md` | Project coding guidelines |
