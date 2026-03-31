# Clio Daye — development tasks

.PHONY: content content-tips content-nudges content-signals content-resources

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
