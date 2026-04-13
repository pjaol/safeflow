# Clio Daye — development tasks

SCHEME    = safeflow
DEST      = platform=iOS Simulator,name=iPhone 17

# Use xcpretty if available, otherwise pass output through directly
XCPRETTY  := $(shell command -v xcpretty 2>/dev/null)

.PHONY: content content-tips content-nudges content-signals content-resources \
        test test-unit test-a11y test-i18n audit-strings test-all

# ── Testing ────────────────────────────────────────────────────────────────────

## Run all tests (unit + UI, default locale) — quick smoke check
test:
ifdef XCPRETTY
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  test 2>&1 | xcpretty --color
else
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  test
endif

## Run unit tests only (fast; no simulator UI required)
## testSessionTimeout is excluded — it sleeps 605 s and is not suitable for CI
test-unit:
ifdef XCPRETTY
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  -testPlan SafeFlowDefault \
	  -only-testing:safeflowTests \
	  -skip-testing:safeflowTests/SecurityTests/testSessionTimeout \
	  test 2>&1 | xcpretty --color
else
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  -testPlan SafeFlowDefault \
	  -only-testing:safeflowTests \
	  -skip-testing:safeflowTests/SecurityTests/testSessionTimeout \
	  test
endif

## Run accessibility UI tests across Dynamic Type + a11y configurations
## Requires SafeFlowAccessibility.xctestplan registered in Xcode scheme (manual test plans)
test-a11y:
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  -testPlan SafeFlowAccessibility \
	  test

## Run localisation UI tests across en-US, es-MX, fr-FR, de-DE
## Requires SafeFlowLocalisation.xctestplan registered in Xcode scheme (manual test plans)
test-i18n:
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  -testPlan SafeFlowLocalisation \
	  test

## Static audit: fail if any View file still contains hardcoded Text("...") strings
audit-strings:
	@bash scripts/audit_strings.sh

## Run unit tests + string audit (CI-safe gate — no test plan required)
## Run make test-a11y and make test-i18n separately after enabling manual test plans in Xcode
test-all: test-unit audit-strings

# ── Content ────────────────────────────────────────────────────────────────────

## Convert all CSV content files to JSON for bundling in the app
content:
	python3 scripts/csv_to_json.py

## Convert individual content files
content-tips:
	python3 scripts/csv_to_json.py tips

content-nudges:
	python3 scripts/csv_to_json.py nudges

content-signals:
	python3 scripts/csv_to_json.py signals

content-resources:
	python3 scripts/csv_to_json.py resources
