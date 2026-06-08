import Foundation
import SwiftData

// MARK: - SwiftData Model for User Progress

@Model
final class WordProgress {
    // CloudKit mirroring forbids unique constraints and requires every stored
    // property to be optional or defaulted. Uniqueness is enforced in
    // ProgressManager (in-memory cache + dedup-on-load), not by the store.
    var word: String = ""
    var wrongCount: Int = 0
    var hasSeenOnce: Bool = false
    var knewOnFirstTry: Bool = false
    var wasPromotedToEasy: Bool = false  // Track if word was promoted through repetition
    var lastReviewedDate: Date? = nil
    var consecutiveCorrectCount: Int = 0  // Track consecutive correct answers
    /// When the word most recently reached an Easy tier (natural or mastered).
    /// Drives the daily streak goal: "words learned today". nil = not easy.
    var masteredDate: Date? = nil

    init(word: String) {
        self.word = word
        self.wrongCount = 0
        self.hasSeenOnce = false
        self.knewOnFirstTry = false
        self.wasPromotedToEasy = false
        self.lastReviewedDate = nil
        self.consecutiveCorrectCount = 0
        self.masteredDate = nil
    }
    
    // Calculate difficulty tier based on progress
    var difficultyTier: DifficultyTier {
        // Never seen = unlocked
        if !hasSeenOnce {
            return .unlocked
        }
        
        // Easy by promotion (mastered through practice)
        if wasPromotedToEasy {
            return .easyMastered
        }
        
        // Knew it on first try = natural easy
        if knewOnFirstTry {
            return .easyNatural
        }
        
        // 20+ wrong swipes = hard
        if wrongCount >= 20 {
            return .hard
        }
        
        // 1-19 wrong swipes = medium
        return .medium
    }
    
    // Mark word as known (swiped right or tapped and knew it)
    func markAsKnown() {
        if !hasSeenOnce {
            hasSeenOnce = true
            knewOnFirstTry = true
            consecutiveCorrectCount = 1
            masteredDate = Date()        // reached Easy (Natural) today
        } else {
            // Increment consecutive correct count
            consecutiveCorrectCount += 1

            // Promotion logic: 5 consecutive correct answers promotes the word one tier
            if consecutiveCorrectCount >= 5 && !knewOnFirstTry && !wasPromotedToEasy {
                if wrongCount >= 20 {
                    // Hard → Medium: reduce wrongCount to exit hard tier
                    wrongCount = 19
                    consecutiveCorrectCount = 0  // Reset streak for next promotion
                } else {
                    // Medium → Easy (Mastered)
                    wasPromotedToEasy = true
                    masteredDate = Date()    // reached Easy (Mastered) today
                }
            }
        }
        lastReviewedDate = Date()
    }
    
    // Mark word as unknown (swiped left)
    func markAsUnknown() {
        // If it was an Easy word (natural or mastered), reset ALL progress (demote to Unlocked)
        if knewOnFirstTry || wasPromotedToEasy {
            resetProgress()
            return
        }
        
        if !hasSeenOnce {
            hasSeenOnce = true
            knewOnFirstTry = false
        }
        wrongCount += 1
        consecutiveCorrectCount = 0  // Reset streak on wrong answer
        lastReviewedDate = Date()
    }
    
    // Reset all progress - word goes back to Unlocked
    func resetProgress() {
        wrongCount = 0
        hasSeenOnce = false
        knewOnFirstTry = false
        wasPromotedToEasy = false
        consecutiveCorrectCount = 0
        lastReviewedDate = nil
        masteredDate = nil
    }
}

// MARK: - App Settings Model

@Model
final class AppSettings {
    var selectedGroups: [Int] = [1]
    var selectedDifficulties: [String] = []
    var isCumulativeMode: Bool = false
    var hasCompletedOnboarding: Bool = false

    init() {
        self.selectedGroups = [1]
        self.selectedDifficulties = DifficultyTier.allCases.map { $0.rawValue }
        self.isCumulativeMode = false
        self.hasCompletedOnboarding = false
    }
}
