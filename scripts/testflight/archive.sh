#!/usr/bin/env bash
# Archives the app and uploads it to App Store Connect for TestFlight (`make testflight-archive`, the TestFlight
# workflow). Reads ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (the .p8 file) and BUILD_NUMBER, and PROJECT and DERIVED
# (the Makefile passes them).
#
# The archive signs with the Apple Development certificate already in the keychain (the workflow installs it from a
# secret), fetching its development profile with the key. Baseline's entitlements (HealthKit, CloudKit, the App Group)
# can't be signed without one; with it in the keychain Xcode never creates a certificate, which the workflow checks.
# The archive must carry every entitlement in Baseline/Baseline.entitlements (check-entitlements.sh) before the export
# signs it with the team's cloud-managed distribution certificate (the key must be Admin) and uploads.
#
# Prints the version, the build and the archive path. xcodebuild's output goes to .build/testflight/{archive,export}.log
# (only its errors are shown), and the key is passed by path, never read.
# TF_XCODEBUILD, TF_CODESIGN and TF_BEAUTIFY are seams for the bats tests (TF_CODESIGN reaches check-entitlements.sh).
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
xcodebuild="${TF_XCODEBUILD:-xcodebuild}"
codesign="${TF_CODESIGN:-codesign}"
beautify="${TF_BEAUTIFY:-xcbeautify --quieter}"
options="scripts/testflight/ExportOptions.plist"
out="$root/.build/testflight"
archive="$out/Baseline.xcarchive"

fail() {
	echo "error: $*" >&2
	exit 2
}

missing=""
for name in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH BUILD_NUMBER; do
	[ -n "${!name:-}" ] || missing="$missing $name"
done
[ -z "$missing" ] || fail "not set:$missing"
[ -f "$ASC_KEY_PATH" ] || fail "ASC_KEY_PATH names no file"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || fail "BUILD_NUMBER must be a positive whole number"

team="$(/usr/libexec/PlistBuddy -c 'Print :teamID' "$options")"

# Runs xcodebuild with its output in .build/testflight/<step>.log, showing only errors; on failure, the log's end.
run_xcodebuild() {
	local step="$1"
	shift
	local log="$out/$step.log"
	if ! "$xcodebuild" "$@" 2>&1 | tee "$log" | $beautify; then
		echo "error: $step failed. The end of $log:" >&2
		tail -40 "$log" >&2
		exit 1
	fi
}

rm -rf "$out"
mkdir -p "$out"

run_xcodebuild archive archive -project "$PROJECT" -scheme Baseline -configuration Release \
	-destination 'generic/platform=iOS' -archivePath "$archive" -derivedDataPath "$DERIVED" \
	-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" \
	-authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
	CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$team" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

app="$archive/Products/Applications/Baseline.app"
[ -d "$app" ] || { echo "error: the archive has no Baseline.app" >&2; exit 1; }
TF_CODESIGN="$codesign" scripts/testflight/check-entitlements.sh "$app" Baseline/Baseline.entitlements

run_xcodebuild export -exportArchive -archivePath "$archive" -exportPath "$out/export" -exportOptionsPlist "$options" \
	-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" \
	-authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"

plist="$app/Info.plist"
echo "Version: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
echo "Build: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
echo "Archive: $archive"
