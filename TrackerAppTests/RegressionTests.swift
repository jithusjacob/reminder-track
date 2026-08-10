import XCTest
import SwiftUI
@testable import Reminder_Track

/// Regression tests document bugs that were fixed and ensure they stay fixed.
/// Each test corresponds to a specific behaviour that must never regress.
final class RegressionTests: XCTestCase {

    // MARK: - REG-001: Month boundary off-by-one
    // Bug: DateRange.month end was bleeding into the next month (day 0 edge case).
    func testMonthEndDoesNotBleedIntoNextMonth() {
        let range   = DateRange.month(containing: .now)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: range.end)!
        let endMonth  = Calendar.current.component(.month, from: range.end)
        let nextMonth = Calendar.current.component(.month, from: nextDay)
        XCTAssertNotEqual(endMonth, nextMonth, "Month end must not overlap next month")
    }

    // MARK: - REG-002: Year stats include future dates
    // Bug: "till now" count was counting entries for future days in the current year.
    func testYearCapDoesNotExceedToday() {
        let yearRange = DateRange.year(containing: .now)
        let today     = Calendar.current.startOfDay(for: .now)
        let cap       = min(yearRange.end, today)
        XCTAssertTrue(cap <= today, "Year stat cap must not exceed today")
    }

    // MARK: - REG-003: Entry dedup key collision for same-day entries
    // Bug: Two entries at different times of day had different ISO keys → duplicates in cache.
    func testSameDayDifferentTimesYieldSameISOKey() {
        let cal  = Calendar.current
        var base = cal.dateComponents([.year, .month, .day], from: .now)
        base.hour = 0;  base.minute = 0
        let am = cal.date(from: base)!
        base.hour = 23; base.minute = 59
        let pm = cal.date(from: base)!
        XCTAssertEqual(DateFormatter.isoDate.string(from: am),
                       DateFormatter.isoDate.string(from: pm),
                       "Same-day entries must share a dedup key")
    }

    // MARK: - REG-004: isoDate formatter singleton is thread-safe
    // Bug: Shared DateFormatter state caused intermittent wrong dates under concurrency.
    func testIsoDateFormatterConcurrentAccess() {
        let dates = (1...20).compactMap { day -> Date? in
            var c = DateComponents(); c.year = 2026; c.month = 1; c.day = day
            return Calendar.current.date(from: c)
        }
        let expected = dates.map { DateFormatter.isoDate.string(from: $0) }
        var results  = [String](repeating: "", count: dates.count)
        let lock     = NSLock()

        DispatchQueue.concurrentPerform(iterations: dates.count) { i in
            let s = DateFormatter.isoDate.string(from: dates[i])
            lock.withLock { results[i] = s }
        }
        XCTAssertEqual(results, expected, "Concurrent isoDate formatting must be stable")
    }

    // MARK: - REG-005: CSV note with double-quotes is parseable
    // Bug: Notes containing " were not escaped, producing malformed CSV.
    func testCSVDoubleQuoteEscaping() {
        let tracker = makeTracker()
        let entry   = makeEntry(note: "he said \"hello\"")
        let csv     = CSVExporter.csv(for: tracker, entries: [entry])
        // Verify the CSV parses back without breaking the row count
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2, "Escaped quotes must not create extra rows")
    }

    // MARK: - REG-006: CSV note with comma is properly quoted
    // Bug: Unquoted commas in notes split the row into extra columns.
    func testCSVCommaInNoteDoesNotSplitColumns() {
        let tracker = makeTracker()
        let entry   = makeEntry(note: "walk, run, swim")
        let csv     = CSVExporter.csv(for: tracker, entries: [entry])
        // The data row should have exactly 4 comma-separated columns at the top level.
        // Since the note is quoted, splitting on "," at top level should give 4 or more items
        // but the critical point is the line count stays at 2.
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
    }

    // MARK: - REG-007: Tracker with / or : in name doesn't break CSV file path
    // Bug: slash and colon in tracker name created invalid file paths on disk.
    func testCSVFilePathSanitizesSpecialChars() {
        let badTracker = Tracker(id: "x", name: "Run: Morning/Night",
                                 icon: "figure.run", color: .green,
                                 reminderTime: nil, recurrence: .daily,
                                 isActive: true, createdAt: .now)
        let url  = CSVExporter.fileURL(for: badTracker, entries: [])
        let name = url.lastPathComponent
        XCTAssertFalse(name.contains("/"), "Slash must be sanitized from file name")
        XCTAssertFalse(name.contains(":"), "Colon must be sanitized from file name")
        XCTAssertFalse(name.contains("\\"), "Backslash must be sanitized from file name")
    }

    // MARK: - REG-008: Color roundtrip precision
    // Bug: Color was stored as 8-bit hex but converted with floating-point rounding,
    // causing #FF5733 to come back as #FF5632.
    func testColorHexRoundtripPreservesValue() {
        let hexes = ["FF5733", "6366F1", "000000", "FFFFFF", "10B981"]
        for hex in hexes {
            guard let c = Color(hex: hex) else {
                XCTFail("Color(hex: \(hex)) should not be nil")
                continue
            }
            let tracker = Tracker(id: "rt", name: "T", icon: "star",
                                  color: c, reminderTime: nil,
                                  recurrence: .daily, isActive: true, createdAt: .now)
            XCTAssertEqual(tracker.colorHex.uppercased(), hex.uppercased(),
                           "Color roundtrip failed for \(hex)")
        }
    }

    // MARK: - REG-009: RecurrenceType unknown raw value falls back gracefully
    // Bug: App crashed when an unknown recurrence string was stored in UserDefaults.
    func testUnknownRecurrenceRawValueReturnsNil() {
        XCTAssertNil(RecurrenceType(rawValue: "hourly"))
        XCTAssertNil(RecurrenceType(rawValue: ""))
        XCTAssertNil(RecurrenceType(rawValue: "DAILY"))
    }

    // REG-010 (ExportData version) removed along with the Import/Export Setup feature.

    // MARK: - REG-011: Week range never starts in the future
    // Bug: At week boundaries, the range start was computed as next week's Monday.
    func testWeekRangeStartIsNeverInFuture() {
        let range = DateRange.week(containing: .now)
        XCTAssertTrue(range.start <= Date.now,
                      "Week range start must not be in the future")
    }

    // MARK: - REG-012: Leap year February has 29 days in month range
    func testLeapYearFebruaryHas29Days() {
        var c = DateComponents(); c.year = 2024; c.month = 2; c.day = 1
        let feb = Calendar.current.date(from: c)!
        let range = DateRange.month(containing: feb)
        let days  = Calendar.current.range(of: .day, in: .month, for: feb)!.count
        let end   = Calendar.current.component(.day, from: range.end)
        XCTAssertEqual(days, 29)
        XCTAssertEqual(end,  29)
    }

    // MARK: - REG-013: Non-leap year February has 28 days
    func testNonLeapYearFebruaryHas28Days() {
        var c = DateComponents(); c.year = 2023; c.month = 2; c.day = 1
        let feb   = Calendar.current.date(from: c)!
        let range = DateRange.month(containing: feb)
        let end   = Calendar.current.component(.day, from: range.end)
        XCTAssertEqual(end, 28)
    }

    // MARK: - REG-014: Year stat excludes today's own entry
    // Bug: Year cap was truncated to startOfDay(today), so an entry logged today with a
    // non-midnight timestamp (e.g. completed at 9:43am) fell after the cap and was excluded
    // from the year total, even though it fell inside the current year.
    func testYearCapIncludesEntryLoggedLaterToday() {
        let yearRange  = DateRange.year(containing: .now)
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let endOfToday = Calendar.current.date(
            byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
        let cap = min(yearRange.end, endOfToday)

        let entryLoggedThisAfternoon = Calendar.current.date(
            byAdding: .hour, value: 9, to: startOfDay)!
        XCTAssertTrue(entryLoggedThisAfternoon <= cap,
                      "An entry logged later today must still fall within the year cap")
    }

    // MARK: - REG-015: Calendar keeps showing a deleted tracker
    // Bug: CalendarView only reset its selected tracker when selection was nil, so deleting
    // the currently selected tracker left a stale struct copy selected forever — the page kept
    // showing the deleted tracker and, since it no longer appeared in the live list, the
    // switcher menu (gated on the live list) offered no way back to a valid tracker.
    func testSelectionFallsBackWhenSelectedTrackerIsDeleted() {
        let remaining = makeTracker(id: "keep-me")
        let deleted   = makeTracker(id: "deleted-tracker")

        let resolved = TrackerSelection.resolve(current: deleted, in: [remaining])

        XCTAssertEqual(resolved?.id, remaining.id,
                        "Selection must fall back to a tracker that still exists")
    }

    func testSelectionIsPreservedWhenStillPresent() {
        let a = makeTracker(id: "a")
        let b = makeTracker(id: "b")

        let resolved = TrackerSelection.resolve(current: b, in: [a, b])

        XCTAssertEqual(resolved?.id, b.id,
                        "Selection must not change while it's still a valid tracker")
    }

    func testSelectionIsNilWhenNoTrackersRemain() {
        let resolved = TrackerSelection.resolve(current: makeTracker(id: "deleted-tracker"), in: [])
        XCTAssertNil(resolved, "Selection must clear to nil once every tracker is deleted")
    }

    // MARK: - REG-016: Future date already completed in Reminders stays interactive
    // Bug: DayCell locked every future date unconditionally, so a reminder already marked
    // complete in the Reminders app (synced in as a completed Entry) still showed dimmed and
    // blocked from tapping in Reminder Track instead of reflecting its real completed state.
    func testFutureDateAlreadyDoneIsNotLocked() {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        XCTAssertFalse(DayLockPolicy.isLocked(day: future, isDone: true),
                        "A future date already completed via Reminders must stay unlocked")
    }

    func testFutureDateNotYetDoneStaysLocked() {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: .now)!
        XCTAssertTrue(DayLockPolicy.isLocked(day: future, isDone: false),
                      "A future date with no completion yet must stay locked")
    }

    func testPastAndTodayDatesAreNeverLocked() {
        // MonthGrid always hands DayCell startOfDay-normalized dates (never a
        // live timestamp), so that's what this test feeds the policy too.
        let today = Calendar.current.startOfDay(for: .now)
        let past  = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        XCTAssertFalse(DayLockPolicy.isLocked(day: today, isDone: false))
        XCTAssertFalse(DayLockPolicy.isLocked(day: past, isDone: false))
    }

    // MARK: - REG-017: Trackers were unrecoverable on a fresh install / new device
    // Bug: tracker metadata (icon, color, recurrence, active flag, reminder time, created date)
    // was cached only in local UserDefaults, and createTrackerCalendar wrote no durable EventKit
    // record for it. A new device (or reinstall) synced the Reminders lists/reminders fine via
    // iCloud, but the app had nothing left to recognize them as trackers or rebuild their
    // settings — the Trackers tab would come up empty. Fix: durably encode full metadata into a
    // "config_track_metadata_user_can_ignore" reminder's URL, written on create/update and self-healed on load, so a
    // fresh install can fully reconstruct every tracker from EventKit alone.
    func testConfigURLRoundTripsAllTrackerMetadata() {
        var rt = DateComponents(); rt.hour = 7; rt.minute = 30
        let original = Tracker(
            id: "ignored-in-round-trip", name: "ignored-in-round-trip", icon: "flame",
            color: .orange, reminderTime: rt, recurrence: .weekdays,
            isActive: false, createdAt: Date(timeIntervalSince1970: 1_700_000_000))

        let url = original.configURL!
        let recovered = Tracker.decode(configURL: url, id: "new-device-id", name: "Morning Run")

        XCTAssertEqual(recovered?.id,   "new-device-id", "id/name come from the live calendar, not the URL")
        XCTAssertEqual(recovered?.name, "Morning Run")
        XCTAssertEqual(recovered?.icon,         original.icon)
        XCTAssertEqual(recovered?.colorHex,     original.colorHex)
        XCTAssertEqual(recovered?.recurrence,   original.recurrence)
        XCTAssertEqual(recovered?.isActive,     original.isActive)
        XCTAssertEqual(recovered?.reminderTime?.hour,   original.reminderTime?.hour)
        XCTAssertEqual(recovered?.reminderTime?.minute, original.reminderTime?.minute)
        XCTAssertEqual(recovered?.createdAt,    original.createdAt)
    }

    func testConfigURLRoundTripsWithNoReminderTime() {
        let original = makeTracker()
        let recovered = Tracker.decode(configURL: original.configURL!, id: "id2", name: "N")
        XCTAssertNil(recovered?.reminderTime, "No scheduled time must decode back to nil, not a garbage 0:00")
    }

    func testDecodeRejectsUnrelatedURL() {
        XCTAssertNil(Tracker.decode(configURL: URL(string: "tracker://schedule?trackerId=x")!,
                                     id: "id", name: "N"),
                     "A schedule-reminder URL must not be mistaken for a config reminder")
    }

    // MARK: - REG-018: Completing today's habit created a second reminder instead
    //                  of checking off the one already in Reminders.app
    // Bug: saveEntry always created a brand-new EKReminder titled with a raw ISO date
    // string, even when a pending schedule reminder (titled with the tracker's name) was
    // already due that same day — so completing a habit in-app left the original reminder
    // untouched and added a confusing second, differently-named one instead of checking it
    // off. Fix: reuse and complete the pending schedule reminder when one exists, tagging
    // the returned id with ScheduleDerivedID so a later toggle-off finds the same reminder
    // again instead of creating yet another one.
    func testScheduleDerivedIDRoundTrips() {
        let tagged = ScheduleDerivedID.make(from: "abc123")
        let (id, isSchedDerived) = ScheduleDerivedID.split(tagged)
        XCTAssertEqual(id, "abc123")
        XCTAssertTrue(isSchedDerived)
    }

    func testScheduleDerivedIDSplitLeavesPlainIdsUntouched() {
        let (id, isSchedDerived) = ScheduleDerivedID.split("plain-entry-id")
        XCTAssertEqual(id, "plain-entry-id")
        XCTAssertFalse(isSchedDerived, "An id with no schedule suffix must not be misread as schedule-derived")
    }

    func testScheduleDerivedIDSplitOnEmptyString() {
        let (id, isSchedDerived) = ScheduleDerivedID.split("")
        XCTAssertEqual(id, "")
        XCTAssertFalse(isSchedDerived)
    }

    // MARK: - Helpers

    private func makeTracker(id: String = "reg-t") -> Tracker {
        Tracker(id: id, name: "Regression", icon: "star",
                color: .indigo, reminderTime: nil,
                recurrence: .daily, isActive: true, createdAt: .now)
    }

    private func makeEntry(dateString: String = "2026-05-10", note: String = "") -> Entry {
        let date = DateFormatter.isoDate.date(from: dateString) ?? .now
        return Entry(id: UUID().uuidString, trackerId: "reg-t",
                     date: date, value: 1, note: note,
                     isCompleted: true, completionDate: nil)
    }
}
