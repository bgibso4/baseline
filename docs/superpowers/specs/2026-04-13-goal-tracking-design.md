# Goal Tracking Design Spec

## Goal

Let users set a target for any trackable metric (weight, body fat %, SMM, etc.) with an optional deadline, and see progress toward it on the Trends chart and Now screen.

## Architecture

One active goal at a time, persisted via SwiftData. Goals have a lifecycle: active → completed or abandoned. All goals (including abandoned) are saved for future history UI. The goal line renders on the Trends chart only when viewing the goal's metric.

## Data Model

```swift
@Model
final class Goal {
    var id: UUID
    var metric: String          // TrendMetric rawValue (e.g. "weight", "bodyFatPct")
    var targetValue: Double
    var targetDate: Date?       // Optional deadline, must be today or later
    var startValue: Double      // Value when goal was set
    var startDate: Date
    var status: String          // "active" | "completed" | "abandoned"
    var completedDate: Date?
    var createdAt: Date
}
```

Constraints:
- One active goal at a time (enforce in view model)
- `targetDate` must be >= today when set
- `startValue` captured automatically from most recent entry for the metric

## UI Components

### 1. Trends Screen — Goal Card (below stats row)

**No goal state:** Dashed-border card with "+" icon and "Set a goal" text. Tapping opens Set Goal sheet.

**Goal active (no date):** Solid card showing:
- "GOAL" label (accent color) + ··· menu button
- Current value → target value with arrow
- Progress bar (percentage filled)
- "X.X lb to go" + percentage

**Goal active (with date):** Same as above but:
- "GOAL · by Jul 1" in header
- "47 days left" replaces percentage in footer

**··· menu** opens a sheet with:
- Goal progress summary (current → target, progress bar, started date)
- Edit Goal (accent filled button)
- Mark Complete (card with green text)
- Abandon Goal (red text link)

### 2. Trends Chart — Goal Line

Dotted horizontal line at the target value, rendered only when viewing the goal's metric. Label "185 lb" at the right edge of the line. Uses accent color at reduced opacity.

### 3. Now Screen — Stats Card Swap

When a goal is active, the existing Lowest/Average/Highest stats card repurposes:

**No date:** Current | Target (accent) | To Go

**With date:** Same, but "To Go" slot adds "47 days left" subtitle

User can tap to toggle between goal view and historical stats.

### 4. Set Goal Sheet

Presented from the "Set a goal" card on Trends. Fields:
- **Metric** — dropdown, defaults to currently selected chart metric
- **Target** — numeric input with unit
- **Target Date** — optional, date picker, today or later only

"Set Goal" accent button at bottom.

### 5. Goal Completion

Triggers immediately after saving a weigh-in or scan where the value crosses the target. Only fires once per goal. Shows a celebration modal:
- Target emoji
- "Goal Reached!" title
- Summary: target value, started at value + date
- "Set New Goal" (accent button)
- "Dismiss" (text link)

Also accessible manually via ··· menu → "Mark Complete".

## Behaviors

- Goal line only shows on chart when viewing the goal's metric
- Auto-detect fires once when value crosses target, then marks goal completed
- "Crosses" means: if cutting (target < start), new value ≤ target. If bulking (target > start), new value ≥ target
- Direction is inferred from start vs target values — no explicit bulk/cut selection
- All goals persist in SwiftData for future history UI
- Setting a new goal while one is active: prompt to abandon current goal first

## Mockups

See `docs/mockups/goal-tracking-design.html`
