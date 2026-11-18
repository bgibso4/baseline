#!/usr/bin/env bash
# Exits 0 when a change touches only docs/ and Markdown (or nothing), 1 when it touches anything else.
#   docs-only.sh <git diff revisions…>   e.g. HEAD^1 HEAD, or BASE...HEAD
# The TestFlight workflow's plan (scripts/testflight/plan.sh) uses it to skip the upload.
set -euo pipefail
changed="$(git diff --name-only "$@")"
[ -z "$changed" ] || ! grep -qvE '^docs/|\.md$' <<<"$changed"
