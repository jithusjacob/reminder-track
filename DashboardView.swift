import SwiftUI

// MARK: - Tracker Selection

/// Resolves which tracker should stay selected given the live tracker list.
/// Falls back to the first available tracker whenever the current selection
/// is missing (nil) or no longer exists in the list (e.g. it was just
/// deleted) — a stale struct copy otherwise never re-syncs on its own since
/// it's never `nil`.
enum TrackerSelection {
    static func resolve(current: Tracker?, in trackers: [Tracker]) -> Tracker? {
        if let current, trackers.contains(where: { $0.id == current.id }) {
            return current
        }
        return trackers.first
    }
}

// MARK: - Calendar View

struct CalendarView: View {
    @Environment(TrackerStore.self) var trackerStore
    @Environment(LogStore.self)     var logStore

    // UIKit-bridged dynamic colors (Color(.systemGroupedBackground) etc., used
    // throughout this page) don't reliably redraw on their own when the system
    // appearance flips while the view is already on screen and nothing else is
    // triggering a re-render — this page is unusually static once a tracker and
    // month are picked, so the stale colors are visible here. Reading colorScheme
    // and keying the content on it forces SwiftUI to rebuild the subtree (and
    // thus re-resolve every dynamic color) the moment appearance changes.
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTracker: Tracker?
    @State private var month = Date.now

    var body: some View {
        NavigationStack {
            Group {
                if let tracker = selectedTracker {
                    ScrollView {
                        VStack(spacing: 16) {
                            if trackerStore.trackers.count > 1 {
                                trackerMenuButton(tracker)
                            }
                            monthNavBar
                            MonthGrid(tracker: tracker, month: month)
                            CalendarStatsRow(tracker: tracker, month: month)
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                    .navigationTitle(tracker.name)
                } else {
                    ContentUnavailableView(
                        "No Trackers",
                        systemImage: "calendar",
                        description: Text("Add a tracker in the Trackers tab to get started.")
                    )
                    .navigationTitle("Calendar")
                }
            }
            .id(colorScheme)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                reselectTrackerIfNeeded()
            }
            .onChange(of: trackerStore.trackers) {
                reselectTrackerIfNeeded()
            }
        }
    }

    // MARK: Selection

    private func reselectTrackerIfNeeded() {
        selectedTracker = TrackerSelection.resolve(current: selectedTracker, in: trackerStore.trackers)
    }

    // MARK: Tracker Menu

    private func trackerMenuButton(_ current: Tracker) -> some View {
        Menu {
            ForEach(trackerStore.trackers) { t in
                Button { selectedTracker = t } label: {
                    Label(t.name, systemImage: t.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: current.icon)
                    .font(.subheadline.weight(.semibold))
                Text(current.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .opacity(0.6)
            }
            .foregroundStyle(current.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(current.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: Month Navigation

    private var monthNavBar: some View {
        HStack {
            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.title3.weight(.semibold))
            Spacer()
            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.3 : 1)
        }
        .foregroundStyle(.primary)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private func shiftMonth(by n: Int) {
        month = Calendar.current.date(byAdding: .month, value: n, to: month) ?? month
    }
}

// MARK: - Month Grid

struct MonthGrid: View {
    let tracker: Tracker
    let month: Date

    @Environment(LogStore.self) var logStore

    private let dayHeaders = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var cells: [Date?] {
        let cal   = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let end   = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        let pad   = cal.component(.weekday, from: start) - 1

        var flat = [Date?](repeating: nil, count: pad)
        var d    = start
        while d <= end {
            flat.append(d)
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        while flat.count % 7 != 0 { flat.append(nil) }
        return flat
    }

    private var rows: [[Date?]] {
        stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Day-of-week headers
            HStack {
                ForEach(dayHeaders, id: \.self) { h in
                    Text(h)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            ForEach(rows.indices, id: \.self) { ri in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { di in
                        if let day = rows[ri][safe: di] ?? nil {
                            DayCell(tracker: tracker, day: day)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 54)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Day Lock Policy

/// Future dates are normally locked from logging in-app, but a reminder
/// already marked complete in the Reminders app (synced in as a completed
/// Entry) should still show and stay interactive here, matching what
/// Reminders already shows — only *undone* future days stay locked.
enum DayLockPolicy {
    static func isLocked(day: Date, isDone: Bool,
                          referenceDate: Date = .now, calendar: Calendar = .current) -> Bool {
        let isFuture = day > calendar.startOfDay(for: referenceDate)
        return isFuture && !isDone
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let tracker: Tracker
    let day: Date

    @Environment(LogStore.self) var logStore

    private var entry: Entry?  { logStore.entry(for: tracker, on: day) }
    private var isDone: Bool   { entry?.isCompleted ?? false }
    private var isToday: Bool  { Calendar.current.isDateInToday(day) }
    private var isLocked: Bool { DayLockPolicy.isLocked(day: day, isDone: isDone) }

    var body: some View {
        Button {
            guard !isLocked else { return }
            Task { await logStore.toggle(tracker: tracker, date: day) }
        } label: {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? tracker.color : Color(.secondaryLabel))

                ZStack {
                    Circle()
                        .fill(isDone ? tracker.color : Color(.systemFill))
                        .frame(width: 34, height: 34)

                    if isToday && !isDone {
                        Circle()
                            .strokeBorder(tracker.color, lineWidth: 2)
                            .frame(width: 34, height: 34)
                    }

                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.plain)
        .opacity(isLocked ? 0.25 : 1)
        .accessibilityLabel({
            let dateStr = day.formatted(.dateTime.month(.abbreviated).day())
            if isLocked { return dateStr }
            return isDone
                ? "\(dateStr), completed. Tap to unmark."
                : "\(dateStr), not done. Tap to mark complete."
        }())
        .accessibilityAddTraits(isDone ? [.isSelected] : [])
        .accessibilityHint(isLocked ? "Future date, cannot log" : "")
    }
}

// MARK: - Stats Row

struct CalendarStatsRow: View {
    let tracker: Tracker
    let month: Date

    @Environment(LogStore.self) var logStore

    private var monthCompleted: Int {
        logStore.entries(for: tracker, in: .month(containing: month))
            .filter(\.isCompleted).count
    }

    private var monthTotal: Int {
        Calendar.current.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    private var yearCompleted: Int {
        let yearRange = DateRange.year(containing: month)
        let endOfToday = Calendar.current.date(
            byAdding: DateComponents(day: 1, second: -1),
            to: Calendar.current.startOfDay(for: .now))!
        let cap = min(yearRange.end, endOfToday)
        return logStore.entries(for: tracker, in: DateRange(start: yearRange.start, end: cap))
            .filter(\.isCompleted).count
    }

    private var monthLabel: String {
        month.formatted(.dateTime.month(.abbreviated))
    }

    private var yearLabel: String {
        month.formatted(.dateTime.year())
    }

    var body: some View {
        HStack(spacing: 0) {
            statCell("\(monthCompleted)/\(monthTotal)", monthLabel)
            Divider().frame(height: 44)
            statCell("\(yearCompleted)", yearLabel)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(tracker.color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
