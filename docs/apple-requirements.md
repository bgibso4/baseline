# Apple Requirements Checklist

Pre-submission audit of entitlements, capabilities, and platform requirements for Baseline v1.0.

- **Bundle ID (app):** `com.cadre.baseline`
- **Team:** `W6S6K84XVM`
- **Min iOS:** 27.0
- **Version / build:** 1.0.0 / set by CI (GitHub run number + 3; first upload was build 5)

Legend: ✅ done · ⚠️ verify · ❌ missing

---

## Entitlements

### Main app (`Baseline/Baseline.entitlements`)

| Key | Status | Notes |
|-----|--------|-------|
| `com.apple.developer.healthkit` | ✅ | Enabled |
| `com.apple.developer.healthkit.access` | ✅ | Empty array — standard HealthKit only, no clinical records |
| `com.apple.developer.icloud-services` → `CloudKit` | ✅ | CloudKit only. The unused CloudDocuments entry was removed in PR #105. |
| `com.apple.developer.icloud-container-identifiers` | ✅ | `iCloud.com.cadre.baseline` |
| `com.apple.security.application-groups` | ✅ | `group.com.cadre.baseline` — the SwiftData store lives here, so existing installs depend on it. Keep it even though no extension shares it in v1.0. |
| `aps-environment` | n/a | Not required — CloudKit silent push via `NSPersistentCloudKitContainer` does not use APNs |

---

## Capabilities

| Capability | Status | Notes |
|------------|--------|-------|
| HealthKit | ✅ | Entitlement + usage strings present |
| iCloud (CloudKit) | ✅ | Container identifier configured. |
| App Groups | ✅ | Holds the SwiftData store (see entitlements note above) |
| Background Modes → Remote notifications | ✅ | In `Baseline/Info.plist` — enables CloudKit silent push wake-ups |
| Push Notifications | n/a | User-facing push not used in v1.0 |
| Keychain Sharing | n/a | No cross-app credential sharing needed |

---

## Info.plist usage descriptions

| Key | Status | Notes |
|-----|--------|-------|
| `NSCameraUsageDescription` | ✅ | "Baseline uses the camera to scan InBody printouts..." |
| `NSHealthShareUsageDescription` | ✅ | Required even though the app reads nothing (`read: []`): App Store Connect rejects any upload with the HealthKit entitlement that lacks it (TestFlight build 4 failed on this). Restored in PR #107; it says Baseline doesn't read Health data. |
| `NSHealthUpdateUsageDescription` | ✅ | Matches stated write-only behaviour |
| `NSPhotoLibraryUsageDescription` | n/a | No photo library access (scanner uses camera only) |
| `NSUserTrackingUsageDescription` | n/a | No tracking — confirmed in privacy manifest |

---

## Export compliance

| Item | Status | Notes |
|------|--------|-------|
| `ITSAppUsesNonExemptEncryption` in Info.plist | ✅ | Set to `false` |
| Exemption rationale | ✅ | App uses only iOS-provided encryption (HTTPS via URLSession, CloudKit `encryptedValues`, SwiftData encrypted attributes). All falls under Apple's standard exemption — no `encryption_updates@apple.com` filing required. |

---

## Privacy manifest (`Baseline/PrivacyInfo.xcprivacy`)

| Field | Status | Notes |
|-------|--------|-------|
| `NSPrivacyTracking` = false | ✅ | |
| `NSPrivacyTrackingDomains` = [] | ✅ | |
| `NSPrivacyCollectedDataTypes` = [] | ✅ | Data Not Collected (decided 2026-11-19, #41). Under Apple's definition, data is collected only when it leaves the device in a way the developer or a third party can access. Baseline keeps everything on device and in the user's own iCloud private database, which we can't read, and there is no server. Must stay in step with the App Store privacy label. |
| `NSPrivacyAccessedAPITypes` → UserDefaults (CA92.1) | ✅ | Audited 2026-11-19 (#41): UserDefaults is the only Required Reason API in use, standard suite only (no app-group suite), so CA92.1 is correct. No file timestamp, disk space, system boot time or keyboard APIs. Re-check when adding dependencies or file APIs. |
| Third-party SDKs | ✅ | None — no vendor privacy manifests to merge |

---

## App Store Connect metadata (not in code)

Fill in App Store Connect during submission. Listed here so nothing is forgotten.

| Item | Planned value / decision |
|------|--------------------------|
| Age rating | 4+ (no objectionable content). Confirm via ASC questionnaire — health & fitness data does not require a higher rating. |
| Category (primary) | Health & Fitness |
| Category (secondary) | Lifestyle (tentative) |
| Content rights | Does the app use third-party content? **No.** |
| App privacy section | **Data Not Collected**, matching the privacy manifest. |
| Data retention | Local device + user's iCloud private database. No developer-operated servers. |
| App Review notes | Reuse `docs/APP_REVIEW_NOTES.md`, and attach `docs/app-review/sample-inbody-printout.jpg` so the reviewer can test scanning |
| Demo account | n/a — no sign-in |
| Export compliance (in ASC) | Uses standard encryption, exempt. |
| Privacy policy URL | `https://bgibso4.github.io/baseline/privacy/` — source in `gh-pages` branch. |
| Terms of Service URL | `https://bgibso4.github.io/baseline/terms/` — source in `gh-pages` branch. Not required by Apple but used for the in-app "Not medical advice" disclaimer. |
| Privacy contact email | `gibby.b12@gmail.com` |

---

## Legal pages

Privacy Policy and Terms of Service are hosted on GitHub Pages from the `gh-pages` branch of this repo. Live URLs:

- https://bgibso4.github.io/baseline/privacy/
- https://bgibso4.github.io/baseline/terms/

Both are linked from the app's Settings → About section (see `SettingsView.swift`). To edit, switch to the `gh-pages` branch, modify `privacy.md` or `terms.md`, bump the "Last updated" date at the top, and push. GitHub Pages rebuilds automatically within ~1 minute.

---

## Launch / bundle hygiene

| Item | Status | Notes |
|------|--------|-------|
| `CFBundleShortVersionString` / `CFBundleVersion` | ✅ | 1.0.0 / set by the TestFlight workflow on every merge to `main` |
| `UILaunchScreen` | ✅ | Empty dict — uses default (system-generated from app icon) |
| `UISupportedInterfaceOrientations` | ✅ | Portrait + landscape left/right (landscape gated by `BaselineAppDelegate.allowLandscape` for Trends fullscreen only) |
| App icon (`Assets.xcassets/AppIcon`) | ✅ | EKG icon is the v1.0 icon. A redesign is possible later and only needs a new build. |

---

## Open questions / follow-ups

1. **Mac and Vision Pro availability:** turn off "Make this app available" for Apple silicon Macs and Apple Vision Pro in App Store Connect. HealthKit writes and the camera scan flow don't fit those devices.
2. **EU trader status:** declare non-trader while the app is free with no in-app purchases.
3. **Submission-day questionnaires:** the updated age rating questionnaire and the Accessibility Nutrition Labels.

---

Last audited: 2026-11-19 (issue #41: placeholder copy removed, Data Not Collected, review sample printout, doc brought up to date with PRs #105 and #107).
