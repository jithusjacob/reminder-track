import XCTest
import SwiftUI
@testable import Reminder_Track

@MainActor
final class LogStoreCacheTests: XCTestCase {

    private var service: EventKitService!
    private var logStore: LogStore!

    override func setUp() async throws {
        try await super.setUp()
        service  = EventKitService()
        logStore = LogStore(service: service)
    }

    private func makeTracker(id: String = "t1") -> Tracker {
        Tracker(id: id, name: "Test", icon: "star",
                color: .indigo, reminderTime: nil,
                recurrence: .daily, isActive: true, createdAt: .now)
    }

    // MARK: - Initial State

    func testInitialCacheIsEmpty() {
        XCTAssertTrue(logStore.entriesByTracker.isEmpty)
    }

    func testIsLoadingFalseInitially() {
        XCTAssertFalse(logStore.isLoading)
    }

    func testErrorMessageNilInitially() {
        XCTAssertNil(logStore.errorMessage)
    }

    // MARK: - Query on Empty Cache

    func testEntryForUnknownTrackerReturnsNil() {
        XCTAssertNil(logStore.entry(for: makeTracker(), on: .now))
    }

    func testEntriesForUnknownTrackerReturnsEmpty() {
        let range = DateRange.month(containing: .now)
        XCTAssertTrue(logStore.entries(for: makeTracker(), in: range).isEmpty)
    }

    func testAllEntriesForUnknownTrackerReturnsEmpty() {
        XCTAssertTrue(logStore.allEntries(for: makeTracker()).isEmpty)
    }

    func testEntryForPastDateReturnsNil() {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        c.day! -= 30
        let past = Calendar.current.date(from: c)!
        XCTAssertNil(logStore.entry(for: makeTracker(), on: past))
    }

    // MARK: - Multi-Tracker Isolation

    func testEntriesForTwoUnknownTrackersAreBothEmpty() {
        let t1 = makeTracker(id: "tracker-a")
        let t2 = makeTracker(id: "tracker-b")
        XCTAssertNil(logStore.entry(for: t1, on: .now))
        XCTAssertNil(logStore.entry(for: t2, on: .now))
    }

    func testEntriesByTrackerKeysAreTrackerIds() {
        // With an empty store, the dictionary must be empty (not contain any spurious keys).
        XCTAssertEqual(logStore.entriesByTracker.keys.count, 0)
    }

    // MARK: - Date Range Filtering Edge Cases

    func testEntriesInFutureRangeReturnsEmpty() {
        let cal   = Calendar.current
        let start = cal.date(byAdding: .day, value: 30, to: .now)!
        let end   = cal.date(byAdding: .day, value: 60, to: .now)!
        let range = DateRange(start: start, end: end)
        XCTAssertTrue(logStore.entries(for: makeTracker(), in: range).isEmpty)
    }

    func testEntriesInPastRangeReturnsEmpty() {
        let cal   = Calendar.current
        let end   = cal.date(byAdding: .day, value: -30, to: .now)!
        let start = cal.date(byAdding: .day, value: -60, to: .now)!
        let range = DateRange(start: start, end: end)
        XCTAssertTrue(logStore.entries(for: makeTracker(), in: range).isEmpty)
    }

    // MARK: - EventKit-Gated Tests (skipped without permission)

    func testToggleRequiresPermission() async throws {
        guard service.isAuthorized else {
            throw XCTSkip("Reminders permission not granted")
        }
        let t = makeTracker()
        await logStore.toggle(tracker: t, date: .now)
        XCTAssertNotNil(logStore.entry(for: t, on: .now))
        XCTAssertTrue(logStore.entry(for: t, on: .now)?.isCompleted == true)
    }

    func testDoubleToggleResetsState() async throws {
        guard service.isAuthorized else {
            throw XCTSkip("Reminders permission not granted")
        }
        let t = makeTracker()
        await logStore.toggle(tracker: t, date: .now)
        await logStore.toggle(tracker: t, date: .now)
        XCTAssertFalse(logStore.entry(for: t, on: .now)?.isCompleted == true)
    }

    func testFetchAllWithUnknownIdReturnsEmpty() async throws {
        guard service.isAuthorized else {
            throw XCTSkip("Reminders permission not granted")
        }
        await logStore.fetchAll(trackerIds: ["definitely-does-not-exist"])
        XCTAssertFalse(logStore.isLoading)
    }
}
