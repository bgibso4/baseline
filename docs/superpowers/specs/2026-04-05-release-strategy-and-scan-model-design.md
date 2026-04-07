# Baseline — Release Strategy & Scan Data Model (Amendment)

**Date:** 2026-04-05
**Status:** Design approved, pending implementation planning
**Parent:** `docs/superpowers/specs/2026-04-02-baseline-app-design.md`

## Purpose

Amends the Baseline design doc with two decisions that were deferred from the original spec:

1. **Dual release strategy** — how a public App Store build and an internal Cadre build coexist from one codebase.
2. **Body composition data model** — how scans (InBody today; DEXA, lab panels, etc. later) are modeled so that new scan types can be added without schema migrations.

Neither decision changes any existing user-facing feature; both establish architectural boundaries that affect sync, storage, and future extensibility.

---

## 1. Release Strategy

### Goal

Ship a public version of Baseline to the App Store that uses iCloud/CloudKit sync only (no custom backend, no accounts), while keeping a fully-featured Cadre build — with Cloudflare D1 sync — in private internal distribution. One codebase, two App Store Connect records, two TestFlight lanes.

### Two Builds, One Codebase

| | Public Build | Cadre Build |
|---|---|---|
| Bundle ID | `com.<org>.baseline` | `com.<org>.baseline.cadre` |
| iCloud/CloudKit sync | ✅ always on | ✅ always on |
| Cloudflare D1 outbound mirror | ❌ disabled (no-op) | ✅ enabled |
| Distribution | App Store + TestFlight (external testers) | TestFlight (internal testers only) |
| Audience | Public users | Ben + Cadre circle |

Each bundle ID gets its own CloudKit container, so the two apps can live on the same device simultaneously with zero data cross-contamination. Two icons, two independent iCloud stores.

### Xcode Configuration

- **One Xcode project, two schemes:** `Baseline` (public) and `Baseline-Cadre` (internal).
- **Build configurations** carry: bundle identifier, CloudKit container ID, display name, and a `CADRE_BUILD` compile flag.
- **No `#if CADRE_BUILD` blocks** scattered through app code. The flag's only job is to choose which `OutboundMirror` implementation gets injected at app startup (see below).

### Sync Architecture

CloudKit is always the primary sync — hard-wired, no abstraction. It is the source of truth for cross-device syncing and backup on both builds.

The Cloudflare D1 sync is modeled as an **additive outbound mirror**, not a replacement for CloudKit. It never blocks a user action and is never on the critical path for correctness.

```
┌─────────────────────────────────────┐
│       SwiftData (local truth)       │
└──────────┬──────────────────────────┘
           │
    ┌──────┴──────┐
    ▼             ▼
┌────────┐   ┌─────────────────┐
│CloudKit│   │ OutboundMirror  │  ← protocol
│(always)│   │                 │
└────────┘   │ ┌─────────────┐ │
             │ │ NoOp (pub)  │ │
             │ │ Cloudflare  │ │  ← build-flag picks one
             │ │   (Cadre)   │ │
             │ └─────────────┘ │
             └─────────────────┘
```

**`OutboundMirror` protocol:** defines a minimal surface — something like `func mirror(_ record: MirrorableRecord) async`, plus a catch-up `func reconcile() async` for backfilling anything missed while offline. Exact shape TBD in implementation plan.

**Two implementations:**
- `NoOpOutboundMirror` — does nothing. Injected in the public build.
- `CloudflareOutboundMirror` — pushes records to the Cloudflare D1 API (same endpoints Apex uses). Injected in the Cadre build. Fire-and-forget: failures are logged and retried, never surfaced as errors blocking the user.

The rest of the app talks only to the protocol. App logic is identical in both builds.

### Why This Shape

- **iCloud sync no matter what** — both builds get it. Satisfies the "public users should get real multi-device sync" requirement without introducing accounts.
- **Public binary carries zero Cloudflare code** — `CloudflareOutboundMirror` is excluded from the public target entirely (not just disabled at runtime). No secret API endpoints leaking into App Store binaries.
- **CloudKit is always the safety net** — if the Cloudflare mirror fails in the Cadre build, nothing is lost; CloudKit already has it.
- **Clean C → B migration path** — if Cadre later grows into a public ecosystem with user accounts, the `OutboundMirror` protocol already exists. A new `CadreAccountMirror` implementation could be added and gated by sign-in, without touching app logic.

### Distribution Logistics

- **Public build** → App Store submission + External TestFlight (up to 10,000 beta testers via public link). First TestFlight build of each version requires Beta App Review (~24h).
- **Cadre build** → Internal TestFlight only (up to 100 Apple IDs on the team). Builds available immediately after processing, no Beta App Review.
- **Build expiry:** TestFlight builds expire after 90 days. Cadre build needs re-upload every ~3 months — acceptable overhead.

---

## 2. Body Composition Data Model

### Goal

Support InBody scans today, and DEXA / BodPod / lab panels later, without schema migrations or rewrites. Keep metric display and trend charts simple.

### Three Distinct Entities

The Body tab and Trends screens are backed by three separate SwiftData models. They are not unified — each has a different shape and lifecycle.

| Entity | Shape | Example |
|---|---|---|
| `WeightEntry` | Daily scalar | `{ date, weightKg, source }` |
| `Measurement` | Tape-measure value per body part | `{ date, type: .waist, valueCm }` |
| `Scan` | Structured multi-field body-comp report | `{ date, type: .inBody, payload: <encoded> }` |

Rationale: these three concepts look superficially similar ("numbers about your body over time") but differ enough in entry flow, shape, and cardinality that a unified model would be more awkward than helpful.

### `WeightEntry`

Unchanged from the parent spec. One row per weigh-in, the primary tracked metric.

### `Measurement`

Single-scalar, type-discriminated:

```swift
@Model final class Measurement {
    var id: UUID
    var date: Date
    var type: MeasurementType   // enum
    var valueCm: Double
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}

enum MeasurementType: String, Codable, CaseIterable {
    case waist, hips, chest, neck
    case armLeft, armRight
    case thighLeft, thighRight
    case calfLeft, calfRight
    // add cases as needed — no migration required
}
```

Extensible by adding `MeasurementType` enum cases. Schema never changes; new body parts are a code-only addition.

Unit is stored canonically in centimeters; the display layer converts to inches per user preference (the `UnitConversion` helper already exists per recent commits).

### `Scan` — Type + Codable Payload

Structured multi-field scans use a single `Scan` entity with a `type` discriminator and a Codable payload blob:

```swift
@Model final class Scan {
    var id: UUID
    var date: Date
    var type: ScanType          // enum: inBody, dexa, bodPod, labPanel…
    var source: ScanSource      // manual, ocr, import
    var notes: String?
    var payloadData: Data       // encoded Codable, shape determined by `type`
    var createdAt: Date
    var updatedAt: Date
}

enum ScanType: String, Codable {
    case inBody
    // future: dexa, bodPod, labPanel…
}

enum ScanSource: String, Codable {
    case manual, ocr, imported
}

// Type-specific payloads are plain Codable structs, NOT @Model entities.
struct InBodyPayload: Codable {
    var weightKg: Double
    var skeletalMuscleMassKg: Double
    var bodyFatMassKg: Double
    var bodyFatPct: Double
    var totalBodyWaterL: Double
    var pbf: Double              // percent body fat
    var smi: Double              // skeletal muscle index
    // …full InBody field set TBD during Body-tab mockup phase
}

// Later:
// struct DEXAPayload: Codable { … }
// struct LabPanelPayload: Codable { … }
```

**Encode/decode boundary lives in a typed wrapper** — a small helper that takes a `Scan` and returns a strongly-typed case, e.g.:

```swift
enum ScanContent {
    case inBody(InBodyPayload)
    // case dexa(DEXAPayload)
    // case labPanel(LabPanelPayload)
}

extension Scan {
    func decoded() throws -> ScanContent { /* switch on self.type, decode payloadData */ }
}
```

View code calls `scan.decoded()` and switches on the case. Type safety is enforced at the decode boundary, not at the SwiftData column level.

### Why the Payload-Blob Shape

- **Adding a new scan type is purely additive:** new `ScanType` case + new Codable struct + new `ScanContent` case. No `@Model` changes, no SwiftData migration.
- **Unified timeline queries are trivial:** one fetch on `Scan` returns all scans across types in date order.
- **Sync and mirror layers don't need to know about scan types** — they ship `Scan` rows whole. `OutboundMirror` (Cloudflare) and CloudKit both serialize the whole `Scan` record including its opaque `payloadData`.
- **Cost is acceptable:** cannot filter by payload-internal fields in a SwiftData predicate. But scan volume is dozens-to-hundreds per user lifetime — decoding on fetch for trend charts is cheap. If a specific payload field ever needs to be queried hot (e.g. "all InBody scans with body fat > 25%"), we can materialize just that field onto `Scan` later without reshaping the payload model.

### Displaying Metrics

Trend charts and detail views read through the decoded wrapper:

| View | Query / render path |
|---|---|
| Weight trend chart | `WeightEntry` ordered by date → `Swift Charts` |
| Waist trend chart | `Measurement` where type == `.waist` → `Swift Charts` |
| Body fat % trend (InBody) | `Scan` where type == `.inBody` → decode payloads → extract `bodyFatPct` → chart |
| InBody scan detail | Fetch one `Scan` → `scan.decoded()` → render `InBodyPayload` fields |
| Body-tab timeline (if mockups call for it) | Union of `Measurement` + `Scan` sorted by date |

The Body-tab UX (unified timeline vs. per-type sections vs. type-filtered view) remains a mockup-phase decision, deferred per the app's design-driven methodology.

---

## Summary of Decisions

1. **Two builds, one codebase** via separate bundle IDs, separate Xcode schemes/configurations, and a `CADRE_BUILD` compile flag that only selects which `OutboundMirror` gets injected.
2. **CloudKit is always primary.** The Cloudflare D1 sync is an additive outbound mirror behind an `OutboundMirror` protocol, with `NoOpOutboundMirror` (public) and `CloudflareOutboundMirror` (Cadre) implementations.
3. **TestFlight distribution:** public build via External TestFlight + App Store; Cadre build via Internal TestFlight only.
4. **`WeightEntry`, `Measurement`, and `Scan` are three distinct `@Model` entities** with different shapes.
5. **`Scan` uses a `type` discriminator + Codable payload blob**, so new scan types (DEXA, labs, etc.) add no schema migrations.
6. **Body-tab UX shape is deferred** to the mockup phase per the parent spec's design-driven methodology.

## Out of Scope for This Amendment

- Exact `InBodyPayload` field list (resolved during Body-tab mockup phase).
- Body-tab visual layout and whether scans/measurements share a timeline (mockup phase).
- Cloudflare API contract details for the mirror (resolved during implementation planning — will reuse Apex's `POST /v1/:table`, `GET /v1/:table?since=` endpoints).
- Account-based sync (potential future B-model migration; not in scope now).
- Conflict resolution between CloudKit and Cloudflare mirror (Cloudflare is write-only outbound from the device; no conflicts to resolve since CloudKit is the source of truth and Cloudflare is downstream of it).
