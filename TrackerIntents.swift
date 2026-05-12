import AppIntents
import EventKit

// MARK: - Log Habit Intent
// "Hey Siri, log Morning Run in Reminder Track"

struct LogHabitIntent: AppIntent {

    static var title: LocalizedStringResource = "Log a Habit"
    static var description = IntentDescription(
        "Mark a habit as done for today in Reminder Track.")
    static var openAppWhenRun = false

    @Parameter(title: "Tracker Name")
    var trackerName: String

    func perform() async throws -> some ReturnsValue<String> {
        let service = EventKitService()
        guard await service.requestPermission() else {
            throw TrackerError.permissionDenied
        }

        let trackers = await service.fetchAllTrackers()
        guard let tracker = trackers.first(where: {
            $0.name.localizedCaseInsensitiveContains(trackerName)
        }) else {
            throw IntentError.trackerNotFound(trackerName)
        }

        let entry = Entry(
            id:          "",
            trackerId:   tracker.id,
            date:        Calendar.current.startOfDay(for: .now),
            value:       1,
            note:        "Logged via Siri",
            isCompleted: true
        )
        try service.saveEntry(entry)

        return .result(value: "✅ \(tracker.name) logged for today!")
    }
}

// MARK: - Check Habit Intent
// "Hey Siri, did I complete Morning Run today?"

struct CheckHabitIntent: AppIntent {

    static var title: LocalizedStringResource = "Check a Habit"
    static var description = IntentDescription(
        "Check whether a habit was completed today.")
    static var openAppWhenRun = false

    @Parameter(title: "Tracker Name") var trackerName: String

    func perform() async throws -> some ReturnsValue<String> {
        let service = EventKitService()
        guard await service.requestPermission() else {
            throw TrackerError.permissionDenied
        }

        let trackers = await service.fetchAllTrackers()
        guard let tracker = trackers.first(where: {
            $0.name.localizedCaseInsensitiveContains(trackerName)
        }) else {
            throw IntentError.trackerNotFound(trackerName)
        }

        let today   = Calendar.current.startOfDay(for: .now)
        let range   = DateRange(start: today, end: today.addingTimeInterval(86399))
        let entries = await service.fetchEntries(trackerIds: [tracker.id], in: range)

        if let e = entries.first {
            return .result(value: e.isCompleted
                ? "✅ Yes, you completed \(tracker.name) today."
                : "❌ Not yet done for \(tracker.name) today.")
        } else {
            return .result(value: "Nothing logged yet for \(tracker.name) today.")
        }
    }
}

// MARK: - Errors

enum IntentError: LocalizedError {
    case trackerNotFound(String)
    var errorDescription: String? {
        switch self {
        case .trackerNotFound(let n): return "No tracker found matching '\(n)'."
        }
    }
}
