#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/testflight/check-entitlements.sh against real codesign: a bundle signed with every entitlement passes; one
# missing a key or an array element, or signed without any, or not signed at all, fails.

CHECK="$BATS_TEST_DIRNAME/../check-entitlements.sh"
EXPECTED="$BATS_TEST_DIRNAME/../../../Baseline/Baseline.entitlements"

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  APP="$BATS_TEST_TMPDIR/Fake.app"
  mkdir -p "$APP"
  cp /usr/bin/true "$APP/Fake"
  plutil -create xml1 "$APP/Info.plist"
  plutil -insert CFBundleExecutable -string Fake "$APP/Info.plist"
  plutil -insert CFBundleIdentifier -string com.example.fake "$APP/Info.plist"
}

# Ad-hoc signs the fake app with the given entitlements file.
sign() { codesign --force --sign - --entitlements "$1" "$APP" 2>/dev/null; }

@test "passes when every entitlement is signed in, with extras the signing adds" {
  cp "$EXPECTED" "$BATS_TEST_TMPDIR/signed.plist"
  plutil -insert get-task-allow -bool false "$BATS_TEST_TMPDIR/signed.plist"
  sign "$BATS_TEST_TMPDIR/signed.plist"
  run -0 "$CHECK" "$APP" "$EXPECTED"
  [[ "$output" == "Entitlements: all "*" present" ]]
}

@test "fails naming a missing key" {
  cp "$EXPECTED" "$BATS_TEST_TMPDIR/signed.plist"
  /usr/libexec/PlistBuddy -c "Delete :com.apple.security.application-groups" "$BATS_TEST_TMPDIR/signed.plist"
  sign "$BATS_TEST_TMPDIR/signed.plist"
  run -1 "$CHECK" "$APP" "$EXPECTED"
  [[ "$output" == *"missing entitlements: com.apple.security.application-groups"* ]]
}

@test "fails naming a missing array element" {
  plutil -create xml1 "$BATS_TEST_TMPDIR/signed.plist"
  /usr/libexec/PlistBuddy -c "Merge $EXPECTED" "$BATS_TEST_TMPDIR/signed.plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.icloud-services:0" "$BATS_TEST_TMPDIR/signed.plist"
  sign "$BATS_TEST_TMPDIR/signed.plist"
  run -1 "$CHECK" "$APP" "$EXPECTED"
  [[ "$output" == *"com.apple.developer.icloud-services CloudKit"* ]]
}

@test "fails for an app signed without entitlements, and one not signed at all" {
  codesign --force --sign - "$APP" 2>/dev/null
  run -1 "$CHECK" "$APP" "$EXPECTED"
  [[ "$output" == *"com.apple.developer.healthkit"* ]]
  codesign --remove-signature "$APP/Fake"
  rm -rf "$APP/_CodeSignature"
  run -1 "$CHECK" "$APP" "$EXPECTED"
  [[ "$output" == *"error:"* ]]
}
