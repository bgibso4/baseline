# Future Work

Running backlog of improvements, features, and fixes for Baseline.

---

## v1.0 — Must-Have for Launch

### Scan / OCR
- [ ] **Test with clean sheet** — Verify accuracy on a sheet without pen marks
- [ ] **Confidence flagging accuracy** — Not all incorrect fields get flagged; users may trust unflagged wrong values

### Features
- [ ] **Apple Health sync — expand metrics** — Sync as many metrics as possible
- [ ] **Data export to Cloudflare/dashboard** — Export data for web dashboard and Cloudflare D1
- [ ] **Goal tracking overlay on trends** — Dotted goal line on chart when user has an active bulk/cut/maintain goal

### Branding / Design Decisions
- [ ] **App logo** — No final logo designed yet
- [ ] **Splash screen design** — Needs logo + animation treatment
- [ ] **Color palette finalization** — Narrowed to 3-4 options, never locked final choice. Design tokens are swappable
- [ ] **Font swappability** — Exo 2 locked, architecture built for easy swap. May revisit
- [ ] **App icon variants** — Standard, dark mode, tinted variants for iOS

### Custom Animations
- [ ] **Now tab arc fill** — Weight arc needs a polished animated fill on appear
- [ ] **Loading / processing animation** — Scan processing, data loading states
- [ ] **Launch screen / splash animation** — Logo or design theme animates in on app launch
- [ ] **Metric picker animation** — Trend metric bottom sheet open/close. See `docs/ANIMATIONS.md`
- [ ] **Tab transitions** — Polish transitions between Now / Trends / Body tabs
- [ ] **Chart draw-on animations** — Trend lines, bar charts animate in

### Infrastructure / Tech Debt
- [ ] **Snapshot tests refresh** — May be stale after recent UI changes
- [ ] **CloudKit push notifications** — Requires `remote-notification` background mode in Info.plist
- [ ] **Test data safeguards** — Prevent accidentally syncing test data to real Apple Health
- [ ] **Body measurements tracking** — Waist, arm, neck size. `BodyMeasurement` long table spec'd but may not be fully built

### App Store Launch Prep
- [ ] **App Store listing** — Screenshots, description, keywords, category
- [ ] **Privacy policy** — Required for App Store submission
- [ ] **Terms of service** — May be required depending on features
- [ ] **App Store review guidelines audit** — Ensure compliance (health data handling, etc.)
- [ ] **Apple requirements spike** — Research and verify all Apple requirements for App Store submission (entitlements, capabilities, export compliance, age rating, etc.)
- [ ] **TestFlight beta** — External beta testing before public launch
- [ ] **Onboarding flow** — First-launch experience explaining the app, permissions requests
- [ ] **Settings screen** — Units preference (kg/lbs), Apple Health toggle, about/version info
- [ ] **Error states and empty states** — Polish all zero-data and error screens
- [ ] **Accessibility audit** — VoiceOver labels, contrast ratios, Dynamic Type
- [ ] **Performance profiling** — Memory, launch time, scroll performance on older devices
- [ ] **Crash reporting** — Integrate crash reporting (Sentry, Firebase Crashlytics, etc.)
- [ ] **Analytics** — Decide on analytics approach (or explicitly decide not to track)
- [ ] **Scrub Cadre references** — Remove/rename any Cadre mentions in non-Cadre build so users aren't confused

### Scan / OCR — Should-Have
- [ ] **Byzantine multi-scan voting** — Scan 3x, derive correct values from consensus
- [ ] **History column handling** — GitHub issue #1, repeat scans with history data

---

## v1.5+ — Post-Launch

### Priority Fixes
- [ ] **P6 — Landscape expand rotation reliability** — `LandscapeHostingController` may not work reliably on all devices
- [ ] **P7 — Dynamic Type scaling** — All text uses fixed Exo 2 sizes, no accessibility scaling. Touches 20+ files
- [ ] **P11 — Cadre build flag + scheme** — No `CADRE_BUILD` flag or `Baseline-Cadre` Xcode scheme yet
- [ ] **P12 — Data migration helper** — App Group store URL change means existing beta data won't auto-migrate

### Widget
- [ ] **Widget sparkline** — Medium home screen widget shows placeholder line, needs real historical data + App Group wiring
- [ ] **Widget spacing** — Small and medium widgets have too much gap above the number

### Scan / OCR
- [ ] **LLM vision upgrade** — Send scan image to Claude/GPT for structured extraction. The definitive solution for accuracy
- [ ] **More scan types** — InBody 770, 270, DEXA. "More coming soon" placeholder already in UI

### Features
- [ ] **Apple Watch app** — Log weight from wrist, complication on watch face
- [ ] **Siri Shortcuts** — Quick log from Siri
- [ ] **iPad support**
- [ ] **Training phase overlay** — Overlay training phases on weight trend graph (complex, needs Apex integration)
- [ ] **Light theme** — Only dark theme exists currently

### Broader Ecosystem
- [ ] **Redesign Apex (workout app) in Swift** — Adopt Cadre design language
- [ ] **Cadre design system adoption** — Baseline establishes the design language; Apex adopts it later

---

## Completed

- [x] **Fix manual entry page** — Now reuses review form layout
- [x] **Multi-photo hint** — "Multiple photos improve accuracy" on scan method card
- [x] **Overwrite scan warning** — "Replace Existing Scan?" alert when saving on a date that already has a scan
- [x] ~~Moving average line~~ — Already built (7-day rolling average on trends chart)
