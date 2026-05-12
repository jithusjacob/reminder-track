# Reminder Track — Test Plan

> Execute this plan for every PR, release candidate, or significant change.
> All tests live in `TrackerAppTests/` (unit + regression + volume) and
> `TrackerAppUITests/` (UI smoke). Run via `xcodebuild test` or Xcode's
> Test Navigator.

---

## 1. How to Run

```bash
# Unit + regression + volume tests (fast, no device needed)
xcodebuild test \
  -scheme TrackerAppTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/tracker-build

# UI smoke tests (requires booted simulator)
xcodebuild test \
  -scheme TrackerAppUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/tracker-build
```

Run both before merging any PR.

---

## 2. Automated Tests

### 2.1 Unit Tests — `ModelsTests`

| # | Test | What It Verifies |
|---|------|-----------------|
| U-01 | `testColorFromValidLowercaseHex` | Color parses lowercase hex |
| U-02 | `testColorFromValidUppercaseHex` | Color parses uppercase hex |
| U-03 | `testColorFromHexWithLeadingHash` | `#RRGGBB` format accepted |
| U-04 | `testColorFromEmptyStringReturnsNil` | Empty string → nil |
| U-05 | `testColorFromInvalidCharsReturnsNil` | Non-hex chars → nil |
| U-06 | `testColorRoundtripThroughHex` | Hex → Color → hex preserves value |
| U-07 | `testWeekRangeSpansSixDays` | Week is exactly 7 days (start→end = 6) |
| U-08 | `testWeekRangeStartDoesNotExceedToday` | Week start ≤ today |
| U-09 | `testWeekRangeContainsToday` | Today is inside the week range |
| U-10 | `testWeekRangeStartIsStartOfWeek` | Start aligns to firstWeekday |
| U-11 | `testMonthRangeStartIsFirstDay` | Month range starts on day 1 |
| U-12 | `testMonthRangeEndIsLastDay` | Month range ends on last day |
| U-13 | `testMonthRangeContainsToday` | Today is inside month range |
| U-14 | `testMonthRangeLeapYearFebruary` | Feb 2024 ends on day 29 |
| U-15 | `testMonthRangeNonLeapYearFebruary` | Feb 2023 ends on day 28 |
| U-16 | `testMonthRangeEndDoesNotOverlapNextMonth` | Month end ≠ next month |
| U-17 | `testYearRangeStartIsJanFirst` | Year starts Jan 1 |
| U-18 | `testYearRangeEndIsDecThirtyFirst` | Year ends Dec 31 |
| U-19 | `testYearRangeContainsToday` | Today inside year range |
| U-20 | `testRecurrenceTypeRawValues` | Raw strings match spec |
| U-21 | `testRecurrenceTypeAllCasesCount` | 3 recurrence types |
| U-22 | `testRecurrenceTypeCodableRoundtrip` | JSON encode/decode stable |
| U-23 | `testExportDataVersionIsTwo` | Export format version = 2 |
| U-24 | `testExportDataRoundtrip` | JSON encode → decode → same values |
| U-25 | `testExportDataToTrackersPreservesFields` | Fields survive import |
| U-26 | `testExportDataToTrackersAssignsUniqueIds` | Imported trackers get fresh UUIDs |
| U-27 | `testIsoDateFormatterFormat` | Produces `yyyy-MM-dd` |
| U-28 | `testIsoDateFormatterZeroPadsMonth` | Jan → `01`, not `1` |
| U-29 | `testIsoDateFormatterParseRoundtrip` | String → Date → String is stable |
| U-30 | `testIsoDateFormatterKeySameForSameDayDifferentTimes` | 00:00 and 23:59 same key |
| U-31 | `testScheduleURLSchemeAndHost` | `tracker://schedule` |
| U-32 | `testScheduleURLContainsTrackerId` | trackerId param present |
| U-33 | `testConfigURLSchemeAndHost` | `tracker://config` |

### 2.2 Unit Tests — `CSVExporterTests`

| # | Test | What It Verifies |
|---|------|-----------------|
| C-01 | `testEmptyEntriesProducesHeaderOnly` | No entries → header row only |
| C-02 | `testHeaderContainsExpectedColumns` | All 4 column headers present |
| C-03 | `testSingleEntryProducesTwoLines` | 1 entry → 2 lines total |
| C-04 | `testSingleEntryDateColumn` | Date in `yyyy-MM-dd` format |
| C-05 | `testCompletedEntryShowsTrue` | Completed → `"true"` |
| C-06 | `testIncompleteEntryShowsFalse` | Not done → `"false"` |
| C-07 | `testValueIsPreserved` | Numeric value passes through |
| C-08 | `testEntriesSortedByDateAscending` | Oldest first |
| C-09 | `testNoteWithCommaIsQuoted` | `"good, great"` → double-quoted |
| C-10 | `testNoteWithDoubleQuoteIsEscaped` | `"` → `""` inside quoted field |
| C-11 | `testNoteWithSemicolonPassesThrough` | `;` needs no escaping |
| C-12 | `testEmptyNoteProducesEmptyQuotes` | Empty note → `""` |
| C-13 | `testNoteWithUnicodePreserved` | Emoji and multi-byte chars survive |
| C-14 | `testFileURLCreatesFile` | File written to disk |
| C-15 | `testFileURLExtensionIsCSV` | Extension is `.csv` |
| C-16 | `testFileURLContainsTrackerName` | File name includes tracker name |
| C-17 | `testFileURLSanitizesForwardSlash` | `/` removed from name |
| C-18 | `testFileURLSanitizesColon` | `:` removed from name |
| C-19 | `testFileURLContainsDate` | Today's date in file name |
| C-20 | `testFileContentsMatchCSVOutput` | File bytes equal `csv()` output |

### 2.3 Unit Tests — `LogStoreCacheTests`

| # | Test | What It Verifies |
|---|------|-----------------|
| L-01 | `testInitialCacheIsEmpty` | Fresh store has no cached entries |
| L-02 | `testIsLoadingFalseInitially` | isLoading starts false |
| L-03 | `testErrorMessageNilInitially` | No error at startup |
| L-04 | `testLogVersionStartsAtZero` | logVersion = 0 initially |
| L-05 | `testEntryForUnknownTrackerReturnsNil` | Cache miss → nil |
| L-06 | `testEntriesForUnknownTrackerReturnsEmpty` | Range query on unknown → [] |
| L-07 | `testAllEntriesForUnknownTrackerReturnsEmpty` | allEntries on unknown → [] |
| L-08 | `testEntryForPastDateReturnsNil` | Past date not in cache |
| L-09 | `testEntriesForTwoUnknownTrackersAreBothEmpty` | Multiple tracker isolation |
| L-10 | `testEntriesInFutureRangeReturnsEmpty` | Future range → [] |
| L-11 | `testEntriesInPastRangeReturnsEmpty` | Far-past range → [] |
| L-12 | `testToggleRequiresPermission` *(skipped w/o auth)* | Toggle creates entry |
| L-13 | `testDoubleToggleResetsState` *(skipped w/o auth)* | Two toggles = unchecked |
| L-14 | `testLogIncrementsLogVersion` *(skipped w/o auth)* | logVersion advances |

### 2.4 Regression Tests — `RegressionTests`

| # | ID | Test | Bug Fixed |
|---|----|------|-----------|
| R-01 | REG-001 | `testMonthEndDoesNotBleedIntoNextMonth` | Off-by-one on month boundary |
| R-02 | REG-002 | `testYearCapDoesNotExceedToday` | "Till now" count included future |
| R-03 | REG-003 | `testSameDayDifferentTimesYieldSameISOKey` | Duplicate entries for same day |
| R-04 | REG-004 | `testIsoDateFormatterConcurrentAccess` | Race condition in shared formatter |
| R-05 | REG-005 | `testCSVDoubleQuoteEscaping` | Unescaped quotes broke CSV |
| R-06 | REG-006 | `testCSVCommaInNoteDoesNotSplitColumns` | Unquoted comma split rows |
| R-07 | REG-007 | `testCSVFilePathSanitizesSpecialChars` | `/` and `:` in name → invalid path |
| R-08 | REG-008 | `testColorHexRoundtripPreservesValue` | `Int(r*255)` truncation error |
| R-09 | REG-009 | `testUnknownRecurrenceRawValueReturnsNil` | Unknown recurrence crashed app |
| R-10 | REG-010 | `testExportDataVersionIsAlwaysTwo` | Accidental version bump on migration |
| R-11 | REG-011 | `testWeekRangeStartIsNeverInFuture` | Week start computed in next week |
| R-12 | REG-012 | `testLeapYearFebruaryHas29Days` | Leap year counted 28 days |
| R-13 | REG-013 | `testNonLeapYearFebruaryHas28Days` | Non-leap year edge case |

### 2.5 Volume / Performance Tests — `VolumeTests`

These use `measure {}` (10 iterations, baseline recorded). A 10× regression is a blocking failure.

| # | Test | Scale | Baseline Target |
|---|------|-------|----------------|
| V-01 | `testDateRangeMonthCreation1000Times` | 1 000 months | < 30 ms |
| V-02 | `testDateRangeYearCreation100Times` | 100 years | < 5 ms |
| V-03 | `testColorParsing1000HexStrings` | 1 000 hex strings | < 50 ms |
| V-04 | `testCSVExport365Entries` | 365 rows | < 20 ms |
| V-05 | `testCSVExport3650Entries` | 3 650 rows | < 100 ms |
| V-06 | `testExportDataEncodeFor100Trackers` | 100 trackers encode | < 10 ms |
| V-07 | `testExportDataDecodeFor100Trackers` | 100 trackers decode | < 10 ms |
| V-08 | `testDateRangeFiltering10000Entries` | 10 000 entries filtered | < 20 ms |
| V-09 | `testCompletedFilterFor10000Entries` | 10 000 filter(\.isCompleted) | < 20 ms |
| V-10 | `testIsoDateKeyGenerationFor5000Dates` | 5 000 ISO key lookups | < 50 ms |
| V-11 | `testCreate500TrackersFromExportData` | 500 tracker export+restore | < 30 ms |

### 2.6 UI Smoke Tests — `AppUITests`

| # | Test | What It Verifies |
|---|------|-----------------|
| UI-01 | `testAppLaunchesSuccessfully` | App reaches foreground |
| UI-02 | `testTabBarExists` | Tab bar is present |
| UI-03 | `testFourTabsExist` | Exactly 4 tabs |
| UI-04 | `testTodayTabExists` | "Today" tab label |
| UI-05 | `testCalendarTabExists` | "Calendar" tab label |
| UI-06 | `testSummaryTabExists` | "Summary" tab label |
| UI-07 | `testTrackersTabExists` | "Trackers" tab label |
| UI-08 | `testNavigateToCalendarTab` | Calendar shows nav bar |
| UI-09 | `testNavigateToSummaryTab` | "Summary" nav title appears |
| UI-10 | `testNavigateToTrackersTab` | "Trackers" nav title appears |
| UI-11 | `testNavigateBackToTodayTab` | App stays running after roundtrip |
| UI-12 | `testTodayTabIsSelected` | Today selected by default |
| UI-13 | `testTrackersTabShowsAddButton` | Add button in Trackers nav |
| UI-14 | `testAllTabBarButtonsAreEnabled` | No tab is greyed out |
| UI-15 | `testAllTabBarButtonsAreHittable` | All tabs respond to taps |
| UI-16 | `testSummaryTabShowsCorrectTitle` | REG: "Summary" title not broken |
| UI-17 | `testTrackersTabShowsCorrectTitle` | REG: "Trackers" title not broken |
| UI-18 | `testRapidTabSwitchingDoesNotCrash` | No crash on rapid navigation |

---

## 3. Manual Test Checklist

Run manually on a real device before every release. Check each box.

### 3.1 Permissions
- [ ] Fresh install: permission sheet appears
- [ ] Deny permission → PermissionView shown, app not crashed
- [ ] Grant permission → today view loads trackers

### 3.2 Tracker CRUD (Trackers Tab)
- [ ] Add tracker: name, icon, color, recurrence, time → appears in list
- [ ] Edit tracker: change all fields → changes reflected everywhere (Today, Calendar, Summary)
- [ ] Delete tracker: swipe-delete → removed from Reminders app too
- [ ] Pause/unpause tracker: paused trackers hidden from Today view
- [ ] Tracker with `/` or `:` in name → CSV export filename valid

### 3.3 Today Tab — Logging
- [ ] Tap checkbox → entry marked done, circle fills with tracker color
- [ ] Tap again → entry un-done
- [ ] Scroll date strip left → past 7 days accessible
- [ ] Log on a past date → entry appears in Calendar on that date
- [ ] Log in app → Reminders.app shows completed item within 5 s
- [ ] Mark done in Reminders.app → app reflects it within 5 s (two-way sync)
- [ ] Un-mark in Reminders.app → app reverts within 5 s

### 3.4 Calendar Tab
- [ ] Month grid shows correct days and first-day alignment
- [ ] Today cell has colored ring
- [ ] Future days are dimmed and untappable
- [ ] Tapping a past day toggles completion
- [ ] Navigating to previous month shows historical data
- [ ] Month stat shows `X/31` format
- [ ] Year stat shows all-time completions only up to today
- [ ] With multiple trackers → tracker picker menu appears
- [ ] Switching trackers updates grid and stats

### 3.5 Summary Tab
- [ ] All active trackers appear as cards
- [ ] Month stat shows `completed/total-days-in-month`
- [ ] All-time stat reflects total completions
- [ ] Progress bar moves as completions are logged

### 3.6 Two-Way Sync (Critical)
- [ ] App → Reminders: toggle → appears in Reminders within 5 s
- [ ] Reminders → App: complete in Reminders → App reflects within 5 s
- [ ] Change reminder time in Reminders.app → app reads new time on next load
- [ ] Delete scheduled reminder in Reminders.app → tracker shows no time

### 3.7 Scheduled Reminders
- [ ] Set reminder time → single reminder created in Reminders.app under tracker list
- [ ] Change time → old reminder removed, new one created (no duplicates)
- [ ] Remove time → reminder removed from Reminders.app
- [ ] Notification fires at correct time

### 3.8 Import / Export
- [ ] Export JSON → share sheet shows, file is valid JSON
- [ ] Import JSON → trackers restored with correct names, icons, colors
- [ ] Export CSV → correct header, rows sorted by date, notes escaped
- [ ] CSV filename is safe (no `/` or `:`)

### 3.9 iCloud Sync
- [ ] Log on device A → appears on device B within 30 s (Reminders iCloud sync)

### 3.10 Widget & Live Activity
- [ ] Home screen widget shows today's progress
- [ ] Logging in app updates widget within seconds
- [ ] Live Activity (if enabled) shows correct count on Lock Screen

---

## 4. Volume / Stress Tests (Manual)

Run once per major version on a physical device.

| Scenario | Steps | Pass Criteria |
|----------|-------|---------------|
| 10 trackers, 365 days each | Create 10 trackers, bulk-log 365 entries each | App launches < 2 s, Calendar scrolls at 60 fps |
| 50 trackers | Create 50 trackers | Today view renders < 1 s |
| 3 650 entries in one tracker | Log daily for 10 years (simulate via unit test) | CSV export < 5 s |
| Rapid toggling | Toggle same entry 100× quickly | No duplicate reminders, final state correct |
| Background/foreground cycling | Lock/unlock device 20× with app in background | No data loss, sync resumes |

---

## 5. Change-Specific Test Matrix

For each type of change, run the indicated tests at minimum.

| Change Area | Automated | Manual |
|-------------|-----------|--------|
| `Models.swift` | All unit + regression | Section 3.8 |
| `EventKitService.swift` | L-12→L-14 (with device) | Sections 3.2–3.7 |
| `LogStore.swift` | L-01→L-11 | Sections 3.3–3.6 |
| `TrackerStore.swift` | Unit tests | Sections 3.2, 3.6 |
| `DashboardView.swift` / `SummaryView.swift` | UI-08→UI-09, UI-16 | Sections 3.4, 3.5 |
| `TodayView.swift` | UI-01→UI-07, UI-12 | Section 3.3 |
| `CSVExporter.swift` | C-01→C-20 | Section 3.8 |
| `TrackerWidget.swift` | Build test | Section 3.10 |
| Any UI change | UI-01→UI-18 | Section 3.1 |
| Performance-critical path | V-01→V-11 | Section 4 |
| New bug fix | Add regression test + REG-XXX | Targeted section |

---

## 6. Definition of Done (for a PR)

- [ ] `xcodebuild test -scheme TrackerAppTests` → **TEST SUCCEEDED**, 0 failures
- [ ] `xcodebuild test -scheme TrackerAppUITests` → **TEST SUCCEEDED**, 0 failures
- [ ] No new Xcode warnings introduced
- [ ] For bug fixes: a new regression test added before the fix
- [ ] Manual checklist for affected areas completed on simulator
- [ ] Volume tests show no > 10× regression vs. baseline

---

## 7. Adding New Tests

When you find a bug:
1. Write a failing test in `RegressionTests.swift` with ID `REG-NNN`
2. Add a row to Section 2.4 of this document
3. Fix the bug
4. Verify the test now passes
5. Add the test to the change matrix in Section 5

When you add a feature:
1. Add unit tests to the relevant `*Tests.swift` file
2. Add a manual checklist row to Section 3
3. Update the change matrix in Section 5
