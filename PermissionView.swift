import SwiftUI

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
                FeatureRow(icon: "icloud.fill",      color: .blue,   text: "iCloud sync across all your Apple devices")
                FeatureRow(icon: "applewatch",       color: .green,  text: "Visible on Apple Watch & Reminders widgets")
                FeatureRow(icon: "mic.fill",         color: .orange, text: "Ask Siri about your habits")
                FeatureRow(icon: "arrow.triangle.2.circlepath", color: .indigo, text: "Two-way sync — tick in Reminders or in the app")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onRequest) {
                Label("Allow Access to Reminders", systemImage: "checkmark.shield.fill")
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
