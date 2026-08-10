import SwiftUI

// MARK: - Summary Range Filter

enum SummaryRangeFilter: String, CaseIterable, Identifiable {
    case week    = "Week"
    case month   = "Month"
    case year    = "Year"
    case allTime = "All Time"

    var id: String { rawValue }

    /// "All Time" is just the range from the tracker's own creation date through
    /// today — expressing it as a DateRange (rather than a special nil case) lets
    /// every stat below use the same completed/elapsed-days math for all four cases.
    func range(trackerCreatedAt: Date, referenceDate: Date = .now) -> DateRange {
        switch self {
        case .week:  return .week(containing: referenceDate)
        case .month: return .month(containing: referenceDate)
        case .year:  return .year(containing: referenceDate)
        case .allTime:
            return DateRange(start: Calendar.current.startOfDay(for: trackerCreatedAt),
                              end:   referenceDate)
        }
    }
}

// MARK: - Summary View

struct SummaryView: View {
    @Environment(TrackerStore.self) var trackerStore
    @Environment(LogStore.self)     var logStore

    @State private var filter: SummaryRangeFilter = .month

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
                        Picker("Range", selection: $filter) {
                            ForEach(SummaryRangeFilter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 8)

                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(trackerStore.trackers) { tracker in
                                    TrackerSummaryCard(tracker: tracker, filter: filter)
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
}

// MARK: - Tracker Summary Card

private struct TrackerSummaryCard: View {
    let tracker: Tracker
    let filter: SummaryRangeFilter

    @Environment(LogStore.self) var logStore

    private var range: DateRange { filter.range(trackerCreatedAt: tracker.createdAt) }

    private var rangeCompleted: Int {
        logStore.entries(for: tracker, in: range).filter(\.isCompleted).count
    }

    private var rangeTotalDays: Int {
        let days = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        return max(1, days + 1)
    }

    /// Days elapsed so far within the range, capped at today — every preset range
    /// (including "All Time") runs through the present, so this is never the full
    /// range width until the range's last day has actually passed.
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

    private var progressLabel: String {
        filter == .allTime
            ? "\(rangeCompleted) of \(rangeElapsedDays) days since you started"
            : "\(rangeCompleted) of \(rangeElapsedDays) days this \(filter.rawValue.lowercased())"
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

            // Stats row — a second "All Time" cell would just duplicate the first
            // when the filter itself is All Time, so collapse to one cell there.
            if filter == .allTime {
                statCell("\(rangeCompleted)", "All Time")
                    .frame(maxWidth: .infinity)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 0) {
                    statCell("\(rangeCompleted)/\(rangeTotalDays)", filter.rawValue)
                    Divider().frame(height: 36)
                    statCell("\(allTimeCompleted)", "All Time")
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
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
