import SwiftUI

struct ContentView: View {
    @Environment(TrackerStore.self) var trackerStore
    @Environment(LogStore.self)     var logStore

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "checkmark.circle.fill")
                }

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            SummaryView()
                .tabItem {
                    Label("Summary", systemImage: "chart.bar.fill")
                }

            TrackersListView()
                .tabItem {
                    Label("Trackers", systemImage: "list.bullet.rectangle.fill")
                }
        }
        .tint(.indigo)
        .task {
            let ids = trackerStore.trackers.map(\.id)
            await logStore.fetchAll(trackerIds: ids)
            logStore.syncLiveActivity(trackers: trackerStore.trackers)
        }
        .onChange(of: logStore.logVersion) {
            logStore.syncLiveActivity(trackers: trackerStore.trackers)
        }
    }
}
