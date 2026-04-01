# REQ-001 — Content Safety Audit: Clio Advisor Review

| Field      | Value                        |
|------------|------------------------------|
| Doc ID     | REQ-001                      |
| Version    | 1.0                          |
| Date       | 2026-04-01                   |
| Status     | Draft                        |
| Authors    | Clio Advisor Audit           |

---

## Executive Summary

A structured safety and clinical accuracy audit of the Clio Daye iOS app identified five blocker-level issues that require immediate resolution before any public release, alongside ten high-priority recommendations and ten content and resource gaps. The blockers span crisis-resource discoverability, unsafe clinical language, a missing overdue-cycle pathway, coercive-control safeguards, and unqualified medication instruction. Addressing these findings will bring the app into alignment with the privacy-first, harm-reduction design principles established in the PRD.

---

## Scope

This document covers:

- All user-facing content rendered from `clio_content.xlsx` (tips, nudges, signals, get-support resources)
- `resources.json` — the structured list of external support organisations
- `GetSupportView`, `HomeView`, `ForecastView`, `LogDayView`, `InsightCard`, and `ContentEvaluator`
- Onboarding question set
- Notification copy
- Settings / data-privacy disclosures

Out of scope: prediction engine accuracy (covered separately), accessibility audit beyond what is called out per-finding, server infrastructure (none exists by design).

---

## Requirements

### Blockers

> Blockers must be resolved before any public or TestFlight release.

| ID | Priority | Category | Title | Description | Acceptance Criteria |
|----|----------|----------|-------|-------------|---------------------|
| B1 | **Blocker** | Safety / UX | Crisis resources buried in flat list | IAPMD Crisis, RAINN, DVH, and Crisis Text Line sit alphabetically alongside informational links in the Get Support sheet. There is no visual triage, no pinned section, and no differentiation from condition-information links. In a crisis moment a user cannot quickly identify emergency contacts. | Crisis resources (`category=crisis` AND `category=mental_health` with crisis tag) are pinned to the top of Get Support in a visually distinct section. Section header reads "If you need help now". Layout and tap targets are tested with VoiceOver enabled. |
| B2 | **Blocker** | Clinical Language | Heavy flow signal uses leakage framing | `signal.heavyFlow` body copy reads "soaking through protection", which frames heavy bleeding as a product-management failure rather than a clinical threshold. This may discourage users from seeking care. | Body copy updated to reference the clinical definition: "soaking through a pad or tampon within an hour, on multiple consecutive hours". All language implying product management failure is removed. |
| B3 | **Blocker** | Clinical Safety | No overdue-cycle pathway | The "Late" label was correctly removed. However, there is no nudge, tip, or resource for a user whose regular cycle is significantly overdue. This gap could delay care for ectopic pregnancy or leave the user without support. | A new nudge fires after 7+ days past the latest predicted period date, only when the user has 2+ cycles of prior data. Body copy is non-assumptive: "There are a few reasons a cycle can be late — stress, illness, hormonal shifts, or sometimes pregnancy. Here's what to consider." Nudge routes to GP/general health resources. Copy does not say "you might be pregnant." Implementation requires a new `check_type` in `ContentEvaluator`: `cycle_overdue`. |
| B4 | **Blocker** | Coercive Control / Privacy | No coercive-control safeguards | Refuge and DVH exist in `resources.json` but nothing routes to them. There is no quick-exit mechanism, no plain-language data-privacy note for users in unsafe situations, and persistent "log today" notifications could expose the app's nature. | (a) A quick-exit mechanism is accessible from `HomeView` (triple-tap on app icon, or a Settings toggle) that immediately closes the app and clears the screen. (b) A "Your data & privacy" section in Settings explains in plain language: data is stored on-device only, how to delete all data in one tap, and that no one can remotely access cycle data. (c) Default notification copy is reviewed and updated to not reveal the app's purpose. (d) DV resources are surfaced proactively in Get Support with a distinct callout, not buried in the flat list. |
| B5 | **Blocker** | Clinical Safety | Ibuprofen tip contains unqualified dosing guidance | `tip.menstrual.ibuprofen` gives specific NSAID dosing guidance with no contraindication caveat. Users with asthma, kidney disease, GI conditions, or who are pregnant should not take ibuprofen. | Tip body updated to include: "if ibuprofen is suitable for you — check with a pharmacist if you're unsure." `source` field updated to reference NHS ibuprofen guidance. |

---

### High Priority

> High-priority items should be resolved before v1.0 general availability.

| ID | Priority | Category | Title | Description | Acceptance Criteria |
|----|----------|----------|-------|-------------|---------------------|
| R1 | **High** | Clinical Transparency | Fixed 14-day luteal assumption undisclosed | Predictions fail silently for users with non-standard luteal phases (common in perimenopause and PCOS). Prediction errors are implicitly blamed on the user's body rather than the model's assumption. | `ForecastView` shows disclosure text: "Predictions assume a typical 14-day luteal phase. Your experience may vary." Alternatively, a calibration prompt is offered after 3+ completed cycles. |
| R2 | **High** | Content / Inclusivity | Mood labels encode moral valence | "Sensitive" is categorised as negative. "Positive / negative" section headers moralise emotion. Clinical terms such as Anxious and Irritable have no gradation. | Section headers replaced with neutral framing (e.g. "Feeling up" / "Feeling low") or removed entirely. "Sensitive" placement is audited and either moved to neutral or renamed to "Heightened". |
| R3 | **High** | UX / Clinical Framing | InsightCard low-prevalence framing discourages | Population bar showing low percentages (e.g. "5–10% of people") can inadvertently signal that a user's experience is unusual or not worth acting on. | Any prevalence below ~30% renders as "This is a recognised experience, though less common" rather than a bare percentage bar. Bar fill always conveys solidarity ("you are not alone"), not rarity ("you are unusual"). |
| R4 | **High** | Content Logic | PCOS users receive repeated identical nudges | After 2+ consecutive cycles triggering the same nudge, repeated identical messaging is unhelpful and may cause the user to disengage. | Each health-pattern nudge can only fire once per 6-cycle window (not once-ever). If the same trigger recurs after dismissal, a softer re-surface is shown: "Still noticing this pattern? Tap to revisit." |
| R5 | **High** | Clinical Language | Discharge tip is incomplete | "Discharge changes are normal" without qualification could delay care for abnormal discharge (colour, odour changes). | `tip.ovulatory.discharge` body updated to: "Clear or stretchy cervical mucus changes around ovulation are a normal hormonal sign. If you notice changes in colour, smell, or texture at other times, it's worth mentioning to a doctor." |
| R6 | **High** | Localisation / UX | No geographic routing for resources | UK users see RAINN before NHS. US users see NHS before RAINN. Device locale is available without a network call. | `GetSupportView` reads `Locale.current.region` on first load and reorders resources to surface region-matching entries first. No network call is made. |
| R7 | **High** | Clinical Language | Severity Signal 3 names endometriosis prematurely | "Cramps outside your period" signal names endometriosis as a possible cause. Premature condition labelling can generate significant anxiety before a diagnostic pathway is established. | Signal body updated to: "Cramps outside your period can have several causes. It's worth mentioning to a doctor who can help investigate." The specific condition name is removed from the signal body (it may remain in linked resources). |
| R8 | **High** | Content Gap | No perimenopause content | Users with increasing cycle variability following a prior regular history have no tailored content acknowledging perimenopausal pattern change. | New nudge `nudge.pattern.increasingVariability` fires when variability has increased significantly over the last 6 cycles compared to the prior 6. Body: "Cycle patterns can shift over time — if you've noticed significant changes over several months, it may be worth discussing with a doctor." |
| R9 | **High** | Clinical Safety | Teen users receive adult-calibrated clinical nudges | Cycles are naturally irregular for the first 2–5 years post-menarche. Short/long/variable-cycle nudges calibrated for adults will cause unnecessary alarm in teenage users. | Onboarding adds an optional question: "Are you in your first few years of tracking?" If yes, medical-attention nudges are suppressed for 12 months and replaced with: "Cycles are often irregular in the first few years — this is normal." |
| R10 | **High** | Clinical Language | Magnesium tip implies supplementation | `tip.luteal.magnesium` implies supplementation without distinguishing from dietary intake. The evidence base is moderate. | Tip body updated to focus on dietary sources: "Dark chocolate, nuts, and leafy greens are decent sources of magnesium, which some research links to reduced PMS symptoms." Supplementation implication removed. `source` field updated to reference a relevant Cochrane or ACOG reference. |
| CG8 | **High** | Clinical Safety | No proactive PMDD crisis routing | There is no severity signal for mood/psychological symptoms concentrated in the late luteal phase. PMDD carries a meaningful mortality risk and warrants a specific content pathway. | New signal `signal.pmddPattern` with `check_type: pmdd_pattern`. Fires when 3+ consecutive cycles include 3+ of (anxious, irritable, sad, sensitive) logged on days 20–28. Body: "You've been logging significant mood symptoms in the days before your period. This pattern has a name — PMDD — and it's treatable. The IAPMD has specialist support." Routes directly to IAPMD and IAPMD crisis resources in Get Support. |
| CG9 | **High** | Data Model | Pain has no severity gradation | Cramps at 9/10 and 2/10 produce identical data. Signal 1 (escalating cramps) operates on frequency only, not severity. | Symptom model extended with optional severity (1–3 scale: mild / moderate / severe) for pain-category symptoms. `LogDayView` updated to show a severity selector after a pain symptom is selected. `ContentEvaluator` signals updated to use severity data when available. Change is backwards-compatible (severity is optional). |
| RG6 | **High** | Resource Gap | No US reproductive rights resource | The app was partly designed in response to post-Roe data-privacy risk. Planned Parenthood and Abortion Finder are absent from resources. | Add to `resources.json`: Planned Parenthood (`plannedparenthood.org`, US, `reproductive_health` category, tags: `reproductive_rights`, `general`) and Abortion Finder (`abortionfinder.org`, US, `reproductive_health`, tags: `reproductive_rights`). Surface in Get Support under a "Reproductive Health" category. |

---

## Content Gaps

> Items to add to the tips, nudges, and signals pipeline in `clio_content.xlsx`.

| ID | Title | Description | Notes |
|----|-------|-------------|-------|
| CG1 | Non-menstruating tracker content | No content for users who track without menstruating (trans men on HRT, post-hysterectomy symptom monitoring). | Requires onboarding question to identify tracking goal. |
| CG2 | Uterine fibroids | No tip, nudge, or signal mentions fibroids despite being the leading cause of heavy bleeding (70–80% prevalence by age 50). | Signal should link to RG2 fibroid resources. |
| CG3 | Thyroid conditions | Hypo/hyperthyroidism affects cycles, fatigue, and brain fog. No mention in any content category. | Signal for fatigue + cycle irregularity combination. Link to RG3. |
| CG4 | Adenomyosis | Causes heavy bleeding and severe cramps; routinely misdiagnosed as endometriosis. Absent from all content. | Add distinct signal body copy; do not merge with endometriosis signal. |
| CG5 | Luteal spotting vs period start | Luteal spotting is not distinguished from period start, creating a data-quality problem and a clinical gap (associated with low progesterone). | Requires UI affordance in `LogDayView` ("Is this the start of your period?") and corresponding content. |
| CG6 | Post-hormonal-contraception cycle return | 3–6 months of irregularity is normal post-pill; 12–18 months post-injection. No onboarding or tip addresses this. | Onboarding question: "Have you recently stopped hormonal contraception?" triggers a tailored tip series. |
| CG7 | Postpartum cycle return | Postpartum return is a different pattern, often overlapping with perinatal mental health conditions. No content addresses this transition. | Coordinate with any future perinatal mental health content. |
| CG8 | PMDD crisis routing | Captured above in requirements table (High priority). | See R-CG8. |
| CG9 | Pain severity gradation | Captured above in requirements table (High priority). | See R-CG9. |
| CG10 | Vulvodynia / pelvic floor conditions | Cycle-phase-varying vulval pain has no language in the symptom set or tips. | Requires new symptom option and at least one tip. |

---

## Resource Gaps

> Items to add to `resources.json`.

| ID | Region | Organisation | URL | Suggested Category | Tags |
|----|--------|-------------|-----|--------------------|------|
| RG1a | CA | SOGC (Society of Obstetricians and Gynaecologists of Canada) | sogc.org | general_health | canada, gynaecology |
| RG1b | AU | Jean Hailes for Women's Health | jeanhailes.org.au | general_health | australia |
| RG1c | IE | Irish Endometriosis Alliance | — | endometriosis | ireland |
| RG2a | US | US Fibroid Foundation | usfibroidfoundation.org | fibroids | us, fibroids |
| RG2b | UK | UK Fibroid Network | fibroid.org.uk | fibroids | uk, fibroids |
| RG3a | UK | British Thyroid Foundation | btf-thyroid.org | general_health | uk, thyroid |
| RG3b | US | American Thyroid Association | thyroid.org | general_health | us, thyroid |
| RG4a | US | GLMA (LGBTQ+ health) | glma.org | trans_health | us, lgbtq |
| RG4b | US | Planned Parenthood trans health pages | plannedparenthood.org | trans_health | us, lgbtq, trans |
| RG5a | US | RESOLVE — National Infertility Association | resolve.org | fertility | us, infertility |
| RG5b | UK | Fertility Network UK | fertilitynetworkuk.org | fertility | uk, infertility |
| RG6a | US | Planned Parenthood | plannedparenthood.org | reproductive_health | us, reproductive_rights |
| RG6b | US | Abortion Finder | abortionfinder.org | reproductive_health | us, reproductive_rights |
| RG7a | US | NEDA (National Eating Disorders Association) | nationaleatingdisorders.org | mental_health | us, eating_disorders |
| RG7b | UK | Beat Eating Disorders | beateatingdisorders.org.uk | mental_health | uk, eating_disorders |

---

## How to Action

### Code changes required

The following findings require changes to Swift source files and cannot be addressed through the content pipeline alone:

| Finding | Files affected |
|---------|---------------|
| B1 — Crisis resources pinned | `GetSupportView.swift`, `resources.json` sort/filter logic |
| B3 — Overdue-cycle pathway | `ContentEvaluator.swift` (new `check_type: cycle_overdue`), `clio_content.xlsx` (new nudge) |
| B4 — Coercive-control safeguards | `HomeView.swift` (quick-exit), `SettingsView.swift` (data-privacy section), notification copy, `GetSupportView.swift` (DV callout) |
| CG8 — PMDD crisis routing | `ContentEvaluator.swift` (new `check_type: pmdd_pattern`), `clio_content.xlsx` (new signal) |
| CG9 — Pain severity | `CycleDay.swift` (symptom severity field), `LogDayView.swift` (severity selector), `ContentEvaluator.swift` (severity-aware signals) |
| R6 — Geographic resource routing | `GetSupportView.swift` (`Locale.current.region` sort) |
| R9 — Teen nudge suppression | `OnboardingView.swift` (new question), `ContentEvaluator.swift` (suppression logic) |

### Content-pipeline changes (clio_content.xlsx + `make content`)

The following findings are resolved by editing `clio_content.xlsx` and regenerating content assets. No Swift changes are required:

- B2 — Heavy flow clinical language
- B5 — Ibuprofen contraindication qualifier
- R3 — InsightCard prevalence framing
- R5 — Discharge tip qualification
- R7 — Endometriosis name removed from signal body
- R8 — Perimenopause variability nudge (new row)
- R10 — Magnesium dietary framing

### resources.json additions

All items in the Resource Gaps table (RG1–RG7) are additions to `resources.json`. No code changes are required provided the existing `GetSupportView` already renders entries by category and region tag. Verify that geographic routing (R6) is implemented before adding new entries, so they surface correctly for their target regions.

---

## Dependencies / Related Documents

| Document | Location | Relevance |
|----------|----------|-----------|
| PRD.md | `/docs/PRD.md` | Establishes privacy-first constraints, no-contraceptive-claims policy, on-device-only hard constraint, and 14-day luteal constant that R1 must disclose |
| ADR-001-content-pipeline.md | `/docs/adr/ADR-001-content-pipeline.md` | Defines how `clio_content.xlsx` is processed and deployed; governs the content-pipeline change process referenced in "How to Action" |
| CLAUDE.md | `/CLAUDE.md` | Project architecture overview; relevant for understanding `ContentEvaluator`, `CycleStore`, `CycleDay`, and `SecurityService` scope |
