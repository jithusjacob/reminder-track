# Reminder Track

## Running tests

Always build the `TrackerApp` scheme **before** running `TrackerAppTests`.
The test target links against the host app (`TEST_HOST`) but its scheme
doesn't rebuild it, so tests otherwise compile against a stale app binary.

```bash
xcodebuild build -project Tracker.xcodeproj -scheme TrackerApp      -destination 'id=<simulator-udid>'
xcodebuild test  -project Tracker.xcodeproj -scheme TrackerAppTests -destination 'id=<simulator-udid>'
```

Every bug fix gets a `REG-###` test in `TrackerAppTests/RegressionTests.swift`
and a full test-suite run. See `TEST_PLAN.md` for the full plan.
