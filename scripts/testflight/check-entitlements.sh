#!/usr/bin/env bash
# Fails unless a signed app carries every entitlement in the entitlements file it was built from: each key, and every
# element of each array. An archive signed without a certificate, or not at all, silently drops them (HealthKit,
# CloudKit, the App Group), and such a build must never reach TestFlight.
#   check-entitlements.sh <app bundle> <entitlements file>
# TF_CODESIGN is a seam for the bats tests.
set -euo pipefail
app="$1" expected="$2"
codesign="${TF_CODESIGN:-codesign}"

signed="$(mktemp)"
trap 'rm -f "$signed"' EXIT
"$codesign" -d --entitlements - --xml "$app" >"$signed" 2>/dev/null ||
	{ echo "error: can't read the signature of $app" >&2; exit 1; }

python3 -I - "$expected" "$signed" <<'PY'
import plistlib, sys

with open(sys.argv[1], "rb") as file:
    expected = plistlib.load(file)
try:
    with open(sys.argv[2], "rb") as file:
        signed = plistlib.load(file)
except Exception:  # unsigned or no entitlements: nothing is present
    signed = {}

missing = []
for key, value in expected.items():
    have = signed.get(key)
    if isinstance(value, list):
        if not isinstance(have, list):
            missing.append(key)
        else:
            missing += [f"{key} {item}" for item in value if item not in have]
    elif have != value:
        missing.append(key)

if missing:
    sys.exit("error: the signed app is missing entitlements: " + ", ".join(missing))
print(f"Entitlements: all {len(expected)} present")
PY
