import Foundation
import EventKit

// MARK: - Entry Cache Merge

/// Pure computation behind LogStore.replaceCache: given one tracker's current
/// cache, the freshly fetched entries for it, and (optionally) the date range
/// that fetch covered, returns what the cache should become — dropping any
/// cached entry no longer present upstream (e.g. a reminder deleted in
/// Reminders.app) instead of leaving it stranded the way a simple additive
/// merge would. Kept separate from LogStore/EventKit so it's unit-testable.
enum EntryCacheMerge {
    static func replacing(_ cache: [String: Entry], in range: DateRange?,
                           with entries: [Entry], keyedBy key: (Date) -> String) -> [String: Entry] {
        var result = cache
        if let range {
            for (dateKey, cached) in cache
            where cached.date >= range.start && cached.date <= range.end {
                result.removeValue(forKey: dateKey)
            }
        } else {
            result.removeAll()
        }
        for entry in entries {
            result[key(entry.date)] = entry
        }
        return result
    }
}

// MARK: - LogStore

@MainActor
@Observable
final class LogStore {
    // Cache: trackerId → [dateString: Entry]
    private(set) var entriesByTracker: [String: [String: Entry]] = [:]
    private(set) var isLoading = false
    var errorMessage: String?

    private let service: EventKitService
    private var debounceTask: Task<Void, Never>?
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
        replaceCache(for: trackerIds, in: range, with: fetched)
        isLoading = false
    }

    func fetchAll(trackerIds: [String]) async {
        watchedTrackerIds = trackerIds
        isLoading = true
        let fetched = await service.fetchAllEntries(trackerIds: trackerIds)
        replaceCache(for: trackerIds, with: fetched)
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

    // MARK: - Private

    private func save(entry: Entry, tracker: Tracker) async {
        do {
            let savedId = try await service.saveEntry(entry)
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Replaces cached entries for the given trackers (optionally scoped to a date
    /// range) with a freshly fetched snapshot, dropping anything no longer present
    /// upstream — e.g. a reminder that was deleted in Reminders.app. A plain additive
    /// merge alone only ever adds/updates keys, so a stale completed entry for a deleted
    /// reminder would otherwise never clear from the UI. When `range` is nil, the
    /// fetch is assumed to be a complete unbounded snapshot for those trackers (as
    /// fetchAllEntries always is), so their whole cache is cleared before merging.
    private func replaceCache(for trackerIds: [String], in range: DateRange? = nil,
                               with entries: [Entry]) {
        let byTracker = Dictionary(grouping: entries, by: \.trackerId)
        for id in trackerIds {
            entriesByTracker[id] = EntryCacheMerge.replacing(
                entriesByTracker[id] ?? [:], in: range,
                with: byTracker[id] ?? [], keyedBy: key)
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
