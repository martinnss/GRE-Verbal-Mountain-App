import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    // MARK: - Notification Slots

    private let notificationSlots: [(hour: Int, minute: Int, id: String, body: String)] = [
        (13, 30, "gre.verbal.daily.1330", "Afternoon check-in 📚 — take a few minutes to study your GRE vocab."),
        (17, 30, "gre.verbal.daily.1730", "Evening warmup 🧠 — keep your streak alive with one quick session."),
        (20,  0, "gre.verbal.daily.2000", "Prime study time 🔥 — your streak is waiting. Study now!"),
        (21,  0, "gre.verbal.daily.2100", "Still time to study! Don't break your streak tonight."),
        (22,  0, "gre.verbal.daily.2200", "Last reminder ⏰ — one session before bed keeps your streak going."),
        (23,  0, "gre.verbal.daily.2300", "Final call 🚨 — midnight is near. Study GRE Verbal and keep that streak alive!")
    ]

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("⚠️ Notification permission error: \(error)")
            } else {
                print(granted ? "✅ Notifications authorized" : "ℹ️ Notifications denied by user")
            }
        }
    }

    // MARK: - Scheduling

    /// Schedules all 6 daily notifications (idempotent — same identifiers overwrite existing ones).
    func scheduleAllNotifications() {
        let center = UNUserNotificationCenter.current()
        for slot in notificationSlots {
            let content = UNMutableNotificationContent()
            content.title = "GRE Verbal — Study Reminder"
            content.body = slot.body
            content.sound = .default

            var components = DateComponents()
            components.hour = slot.hour
            components.minute = slot.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: slot.id, content: content, trigger: trigger)
            center.add(request) { error in
                if let error {
                    print("⚠️ Failed to schedule notification \(slot.id): \(error)")
                }
            }
        }
    }

    /// Removes all 6 scheduled daily notifications.
    func cancelAllNotifications() {
        let ids = notificationSlots.map { $0.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Refresh on Launch

    /// Call on app launch. If the user already studied today, cancel notifications;
    /// otherwise ensure they are scheduled.
    func refreshOnLaunch(todayCompleted: Bool) {
        if todayCompleted {
            cancelAllNotifications()
        } else {
            // Check authorization status before scheduling
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized ||
                      settings.authorizationStatus == .provisional else { return }
                DispatchQueue.main.async {
                    self.scheduleAllNotifications()
                }
            }
        }
    }
}
