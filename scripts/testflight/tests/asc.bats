#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/testflight/asc.swift offline: the token's shape, error reports and its usage.
# Nothing here talks to App Store Connect.

ASC="$BATS_TEST_DIRNAME/../asc.swift"

@test "selftest: the token and error reports" {
  run -0 swift "$ASC" selftest
  [ "$output" = "selftest: ok" ]
}

@test "help, and refusals without the key env or with an unknown command" {
  run -0 swift "$ASC" --help
  [[ "$output" == *"count-certificates [--type <certificateType>]"* ]]
  run -1 env -u ASC_KEY_ID -u ASC_ISSUER_ID -u ASC_KEY_PATH swift "$ASC" count-certificates
  [[ "$output" == *"not set: ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH"* ]]
  run -1 swift "$ASC" send-to-friends
  [[ "$output" == *"unknown command send-to-friends"* ]]
}

@test "a file that isn't a .p8 key is refused without showing it" {
  printf 'SECRETCONTENTS\n' >"$BATS_TEST_TMPDIR/bad.p8"
  ASC_KEY_ID=a ASC_ISSUER_ID=b ASC_KEY_PATH="$BATS_TEST_TMPDIR/bad.p8" run -1 swift "$ASC" count-certificates
  [[ "$output" == *"isn't an App Store Connect .p8 key"* && "$output" != *SECRETCONTENTS* ]]
}
