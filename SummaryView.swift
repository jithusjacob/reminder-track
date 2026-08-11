import SwiftUI

// MARK: - Summary View

struct SummaryView: View {
    @Environment(TrackerStore.self) var trackerStore
    @Environment(LogStore.self)     var logStore

    // Defaults to "this month, to date" — bounded by the date pickers below so
    // it always stays valid (From ≤ To ≤ today).
    @State private var rangeStart = DateRange.month(containing: .now).start
    @State private var rangeEnd   = Date.now

    private var selectedRange: DateRange {
        DateRange(start: rangeStart, end: rangeEnd)
    }

    var body: some View {
        NavigationStack {
            Group {
                if trackerStore.trackers.isEmpty {
                    ContentUnavailableView(
                        "No Trackers",
                        systemImage: "chart.bar",
                        description: Text("Add a tracker in the Trackers tab to get started.")
                    )
                } else {
                    VStack(spacing: 0) {
                        dateRangeBar

                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(trackerStore.trackers) { tracker in
                                    TrackerSummaryCard(tracker: tracker, range: selectedRange)
                                }
                            }
                            .padding()
                        }
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Date Range Pickers

    private var dateRangeBar: some View {
        HStack(spacing: 12) {
            DatePicker("From", selection: $rangeStart, in: ...rangeEnd, displayedComponents: .date)
                .labelsHidden()
            Text("–").foregroundStyle(.secondary)
            DatePicker("To", selection: $rangeEnd, in: rangeStart...Date.now, displayedComponents: .date)
                .labelsHidden()
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Tracker Summary Card

private struct TrackerSummaryCard: View {
    let tracker: Tracker
    let range: DateRange

    @Environment(LogStore.self) var logStore

    private var rangeCompleted: Int {
        logStore.entries(for: tracker, in: range).filter(\.isCompleted).count
    }

    private var rangeTotalDays: Int {
        let days = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        return max(1, days + 1)
    }

    /// Days elapsed so far within the range, capped at today.
    private var rangeElapsedDays: Int {
        let today     = Calendar.current.startOfDay(for: .now)
        let cappedEnd = min(today, Calendar.current.startOfDay(for: range.end))
        let days      = Calendar.current.dateComponents([.day], from: range.start, to: cappedEnd).day ?? 0
        return max(1, min(days + 1, rangeTotalDays))
    }

    private var rangeProgress: Double {
        Double(rangeCompleted) / Double(rangeElapsedDays)
    }

    private var allTimeCompleted: Int {
        logStore.allEntries(for: tracker).filter(\.isCompleted).count
    }

    private var rangeLabel: String {
        "\(range.start.formatted(.dateTime.month(.abbreviated).day())) – \(range.end.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var progressLabel: String {
        "\(rangeCompleted) of \(rangeTotalDays) days in \(rangeLabel)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: tracker.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tracker.color)
                    .frame(width: 36, height: 36)
                    .background(tracker.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(tracker.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: min(rangeProgress, 1.0))
                    .tint(tracker.color)
                    .scaleEffect(x: 1, y: 1.5)

                Text(progressLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Stats row: selected range alongside a fixed All Time reference.
            HStack(spacing: 0) {
                statCell("\(rangeCompleted)/\(rangeTotalDays)", rangeLabel)
                Divider().frame(height: 36)
                statCell("\(allTimeCompleted)", "All Time")
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(tracker.color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
