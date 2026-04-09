# Future Work

Running backlog of improvements, features, and fixes for Baseline.

---

## Priority Fixes (P6-P12 from original build)

- [ ] **P6 — Landscape expand rotation reliability** — `LandscapeHostingController` may not work reliably on all devices
- [ ] **P7 — Dynamic Type scaling** — All text uses fixed Exo 2 sizes, no accessibility scaling. Touches 20+ files, requires reworking `CadreTypography`
- [ ] **P10 — Widget sparkline** — Medium home screen widget shows placeholder line, needs real historical data + App Group wiring
- [ ] **P11 — Cadre build flag + scheme** — No `CADRE_BUILD` flag or `Baseline-Cadre` Xcode scheme yet. Not needed until Cadre branding ships
- [ ] **P12 — Data migration helper** — App Group store URL change means existing beta data won't auto-migrate

## Scan / OCR

- [x] **Fix manual entry page** — Now reuses review form layout (sections, segmental tables, date picker, scroll dismiss)
- [x] **Multi-photo hint** — "Take multiple photos for better accuracy" on scan method card
- [ ] **LLM vision upgrade** — Send scan image to Claude/GPT for structured extraction. Deferred due to API key exposure concerns, but would solve remaining accuracy issues
- [ ] **Byzantine multi-scan voting** — Scan 3x, derive correct values from consensus
- [ ] **History column handling** — GitHub issue #1, repeat scans with history data
- [ ] **Test with clean sheet** — Verify accuracy on a sheet without pen marks
- [ ] **Confidence flagging accuracy** — Not all incorrect fields get flagged; users may trust unflagged wrong values
- [ ] **More scan types** — InBody 770, 270, DEXA. "More coming soon" placeholder already in UI

## Features (v1.5+)

- [ ] **Apple Watch app** — Log weight from wrist, complication on watch face
- [ ] **Siri Shortcuts** — Quick log from Siri
- [ ] **iPad support**
- [ ] **Apple Health sync — expand metrics** — Sync as many metrics as possible
- [ ] **Data export to Cloudflare/dashboard** — Export data for web dashboard and Cloudflare D1
- [ ] **Goal tracking overlay on trends** — Dotted goal line on chart when user has an active bulk/cut/maintain goal
- [ ] **Training phase overlay** — Overlay training phases on weight trend graph (complex with multiple overlays)
- [ ] **Moving average line on chart**
- [ ] **Multi-user support** — Needed before App Store public release
- [ ] **Light theme** — Only dark theme exists currently

## Branding / Design Decisions

- [ ] **App logo** — No final logo designed yet
- [ ] **Splash screen design** — Needs logo + animation treatment
- [ ] **Color palette finalization** — Narrowed to 3-4 options, never locked final choice. Design tokens are swappable
- [ ] **Font swappability** — Exo 2 locked, architecture built for easy swap. May revisit
- [ ] **App icon variants** — Standard, dark mode, tinted variants for iOS

## UI / Polish

- [x] **Overwrite scan warning** — "Replace Existing Scan?" alert when saving on a date that already has a scan
- [ ] **Widget spacing** — Small and medium widgets have too much gap above the number

## Custom Animations

- [ ] **Now tab arc fill** — Weight arc needs a polished animated fill on appear
- [ ] **Loading / processing animation** — Scan processing, data loading states
- [ ] **Launch screen / splash animation** — Logo or design theme animates in on app launch
- [ ] **Metric picker animation** — Trend metric bottom sheet open/close. See `docs/ANIMATIONS.md`
- [ ] **Tab transitions** — Polish transitions between Now / Trends / Body tabs
- [ ] **Chart draw-on animations** — Trend lines, bar charts animate in

## Infrastructure / Tech Debt

- [ ] **Snapshot tests refresh** — May be stale after recent UI changes
- [ ] **CloudKit push notifications** — Requires `remote-notification` background mode in Info.plist
- [ ] **Test data safeguards** — Prevent accidentally syncing test data to real Apple Health
- [ ] **Body measurements tracking** — Waist, arm, neck size. `BodyMeasurement` long table spec'd but may not be fully built

## App Store Launch Prep

- [ ] **App Store listing** — Screenshots, description, keywords, category
- [ ] **Privacy policy** — Required for App Store submission
- [ ] **Terms of service** — May be required depending on features
- [ ] **App Store review guidelines audit** — Ensure compliance (health data handling, etc.)
- [ ] **TestFlight beta** — External beta testing before public launch
- [ ] **Onboarding flow** — First-launch experience explaining the app, permissions requests
- [ ] **Settings screen** — Units preference (kg/lbs), Apple Health toggle, about/version info
- [ ] **Error states and empty states** — Polish all zero-data and error screens
- [ ] **Accessibility audit** — VoiceOver labels, contrast ratios, Dynamic Type (see P7)
- [ ] **Performance profiling** — Memory, launch time, scroll performance on older devices
- [ ] **Crash reporting** — Integrate crash reporting (Sentry, Firebase Crashlytics, etc.)
- [ ] **Analytics** — Decide on analytics approach (or explicitly decide not to track)

## Broader Ecosystem

- [ ] **Redesign Apex (workout app) in Swift** — Adopt Cadre design language
- [ ] **Cadre design system adoption** — Baseline establishes the design language; Apex adopts it later
