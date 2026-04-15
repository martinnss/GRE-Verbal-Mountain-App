import Foundation

// MARK: - JSON Data Models

struct VocabWord: Codable, Identifiable, Hashable {
    let group: String
    let word: String
    let pronunciation: String
    let definitions: [Definition]
    
    var id: String { word }
    
    // Extract group number for sorting/filtering
    var groupNumber: Int {
        let digits = group.filter { $0.isNumber }
        return Int(digits) ?? 0
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }
    
    static func == (lhs: VocabWord, rhs: VocabWord) -> Bool {
        lhs.word == rhs.word
    }
}

struct Definition: Codable, Identifiable, Hashable {
    let partOfSpeech: String
    let definition: String
    let sentence: String
    let synonyms: [String]
    
    var id: String { "\(partOfSpeech)-\(definition)" }
    
    // Check if sentence is available
    var hasSentence: Bool {
        !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    enum CodingKeys: String, CodingKey {
        case partOfSpeech = "part_of_speech"
        case definition, sentence, synonyms
    }
}

// MARK: - Difficulty Tier

enum DifficultyTier: String, Codable, CaseIterable, Identifiable {
    case unlocked = "Unlocked"
    case easyNatural = "Easy (Natural)"
    case easyMastered = "Easy (Mastered)"
    case medium = "Medium"
    case hard = "Hard"
    
    var id: String { rawValue }
    
    var color: String {
        switch self {
        case .unlocked: return "gray"
        case .easyNatural: return "green"
        case .easyMastered: return "mint"
        case .medium: return "orange"
        case .hard: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .unlocked: return "lock.fill"
        case .easyNatural: return "checkmark.circle.fill"
        case .easyMastered: return "star.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .hard: return "xmark.octagon.fill"
        }
    }
    
    // Helper to check if this is any type of easy
    var isEasy: Bool {
        self == .easyNatural || self == .easyMastered
    }
}
