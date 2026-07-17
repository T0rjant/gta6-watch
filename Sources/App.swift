// GTA VI Watch — Copyright (C) 2026 Torjant
// SPDX-License-Identifier: AGPL-3.0-or-later
// This program is free software under the GNU AGPL v3; see LICENSE.

import SwiftUI
import AppKit

@main
struct GTA6WatchApp: App {
    @StateObject private var store = AppStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("GTA VI Watch", id: "dashboard") {
            DashboardView(store: store)
                .onAppear { StoreHolder.shared = store; store.start() }
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarContent(store: store)
        } label: {
            // Cours affiché en direct dans la barre de menus
            let q = store.quote
            if q.price > 0 {
                Text("Ⅵ \(store.money(q.price)) \(q.isUp ? "▲" : "▼")")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            } else {
                Text("Ⅵ TTWO")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Permet à l'AppDelegate d'atteindre le store créé par SwiftUI.
enum StoreHolder {
    @MainActor static var shared: AppStore?
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // L'app continue de tourner en barre de menus quand on ferme la fenêtre.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // Un clic sur l'icône du Dock rouvre la fenêtre.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}
