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

### Step 2 — Bump build number

Edit `project.yml`:

```yaml
settings:
  base:
    MARKETING_VERSION: "1.0.0"     # ← bump only on user-visible feature/bug release
    CURRENT_PROJECT_VERSION: 2     # ← ALWAYS bump this for every TestFlight upload
```

Rules:
- `CURRENT_PROJECT_VERSION` (build number) **must increase** every upload. ASC rejects duplicates.
- `MARKETING_VERSION` (e.g. `1.0.0`) only changes for releases tester-meaningful enough to talk about. Multiple TestFlight builds can share one marketing version.

After editing, regenerate the Xcode project:
```bash
xcodegen
```

Commit the bump:
```bash
git add project.yml Baseline.xcodeproj
git commit -m "chore(release): bump build to <N> for TestFlight"
```

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

## Quick reference: what each version field means

| Field | Plist key | Purpose | When to bump |
|-------|-----------|---------|--------------|
| Marketing version | `CFBundleShortVersionString` | What testers see (e.g. "1.0.0") | When the release is a meaningful step forward |
| Build number | `CFBundleVersion` | What ASC uses to disambiguate uploads | **Every** TestFlight upload, no exceptions |

ASC display: `1.0.0 (5)` means marketing version 1.0.0, build 5.

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

# 2. Bump CURRENT_PROJECT_VERSION in project.yml, regenerate, commit
xcodegen && git add project.yml Baseline.xcodeproj && \
  git commit -m "chore(release): bump build to <N>"

# 3. Xcode → Any iOS Device → Product → Archive
# 4. Organizer → Distribute App → TestFlight & App Store → Upload
# 5. Wait 5–15 min for ASC processing
# 6. Testers get email/push automatically (auto-distribution on)

# 7. Tag
git tag -a tf-build-<N> -m "TestFlight build <N>"
git push origin tf-build-<N>
```
