#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/testflight/plan.sh: whether the TestFlight workflow uploads (true/false), and when it refuses a dispatch.

REPO="$BATS_TEST_DIRNAME/../../.."

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/scripts/testflight" "$FIX/bin"
  cp "$REPO/scripts/docs-only.sh" "$FIX/scripts/"
  cp "$REPO/scripts/testflight/plan.sh" "$FIX/scripts/testflight/"
  git -C "$FIX" init -q -b main
  git -C "$FIX" config user.email t@example.com
  git -C "$FIX" config user.name t
  cd "$FIX"
  git add -A && git commit -qm scripts

  # Stub gh: answers from files. runs: "<id> <title>" lines (newest first); jobs-<id>: the upload job's conclusion;
  # ci-green: how many green CI push runs the commit has. STUB_GH_FAIL=1 makes every call fail.
  export STUB="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB"
  cat >"$FIX/bin/gh" <<'GH'
#!/usr/bin/env bash
[ -z "${STUB_GH_FAIL:-}" ] || { echo "gh: HTTP 502" >&2; exit 1; }
case "$2" in
*/workflows/testflight.yml/runs*) cat "$STUB/runs" 2>/dev/null ;;
*/runs/*/jobs) id="${2%/jobs}"; cat "$STUB/jobs-${id##*/}" 2>/dev/null ;;
*/workflows/ci.yml/runs*) cat "$STUB/ci-green" 2>/dev/null || echo 0 ;;
*) echo "unexpected: $*" >&2; exit 1 ;;
esac
GH
  chmod +x "$FIX/bin/gh"
  export TF_GH="$FIX/bin/gh" GITHUB_REPOSITORY=owner/repo
}

# Commits a change to each path given and prints the new commit's sha.
commit() {
  for path in "$@"; do
    mkdir -p "$(dirname "$path")"
    printf 'changed %s\n' "$RANDOM" >>"$path"
  done
  git add -A && git commit -qm change && git rev-parse HEAD
}

# Records an earlier TestFlight run. Call newest first, as the API lists them.
run_record() { # <id> <sha> <upload job conclusion>
  echo "$1 TestFlight $2" >>"$STUB/runs"
  echo "$3" >"$STUB/jobs-$1"
}

@test "skips when only docs changed since the last upload" {
  uploaded="$(commit App/A.swift)"
  commit docs/a.md >/dev/null
  head="$(commit docs/b.md README.md)"
  run_record 8 "$uploaded" success
  run -0 --separate-stderr scripts/testflight/plan.sh workflow_run "$head" refs/heads/main
  [ "$output" = false ]
}

@test "uploads when code changed anywhere since the last upload, even in an earlier merge" {
  uploaded="$(commit App/A.swift)"
  commit App/A.swift >/dev/null # merge A: its run was cancelled or replaced
  head="$(commit docs/a.md)"    # merge B: docs only
  run_record 8 "$uploaded" success
  run -0 --separate-stderr scripts/testflight/plan.sh workflow_run "$head" refs/heads/main
  [ "$output" = true ]
}

@test "a run that skipped or failed its upload isn't the last upload" {
  uploaded="$(commit App/A.swift)"
  skipped="$(commit App/A.swift)"
  head="$(commit docs/a.md)"
  run_record 9 "$skipped" skipped
  run_record 8 "$skipped" failure
  run_record 7 "$uploaded" success
  run -0 --separate-stderr scripts/testflight/plan.sh workflow_run "$head" refs/heads/main
  [ "$output" = true ]
}

@test "uploads when there is no earlier upload, or it can't be found" {
  head="$(commit docs/a.md)"
  run -0 --separate-stderr scripts/testflight/plan.sh workflow_run "$head" refs/heads/main
  [ "$output" = true ]
  run_record 8 0123456789abcdef0123456789abcdef01234567 success # not in this history
  run -0 --separate-stderr scripts/testflight/plan.sh workflow_run "$head" refs/heads/main
  [ "$output" = true ]
  STUB_GH_FAIL=1 run -0 --separate-stderr scripts/testflight/plan.sh workflow_run "$head" refs/heads/main
  [ "$output" = true ]
  [[ "$stderr" == *"couldn't list"* ]]
}

@test "a dispatch uploads only main, and only once CI has passed for it" {
  head="$(commit App/A.swift)"
  run -2 --separate-stderr scripts/testflight/plan.sh workflow_dispatch "$head" refs/heads/plan-6
  [[ "$stderr" == *"only main"* ]]
  run -2 --separate-stderr scripts/testflight/plan.sh workflow_dispatch "$head" refs/heads/main
  [[ "$stderr" == *"CI hasn't passed"* ]]
  STUB_GH_FAIL=1 run -2 --separate-stderr scripts/testflight/plan.sh workflow_dispatch "$head" refs/heads/main
  [[ "$stderr" == *"CI hasn't passed"* ]]
  echo 1 >"$STUB/ci-green"
  run -0 --separate-stderr scripts/testflight/plan.sh workflow_dispatch "$head" refs/heads/main
  [ "$output" = true ]
}
