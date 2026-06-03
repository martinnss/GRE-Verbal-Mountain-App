import ManagedSettings
import UserNotifications

// nonisolated required because ShieldActionDelegate overrides are nonisolated
// but the project sets SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
final class GREShieldAction: ShieldActionDelegate {

    nonisolated override init() { super.init() }

    nonisolated override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    nonisolated override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    nonisolated override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action, completionHandler: completionHandler)
    }

    private nonisolated func handleAction(_ action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            postOpenGRENotification()
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    private nonisolated func postOpenGRENotification() {
        let content = UNMutableNotificationContent()
        content.title = "Open GRE Verbal to Unlock"
        content.body = "Complete your GRE verbal practice to unlock blocked apps for 15 minutes."
        content.sound = .default
        content.userInfo = ["deeplink": "greverbal://practice"]
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "gre-unlock-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
