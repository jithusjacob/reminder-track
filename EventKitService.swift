import EventKit
import SwiftUI

// MARK: - EventKitService

@Observable
final class EventKitService {

    let store = EKEventStore()
    private(set) var isAuthorized = false

    // MARK: Reset (flush stale in-memory cache after EKEventStoreChanged)

    func reset() {
        store.reset()
    }

    // MARK: Permission

    var isAlreadyAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        }
        return EKEventStore.authorizationStatus(for: .reminder) == .authorized
    }

    var isDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        return status == .denied || status == .restricted
    }

    func requestPermission() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToReminders()
            } else {
                granted = try await store.requestAccess(to: .reminder)
            }
            isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    // MARK: Tracker Loading

    func fetchAllTrackers() async -> [Tracker] {
        let allCals = store.calendars(for: .reminder)

        // One-time cleanup: remove the _Tracker Meta_ calendar created by a prior version.
        cleanupLegacyMetaCalendar(from: allCals)

        // Migrate any old pipe-encoded calendar titles.
        await migrateOldCalendars(allCals)

        let calMap = Dictionary(uniqueKeysWithValues: allCals.map { ($0.calendarIdentifier, $0) })

        // Primary path: load from UserDefaults (no EventKit round-trip needed).
        var trackers = loadFromDefaults(calMap: calMap)

        // Recovery path: any tracker calendar with no local cache entry — a
        // fresh install on a new device, a reinstall, or a cleared cache —
        // gets rebuilt from its durable "config_track_metadata_user_can_ignore" reminder instead
        // of silently disappearing, even though the underlying calendar and
        // reminders synced fine via iCloud.
        let knownIds    = Set(trackers.map(\.id))
        let uncachedCals = allCals.filter { !knownIds.contains($0.calendarIdentifier) }
        if !uncachedCals.isEmpty {
            let pred      = store.predicateForReminders(in: uncachedCals)
            let reminders = await fetchReminders(pred)
            let recovered = reminders
                .filter { isConfigReminder($0) }
                .compactMap { Tracker.from(configReminder: $0) }
            for t in recovered { saveToDefaults(t) }
            trackers += recovered
        }

        // Sync scheduled-reminder times from Reminders.app so edits made there
        // (different time, or reminder deleted) are reflected in the app, and
        // backfill a config reminder for any tracker that predates this fix.
        await syncScheduledReminderTimes(for: &trackers)
        return trackers.sorted { $0.createdAt < $1.createdAt }
    }

    private func migrateOldCalendars(_ cals: [EKCalendar]) async {
        let oldCals = cals.filter { $0.title.hasPrefix("_tracker_|") }
        guard !oldCals.isEmpty else { return }
        for cal in oldCals {
            guard let tracker = Tracker.from(calendar: cal) else { continue }
            do {
                cal.title = tracker.name
                try store.saveCalendar(cal, commit: true)
                saveToDefaults(Tracker(
                    id: cal.calendarIdentifier, name: tracker.name,
                    icon: tracker.icon, color: tracker.color,
                    reminderTime: tracker.reminderTime,
                    recurrence: tracker.recurrence,
                    isActive: tracker.isActive, createdAt: tracker.createdAt))
            } catch {}
        }
    }

    // MARK: Tracker Calendars

    @discardableResult
    func createTrackerCalendar(for tracker: Tracker) throws -> String {
        let cal     = EKCalendar(for: .reminder, eventStore: store)
        cal.title   = tracker.name
        cal.cgColor = UIColor(tracker.color).cgColor
        cal.source  = preferredSource()
        try store.saveCalendar(cal, commit: true)

        // Fast path for this device: cache metadata in UserDefaults.
        let realTracker = Tracker(
            id: cal.calendarIdentifier, name: tracker.name,
            icon: tracker.icon, color: tracker.color,
            reminderTime: tracker.reminderTime,
            recurrence: tracker.recurrence,
            isActive: tracker.isActive, createdAt: tracker.createdAt)
        saveToDefaults(realTracker)

        // Durable copy in EventKit (syncs via iCloud) so a fresh install on a
        // new device — where this UserDefaults cache is empty — can rebuild
        // the tracker instead of losing it. See fetchAllTrackers's recovery path.
        try writeConfigReminder(for: realTracker, in: cal)
        return cal.calendarIdentifier
    }

    func updateTrackerCalendar(_ tracker: Tracker) async throws {
        guard let cal = store.calendar(withIdentifier: tracker.id) else { return }
        cal.title   = tracker.name
        cal.cgColor = UIColor(tracker.color).cgColor
        try store.saveCalendar(cal, commit: true)
        saveToDefaults(tracker)

        let existing = await fetchReminders(store.predicateForReminders(in: [cal]))
            .first(where: isConfigReminder)
        try writeConfigReminder(for: tracker, in: cal, existing: existing)
    }

    /// Writes (or updates) the hidden "config_track_metadata_user_can_ignore" marker reminder that
    /// durably encodes this tracker's full metadata in EventKit — the source
    /// of truth `fetchAllTrackers` recovers from when the local UserDefaults
    /// cache is empty (new device, reinstall, cache cleared).
    ///
    /// Marked completed so it stays out of the Reminders app's default list
    /// view (completed items are hidden there unless "Show Completed" is
    /// toggled) — it's pure metadata, never meant to be seen or acted on.
    private func writeConfigReminder(for tracker: Tracker, in cal: EKCalendar,
                                      existing: EKReminder? = nil) throws {
        let r        = existing ?? EKReminder(eventStore: store)
        r.calendar   = cal
        r.title      = Self.configReminderTitle
        r.url        = tracker.configURL
        r.isCompleted = true
        try store.save(r, commit: true)
    }

    func deleteTrackerCalendar(_ tracker: Tracker) async throws {
        removeFromDefaults(tracker.id)
        guard let cal = store.calendar(withIdentifier: tracker.id) else { return }
        try store.removeCalendar(cal, commit: true)
    }

    // MARK: Entries

    @discardableResult
    func saveEntry(_ entry: Entry) throws -> String {
        if !entry.id.isEmpty,
           let existing = store.calendarItem(withIdentifier: entry.id) as? EKReminder {
            apply(entry, to: existing)
            try store.save(existing, commit: true)
            return existing.calendarItemIdentifier
        }
        guard let cal = store.calendar(withIdentifier: entry.trackerId) else {
            throw TrackerError.calendarNotFound
        }
        let r      = EKReminder(eventStore: store)
        r.calendar = cal
        apply(entry, to: r)
        try store.save(r, commit: true)
        return r.calendarItemIdentifier
    }

    func deleteEntry(_ entry: Entry) throws {
        guard let r = store.calendarItem(withIdentifier: entry.id) as? EKReminder
        else { return }
        try store.remove(r, commit: true)
    }

    func fetchEntries(trackerIds: [String], in range: DateRange) async -> [Entry] {
        let cals = trackerIds.compactMap { store.calendar(withIdentifier: $0) }
        guard !cals.isEmpty else { return [] }
        return await fetchFiltered(calendars: cals, range: range)
    }

    func fetchAllEntries(trackerIds: [String]) async -> [Entry] {
        let cals = trackerIds.compactMap { store.calendar(withIdentifier: $0) }
        guard !cals.isEmpty else { return [] }
        return await fetchFiltered(calendars: cals, range: nil)
    }

    private func fetchFiltered(calendars: [EKCalendar], range: DateRange?) async -> [Entry] {
        // predicateForReminders(in:) can silently miss completed items on some iOS
        // versions, so we fetch incomplete and completed separately.
        let incompletePred = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: calendars)
        let completedPred  = store.predicateForCompletedReminders(
            withCompletionDateStarting: nil, ending: nil, calendars: calendars)

        async let incomplete = fetchReminders(incompletePred)
        async let completed  = fetchReminders(completedPred)
        let all = await incomplete + completed

        var entries = all.compactMap { Entry.from(reminder: $0) }
        if let r = range {
            entries = entries.filter { $0.date >= r.start && $0.date <= r.end }
        }
        // Prefer explicit "entry" reminders over schedule-derived ones for the same day.
        var seen = Set<String>()
        entries = entries
            .sorted { lhs, rhs in
                if lhs.trackerId == rhs.trackerId,
                   Calendar.current.isDate(lhs.date, inSameDayAs: rhs.date) {
                    return !lhs.id.hasSuffix("-sched") && rhs.id.hasSuffix("-sched")
                }
                return lhs.date < rhs.date
            }
            .filter { e in
                let key = e.trackerId + DateFormatter.isoDate.string(from: e.date)
                return seen.insert(key).inserted
            }
        return entries.sorted { $0.date < $1.date }
    }

    private func fetchReminders(_ predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { cont.resume(returning: $0 ?? []) }
        }
    }

    // MARK: Scheduled Reminders

    func scheduleReminder(for tracker: Tracker) throws {
        guard let cal  = store.calendar(withIdentifier: tracker.id),
              let time = tracker.reminderTime else { return }

        // Delete any previous scheduled reminders so edits don't accumulate duplicates.
        removeExistingScheduledReminders(in: cal)

        let r      = EKReminder(eventStore: store)
        r.calendar = cal
        r.title    = tracker.name
        r.url      = tracker.scheduleURL

        var due    = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        due.hour   = time.hour
        due.minute = time.minute
        due.second = 0
        r.dueDateComponents = due
        r.addAlarm(EKAlarm(relativeOffset: 0))

        if let rule = recurrenceRule(for: tracker.recurrence) {
            r.recurrenceRules = [rule]
        }
        try store.save(r, commit: true)
    }

    private func removeExistingScheduledReminders(in cal: EKCalendar) {
        let pred = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: [cal])
        store.fetchReminders(matching: pred) { [weak self] reminders in
            guard let self else { return }
            for r in reminders ?? [] where r.url?.scheme == "tracker" && r.url?.host == "schedule" {
                try? self.store.remove(r, commit: false)
            }
            try? self.store.commit()
        }
    }

    // MARK: UserDefaults persistence (via SharedTrackerDefaults — shared with widget & Watch)

    private func saveToDefaults(_ tracker: Tracker) {
        let meta = SharedTrackerDefaults.TrackerMeta(
            icon:           tracker.icon,
            colorHex:       tracker.colorHex,
            recurrence:     tracker.recurrence.rawValue,
            isActive:       tracker.isActive,
            createdAt:      tracker.createdAt.timeIntervalSince1970,
            reminderHour:   tracker.reminderTime?.hour,
            reminderMinute: tracker.reminderTime?.minute)
        SharedTrackerDefaults.save(meta, id: tracker.id)
    }

    private func removeFromDefaults(_ id: String) {
        SharedTrackerDefaults.remove(id: id)
    }

    private func loadFromDefaults(calMap: [String: EKCalendar]) -> [Tracker] {
        SharedTrackerDefaults.storedIds.compactMap { id in
            guard let cal  = calMap[id],
                  let meta = SharedTrackerDefaults.meta(for: id)
            else { return nil }
            var rt: DateComponents?
            if let h = meta.reminderHour, let m = meta.reminderMinute {
                rt = DateComponents(hour: h, minute: m)
            }
            return Tracker(
                id:           id,
                name:         cal.title,
                icon:         meta.icon,
                color:        Color(hex: meta.colorHex) ?? .indigo,
                reminderTime: rt,
                recurrence:   RecurrenceType(rawValue: meta.recurrence) ?? .daily,
                isActive:     meta.isActive,
                createdAt:    Date(timeIntervalSince1970: meta.createdAt))
        }
    }

    // MARK: Scheduled-reminder sync

    /// Batch-fetches all scheduled reminders and updates UserDefaults + in-memory trackers
    /// to reflect any time edits (or deletions) the user made in Reminders.app. Also backfills
    /// a durable "config_track_metadata_user_can_ignore" reminder for any tracker created before that existed, so
    /// trackers self-heal onto the recoverable path.
    private func syncScheduledReminderTimes(for trackers: inout [Tracker]) async {
        let cals = trackers.compactMap { store.calendar(withIdentifier: $0.id) }
        guard !cals.isEmpty else { return }

        let pred      = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: cals)
        let reminders = await fetchReminders(pred)

        // Build a map: calendarIdentifier → due DateComponents of the schedule reminder.
        var scheduleMap: [String: DateComponents] = [:]
        for r in reminders where r.url?.scheme == "tracker" && r.url?.host == "schedule" {
            guard let calId = r.calendar?.calendarIdentifier else { continue }
            scheduleMap[calId] = r.dueDateComponents
        }

        // Config reminders are marked completed (so they stay out of the Reminders
        // app's default list), so detecting them needs an all-statuses fetch —
        // predicateForIncompleteReminders above would never see them.
        let allReminders = await fetchReminders(store.predicateForReminders(in: cals))
        let hasConfigReminder = Set(
            allReminders.filter(isConfigReminder).compactMap { $0.calendar?.calendarIdentifier })

        for i in trackers.indices {
            let id        = trackers[i].id
            let ekDue     = scheduleMap[id]          // nil → no schedule reminder
            let stored    = trackers[i].reminderTime

            let ekHour    = ekDue?.hour
            let ekMinute  = ekDue?.minute

            if ekHour != stored?.hour || ekMinute != stored?.minute {
                trackers[i].reminderTime = ekDue.flatMap {
                    guard let h = $0.hour, let m = $0.minute else { return nil }
                    return DateComponents(hour: h, minute: m)
                }
                saveToDefaults(trackers[i])
            }

            if !hasConfigReminder.contains(id), let cal = store.calendar(withIdentifier: id) {
                try? writeConfigReminder(for: trackers[i], in: cal)
            }
        }
    }

    // MARK: Legacy cleanup

    private func cleanupLegacyMetaCalendar(from cals: [EKCalendar]) {
        guard let meta = cals.first(where: { $0.title == "_Tracker Meta_" }) else { return }
        // Migrate any config reminders stored there before deleting the calendar.
        let pred = store.predicateForReminders(in: [meta])
        store.fetchReminders(matching: pred) { [weak self] reminders in
            guard let self else { return }
            for r in reminders ?? [] where self.isConfigReminder(r) {
                guard let t = Tracker.from(configReminder: r) else { continue }
                self.saveToDefaults(t)
            }
            try? self.store.removeCalendar(meta, commit: true)
        }
    }

    // MARK: Helpers

    /// Title of the hidden metadata-carrier reminder — deliberately verbose/plain-English
    /// so it reads as obviously ignorable if a user ever spots it via "Show Completed".
    private static let configReminderTitle = "config_track_metadata_user_can_ignore"

    private func isConfigReminder(_ r: EKReminder) -> Bool {
        r.title == Self.configReminderTitle && r.url?.scheme == "tracker" && r.url?.host == "config"
    }

    private func apply(_ entry: Entry, to r: EKReminder) {
        r.title             = DateFormatter.isoDate.string(from: entry.date)
        r.notes             = entry.note.isEmpty ? nil : entry.note
        r.isCompleted       = entry.isCompleted
        r.url               = entry.metadataURL
        r.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: entry.date)
    }

    private func recurrenceRule(for type: RecurrenceType) -> EKRecurrenceRule? {
        switch type {
        case .daily:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .weekdays:
            let days: [EKRecurrenceDayOfWeek] = [
                .init(.monday), .init(.tuesday), .init(.wednesday),
                .init(.thursday), .init(.friday)
            ]
            return EKRecurrenceRule(
                recurrenceWith: .weekly, interval: 1,
                daysOfTheWeek: days, daysOfTheMonth: nil,
                monthsOfTheYear: nil, weeksOfTheYear: nil,
                daysOfTheYear: nil, setPositions: nil, end: nil)
        }
    }

    private func preferredSource() -> EKSource? {
        store.sources.first { $0.sourceType == .calDAV && $0.title == "iCloud" }
        ?? store.sources.first { $0.sourceType == .local }
        ?? store.defaultCalendarForNewReminders()?.source
    }
}

// MARK: - Errors

enum TrackerError: LocalizedError {
    case calendarNotFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .calendarNotFound: return "Tracker list not found in Reminders."
        case .permissionDenied: return "Allow Reminders access in Settings."
        }
    }
}
