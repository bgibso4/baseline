# Baseline Animation Inventory

## System Polish (Built-in SwiftUI transitions)

These are standard SwiftUI animations that make the app feel responsive and fluid.

| Location | Animation | Status |
|----------|-----------|--------|
| Trends hero number | `.contentTransition(.numericText())` + `.snappy` on value change | DONE |
| Trends dual hero | `.contentTransition(.numericText())` on both primary + secondary values | DONE |
| Trends range tabs | `.snappy(duration: 0.25)` spring on active tab background | DONE |
| Trends metric switch | `.easeInOut(duration: 0.3)` crossfade on chart/hero when metric changes | DONE |
| Trends time range switch | `.easeInOut(duration: 0.3)` crossfade on chart/stats when range changes | DONE |
| Trends stats row | `.contentTransition(.numericText())` on stat values | DONE |
| Now hero number | `.contentTransition(.numericText())` + `.snappy` on weight change | DONE |
| Now arc indicator | `.easeInOut(duration: 0.4)` on fraction change when switching ranges | DONE |
| Now range toggle | `.snappy(duration: 0.25)` spring on active segment background | DONE |
| Now stats row | `.contentTransition(.numericText())` on stat values | DONE |
| WeighIn stepper | Already has `.snappy` + haptics | DONE |
| WeighIn note/photo expand | Already has `.easeInOut(duration: 0.25)` | DONE |
| WeighIn date picker | Already has `.easeInOut(duration: 0.25)` | DONE |
| Body tiles | `.opacity` transition + `.easeIn(duration: 0.25)` fade-in on data load | DONE |
| Metric picker sheet | Native sheet spring (system default) | DONE |
| Tab switching | System default (TabView handles this) | DONE |
| Settings toggles | System default (Toggle handles this) | DONE |

## Custom Animations (Require design + iteration)

These are bespoke animations that define the app's personality. Each needs design input.

| Location | Concept | Status |
|----------|---------|--------|
| Launch screen | Logo/brand reveal sequence | NOT STARTED |
| Now screen arc | Animated arc fill on appear (weight range indicator) | NOT STARTED |
| Now screen arc | Pulse/glow on new weigh-in | NOT STARTED |
| Scan entry | Success celebration (checkmark/confetti) | NOT STARTED |
| First weigh-in | Onboarding delight moment | NOT STARTED |
| Pull-to-refresh | Custom refresh indicator | NOT STARTED |
| Chart draw-on | Line drawing animation on first appear | NOT STARTED |
| Compare mode | Split/merge animation when toggling compare | NOT STARTED |
