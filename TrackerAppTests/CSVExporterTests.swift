import XCTest
import SwiftUI
@testable import Reminder_Track

final class CSVExporterTests: XCTestCase {

    private let tracker = Tracker(
        id: "t1", name: "Test Tracker", icon: "star",
        color: .indigo, reminderTime: nil,
        recurrence: .daily, isActive: true, createdAt: .now
    )

    private func entry(_ dateString: String,
                       value: Double = 1,
                       completed: Bool = true,
                       note: String = "") -> Entry {
        let date = DateFormatter.isoDate.date(from: dateString)!
        return Entry(id: UUID().uuidString, trackerId: "t1",
                     date: date, value: value, note: note,
                     isCompleted: completed, completionDate: nil)
    }

    // MARK: - Header

    func testEmptyEntriesProducesHeaderOnly() {
        XCTAssertEqual(CSVExporter.csv(for: tracker, entries: []), "Date,Value,Completed,Note")
    }

    func testHeaderContainsExpectedColumns() {
        let csv = CSVExporter.csv(for: tracker, entries: [])
        XCTAssertTrue(csv.hasPrefix("Date,Value,Completed,Note"))
    }

    // MARK: - Single Entry

    func testSingleEntryProducesTwoLines() {
        let lines = CSVExporter.csv(for: tracker, entries: [entry("2026-05-10")])
            .components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
    }

    func testSingleEntryDateColumn() {
        let csv = CSVExporter.csv(for: tracker, entries: [entry("2026-05-01")])
        XCTAssertTrue(csv.contains("2026-05-01"))
    }

    func testCompletedEntryShowsTrue() {
        XCTAssertTrue(CSVExporter.csv(for: tracker,
                                     entries: [entry("2026-05-01", completed: true)])
            .contains("true"))
    }

    func testIncompleteEntryShowsFalse() {
        XCTAssertTrue(CSVExporter.csv(for: tracker,
                                     entries: [entry("2026-05-01", completed: false)])
            .contains("false"))
    }

    func testValueIsPreserved() {
        XCTAssertTrue(CSVExporter.csv(for: tracker,
                                     entries: [entry("2026-05-01", value: 7.5)])
            .contains("7.5"))
    }

    // MARK: - Sorting

    func testEntriesSortedByDateAscending() {
        let entries = [
            entry("2026-05-03"),
            entry("2026-05-01"),
            entry("2026-05-02")
        ]
        let lines = CSVExporter.csv(for: tracker, entries: entries)
            .components(separatedBy: "\n")
        XCTAssertTrue(lines[1].hasPrefix("2026-05-01"))
        XCTAssertTrue(lines[2].hasPrefix("2026-05-02"))
        XCTAssertTrue(lines[3].hasPrefix("2026-05-03"))
    }

    func testSingletonEntryInCorrectPosition() {
        let lines = CSVExporter.csv(for: tracker, entries: [entry("2026-01-15")])
            .components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].hasPrefix("2026-01-15"))
    }

    // MARK: - Note escaping

    func testNoteWithCommaIsQuoted() {
        let csv = CSVExporter.csv(for: tracker, entries: [entry("2026-05-01", note: "good, great")])
        XCTAssertTrue(csv.contains("\"good, great\""))
    }

    func testNoteWithDoubleQuoteIsEscaped() {
        let csv = CSVExporter.csv(for: tracker, entries: [entry("2026-05-01", note: "he said \"hi\"")])
        XCTAssertTrue(csv.contains("\"\""))
    }

    func testNoteWithSemicolonPassesThrough() {
        let csv = CSVExporter.csv(for: tracker, entries: [entry("2026-05-01", note: "a;b;c")])
        XCTAssertTrue(csv.contains("a;b;c"))
    }

    func testEmptyNoteProducesEmptyQuotes() {
        let csv = CSVExporter.csv(for: tracker, entries: [entry("2026-05-01", note: "")])
        XCTAssertTrue(csv.contains("\"\""))
    }

    func testNoteWithUnicodePreserved() {
        let csv = CSVExporter.csv(for: tracker, entries: [entry("2026-05-01", note: "🏃‍♂️ run")])
        XCTAssertTrue(csv.contains("🏃‍♂️ run"))
    }

    // MARK: - File URL

    func testFileURLCreatesFile() {
        let url = CSVExporter.fileURL(for: tracker, entries: [entry("2026-05-01")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testFileURLExtensionIsCSV() {
        let url = CSVExporter.fileURL(for: tracker, entries: [])
        XCTAssertEqual(url.pathExtension, "csv")
    }

    func testFileURLContainsTrackerName() {
        let url = CSVExporter.fileURL(for: tracker, entries: [])
        XCTAssertTrue(url.lastPathComponent.contains("Test Tracker"))
    }

    func testFileURLSanitizesForwardSlash() {
        let slashTracker = Tracker(id: "s", name: "Morning/Evening", icon: "star",
                                   color: .red, reminderTime: nil,
                                   recurrence: .daily, isActive: true, createdAt: .now)
        let url = CSVExporter.fileURL(for: slashTracker, entries: [])
        XCTAssertFalse(url.lastPathComponent.contains("/"))
    }

    func testFileURLSanitizesColon() {
        let colonTracker = Tracker(id: "c", name: "Run: Sprint", icon: "star",
                                   color: .blue, reminderTime: nil,
                                   recurrence: .daily, isActive: true, createdAt: .now)
        let url = CSVExporter.fileURL(for: colonTracker, entries: [])
        XCTAssertFalse(url.lastPathComponent.contains(":"))
    }

    func testFileURLContainsDate() {
        let url = CSVExporter.fileURL(for: tracker, entries: [])
        let today = DateFormatter.isoDate.string(from: .now)
        XCTAssertTrue(url.lastPathComponent.contains(today))
    }

    func testFileContentsMatchCSVOutput() throws {
        let entries = [entry("2026-05-10"), entry("2026-05-11")]
        let expectedCSV = CSVExporter.csv(for: tracker, entries: entries)
        let url = CSVExporter.fileURL(for: tracker, entries: entries)
        let fileContents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(fileContents, expectedCSV)
    }
}
