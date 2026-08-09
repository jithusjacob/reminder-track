import SwiftUI

// MARK: - Today View

struct TodayView: View {
    @Environment(TrackerStore.self) var trackerStore
    @Environment(LogStore.self)     var logStore
    @State private var selectedDate = Date.now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DateStripView(selectedDate: $selectedDate)
                        .padding(.horizontal)

                    if trackerStore.trackers.filter(\.isActive).isEmpty {
                        EmptyTrackersPrompt()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(trackerStore.trackers.filter(\.isActive)) { tracker in
                                TrackerRowView(tracker: tracker, date: selectedDate)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var navTitle: String {
        if Calendar.current.isDateInToday(selectedDate)     { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.weekday(.wide).month().day())
    }
}

// MARK: - 7-Day Strip

struct DateStripView: View {
    @Binding var selectedDate: Date

    private var days: [Date] {
        let cal = Calendar.current
        return (-6...0).compactMap { cal.date(byAdding: .day, value: $0, to: .now) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                DayChip(date: day,
                        isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate))
                    .onTapGesture { selectedDate = day }
            }
        }
    }
}

struct DayChip: View {
    let date: Date
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
            Text(date.formatted(.dateTime.day()))
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isSelected ? Color.indigo : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Tracker Row

struct TrackerRowView: View {
    let tracker: Tracker
    let date: Date

    @Environment(LogStore.self) var logStore

    private var entry: Entry? { logStore.entry(for: tracker, on: date) }
    private var isDone: Bool  { entry?.isCompleted ?? false }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tracker.color.opacity(isDone ? 0.2 : 0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: tracker.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(tracker.color)
            }

            // Name + status
            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.name)
                    .font(.subheadline.weight(.semibold))
                Text(isDone ? "Done ✓" : "Not done")
                    .font(.caption)
                    .foregroundStyle(isDone ? tracker.color : .secondary)
            }

            Spacer()

            // Checkbox
            Button {
                Task { await logStore.toggle(tracker: tracker, date: date) }
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(isDone ? tracker.color : Color(.tertiaryLabel))
                    .symbolEffect(.bounce, value: isDone)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone
                ? "Mark \(tracker.name) as not done"
                : "Mark \(tracker.name) as done")
            .accessibilityAddTraits(isDone ? [.isSelected] : [])
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Empty State

struct EmptyTrackersPrompt: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No active trackers")
                .font(.headline)
            Text("Go to the Trackers tab to add habits you want to track.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
