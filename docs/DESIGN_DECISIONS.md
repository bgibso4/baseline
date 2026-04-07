# Baseline — Design Decisions

Concise log of design decisions made during mockup sessions. Captures the *why* so future work doesn't re-litigate settled questions. Append chronologically. Keep entries terse — details belong in the mockup file named in each entry.

Format:
```
## YYYY-MM-DD — Topic
- **Decision** — brief reason. (mockup: filename)
```

---

## 2026-04-04 — Visual identity

- **Dark UI with locked neutrals + swappable accent** — bg `#0B0B0E`, card `#17171B`, text primary `#F2F3F5`. Core palette stays fixed; only the accent changes across variants. (tokens in every mockup)
- **Accent = dusty blue `#6B7B94`** — picked from 3 options for the "tactical, athletic, quiet confidence" vibe. Amber `#B89968` and a warmer gray are held in reserve for later. The accent token is swappable without touching layout.
- **Primary font: Exo 2** (Google Fonts). — Second place was SF Pro, rejected for being too generic. We picked a display font with a little character. SF Pro kept for small UI chrome (labels, captions). Easy to swap later via font token.
- **Vibe: tactical, athletic, minimalist, quiet confidence** — "climbing the mountain alone." No celebration UI, no gamification. Not flashy. Data-forward.

## 2026-04-04 — Today screen

- **Chose Variant A: 270° arc wrapping the number** — arc shows today's weight's position within a recent range. Number sits centered inside the arc, "Today" label under it. Group is flex-centered in the open area between toolbar and stats card. (mockup: `today-APPROVED-variant-a-2026-04-04.html`)
- **Range toggle options: 30D / 90D / All** — not 7D/30D/90D. 7D is noise for daily weight. Removed "LAST 30 DAYS" header as redundant.
- **Bottom stats card: Lowest / Average / Highest** — for the selected range.
- **"Weigh In" button anchored bottom, above tab bar** — primary action, always reachable.
- **Goal Mode is a separate variant of Today** — fills arc as progress Start→Goal, stats become Start / To Goal / ETA, progress pill replaces range toggle. (mockup: `today-goal-mode-2026-04-04.html`)

## 2026-04-04 — WeighIn sheet

- **Input method: stepper (±0.1 only)** — rejected multi-step-size toggle as overkill. Two 64px circular buttons, 100px apart. Simplest interaction, fewest taps for typical daily change. (mockup: `weighin-APPROVED-2026-04-04.html`)
- **Sheet uses `height: auto`** — content drives size. Percentage heights broke across rendered phone sizes. Content is pushed to bottom via flexbox, Save button sits just above tab bar.
- **Date chip as tappable pill with chevron-down** — shows "Today" when logging today's entry, tap opens SwiftUI .graphical DatePicker. Future dates are disabled.
- **Notes + photo as optional expansion chips** — small muted chips below stepper. Keeps default view clean; expands on demand only when user wants to add context.
- **Tab bar stays visible below sheet** — non-modal feeling, preserves orientation.

## 2026-04-05 — Trends architecture

- **Metric dropdown as primary header** — not a title+hamburger. Metric chip with icon + name + chevron is the screen's main affordance. No "Trends" title (tab label handles it). No hamburger menu (no clear purpose). (mockup: `trends-v3-2026-04-05.html`)
- **Metric list is dynamic** — only shows metrics the user actually has data for. Grouped: Primary (Weight, Body Fat %, Skeletal Muscle, Visceral Fat) / Measurements (Waist, Chest, etc.).
- **Range tabs: M / 6M / Y / All** — killed W. Daily weight is a long-game metric; a week of data is noise.
- **Each metric has metadata** — `frequency` (.daily / .scanBased / .periodic), `direction` (.lowerIsBetter / .higherIsBetter / .neutral), `statsConfig` ([.start, .best, .current] where "best" resolves via direction), `supportsMovingAverage`. Stats row labels adapt per metric: Weight→Lowest, Skeletal Muscle→Highest.
- **7-day moving average only for daily-frequency metrics** — body fat % is scan-based; MA doesn't apply. Connect-the-dots line for scan data.
- **Compare mode replaces always-on overlays** — rejected the v2 idea of toggleable scan markers + phase bands. Instead: user explicitly picks a secondary context to compare with. Subsumes scan markers (compare with Body Fat % to see scan values in context).
- **Compare cap: 2** — dual-axis is the limit. More metrics = visual chaos. Small-multiples pattern would be a different screen; not v1.
- **Compare options include: other metrics, previous period (last month / last year), program phases** — previous period = same metric, different time window (this month vs last month). Program phases (Apex training blocks) disabled until Cadre integration lands. (mockup: `trends-v4-2026-04-05.html`)
- **Goals in Trends: subtle, not loud** — when an active goal exists, show a single dashed target line + small "Goal X" text anchor on the chart. No badge, no "on track" pill, no stat swap. Goal-first framing lives on Today. If no active goal, no goal UI at all.
- **Expand icon top-right of chart → landscape fullscreen** — standard Apple Health pattern. (mockup: pending v5)
- **Phase bands rejected as always-on** — too loud, low signal. Available only as an opt-in compare option.
- **Compare UX: unified dropdown with toggle at the bottom** — not a separate sheet, not a second dropdown. Same dropdown grows when Compare is ON, revealing new compare-only sections (Previous period, Program). (mockup: `trends-dropdown-states-2026-04-05.html`)
- **Compare interaction rules** — Primary is sticky. When compare ON: tap an unset row → it becomes secondary. Tap primary → nothing. Tap current secondary → nothing (no ✕, stays quiet). Tap a different row → swaps secondary. To change primary: turn compare off, pick new primary, turn compare back on. No swap button. Simple, predictable, low-noise.
- **Compare-only metrics live in separate sections** — `Previous period` (Last month, Last year) and `Program` (Apex phases) only appear when compare is ON. They can only be secondary, never primary.
- **Chip shows stacked icons + dual name in compare mode** — `● ● Weight · Body Fat %` with overlapping circular icons (primary accent, secondary amber offset). Dual hero shows both deltas side-by-side with matching colors.
- **Landscape fullscreen chart: two-column layout** — left column (~180px): metric label, large 54px hero delta, meta text. Right ~2/3: chart with scrubbing crosshair + tooltip card. Close button top-right. Triggered by expand icon in portrait chart. (mockup: `trends-compare-v3-2026-04-05.html`)
- **Landscape compare layout: stacked heroes, equal size** — primary and secondary heroes both 54px, stacked vertically with a thin divider between. Matches the importance of both metrics visually. (mockup: `trends-edge-cases-2026-04-05.html`)

## 2026-04-05 — Trends edge cases (14 data & interaction states)

All 14 locked-in, mockup at `trends-edge-cases-2026-04-05.html`. Summary:

- **Empty states have no CTAs** — "Log weight" is weight-specific; Body Fat and measurements don't log from the same place. Empty state = icon + title + body text only. User navigates to the logging action themselves.
- **No "quick-jump" buttons in empty states** — when no data in selected range, show the message ("You have entries going back to Oct 2025") without a button. User taps range tabs themselves.
- **Single data point** — hero shows current value (no sign, no delta text). Stats: all three columns = same value. Sub-text: "Log more entries to see your trend."
- **Sparse data (2–5 points)** — dots + thin connector line. No 7-day MA. Sub notes count ("4 entries in 30 days").
- **Data gaps** — line breaks, no interpolation. Gap rendered as subtle shaded region with "N day gap" label.
- **M/6M/Y are fixed windows** — data displays within the window, even if sparse (e.g. Y with 3 weeks of data = data compressed right). **All scales to fit** the full data range (3 months of data = 3 months shown).
- **Bucketing is point-count driven** — <60 points: raw. 60–180: weekly bins. 180+: monthly bins. Independent of log cadence. Monthly-logged × 5yr (~60 pts) stays raw; daily × 5yr (~1825 pts) buckets to monthly.
- **Buckets render as min-max bars + median line** — bars show range within bucket, line connects bucket medians.
- **Compare mode always uses dual axes** — even when units match (e.g. Body Fat % vs Visceral %). Scales can differ dramatically; each metric gets its full vertical space.
- **Compare ON with no secondary** — chart renders identically to compare-off state. Compare is armed, not active, until user picks a secondary.
- **Secondary with no data in range** — primary renders normally. Secondary axis dimmed. Amber banner above chart: "No {metric} data in this period." Secondary delta in dual hero = "—".
- **Secondary with 1 data point** — single dot, no connecting line. Secondary hero shows the value (no delta — need 2 points).
- **Primary row in dropdown is non-interactive when compare ON** — visual state (accent check) communicates "this is locked as primary." Hint text: "Primary row is locked — tap others." To change primary: turn off compare, pick new primary, turn on.
- **Compare-only rows disabled with reason** — when "Last month"/"Last year" are unavailable (insufficient history), rows greyed with inline reason: "No data before Mar 22" or "Need 12 months of history."

## 2026-04-05 — Body tab

- **Chose Option B: 2-column tile grid** — each metric a tile with icon, label, big value, delta arrow. Scannable at-a-glance view of all body-comp + measurement metrics. (mockup: `body-v1-2026-04-05.html`)
- **Body tab = dashboard, not deep-dive** — tapping a tile → Trends with that metric pre-selected. Trends owns deep chart/compare; Body owns the broad overview + entry points.
- **Two sections: Body Composition / Measurements** — Body Comp = InBody scan-derived metrics (Body Fat %, Skeletal Muscle, Visceral Fat, BMI, Fat Mass, BMR, etc.). Measurements = manual tape entries (Waist, Chest, Neck, Shoulders, Hips, Arms L/R, Thighs L/R, Calves).
- **Weight lives on Today, not Body tab** — avoid duplication.
- **Bilateral measurements as separate tiles** — Arm · L / Arm · R, Thigh · L / Thigh · R. Left-right differences matter for training.
- **Dynamic: tiles only appear for metrics with data** — no empty placeholder tiles.
- **Delta color coding** — `--accent` (dusty blue) for "goal direction" (down for Body Fat, Waist; up for Muscle). `--up` (sage green) for the opposite direction. `--text-tertiary` for flat (±0.0). Metric metadata drives which direction is "good."

## 2026-04-05 — Scan history access (Option D)

- **Chose Option D: Scan History card below Body Comp tiles** — dedicated card with icon, "Scan history" title, "14 scans · since Oct 2025" metadata, and chevron. (mockup: `body-history-full-density-2026-04-05.html`)
- **Why: scans are holistic multi-metric events, they warrant a dedicated entry point** — unlike measurements (which use per-metric history via Trends), scans need their own list. Card earns its space by showing count + recency inline.
- **Measurements have no history card** — per-metric history accessed through Trends tile-tap → "Show all entries" link. Keeps measurements section clean.
- **Alternatives rejected:** Option A (two icons in header) — too easy to miss. Option B (tappable meta link) — non-standard pattern, low discoverability. Option C (kebab menu) — hides the primary + action.
- **Log actions stay consistent** — both Body Comp and Measurements sections use a single + icon button in their section header for logging new entries.

## 2026-04-05 — Body subviews (scan/measurement detail + history)

- **Scan history list** — pushed from the Scan History card. Row layout: date block (day + month-year) on left, scan type (InBody 770 / DEXA / etc.) as title, 3 key metrics (BF / Muscle / BMI) inline below. Taller rows, scannable. (mockup: `body-v4-refinements-2026-04-05.html`)
- **Scan detail** — tap a scan row → detail view listing all captured metrics grouped into sections. Nav bar has 3-dot kebab menu top-right with Edit / Delete (no inline buttons). iOS standard pattern.
- **Edit scan** — pushed from kebab > Edit. Same layout as detail, but each metric row becomes an editable input field. Active field shown with accent border + blinking caret. Cancel/Save in nav bar.
- **Per-metric entry history (Waist, Body Fat %, etc.)** — pushed from Trends view via "Show all entries" link (to be added to Trends). Row layout: date (day + weekday) + delta + value. Swipe row → Edit / Delete actions.
- **Same entry-history layout for all single-value metrics** — Weight entries, Body Fat % entries, Waist entries, etc. all use this pattern. Weight has its own entry point on Today (list icon); others enter via Trends.

## 2026-04-05 — Log measurement sheet

- **Mirrors WeighIn sheet pattern** — same bottom sheet, same stepper (±0.1 only), same Save button placement.
- **Value number is 56px (not 84px like Weight)** — measurements are secondary; weight is the hero. Differentiated sizing makes hierarchy clear.
- **Stepper buttons: 56px circles** (down from 64px on Weight).
- **40px margin between stepper and Save** — fixed from initial no-gap mistake.
- **Date shown as tappable pill chip** with chevron-down (same pattern as WeighIn). Shows "Today" when logging today's entry.
- **Metric picker chip** at top of sheet shows current metric (Waist) with chevron to open metric list.

## 2026-04-05 — Scan entry flow

- **5-screen flow**: Scan Type → Input Method → (Camera → Review) OR Manual Form → Save. (mockup: `scan-entry-flow-2026-04-05.html`)
- **Scan type picker preserved even with one option** — pattern stays in place for adding InBody 770, DEXA, 270 later. InBody 570 pre-selected (only supported in v1), Continue enabled by default. "More scan types coming soon" placeholder below. No "Other" option — avoids the question of what custom metrics look like.
- **Input method**: two method cards — "Scan printout" (camera OCR) or "Enter manually". Chosen after type so the schema is known.
- **Camera capture**: full-bleed camera view, dashed guide frame with accent corner brackets, align-printout hint, standard shutter button. Cancel X top-right.
- **Post-capture Review**: all OCR'd values pre-filled in editable form. Low-confidence reads flagged with amber border + warning banner at top.
- **Manual form**: same schema + layout as Review, empty placeholders (`—`), first field auto-focused.
- **InBody 570 schema: 22 user-facing metrics across 4 sections.** Core (7): Weight, Body Fat %, Skeletal Muscle, Body Fat Mass, BMI, BMR, Visceral Fat. Body Composition (5): Intracellular Water, Extracellular Water, **Total Body Water** (derived), Dry Lean Mass, **Lean Body Mass** (derived). Segmental Lean (5 × 2 = 10 fields): Right Arm / Left Arm / Trunk / Right Leg / Left Leg, each with lbs + %. Advanced (2): ECW/TBW, SMI.
- **Derived metrics rendered with subtle tinted background + "· derived" label suffix** — signals computed-from-others vs. directly captured. For InBody 570: Total Body Water = IC + EC, Lean Body Mass = TBW + Dry Lean Mass.
- **Segmental rows use 2 smaller side-by-side inputs** (lbs + %) to keep the form compact without losing either value. The % represents lean sufficiency (100% = ideal for height/weight).
- **Height/Age/Gender captured in Settings (user profile), not per scan** — these don't change scan-to-scan.
- **Scan date defaults to Today** via tappable date-chip pill; OCR may populate from printout later.

## 2026-04-05 — Settings

- **7 grouped sections**: Profile, Units, Appearance, Integrations, Data, About, Reset. Single scrollable list, iOS-standard pattern. (mockup: `settings-v1-2026-04-05.html`)
- **Profile section contains 4 rows**: Name, Height, Birthday (not Age), Gender. Height and Gender are needed for BMR/SMI calculations on InBody scans.
- **Birthday (not Age)** — store DOB, auto-compute age. Unlocks future age-based features (e.g. age-over-time overlay on metrics). Birthday picker uses iOS .graphical DatePicker with computed age card below.
- **Units: lb/kg and in/cm as inline segmented toggles** — no sub-screen needed for binary choices.
- **Unit handling principle: store as captured, display as preferred.** Scans save in whatever units they provide (InBody gives us lbs + inches). User's unit preference only affects display rendering, not storage.
- **Appearance section** — accent color picker (3 inline swatches: dusty blue active, amber + warm-gray in reserve) + Theme (Dark only in v1, Light + System marked "Soon").
- **Integrations section** — Apple Health toggle, iCloud Sync toggle with "Synced" status badge, Cadre Sync (push-navigation with "Connected" badge for dev/personal use).
- **Data section** — Export to CSV (push to picker), Import from Weigh In (disabled with "Soon" badge).
- **About section** — Version (read-only info row), About Cadre (push), Privacy Policy + Terms of Service (external link icons, not chevrons — they open web URLs).
- **Reset section** — Delete all data, styled in red (danger), triggers action sheet confirmation.
- **Unset value handling** — rows whose values haven't been set show "Not set" in dim tertiary text on the right. Row is still tappable to set.

## 2026-04-05 — Settings sub-screens

All 9 destinations mocked at `settings-subscreens-2026-04-05.html`:

- **Name** — single text input, auto-focused, Cancel/Save in nav bar, ✕ button to clear field.
- **Height** — two wheel pickers side-by-side (feet + inches imperial) or single cm wheel (metric). Hint text explains usage.
- **Birthday** — iOS .graphical DatePicker, computed-age card below shows current calculated age.
- **Gender** — single-select list (Male / Female / Other / Prefer not to say). Back-arrow-saves pattern (no Cancel/Save buttons needed — tap a row to select).
- **Theme** — list (Dark / Light / System). Dark = only v1 option; others "Soon" badged.
- **Cadre Sync** — form fields for API URL + masked API Key (eye icon to reveal), Test connection button, green status banner ("Connected · last synced 2m ago").
- **Export CSV** — hero icon + title, checkboxes for what to export (Weight / Scans / Measurements) with record counts, "Export N files" button → iOS share sheet to save to Files.
- **About Cadre** — Cadre logo + ecosystem description, app list card (Baseline "This app" / Apex "Sibling" / Dashboard "Soon"). Rows show each app's letter-mark logo with tinted background.
- **Delete all data** — action sheet from bottom (not push). Warning icon, title "Delete all data?", body text, itemized list of what gets deleted with counts, red "Delete everything" + grey "Cancel" buttons.

## 2026-04-05 — Widgets (baseline approval, refine later)

- **7 widget variants across 3 placements**: Home Screen (Small/Medium/Large), Lock Screen (Circular/Rectangular/Inline), StandBy (landscape). (mockup: `widgets-v1-2026-04-05.html`)
- **Home Small (2×2)**: "Today" pulse-dot label + big weight number + delta from yesterday.
- **Home Medium (4×2)**: weight + delta + weekly rate + 7-day sparkline. Most info-per-pixel.
- **Home Large (4×4)**: hero number + 30-day chart + stats row (Start/Lowest/Current). Closest to Today tab.
- **Lock Circular (72×72)**: whole-number weight only (rounds 197.4 → 197).
- **Lock Rectangular (160×72)**: weight + delta with "Baseline" label.
- **Lock Inline**: text-only strip (`197.4 lb · −0.3`) above the clock.
- **StandBy (landscape)**: huge 88px number + 30-day chart, readable across the room while phone docked.
- **All tap to app at Today screen.** Refresh on WidgetKit schedule + after app writes.
- **Approved as baseline, not final.** Widgets are supplemental; revisit spacing + data choices if needed during implementation.

## 2026-04-05 — Tab rename: Today → Now

- **Renamed "Today" tab to "Now"** — present-tense, single syllable, punchier. "Today" felt generic and only described the content (today's weight) rather than the screen's role as the landing glance.
- **Rationale**: fits the tactical/athletic/quiet-confidence vibe. Reads well: `Trends · Now · Body`. "Open app → Now → weigh in" is the primary flow sentence.
- **Alternatives considered**: Home (too generic), Status (blurs with Trends), Base (abbreviation-feel), Overview (bland). Now won on punchiness + present-tense immediacy.
- **Scope of change**: tab-bar label only. Internal model/file naming ("TodayViewModel", "TodayView") can stay as-is or be renamed during implementation — not user-facing.
- **Applied across all mockup tab bars.**
- **Follow-up (Task 8 implementation)**: internal naming also renamed to match — `TodayView` → `NowView`, `TodayViewModel` → `NowViewModel`, folder `Views/Today/` → `Views/Now/`, and associated test files/snapshots. Semantic "today's entry" concepts (`todayEntry` property, date helpers like `isToday`) kept as-is since they refer to the calendar date, not the screen.

## 2026-04-05 — Deferred for dedicated brainstorm

- **Goals (bulk / cut / maintain) as a feature** — lifecycle, history, how they surface across Today / Trends / Settings is unresolved. What happens across time ranges with multiple historical goals? Transitions between goals? Failed/abandoned goals? Needs its own brainstorm before finalizing Trends goal overlay.
