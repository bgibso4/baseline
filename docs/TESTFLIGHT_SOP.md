# TestFlight Release SOP

Standard procedure for cutting a new TestFlight build of Baseline. First run takes ~30 min for one-time ASC setup; subsequent runs take ~10 min hands-on plus 5–15 min of Apple processing time.

> Audience: solo developer + small private tester group (you + your wife). All testing is **internal** — no Beta App Review needed, no privacy policy URL required, no marketing copy.

---

## Prerequisites (one-time, first build only)

Skip this section after the first successful TestFlight build.

### 1. Apple Developer account
- Paid Apple Developer Program membership active (Team ID `W6S6K84XVM`).
- Logged into Xcode with the same Apple ID: **Xcode → Settings → Accounts**.

### 2. App Store Connect record
- App created in App Store Connect at https://appstoreconnect.apple.com → My Apps → +.
  - Bundle ID: `com.cadre.baseline`
  - Name: `Baseline`
  - Primary language: English (U.S.)
  - SKU: `baseline-ios` (or any string; not user-facing)

### 3. Internal testing group
- ASC → My Apps → Baseline → **TestFlight** → **Internal Testing** → +
- Add yourself and your wife by Apple ID email.
- Toggle on "Automatic distribution" so new builds become available without manual approval each time.

### 4. Code signing
- Xcode → Baseline target → **Signing & Capabilities** → Automatic signing on, team `W6S6K84XVM`.
- Repeat for `BaselineWidgets` target.
- If anything fails: see `axiom-code-signing-diag` skill or run `security find-identity -v -p codesigning` to confirm a valid Apple Distribution cert exists.

---

## Standard release flow (every build)

### Step 1 — Pre-flight

```bash
git status                 # clean working tree
git pull                   # ensure main is current
xcodebuild -project Baseline.xcodeproj -scheme Baseline \
  -destination 'generic/platform=iOS Simulator' build | tail -5
```

If the build fails locally it will fail in archive. Fix first.

### Step 2 — Bump version numbers

iOS apps have two version fields. Don't conflate them.

| Field | Plist key | Purpose | When to bump |
|-------|-----------|---------|--------------|
| `MARKETING_VERSION` | `CFBundleShortVersionString` | Tester/user-facing version (e.g. `1.0.1`, `1.1`, `2.0`) | **Only** when the release is meaningful enough for testers to notice |
| `CURRENT_PROJECT_VERSION` | `CFBundleVersion` | ASC build disambiguator (monotonic integer: 1, 2, 3, 4…) | **Every TestFlight upload, no exceptions** |

#### Versioning scheme (Baseline)

**Marketing version** — semantic versioning. `MAJOR.MINOR.PATCH`:
- `1.0.0` → `1.0.1` for bug-fix releases (no new features)
- `1.0.0` → `1.1.0` for releases that add features
- `1.0.0` → `2.0.0` for major reworks (UI overhaul, paradigm shift)

**Build number** — simple monotonic integer. Climbs forever, never resets, doesn't depend on marketing version.

#### Worked example

| Upload | Marketing | Build | What happened |
|--------|-----------|-------|---------------|
| 1st | `1.0.0` | 2 | First internal TestFlight |
| 2nd | `1.0.0` | 3 | Same release, fixed a bug found in testing |
| 3rd | `1.0.0` | 4 | Same release, polish pass |
| 4th | `1.0.1` | 5 | First public bug-fix release |
| 5th | `1.1.0` | 6 | Added a new feature |
| 6th | `1.1.0` | 7 | Hotfix to the new feature |

Build number always increments by 1. Marketing version changes only when the release is semver-meaningful.

#### What to edit

```yaml
# project.yml
settings:
  base:
    MARKETING_VERSION: "1.0.0"     # change only on semver-meaningful release
    CURRENT_PROJECT_VERSION: 2     # always +1 from previous upload
```

After editing, regenerate the Xcode project and commit:

```bash
xcodegen
git add project.yml Baseline.xcodeproj
git commit -m "chore(release): bump to <marketing> (<build>) for TestFlight"
# e.g. "chore(release): bump to 1.0.0 (2) for TestFlight"
```

#### Rules and gotchas

- `CURRENT_PROJECT_VERSION` **must increase** every upload. ASC rejects duplicates, even after a build expires.
- Apple lets `CURRENT_PROJECT_VERSION` reset when marketing version changes — **don't.** Keeping it monotonic across the app's lifetime avoids surprise collisions.
- Multiple TestFlight builds can share one marketing version. Common pattern: keep marketing at `1.0.0` through a series of TestFlight builds, only bump to `1.0.1` / `1.1.0` when you go to a public App Store release or a tester-visible feature jump.
- Don't change marketing version for trivial fixes during a TestFlight cycle — testers will see the version flip back and forth, which is confusing.

### Step 3 — Archive

In Xcode:
1. Top toolbar device selector → **Any iOS Device (arm64)**. Cannot archive against a simulator.
2. **Product → Archive**. Takes 1–3 min.
3. Organizer window opens automatically when done. If not: **Window → Organizer → Archives**.

If archive fails:
- "No signing certificate" → check Step 4 prereq above.
- ITMS errors → see `axiom-code-signing-diag` skill.

### Step 4 — Upload to App Store Connect

In Organizer:
1. Select the new archive (top of list).
2. Click **Distribute App**.
3. Select **TestFlight & App Store** → Next.
4. Defaults are fine (Upload, Automatic signing, Strip Swift symbols ON, Upload symbols ON) → Next → Next → **Upload**.
5. Wait for "Upload Successful" confirmation (~1–3 min).

### Step 5 — Wait for processing

ASC needs to process the binary before testers see it.
- Typical: 5–15 min.
- ASC → TestFlight → Builds. Status will show **Processing** → **Ready to Submit** → no further action.
- **Internal-only** = no Beta App Review. The build becomes installable as soon as processing finishes.

### Step 6 — Notify testers

If "Automatic distribution" is on (Step 3 of prereqs), testers get an email + TestFlight push automatically once the build is processed.

If you want to send a custom note: ASC → TestFlight → the build → "What to Test" field. Optional for internal builds.

### Step 7 — Tag the release locally

```bash
git tag -a tf-build-<N> -m "TestFlight build <N> — <one-line summary>"
git push origin tf-build-<N>
```

This makes it easy to check out the exact code testers had if they hit a bug.

---

## Quick reference: version fields

ASC display: `1.0.0 (5)` means marketing version `1.0.0`, build number `5`.

See **Step 2** above for the full versioning scheme. TL;DR:
- Marketing version: semver (`1.0.0` → `1.0.1` / `1.1.0` / `2.0.0`), bump only on tester-meaningful releases
- Build number: monotonic integer, always +1 every upload, never resets

---

## Failure modes & fixes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Archive succeeds, upload fails with `ITMS-90035` | Cert/profile mismatch | Run `axiom-code-signing-diag` skill |
| Upload succeeds, build never appears in ASC | Apple processing delay | Wait 30 min. If still missing, check email — ASC usually sends a rejection notice with reason |
| Tester sees old build | Build number not bumped, or auto-distribution off | Verify `CURRENT_PROJECT_VERSION` increased; check Internal Testing group settings |
| Crash on tester device | Symbolicate via Xcode Organizer → Crashes tab. See `axiom-app-store-connect-ref` skill |
| "App Encryption" prompt on upload | First time upload only | Already configured: `ITSAppUsesNonExemptEncryption = false` in Info.plist. Should be remembered |

---

## When this changes

This SOP is for **internal-only** TestFlight. If you ever need external testers (>2 people, friends-of-friends, public link):

- Beta App Review required (~24h, lighter than App Store review).
- Privacy policy URL required.
- Beta App Description required.
- Tester limit jumps from 100 to 10,000 but every external tester counts toward Apple's review.

At that point, reopen issues #39 (privacy policy) and #43 (TestFlight expanded scope) and re-run the audit before submission.

---

## TL;DR cheat sheet

```bash
# 1. Pre-flight
git pull && xcodebuild -project Baseline.xcodeproj -scheme Baseline \
  -destination 'generic/platform=iOS Simulator' build | tail -5

# 2. Edit project.yml: bump CURRENT_PROJECT_VERSION (always +1).
#    Bump MARKETING_VERSION only on semver-meaningful release.
xcodegen && git add project.yml Baseline.xcodeproj && \
  git commit -m "chore(release): bump to <marketing> (<build>) for TestFlight"

# 3. Xcode → Any iOS Device → Product → Archive
# 4. Organizer → Distribute App → TestFlight & App Store → Upload
# 5. Wait 5–15 min for ASC processing
# 6. Testers get email/push automatically (auto-distribution on)

# 7. Tag
git tag -a tf-build-<N> -m "TestFlight build <N>"
git push origin tf-build-<N>
```
