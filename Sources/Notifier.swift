// GTA VI Watch — Copyright (C) 2026 Torjant
// SPDX-License-Identifier: AGPL-3.0-or-later
// This program is free software under the GNU AGPL v3; see LICENSE.

import Foundation
import UserNotifications

/// Reçoit les interactions avec les notifications : un clic ouvre l'article ou la vidéo liée.
final class NotifDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotifDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let link = response.notification.request.content.userInfo["link"] as? String {
            DispatchQueue.main.async { SafeOpen.open(link) }
        }
        completionHandler()
    }

    // Affiche aussi la bannière quand l'app est au premier plan
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

/// Notifications macOS natives (cliquables), avec repli AppleScript en dernier recours
/// si la permission est refusée — ce repli n'est pas cliquable, d'où l'importance
/// d'autoriser les notifications dans Réglages Système → Notifications → GTA VI Watch.
enum Notifier {
    static func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = NotifDelegate.shared
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
    }

    static func notify(title: String, body: String, link: String? = nil) {
        guard Bundle.main.bundleIdentifier != nil else {
            fallbackNotify(title: title, body: body); return
        }
        let center = UNUserNotificationCenter.current()
        // Statut vérifié à chaque envoi : si l'utilisateur autorise après coup
        // dans Réglages Système, l'app repasse aussitôt en natif cliquable.
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                if let link { content.userInfo = ["link": link] }
                let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                center.add(req) { error in
                    if error != nil { fallbackNotify(title: title, body: body) }
                }
            default:
                fallbackNotify(title: title, body: body)
            }
        }
    }

    private static func fallbackNotify(title: String, body: String) {
        let esc = { (s: String) in s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
        let script = "display notification \"\(esc(body))\" with title \"\(esc(title))\" sound name \"Submarine\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        try? task.run()
    }
}
