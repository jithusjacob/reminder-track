import XCTest
import SwiftUI
@testable import Reminder_Track

final class VolumeTests: XCTestCase {

    // MARK: - DateRange Performance

    func testDateRangeMonthCreation1000Times() {
        let cal = Calendar.current
        measure {
            var date = Date.now
            for _ in 0..<1_000 {
                _ = DateRange.month(containing: date)
                date = cal.date(byAdding: .month, value: -1, to: date)!
            }
        }
    }

    func testDateRangeYearCreation100Times() {
        let cal = Calendar.current
        measure {
            var date = Date.now
            for _ in 0..<100 {
                _ = DateRange.year(containing: date)
                date = cal.date(byAdding: .year, value: -1, to: date)!
            }
        }
    }

    // MARK: - Color Parsing Performance

    func testColorParsing1000HexStrings() {
        let hexes = (0..<1_000).map { _ in String(format: "%06X", Int.random(in: 0..<0xFF_FFFF)) }
        measure {
            for hex in hexes { _ = Color(hex: hex) }
        }
    }

    // MARK: - CSV Export Performance

    func testCSVExport365Entries() {
        let tracker = makeTracker(id: "perf-365")
        let entries = makeEntries(count: 365)
        measure {
            _ = CSVExporter.csv(for: tracker, entries: entries)
        }
    }

    func testCSVExport3650Entries() {
        let tracker = makeTracker(id: "perf-3650")
        let entries = makeEntries(count: 3_650)
        measure {
            _ = CSVExporter.csv(for: tracker, entries: entries)
        }
    }

    // MARK: - TrackerExportData Performance

    func testExportDataEncodeFor100Trackers() {
        let trackers = (0..<100).map { makeTracker(id: "t\($0)", name: "Tracker \($0)") }
        let data     = TrackerExportData.from(trackers: trackers)
        measure {
            _ = try? JSONEncoder().encode(data)
        }
    }

    func testExportDataDecodeFor100Trackers() throws {
        let trackers = (0..<100).map { makeTracker(id: "t\($0)", name: "Tracker \($0)") }
        let encoded  = try JSONEncoder().encode(TrackerExportData.from(trackers: trackers))
        measure {
            _ = try? JSONDecoder().decode(TrackerExportData.self, from: encoded)
        }
    }

    // MARK: - In-Memory Filter Performance

    func testDateRangeFiltering10000Entries() {
        let range   = DateRange.month(containing: .now)
        let entries = makeEntries(count: 10_000)
        measure {
            _ = entries.filter { $0.date >= range.start && $0.date <= range.end }
        }
    }

    func testCompletedFilterFor10000Entries() {
        let entries = makeEntries(count: 10_000)
        measure {
            _ = entries.filter(\.isCompleted)
        }
    }

    func testIsoDateKeyGenerationFor5000Dates() {
        let dates = makeEntries(count: 5_000).map(\.date)
        measure {
            for date in dates { _ = DateFormatter.isoDate.string(from: date) }
        }
    }

    // MARK: - Tracker creation

    func testCreate500TrackersFromExportData() {
        let trackers = (0..<500).map { makeTracker(id: "t\($0)", name: "T\($0)") }
        measure {
            let export    = TrackerExportData.from(trackers: trackers)
            let restored  = export.toTrackers()
            _ = Set(restored.map(\.id))
        }
    }

    // MARK: - Helpers

    private func makeTracker(id: String = "perf-t", name: String = "Performance") -> Tracker {
        Tracker(id: id, name: name, icon: "bolt",
                color: .indigo, reminderTime: nil,
                recurrence: .daily, isActive: true, createdAt: .now)
    }

    private func makeEntries(count: Int) -> [Entry] {
        let cal  = Calendar.current
        var date = cal.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        return (0..<count).map { i in
            let e = Entry(id: "\(i)", trackerId: "perf-t",
                          date: date, value: 1, note: i % 5 == 0 ? "note \(i)" : "",
                          isCompleted: i % 3 != 0, completionDate: nil)
            date = cal.date(byAdding: .day, value: 1, to: date)!
            return e
        }
    }
}
