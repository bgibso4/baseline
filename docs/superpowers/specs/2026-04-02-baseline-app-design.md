# Baseline — Weight & Body Composition Tracker

**Date:** 2026-04-02
**Status:** Design approved, pending implementation planning
**Parent:** Cadre ecosystem (`apex/docs/superpowers/specs/2026-03-22-health-ecosystem-design.md`, `apex/docs/superpowers/specs/2026-03-30-cadre-umbrella-naming-design.md`)

## Overview

**Baseline** is a native iOS app for daily weight tracking and periodic body composition (InBody scan) logging. It is the second app in the Cadre ecosystem, alongside Apex (workout logging). Baseline's role is to establish the foundational body metrics that contextualize everything else — strength gains, training phases, body comp changes.

**Philosophy:** Log and go. The app should feel like a non-event to use. Zero friction, not because the user is impaired, but because logging weight should never require thought.

**This is a design-driven app.** Every screen, interaction, and feature starts with a high-fidelity mockup before any implementation. Mockups are the contract — agree on what it looks like and how it behaves, then build it. Never skip straight to code without a visual reference. The UI/UX is as important as the software — this app needs to look and feel premium enough for the App Store. Design decisions are validated visually, not described in text.

## Problems Solved

1. **Unified ecosystem** — Weight and body comp data lives alongside workout data in the user's own Cloudflare D1 backend, not siloed in a third-party app (Weigh In).
2. **Body comp tracking** — InBody scans have no good home. Baseline gives them one, with OCR-based entry from paper printouts.
3. **Design upgrade** — fresh, premium visual identity that will become the new Cadre design language. Better UX than Weigh In.
4. **Data ownership** — User's data, user's format, exportable, queryable, feeds the future Cadre Dashboard.
5. **Future analytics** — Cross-cutting insights via the Cadre Dashboard (weight vs 1RM trends, body comp vs training phases, recovery correlations).

## Name: Baseline

**Why it fits:**
- Daily weigh-ins literally establish your baseline — the reference point everything else is measured against.
- In the Cadre ecosystem, weight *is* the baseline that contextualizes strength, body comp, and training data.
- Pairs naturally with Apex: Apex is peak performance (training), Baseline is foundational metrics (weight/body comp).
- Short, clear, self-evident meaning. "What does Baseline do?" needs no explanation.
- Works as a brand: "Cadre Baseline."

## Tech Stack

- **Platform:** iOS (native)
- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData (backed by SQLite)
- **Sync:** Custom Swift sync client → Cloudflare D1 API (same endpoints Apex uses); CloudKit for iCloud backup/sync
- **Camera/OCR:** Vision framework or third-party OCR library for InBody printout scanning
- **Health:** HealthKit for writing weight and body comp data to Apple Health
- **Charts:** Swift Charts for all trend visualizations
- **Onboarding:** TipKit for contextual feature discovery
- **Haptics:** UIFeedbackGenerator for tactile feedback on key interactions
- **Minimum target:** iOS 17+ (SwiftData, TipKit, Swift Charts requirement)

### Why Native Swift (Not React Native)

- Baseline is small and focused — the right project to start the Cadre ecosystem's migration toward native iOS.
- Native SwiftUI feels more premium and snappy for an app this simple.
- React Native is overkill for a single-platform, single-purpose app.
- Long-term goal: Apex will eventually migrate to Swift as well. Baseline establishes the Swift patterns, sync client, and design tokens that Apex will reuse.

### Relationship to @cadre/shared

The existing `@cadre/shared` npm package contains TypeScript design tokens, API types, and the SyncEngine class. Baseline cannot consume this directly as a Swift app. Instead:

- **API contract:** Baseline's Swift sync client hits the same D1 API endpoints (`POST /v1/:table`, `GET /v1/:table?since=`). The contract is the HTTP API, not the npm package.
- **Design tokens:** Cadre color, spacing, and typography tokens are translated to Swift constants. These become the seed of a future `CadreKit` Swift package when Apex migrates.
- **Sync engine:** A Swift `SyncEngine` class implementing the same push-based, timestamp-tracked sync model as the TypeScript version.

When Apex migrates to Swift, the shared Swift code (tokens, sync, API types) can be extracted into a Swift package (`CadreKit` or similar).

## App Structure & Navigation

### Navigation: Three Tabs with Raised Center

```
┌─────────────────────────────────┐
│ ⚙️          Today          📋  │  ← gear (settings) / list (history) icons
│                                 │
│         [ Screen Content ]      │
│                                 │
├─────────────────────────────────┤
│  Trends    [ ⚖️ Today ]   Body │  ← 3 tabs, Today is raised/center
└─────────────────────────────────┘
```

- **Today (center, raised)** — the home screen. Landing screen on app open. Shows today's weight, delta, mini trend sparkline, and the "Weigh In" button.
- **Trends (left tab)** — chart view with time range tabs, moving average, body comp overlay, possibly training phase bands.
- **Body (right tab)** — body measurements hub. InBody scans, manual measurements (waist, arms, neck, chest, etc.), key metric trends.
- **Settings** — gear icon, top-left of Today screen. Push navigation.
- **History** — list icon, top-right of Today screen. Push navigation. Full entry list with daily deltas, edit/delete.

### Screen Inventory

| Screen | Access | Purpose |
|--------|--------|---------|
| **Today** | Center tab (default) | Today's weight, delta, mini trend, Weigh In button |
| **Log Weight** | Sheet/modal from Today | Weight entry (input method TBD — stepper, arc, or hybrid, to be resolved in mockups) |
| **Trends** | Left tab | Weight chart with time ranges, moving average, overlays |
| **Body** | Right tab | Measurements hub — InBody scans, manual measurements, metric trends |
| **Log Measurement** | Sheet from Body tab | Quick entry for individual measurements (waist, arms, neck, etc.) |
| **Log Scan** | Push from Body tab | Camera OCR or manual form for InBody scan entry |
| **Scan Detail** | Push from Body tab | Full scan data for a specific date |
| **History** | Top-right icon on Today | Chronological weight entry list with deltas |
| **Settings** | Top-left icon on Today | Units, data export, API config, about |

## Primary Use Case: Daily Weight Logging

**When:** Every morning, part of the routine.
**Goal:** Zero friction. Tap, adjust, save, done.

### Flow

1. Open app → Today screen
2. Tap "Weigh In" → Log Weight sheet appears
3. Defaults to yesterday's weight
4. Adjust (input method to be resolved in high-fidelity mockups — candidates: stepper with step-size toggle, slider arc, or hybrid arc-display + stepper)
5. Tap Save → sheet dismisses, Today screen updates

### Input Method (To Be Resolved in Mockups)

Three candidates explored during brainstorming. Final decision deferred to high-fidelity mockup phase:

- **Stepper (+/−)** — defaults to yesterday's weight, tap to adjust, toggle step size (0.1 / 0.5 / 1.0 lb). Fewest taps for typical changes.
- **Slider arc** — drag a handle along an arc. Range auto-centers around recent weights. Fine-tune with ± 0.1 buttons. Visually striking.
- **Hybrid** — arc as a display-only visual (shows where weight sits in recent range), stepper for actual input. Arc animates as you tap. Visual flair without sacrificing stepper simplicity.

The raised-center tab design is also open to refinement in mockups — the concept is approved but the visual execution (how much larger, what styling) will be explored.

## Secondary Use Case: Body Measurements

The Body tab is a hub for all body measurements — not just InBody scans. Two entry paths:

### Manual Measurements (tape measure)

**When:** Periodically — weekly, biweekly, whenever.
**Goal:** Quick entry of individual measurements.

**Tracked measurements:**
- Waist circumference
- Neck circumference
- Chest circumference
- Right arm / left arm
- Right thigh / left thigh
- Hips
- Any custom measurement the user wants to add

**Flow:**
1. Navigate to Body tab
2. Tap "Log Measurement"
3. Select measurement type (or add custom)
4. Enter value → save
5. Can log multiple measurements in one session

### InBody Scan Logging

**When:** Monthly or less. An event, not a routine.
**Goal:** Capture all data from the paper printout with minimal manual effort.

**Flow:**
1. Navigate to Body tab
2. Tap "Log Scan"
3. **Primary path:** Camera opens → photograph InBody printout → OCR extracts fields → user reviews/corrects → save
4. **Fallback path:** Manual entry form with all fields

**When an InBody scan is saved**, key metrics (body fat %, skeletal muscle mass, body fat mass, etc.) are also written as individual `BodyMeasurement` records with `source: "inbody"`. This means the Body tab's trend charts show a unified view of all metrics regardless of source — tape measure or InBody machine.

**Data captured from InBody:**

All fields from a standard InBody scan printout. Key metrics surfaced prominently in the UI; full data available in scan detail view.

*Key metrics (prominent):* body weight, body fat percentage, skeletal muscle mass, body fat mass.

*Full capture (detail view):* BMI, total body water, lean body mass, basal metabolic rate, InBody score, segmental lean analysis (right arm, left arm, trunk, right leg, left leg), segmental fat analysis, and any other fields present on the printout.

### OCR Approach

InBody printouts have a consistent, standardized layout. The OCR system can be trained/configured to look for specific field positions and labels. Implementation options:

- Apple Vision framework (on-device, no network required)
- Third-party OCR library with template matching

Manual entry is always available as a fallback. OCR results are presented for user review before saving.

## Trends & Charts

### Weight Trend Chart

- **Time ranges:** Week, Month, 90 Days, Year (tab selector, same as Weigh In)
- **Raw data points:** Individual daily weights as dots/line
- **Moving average:** 7-day moving average line to smooth daily fluctuations and show the real trend (to be validated in mockups — user wants to see it visually before committing)
- **Interactive:** Tap/drag to see specific day's weight (like Weigh In's crosshair)

### Overlays (To Be Validated in Mockups)

Two overlay concepts were discussed. Both are appealing but may be too much information on one chart. Mockups will determine what works visually:

1. **Body comp markers** — InBody scan dates shown as markers on the weight chart. Tap to see body fat % or muscle mass at that point. "I gained 3 lbs but my body fat went down."
2. **Training phase bands** — subtle background color bands showing Apex program phases (hypertrophy, strength, deload, realization). Requires reading phase data from D1. Weight going up during hypertrophy tells a different story than during a cut.

Both overlays, the moving average, and the raised tab styling will be explored together in high-fidelity mockups to find the right balance of information density vs. clarity.

## Data Model

### SwiftData Models

```swift
@Model
class WeightEntry {
    var id: UUID
    var weight: Double          // in user's preferred unit (lb or kg)
    var unit: String            // "lb" or "kg"
    var date: Date              // date of entry (unique — one per day, enforced by app logic)
    var notes: String?
    var createdAt: Date
    var updatedAt: Date         // for sync tracking
}

@Model
class InBodyScan {
    var id: UUID
    var date: Date
    var weight: Double
    var unit: String
    var bodyFatPercentage: Double?
    var skeletalMuscleMass: Double?
    var bodyFatMass: Double?
    var bmi: Double?
    var totalBodyWater: Double?
    var leanBodyMass: Double?
    var basalMetabolicRate: Double?
    var inBodyScore: Double?
    // Segmental analysis
    var rightArmLean: Double?
    var leftArmLean: Double?
    var trunkLean: Double?
    var rightLegLean: Double?
    var leftLegLean: Double?
    var rightArmFat: Double?
    var leftArmFat: Double?
    var trunkFat: Double?
    var rightLegFat: Double?
    var leftLegFat: Double?
    // Raw scan data
    var rawOcrText: String?     // preserved for debugging/reprocessing
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}

@Model
class BodyMeasurement {
    var id: UUID
    var date: Date
    var type: String            // "waist", "neck", "right_arm", "left_arm", "chest", "right_thigh", "left_thigh", "hips",
                                // "body_fat_pct", "skeletal_muscle_mass", "lean_body_mass", etc.
                                // Also receives values from InBody scans (source distinguishes origin)
    var value: Double
    var unit: String            // "in", "cm", "%", "lb", "kg"
    var source: String          // "manual" (tape measure), "inbody" (extracted from scan)
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}

@Model
class SyncState {
    var tableName: String
    var lastSyncTimestamp: String
}
```

**Design note on BodyMeasurement (long table):** One row per measurement per date, with a `type` field. This is intentionally a long/EAV table rather than a wide table because:
- New measurement types can be added without schema changes
- Not every measurement is logged every time — a wide table would be mostly nulls
- Easy to query trends for a single metric: filter by `type`, order by `date`
- InBody scans write their key metrics here (with `source: "inbody"`) so all body metrics have a single queryable home for trending and display

### D1 Table Mapping

| SwiftData Model | D1 Table | Status |
|----------------|----------|--------|
| `WeightEntry` | `body_weights` | Already in Worker allowlist |
| `InBodyScan` | `body_comp_scans` | Already in Worker allowlist |
| `BodyMeasurement` | `body_measurements` | Needs to be added to Worker allowlist |

The D1 Worker already accepts `body_weights` and `body_comp_scans`. `body_measurements` needs to be added to the allowlist — a one-line change in `@cadre/shared/api/tables.ts`.

## Sync

### Architecture

```
Baseline (SwiftData/SQLite) → Swift SyncEngine → POST /v1/:table → D1
```

- **Push-only.** Baseline pushes changes to D1. No pull (except future reinstall recovery).
- **Timestamp-based.** Each record has `updatedAt`. SyncEngine tracks last successful sync per table.
- **Background, non-blocking.** Sync on app open and after writes. Fails silently.
- **Offline resilient.** Local SwiftData is always the source of truth.
- **Same API contract as Apex.** `X-API-Key` header, `POST /v1/:table` with JSON body.

### Swift SyncEngine

A Swift class mirroring the TypeScript `SyncEngine` from `@cadre/shared`:

```swift
class SyncEngine {
    let apiUrl: String
    let apiKey: String
    let appId: String   // "baseline"

    func registerTable(_ config: TablePushConfig)
    func syncAll() async
    func syncTable(_ name: String) async
}
```

Each table provides its own query and optional transform, same pattern as Apex.

### iCloud Persistence (CloudKit)

SwiftData has built-in CloudKit integration — adding iCloud sync is a configuration step, not a rewrite. This provides:

- **Device-to-device sync** — user's data syncs across their iPhone and iPad automatically via iCloud
- **Backup** — data survives device loss/replacement without needing the D1 backend
- **App Store readiness** — public users get persistence without needing a Cadre API key

**V1 (personal use):** iCloud is enabled as a persistence/backup layer alongside D1 sync. Both run independently — SwiftData syncs to iCloud automatically, the SyncEngine pushes to D1 on its own schedule.

**Future (App Store / multi-user):** iCloud becomes the *primary* persistence layer for public users. D1 sync is only active for the developer (Cadre ecosystem user) or disabled entirely for public users. This means:
- Public App Store users get iCloud sync out of the box — no account creation, no API keys, no backend to maintain at scale
- The D1 backend remains a personal/Cadre-ecosystem feature, not a public service
- No multi-user backend infrastructure needed — each user's data lives in their own iCloud container

### Multi-User Considerations (App Store Future)

If Baseline goes to the App Store, the architecture naturally supports multiple users without a shared backend:

- **iCloud handles it.** Each user's data lives in their private CloudKit container. No shared database, no user accounts, no auth system to build.
- **No D1 for public users.** The Cloudflare D1 sync is a Cadre-ecosystem feature for the developer's personal cross-app analytics. Public users don't need it and won't have it.
- **No server costs at scale.** Apple handles iCloud storage and sync infrastructure. The app is fully client-side for public users.
- **Privacy by design.** No user data ever touches a server you control (for public users). Strong App Store privacy story.

The only scenario requiring a shared backend is if social features (sharing progress, challenges, leaderboards) are ever added — but that's explicitly a non-goal.

## HealthKit Integration

Baseline writes health data to Apple Health so other apps (WHOOP, Garmin, MyFitnessPal, etc.) can read it. This makes Baseline a good citizen in the iOS health ecosystem.

**Data written to HealthKit:**

| Baseline Data | HealthKit Type | When |
|--------------|----------------|------|
| Weight entry | `HKQuantityType.bodyMass` | On every weight save |
| Body fat % | `HKQuantityType.bodyFatPercentage` | On InBody scan save |
| Lean body mass | `HKQuantityType.leanBodyMass` | On InBody scan save |
| BMI | `HKQuantityType.bodyMassIndex` | On InBody scan save |
| Waist circumference | `HKQuantityType.waistCircumference` | On manual measurement save |

**Implementation:**
- Request HealthKit write permission on first relevant save (not on app launch — only when the user actually logs something)
- Write is fire-and-forget — if the user declines HealthKit permission, Baseline works identically without it
- Read permission is not requested in v1 — Baseline is an input device, not a HealthKit aggregator

## Design System

**Baseline establishes the new Cadre design language.** The current Cadre tokens (from Apex's React Native theme) will be redesigned — Baseline is the greenfield canvas for the new aesthetic. When Apex eventually migrates to Swift, it adopts Baseline's design language rather than the other way around.

**Approach:**
- Design Baseline's visual identity from scratch using iOS design skills and plugins, not porting Apex's existing tokens
- The result becomes the new Cadre design system — a Swift-native token set
- Dark theme is still the direction (premium, gym-appropriate), but colors, typography, spacing, and component patterns are all open for redesign
- Design tokens are defined as Swift constants and will be extracted into a shared `CadreKit` Swift package when Apex migrates

**Design token structure (values TBD during mockup phase):**

```swift
enum CadreColors {
    // Values to be established during high-fidelity mockup design
    static let bg = Color(...)
    static let card = Color(...)
    static let text = Color(...)
    static let accent = Color(...)
    // ...
}

enum CadreSpacing {
    static let xs: CGFloat = ...
    static let sm: CGFloat = ...
    static let md: CGFloat = ...
    static let lg: CGFloat = ...
    // ...
}

enum CadreTypography {
    // Font choices, sizes, weights — TBD during design
}
```

## Settings

- **Units:** lb / kg toggle (default: lb)
- **Data export:** CSV export of all weight entries and InBody scans
- **Sync:** API URL and key configuration (or environment-based for App Store builds)
- **About:** App version, Cadre ecosystem info

## Apple Ecosystem Features

### V1

| Feature | Framework | Purpose |
|---------|-----------|---------|
| **Widgets** | WidgetKit | Home screen + lock screen widgets showing today's weight and trend |
| **Swift Charts** | Charts | All trend visualizations — weight, body comp, measurements |
| **Haptics** | UIFeedbackGenerator | Tactile feedback on stepper taps, save, scan complete |
| **TipKit** | TipKit | Contextual onboarding tips for feature discovery |
| **HealthKit** | HealthKit | Write weight and body comp to Apple Health |
| **Accessibility** | SwiftUI semantics | VoiceOver, Dynamic Type, proper contrast ratios |

### V1.5

| Feature | Framework | Purpose |
|---------|-----------|---------|
| **Apple Watch** | WatchKit / SwiftUI | Quick weight entry from wrist, complication showing today's weight |
| **Siri Shortcuts** | App Intents | "Hey Siri, log 197 pounds" — voice-driven weight entry |
| **iPad support** | SwiftUI (adaptive) | Larger charts, side-by-side views — mostly free with SwiftUI |

## Future Considerations (Not V1)

- **App Store distribution** — proper signing (paid Apple Developer account), App Store assets (icon, screenshots, description), privacy policy. Influences early decisions like project structure and secrets management, but not a v1 blocker.
- **CSV import from Weigh In** — over a year of daily weight history exists in Weigh In and should be migrated. Weigh In supports export. Plan for an import feature but not a v1 blocker.
- **Reinstall recovery** — pull own data back from D1 as a one-time restore after reinstall.
- **Goal tracking** — target weight with projected trend line ("at this rate, you'll hit 185 by June").
- **Rate of change** — weekly/monthly rate display ("averaging +0.3 lb/week").
- **CadreKit Swift package** — when Apex migrates to Swift, extract shared tokens, sync engine, and API types into a shared Swift package.
- **Notifications** — not wanted currently. User remembers on their own.
- **StoreKit** — premium tier if needed (ad-free, advanced analytics, export). Keep the door open architecturally.

## Non-Goals

- **Not cross-platform.** iOS only.
- **No social features.** No sharing, challenges, or leaderboards. Single-user focus.
- **No shared multi-user backend.** Public users use iCloud. No server infrastructure to scale.
- **No dashboard.** That's a separate Cadre project.
- **No real-time sync.** Push on open and after writes.
- **No HealthKit reads.** Baseline writes to Apple Health but does not read from it. It's an input device.
- **No pre-built UI components in @cadre/shared.** Components are promoted from apps when real duplication exists.
