import Foundation
import UserNotifications

/// Notifications macOS natives, avec repli sur osascript si l'autorisation échoue
/// (ce qui peut arriver pour une app signée en ad hoc).
enum Notifier {
    private static var useFallback = false

    static func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else { useFallback = true; return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if !granted { useFallback = true }
        }
    }

    static func notify(title: String, body: String, link: String? = nil) {
        if useFallback {
            fallbackNotify(title: title, body: body)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let link { content.userInfo = ["link": link] }
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { error in
            if error != nil { fallbackNotify(title: title, body: body) }
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
