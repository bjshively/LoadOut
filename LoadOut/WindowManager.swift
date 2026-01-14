//
//  WindowManager.swift
//  LoadOut
//
//  Created by Brad Shively on 1/13/26.
//

import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import SwiftUI

struct RunningApp: Identifiable, Hashable {
    let id: pid_t
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage?
    var isSelected: Bool = false

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.id == rhs.id
    }
}

struct WindowInfo: Codable, Identifiable {
    let id: UUID
    let bundleIdentifier: String
    let appName: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(bundleIdentifier: String, appName: String, x: Double, y: Double, width: Double, height: Double) {
        self.id = UUID()
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

struct LaunchItem: Codable, Identifiable, Equatable {
    let id: UUID
    var path: String  // URL or file path

    init(path: String) {
        self.id = UUID()
        self.path = LaunchItem.normalizePath(path)
    }

    /// Detects if input looks like a URL and adds https:// if needed
    private static func normalizePath(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Already has a protocol
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }

        // Check if it looks like a URL (has domain-like pattern)
        if looksLikeURL(trimmed) {
            return "https://\(trimmed)"
        }

        return trimmed
    }

    /// Checks if the string looks like a URL without protocol
    private static func looksLikeURL(_ input: String) -> Bool {
        // Common TLDs to detect
        let tlds = [".com", ".org", ".net", ".io", ".dev", ".app", ".co", ".edu", ".gov", ".me", ".tv", ".info", ".biz", ".uk", ".ca", ".au", ".de", ".fr", ".jp"]

        // Check for www. prefix
        if input.lowercased().hasPrefix("www.") {
            return true
        }

        // Check for common TLDs
        let lowercased = input.lowercased()
        for tld in tlds {
            if lowercased.contains(tld) {
                // Make sure it's not a file path containing these strings
                // File paths typically start with / or ~
                if !input.hasPrefix("/") && !input.hasPrefix("~") {
                    return true
                }
            }
        }

        return false
    }

    var isURL: Bool {
        path.hasPrefix("http://") || path.hasPrefix("https://")
    }

    var displayName: String {
        if isURL {
            // Extract domain from URL
            if let url = URL(string: path), let host = url.host {
                return host
            }
            return path
        } else {
            // Get filename from path
            return (path as NSString).lastPathComponent
        }
    }

    var icon: String {
        if isURL {
            return "globe"
        } else if path.hasSuffix("/") {
            return "folder"
        } else {
            return "doc"
        }
    }
}

struct Preset: Codable, Identifiable {
    let id: UUID
    var name: String
    var windows: [WindowInfo]
    var launchItems: [LaunchItem]

    init(name: String, windows: [WindowInfo], launchItems: [LaunchItem] = []) {
        self.id = UUID()
        self.name = name
        self.windows = windows
        self.launchItems = launchItems
    }
}

class WindowManager: ObservableObject {
    @Published var runningApps: [RunningApp] = []
    @Published var presets: [Preset] = []
    @Published var accessibilityEnabled: Bool = false

    @Published var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }

    @Published var hideDockIcon: Bool {
        didSet {
            updateDockIconVisibility()
            UserDefaults.standard.set(hideDockIcon, forKey: hideDockIconKey)
        }
    }

    @Published var hasSeenOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenOnboarding, forKey: hasSeenOnboardingKey)
        }
    }

    private let presetsKey = "savedPresets"
    private let hideDockIconKey = "hideDockIcon"
    private let hasSeenOnboardingKey = "hasSeenOnboarding"

    init() {
        // Load settings before other initialization
        self.hideDockIcon = UserDefaults.standard.bool(forKey: hideDockIconKey)
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: hasSeenOnboardingKey)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        checkAccessibilityPermissions()
        loadPresets()
        refreshRunningApps()

        // Apply dock icon setting on launch
        updateDockIconVisibility()
    }

    // MARK: - Settings

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }

    private func updateDockIconVisibility() {
        if hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            // Re-activate the app to show in dock immediately
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Preset Reordering

    func movePreset(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        persistPresets()
    }

    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
    }

    func refreshRunningApps() {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications

        runningApps = apps
            .filter { $0.activationPolicy == .regular && $0.localizedName != nil }
            .filter { $0.localizedName != "LoadOut" } // Exclude ourselves
            .map { app in
                RunningApp(
                    id: app.processIdentifier,
                    name: app.localizedName ?? "Unknown",
                    bundleIdentifier: app.bundleIdentifier,
                    icon: app.icon
                )
            }
            .filter { appHasWindows($0) } // Only show apps with visible windows
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    func appHasWindows(_ app: RunningApp) -> Bool {
        let appElement = AXUIElementCreateApplication(app.id)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              !windows.isEmpty else {
            return false
        }
        return true
    }

    func captureWindowPosition(for app: RunningApp) -> WindowInfo? {
        guard let bundleId = app.bundleIdentifier else { return nil }

        let appElement = AXUIElementCreateApplication(app.id)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              let firstWindow = windows.first else {
            return nil
        }

        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        AXUIElementCopyAttributeValue(firstWindow, kAXPositionAttribute as CFString, &positionRef)
        AXUIElementCopyAttributeValue(firstWindow, kAXSizeAttribute as CFString, &sizeRef)

        var position = CGPoint.zero
        var size = CGSize.zero

        if let positionRef = positionRef {
            AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        }

        if let sizeRef = sizeRef {
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        }

        return WindowInfo(
            bundleIdentifier: bundleId,
            appName: app.name,
            x: Double(position.x),
            y: Double(position.y),
            width: Double(size.width),
            height: Double(size.height)
        )
    }

    func captureSelectedApps() -> [WindowInfo] {
        var windowInfos: [WindowInfo] = []

        for app in runningApps where app.isSelected {
            if let info = captureWindowPosition(for: app) {
                windowInfos.append(info)
            }
        }

        return windowInfos
    }

    func savePreset(name: String, launchItems: [LaunchItem] = []) {
        let windows = captureSelectedApps()
        guard !windows.isEmpty else { return }

        let preset = Preset(name: name, windows: windows, launchItems: launchItems)
        presets.append(preset)
        persistPresets()

        // Clear selections
        for i in runningApps.indices {
            runningApps[i].isSelected = false
        }
    }

    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        persistPresets()
    }

    func sortPresetsByName() {
        presets.sort { $0.name.lowercased() < $1.name.lowercased() }
        persistPresets()
    }

    func renamePreset(_ preset: Preset, to newName: String) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = newName
        persistPresets()
    }

    func updatePresetPositions(_ preset: Preset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }

        // Recapture window positions for the apps in this preset
        var updatedWindows: [WindowInfo] = []
        let workspace = NSWorkspace.shared

        for existingWindow in preset.windows {
            // Find the running app matching this window's bundle ID
            if let app = workspace.runningApplications.first(where: {
                $0.bundleIdentifier == existingWindow.bundleIdentifier
            }) {
                let runningApp = RunningApp(
                    id: app.processIdentifier,
                    name: app.localizedName ?? existingWindow.appName,
                    bundleIdentifier: app.bundleIdentifier,
                    icon: app.icon
                )
                if let newPosition = captureWindowPosition(for: runningApp) {
                    updatedWindows.append(newPosition)
                } else {
                    // App is running but couldn't capture - keep old position
                    updatedWindows.append(existingWindow)
                }
            } else {
                // App not running - keep old position
                updatedWindows.append(existingWindow)
            }
        }

        presets[index].windows = updatedWindows
        persistPresets()
    }

    func addWindowToPreset(_ preset: Preset, from app: RunningApp) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }

        // Don't add duplicates
        guard !presets[index].windows.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }

        if let windowInfo = captureWindowPosition(for: app) {
            presets[index].windows.append(windowInfo)
            persistPresets()
        }
    }

    func removeWindowFromPreset(_ preset: Preset, window: WindowInfo) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].windows.removeAll { $0.id == window.id }
        persistPresets()
    }

    func applyPreset(_ preset: Preset) {
        // Open launch items first
        for item in preset.launchItems {
            openLaunchItem(item)
        }

        // Small delay to let items open before positioning
        let delay = preset.launchItems.isEmpty ? 0.0 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            for windowInfo in preset.windows {
                self.applyWindowPosition(windowInfo)
            }
        }

        // Show feedback toast
        let itemCount = preset.launchItems.count
        let windowCount = preset.windows.count
        ToastWindow.show(presetName: preset.name, windowCount: windowCount, launchItemCount: itemCount)
    }

    private func openLaunchItem(_ item: LaunchItem) {
        let path = item.path

        // Expand tilde in paths
        let expandedPath = (path as NSString).expandingTildeInPath

        if item.isURL {
            // Open URL
            if let url = URL(string: path) {
                NSWorkspace.shared.open(url)
            }
        } else {
            // Open file or folder
            let fileURL = URL(fileURLWithPath: expandedPath)
            NSWorkspace.shared.open(fileURL)
        }
    }

    func addLaunchItem(to preset: Preset, path: String) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        let item = LaunchItem(path: path)
        presets[index].launchItems.append(item)
        persistPresets()
    }

    func removeLaunchItem(from preset: Preset, item: LaunchItem) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].launchItems.removeAll { $0.id == item.id }
        persistPresets()
    }

    private func applyWindowPosition(_ info: WindowInfo) {
        let workspace = NSWorkspace.shared

        if let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == info.bundleIdentifier }) {
            // App is running - activate it first to unhide windows
            app.activate()

            // Give the app a moment to activate and show its window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.setWindowPosition(for: app, info: info)
            }
        } else {
            // App is not running, launch it
            launchApp(bundleIdentifier: info.bundleIdentifier) { [weak self] pid in
                if let pid = pid {
                    // Wait a moment for the app to create its window
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let app = workspace.runningApplications.first(where: { $0.processIdentifier == pid }) {
                            self?.setWindowPosition(for: app, info: info)
                        }
                    }
                }
            }
        }
    }

    private func setWindowPosition(for app: NSRunningApplication, info: WindowInfo, retryCount: Int = 0) {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        let windows = windowsRef as? [AXUIElement] ?? []

        // If no windows found, the app window might be closed - try to reopen it
        if result != .success || windows.isEmpty {
            if retryCount == 0 {
                // First attempt: try unhide and activate
                app.unhide()
                app.activate()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.setWindowPosition(for: app, info: info, retryCount: 1)
                }
            } else if retryCount == 1 {
                // Second attempt: try to open the app again (this often reopens the main window)
                if let bundleId = app.bundleIdentifier,
                   let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.setWindowPosition(for: app, info: info, retryCount: 2)
                        }
                    }
                }
            } else if retryCount == 2 {
                // Third attempt: try AppleScript to tell the app to reopen
                reopenAppWindow(bundleIdentifier: app.bundleIdentifier ?? "") { [weak self] in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.positionWindow(pid: pid, info: info)
                    }
                }
            }
            return
        }

        positionWindow(pid: pid, info: info)
    }

    private func reopenAppWindow(bundleIdentifier: String, completion: @escaping () -> Void) {
        // Use AppleScript to tell the app to reopen/activate
        let script = """
        tell application id "\(bundleIdentifier)"
            activate
            reopen
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
        completion()
    }

    private func positionWindow(pid: pid_t, info: WindowInfo) {
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              let firstWindow = windows.first else {
            return
        }

        // Check if window is minimized and unminimize it
        var minimizedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(firstWindow, kAXMinimizedAttribute as CFString, &minimizedRef) == .success {
            if let minimized = minimizedRef as? Bool, minimized {
                AXUIElementSetAttributeValue(firstWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                // Wait for unminimize animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.setWindowFrame(window: firstWindow, info: info)
                }
                return
            }
        }

        setWindowFrame(window: firstWindow, info: info)
    }

    private func setWindowFrame(window: AXUIElement, info: WindowInfo) {
        // Set position
        var position = CGPoint(x: info.x, y: info.y)
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }

        // Set size
        var size = CGSize(width: info.width, height: info.height)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    private func launchApp(bundleIdentifier: String, completion: @escaping (pid_t?) -> Void) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            completion(nil)
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false

        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
            DispatchQueue.main.async {
                completion(app?.processIdentifier)
            }
        }
    }

    private func persistPresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }

    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = decoded
        }
    }

    func toggleSelection(for app: RunningApp) {
        if let index = runningApps.firstIndex(where: { $0.id == app.id }) {
            runningApps[index].isSelected.toggle()
        }
    }

    func selectAllApps() {
        for i in runningApps.indices {
            // Only select apps that have windows
            if appHasWindows(runningApps[i]) {
                runningApps[i].isSelected = true
            }
        }
    }
}
