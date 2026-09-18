import SwiftUI

// MARK: - Permission Denied

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("Reminders Access Required")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text("Reminder Track needs access to Apple Reminders to store your habits. Please enable it in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Permission Request

struct PermissionView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 72))
                .foregroundStyle(.indigo)
                .symbolEffect(.pulse)

            VStack(spacing: 12) {
                Text("Reminder Track")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text("Tracker uses Apple Reminders as its database — your data lives natively on your device and syncs via iCloud automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Kept in sync with what's actually shipped — matches IntroView's
                // claims (calendar/stats/reminders), not features that aren't
                // built (widgets/Watch/Siri were removed from here for the same
                // reason they're absent from the App Store description).
                FeatureRow(icon: "icloud.fill",      color: .blue,   text: "iCloud sync across all your Apple devices")
                FeatureRow(icon: "calendar",         color: .green,  text: "A full calendar view of every day you tracked")
                FeatureRow(icon: "chart.bar.fill",   color: .orange, text: "Stats for every tracker, updated automatically")
                FeatureRow(icon: "arrow.triangle.2.circlepath", color: .indigo, text: "Two-way sync — tick in Reminders or in the app")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onRequest) {
                // Apple Guideline 5.1.1(iv): a pre-permission screen must not use
                // "Allow"-style wording — that's reserved for the system's own
                // prompt, which appears right after this. "Continue" hands the
                // actual decision to the real Reminders permission dialog.
                Label("Continue", systemImage: "checkmark.shield.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
