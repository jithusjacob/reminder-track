import SwiftUI

@main
struct TrackerApp: App {

    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    @State private var service       = EventKitService()
    @State private var trackerStore: TrackerStore?
    @State private var logStore: LogStore?
    @State private var permissionDenied = false

    // Distinguishes "haven't checked authorization yet" from "checked, and it's
    // not granted" — without this, a returning user who already granted access
    // briefly sees PermissionView flash before requestAndSetup() finishes loading
    // and swaps in ContentView, since trackerStore/logStore start out nil either way.
    @State private var isCheckingAuth = true

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenIntro {
                    IntroView { hasSeenIntro = true }
                } else if isCheckingAuth {
                    LaunchLoadingView()
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
                isCheckingAuth = false
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

// MARK: - Launch Loading

/// Shown only while checking prior Reminders authorization on launch — kept
/// blank/neutral since it's meant to be invisible in the common case (already
/// granted, loads fast) rather than read as its own screen.
private struct LaunchLoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
