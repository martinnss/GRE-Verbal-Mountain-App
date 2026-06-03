import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

// All computed properties are explicitly nonisolated to avoid Swift 6 @MainActor
// isolation issues (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
final class GREScreenTimeMonitor: DeviceActivityMonitor {

    nonisolated override init() { super.init() }

    // Use the default (unnamed) store so iOS can correctly associate the
    // GREShieldConfig ShieldConfigurationDataSource extension with these shields.
    nonisolated private var store: ManagedSettingsStore {
        ManagedSettingsStore()
    }

    nonisolated private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.molivares.GRE-Verbal")
    }

    nonisolated private var isSessionActive: Bool {
        sharedDefaults?.bool(forKey: "sessionActive") ?? false
    }

    nonisolated override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        switch activity.rawValue {
        case "com.molivares.GRE-Verbal.blocking":
            // Re-apply shields whenever the daily blocking interval (re)starts,
            // unless a 15-min unlock session is currently active. There is no
            // "completed for the day" concept — every drill grants a fresh
            // 15-min window and apps re-block afterwards.
            if !isSessionActive {
                applyShields()
            }
        case "com.molivares.GRE-Verbal.session":
            store.clearAllSettings()
        default:
            break
        }
    }

    nonisolated override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        switch activity.rawValue {
        case "com.molivares.GRE-Verbal.session":
            sharedDefaults?.set(false, forKey: "sessionActive")
            applyShields()
        default:
            break
        }
    }

    nonisolated override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
    }

    nonisolated private func applyShields() {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "familyActivitySelection"),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
        }
    }
}
