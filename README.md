# Tracker — SwiftUI + EventKit

> **The only habit tracker where Apple Reminders IS the database.**
> Tick in the app ↔ tick in Reminders. Your data lives natively on device,
> syncs via iCloud, and works with Siri, Widgets, and Apple Watch —
> no proprietary cloud, no subscription.

---

## Project Structure

```
TrackerApp/
├── App/
│   └── TrackerApp.swift              # @main, permission gate, foreground sync
├── Models/
│   └── Models.swift                  # Tracker, Entry, DateRange, Color helpers
├── EventKit/
│   └── EventKitService.swift         # All EKEventStore reads & writes
├── Stores/
│   ├── TrackerStore.swift            # @Observable — tracker CRUD
│   └── LogStore.swift                # @Observable — entry logging + in-memory cache
├── Views/
│   ├── ContentView.swift             # TabView (Today / Dashboard / Trackers)
│   ├── PermissionView.swift          # Onboarding / permission screen
│   ├── Today/TodayView.swift         # Daily logging — date strip, row controls
│   ├── Dashboard/DashboardView.swift # Weekly / Monthly / Yearly heatmaps + stats
│   └── Trackers/TrackersListView.swift
├── Intents/
│   └── TrackerIntents.swift          # App Intents — Siri & Shortcuts app
├── TrackerWidget/
│   └── TrackerWidget.swift           # WidgetKit — Home Screen + Lock Screen
└── TrackerWatch/
    └── TrackerWatchApp.swift         # watchOS app — toggle from wrist
```

---

## Xcode Setup — 4 Targets

| Target | Type | Min OS |
|--------|------|--------|
| TrackerApp | iOS App | iOS 16.0 |
| TrackerWidgetExtension | Widget Extension | iOS 16.0 |
| TrackerWatchApp | watchOS App | watchOS 9.0 |
| App Intents | (baked into main target) | iOS 16.0 |

### Steps
1. New Project → iOS App (SwiftUI, Swift)
2. Copy files into matching folders
3. Add Widget Extension target (File → New → Target → Widget Extension)
   - Uncheck "Include Configuration Intent"
   - Copy TrackerWidget.swift into that target
4. Add watchOS App target (File → New → Target → Watch App)
   - Copy TrackerWatchApp.swift into that target
5. Add to iOS target Info.plist:
   ```xml
   <key>NSRemindersUsageDescription</key>
   <string>Tracker uses Reminders to store your data and sync it across your devices.</string>
   ```
6. Build on a real device (EventKit needs a device for full sync)

---

## How Data Is Stored

### Tracker → EKCalendar (a Reminders list)
```
_tracker_|uuid|Morning Run|figure.run|22C55E|boolean||times|daily|1|1715000000
```

### Entry → EKReminder (inside that list)
| EK Field | Stores |
|----------|--------|
| title | ISO date: `2026-05-10` |
| notes | User's note |
| isCompleted | Done state — bidirectionally synced |
| dueDateComponents | Tracking date for range queries |
| url | `tracker://entry?trackerId=X&value=Y&date=Z` |

---

## Bidirectional Sync Flow

```
App tap → EKEventStore.save() → Reminders updates instantly

Reminders tick → EKEventStoreChanged notification
              → LogStore debounces 500ms → re-fetches
              → @Observable updates UI automatically

App foregrounds → willEnterForegroundNotification → full re-sync
```

---

## Siri Phrases (automatic after install)

- "Log Morning Run in Tracker"
- "Log 8 Water in Tracker"
- "Did I do Morning Run in Tracker?"
- All also appear in Shortcuts app as automatable actions

---

## Widgets

| Widget | Family | Shows |
|--------|--------|-------|
| Home Screen | systemMedium | Up to 4 trackers, done/pending |
| Home Screen | systemSmall | Top tracker |
| Lock Screen | accessoryCircular | Icon, green when done |
| Watch Face | accessoryCircular (watchOS 10) | Same as lock screen |

---

## Unique Positioning vs Competitors

| | Streaks | Habitify | Productive | Tracker |
|-|---------|----------|-----------|---------|
| Data in Reminders app | No | No | No | Yes |
| Tick in Reminders syncs to app | No | No | No | Yes |
| Data survives app deletion | No | No | No | Yes |
| Subscription required | No | Yes | Yes | No |
| Native iCloud (no proprietary sync) | No | No | No | Yes |

---

## Roadmap

- CSV export via ShareLink
- Live Activity / Dynamic Island (ActivityKit)
- Attendance tracker type with people tagging
- iCloud calendar sharing for family/team tracking
