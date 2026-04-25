import Foundation
import Observation

@Observable
final class StreakManager {
    static let shared = StreakManager()

    // MARK: - Persisted State

    private(set) var currentStreak: Int
    private(set) var longestStreak: Int
    private(set) var lastCompletedDate: Date?
    /// Stores whether each of the past 7 days (including today) had a completion.
    /// Index 0 = today, 6 = 6 days ago.
    private(set) var last7DaysCompleted: [Bool]

    // MARK: - Keys

    private enum Keys {
        static let currentStreak = "streak.currentStreak"
        static let longestStreak = "streak.longestStreak"
        static let lastCompletedDate = "streak.lastCompletedDate"
        static let completedDays = "streak.completedDays"  // [TimeInterval] of day-start timestamps
    }

    // MARK: - Init

    private init() {
        let ud = UserDefaults.standard
        currentStreak = ud.integer(forKey: Keys.currentStreak)
        longestStreak = ud.integer(forKey: Keys.longestStreak)
        lastCompletedDate = ud.object(forKey: Keys.lastCompletedDate) as? Date
        last7DaysCompleted = Array(repeating: false, count: 7)
        last7DaysCompleted = Self.buildLast7Days(
            from: (ud.array(forKey: Keys.completedDays) as? [Double])?.map { Date(timeIntervalSince1970: $0) } ?? []
        )
    }

    // MARK: - Computed

    var todayCompleted: Bool {
        guard let last = lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    // MARK: - Public API

    /// Call this when the user finishes a flashcard session.
    func recordCompletion() {
        guard !todayCompleted else { return }

        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!

        if let last = lastCompletedDate, cal.isDate(last, inSameDayAs: yesterday) {
            currentStreak += 1
        } else {
            currentStreak = 1
        }

        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        lastCompletedDate = Date()
        persistState()

        // Cancel today's notifications since the user has studied
        NotificationManager.shared.cancelAllNotifications()
    }

    /// Call on app launch. Resets streak if the user missed a full calendar day.
    func checkAndResetIfNeeded() {
        guard let last = lastCompletedDate else { return }
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        // If last completion was before yesterday (i.e. not today and not yesterday), streak is broken
        if !cal.isDateInToday(last) && !cal.isDate(last, inSameDayAs: yesterday) {
            if currentStreak > 0 {
                currentStreak = 0
                persistState()
            }
        }
    }

    // MARK: - Persistence

    private func persistState() {
        let ud = UserDefaults.standard
        ud.set(currentStreak, forKey: Keys.currentStreak)
        ud.set(longestStreak, forKey: Keys.longestStreak)
        ud.set(lastCompletedDate, forKey: Keys.lastCompletedDate)

        // Update completed-days log (keep rolling 30 days)
        var completedDays = (ud.array(forKey: Keys.completedDays) as? [Double])?.map {
            Date(timeIntervalSince1970: $0)
        } ?? []
        let today = Calendar.current.startOfDay(for: Date())
        if !completedDays.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
            completedDays.append(today)
        }
        // Prune to last 30 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        completedDays = completedDays.filter { $0 >= cutoff }
        ud.set(completedDays.map { $0.timeIntervalSince1970 }, forKey: Keys.completedDays)

        last7DaysCompleted = Self.buildLast7Days(from: completedDays)
    }

    // MARK: - Helpers

    private static func buildLast7Days(from completedDays: [Date]) -> [Bool] {
        let cal = Calendar.current
        return (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date())!
            return completedDays.contains { cal.isDate($0, inSameDayAs: day) }
        }
    }
}
