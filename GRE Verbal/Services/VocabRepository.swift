import Foundation
import SwiftData

// MARK: - Vocabulary Repository

@Observable
final class VocabRepository {
    private(set) var allWords: [VocabWord] = []
    private(set) var groups: [String] = []
    private(set) var isLoaded = false
    
    init() {
        loadVocabulary()
    }
    
    private func loadVocabulary() {
        guard let url = Bundle.main.url(forResource: "gregmat_vocab", withExtension: "json") else {
            print("❌ Could not find gregmat_vocab.json in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            allWords = try decoder.decode([VocabWord].self, from: data)
            
            // Extract unique groups and sort them
            let uniqueGroups = Set(allWords.map { $0.group })
            groups = uniqueGroups.sorted { group1, group2 in
                let num1 = Int(group1.filter { $0.isNumber }) ?? 0
                let num2 = Int(group2.filter { $0.isNumber }) ?? 0
                return num1 < num2
            }
            
            isLoaded = true
            print("✅ Loaded \(allWords.count) words from \(groups.count) groups")
        } catch {
            print("❌ Failed to decode vocabulary: \(error)")
        }
    }
    
    // Get words for specific groups
    func words(forGroups groupNumbers: [Int]) -> [VocabWord] {
        let groupNames = groupNumbers.map { "Group \($0)" }
        return allWords.filter { groupNames.contains($0.group) }
    }
    
    // Get words for cumulative mode (all groups up to and including selected)
    func wordsCumulative(upToGroup maxGroup: Int) -> [VocabWord] {
        return allWords.filter { $0.groupNumber <= maxGroup }
    }
    
    // Get total group count
    var totalGroups: Int {
        groups.count
    }
    
    // Get group numbers
    var groupNumbers: [Int] {
        groups.compactMap { group in
            Int(group.filter { $0.isNumber })
        }
    }
}

// MARK: - Progress Export Data

struct ProgressExportData: Codable {
    let word: String
    let wrongCount: Int
    let hasSeenOnce: Bool
    let knewOnFirstTry: Bool
    let wasPromotedToEasy: Bool
    let consecutiveCorrectCount: Int
    let lastReviewedDate: Date?
}

// MARK: - Progress Manager

@Observable
final class ProgressManager {
    private var modelContext: ModelContext?
    private var progressCache: [String: WordProgress] = [:]
    private let autoBackupFileName = "progress_autobackup.json"
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAllProgress()
    }
    
    private func loadAllProgress() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<WordProgress>()
        if let results = try? context.fetch(descriptor) {
            progressCache = Dictionary(uniqueKeysWithValues: results.map { ($0.word, $0) })

            // Safety net: if the store is empty but we have an auto-backup file, restore it.
            if results.isEmpty {
                restoreFromAutoBackupIfNeeded()
                if let restored = try? context.fetch(descriptor) {
                    progressCache = Dictionary(uniqueKeysWithValues: restored.map { ($0.word, $0) })
                }
            }

            print("✅ Loaded progress for \(progressCache.count) words")
        }
    }
    
    func getProgress(for word: String) -> WordProgress {
        if let existing = progressCache[word] {
            return existing
        }
        
        // Create new progress entry
        let newProgress = WordProgress(word: word)
        progressCache[word] = newProgress
        modelContext?.insert(newProgress)
        return newProgress
    }
    
    func getDifficultyTier(for word: String) -> DifficultyTier {
        return getProgress(for: word).difficultyTier
    }
    
    func markWordAsKnown(_ word: String) {
        let progress = getProgress(for: word)
        progress.markAsKnown()
        saveContext()
    }
    
    func markWordAsUnknown(_ word: String) {
        let progress = getProgress(for: word)
        progress.markAsUnknown()
        saveContext()
    }
    
    private func saveContext() {
        do {
            try modelContext?.save()
            writeAutoBackup()
        } catch {
            print("⚠️ Failed to save progress context: \(error)")
        }
    }

    private func autoBackupURL() -> URL {
        URL.applicationSupportDirectory.appending(path: autoBackupFileName)
    }

    private func writeAutoBackup() {
        let studied = exportProgress()
        guard !studied.isEmpty else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(studied)
            try data.write(to: autoBackupURL(), options: .atomic)
        } catch {
            print("⚠️ Failed to write progress auto-backup: \(error)")
        }
    }

    private func restoreFromAutoBackupIfNeeded() {
        guard let context = modelContext else { return }

        let url = autoBackupURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let backup = try decoder.decode([ProgressExportData].self, from: data)
            guard !backup.isEmpty else { return }

            for item in backup {
                let progress = getProgress(for: item.word)
                progress.wrongCount = item.wrongCount
                progress.hasSeenOnce = item.hasSeenOnce
                progress.knewOnFirstTry = item.knewOnFirstTry
                progress.wasPromotedToEasy = item.wasPromotedToEasy
                progress.consecutiveCorrectCount = item.consecutiveCorrectCount
                progress.lastReviewedDate = item.lastReviewedDate
            }

            try context.save()
            print("♻️ Restored progress from auto-backup (\(backup.count) words)")
        } catch {
            print("⚠️ Failed to restore from auto-backup: \(error)")
        }
    }
    
    // Filter words by difficulty tiers
    func filterWords(_ words: [VocabWord], byTiers tiers: [DifficultyTier]) -> [VocabWord] {
        return words.filter { word in
            let tier = getDifficultyTier(for: word.word)
            return tiers.contains(tier)
        }
    }
    
    // Get statistics
    func getStatistics(for words: [VocabWord]) -> (easyNatural: Int, easyMastered: Int, medium: Int, hard: Int, unlocked: Int) {
        var easyNatural = 0, easyMastered = 0, medium = 0, hard = 0, unlocked = 0
        
        for word in words {
            switch getDifficultyTier(for: word.word) {
            case .easyNatural: easyNatural += 1
            case .easyMastered: easyMastered += 1
            case .medium: medium += 1
            case .hard: hard += 1
            case .unlocked: unlocked += 1
            }
        }
        
        return (easyNatural, easyMastered, medium, hard, unlocked)
    }
    
    // MARK: - Export/Import
    
    func exportProgress() -> [ProgressExportData] {
        return progressCache.values
            .filter { $0.hasSeenOnce } // Only export words that have been studied
            .map { progress in
                ProgressExportData(
                    word: progress.word,
                    wrongCount: progress.wrongCount,
                    hasSeenOnce: progress.hasSeenOnce,
                    knewOnFirstTry: progress.knewOnFirstTry,
                    wasPromotedToEasy: progress.wasPromotedToEasy,
                    consecutiveCorrectCount: progress.consecutiveCorrectCount,
                    lastReviewedDate: progress.lastReviewedDate
                )
            }
    }
    
    func importProgress(_ data: [ProgressExportData]) {
        guard modelContext != nil else { return }
        
        for item in data {
            let progress = getProgress(for: item.word)
            progress.wrongCount = item.wrongCount
            progress.hasSeenOnce = item.hasSeenOnce
            progress.knewOnFirstTry = item.knewOnFirstTry
            progress.wasPromotedToEasy = item.wasPromotedToEasy
            progress.consecutiveCorrectCount = item.consecutiveCorrectCount
            progress.lastReviewedDate = item.lastReviewedDate
        }
        
        saveContext()
        loadAllProgress() // Refresh cache
    }
}
