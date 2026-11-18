#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/docs-only.sh: whether a change touches only docs/ and Markdown (the TestFlight skip).

REPO="$BATS_TEST_DIRNAME/../.."

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX"
  git -C "$FIX" init -q -b main
  git -C "$FIX" config user.email t@example.com
  git -C "$FIX" config user.name t
  cd "$FIX"
  commit App/A.swift
}

# Commits a change to each path given.
commit() {
  for path in "$@"; do
    mkdir -p "$(dirname "$path")"
    printf 'changed %s\n' "$RANDOM" >>"$path"
  done
  git add -A && git commit -qm change
}

@test "skips a docs-only merge" {
  commit docs/plan.md README.md
  run -0 "$REPO/scripts/docs-only.sh" HEAD^1 HEAD
}

@test "uploads a merge that touches code" {
  commit docs/plan.md App/A.swift
  run -1 "$REPO/scripts/docs-only.sh" HEAD^1 HEAD
  commit scripts/testflight/archive.sh
  run -1 "$REPO/scripts/docs-only.sh" HEAD^1 HEAD
}

@test "takes a range" {
  commit docs/a.md
  commit App/A.swift
  run -1 "$REPO/scripts/docs-only.sh" HEAD~2...HEAD
  run -0 "$REPO/scripts/docs-only.sh" HEAD~2...HEAD~1
}

@test "an empty change counts as docs-only, and a bad revision fails" {
  git commit -q --allow-empty -m empty
  run -0 "$REPO/scripts/docs-only.sh" HEAD^1 HEAD
  run -128 "$REPO/scripts/docs-only.sh" nope HEAD
}
