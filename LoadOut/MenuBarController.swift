//
//  MenuBarController.swift
//  LoadOut
//
//  Created by Brad Shively on 1/13/26.
//

import AppKit
import SwiftUI

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}

class MenuBarController {
    private var statusItem: NSStatusItem?
    private var windowManager: WindowManager
    private var mainWindow: NSWindow?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        setupMenuBar()
    }

    private func createMainWindow() -> NSWindow {
        let contentView = ContentView(windowManager: windowManager)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "LoadOut"
        window.center()
        window.setFrameAutosaveName("LoadOutMainWindow")

        return window
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "LoadOut")
            button.image?.isTemplate = true
        }

        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()

        // Presets section
        if windowManager.presets.isEmpty {
            let noPresetsItem = NSMenuItem(title: "No Presets", action: nil, keyEquivalent: "")
            noPresetsItem.isEnabled = false
            menu.addItem(noPresetsItem)
        } else {
            let presetsHeader = NSMenuItem(title: "Apply Preset", action: nil, keyEquivalent: "")
            presetsHeader.isEnabled = false
            menu.addItem(presetsHeader)

            for preset in windowManager.presets {
                let item = NSMenuItem(
                    title: preset.name,
                    action: #selector(applyPreset(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = preset
                item.indentationLevel = 1

                // Add subtitle with app names
                let appNames = preset.windows.map { $0.appName }.joined(separator: ", ")
                item.toolTip = appNames

                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Open main window
        let openItem = NSMenuItem(
            title: "Open LoadOut...",
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit LoadOut",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? Preset else { return }
        windowManager.applyPreset(preset)
    }

    func showMainWindow() {
        openMainWindow()
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        // Check if our window already exists and is usable
        if let window = mainWindow, window.isVisible || !window.isMiniaturized {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Check if a SwiftUI-created window exists
        let contentWindows = NSApp.windows.filter { window in
            window.level == .normal &&
            window.contentView != nil &&
            !window.className.contains("StatusBar")
        }

        if let window = contentWindows.first {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            return
        }

        // No window exists - create one
        mainWindow = createMainWindow()
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
