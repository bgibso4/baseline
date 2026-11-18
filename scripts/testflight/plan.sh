#!/usr/bin/env bash
# The TestFlight workflow's plan: prints true (upload) or false (skip), with the reason on stderr.
#   plan.sh <event> <sha> <ref>
# workflow_run (CI passed on a push to main): skip only when nothing but docs/ and Markdown changed since the
#   commit of the last run whose upload job succeeded (its run-name carries the sha). CI cancels superseded runs and
#   the testflight concurrency group replaces pending ones, so that can be several merges back. No earlier upload,
#   or one that can't be found: upload.
# workflow_dispatch: uploads, but only main, and only a commit CI passed on a push (exit 2 otherwise).
# Reads GITHUB_REPOSITORY; calls the GitHub API through gh (GH_TOKEN, actions: read). TF_GH is a seam for the tests.
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
gh="${TF_GH:-gh}"
event="$1" sha="$2" ref="$3"
repo="$GITHUB_REPOSITORY"

say() { echo "$*" >&2; }

if [ "$event" = workflow_dispatch ]; then
	[ "$ref" = refs/heads/main ] || { say "error: TestFlight uploads only main; this run is on $ref."; exit 2; }
	green="$("$gh" api "repos/$repo/actions/workflows/ci.yml/runs?head_sha=$sha&event=push&status=success&per_page=1" \
		--jq '.total_count')" || green=0
	[ "${green:-0}" -gt 0 ] || { say "error: CI hasn't passed for $sha on main; wait for it, then run this again."; exit 2; }
	echo true
	exit 0
fi
[ "$event" = workflow_run ] || { say "error: unexpected event $event"; exit 2; }

# The sha of the last run whose upload job succeeded, or nothing.
last_upload() {
	local runs id title
	runs="$("$gh" api "repos/$repo/actions/workflows/testflight.yml/runs?branch=main&status=success&per_page=50" \
		--jq '.workflow_runs[] | "\(.id) \(.display_title)"')" || { say "warning: couldn't list earlier TestFlight runs."; return 0; }
	while read -r id title; do
		[ -n "$id" ] || continue
		[ "$("$gh" api "repos/$repo/actions/runs/$id/jobs" --jq '.jobs[] | select(.name == "upload") | .conclusion' \
			2>/dev/null)" = success ] || continue
		grep -oE '[0-9a-f]{40}' <<<"$title" | head -1
		return 0
	done <<<"$runs"
}

base="$(last_upload)"
if [ -z "$base" ]; then
	say "No earlier upload found: upload."
	echo true
elif ! git cat-file -e "$base^{commit}" 2>/dev/null; then
	say "The last upload ($base) isn't in this history: upload."
	echo true
elif scripts/docs-only.sh "$base" "$sha"; then
	say "Only docs/ and Markdown changed since the last upload ($base): no upload."
	echo false
else
	say "Code changed since the last upload ($base): upload."
	echo true
fi
