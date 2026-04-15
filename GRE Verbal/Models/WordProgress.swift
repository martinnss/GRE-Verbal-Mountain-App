import Foundation
import SwiftData

// MARK: - SwiftData Model for User Progress

@Model
final class WordProgress {
    @Attribute(.unique) var word: String
    var wrongCount: Int
    var hasSeenOnce: Bool
    var knewOnFirstTry: Bool
    @Attribute var wasPromotedToEasy: Bool = false  // Track if word was promoted through repetition
    var lastReviewedDate: Date?
    var consecutiveCorrectCount: Int  // Track consecutive correct answers
    
    init(word: String) {
        self.word = word
        self.wrongCount = 0
        self.hasSeenOnce = false
        self.knewOnFirstTry = false
        self.wasPromotedToEasy = false
        self.lastReviewedDate = nil
        self.consecutiveCorrectCount = 0
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
    }
}

// MARK: - App Settings Model

@Model
final class AppSettings {
    var selectedGroups: [Int]
    var selectedDifficulties: [String]
    var isCumulativeMode: Bool
    var hasCompletedOnboarding: Bool
    
    init() {
        self.selectedGroups = [1]
        self.selectedDifficulties = DifficultyTier.allCases.map { $0.rawValue }
        self.isCumulativeMode = false
        self.hasCompletedOnboarding = false
    }
}
