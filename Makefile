# Baseline — developer tooling. Run targets from the repository root.
# See `make help`.

PROJECT      := Baseline.xcodeproj
SCHEME       := Baseline
DERIVED_DATA := $(CURDIR)/.build/DerivedData
BUNDLE_ID    := com.cadre.baseline

# Simulator auto-detection: booted iPhone Pro -> first available iPhone Pro -> fallback.
# grep -v Max excludes "Pro Max" lines before extracting the device name.
BOOTED_SIM  := $(shell xcrun simctl list devices booted 2>/dev/null | grep -E 'iPhone [0-9]+ Pro' | grep -v Max | grep -oE 'iPhone [0-9]+ Pro' | head -n1)
AVAIL_SIM   := $(shell xcrun simctl list devices available 2>/dev/null | grep -E 'iPhone [0-9]+ Pro' | grep -v Max | grep -oE 'iPhone [0-9]+ Pro' | head -n1)
SIM_DEVICE  := $(or $(BOOTED_SIM),$(AVAIL_SIM),iPhone 16 Pro)
DESTINATION := platform=iOS Simulator,name=$(SIM_DEVICE)

.PHONY: help setup generate build test test-ui test-snapshots test-all lint format sim clean

help:
	@echo "Baseline — make targets:"
	@echo "  setup           Install tooling (brew bundle) + configure git hooks"
	@echo "  generate        Regenerate Baseline.xcodeproj from project.yml"
	@echo "  build           Build the app for the simulator"
	@echo "  test            Run logic tests + UI tests (Baseline-CI plan) — the CI gate"
	@echo "  test-ui         Run UI tests only (Baseline-UITests plan)"
	@echo "  test-snapshots  Run snapshot tests only (Baseline-Snapshots plan)"
	@echo "  test-all        Run all tests (Baseline plan)"
	@echo "  lint            Run SwiftLint"
	@echo "  format          Autocorrect with SwiftLint"
	@echo "  sim             Build, install, and launch on a simulator"
	@echo "  clean           Clean build output and DerivedData"
	@echo ""
	@echo "Simulator: $(SIM_DEVICE)"

setup:
	brew bundle
	git config core.hooksPath hooks
	@echo "Tooling installed and git hooks configured."

generate:
	xcodegen generate

build:
	set -o pipefail && xcodebuild build \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) | xcbeautify

test:
	set -o pipefail && xcodebuild test \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -testPlan Baseline-CI \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) | xcbeautify

test-ui: ## Run UI tests only (Baseline-UITests plan)
	set -o pipefail && xcodebuild test \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -testPlan Baseline-UITests \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) | xcbeautify

test-snapshots:
	set -o pipefail && xcodebuild test \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -testPlan Baseline-Snapshots \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) | xcbeautify

test-all:
	set -o pipefail && xcodebuild test \
	  -project $(PROJECT) -scheme $(SCHEME) \
	  -testPlan Baseline \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) | xcbeautify

lint:
	swiftlint lint --strict

format:
	swiftlint --fix

sim: build
	@set -e; \
	UDID=$$(xcrun simctl list devices available | grep -E '$(SIM_DEVICE) \(' | grep -oE '[0-9A-Fa-f-]{36}' | head -n1); \
	if [ -z "$$UDID" ]; then echo "No simulator found for $(SIM_DEVICE)"; exit 1; fi; \
	xcrun simctl boot "$$UDID" 2>/dev/null || true; \
	open -a Simulator; \
	APP=$$(find $(DERIVED_DATA)/Build/Products -name 'Baseline.app' -type d | head -n1); \
	if [ -z "$$APP" ]; then echo "Baseline.app not found in $(DERIVED_DATA)/Build/Products"; exit 1; fi; \
	xcrun simctl install "$$UDID" "$$APP"; \
	xcrun simctl launch "$$UDID" $(BUNDLE_ID)

clean:
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) >/dev/null 2>&1 || true
	rm -rf $(DERIVED_DATA)
