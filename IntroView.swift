import SwiftUI

// MARK: - First-Launch Intro

/// Shown once, the very first time the app is opened on this install — before
/// the Reminders permission ask — to set expectations for what the app does.
/// `TrackerApp` gates this behind an `@AppStorage` flag so it never appears again.
struct IntroView: View {
    let onContinue: () -> Void

    @State private var page = 0

    private let pages: [IntroPage] = [
        IntroPage(icon: "checkmark.seal.fill", color: .indigo,
                  title: "Welcome to\nReminder Track",
                  text: "Build habits you'll actually stick to — tracked right inside the Reminders app you already use."),
        IntroPage(icon: "flame.fill", color: .orange,
                  title: "Build Streaks",
                  text: "Check in daily and watch your streak grow. See your progress at a glance."),
        IntroPage(icon: "calendar", color: .indigo,
                  title: "See Every Day",
                  text: "A full calendar view of every day you showed up, for every habit you track."),
        IntroPage(icon: "chart.bar.fill", color: .green,
                  title: "Track Your Stats",
                  text: "Weekly, monthly, and yearly stats for every tracker, updated automatically."),
        IntroPage(icon: "bell.badge.fill", color: .red,
                  title: "Stay on Schedule",
                  text: "Daily reminders that count as a check-in the moment you mark them done — in the app or in Reminders.")
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onContinue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding()
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
            }

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    IntroPageView(page: pages[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 24) {
                PageIndicator(count: pages.count, current: page)

                Button(action: advance) {
                    Text(isLastPage ? "Get Started" : "Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
    }

    private func advance() {
        if isLastPage {
            onContinue()
        } else {
            withAnimation { page += 1 }
        }
    }
}

// MARK: - Page Model & Views

private struct IntroPage {
    let icon: String
    let color: Color
    let title: String
    let text: String
}

private struct IntroPageView: View {
    let page: IntroPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 84))
                .foregroundStyle(page.color)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(page.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

private struct PageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.indigo : Color(.systemFill))
                    .frame(width: i == current ? 20 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: current)
    }
}
