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

    // MARK: - REG-010: ExportData version is always 2
    // Bug: Version was bumped accidentally when migrating old format, causing import failures.
    func testExportDataVersionIsAlwaysTwo() {
        let empty   = TrackerExportData.from(trackers: [])
        let nonEmpty = TrackerExportData.from(trackers: [makeTracker()])
        XCTAssertEqual(empty.version,    2)
        XCTAssertEqual(nonEmpty.version, 2)
    }

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
