# App Store Review Notes

Notes to include in the "App Review Information" section of App Store Connect when submitting Baseline for review.

---

## How to Review

No account or sign-in is needed. Everything works offline.

1. **Weigh in.** Finish the short onboarding, then tap **Weigh In** on the Now tab. Enter a weight and optionally add a note or a photo from your library. The entry appears on Now and in History (top right).
2. **Trends.** After a few weigh-ins, the Trends tab charts them over 30 days, 90 days or all time.
3. **Scan a body composition printout.** Baseline reads printouts from an InBody 570 body composition analyzer, which you'll find in gyms and clinics. We've attached a sample printout for a fictional person (`sample-inbody-printout.jpg`). To test:
   - Open the attached image on another screen, or print it.
   - In Baseline, open the **Body** tab and tap **+** beside Body Composition. Keep **InBody 570** selected, tap **Continue**, choose **Scan printout**, and point the camera at the sheet.
   - Review the extracted values and save.
   
   The sample reads: weight 172.6 lb, skeletal muscle mass 78.4 lb, body fat 30.2 lb (17.5%), total body water 104.6 lb, BMI 24.8, BMR 1765 kcal. Scanning is optional; every scan field can also be typed in by hand.
4. **Apple Health (optional).** Allowing Health access writes weigh-ins and scan results to Apple Health. Declining doesn't block anything in the app.

---

## Health Data Architecture

Baseline is a personal body weight and body composition tracker. Users manually enter their own weight or scan an InBody body composition sheet.

### Data Storage

- All user health data is stored locally on-device in a SwiftData persistent store
- Cross-device sync uses CloudKit private database (user's own iCloud account)
- **All health-sensitive fields are end-to-end encrypted** using SwiftData's `.allowsCloudEncryption` attribute, which maps to CloudKit's `encryptedValues` API
- Encrypted fields: body weight values, body composition measurements, scan payloads, goal target/start values, user notes
- Structural fields (dates, IDs, measurement types, goal status) are not encrypted as they contain no personally identifiable health information
- Optional weigh-in photos are chosen by the user from their photo library (system picker, no library permission requested). They are stored with the entry on device and in the user's iCloud private database
- Scan images are processed on device with Apple's Vision framework and are not stored or sent anywhere
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
