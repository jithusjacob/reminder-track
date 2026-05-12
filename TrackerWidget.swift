import WidgetKit
import SwiftUI
import EventKit
import ActivityKit

// Avoid collision with TimelineProvider's `Entry` associated type inside provider methods.
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
            // Refresh at midnight so the widget resets daily
            let midnight = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
            let timeline = Timeline(entries: [entry], policy: .after(midnight))
            completion(timeline)
        }
    }

    // MARK: Build

    private func buildEntry() async -> TrackerWidgetEntry {
        let store = EKEventStore()
        // Widget runs in a separate process — request access directly
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await store.requestFullAccessToReminders()) ?? false
        } else {
            granted = (try? await store.requestAccess(to: .reminder)) ?? false
        }
        guard granted else {
            return TrackerWidgetEntry(date: .now, trackers: [])
        }

        // One fetch covers both config reminders (tracker identity) and entry reminders.
        let allCals = store.calendars(for: .reminder)
        guard !allCals.isEmpty else {
            return TrackerWidgetEntry(date: .now, trackers: [])
        }
        let pred = store.predicateForReminders(in: allCals)
        let allReminders: [EKReminder] = await withCheckedContinuation { cont in
            store.fetchReminders(matching: pred) { cont.resume(returning: $0 ?? []) }
        }

        var seen = Set<String>()
        let trackers = allReminders
            .filter { $0.title == "_tracker_config_"
                   && $0.url?.scheme == "tracker"
                   && $0.url?.host  == "config" }
            .compactMap { Tracker.from(configReminder: $0) }
            .filter { seen.insert($0.id).inserted }
            .filter(\.isActive)
            .prefix(4)

        let today = Calendar.current.startOfDay(for: .now)
        let end   = today.addingTimeInterval(86399)

        let summaries = trackers.map { tracker -> TrackerSummary in
            let todayEntry = allReminders
                .compactMap { HabitEntry.from(reminder: $0) }
                .filter { $0.trackerId == tracker.id
                       && $0.date >= today && $0.date <= end }
                .first
            return TrackerSummary(
                id:          tracker.id,
                name:        tracker.name,
                icon:        tracker.icon,
                color:       tracker.color,
                isDoneToday: todayEntry?.isCompleted ?? false,
                streak:      0
            )
        }

        return TrackerWidgetEntry(date: .now, trackers: Array(summaries))
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
        } else {
            Text("No trackers").font(.caption).foregroundStyle(.secondary)
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
            Group {
                switch entry.trackers.count {
                case 0: Text("Add trackers in the app")
                        .font(.caption).foregroundStyle(.secondary)
                default: MediumWidgetView(entry: entry)
                }
            }
            .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Tracker")
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
        .configurationDisplayName("Tracker (Lock Screen)")
        .description("Quick glance at your top habit.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Live Activity (iOS 16.2+)

@available(iOSApplicationExtension 16.2, *)
struct TrackerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrackerActivityAttributes.self) { context in
            // Lock-screen / banner view
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                    let pct = context.state.totalCount > 0
                        ? Double(context.state.completedCount) / Double(context.state.totalCount)
                        : 0.0
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(Color.white,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(context.state.completedCount)")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                        Text("of \(context.state.totalCount)")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Habits")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    if context.state.completedCount == context.state.totalCount
                        && context.state.totalCount > 0 {
                        Text("All done! 🎉")
                            .font(.caption2).foregroundStyle(.white)
                    } else if context.state.completedNames.isEmpty {
                        Text("None logged yet")
                            .font(.caption2).foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text(context.state.completedNames.joined(separator: ", "))
                            .font(.caption2).foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.indigo.gradient)
            .activityBackgroundTint(Color.indigo)

        } dynamicIsland: { context in
            let pct = context.state.totalCount > 0
                ? Double(context.state.completedCount) / Double(context.state.totalCount)
                : 0.0

            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: pct)
                                .stroke(Color.indigo,
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(context.state.completedCount)/\(context.state.totalCount)")
                                .font(.system(size: 11, design: .rounded).weight(.bold))
                        }
                        .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Habits")
                                .font(.caption.weight(.semibold))
                            Text(context.state.completedNames.isEmpty
                                 ? "None yet"
                                 : context.state.completedNames.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.indigo).font(.caption)
            } compactTrailing: {
                Text("\(context.state.completedCount)/\(context.state.totalCount)")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(.indigo)
            } minimal: {
                ZStack {
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(Color.indigo, lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.indigo)
                }
            }
        }
    }
}

// MARK: - Widget Bundle

@main
struct TrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrackerWidget()
        TrackerLockScreenWidget()
        if #available(iOSApplicationExtension 16.2, *) {
            TrackerLiveActivity()
        }
    }
}
