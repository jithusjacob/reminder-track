import WidgetKit
import SwiftUI
import EventKit

private typealias HabitEntry = Entry

// MARK: - Widget Entry

struct TrackerWidgetEntry: TimelineEntry {
    let date: Date
    let trackers: [TrackerSummary]
}

struct TrackerSummary: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let isDoneToday: Bool
    let streak: Int
}

// MARK: - Provider

struct TrackerWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> TrackerWidgetEntry {
        TrackerWidgetEntry(date: .now, trackers: [
            TrackerSummary(id: "1", name: "Morning Run", icon: "figure.run",
                           color: .green, isDoneToday: true, streak: 7),
            TrackerSummary(id: "2", name: "Read", icon: "book.fill",
                           color: .indigo, isDoneToday: false, streak: 3),
        ])
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (TrackerWidgetEntry) -> Void) {
        Task {
            let entry = await buildEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<TrackerWidgetEntry>) -> Void) {
        Task {
            let entry = await buildEntry()
            let midnight = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
            let timeline = Timeline(entries: [entry], policy: .after(midnight))
            completion(timeline)
        }
    }

    // MARK: Build

    private func buildEntry() async -> TrackerWidgetEntry {
        // Widget extensions can't present the system permission alert, so only
        // read from EventKit if the host app has already been granted access —
        // never call requestAccess/requestFullAccessToReminders from here.
        let authorized: Bool
        if #available(iOS 17.0, *) {
            authorized = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        } else {
            authorized = EKEventStore.authorizationStatus(for: .reminder) == .authorized
        }
        guard authorized else {
            return TrackerWidgetEntry(date: .now, trackers: [])
        }
        let store = EKEventStore()

        // Read tracker IDs and metadata from the shared App Group UserDefaults.
        let ids = SharedTrackerDefaults.storedIds
        guard !ids.isEmpty else {
            return TrackerWidgetEntry(date: .now, trackers: [])
        }

        let today = Calendar.current.startOfDay(for: .now)
        let end   = today.addingTimeInterval(86399)

        // Fetch today's entries for all tracker calendars in one pass.
        let cals = ids.compactMap { store.calendar(withIdentifier: $0) }
        let allEntries: [HabitEntry]
        if cals.isEmpty {
            allEntries = []
        } else {
            let incompletePred = store.predicateForIncompleteReminders(
                withDueDateStarting: today, ending: end, calendars: cals)
            let completedPred  = store.predicateForCompletedReminders(
                withCompletionDateStarting: today, ending: end, calendars: cals)
            let incomplete: [EKReminder] = await withCheckedContinuation { cont in
                store.fetchReminders(matching: incompletePred) { cont.resume(returning: $0 ?? []) }
            }
            let completed: [EKReminder] = await withCheckedContinuation { cont in
                store.fetchReminders(matching: completedPred) { cont.resume(returning: $0 ?? []) }
            }
            allEntries = (incomplete + completed).compactMap { HabitEntry.from(reminder: $0) }
        }

        let summaries: [TrackerSummary] = ids.prefix(4).compactMap { id in
            guard let meta = SharedTrackerDefaults.meta(for: id),
                  meta.isActive,
                  let cal = store.calendar(withIdentifier: id)
            else { return nil }

            let isDone = allEntries.contains {
                $0.trackerId == id && $0.isCompleted &&
                $0.date >= today && $0.date <= end
            }

            return TrackerSummary(
                id:          id,
                name:        cal.title,
                icon:        meta.icon,
                color:       Color(hex: meta.colorHex) ?? .indigo,
                isDoneToday: isDone,
                streak:      0
            )
        }

        return TrackerWidgetEntry(date: .now, trackers: summaries)
    }
}

// MARK: - Entry View (family-aware)

struct TrackerWidgetEntryView: View {
    let entry: TrackerWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            if entry.trackers.first != nil {
                SmallWidgetView(entry: entry)
            } else {
                placeholderText
            }
        default:
            if entry.trackers.isEmpty {
                placeholderText
            } else {
                MediumWidgetView(entry: entry)
            }
        }
    }

    private var placeholderText: some View {
        Text("Add trackers in the app")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding()
    }
}

// MARK: - Small Widget (1 tracker)

struct SmallWidgetView: View {
    let entry: TrackerWidgetEntry
    var tracker: TrackerSummary? { entry.trackers.first }

    var body: some View {
        if let t = tracker {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: t.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(t.color)
                    Spacer()
                    Image(systemName: t.isDoneToday
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(t.isDoneToday ? t.color : .secondary)
                }
                Spacer()
                Text(t.name)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                Text(t.isDoneToday ? "Done ✓" : "Not yet")
                    .font(.caption2)
                    .foregroundStyle(t.isDoneToday ? t.color : .secondary)
            }
            .padding()
            .background(ContainerRelativeShape().fill(.background))
        }
    }
}

// MARK: - Medium Widget (up to 4 trackers)

struct MediumWidgetView: View {
    let entry: TrackerWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            LazyVGrid(columns: [GridItem(.flexible()),
                                GridItem(.flexible())],
                      spacing: 8) {
                ForEach(entry.trackers.prefix(4)) { t in
                    HStack(spacing: 8) {
                        Image(systemName: t.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(t.color)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(subtitleFor(t))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Circle()
                            .fill(t.isDoneToday ? t.color : Color(.systemFill))
                            .frame(width: 10, height: 10)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(ContainerRelativeShape().fill(.background))
    }

    private func subtitleFor(_ t: TrackerSummary) -> String {
        t.isDoneToday ? "Done ✓" : "Pending"
    }
}

// MARK: - Lock Screen Widget (accessoryCircular)

struct LockScreenWidgetView: View {
    let entry: TrackerWidgetEntry
    var tracker: TrackerSummary? { entry.trackers.first }

    var body: some View {
        if let t = tracker {
            ZStack {
                Image(systemName: t.isDoneToday
                      ? "checkmark.circle.fill" : t.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(t.isDoneToday ? .green : .primary)
            }
            .widgetAccentable()
        }
    }
}

// MARK: - Widget Configuration

struct TrackerWidget: Widget {
    let kind = "TrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrackerWidgetProvider()) { entry in
            TrackerWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Reminder Track")
        .description("See and log your habits at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TrackerLockScreenWidget: Widget {
    let kind = "TrackerLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrackerWidgetProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Reminder Track (Lock Screen)")
        .description("Quick glance at your top habit.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Widget Bundle

@main
struct TrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrackerWidget()
        TrackerLockScreenWidget()
    }
}
