import Foundation
import SwiftUI

// MARK: - Flashcard View Model

@Observable
final class FlashcardViewModel {
    // Dependencies
    let repository: VocabRepository
    let progressManager: ProgressManager
    let audioManager: AudioManager
    
    // Current session state
    var currentDeck: [VocabWord] = []
    var currentIndex: Int = 0
    var isCardFlipped: Bool = false
    var cardOffset: CGSize = .zero
    var cardRotation: Double = 0
    
    // Session configuration
    var selectedGroups: Set<Int> = [1]
    var selectedDifficulties: Set<DifficultyTier> = Set(DifficultyTier.allCases)
    var isCumulativeMode: Bool = false
    
    // Session statistics
    var knownCount: Int = 0
    var unknownCount: Int = 0
    var sessionStartTime: Date?
    
    // UI State
    var showingGroupSelector = false
    var showingDifficultySelector = false
    var showingSessionComplete = false
    
    init(repository: VocabRepository, progressManager: ProgressManager, audioManager: AudioManager = .shared) {
        self.repository = repository
        self.progressManager = progressManager
        self.audioManager = audioManager
    }
    
    // MARK: - Current Word
    
    var currentWord: VocabWord? {
        guard currentIndex >= 0 && currentIndex < currentDeck.count else { return nil }
        return currentDeck[currentIndex]
    }
    
    var hasMoreCards: Bool {
        currentIndex < currentDeck.count - 1
    }
    
    var progress: Double {
        guard !currentDeck.isEmpty else { return 0 }
        return Double(currentIndex) / Double(currentDeck.count)
    }
    
    var remainingCards: Int {
        max(0, currentDeck.count - currentIndex)
    }
    
    // MARK: - Deck Management
    
    func buildDeck() {
        var words: [VocabWord]
        
        if isCumulativeMode {
            // Get max selected group and include all words up to that group
            let maxGroup = selectedGroups.max() ?? 1
            words = repository.wordsCumulative(upToGroup: maxGroup)
        } else {
            // Get words only from selected groups
            words = repository.words(forGroups: Array(selectedGroups))
        }
        
        // Filter by selected difficulties
        words = progressManager.filterWords(words, byTiers: Array(selectedDifficulties))
        
        // Shuffle for varied practice
        currentDeck = words.shuffled()
        currentIndex = 0
        knownCount = 0
        unknownCount = 0
        isCardFlipped = false
        sessionStartTime = Date()
        
        // Pre-cache audio for the deck
        audioManager.preCacheAudio(for: currentDeck)
        
        print("📚 Built deck with \(currentDeck.count) words")
    }
    
    // MARK: - Card Actions
    
    func flipCard() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isCardFlipped = true
        }
    }
    
    func playCurrentWordAudio() {
        guard let word = currentWord else { return }
        audioManager.playPronunciation(from: word.pronunciation)
    }
    
    func markCurrentAsKnown() {
        guard let word = currentWord else { return }
        progressManager.markWordAsKnown(word.word)
        knownCount += 1
        moveToNextCard()
    }
    
    func markCurrentAsUnknown() {
        guard let word = currentWord else { return }
        progressManager.markWordAsUnknown(word.word)
        unknownCount += 1
        moveToNextCard()
    }
    
    private func moveToNextCard() {
        if hasMoreCards {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentIndex += 1
                isCardFlipped = false
                cardOffset = .zero
                cardRotation = 0
            }
            
            // Auto-play pronunciation for next word
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.playCurrentWordAudio()
            }
        } else {
            showingSessionComplete = true
            StreakManager.shared.recordCompletion()
        }
    }
    
    // MARK: - Swipe Handling
    
    func handleDragChange(_ value: DragGesture.Value) {
        cardOffset = value.translation
        cardRotation = Double(value.translation.width / 20)
    }
    
    func handleDragEnd(_ value: DragGesture.Value) {
        let threshold: CGFloat = 100
        
        if value.translation.width < -threshold {
            // Swiped left - Don't know
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                cardOffset = CGSize(width: -500, height: 0)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.markCurrentAsUnknown()
            }
        } else if value.translation.width > threshold {
            // Swiped right - Know it
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                cardOffset = CGSize(width: 500, height: 0)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.markCurrentAsKnown()
            }
        } else {
            // Return to center
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                cardOffset = .zero
                cardRotation = 0
            }
        }
    }
    
    // MARK: - Statistics
    
    func getOverallStatistics() -> (easyNatural: Int, easyMastered: Int, medium: Int, hard: Int, unlocked: Int) {
        return progressManager.getStatistics(for: repository.allWords)
    }
    
    func getGroupStatistics(for groupNumber: Int) -> (easyNatural: Int, easyMastered: Int, medium: Int, hard: Int, unlocked: Int) {
        let words = repository.words(forGroups: [groupNumber])
        return progressManager.getStatistics(for: words)
    }
    
    var sessionDuration: String {
        guard let start = sessionStartTime else { return "0:00" }
        let elapsed = Int(Date().timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Settings
    
    func toggleGroup(_ group: Int) {
        if selectedGroups.contains(group) {
            selectedGroups.remove(group)
        } else {
            selectedGroups.insert(group)
        }
    }
    
    func toggleDifficulty(_ difficulty: DifficultyTier) {
        if selectedDifficulties.contains(difficulty) {
            selectedDifficulties.remove(difficulty)
        } else {
            selectedDifficulties.insert(difficulty)
        }
    }
    
    func selectAllGroups() {
        selectedGroups = Set(repository.groupNumbers)
    }
    
    func deselectAllGroups() {
        selectedGroups = [1] // Keep at least one group
    }
}
