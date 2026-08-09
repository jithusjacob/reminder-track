import SwiftUI

// MARK: - Trackers List

struct TrackersListView: View {
    @Environment(TrackerStore.self) var trackerStore
    @State private var showAdd      = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(trackerStore.trackers) { tracker in
                    NavigationLink { TrackerFormView(mode: .edit(tracker)) } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(tracker.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: tracker.icon)
                                    .foregroundStyle(tracker.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tracker.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(tracker.recurrence.rawValue.capitalized)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if !tracker.isActive {
                                Spacer()
                                Text("Paused")
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color(.systemFill))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { idx in
                    Task {
                        for i in idx { await trackerStore.delete(trackerStore.trackers[i]) }
                    }
                }
            }
            .navigationTitle("Trackers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { TrackerFormView(mode: .add) }
            .overlay {
                if trackerStore.trackers.isEmpty {
                    ContentUnavailableView(
                        "No Trackers",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Tap + to create your first tracker")
                    )
                }
            }
        }
    }
}

// MARK: - Tracker Form

enum TrackerFormMode { case add; case edit(Tracker) }

struct TrackerFormView: View {
    let mode: TrackerFormMode

    @Environment(TrackerStore.self) var trackerStore
    @Environment(\.dismiss) var dismiss

    @State private var name         = ""
    @State private var icon         = "star.fill"
    @State private var color        = Color.indigo
    @State private var recurrence   = RecurrenceType.daily
    @State private var isActive     = true
    @State private var setReminder  = false
    @State private var reminderTime = Calendar.current.date(
        bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var showIcons    = false

    private var isEditing: Bool {
        if case .edit = mode { return true }; return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    HStack(spacing: 12) {
                        Button { showIcons = true } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(color.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: icon)
                                    .font(.system(size: 22))
                                    .foregroundStyle(color)
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading) {
                            TextField("Tracker name", text: $name)
                                .font(.headline)
                            Text("Tap icon to change").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                }

                Section("Schedule") {
                    Picker("Repeat", selection: $recurrence) {
                        Text("Daily").tag(RecurrenceType.daily)
                        Text("Weekdays").tag(RecurrenceType.weekdays)
                        Text("Weekly").tag(RecurrenceType.weekly)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Add Reminder", isOn: $setReminder.animation())
                    if setReminder {
                        DatePicker("Time",
                                   selection: $reminderTime,
                                   displayedComponents: .hourAndMinute)
                    }
                }

                if isEditing {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    } footer: {
                        Text("Inactive trackers are hidden from Today view.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Tracker" : "New Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showIcons) {
                IconPickerSheet(selected: $icon, color: color)
            }
        }
        .onAppear(perform: populate)
    }

    private func populate() {
        guard case .edit(let t) = mode else { return }
        name       = t.name
        icon       = t.icon
        color      = t.color
        recurrence = t.recurrence
        isActive   = t.isActive
        if let rt = t.reminderTime, let h = rt.hour, let m = rt.minute {
            setReminder  = true
            reminderTime = Calendar.current.date(
                bySettingHour: h, minute: m, second: 0, of: .now) ?? reminderTime
        }
    }

    private func save() {
        let timeComps: DateComponents? = setReminder
            ? Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            : nil

        let tracker: Tracker
        switch mode {
        case .add:
            tracker = Tracker(
                id: UUID().uuidString, name: name, icon: icon,
                color: color, reminderTime: timeComps,
                recurrence: recurrence, isActive: true, createdAt: .now)
        case .edit(var t):
            t.name = name; t.icon = icon; t.color = color
            t.recurrence = recurrence; t.isActive = isActive
            t.reminderTime = timeComps
            tracker = t
        }

        Task {
            if case .add = mode {
                // add() returns the tracker with the real calendar ID
                if let created = await trackerStore.add(tracker), setReminder {
                    await trackerStore.scheduleReminder(for: created)
                }
            } else {
                await trackerStore.update(tracker)
                if setReminder { await trackerStore.scheduleReminder(for: tracker) }
            }
            dismiss()
        }
    }
}

// MARK: - Icon Picker

struct IconPickerSheet: View {
    @Binding var selected: String
    let color: Color
    @Environment(\.dismiss) var dismiss

    let icons = [
        "star.fill","heart.fill","bolt.fill","flame.fill","drop.fill",
        "moon.fill","sun.max.fill","leaf.fill","dumbbell.fill","figure.run",
        "figure.walk","bicycle","book.fill","pencil","music.note",
        "fork.knife","bed.double.fill","pills.fill","brain.head.profile",
        "laptopcomputer","phone.fill","globe","camera.fill","paintbrush.fill",
        "checkmark.seal.fill","trophy.fill","medal.fill","crown.fill",
        "graduationcap.fill","briefcase.fill","cart.fill","house.fill",
        "car.fill","airplane","figure.yoga","figure.swimming","figure.hiking",
        "cup.and.saucer.fill","wineglass","person.2.fill","person.3.fill"
    ].filter { UIImage(systemName: $0) != nil }

    let cols = Array(repeating: GridItem(.flexible()), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selected = icon
                            dismiss()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selected == icon ? color : color.opacity(0.1))
                                    .frame(height: 56)
                                Image(systemName: icon)
                                    .font(.system(size: 26))
                                    .foregroundStyle(selected == icon ? .white : color)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
