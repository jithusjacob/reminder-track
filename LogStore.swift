import Foundation
import EventKit
import ActivityKit

// MARK: - LogStore

@MainActor
@Observable
final class LogStore {
    // Cache: trackerId → [dateString: Entry]
    private(set) var entriesByTracker: [String: [String: Entry]] = [:]
    private(set) var isLoading = false
    // Bumped after every save; lets views trigger live-activity sync via onChange.
    private(set) var logVersion = 0
    var errorMessage: String?

    private let service: EventKitService
    private var debounceTask: Task<Void, Never>?
    private var _liveActivity: Any?  // Activity<TrackerActivityAttributes> when available
    private var watchedTrackerIds: [String] = []

    init(service: EventKitService) {
        self.service = service
        observeChanges()
    }

    // MARK: - Query helpers

    func entry(for tracker: Tracker, on date: Date) -> Entry? {
        entriesByTracker[tracker.id]?[key(date)]
    }

    func entries(for tracker: Tracker, in range: DateRange) -> [Entry] {
        guard let byDate = entriesByTracker[tracker.id] else { return [] }
        return byDate.values.filter { $0.date >= range.start && $0.date <= range.end }
                            .sorted { $0.date < $1.date }
    }

    func allEntries(for tracker: Tracker) -> [Entry] {
        entriesByTracker[tracker.id].map { Array($0.values) } ?? []
    }

// MARK: - Fetch

    func fetchEntries(trackerIds: [String], range: DateRange) async {
        isLoading = true
        let fetched = await service.fetchEntries(trackerIds: trackerIds, in: range)
        mergeIntoCache(fetched)
        isLoading = false
    }

    func fetchAll(trackerIds: [String]) async {
        watchedTrackerIds = trackerIds
        isLoading = true
        let fetched = await service.fetchAllEntries(trackerIds: trackerIds)
        mergeIntoCache(fetched)
        isLoading = false
    }

    // MARK: - Log / Toggle

    func log(tracker: Tracker, date: Date, value: Double, note: String = "") async {
        let existing = entry(for: tracker, on: date)
        var entry = existing ?? Entry(
            id: "", trackerId: tracker.id,
            date: date, value: value,
            note: note, isCompleted: value > 0
        )
        entry.value       = value
        entry.note        = note
        entry.isCompleted = value > 0

        await save(entry: entry, tracker: tracker)
    }

    func toggle(tracker: Tracker, date: Date) async {
        let existing    = entry(for: tracker, on: date)
        let nowComplete = !(existing?.isCompleted ?? false)
        var entry = existing ?? Entry(
            id: "", trackerId: tracker.id,
            date: date, value: nowComplete ? 1 : 0,
            note: "", isCompleted: nowComplete
        )
        entry.isCompleted = nowComplete
        entry.value       = nowComplete ? 1 : 0

        await save(entry: entry, tracker: tracker)
    }

    func delete(entry: Entry) async {
        do {
            try service.deleteEntry(entry)
            entriesByTracker[entry.trackerId]?.removeValue(forKey: key(entry.date))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Live Activity

    func syncLiveActivity(trackers: [Tracker]) {
        guard #available(iOS 16.2, *),
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let today   = Calendar.current.startOfDay(for: .now)
        let active  = trackers.filter(\.isActive)
        let done    = active.filter { t in
            entry(for: t, on: today)?.isCompleted == true
        }

        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        let state = TrackerActivityAttributes.ContentState(
            completedCount: done.count,
            totalCount:     active.count,
            completedNames: done.map(\.name)
        )
        let content = ActivityContent(state: state, staleDate: midnight)

        if let activity = _liveActivity as? Activity<TrackerActivityAttributes> {
            Task { await activity.update(content) }
        } else {
            _liveActivity = try? Activity.request(
                attributes: TrackerActivityAttributes(),
                content:    content
            )
        }
    }

    func endLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = _liveActivity as? Activity<TrackerActivityAttributes> else { return }
        Task {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        _liveActivity = nil
    }

    // MARK: - Private

    private func save(entry: Entry, tracker: Tracker) async {
        do {
            let savedId = try service.saveEntry(entry)
            let updated = Entry(
                id: savedId, trackerId: entry.trackerId,
                date: entry.date, value: entry.value,
                note: entry.note, isCompleted: entry.isCompleted,
                completionDate: entry.completionDate
            )
            if entriesByTracker[tracker.id] == nil {
                entriesByTracker[tracker.id] = [:]
            }
            entriesByTracker[tracker.id]?[key(entry.date)] = updated
            logVersion += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mergeIntoCache(_ entries: [Entry]) {
        for entry in entries {
            if entriesByTracker[entry.trackerId] == nil {
                entriesByTracker[entry.trackerId] = [:]
            }
            entriesByTracker[entry.trackerId]?[key(entry.date)] = entry
        }
    }

    private func key(_ date: Date) -> String {
        DateFormatter.isoDate.string(from: date)
    }

    // MARK: - Live sync (EKEventStoreChanged → debounced re-fetch)

    private func observeChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object:  service.store,
            queue:   .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Flush stale in-memory EKObjects so the subsequent fetch reads
                // the current database state (required after external changes).
                self.service.reset()
                self.debounceTask?.cancel()
                self.debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    let ids = self.watchedTrackerIds
                    guard !ids.isEmpty else { return }
                    await self.fetchAll(trackerIds: ids)
                }
            }
        }
    }
}
