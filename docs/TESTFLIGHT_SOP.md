# TestFlight Release SOP

Standard procedure for cutting a new TestFlight build of Baseline. First run takes ~30 min for one-time ASC setup; subsequent builds upload automatically on merge to `main`, plus 5–15 min of Apple processing time.

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
- If anything fails: see `axiom-code-signing-diag` skill or run `security find-identity -v -p codesigning` to confirm a valid Apple Distribution cert exists.

---

## Standard release flow (every build)

Uploads are automatic. Every merge to `main` that passes CI is archived and uploaded to TestFlight by the **TestFlight** workflow (`.github/workflows/testflight.yml`), unless only `docs/` and Markdown changed since the last upload. With automatic distribution on, the internal group gets it once Apple finishes processing (5–15 min).

- **Upload again by hand:** GitHub → Actions → TestFlight → **Run workflow** on `main` (only once CI has passed for main's head).
- **Release to the App Store:** still manual. App Store Connect → the version → pick the TestFlight build → submit for review.

### How the workflow builds

1. Installs the Apple Development certificate from a secret into a keychain of its own. Baseline's entitlements (HealthKit, CloudKit, the App Group) can't be archived without one.
2. Archives (`make testflight-archive` → `scripts/testflight/archive.sh`), fetching the development profile with the API key.
3. Fails before uploading unless the archive carries every entitlement in `Baseline/Baseline.entitlements` (`scripts/testflight/check-entitlements.sh`). A build without them would lose HealthKit and iCloud sync.
4. Exports with the team's cloud-managed distribution certificate and uploads.
5. Fails if the run created a development certificate (Apple caps them), and deletes the key and the keychain.

### Secrets (one-time, repo Settings → Secrets and variables → Actions)

| Secret | What |
|--------|------|
| `ASC_KEY_ID`, `ASC_ISSUER_ID` | App Store Connect → Users and Access → Integrations → the key's ID and the issuer ID |
| `ASC_KEY_P8` | The key's `.p8` file contents. The key must have the **Admin** role (cloud signing needs it). The filing-cabinet key works: keys are per team. |
| `BUILD_CERTIFICATE_P12` | An Apple Development certificate with its private key: Keychain Access → My Certificates → "Apple Development: …" → Export as `.p12` with a password, then `base64 -i cert.p12 \| pbcopy` |
| `BUILD_CERTIFICATE_PASSWORD` | That `.p12`'s password |

When the development certificate expires (yearly), export the new one and replace `BUILD_CERTIFICATE_P12` and its password.

### Version numbers

iOS apps have two version fields. Don't conflate them.

| Field | Plist key | Purpose | Who sets it |
|-------|-----------|---------|-------------|
| `MARKETING_VERSION` | `CFBundleShortVersionString` | User-facing version (`1.0.0`, `1.1.0`, `2.0.0`) | You, in `project.yml`, on a semver-meaningful release |
| `CURRENT_PROJECT_VERSION` | `CFBundleVersion` | ASC build disambiguator (monotonic integer) | The workflow: its run number + 3 (builds 1–3 were uploaded by hand). `project.yml`'s value only applies to local builds. |

**Marketing version** — semantic versioning, `MAJOR.MINOR.PATCH`:
- `1.0.0` → `1.0.1` for bug-fix releases (no new features)
- `1.0.0` → `1.1.0` for releases that add features
- `1.0.0` → `2.0.0` for major reworks

To bump it: edit `MARKETING_VERSION` in `project.yml`, `make generate`, and merge it like any change. ASC display `1.0.0 (5)` means marketing version `1.0.0`, build `5`.

- A re-run of a TestFlight run keeps its build number, so re-run only a run that failed **before** its upload. Otherwise use **Run workflow** for a fresh number.
- ASC rejects a build number it has seen, even an expired one.

### Fallback: upload from Xcode

Only if the workflow can't run. The build number must be higher than every build in ASC: set `CURRENT_PROJECT_VERSION` to the highest + 1 for the archive (don't commit it). A later workflow run that lands on the same number fails at upload; start it again with **Run workflow**.

1. Xcode → device selector **Any iOS Device (arm64)** → **Product → Archive**.
2. Organizer → the new archive → **Distribute App** → **TestFlight & App Store** → defaults → **Upload**.

---

## Moving an existing install to the release build

One-off procedure for the first time a phone that already holds real data moves onto a build with the versioned SwiftData schema (`BaselineSchemaV1`, issue #78). Follow it in order. Do not skip the rehearsal.

### What your phone has been through

Your phone has run TestFlight builds, then Xcode builds, on the same local store:

| Stage | Build | CloudKit environment |
|-------|-------|----------------------|
| 1 | TestFlight builds | Production |
| 2 | Xcode build | Development |
| 3 | Release build (this move) | Production again |

Production very likely holds the records you created during the TestFlight period. The release build sends the phone back to Production. Nobody has tested what mirroring does with that store and those records: it may match them up, re-upload the newer ones, or import the Production copies as duplicates (records have no unique constraint).

### Procedure

1. **Back up, on the day of the move.**
   - In Settings, export fresh CSVs from the current build and save them off the phone. Open the weights file and check the row count and the oldest date.
   - Make an encrypted Finder backup: Finder → your iPhone → **Back up all of the data on your iPhone to this Mac**, tick **Encrypt local backup**, **Back Up Now**. Save the password.
   - The encrypted backup is the only full copy of the real store (goals, every scan field, photos). Restoring it rolls back the whole phone, so it is a last resort.
2. **Record Production, then deploy the schema.** Merge the versioned-schema change (issue #78). In the CloudKit Console, open **Production** and note the schema and the record count per type. Then deploy the CloudKit schema to Production. Before you confirm, read the diff in the Deploy dialog. #78 adds nothing to the CloudKit schema, so the diff should be empty or list only types and fields you expect. If anything unexpected appears, stop. A Production deploy is permanent: types and fields can't be removed.
3. **Rehearse on your wife's phone**, repeating your phone's path:
   1. Export her CSVs first (her phone may hold her own Baseline data).
   2. Install a TestFlight build from before #78 and log some entries. Use the oldest one still available in TestFlight, since it's closest to what your phone ran, and write down which build it is. TestFlight builds expire after 90 days. If none from before #78 is left, archive and upload a build of `f66afa8` and use that.
   3. Install an Xcode build of `f66afa8` over it and log more entries.
   4. Install the TestFlight build of this work over that.
   - The Xcode install needs Developer Mode on her phone: connect it to Xcode, then Settings → Privacy & Security → Developer Mode, and restart.
   - Simulators can't install TestFlight builds, so this must be a physical device.
   - Never sign your real phone into a different iCloud account to test. An account change can purge or reassign the local store.
4. **Check the stop conditions** after the rehearsal: any lost record, any duplicate record, the app crashing on launch. If any happen, your phone does not move until the cause is fixed in a separate change. The fixture tests can't simulate a store that has synced through CloudKit, so the rehearsal is the only proof for that.
5. **Install the TestFlight build over the Xcode build on your phone.** It shares the bundle ID, so the local store stays.
6. **Verify.** Check the weight count and history against the CSV. Then check the CloudKit Console (Production) for what reached it. The record count per type must be no lower than the counts you wrote down in step 2. If any is lower, stop.

### If older records don't reach Production

Launch anyway. The phone's store is the source of truth, and fixing sync is separate work after launch. Leave the data untouched: do not run an import, a delete-and-reimport, or a dedupe tool on the phone to force it. CSV import can't do it safely:

- Skip mode (the default) matches by day and uploads nothing.
- Overwrite mode deletes and recreates each record and rewrites the matching Apple Health entries.
- Reinstalling loses goals and the scan fields the CSV leaves out.

Until sync is fixed, keep a current CSV export, and don't delete the app or move to a new phone.

### Way back if the new build crashes on launch

Reinstall `f66afa8` from Xcode over it. That keeps the store. Do not delete the app. This is why `f66afa8` must stay buildable.

Reinstalling fixes a crash on launch. It does not undo duplicates CloudKit has already imported. If duplicates appear, stop, and don't run any import or cleanup tools.

---

## Failure modes & fixes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Archive succeeds, upload fails with `ITMS-90035` | Cert/profile mismatch | Run `axiom-code-signing-diag` skill |
| Workflow fails at "Install the development certificate" or archive says no signing certificate | `BUILD_CERTIFICATE_P12` missing, wrong password, or the certificate expired | Export a current Apple Development certificate as `.p12` and replace both secrets |
| Workflow fails with "missing entitlements" | The archive wasn't signed with the certificate, or an entitlement was added without a device build to register it | Do one automatic-signing device build from Xcode, then Run workflow |
| Workflow fails at "Check no certificate was created" | Xcode made a new development certificate | Revoke the extra one in Certificates, Identifiers & Profiles; check `BUILD_CERTIFICATE_P12` is current |
| Upload succeeds, build never appears in ASC | Apple processing delay | Wait 30 min. If still missing, check email — ASC usually sends a rejection notice with reason |
| Tester sees old build | The upload was skipped (docs-only) or failed, or auto-distribution off | Check the TestFlight workflow run; check Internal Testing group settings |
| Crash on tester device | Symbolicate via Xcode Organizer → Crashes tab. See `axiom-app-store-connect-ref` skill |
| "App Encryption" prompt on upload | First time upload only | Already configured: `ITSAppUsesNonExemptEncryption = false` in Info.plist. Should be remembered |
| Crash on launch after installing a schema-versioned build | Store doesn't match `BaselineSchemaV1` | Reinstall `f66afa8` from Xcode; don't delete the app |

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

- Merge to `main` → CI passes → TestFlight workflow uploads → installable in 5–15 min.
- Upload again: Actions → TestFlight → Run workflow (on `main`).
- New user-facing version: bump `MARKETING_VERSION` in `project.yml`, `make generate`, merge.
- App Store release: App Store Connect → pick the build → submit for review.
