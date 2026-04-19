# Apple Requirements Checklist

Pre-submission audit of entitlements, capabilities, and platform requirements for Baseline v1.0.

- **Bundle ID (app):** `com.cadre.baseline`
- **Bundle ID (widget):** `com.cadre.baseline.widgets`
- **Team:** `W6S6K84XVM`
- **Min iOS:** 26.0
- **Version / build:** 1.0.0 / 1

Legend: ✅ done · ⚠️ verify · ❌ missing

---

## Entitlements

### Main app (`Baseline/Baseline.entitlements`)

| Key | Status | Notes |
|-----|--------|-------|
| `com.apple.developer.healthkit` | ✅ | Enabled |
| `com.apple.developer.healthkit.access` | ✅ | Empty array — standard HealthKit only, no clinical records |
| `com.apple.developer.icloud-services` → `CloudKit` | ✅ | CloudDocuments removed 2026-04-19 — unused (no UIDocument/iCloud Drive path; photos sync via CloudKit external storage, CSV export uses system share sheet) |
| `com.apple.developer.icloud-container-identifiers` | ✅ | `iCloud.com.cadre.baseline` |
| `com.apple.security.application-groups` | ✅ | `group.com.cadre.baseline` (shared with widget) |
| `aps-environment` | n/a | Not required — CloudKit silent push via `NSPersistentCloudKitContainer` does not use APNs |

### Widget (`BaselineWidgets/BaselineWidgets.entitlements`)

| Key | Status | Notes |
|-----|--------|-------|
| `com.apple.security.application-groups` | ✅ | Reads shared store from App Group — intentionally no iCloud entitlement |

---

## Capabilities

| Capability | Status | Notes |
|------------|--------|-------|
| HealthKit | ✅ | Entitlement + usage strings present |
| iCloud (CloudKit + CloudDocuments) | ✅ | Container identifier configured |
| App Groups | ✅ | Shared between app and widget |
| Background Modes → Remote notifications | ✅ | In `Baseline/Info.plist` — enables CloudKit silent push wake-ups |
| Push Notifications | n/a | User-facing push not used in v1.0 |
| Keychain Sharing | n/a | No cross-app credential sharing needed |

---

## Info.plist usage descriptions

| Key | Status | Notes |
|-----|--------|-------|
| `NSCameraUsageDescription` | ✅ | "Baseline uses the camera to scan InBody printouts..." |
| `NSHealthShareUsageDescription` | ✅ | Removed 2026-04-19 — `HealthKitManager` calls `requestAuthorization(toShare:, read: [])`, so read permission was never requested and the string was unused |
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
| `NSPrivacyCollectedDataTypes` → HealthAndFitness, linked, non-tracking, app-functionality | ✅ | Matches health data usage |
| `NSPrivacyAccessedAPITypes` → UserDefaults (CA92.1) | ⚠️ | Verify reason code is current and sufficient. Add additional Required Reason APIs if any of the following are called: `stat`, `timestamp`, `fileModificationDate`, disk space APIs, `systemUptime`, keyboard user dictionary, active keyboards. Run Xcode's privacy report to confirm. |
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
| App privacy section | Mirrors the privacy manifest: Health & Fitness data collected, linked to user, not used for tracking, used for app functionality only. |
| Data retention | Local device + user's iCloud private database. No developer-operated servers. |
| App Review notes | Reuse `docs/APP_REVIEW_NOTES.md` |
| Demo account | n/a — no sign-in |
| Export compliance (in ASC) | Uses standard encryption, exempt. |

---

## Launch / bundle hygiene

| Item | Status | Notes |
|------|--------|-------|
| `CFBundleShortVersionString` / `CFBundleVersion` | ✅ | 1.0 / 1 (bump before each TestFlight build) |
| `UILaunchScreen` | ✅ | Empty dict — uses default (system-generated from app icon) |
| `UISupportedInterfaceOrientations` | ✅ | Portrait + landscape left/right (landscape gated by `BaselineAppDelegate.allowLandscape` for Trends fullscreen only) |
| App icon (`Assets.xcassets/AppIcon`) | ⚠️ | Currently under revision — final icon must land before first TestFlight submission |

---

## Open questions / follow-ups

1. **Required Reason API audit** — walk through Apple's list once before submission and add any new entries to `PrivacyInfo.xcprivacy`.
2. **Final app icon** — blocker for TestFlight.

---

Last audited: 2026-04-19 (issue #19).
