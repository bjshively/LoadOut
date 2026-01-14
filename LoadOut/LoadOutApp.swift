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

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(windowManager: windowManager)

        // Update menu when presets change
        windowManager.$presets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.menuBarController?.updateMenu()
            }
            .store(in: &cancellables)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            menuBarController?.showMainWindow()
        }
        return true
    }
}
