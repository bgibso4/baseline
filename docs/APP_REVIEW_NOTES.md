# App Store Review Notes

Notes to include in the "App Review Information" section of App Store Connect when submitting Baseline for review.

---

## Health Data Architecture

Baseline is a personal body weight and body composition tracker. Users manually enter their own weight or scan an InBody body composition sheet.

### Data Storage

- All user health data is stored locally on-device in a SwiftData persistent store
- Cross-device sync uses CloudKit private database (user's own iCloud account)
- **All health-sensitive fields are end-to-end encrypted** using SwiftData's `.allowsCloudEncryption` attribute, which maps to CloudKit's `encryptedValues` API
- Encrypted fields: body weight values, body composition measurements, scan payloads, goal target/start values, user notes
- Structural fields (dates, IDs, measurement types, goal status) are not encrypted as they contain no personally identifiable health information
- No health data is stored on any developer-operated server
- No health data is shared with any third party

### HealthKit Integration

- Baseline **writes** to HealthKit only (weight, body fat percentage, BMR, body measurements)
- Baseline does **not** read from HealthKit
- All HealthKit data originates from user manual entry, not from HealthKit queries
- HealthKit data is not used for advertising, marketing, or data mining

### Privacy

- Privacy manifest (`PrivacyInfo.xcprivacy`) declares health data collection for app functionality
- No tracking, no analytics, no third-party SDKs
- Users can export all data via CSV from Settings
- Users can delete all data from Settings
