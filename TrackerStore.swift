import Foundation
import EventKit

// MARK: - TrackerStore

@MainActor
@Observable
final class TrackerStore {
    private(set) var trackers: [Tracker] = []
    private(set) var isLoading           = false
    var errorMessage: String?

    private let service: EventKitService

    init(service: EventKitService) {
        self.service = service
        observeChanges()
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        trackers  = await service.fetchAllTrackers()
        isLoading = false
    }

    // MARK: - CRUD

    @discardableResult
    func add(_ tracker: Tracker) async -> Tracker? {
        do {
            let calId = try service.createTrackerCalendar(for: tracker)
            await load()
            return trackers.first(where: { $0.id == calId })
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func update(_ tracker: Tracker) async {
        do {
            try await service.updateTrackerCalendar(tracker)
            if let idx = trackers.firstIndex(where: { $0.id == tracker.id }) {
                trackers[idx] = tracker
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ tracker: Tracker) async {
        do {
            try await service.deleteTrackerCalendar(tracker)
            trackers.removeAll { $0.id == tracker.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scheduleReminder(for tracker: Tracker) async {
        do {
            try service.scheduleReminder(for: tracker)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Live sync

    private func observeChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object:  service.store,
            queue:   .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.service.reset()
                await self.load()
            }
        }
    }
}
