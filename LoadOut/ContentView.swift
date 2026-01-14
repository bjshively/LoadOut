//
//  ContentView.swift
//  LoadOut
//
//  Created by Brad Shively on 1/13/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var windowManager: WindowManager
    @State private var presetName: String = ""
    @State private var showingSaveSheet: Bool = false

    var selectedCount: Int {
        windowManager.runningApps.filter { $0.isSelected }.count
    }

    var body: some View {
        HSplitView {
            // Left panel - Running Apps
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Running Apps")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        windowManager.refreshRunningApps()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh app list")
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Accessibility warning
                if !windowManager.accessibilityEnabled {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility access required")
                            .font(.caption)
                        Spacer()
                        Button("Grant Access") {
                            windowManager.checkAccessibilityPermissions()
                        }
                        .font(.caption)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                }

                // App list
                List {
                    ForEach(windowManager.runningApps) { app in
                        AppRowView(app: app) {
                            windowManager.toggleSelection(for: app)
                        }
                    }
                }
                .listStyle(.plain)

                Divider()

                // Save button
                HStack {
                    Text("\(selectedCount) app(s) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Save as Preset...") {
                        showingSaveSheet = true
                    }
                    .disabled(selectedCount == 0)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 280, idealWidth: 320)

            // Right panel - Saved Presets
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Saved Presets")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                if windowManager.presets.isEmpty {
                    VStack {
                        Spacer()
                        Text("No presets saved yet")
                            .foregroundColor(.secondary)
                        Text("Select apps and save a preset to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(windowManager.presets) { preset in
                            PresetRowView(preset: preset) {
                                windowManager.applyPreset(preset)
                            } onDelete: {
                                windowManager.deletePreset(preset)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 280, idealWidth: 320)
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showingSaveSheet) {
            SavePresetSheet(presetName: $presetName) {
                if !presetName.trimmingCharacters(in: .whitespaces).isEmpty {
                    windowManager.savePreset(name: presetName)
                    presetName = ""
                    showingSaveSheet = false
                }
            } onCancel: {
                presetName = ""
                showingSaveSheet = false
            }
        }
    }
}

struct AppRowView: View {
    let app: RunningApp
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Image(systemName: app.isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(app.isSelected ? .accentColor : .secondary)
                .font(.title2)

            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }

            // App name
            VStack(alignment: .leading) {
                Text(app.name)
                    .fontWeight(.medium)
                if let bundleId = app.bundleIdentifier {
                    Text(bundleId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

struct PresetRowView: View {
    let preset: Preset
    let onApply: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .fontWeight(.medium)
                Text("\(preset.windows.count) window(s): \(preset.windows.map { $0.appName }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    Button(action: onApply) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Apply this preset")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .help("Delete this preset")
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct SavePresetSheet: View {
    @Binding var presetName: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Save Preset")
                .font(.headline)

            TextField("Preset name (e.g., Development)", text: $presetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }
}

#Preview {
    ContentView(windowManager: WindowManager())
}
