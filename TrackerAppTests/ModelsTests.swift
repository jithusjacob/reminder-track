import XCTest
import SwiftUI
@testable import Reminder_Track

final class ModelsTests: XCTestCase {

    // MARK: - Content Tab

    func testInitialTabIsTodayWhenTrackersExist() {
        XCTAssertEqual(ContentTab.initial(hasTrackers: true), .today)
    }

    func testInitialTabIsTrackersWhenNoneExist() {
        XCTAssertEqual(ContentTab.initial(hasTrackers: false), .trackers)
    }

    // MARK: - Summary Range Filter

    private var refDate: Date {
        var c = DateComponents(); c.year = 2026; c.month = 3; c.day = 15  // a Sunday
        return Calendar.current.date(from: c)!
    }

    func testWeekFilterMatchesDateRangeWeek() {
        let expected = DateRange.week(containing: refDate)
        let actual   = SummaryRangeFilter.week.range(trackerCreatedAt: .distantPast, referenceDate: refDate)
        XCTAssertEqual(actual.start, expected.start)
        XCTAssertEqual(actual.end,   expected.end)
    }

    func testMonthFilterMatchesDateRangeMonth() {
        let expected = DateRange.month(containing: refDate)
        let actual   = SummaryRangeFilter.month.range(trackerCreatedAt: .distantPast, referenceDate: refDate)
        XCTAssertEqual(actual.start, expected.start)
        XCTAssertEqual(actual.end,   expected.end)
    }

    func testYearFilterMatchesDateRangeYear() {
        let expected = DateRange.year(containing: refDate)
        let actual   = SummaryRangeFilter.year.range(trackerCreatedAt: .distantPast, referenceDate: refDate)
        XCTAssertEqual(actual.start, expected.start)
        XCTAssertEqual(actual.end,   expected.end)
    }

    func testAllTimeFilterSpansFromCreationToReferenceDate() {
        var c = DateComponents(); c.year = 2025; c.month = 6; c.day = 1
        let createdAt = Calendar.current.date(from: c)!

        let range = SummaryRangeFilter.allTime.range(trackerCreatedAt: createdAt, referenceDate: refDate)

        XCTAssertEqual(range.start, Calendar.current.startOfDay(for: createdAt))
        XCTAssertEqual(range.end,   refDate)
    }

    // MARK: - Color Hex Parsing

    func testColorFromValidLowercaseHex() {
        XCTAssertNotNil(Color(hex: "ff0000"))
    }

    func testColorFromValidUppercaseHex() {
        XCTAssertNotNil(Color(hex: "FF5733"))
    }

    func testColorFromHexWithLeadingHash() {
        XCTAssertNotNil(Color(hex: "#6366f1"))
    }

    func testColorFromEmptyStringReturnsNil() {
        XCTAssertNil(Color(hex: ""))
    }

    func testColorFromInvalidCharsReturnsNil() {
        XCTAssertNil(Color(hex: "ZZZZZZ"))
    }

    func testColorFromWhitespaceReturnsNil() {
        XCTAssertNil(Color(hex: "      "))
    }

    func testColorRoundtripThroughHex() {
        // Encode → decode should yield a non-nil color.
        let tracker = Tracker(id: "t", name: "T", icon: "star",
                              color: Color(hex: "FF5733")!,
                              reminderTime: nil, recurrence: .daily,
                              isActive: true, createdAt: .now)
        let hex = tracker.colorHex
        XCTAssertEqual(hex.count, 6)
        XCTAssertNotNil(Color(hex: hex))
    }

    // MARK: - DateRange.week

    func testWeekRangeSpansSixDays() {
        let range = DateRange.week(containing: .now)
        let days  = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day!
        XCTAssertEqual(days, 6)
    }

    func testWeekRangeStartDoesNotExceedToday() {
        XCTAssertTrue(DateRange.week(containing: .now).start <= Date.now)
    }

    func testWeekRangeContainsToday() {
        let r = DateRange.week(containing: .now)
        XCTAssertTrue(Date.now >= r.start && Date.now <= r.end)
    }

    func testWeekRangeStartIsStartOfWeek() {
        let range   = DateRange.week(containing: .now)
        let weekday = Calendar.current.component(.weekday, from: range.start)
        XCTAssertEqual(weekday, Calendar.current.firstWeekday)
    }

    // MARK: - DateRange.month

    func testMonthRangeStartIsFirstDay() {
        let range = DateRange.month(containing: .now)
        XCTAssertEqual(Calendar.current.component(.day, from: range.start), 1)
    }

    func testMonthRangeEndIsLastDay() {
        let range       = DateRange.month(containing: .now)
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: .now)!.count
        XCTAssertEqual(Calendar.current.component(.day, from: range.end), daysInMonth)
    }

    func testMonthRangeContainsToday() {
        let r = DateRange.month(containing: .now)
        XCTAssertTrue(Date.now >= r.start && Date.now <= r.end)
    }

    func testMonthRangeLeapYearFebruary() {
        var c = DateComponents(); c.year = 2024; c.month = 2; c.day = 15
        let feb = Calendar.current.date(from: c)!
        let range = DateRange.month(containing: feb)
        let endDay = Calendar.current.component(.day, from: range.end)
        XCTAssertEqual(endDay, 29)
    }

    func testMonthRangeNonLeapYearFebruary() {
        var c = DateComponents(); c.year = 2023; c.month = 2; c.day = 10
        let feb = Calendar.current.date(from: c)!
        let range = DateRange.month(containing: feb)
        let endDay = Calendar.current.component(.day, from: range.end)
        XCTAssertEqual(endDay, 28)
    }

    func testMonthRangeEndDoesNotOverlapNextMonth() {
        let range   = DateRange.month(containing: .now)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: range.end)!
        XCTAssertNotEqual(Calendar.current.component(.month, from: range.end),
                          Calendar.current.component(.month, from: nextDay))
    }

    // MARK: - DateRange.year

    func testYearRangeStartIsJanFirst() {
        let r = DateRange.year(containing: .now)
        XCTAssertEqual(Calendar.current.component(.month, from: r.start), 1)
        XCTAssertEqual(Calendar.current.component(.day,   from: r.start), 1)
    }

    func testYearRangeEndIsDecThirtyFirst() {
        let r = DateRange.year(containing: .now)
        XCTAssertEqual(Calendar.current.component(.month, from: r.end), 12)
        XCTAssertEqual(Calendar.current.component(.day,   from: r.end), 31)
    }

    func testYearRangeContainsToday() {
        let r = DateRange.year(containing: .now)
        XCTAssertTrue(Date.now >= r.start && Date.now <= r.end)
    }

    // MARK: - RecurrenceType

    func testRecurrenceTypeRawValues() {
        XCTAssertEqual(RecurrenceType.daily.rawValue,    "daily")
        XCTAssertEqual(RecurrenceType.weekdays.rawValue, "weekdays")
        XCTAssertEqual(RecurrenceType.weekly.rawValue,   "weekly")
    }

    func testRecurrenceTypeAllCasesCount() {
        XCTAssertEqual(RecurrenceType.allCases.count, 3)
    }

    func testRecurrenceTypeFromUnknownRawValueReturnsNil() {
        XCTAssertNil(RecurrenceType(rawValue: "hourly"))
    }

    func testRecurrenceTypeCodableRoundtrip() throws {
        for type in RecurrenceType.allCases {
            let encoded = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(RecurrenceType.self, from: encoded)
            XCTAssertEqual(type, decoded)
        }
    }

    // MARK: - ISO Date Formatter

    func testIsoDateFormatterFormat() {
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 12
        let date = Calendar.current.date(from: c)!
        XCTAssertEqual(DateFormatter.isoDate.string(from: date), "2026-05-12")
    }

    func testIsoDateFormatterZeroPadsMonth() {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 3
        let date = Calendar.current.date(from: c)!
        let s = DateFormatter.isoDate.string(from: date)
        XCTAssertEqual(s, "2026-01-03")
    }

    func testIsoDateFormatterParseRoundtrip() {
        let original = DateFormatter.isoDate.string(from: .now)
        let parsed   = DateFormatter.isoDate.date(from: original)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(DateFormatter.isoDate.string(from: parsed!), original)
    }

    func testIsoDateFormatterKeySameForSameDayDifferentTimes() {
        let cal  = Calendar.current
        var base = cal.dateComponents([.year, .month, .day], from: .now)
        base.hour = 0;  base.minute = 0
        let midnight = cal.date(from: base)!
        base.hour = 23; base.minute = 59
        let endOfDay = cal.date(from: base)!
        XCTAssertEqual(DateFormatter.isoDate.string(from: midnight),
                       DateFormatter.isoDate.string(from: endOfDay))
    }

    // MARK: - Tracker URLs

    func testScheduleURLSchemeAndHost() {
        let t = Tracker(id: "myId", name: "T", icon: "star",
                        color: .indigo, reminderTime: nil,
                        recurrence: .daily, isActive: true, createdAt: .now)
        XCTAssertEqual(t.scheduleURL?.scheme, "tracker")
        XCTAssertEqual(t.scheduleURL?.host,   "schedule")
    }

    func testScheduleURLContainsTrackerId() {
        let t = Tracker(id: "xyz42", name: "T", icon: "star",
                        color: .indigo, reminderTime: nil,
                        recurrence: .daily, isActive: true, createdAt: .now)
        XCTAssertTrue(t.scheduleURL!.absoluteString.contains("trackerId=xyz42"))
    }

    func testConfigURLSchemeAndHost() {
        let t = Tracker(id: "cfg", name: "T", icon: "star",
                        color: .indigo, reminderTime: nil,
                        recurrence: .daily, isActive: true, createdAt: .now)
        XCTAssertEqual(t.configURL?.scheme, "tracker")
        XCTAssertEqual(t.configURL?.host,   "config")
    }
}
