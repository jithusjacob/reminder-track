import SwiftUI
import EventKit
import WatchKit

// MARK: - Watch App Entry

@main
struct TrackerWatchApp: App {
    @State private var store = WatchTrackerStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(store)
                .task { await store.load() }
        }
    }
}

// MARK: - Watch Store

@Observable
final class WatchTrackerStore {
    var trackers: [Tracker]                     = []
    var todayEntries: [String: Entry]           = [:]   // trackerId → Entry
    var isLoading = false

    private let eventStore = EKEventStore()

    func load() async {
        isLoading = true
        // Request permission
        let granted: Bool
        if #available(watchOS 10.0, *) {
            granted = (try? await eventStore.requestFullAccessToReminders()) ?? false
        } else {
            granted = (try? await eventStore.requestAccess(to: .reminder)) ?? false
        }
        guard granted else { isLoading = false; return }

        // One fetch covers both config reminders (tracker identity) and entry reminders.
        let allCals = eventStore.calendars(for: .reminder)
        guard !allCals.isEmpty else { isLoading = false; return }
        let pred = eventStore.predicateForReminders(in: allCals)

        let allReminders: [EKReminder] = await withCheckedContinuation { cont in
            eventStore.fetchReminders(matching: pred) { cont.resume(returning: $0 ?? []) }
        }

        var seen = Set<String>()
        trackers = allReminders
            .filter { $0.title == "_tracker_config_"
                   && $0.url?.scheme == "tracker"
                   && $0.url?.host  == "config" }
            .compactMap { Tracker.from(configReminder: $0) }
            .filter { seen.insert($0.id).inserted }
            .filter(\.isActive)

        // Load today's entries
        let today = Calendar.current.startOfDay(for: .now)
        let end   = today.addingTimeInterval(86399)

        for r in allReminders {
            if let entry = Entry.from(reminder: r),
               entry.date >= today, entry.date <= end {
                todayEntries[entry.trackerId] = entry
            }
        }
        isLoading = false
    }

    func toggle(tracker: Tracker) async {
        let existing    = todayEntries[tracker.id]
        let nowDone     = !(existing?.isCompleted ?? false)
        let today       = Calendar.current.startOfDay(for: .now)
        let entry = Entry(
            id:          existing?.id ?? "",
            trackerId:   tracker.id,
            date:        today,
            value:       nowDone ? 1 : 0,
            note:        "",
            isCompleted: nowDone
        )
        do {
            guard let cal = eventStore.calendar(withIdentifier: tracker.id) else { return }
            let reminder      = EKReminder(eventStore: eventStore)
            reminder.calendar = cal
            reminder.title           = DateFormatter.isoDate.string(from: today)
            reminder.notes           = nil
            reminder.isCompleted     = nowDone
            reminder.url             = entry.metadataURL
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day], from: today)
            try eventStore.save(reminder, commit: true)
            todayEntries[tracker.id] = Entry(
                id:          reminder.calendarItemIdentifier,
                trackerId:   tracker.id,
                date:        today,
                value:       nowDone ? 1 : 0,
                note:        "",
                isCompleted: nowDone)
            // Haptic feedback
            WKInterfaceDevice.current().play(.success)
        } catch {
            WKInterfaceDevice.current().play(.failure)
        }
    }
}

// MARK: - Watch Content View

struct WatchContentView: View {
    @Environment(WatchTrackerStore.self) var store

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView()
                } else if store.trackers.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Add trackers in the iPhone app")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List(store.trackers) { tracker in
                        WatchTrackerRow(tracker: tracker)
                    }
                }
            }
            .navigationTitle("Today")
        }
    }
}

// MARK: - Watch Tracker Row

struct WatchTrackerRow: View {
    let tracker: Tracker
    @Environment(WatchTrackerStore.self) var store

    private var entry: Entry?   { store.todayEntries[tracker.id] }
    private var isDone: Bool    { entry?.isCompleted ?? false }

    var body: some View {
        Button {
            Task { await store.toggle(tracker: tracker) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tracker.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(tracker.color)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tracker.name)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                    Text(isDone ? "Done ✓" : "Tap to log")
                        .font(.caption2)
                        .foregroundStyle(isDone ? tracker.color : .secondary)
                }

                Spacer()

                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isDone ? tracker.color : Color(.lightGray))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isDone ? tracker.color.opacity(0.1) : Color.clear
        )
    }
}

// MARK: - Watch Complication (watchOS 9+)

import ClockKit

// For watchOS 9 and earlier, use ComplicationController.
// For watchOS 10+, use WidgetKit with .accessoryCircular family (same as Lock Screen widget).
// The WidgetKit widget defined in TrackerWidget.swift already supports .accessoryCircular
// and will appear as a complication on watchOS 10+. No additional code needed.
