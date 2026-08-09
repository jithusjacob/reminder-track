import SwiftUI

@main
struct TrackerApp: App {

    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    @State private var service       = EventKitService()
    @State private var trackerStore: TrackerStore?
    @State private var logStore: LogStore?
    @State private var permissionDenied = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenIntro {
                    IntroView { hasSeenIntro = true }
                } else if permissionDenied {
                    PermissionDeniedView()
                } else if let ts = trackerStore, let ls = logStore {
                    ContentView()
                        .environment(service)
                        .environment(ts)
                        .environment(ls)
                } else {
                    PermissionView {
                        Task { await requestAndSetup() }
                    }
                }
            }
            .task {
                // Skip the permission screen automatically if already granted.
                if service.isAlreadyAuthorized {
                    await requestAndSetup()
                } else if service.isDenied {
                    permissionDenied = true
                }
            }
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

    private func requestAndSetup() async {
        let granted = await service.requestPermission()
        if granted {
            let ts = TrackerStore(service: service)
            let ls = LogStore(service: service)
            await ts.load()
            trackerStore = ts
            logStore     = ls
        } else if service.isDenied {
            permissionDenied = true
        }
    }
}
