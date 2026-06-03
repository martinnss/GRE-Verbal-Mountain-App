import Foundation
import FamilyControls
import DeviceActivity

// MARK: - Notification name for deep-link from shield notification

extension Notification.Name {
    static let openPracticeTab = Notification.Name("openPracticeTab")
}

// MARK: - Shared constants (must match values in all three extensions)

enum ScreenTimeConstants {
    static let appGroupID            = "group.molivares.GRE-Verbal"
    static let blockingActivityName  = DeviceActivityName("com.molivares.GRE-Verbal.blocking")
    static let sessionActivityName   = DeviceActivityName("com.molivares.GRE-Verbal.session")
    // NOTE: ManagedSettingsStore.Name("GREVerbalStore") lives in extensions only —
    //       the main app must NOT import ManagedSettings or touch ManagedSettingsStore.
    static let selectionKey          = "familyActivitySelection"
    static let sessionActiveKey      = "sessionActive"
    static let sessionEndDateKey     = "sessionEndDate"
    static let sessionMinutes        = 15
    // Shield vocabulary (read by GREShieldConfig when drawing the lock screen)
    static let shieldHardWordsKey    = "shieldHardWords"
    static let shieldAllWordsKey     = "shieldAllWords"
}

// MARK: - Shield vocabulary contract
// One vocab entry the shield extension renders. The JSON keys here are the wire
// contract shared with GREShieldConfig — keep the mirror struct there in sync.

struct ShieldWord: Codable {
    let word: String
    let pos: String
    let def: String
    let sentence: String

    init?(_ v: VocabWord) {
        guard let d = v.definitions.first else { return nil }
        word = v.word
        pos = d.partOfSpeech
        def = d.definition
        sentence = d.sentence
    }
}

// MARK: - Screen Time Manager
// The main app is responsible for:
//   1. Requesting FamilyControls authorization
//   2. Storing FamilyActivitySelection in the shared App Group
//   3. Scheduling / stopping DeviceActivity monitoring
//
// The main app must NEVER import ManagedSettings or use ManagedSettingsStore.
// Shield apply/clear is handled exclusively by GREScreenTimeMonitor extension.

@MainActor
@Observable
final class ScreenTimeManager {

    static let shared = ScreenTimeManager()

    // MARK: Published state
    var isAuthorized        = false
    var hasAppSelection     = false
    var isSessionActive     = false
    var sessionEndDate: Date?
    var authorizationError: String?

    // MARK: Private
    private let authCenter    = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()

    // MARK: App Group UserDefaults
    var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: ScreenTimeConstants.appGroupID)
    }

    // MARK: Derived state

    var minutesRemainingInSession: Int {
        guard isSessionActive, let end = sessionEndDate else { return 0 }
        return max(0, Int(end.timeIntervalSinceNow / 60))
    }

    var currentSelection: FamilyActivitySelection {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: ScreenTimeConstants.selectionKey),
              let sel = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return sel
    }

    // MARK: Init

    private init() { refreshState() }

    func refreshState() {
        isAuthorized    = authCenter.authorizationStatus == .approved
        hasAppSelection = sharedDefaults?.data(forKey: ScreenTimeConstants.selectionKey) != nil

        let active = sharedDefaults?.bool(forKey: ScreenTimeConstants.sessionActiveKey) ?? false
        let end    = sharedDefaults?.object(forKey: ScreenTimeConstants.sessionEndDateKey) as? Date

        if active, let end, end > Date() {
            isSessionActive = true
            sessionEndDate  = end
        } else {
            isSessionActive = false
            sessionEndDate  = nil
            if active {
                // The session window has expired but the flag is still set,
                // which means the monitor's intervalDidEnd callback never fired
                // (e.g. dropped by the system, or the app was killed). Clear the
                // flag and force the shields back on so blocked apps don't stay
                // open indefinitely.
                sharedDefaults?.set(false, forKey: ScreenTimeConstants.sessionActiveKey)
                reapplyBlocking()
            }
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        authorizationError = nil
        guard authCenter.authorizationStatus != .approved else {
            isAuthorized = true
            return
        }
        do {
            try await authCenter.requestAuthorization(for: .individual)
            isAuthorized = authCenter.authorizationStatus == .approved
        } catch {
            isAuthorized       = false
            authorizationError = error.localizedDescription
        }
    }

    // MARK: - Selection

    func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? PropertyListEncoder().encode(selection) else { return }
        sharedDefaults?.set(data, forKey: ScreenTimeConstants.selectionKey)
        hasAppSelection = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
        startBlockingSchedule()
    }

    // MARK: - Blocking schedule

    /// Start the daily DeviceActivity schedule.
    /// When the interval starts the GREScreenTimeMonitor extension wakes up
    /// and applies shields — the main app never touches ManagedSettingsStore.
    func startBlockingSchedule() {
        guard isAuthorized, hasAppSelection else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd:   DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        // Ignore errors — monitoring may already be running
        try? activityCenter.startMonitoring(ScreenTimeConstants.blockingActivityName, during: schedule)
    }

    /// Force the daily blocking schedule to restart so the monitor's
    /// `intervalDidStart` fires immediately (its interval spans the whole day,
    /// so it is always currently active). Used to re-apply shields after a
    /// session expires without the `intervalDidEnd` callback firing.
    private func reapplyBlocking() {
        guard isAuthorized, hasAppSelection else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd:   DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        // Stop first: starting an already-monitored activity is a no-op and
        // would not re-trigger intervalDidStart. Stop + start forces it.
        activityCenter.stopMonitoring([ScreenTimeConstants.blockingActivityName])
        try? activityCenter.startMonitoring(ScreenTimeConstants.blockingActivityName, during: schedule)
    }

    func stopBlocking() {
        activityCenter.stopMonitoring([
            ScreenTimeConstants.blockingActivityName,
            ScreenTimeConstants.sessionActivityName
        ])
        sharedDefaults?.set(false, forKey: ScreenTimeConstants.sessionActiveKey)
        isSessionActive = false
        sessionEndDate  = nil
    }

    // MARK: - Unlock session (called after practice completes)

    /// Record completion and schedule a 15-min DeviceActivity session.
    /// The GREScreenTimeMonitor extension will clear shields on intervalDidStart
    /// and re-apply them on intervalDidEnd — no ManagedSettingsStore here.
    func startUnlockSession() {
        guard isAuthorized else { return }

        let now     = Date()
        let endDate = now.addingTimeInterval(TimeInterval(ScreenTimeConstants.sessionMinutes * 60))

        // Persist state for the extension and the UI
        sharedDefaults?.set(endDate, forKey: ScreenTimeConstants.sessionEndDateKey)
        sharedDefaults?.set(true,    forKey: ScreenTimeConstants.sessionActiveKey)
        isSessionActive = true
        sessionEndDate  = endDate

        // Stop any previous session before scheduling a new one
        activityCenter.stopMonitoring([ScreenTimeConstants.sessionActivityName])

        let startComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let endComponents   = Calendar.current.dateComponents([.hour, .minute, .second], from: endDate)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd:   endComponents,
            repeats: false
        )
        try? activityCenter.startMonitoring(ScreenTimeConstants.sessionActivityName, during: schedule)
    }

    // MARK: - Shield vocabulary

    /// Push the words the shield should show into the App Group: the user's
    /// struggling words first, plus a random fallback sample so a brand-new
    /// user (no hard words yet) still gets a real entry. The extension picks
    /// one at render time. Cheap enough to call after every drill.
    func syncShieldVocabulary(repository: VocabRepository, progress: ProgressManager) {
        guard let defaults = sharedDefaults else { return }

        let byWord = Dictionary(repository.allWords.map { ($0.word, $0) },
                                uniquingKeysWith: { first, _ in first })

        let hard = progress.strugglingWords()
            .compactMap { byWord[$0] }
            .compactMap(ShieldWord.init)

        let fallback = repository.allWords
            .shuffled()
            .prefix(150)
            .compactMap(ShieldWord.init)

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(hard) {
            defaults.set(data, forKey: ScreenTimeConstants.shieldHardWordsKey)
        }
        if let data = try? encoder.encode(Array(fallback)) {
            defaults.set(data, forKey: ScreenTimeConstants.shieldAllWordsKey)
        }
    }

    // MARK: - Reset

    func resetAll() {
        stopBlocking()
        sharedDefaults?.removeObject(forKey: ScreenTimeConstants.selectionKey)
        sharedDefaults?.removeObject(forKey: ScreenTimeConstants.sessionActiveKey)
        sharedDefaults?.removeObject(forKey: ScreenTimeConstants.sessionEndDateKey)
        sharedDefaults?.removeObject(forKey: ScreenTimeConstants.shieldHardWordsKey)
        sharedDefaults?.removeObject(forKey: ScreenTimeConstants.shieldAllWordsKey)
        hasAppSelection = false
        isSessionActive = false
        sessionEndDate  = nil
    }
}
