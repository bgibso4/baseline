#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/testflight/archive.sh: the env it needs, signing with the keychain's certificate, the entitlement gate and the key.

REPO="$BATS_TEST_DIRNAME/../../.."

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/scripts/testflight" "$FIX/Baseline" "$FIX/bin"
  cp "$REPO/scripts/testflight/archive.sh" "$REPO/scripts/testflight/check-entitlements.sh" \
    "$REPO/scripts/testflight/ExportOptions.plist" "$FIX/scripts/testflight/"
  cp "$REPO/Baseline/Baseline.entitlements" "$FIX/Baseline/"
  git -C "$FIX" init -q -b main
  cd "$FIX"

  # Stub xcodebuild: echoes its arguments (so a key in them would show) and makes the archive's bundles.
  cat >"$FIX/bin/xcodebuild" <<'STUB'
#!/usr/bin/env bash
echo "xcodebuild $*"
args=("$@")
for i in "${!args[@]}"; do
  if [ "${args[$i]}" = -archivePath ] && [ "${args[0]}" = archive ]; then
    app="${args[$((i + 1))]}/Products/Applications/Baseline.app"
    mkdir -p "$app"
    plutil -create xml1 "$app/Info.plist"
    plutil -insert CFBundleShortVersionString -string 1.0 "$app/Info.plist"
    plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$app/Info.plist"
  fi
done
exit "${STUB_STATUS:-0}"
STUB
  # Stub codesign: prints the signed entitlements, STUB_ENTITLEMENTS (default: the project's file).
  cat >"$FIX/bin/codesign" <<'STUB'
#!/usr/bin/env bash
cat "${STUB_ENTITLEMENTS:-Baseline/Baseline.entitlements}"
STUB
  chmod +x "$FIX/bin/xcodebuild" "$FIX/bin/codesign"
  export TF_XCODEBUILD="$FIX/bin/xcodebuild" TF_CODESIGN="$FIX/bin/codesign" TF_BEAUTIFY=cat
  export DERIVED="$FIX/.build/DerivedData" PROJECT=P.xcodeproj

  printf -- '-----BEGIN PRIVATE KEY-----\nTHEKEYCONTENTS\n-----END PRIVATE KEY-----\n' >"$BATS_TEST_TMPDIR/AuthKey.p8"
  export ASC_KEY_ID=KEYID12345 ASC_ISSUER_ID=issuer-0000 ASC_KEY_PATH="$BATS_TEST_TMPDIR/AuthKey.p8" BUILD_NUMBER=7
}

@test "refuses without the key env" {
  unset ASC_KEY_ID
  run -2 scripts/testflight/archive.sh
  [[ "$output" == *"ASC_KEY_ID"* ]]
  [ ! -d .build/testflight ]
}

@test "refuses a missing key file or a build number that isn't a number" {
  ASC_KEY_PATH="$BATS_TEST_TMPDIR/nope.p8" run -2 scripts/testflight/archive.sh
  [[ "$output" == *"ASC_KEY_PATH"* ]]
  BUILD_NUMBER=7a run -2 scripts/testflight/archive.sh
  [[ "$output" == *"BUILD_NUMBER"* ]]
}

@test "archives signed with the team's certificate, checks the entitlements, then exports and uploads" {
  TF_BEAUTIFY="sed -n /error/p" run -0 scripts/testflight/archive.sh
  archive_call="$(grep '^xcodebuild archive ' .build/testflight/archive.log)"
  [[ "$archive_call" == *"-allowProvisioningUpdates -authenticationKeyPath $ASC_KEY_PATH"* ]]
  [[ "$archive_call" == *"CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=W6S6K84XVM CURRENT_PROJECT_VERSION=7"* ]]
  [[ "$archive_call" != *"CODE_SIGN_IDENTITY"* && "$archive_call" != *"AD_HOC"* ]]
  export_call="$(grep '^xcodebuild -exportArchive ' .build/testflight/export.log)"
  [[ "$export_call" == *"-allowProvisioningUpdates -authenticationKeyPath $ASC_KEY_PATH"* ]]
  [[ "$export_call" == *"-exportOptionsPlist scripts/testflight/ExportOptions.plist"* ]]
  [ "$output" = "$(printf 'Entitlements: all 5 present\nVersion: 1.0\nBuild: 7\nArchive: %s/.build/testflight/Baseline.xcarchive' "$(git rev-parse --show-toplevel)")" ]
}

@test "stops before the upload when the archive is missing an entitlement" {
  plutil -create xml1 "$BATS_TEST_TMPDIR/none.plist"
  STUB_ENTITLEMENTS="$BATS_TEST_TMPDIR/none.plist" run -1 scripts/testflight/archive.sh
  [[ "$output" == *"missing entitlements: com.apple.developer.healthkit"* ]]
  [ ! -f .build/testflight/export.log ]
}

@test "a failing xcodebuild fails the script and shows the log's end" {
  STUB_STATUS=65 run -1 scripts/testflight/archive.sh
  [[ "$output" == *"archive failed"* ]]
  [[ "$output" == *"xcodebuild archive "* ]]
}

@test "never prints the key" {
  TF_BEAUTIFY=cat run -0 scripts/testflight/archive.sh
  [[ "$output" == *"xcodebuild archive "* ]] # the stub's echo of its arguments got through
  [[ "$output" != *THEKEYCONTENTS* && "$output" != *"PRIVATE KEY"* ]]
  ! grep -rq THEKEYCONTENTS .build/testflight
}
