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
    var windowIndex: Int        // Index in app's window list at capture time (for multi-window support)

    init(bundleIdentifier: String, appName: String, x: Double, y: Double, width: Double, height: Double, windowIndex: Int = 0) {
        self.id = UUID()
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.windowIndex = windowIndex
    }

    // Custom decoder for backward compatibility with existing presets
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        appName = try container.decode(String.self, forKey: .appName)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        windowIndex = try container.decodeIfPresent(Int.self, forKey: .windowIndex) ?? 0
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
        didSet {
            if !isRevertingLaunchAtLogin {
                updateLaunchAtLogin()
            }
        }
    }
    private var isRevertingLaunchAtLogin = false

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

    @Published var autoCheckForUpdates: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckForUpdates, forKey: autoCheckForUpdatesKey)
        }
    }

    private let presetsKey = "savedPresets"
    private let hideDockIconKey = "hideDockIcon"
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    private let autoCheckForUpdatesKey = "SUEnableAutomaticChecks"  // Sparkle's standard key

    init() {
        // Load settings before other initialization
        self.hideDockIcon = UserDefaults.standard.bool(forKey: hideDockIconKey)
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: hasSeenOnboardingKey)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        // Default to true for auto-updates if not set
        self.autoCheckForUpdates = UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true

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
            // Revert the toggle since it failed
            isRevertingLaunchAtLogin = true
            launchAtLogin = !launchAtLogin
            isRevertingLaunchAtLogin = false

            ToastWindow.showError(
                title: "Settings Error",
                message: "Failed to update launch at login setting"
            )
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

    /// Find the best matching window for a WindowInfo using score-based matching
    /// - Parameters:
    ///   - info: The WindowInfo to match
    ///   - windows: Available windows to match against
    ///   - usedIndices: Set of window indices already matched (to avoid double-matching)
    /// - Returns: The best matching window and its index, or nil if no match
    private func findMatchingWindow(for info: WindowInfo, in windows: [AXUIElement], usedIndices: Set<Int>) -> (window: AXUIElement, index: Int)? {
        var bestMatch: (window: AXUIElement, index: Int, score: Int)?

        for (index, window) in windows.enumerated() {
            // Skip already-used windows
            guard !usedIndices.contains(index) else { continue }

            // Skip tiny windows
            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success {
                var size = CGSize.zero
                AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
                if size.width < 100 || size.height < 100 {
                    continue
                }
            }

            var score = 0

            // Score based on window index matching
            if index == info.windowIndex {
                score += 30
            }

            // Score bonus if this is the main window (for legacy presets)
            var mainRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMainAttribute as CFString, &mainRef) == .success,
               let isMain = mainRef as? Bool, isMain {
                score += 20
            }

            // Track best match
            if bestMatch == nil || score > bestMatch!.score {
                bestMatch = (window, index, score)
            }
        }

        if let match = bestMatch {
            return (match.window, match.index)
        }
        return nil
    }

    /// Find the main window from a list of windows - prefers AXMain, falls back to largest window
    private func findMainWindow(from windows: [AXUIElement]) -> AXUIElement? {
        // First, try to find a window with AXMain = true
        for window in windows {
            var mainRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMainAttribute as CFString, &mainRef) == .success,
               let isMain = mainRef as? Bool, isMain {
                return window
            }
        }

        // If no AXMain window, find the largest window (by area, excluding tiny windows like toolbars)
        var largestArea: CGFloat = 0
        var mainWindow: AXUIElement?
        for window in windows {
            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success {
                var size = CGSize.zero
                AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
                let area = size.width * size.height
                // Ignore tiny windows (toolbars, menubars, etc.)
                if size.height > 100 && area > largestArea {
                    largestArea = area
                    mainWindow = window
                }
            }
        }
        return mainWindow
    }

    func captureWindowPosition(for app: RunningApp) -> WindowInfo? {
        guard let bundleId = app.bundleIdentifier else { return nil }

        let appElement = AXUIElementCreateApplication(app.id)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              let mainWindow = findMainWindow(from: windows) else {
            return nil
        }

        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        AXUIElementCopyAttributeValue(mainWindow, kAXPositionAttribute as CFString, &positionRef)
        AXUIElementCopyAttributeValue(mainWindow, kAXSizeAttribute as CFString, &sizeRef)

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
            height: Double(size.height),
            windowIndex: 0
        )
    }

    /// Captures ALL windows for an app (not just the main window)
    func captureAllWindowPositions(for app: RunningApp) -> [WindowInfo] {
        guard let bundleId = app.bundleIdentifier else { return [] }

        let appElement = AXUIElementCreateApplication(app.id)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return []
        }

        var windowInfos: [WindowInfo] = []

        for (index, window) in windows.enumerated() {
            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?

            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

            var position = CGPoint.zero
            var size = CGSize.zero

            if let positionRef = positionRef {
                AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
            }

            if let sizeRef = sizeRef {
                AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
            }

            // Skip tiny windows (toolbars, palettes, etc.) - require minimum 100px in both dimensions
            if size.width < 100 || size.height < 100 {
                continue
            }

            let info = WindowInfo(
                bundleIdentifier: bundleId,
                appName: app.name,
                x: Double(position.x),
                y: Double(position.y),
                width: Double(size.width),
                height: Double(size.height),
                windowIndex: index
            )

            windowInfos.append(info)
        }

        return windowInfos
    }

    func captureSelectedApps() -> [WindowInfo] {
        var windowInfos: [WindowInfo] = []

        for app in runningApps where app.isSelected {
            // Capture ALL windows for each selected app
            let appWindows = captureAllWindowPositions(for: app)
            windowInfos.append(contentsOf: appWindows)
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

        // Group existing windows by bundleIdentifier
        var existingByApp: [String: [WindowInfo]] = [:]
        for window in preset.windows {
            existingByApp[window.bundleIdentifier, default: []].append(window)
        }

        // Recapture window positions for all apps in this preset
        var updatedWindows: [WindowInfo] = []
        let workspace = NSWorkspace.shared

        for (bundleId, existingWindows) in existingByApp {
            // Find the running app matching this bundle ID
            if let app = workspace.runningApplications.first(where: {
                $0.bundleIdentifier == bundleId
            }) {
                let runningApp = RunningApp(
                    id: app.processIdentifier,
                    name: app.localizedName ?? existingWindows.first?.appName ?? "Unknown",
                    bundleIdentifier: app.bundleIdentifier,
                    icon: app.icon
                )

                // Capture all current windows for this app
                let currentWindows = captureAllWindowPositions(for: runningApp)

                if currentWindows.isEmpty {
                    // App is running but no windows - keep old positions
                    updatedWindows.append(contentsOf: existingWindows)
                } else {
                    // Match and update: for each existing window, find best match in current windows
                    var usedCurrentIndices = Set<Int>()

                    for existingWindow in existingWindows {
                        var bestMatch: (index: Int, window: WindowInfo, score: Int)?

                        for (i, current) in currentWindows.enumerated() {
                            guard !usedCurrentIndices.contains(i) else { continue }

                            var score = 0

                            // Score by index match
                            if existingWindow.windowIndex == current.windowIndex {
                                score += 30
                            }

                            if bestMatch == nil || score > bestMatch!.score {
                                bestMatch = (i, current, score)
                            }
                        }

                        if let match = bestMatch {
                            usedCurrentIndices.insert(match.index)
                            updatedWindows.append(match.window)
                        } else {
                            // Find any remaining unused window as fallback
                            var foundFallback = false
                            for (i, window) in currentWindows.enumerated() where !usedCurrentIndices.contains(i) {
                                usedCurrentIndices.insert(i)
                                updatedWindows.append(window)
                                foundFallback = true
                                break
                            }
                            if !foundFallback {
                                // No more windows available - keep old position
                                updatedWindows.append(existingWindow)
                            }
                        }
                    }
                }
            } else {
                // App not running - keep old positions
                updatedWindows.append(contentsOf: existingWindows)
            }
        }

        presets[index].windows = updatedWindows
        persistPresets()
    }

    func addWindowToPreset(_ preset: Preset, from app: RunningApp) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }

        // Capture all windows for this app
        let newWindows = captureAllWindowPositions(for: app)

        for newWindow in newWindows {
            // Check for exact duplicates (same position)
            let isDuplicate = presets[index].windows.contains { existing in
                existing.bundleIdentifier == newWindow.bundleIdentifier &&
                abs(existing.x - newWindow.x) < 10 &&
                abs(existing.y - newWindow.y) < 10
            }

            if !isDuplicate {
                presets[index].windows.append(newWindow)
            }
        }

        persistPresets()
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

        // Group windows by bundleIdentifier for batch processing
        var windowsByApp: [String: [WindowInfo]] = [:]
        for windowInfo in preset.windows {
            windowsByApp[windowInfo.bundleIdentifier, default: []].append(windowInfo)
        }

        // Small delay to let items open before positioning
        let delay = preset.launchItems.isEmpty ? 0.0 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            for (bundleId, windowInfos) in windowsByApp {
                self.applyWindowPositions(bundleIdentifier: bundleId, windowInfos: windowInfos)
            }
        }

        // Show feedback toast
        let itemCount = preset.launchItems.count
        let windowCount = preset.windows.count
        ToastWindow.show(presetName: preset.name, windowCount: windowCount, launchItemCount: itemCount)
    }

    /// Apply multiple window positions for a single app
    private func applyWindowPositions(bundleIdentifier: String, windowInfos: [WindowInfo]) {
        let workspace = NSWorkspace.shared

        if let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            // App is running - activate it first to unhide windows
            app.activate()

            // Give the app a moment to activate and show its window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.setWindowPositions(for: app, windowInfos: windowInfos)
            }
        } else {
            // App is not running, launch it
            launchApp(bundleIdentifier: bundleIdentifier) { [weak self] pid in
                if let pid = pid {
                    // Wait a moment for the app to create its window
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let app = workspace.runningApplications.first(where: { $0.processIdentifier == pid }) {
                            self?.setWindowPositions(for: app, windowInfos: windowInfos)
                        }
                    }
                }
            }
        }
    }

    /// Set positions for multiple windows of a single app
    private func setWindowPositions(for app: NSRunningApplication, windowInfos: [WindowInfo], retryCount: Int = 0) {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        let windows = windowsRef as? [AXUIElement] ?? []

        // If no windows found, the app window might be closed - try to reopen it
        if result != .success || windows.isEmpty {
            if retryCount == 0 {
                app.unhide()
                app.activate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.setWindowPositions(for: app, windowInfos: windowInfos, retryCount: 1)
                }
            } else if retryCount == 1 {
                if let bundleId = app.bundleIdentifier,
                   let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.setWindowPositions(for: app, windowInfos: windowInfos, retryCount: 2)
                        }
                    }
                }
            } else if retryCount == 2 {
                reopenAppWindow(bundleIdentifier: app.bundleIdentifier ?? "") { [weak self] in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.positionMultipleWindows(for: app, windowInfos: windowInfos)
                    }
                }
            }
            return
        }

        positionMultipleWindows(for: app, windowInfos: windowInfos)
    }

    /// Create additional windows for an app using Cmd+N keyboard simulation
    private func createAdditionalWindows(for app: NSRunningApplication, count: Int, completion: @escaping () -> Void) {
        guard count > 0 else {
            completion()
            return
        }

        // Activate the app first
        app.activate()

        // Send Cmd+N for each additional window needed, with delays between
        var windowsCreated = 0

        func createNextWindow() {
            guard windowsCreated < count else {
                // Wait a moment for windows to fully initialize, then complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    completion()
                }
                return
            }

            // Send Cmd+N to create a new window
            let keyCode: CGKeyCode = 45 // 'n' key
            if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                keyDown.flags = .maskCommand
                keyUp.flags = .maskCommand
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }

            windowsCreated += 1

            // Wait for the window to be created before creating the next one
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                createNextWindow()
            }
        }

        // Start creating windows after a brief delay to ensure app is active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            createNextWindow()
        }
    }

    /// Position multiple windows for an app using score-based matching
    /// Creates additional windows if needed to match the preset
    private func positionMultipleWindows(for app: NSRunningApplication, windowInfos: [WindowInfo]) {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        let windows = (windowsRef as? [AXUIElement]) ?? []

        // Filter to only count "real" windows (not tiny toolbars/palettes)
        let realWindows = windows.filter { window in
            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success {
                var size = CGSize.zero
                AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
                return size.width >= 100 && size.height >= 100
            }
            return true // Include if we can't determine size
        }

        let neededWindows = windowInfos.count
        let existingWindows = realWindows.count

        if existingWindows < neededWindows {
            // Create additional windows using Cmd+N, then position all
            createAdditionalWindows(for: app, count: neededWindows - existingWindows) { [weak self] in
                self?.doPositionWindows(pid: pid, windowInfos: windowInfos)
            }
        } else {
            doPositionWindows(pid: pid, windowInfos: windowInfos)
        }
    }

    /// Actually position windows after ensuring we have enough of them
    private func doPositionWindows(pid: pid_t, windowInfos: [WindowInfo]) {
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              !windows.isEmpty else {
            #if DEBUG
            if let info = windowInfos.first {
                print("Could not position windows for \(info.appName): no windows found after all retries")
            }
            #endif
            return
        }

        var usedIndices = Set<Int>()

        for info in windowInfos {
            // Find the best matching window that hasn't been used yet
            if let match = findMatchingWindow(for: info, in: windows, usedIndices: usedIndices) {
                usedIndices.insert(match.index)
                positionSingleWindow(window: match.window, info: info, pid: pid)
            } else if let fallbackWindow = findMainWindow(from: windows.enumerated().filter { !usedIndices.contains($0.offset) }.map { $0.element }) {
                // Fallback: use main window if no match found (for legacy presets)
                if let fallbackIndex = windows.firstIndex(where: { $0 == fallbackWindow }) {
                    usedIndices.insert(fallbackIndex)
                }
                positionSingleWindow(window: fallbackWindow, info: info, pid: pid)
            }
        }
    }

    /// Position a single specific window
    private func positionSingleWindow(window: AXUIElement, info: WindowInfo, pid: pid_t) {
        // Get current window position and size for full-screen detection
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        var windowPosition = CGPoint.zero
        var windowSize = CGSize.zero
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
           AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success {
            AXValueGetValue(positionRef as! AXValue, .cgPoint, &windowPosition)
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &windowSize)
        }

        // Check if window is in full-screen mode
        var isFullscreen = false

        // Method 1: Check AXFullScreen attribute
        var fullscreenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fullscreenRef) == .success {
            isFullscreen = (fullscreenRef as? Bool) ?? false
        }

        // Method 2: Check if window bounds match screen bounds (fallback detection)
        if !isFullscreen {
            for screen in NSScreen.screens {
                let screenFrame = screen.frame
                let isAtOrigin = windowPosition.x == screenFrame.origin.x && windowPosition.y == 0
                let matchesScreenSize = abs(windowSize.width - screenFrame.size.width) < 2 &&
                                       abs(windowSize.height - screenFrame.size.height) < 50
                if isAtOrigin && matchesScreenSize {
                    isFullscreen = true
                    break
                }
            }
        }

        if isFullscreen {
            // Activate the app first
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.activate()
            }

            // Use CGEvent to send Cmd+Ctrl+F to exit full-screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                let keyCode: CGKeyCode = 3 // 'f' key
                if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
                   let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                    keyDown.flags = [.maskCommand, .maskControl]
                    keyUp.flags = [.maskCommand, .maskControl]
                    keyDown.post(tap: .cghidEventTap)
                    keyUp.post(tap: .cghidEventTap)
                }

                // Wait for full-screen exit animation then position
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.setWindowFrame(window: window, info: info)
                }
            }
            return
        }

        // Check if window is minimized and unminimize it
        var minimizedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef) == .success {
            if let minimized = minimizedRef as? Bool, minimized {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                // Wait for unminimize animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.setWindowFrame(window: window, info: info)
                }
                return
            }
        }

        setWindowFrame(window: window, info: info)
    }

    private func openLaunchItem(_ item: LaunchItem) {
        let path = item.path

        // Expand tilde in paths
        let expandedPath = (path as NSString).expandingTildeInPath

        if item.isURL {
            // Open URL
            guard let url = URL(string: path) else {
                ToastWindow.showError(title: "Invalid URL", message: item.displayName)
                return
            }
            if !NSWorkspace.shared.open(url) {
                ToastWindow.showError(title: "Failed to Open", message: item.displayName)
            }
        } else {
            // Check if file/folder exists
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: expandedPath) else {
                ToastWindow.showError(title: "File Not Found", message: item.displayName)
                return
            }

            // Open file or folder
            let fileURL = URL(fileURLWithPath: expandedPath)
            if !NSWorkspace.shared.open(fileURL) {
                ToastWindow.showError(title: "Failed to Open", message: item.displayName)
            }
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
            if let error = error {
                // Log AppleScript errors but don't surface to user since this is a fallback mechanism
                #if DEBUG
                print("AppleScript error for \(bundleIdentifier): \(error)")
                #endif
            }
        }
        completion()
    }

    private func setWindowFrame(window: AXUIElement, info: WindowInfo) {
        // Adjust position to ensure window is visible on current screen configuration
        let adjustedInfo = adjustWindowInfoForCurrentScreens(info)

        // Set position
        var position = CGPoint(x: adjustedInfo.x, y: adjustedInfo.y)
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }

        // Set size
        var size = CGSize(width: adjustedInfo.width, height: adjustedInfo.height)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    /// Adjusts window position/size to ensure it's visible on the current screen configuration
    private func adjustWindowInfoForCurrentScreens(_ info: WindowInfo) -> WindowInfo {
        // Check if window origin is meaningfully visible on any screen
        for screen in NSScreen.screens {
            let screenFrame = screen.frame

            // NSScreen uses bottom-left origin, Accessibility uses top-left origin
            let mainScreenHeight = NSScreen.screens.first?.frame.height ?? screenFrame.height

            // Calculate the screen bounds in Accessibility (top-left origin) coordinates
            let screenMinX = screenFrame.origin.x
            let screenMaxX = screenFrame.origin.x + screenFrame.width
            let screenMinY = mainScreenHeight - screenFrame.origin.y - screenFrame.height
            let screenMaxY = mainScreenHeight - screenFrame.origin.y

            // Require at least 200px of space to the right/bottom so window is usable
            let minVisibleSpace: CGFloat = 200
            let effectiveMaxX = screenMaxX - minVisibleSpace
            let effectiveMaxY = screenMaxY - minVisibleSpace

            let originOnScreenX = info.x >= screenMinX && info.x <= effectiveMaxX
            let originOnScreenY = info.y >= screenMinY && info.y <= effectiveMaxY

            if originOnScreenX && originOnScreenY {
                return info
            }
        }

        // Window is not visible on any screen - reposition to primary screen
        guard let primaryScreen = NSScreen.main ?? NSScreen.screens.first else {
            return info
        }

        let primaryFrame = primaryScreen.frame

        // Calculate new position on primary screen, with some offset from top-left
        let newX = primaryFrame.origin.x + 50
        let newY: Double = 50  // Top of screen in flipped coordinates
        var newWidth = info.width
        var newHeight = info.height

        // Ensure window fits on screen (scale down if necessary)
        let maxWidth = primaryFrame.width - 100
        let maxHeight = primaryFrame.height - 100

        if newWidth > maxWidth {
            newWidth = maxWidth
        }
        if newHeight > maxHeight {
            newHeight = maxHeight
        }

        return WindowInfo(
            bundleIdentifier: info.bundleIdentifier,
            appName: info.appName,
            x: newX,
            y: newY,
            width: newWidth,
            height: newHeight
        )
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
