# Branching Strategy

**Last updated:** 2026-04-10

---

## Overview

We use a lightweight trunk-based strategy optimised for a small team (1–2 engineers). The goal is:
- `main` is always releasable
- Fixes reach users fast, without blocking feature work
- v2 development can proceed in parallel without disrupting post-launch stability

---

## Branch structure

```
main                         ← production; always App Store releasable
├── release/1.x              ← patch/hotfix holding branch for v1
│   └── fix/...              ← individual bug fixes against v1
├── release/1.1              ← v1.1 accessibility & i18n (Track A)
│   └── fix/...              ← fixes found during v1.1 development
└── feature/v2/...           ← v2 feature branches off main
```

### `main`
- Reflects what is currently live in the App Store (or the next imminent release)
- Direct commits to `main` only for trivial copy/doc fixes
- All code changes via PR

### `release/1.x`
- Branched from the v1.0 App Store commit
- All post-launch bug fixes and patch releases (1.0.1, 1.0.2, etc.) branch from and merge back into `release/1.x`
- `release/1.x` is merged forward into `main` and into `release/1.1` after each patch ships
- Archived (not deleted) when v1.1 ships

### `release/1.1`
- Branched from `main` (after absorbing any outstanding `release/1.x` patches)
- All v1.1 Track A work: accessibility, i18n string extraction, locale-aware formatting
- Individual pieces of work branch off `release/1.1` as `fix/a11y-*` or `fix/i18n-*` branches and PR back in
- When complete, `release/1.1` → `main` via PR and is tagged `v1.1.0`
- `release/1.1` is then merged into any in-flight `feature/v2/*` branches to keep them current

### `fix/<description>`
- Short-lived; branched from the appropriate release branch
- One fix per branch
- v1.0.x fixes: branch from `release/1.x` → PR back to `release/1.x`
- v1.1 work: branch from `release/1.1` → PR back to `release/1.1`
- Examples: `fix/a11y-toolbar-labels`, `fix/i18n-date-formatter`, `fix/prediction-nil-crash`

### `feature/v2/<description>`
- Branched from `main`
- All v2.0+ work; can be long-lived
- Rebased onto `main` regularly to absorb v1.1 patches as they land
- Merged to `main` only when the feature is complete, tested, and ready to include in a v2 release candidate
- Examples: `feature/v2/life-stage-settings`, `feature/v2/expanded-symptoms`, `feature/v2/symptom-first-home`

---

## Release versioning

We follow semantic versioning: `MAJOR.MINOR.PATCH`

| Type | Version bump | Branch | Example |
|---|---|---|---|
| App Store hotfix | PATCH | `fix/*` → `release/1.x` → `main` | 1.0.0 → 1.0.1 |
| v1.1 (accessibility & i18n) | MINOR | `fix/*` → `release/1.1` → `main` | 1.0.x → 1.1.0 |
| v2 release | MAJOR | `feature/v2/*` → `main` | 1.1.x → 2.0.0 |

---

## Day-to-day workflow

### Shipping a post-launch patch (v1.0.x)

```bash
git checkout release/1.x
git checkout -b fix/my-fix
# ... make fix, add tests ...
git push origin fix/my-fix
# PR → release/1.x
# after merge: PR release/1.x → main
# also merge release/1.x → release/1.1 to keep it current
git checkout release/1.1
git merge release/1.x
```

### Working on v1.1 (accessibility / i18n)

```bash
git checkout release/1.1
git checkout -b fix/a11y-toolbar-labels
# ... make change, add tests ...
git push origin fix/a11y-toolbar-labels
# PR → release/1.1
```

### Shipping v1.1

When all v1.1 checklist items are complete and TestFlight is signed off:

```bash
# PR release/1.1 → main
# tag on main after submission
git tag v1.1.0
git push origin v1.1.0
# merge main into any open feature/v2/* branches
git checkout feature/v2/my-feature
git rebase origin/main
```

### Working on v2

```bash
git checkout main
git checkout -b feature/v2/my-feature
# ... build feature ...
git push origin feature/v2/my-feature
# PR → main when feature complete and tested
```

### Keeping v2 branches up to date

Rebase onto `main` at least weekly to absorb v1.x patches and the eventual v1.1 merge:

```bash
git fetch origin
git rebase origin/main
```

---

## PR rules

- Every PR requires at least one reviewer (can be async for solo work — review your own diff the next morning)
- CI must pass: build + unit tests
- No PR merges with failing tests
- PR descriptions must reference the relevant milestone or issue

---

## Tag convention

App Store submissions are tagged on `main`:

```
v1.0.0    ← initial App Store release
v1.0.1    ← first patch (from release/1.x)
v1.1.0    ← accessibility & i18n (from release/1.1)
v2.0.0    ← life-stage expansion launch
```

Tag immediately after the build is submitted to App Store Connect:

```
git tag v1.0.1
git push origin v1.0.1
```

---

## What we don't do

- **No `develop` branch.** Unnecessary indirection for a small team.
- **No long-lived `staging` branch.** TestFlight builds come from `main` or a release branch directly.
- **No squash-merging feature branches.** Preserve commit history for `git blame` usefulness.
- **No force-pushing to `main` or `release/1.x`.** Ever.
