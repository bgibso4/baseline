# Future Work

Running backlog of improvements, features, and fixes for Baseline.

---

## v1.0 — Must-Have for Launch

### Phase 1 — Lock the Foundation
*Branding decisions gate everything visual. Infrastructure items are quick and should be early.*

- [ ] 1. **Color palette finalization** — Narrowed to 3-4 options, never locked final choice. Design tokens are swappable
- [ ] 2. **Font decision** — Exo 2 locked, architecture built for easy swap. Decide now
- [ ] 3. **App logo** — No final logo designed yet
- [ ] 4. **App icon variants** — Standard, dark mode, tinted variants for iOS
- [ ] 5. **Crash reporting** — Integrate crash reporting (Sentry, Firebase Crashlytics, etc.)
- [ ] 6. **CloudKit push notifications** — Requires `remote-notification` background mode in Info.plist
- [ ] 7. **Scrub Cadre references** — Remove/rename any Cadre mentions in non-Cadre build so users aren't confused
- [ ] 8. **Apple requirements spike** — Research and verify all Apple requirements (entitlements, capabilities, export compliance, age rating, etc.)

### Phase 2 — Build Missing Features
*Independent of each other, can be parallelized.*

- [ ] 9. **Apple Health sync — expand metrics** — Sync as many metrics as possible
- [ ] 10. **Data export to Cloudflare/dashboard** — Export data for web dashboard and Cloudflare D1
- [ ] 11. **Goal tracking overlay on trends** — Dotted goal line on chart when user has an active bulk/cut/maintain goal
- [ ] 12. **Body measurements tracking** — Waist, arm, neck size. `BodyMeasurement` long table spec'd but may not be fully built
- [ ] 13. **Confidence flagging accuracy** — Not all incorrect fields get flagged; users may trust unflagged wrong values
- [ ] 14. **Test with clean sheet** — Verify accuracy on a sheet without pen marks
- [ ] 15. **Test data safeguards** — Prevent accidentally syncing test data to real Apple Health
- [ ] 16. **Settings screen** — Units preference (kg/lbs), Apple Health toggle, about/version info
- [ ] 17. **Byzantine multi-scan voting** — Scan 3x, derive correct values from consensus
- [ ] 18. **History column handling** — GitHub issue #1, repeat scans with history data

### Phase 3 — Polish & Animate
*Branding is locked, features are built, now make it feel good.*

- [ ] 19. **Splash screen design** — Needs logo + animation treatment
- [ ] 20. **Launch screen / splash animation** — Logo or design theme animates in on app launch
- [ ] 21. **Now tab arc fill** — Weight arc needs a polished animated fill on appear
- [ ] 22. **Loading / processing animation** — Scan processing, data loading states
- [ ] 23. **Metric picker animation** — Trend metric bottom sheet open/close. See `docs/ANIMATIONS.md`
- [ ] 24. **Tab transitions** — Polish transitions between Now / Trends / Body tabs
- [ ] 25. **Chart draw-on animations** — Trend lines, bar charts animate in
- [ ] 26. **Error states and empty states** — Polish all zero-data and error screens
- [ ] 27. **Accessibility audit** — VoiceOver labels, contrast ratios, Dynamic Type
- [ ] 28. **Performance profiling** — Memory, launch time, scroll performance on older devices

### Phase 4 — Ship
*Everything is built and polished. Final prep.*

- [ ] 29. **Snapshot tests refresh** — After all UI is final
- [ ] 30. **Onboarding flow** — First-launch experience explaining the app, permissions requests
- [ ] 31. **Privacy policy + Terms of service** — Required for App Store submission
- [ ] 32. **Analytics** — Decide on analytics approach (or explicitly decide not to track)
- [ ] 33. **App Store review guidelines audit** — Ensure compliance (health data handling, etc.)
- [ ] 34. **App Store listing** — Screenshots, description, keywords, category
- [ ] 35. **TestFlight beta** — External beta testing before public launch

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

### Goal Tracking
- [ ] **Auto-detect goal completion for scans/measurements** — Wire checkCompletion after scan save (ScanEntryViewModel) and measurement save (LogMeasurementSheet) for non-weight goals like body fat %, waist size, etc.

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
- [x] **Guideline 5.1.3 compliance** — CloudKit fields encrypted with `.allowsCloudEncryption`, sync monitor added for keychain reset edge case
