//
//  LoadOutApp.swift
//  LoadOut
//
//  Created by Brad Shively on 1/13/26.
//

import SwiftUI
import Combine

@main
struct LoadOutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(windowManager: appDelegate.windowManager)
        }
        .defaultSize(width: 700, height: 500)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowManager = WindowManager()
    var menuBarController: MenuBarController?
    private var cancellables = Set<AnyCancellable>()
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(windowManager: windowManager)

        // Update menu when presets change
        windowManager.$presets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.menuBarController?.updateMenu()
            }
            .store(in: &cancellables)

        // Setup global keyboard shortcuts (CTRL+OPT+1-9)
        setupGlobalShortcuts()
    }

    private func setupGlobalShortcuts() {
        let requiredFlags: NSEvent.ModifierFlags = [.control, .option]

        // Monitor for when app is NOT frontmost
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleShortcutEvent(event, requiredFlags: requiredFlags)
        }

        // Monitor for when app IS frontmost
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleShortcutEvent(event, requiredFlags: requiredFlags) == true {
                return nil  // Consume the event
            }
            return event
        }
    }

    private func handleShortcutEvent(_ event: NSEvent, requiredFlags: NSEvent.ModifierFlags) -> Bool {
        // Check that CTRL+OPT are pressed (and not CMD or SHIFT)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == requiredFlags else { return false }

        // Check for number keys 1-9
        guard let characters = event.charactersIgnoringModifiers,
              let char = characters.first,
              let number = Int(String(char)),
              number >= 1 && number <= 9 else {
            return false
        }

        // Apply the preset at index (number - 1)
        let index = number - 1
        guard index < windowManager.presets.count else { return false }

        let preset = windowManager.presets[index]
        DispatchQueue.main.async { [weak self] in
            self?.windowManager.applyPreset(preset)
        }

        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up monitors
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            menuBarController?.showMainWindow()
        }
        return true
    }
}
