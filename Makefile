# Clio Daye — development tasks

SCHEME    = safeflow
DEST      = platform=iOS Simulator,name=iPhone 17

.PHONY: content content-tips content-nudges content-signals content-resources \
        test test-unit test-a11y test-i18n audit-strings test-all

# ── Testing ────────────────────────────────────────────────────────────────────

## Run all tests (unit + UI, default locale) — quick smoke check
test:
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  test 2>&1 | xcpretty --color || \
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  test

## Run unit tests only (fast; no simulator UI required)
test-unit:
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  -only-testing:safeflowTests \
	  test 2>&1 | xcpretty --color

## Run accessibility UI tests across Dynamic Type + a11y configurations
test-a11y:
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  -testPlan SafeFlowAccessibility \
	  test 2>&1 | xcpretty --color

## Run localisation UI tests across en-US, es-MX, fr-FR, de-DE
test-i18n:
	xcodebuild -project safeflow.xcodeproj \
	  -scheme $(SCHEME) \
	  -destination '$(DEST)' \
	  -testPlan SafeFlowLocalisation \
	  test 2>&1 | xcpretty --color

## Static audit: fail if any View file still contains hardcoded Text("...") strings
audit-strings:
	@bash scripts/audit_strings.sh

## Run everything — required to pass before opening a PR to release/1.1
test-all: test-unit test-a11y test-i18n audit-strings

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
