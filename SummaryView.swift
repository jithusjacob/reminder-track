import SwiftUI

// MARK: - Summary View

struct SummaryView: View {
    @Environment(TrackerStore.self) var trackerStore
    @Environment(LogStore.self)     var logStore

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
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(trackerStore.trackers) { tracker in
                                TrackerSummaryCard(tracker: tracker)
                            }
                        }
                        .padding()
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

    @Environment(LogStore.self) var logStore

    private var monthCompleted: Int {
        logStore.entries(for: tracker, in: .month(containing: .now))
            .filter(\.isCompleted).count
    }

    private var monthTotal: Int {
        Calendar.current.range(of: .day, in: .month, for: .now)?.count ?? 30
    }

    private var allTimeCompleted: Int {
        logStore.allEntries(for: tracker).filter(\.isCompleted).count
    }

    private var monthProgress: Double {
        guard monthTotal > 0 else { return 0 }
        let today = Calendar.current.component(.day, from: .now)
        return Double(monthCompleted) / Double(today)
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
                ProgressView(value: min(monthProgress, 1.0))
                    .tint(tracker.color)
                    .scaleEffect(x: 1, y: 1.5)

                Text("\(monthCompleted) of \(daysElapsedThisMonth) days this month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Stats row
            HStack(spacing: 0) {
                statCell("\(monthCompleted)/\(monthTotal)", "This Month")
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

    private var daysElapsedThisMonth: Int {
        Calendar.current.component(.day, from: .now)
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
