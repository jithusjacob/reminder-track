import SwiftUI

// MARK: - Content Tab

enum ContentTab: Hashable {
    case today, calendar, summary, trackers

    /// With no trackers yet, landing on Today (or Calendar/Summary) shows nothing
    /// useful — send first-time and freshly-emptied users straight to Trackers so
    /// they can create one immediately.
    static func initial(hasTrackers: Bool) -> ContentTab {
        hasTrackers ? .today : .trackers
    }
}

struct ContentView: View {
    @Environment(TrackerStore.self) var trackerStore
    @Environment(LogStore.self)     var logStore

    @State private var selectedTab: ContentTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "checkmark.circle.fill")
                }
                .tag(ContentTab.today)

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(ContentTab.calendar)

            SummaryView()
                .tabItem {
                    Label("Summary", systemImage: "chart.bar.fill")
                }
                .tag(ContentTab.summary)

            TrackersListView()
                .tabItem {
                    Label("Trackers", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(ContentTab.trackers)
        }
        .tint(.indigo)
        .task {
            selectedTab = .initial(hasTrackers: !trackerStore.trackers.isEmpty)
            let ids = trackerStore.trackers.map(\.id)
            await logStore.fetchAll(trackerIds: ids)
            logStore.syncLiveActivity(trackers: trackerStore.trackers)
        }
        .onChange(of: logStore.logVersion) {
            logStore.syncLiveActivity(trackers: trackerStore.trackers)
        }
        .alert("Something went wrong",
               isPresented: Binding(
                   get: { trackerStore.errorMessage != nil || logStore.errorMessage != nil },
                   set: { if !$0 {
                       trackerStore.errorMessage = nil
                       logStore.errorMessage     = nil
                   }})) {
            Button("OK") { }
        } message: {
            Text(trackerStore.errorMessage ?? logStore.errorMessage ?? "")
        }
    }
}
