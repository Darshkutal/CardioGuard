# CardioGuard — Phase 1: Tracker Skeleton

SwiftUI + SwiftData + Swift Charts. Requires Xcode 15+ and iOS 17+.

## Open it in Xcode

**Option A (XcodeGen):** `brew install xcodegen && cd CardioGuard && xcodegen && open CardioGuard.xcodeproj`
(edit `bundleIdPrefix` in `project.yml` first).

**Option B (manual):** Xcode > New Project > iOS App (SwiftUI, name `CardioGuard`, min iOS 17). Delete the generated
`ContentView.swift` and `CardioGuardApp.swift`, drag in the `CardioGuard/` source folder, and add
`CardioGuardTests/StatsTests.swift` to a unit-test target.

## What Phase 1 includes
- Onboarding: name, conditions, medications, allergies, emergency contact, required "not a medical device / call 911" acknowledgment
- Log vitals (heart rate, blood pressure, glucose, SpO2) with typo-guard validation, backdating, and notes
- Log symptoms with 1-5 severity
- Dashboard cards: latest value, 7-day average, sparkline
- Trend screen: Swift Charts line chart with 7D/30D/90D/All, average line, min/max/avg tiles (BP shows both series)
- History: vitals/symptoms lists with swipe-to-delete, CSV export via share sheet for doctor visits
- Profile editing, erase-all-data, debug-only "Load demo data" button (Profile tab) for populating charts
- All data local via SwiftData; nothing leaves the device
- Unit tests for stats, time ranges, CSV escaping, input bounds

## Deliberately not in Phase 1
No anomaly scoring, alerts, backend, HealthKit, or emergency notifications (Phases 2-5). The `plausibleRange` values
only catch typos and are not medical thresholds.

## Note
This code was written without access to a Swift compiler, so expect to fix a small compile error or two on first build.
