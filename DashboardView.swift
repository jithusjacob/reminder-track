import SwiftUI

// MARK: - Calendar View

struct CalendarView: View {
    @Environment(TrackerStore.self) var trackerStore
    @Environment(LogStore.self)     var logStore

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
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedTracker == nil {
                    selectedTracker = trackerStore.trackers.first
                }
            }
            .onChange(of: trackerStore.trackers) {
                if selectedTracker == nil {
                    selectedTracker = trackerStore.trackers.first
                }
            }
        }
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

// MARK: - Day Cell

struct DayCell: View {
    let tracker: Tracker
    let day: Date

    @Environment(LogStore.self) var logStore

    private var entry: Entry?  { logStore.entry(for: tracker, on: day) }
    private var isDone: Bool   { entry?.isCompleted ?? false }
    private var isToday: Bool  { Calendar.current.isDateInToday(day) }
    private var isFuture: Bool {
        day > Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        Button {
            guard !isFuture else { return }
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
        .opacity(isFuture ? 0.25 : 1)
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
        let cap = min(yearRange.end, Calendar.current.startOfDay(for: .now))
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
