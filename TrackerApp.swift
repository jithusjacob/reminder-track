import SwiftUI

@main
struct TrackerApp: App {

    @State private var service       = EventKitService()
    @State private var trackerStore: TrackerStore?
    @State private var logStore: LogStore?

    var body: some Scene {
        WindowGroup {
            Group {
                if let ts = trackerStore, let ls = logStore {
                    ContentView()
                        .environment(service)
                        .environment(ts)
                        .environment(ls)
                } else {
                    PermissionView {
                        Task {
                            guard await service.requestPermission() else { return }
                            let ts = TrackerStore(service: service)
                            let ls = LogStore(service: service)
                            await ts.load()
                            trackerStore = ts
                            logStore     = ls
                        }
                    }
                }
            }
            // Re-sync when app comes back to foreground
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification)
            ) { _ in
                guard let ts = trackerStore, let ls = logStore else { return }
                Task {
                    await ts.load()
                    await ls.fetchAll(trackerIds: ts.trackers.map(\.id))
                }
            }
        }
    }
}
