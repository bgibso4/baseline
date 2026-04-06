# Metric Picker Redesign — Bottom Sheet + Compare

**Date:** 2026-04-06
**Status:** Design approved
**Parent:** Trends screen (Task 13)

## Summary

Replace the current overlay dropdown metric picker with a bottom sheet. The dropdown approach doesn't scale to 20+ InBody metrics and makes the compare toggle awkward. The bottom sheet provides room for grouped metrics, a sticky compare toggle, and scrollable content.

## Design Decision

**Bottom sheet** (Option B) chosen over overlay dropdown (Option A) and full-screen push (Option C).

**Why:** The metric picker is a low-frequency, high-importance interaction. Users don't switch metrics every session, but when they do, they need to browse 20+ options with grouping, toggle compare mode, and select a secondary metric. A bottom sheet is the standard iOS pattern for this kind of rich, infrequent configuration. The spatial disconnect (chip at top, sheet from bottom) is mitigated by the chip updating immediately on selection.

## Interaction Model

### Compare OFF (default)
- Tap chip → sheet slides up
- Compare toggle is sticky at top of sheet (always visible while scrolling)
- Metrics grouped by category, only metrics with recorded data shown
- Tap any row → becomes primary metric, sheet auto-dismisses, chart updates

### Compare ON
- Toggle compare switch → sheet grows to show additional sections
- Primary metric is locked (accent checkmark, non-interactive)
- Hint text: "Primary is locked — tap others to compare"
- Tap an unset row → becomes secondary (amber checkmark)
- Tap current secondary → nothing (no deselect, stays quiet)
- Tap a different row → swaps secondary
- To change primary: turn compare OFF, pick new primary, turn compare ON

### Compare-Only Sections (visible only when compare ON)
- **Previous period:** Last month, Last year (greyed with reason if insufficient data)
- **Program:** Apex phases (disabled, "Soon" badge)

## Metric Groups

Only metrics with at least 1 recorded data point are shown. Groups:

1. **Core** — Weight, Body Fat %, Skeletal Muscle, BMI, Fat Mass
2. **Body Composition** — Lean Body Mass, Total Body Water, ICW, ECW, Dry Lean Mass, BMR, InBody Score
3. **Segmental Lean** — Right/Left Arm, Trunk, Right/Left Leg
4. **Segmental Fat** — Right/Left Arm, Trunk, Right/Left Leg
5. **Measurements** — Waist, Chest, Neck, Hips, Arms, Thighs, Calves

## Chip States

- **Single metric:** Icon + metric name + down chevron
- **Dual metric (compare active):** Stacked icons (primary accent, secondary amber offset) + "Primary · Secondary" + down chevron

## Hero Behavior

- **Weight, weighed in today:** Latest value in accent color, "Today" label
- **Weight, not weighed in today:** Latest value in textTertiary (dimmed), relative date label ("Yesterday", "3 days ago", "Mar 28")
- **Non-weight scan metrics:** Latest value always in metric color (scans aren't daily, no today/not-today distinction)
- **Compare active:** Dual hero — primary value (accent) + secondary value (amber) side by side

## Visual Spec

- Sheet background: `#1C1C22`
- Sheet border-radius: 20px top corners
- Drag handle: 36×5, textTertiary, centered
- Compare toggle: sticky header, doesn't scroll
- Row height: 11px vertical padding + 26×26 icon box + 14px font
- Dividers: 0.5px `rgba(255,255,255,0.06)`
- Section labels: 10px uppercase, 0.5px tracking, textTertiary
- Active primary row: accent icon bg + accent checkmark
- Active secondary row: amber icon bg + amber checkmark
- Disabled rows: 35% opacity + reason text or "Soon" badge

## Body Tab Tile Routing (also in scope)

- **Scan-derived metrics** (BF%, SMM, BMI, Fat Mass, LBM, TBW, etc.) → tap navigates to Trends tab with that metric pre-selected
- **Manual measurements** (Waist, Chest, Neck, etc.) → tap navigates to measurement-specific history list (date + value rows, editable)
- All scan-derived metrics from InBodyPayload should map to TrendMetric enum cases

## Flagged for Later

- **Animation pass:** Chip chevron rotation, chip pulse on sheet open, sheet spring animation, metric row selection feedback
- **Dual-axis chart rendering** for compare mode (both metrics plotted, independent Y scales)
- **Previous period overlay** (same metric, different time window)

## Mockups

- `docs/mockups/metric-picker-v2-2026-04-06.html` — approved final (6 states + interaction rules)
- `docs/mockups/metric-picker-options-2026-04-06.html` — exploration (3 options compared)
