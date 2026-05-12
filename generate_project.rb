#!/usr/bin/env ruby
# Generates Tracker.xcodeproj with four targets:
#   1. TrackerApp         — iOS 16.0 main app
#   2. TrackerWidgetExtension — iOS 16.0 widget + live activity
#   3. TrackerWatchApp    — watchOS 9.0 watch app
# Run: ruby generate_project.rb

require 'xcodeproj'
require 'fileutils'

PROJECT_NAME  = "Tracker"
BUNDLE_PREFIX = "com.tracker"
ROOT          = __dir__

# ── File sets per target ──────────────────────────────────────────────────────

APP_SOURCES = %w[
  TrackerApp.swift
  Models.swift
  EventKitService.swift
  TrackerStore.swift
  LogStore.swift
  ContentView.swift
  PermissionView.swift
  TodayView.swift
  DashboardView.swift
  TrackersListView.swift
  TrackerIntents.swift
  CSVExporter.swift
  TrackerActivityAttributes.swift
]

WIDGET_SOURCES = %w[
  TrackerWidget.swift
  TrackerActivityAttributes.swift
  Models.swift
]

WATCH_SOURCES = %w[
  TrackerWatchApp.swift
  Models.swift
]

# ── Helper ────────────────────────────────────────────────────────────────────

def add_files(target, group, filenames, root)
  filenames.each do |name|
    path = File.join(root, name)
    unless File.exist?(path)
      puts "  ⚠️  Missing: #{name}"
      next
    end
    ref = group.new_reference(path)
    ref.set_explicit_file_type
    target.add_file_references([ref])
  end
end

def set_build_setting(target, key, value)
  target.build_configurations.each { |c| c.build_settings[key] = value }
end

def apply_base_settings(target, bundle_id, swift_version: "5.9")
  {
    "PRODUCT_BUNDLE_IDENTIFIER"        => bundle_id,
    "SWIFT_VERSION"                    => swift_version,
    "CLANG_ENABLE_MODULES"             => "YES",
    "ENABLE_PREVIEWS"                  => "YES",
    "DEBUG_INFORMATION_FORMAT"         => "dwarf-with-dsym",
    "ASSETCATALOG_COMPILER_APPICON_NAME" => "AppIcon",
  }.each { |k, v| set_build_setting(target, k, v) }
end

# ── Create project ────────────────────────────────────────────────────────────

proj = Xcodeproj::Project.new(File.join(ROOT, "#{PROJECT_NAME}.xcodeproj"))
proj.root_object.attributes["LastUpgradeCheck"] = "1600"
main_group = proj.main_group

# ── Shared assets group ───────────────────────────────────────────────────────

sources_group  = main_group.new_group("Sources",    ROOT)
widget_group   = main_group.new_group("Widget",     ROOT)
watch_group    = main_group.new_group("Watch",      ROOT)

# ── 1. iOS App target ─────────────────────────────────────────────────────────

app_target = proj.new_target(
  :application,
  "TrackerApp",
  :ios,
  "16.0",
  proj.products_group,
  :swift
)

app_target.build_configurations.each do |config|
  config.build_settings.merge!(
    "PRODUCT_BUNDLE_IDENTIFIER"              => "#{BUNDLE_PREFIX}.app",
    "PRODUCT_NAME"                           => "Tracker",
    "SWIFT_VERSION"                          => "5.9",
    "IPHONEOS_DEPLOYMENT_TARGET"             => "16.0",
    "TARGETED_DEVICE_FAMILY"                 => "1,2",
    "INFOPLIST_FILE"                         => "TrackerApp-Info.plist",
    "CODE_SIGN_STYLE"                        => "Automatic",
    "DEVELOPMENT_TEAM"                       => "",
    "ENABLE_PREVIEWS"                        => "YES",
    "SWIFT_EMIT_LOC_STRINGS"                 => "YES",
    "CLANG_ENABLE_MODULES"                   => "YES",
    "ASSETCATALOG_COMPILER_APPICON_NAME"     => "AppIcon",
  )
end

add_files(app_target, sources_group, APP_SOURCES, ROOT)

# ── 2. Widget Extension target ────────────────────────────────────────────────

widget_target = proj.new_target(
  :app_extension,
  "TrackerWidgetExtension",
  :ios,
  "16.0",
  proj.products_group,
  :swift
)

widget_target.build_configurations.each do |config|
  config.build_settings.merge!(
    "PRODUCT_BUNDLE_IDENTIFIER"          => "#{BUNDLE_PREFIX}.app.widget",
    "PRODUCT_NAME"                       => "TrackerWidgetExtension",
    "SWIFT_VERSION"                      => "5.9",
    "IPHONEOS_DEPLOYMENT_TARGET"         => "16.0",
    "INFOPLIST_FILE"                     => "TrackerWidget-Info.plist",
    "CODE_SIGN_STYLE"                    => "Automatic",
    "DEVELOPMENT_TEAM"                   => "",
    "ENABLE_PREVIEWS"                    => "YES",
    "SWIFT_EMIT_LOC_STRINGS"             => "YES",
    "CLANG_ENABLE_MODULES"               => "YES",
    # Required for WidgetKit extensions
    "APPLICATION_EXTENSION_API_ONLY"     => "NO",
  )
end

add_files(widget_target, widget_group, WIDGET_SOURCES, ROOT)

# Embed widget in the app
embed_widgets = app_target.new_copy_files_build_phase("Embed Foundation Extensions")
embed_widgets.symbol_dst_subfolder_spec = :plug_ins
widget_ref = proj.products_group.files.find { |f| f.display_name == "TrackerWidgetExtension.appex" }
if widget_ref
  build_file = embed_widgets.add_file_reference(widget_ref)
  build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
end

# ── 3. watchOS App target ─────────────────────────────────────────────────────

watch_target = proj.new_target(
  :application,
  "TrackerWatchApp",
  :watchos,
  "9.0",
  proj.products_group,
  :swift
)

watch_target.build_configurations.each do |config|
  config.build_settings.merge!(
    "PRODUCT_BUNDLE_IDENTIFIER"              => "#{BUNDLE_PREFIX}.app.watchkitapp",
    "PRODUCT_NAME"                           => "TrackerWatchApp",
    "SWIFT_VERSION"                          => "5.9",
    "WATCHOS_DEPLOYMENT_TARGET"              => "9.0",
    "INFOPLIST_FILE"                         => "TrackerWatch-Info.plist",
    "CODE_SIGN_STYLE"                        => "Automatic",
    "DEVELOPMENT_TEAM"                       => "",
    "ENABLE_PREVIEWS"                        => "YES",
    "SWIFT_EMIT_LOC_STRINGS"                 => "YES",
    "CLANG_ENABLE_MODULES"                   => "YES",
    "TARGETED_DEVICE_FAMILY"                 => "4",
  )
end

add_files(watch_target, watch_group, WATCH_SOURCES, ROOT)

# Embed watch app in the iOS app
embed_watch = app_target.new_copy_files_build_phase("Embed Watch Content")
embed_watch.symbol_dst_subfolder_spec = :products_directory
watch_ref = proj.products_group.files.find { |f| f.display_name == "TrackerWatchApp.app" }
if watch_ref
  build_file = embed_watch.add_file_reference(watch_ref)
  build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
end

# ── Schemes ───────────────────────────────────────────────────────────────────

proj.recreate_user_schemes

# ── Save project ──────────────────────────────────────────────────────────────

proj.save
puts "\n✅  #{PROJECT_NAME}.xcodeproj created."
puts "\nNext steps:"
puts "  1. Set your Team in each target's Signing & Capabilities."
puts "  2. Create TrackerApp-Info.plist, TrackerWidget-Info.plist, TrackerWatch-Info.plist (see below)."
puts "  3. Add an Assets.xcassets with an AppIcon set to each target."
puts "  4. Build on a real device (EventKit needs a device for full Reminders sync)."
puts ""
puts "─── TrackerApp-Info.plist additions ────────────────────────────────────"
puts "  NSRemindersUsageDescription  →  'Tracker uses Reminders to store your data.'"
puts "  NSSupportsLiveActivities     →  YES   (for Dynamic Island / Live Activity)"
puts ""
puts "─── TrackerWidget-Info.plist must include ──────────────────────────────"
puts "  NSExtension / NSExtensionPointIdentifier → com.apple.widgetkit-extension"
