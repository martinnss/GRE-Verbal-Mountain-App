import Foundation
import SwiftData
import CoreData

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
    var masteredDate: Date? = nil
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
        // If there are no studied words (empty store or bad CloudKit sync),
        // force-write the hardcoded backup so progress is never lost.
        let hasStudied = progressCache.values.contains { $0.hasSeenOnce }
        if !hasStudied {
            forceRestoreHardcodedProgress()
        }
    }

    private func forceRestoreHardcodedProgress() {
        guard let context = modelContext else { return }
        var count = 0
        for entry in Self.hardcodedProgress() {
            let p = getProgress(for: entry.word)
            p.hasSeenOnce            = entry.hasSeenOnce
            p.knewOnFirstTry         = entry.knewOnFirstTry
            p.wasPromotedToEasy      = entry.wasPromotedToEasy
            p.wrongCount             = entry.wrongCount
            p.consecutiveCorrectCount = entry.consecutiveCorrectCount
            count += 1
        }
        try? context.save()
        // Reload cache so the UI reflects the restored data immediately.
        let descriptor = FetchDescriptor<WordProgress>()
        if let results = try? context.fetch(descriptor) {
            progressCache = deduplicated(results, in: context)
        }
        print("✅ Hardcoded progress restored: \(count) words")
    }

    // MARK: - Hardcoded progress backup (2026-06-03)
    private static func hardcodedProgress() -> [(word: String, wrongCount: Int, hasSeenOnce: Bool, knewOnFirstTry: Bool, wasPromotedToEasy: Bool, consecutiveCorrectCount: Int)] {
        return [
            ("placate", 0, true, true, false, 1),
            ("exacerbate", 0, true, true, false, 1),
            ("mitigate", 0, true, true, false, 1),
            ("anomalous", 0, true, true, false, 1),
            ("pellucid", 1, true, false, false, 0),
            ("antipathy", 0, true, true, false, 1),
            ("skullduggery", 4, true, false, true, 5),
            ("aesthetic", 0, true, true, false, 1),
            ("perfidy", 7, true, false, true, 6),
            ("underscore", 2, true, false, true, 5),
            ("bucolic", 0, true, true, false, 1),
            ("construe", 19, true, false, true, 5),
            ("abjure", 0, true, true, false, 1),
            ("polemical", 2, true, false, true, 6),
            ("amorphous", 0, true, true, false, 1),
            ("arbitrary", 0, true, true, false, 1),
            ("obeisance", 0, true, true, false, 1),
            ("cerebral", 0, true, true, false, 1),
            ("lethargic", 1, true, false, false, 0),
            ("expedite", 0, true, true, false, 1),
            ("diatribe", 0, true, true, false, 1),
            ("clangor", 1, true, false, true, 5),
            ("dearth", 37, true, false, false, 0),
            ("marginalize", 0, true, true, false, 1),
            ("deft", 0, true, true, false, 1),
            ("transient", 2, true, false, true, 5),
            ("deify", 0, true, true, false, 1),
            ("dissemble", 38, true, false, false, 0),
            ("cogent", 13, true, false, true, 5),
            ("churlish", 4, true, false, false, 0),
            ("tendentious", 10, true, false, true, 5),
            ("indefatigable", 4, true, false, true, 5),
            ("cordial", 0, true, true, false, 1),
            ("stern", 3, true, false, true, 5),
            ("artless", 0, true, true, false, 1),
            ("esoteric", 0, true, true, false, 1),
            ("weary", 1, true, false, true, 5),
            ("transgression", 0, true, true, false, 1),
            ("mordant", 17, true, false, false, 2),
            ("debilitating", 0, true, true, false, 1),
            ("omnipresent", 0, true, true, false, 1),
            ("assuage", 2, true, false, true, 5),
            ("precarious", 0, true, true, false, 1),
            ("adulterate", 0, true, true, false, 1),
            ("cacophonous", 2, true, false, true, 5),
            ("metaphorical", 0, true, true, false, 1),
            ("loathe", 36, true, false, false, 0),
            ("caustic", 0, true, true, false, 1),
            ("arcane", 0, true, true, false, 1),
            ("extravagant", 1, true, false, true, 5),
            ("mawkish", 4, true, false, false, 0),
            ("daunting", 0, true, true, false, 1),
            ("deleterious", 4, true, false, true, 5),
            ("feasible", 0, true, true, false, 1),
            ("verisimilitude", 0, true, true, false, 1),
            ("prodigal", 1, true, false, true, 5),
            ("exasperated", 0, true, true, false, 1),
            ("erudite", 0, true, true, false, 1),
            ("equivocate", 0, true, true, false, 1),
            ("peripheral", 1, true, false, false, 0),
            ("acrimonious", 1, true, false, false, 0),
            ("debunk", 0, true, true, false, 1),
            ("eccentric", 0, true, true, false, 1),
            ("onerous", 1, true, false, false, 0),
            ("opaque", 0, true, true, false, 1),
            ("panacea", 0, true, true, false, 1),
            ("impertinent", 4, true, false, true, 5),
            ("renounce", 1, true, false, false, 0),
            ("insipid", 0, true, true, false, 1),
            ("perilous", 0, true, true, false, 1),
            ("irreverent", 0, true, true, false, 1),
            ("covet", 0, true, true, false, 1),
            ("avaricious", 0, true, true, false, 1),
            ("craven", 0, true, true, false, 1),
            ("advocate", 0, true, true, false, 1),
            ("brazen", 55, true, false, false, 0),
            ("wane", 7, true, false, false, 0),
            ("rudimentary", 0, true, true, false, 1),
            ("soporific", 0, true, true, false, 1),
            ("enervate", 0, true, true, false, 1),
            ("evasive", 0, true, true, false, 1),
            ("outstrip", 2, true, false, true, 5),
            ("reproach", 0, true, true, false, 1),
            ("ephemeral", 0, true, true, false, 1),
            ("befuddled", 4, true, false, false, 2),
            ("utilitarian", 0, true, true, false, 1),
            ("puerile", 0, true, true, false, 1),
            ("tact", 0, true, true, false, 1),
            ("galvanize", 8, true, false, true, 5),
            ("lament", 0, true, true, false, 1),
            ("provincial", 7, true, false, false, 0),
            ("affectation", 14, true, false, true, 5),
            ("congenial", 0, true, true, false, 1),
            ("venerate", 0, true, true, false, 1),
            ("incredulous", 2, true, false, true, 5),
            ("boorish", 21, true, false, false, 0),
            ("heterogeneous", 0, true, true, false, 1),
            ("aggrandize", 0, true, true, false, 1),
            ("demur", 0, true, true, false, 1),
            ("sanguine", 10, true, false, true, 5),
            ("fervid", 0, true, true, false, 1),
            ("rational", 0, true, true, false, 1),
            ("dichotomy", 1, true, false, true, 5),
            ("provocative", 0, true, true, false, 1),
            ("connoisseur", 0, true, true, false, 1),
            ("rapacious", 4, true, false, false, 0),
            ("arduous", 0, true, true, false, 1),
            ("nonchalant", 0, true, true, false, 1),
            ("tortuous", 0, true, true, false, 1),
            ("irascible", 3, true, false, true, 5),
            ("ascribe", 7, true, false, false, 0),
            ("abhor", 4, true, false, false, 0),
            ("chicanery", 0, true, true, false, 1),
            ("futile", 1, true, false, false, 0),
            ("obsolete", 0, true, true, false, 1),
            ("neophyte", 8, true, false, true, 5),
            ("covert", 1, true, false, false, 0),
            ("admonish", 5, true, false, true, 5),
            ("vitiate", 1, true, false, false, 0),
            ("precipitate", 0, true, true, false, 1),
            ("recondite", 0, true, true, false, 1),
            ("betray", 0, true, true, false, 1),
            ("tranquil", 0, true, true, false, 1),
            ("laudable", 2, true, false, true, 5),
            ("enigmatic", 0, true, true, false, 1),
            ("comity", 18, true, false, false, 2),
            ("ubiquitous", 5, true, false, true, 5),
            ("fractious", 4, true, false, false, 0),
            ("skirt", 4, true, false, false, 0),
            ("portend", 7, true, false, false, 0),
            ("baroque", 1, true, false, false, 0),
            ("clamorous", 1, true, false, true, 5),
            ("emulate", 0, true, true, false, 1),
            ("calumny", 0, true, true, false, 1),
            ("turbulent", 0, true, true, false, 1),
            ("intransigent", 4, true, false, true, 5),
            ("overt", 1, true, false, false, 0),
            ("spendthrift", 0, true, true, false, 1),
            ("cavalier", 1, true, false, false, 0),
            ("conspicuous", 0, true, true, false, 1),
            ("misanthropic", 0, true, true, false, 1),
            ("abstain", 0, true, true, false, 1),
            ("pertinacious", 39, true, false, false, 1),
            ("pervasive", 4, true, false, false, 0),
            ("profuse", 6, true, false, true, 6),
            ("hamper", 7, true, false, false, 0),
            ("myopic", 1, true, false, true, 5),
            ("innocuous", 0, true, true, false, 1),
            ("misnomer", 0, true, true, false, 1),
            ("belligerent", 1, true, false, false, 0),
            ("clandestine", 0, true, true, false, 1),
            ("urbane", 1, true, false, false, 0),
            ("paradigmatic", 0, true, true, false, 1),
            ("negligent", 0, true, true, false, 1),
            ("placid", 0, true, true, false, 1),
            ("indiscriminate", 0, true, true, false, 1),
            ("coalesce", 0, true, true, false, 1),
            ("didactic", 0, true, true, false, 1),
            ("humdrum", 0, true, true, false, 1),
            ("perfunctory", 4, true, false, false, 0),
            ("cherish", 1, true, false, true, 5),
            ("intrepid", 6, true, false, true, 6),
            ("haphazard", 10, true, false, true, 5),
            ("stoic", 0, true, true, false, 1),
            ("specious", 40, true, false, false, 0),
            ("altruistic", 0, true, true, false, 1),
            ("belie", 0, true, true, false, 1),
            ("byzantine", 1, true, false, false, 0),
            ("copious", 0, true, true, false, 1),
            ("conciliatory", 0, true, true, false, 1),
            ("restive", 0, true, true, false, 1),
            ("slight", 7, true, false, false, 0),
            ("plastic", 1, true, false, true, 6),
            ("edify", 3, true, false, true, 5),
            ("ingenuous", 0, true, true, false, 1),
            ("fastidious", 5, true, false, false, 2),
            ("egregious", 1, true, false, true, 5),
            ("profundity", 0, true, true, false, 1),
            ("forestall", 7, true, false, true, 5),
            ("hackneyed", 1, true, false, false, 0),
            ("sporadic", 0, true, true, false, 1),
            ("pristine", 0, true, true, false, 1),
            ("panache", 6, true, false, true, 5),
            ("convivial", 4, true, false, true, 6),
            ("oust", 6, true, false, true, 5),
            ("mercenary", 0, true, true, false, 1),
            ("platitude", 37, true, false, false, 0),
            ("banal", 0, true, true, false, 1),
            ("tractable", 7, true, false, true, 6),
            ("sluggish", 4, true, false, false, 0),
            ("commensurate", 2, true, false, true, 5),
            ("garrulous", 0, true, true, false, 1),
            ("subvert", 8, true, false, true, 5),
            ("polarize", 1, true, false, true, 5),
            ("malign", 0, true, true, false, 1),
            ("diffuse", 1, true, false, false, 0),
            ("convoluted", 0, true, true, false, 1),
            ("vacillate", 0, true, true, false, 1),
            ("probity", 3, true, false, true, 5),
            ("tempestuous", 0, true, true, false, 1),
            ("pugnacious", 18, true, false, true, 5),
            ("verbose", 0, true, true, false, 1),
            ("amenable", 0, true, true, false, 1),
            ("contrite", 18, true, false, true, 5),
            ("prophetic", 0, true, true, false, 1),
            ("subtle", 0, true, true, false, 1),
            ("tenable", 1, true, false, false, 0),
            ("feeble", 6, true, false, true, 5),
            ("parsimonious", 0, true, true, false, 1),
            ("taciturn", 2, true, false, true, 5),
            ("cumbersome", 4, true, false, false, 0),
            ("complacent", 4, true, false, false, 0),
            ("approbation", 2, true, false, true, 5),
            ("superficial", 0, true, true, false, 1),
            ("impede", 0, true, true, false, 1),
            ("exculpate", 1, true, false, true, 5),
            ("prudent", 0, true, true, false, 1),
            ("meticulous", 0, true, true, false, 1),
            ("supersede", 0, true, true, false, 1),
            ("abate", 0, true, true, false, 1),
            ("obsequious", 1, true, false, true, 6),
            ("nettlesome", 24, true, false, false, 0),
            ("chauvinistic", 2, true, false, true, 5),
            ("boisterous", 4, true, false, false, 0),
            ("laconic", 1, true, false, false, 0),
            ("credible", 0, true, true, false, 1),
            ("sedulous", 37, true, false, false, 0),
            ("eclipse", 0, true, true, false, 1),
            ("distressed", 0, true, true, false, 1),
            ("intimate", 0, true, true, false, 1),
            ("sanction", 3, true, false, true, 6),
            ("pensive", 0, true, true, false, 1),
            ("disparate", 6, true, false, true, 5),
            ("beneficent", 0, true, true, false, 1),
            ("aloof", 19, true, false, true, 5),
            ("inimical", 0, true, true, false, 1),
            ("plodding", 16, true, false, true, 5),
            ("salutary", 1, true, false, true, 5),
            ("affinity", 0, true, true, false, 1),
            ("droll", 4, true, false, false, 0),
            ("proclivity", 0, true, true, false, 1),
            ("eschew", 7, true, false, false, 0),
            ("prosaic", 19, true, false, true, 5),
            ("zealous", 13, true, false, true, 5),
            ("chivalrous", 4, true, false, false, 0),
            ("burgeon", 0, true, true, false, 1),
            ("ambivalent", 17, true, false, true, 5),
            ("vapid", 21, true, false, false, 3),
            ("relish", 4, true, false, false, 0),
            ("pedantic", 4, true, false, true, 5),
            ("canny", 1, true, false, false, 0),
            ("dogged", 19, true, false, true, 5),
            ("contend", 0, true, true, false, 1),
            ("accentuate", 0, true, true, false, 1),
            ("archaic", 0, true, true, false, 1),
            ("incendiary", 0, true, true, false, 1),
            ("discernible", 0, true, true, false, 1),
            ("fervor", 0, true, true, false, 1),
            ("canonize", 0, true, true, false, 1),
            ("indolent", 15, true, false, true, 5),
            ("explicable", 0, true, true, false, 1),
            ("abound", 0, true, true, false, 1),
            ("punctilious", 1, true, false, true, 6),
            ("desultory", 19, true, false, false, 0),
            ("irresolute", 0, true, true, false, 1),
            ("censure", 0, true, true, false, 1),
            ("interchangeable", 0, true, true, false, 1),
            ("lucrative", 0, true, true, false, 1),
            ("invidious", 1, true, false, false, 0),
            ("dilatory", 0, true, true, false, 1),
            ("robust", 0, true, true, false, 1),
            ("desiccate", 0, true, true, false, 1),
            ("estranged", 2, true, false, true, 5),
            ("truculent", 4, true, false, false, 0),
            ("sever", 7, true, false, false, 0),
            ("alacrity", 0, true, true, false, 1),
            ("corroborate", 0, true, true, false, 1),
            ("repudiate", 0, true, true, false, 1),
            ("trivial", 0, true, true, false, 1),
            ("antithesis", 0, true, true, false, 1),
            ("engender", 0, true, true, false, 1),
            ("venal", 3, true, false, true, 5),
            ("decadent", 0, true, true, false, 1),
            ("deference", 0, true, true, false, 1),
            ("alleviate", 1, true, false, true, 5),
            ("loquacious", 0, true, true, false, 1),
            ("presumptuous", 25, true, false, false, 4),
            ("gainsay", 17, true, false, true, 5),
            ("hodgepodge", 12, true, false, true, 5),
            ("spartan", 3, true, false, false, 1),
            ("scant", 24, true, false, false, 0),
            ("conventional", 0, true, true, false, 1),
            ("predilection", 0, true, true, false, 1),
            ("exhaustive", 1, true, false, false, 0),
            ("invasive", 0, true, true, false, 1),
            ("ostentatious", 0, true, true, false, 1),
            ("hyperbole", 0, true, true, false, 1),
            ("nullify", 0, true, true, false, 1),
            ("preclude", 4, true, false, false, 0),
            ("flamboyant", 0, true, true, false, 1),
            ("timorous", 16, true, false, true, 5),
            ("circumspect", 8, true, false, true, 5),
            ("indispensable", 0, true, true, false, 1),
            ("audacious", 0, true, true, false, 1),
            ("compelling", 0, true, true, false, 1),
            ("somnolent", 0, true, true, false, 1),
            ("spurious", 19, true, false, true, 5),
            ("furtive", 1, true, false, true, 5),
            ("brook", 20, true, false, false, 1),
            ("satirical", 0, true, true, false, 1),
            ("limpid", 4, true, false, false, 0),
            ("fanciful", 9, true, false, true, 5),
            ("austere", 0, true, true, false, 1),
            ("quirky", 21, true, false, false, 0),
            ("forbear", 20, true, false, false, 0),
            ("ameliorate", 1, true, false, true, 6),
            ("imperious", 1, true, false, true, 6),
            ("wary", 0, true, true, false, 1),
            ("mimic", 0, true, true, false, 1),
            ("stigmatize", 0, true, true, false, 1),
            ("extraneous", 1, true, false, false, 0),
            ("sham", 4, true, false, false, 0),
            ("decorum", 1, true, false, true, 7),
            ("anachronistic", 0, true, true, false, 1),
            ("ascetic", 0, true, true, false, 1),
            ("documentary", 0, true, true, false, 1),
            ("dupe", 2, true, false, true, 5),
            ("immutable", 0, true, true, false, 1),
            ("appease", 8, true, false, true, 5),
            ("capricious", 2, true, false, true, 5),
            ("sagacious", 12, true, false, true, 5),
            ("acumen", 7, true, false, false, 0),
            ("derivative", 1, true, false, true, 6),
            ("cursory", 0, true, true, false, 1),
            ("scrupulous", 2, true, false, true, 6),
            ("partial", 0, true, true, false, 1),
            ("cosmopolitan", 0, true, true, false, 1),
            ("empirical", 0, true, true, false, 1),
            ("castigate", 0, true, true, false, 1),
            ("elicit", 20, true, false, false, 0),
            ("incongruous", 0, true, true, false, 1),
            ("countenance", 1, true, false, false, 0),
            ("invigorate", 0, true, true, false, 1),
            ("undermine", 0, true, true, false, 1),
            ("frivolous", 1, true, false, true, 5),
            ("fungible", 1, true, false, false, 0),
            ("obscure", 1, true, false, false, 0),
            ("palpable", 0, true, true, false, 1),
            ("exhilarating", 1, true, false, false, 0),
            ("benign", 0, true, true, false, 1),
            ("tout", 7, true, false, false, 0),
            ("bolster", 9, true, false, true, 5),
            ("opprobrium", 1, true, false, false, 0),
            ("felicitous", 0, true, true, false, 1),
            ("candid", 19, true, false, true, 5),
            ("fecund", 0, true, true, false, 1),
            ("trifling", 16, true, false, false, 4),
            ("deliberate", 2, true, false, false, 2),
            ("magisterial", 1, true, false, false, 0),
            ("insular", 5, true, false, true, 5),
            ("disseminate", 0, true, true, false, 1),
            ("lax", 11, true, false, true, 6),
            ("evanescent", 1, true, false, true, 6),
            ("quixotic", 2, true, false, true, 6),
            ("illusory", 0, true, true, false, 1),
            ("salubrious", 5, true, false, true, 5),
            ("numinous", 1, true, false, false, 0),
            ("perpetuate", 0, true, true, false, 1),
            ("encyclopedic", 0, true, true, false, 1),
            ("proliferate", 0, true, true, false, 1),
            ("utterly", 0, true, true, false, 1),
            ("malleable", 0, true, true, false, 1),
            ("analogous", 3, true, false, true, 5),
            ("flout", 0, true, true, false, 1),
            ("diffident", 35, true, false, false, 2),
            ("prescient", 5, true, false, true, 5),
            ("remedial", 3, true, false, true, 5),
            ("entitled", 3, true, false, true, 5),
            ("feign", 6, true, false, false, 1),
            ("conjectural", 4, true, false, true, 5),
            ("momentary", 0, true, true, false, 1),
            ("impetuous", 17, true, false, false, 0),
            ("obviate", 1, true, false, true, 5),
            ("subjective", 0, true, true, false, 1),
            ("dwindling", 1, true, false, false, 0),
            ("scathing", 1, true, false, false, 0),
            ("diminutive", 0, true, true, false, 1),
            ("compromise", 0, true, true, false, 1),
            ("homogeneous", 0, true, true, false, 1),
            ("mundane", 0, true, true, false, 1),
        ]
    }
    
    private func loadAllProgress() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<WordProgress>()
        if let results = try? context.fetch(descriptor) {
            progressCache = deduplicated(results, in: context)

            // Safety net: restore from the auto-backup whenever there is NO studied
            // progress — store empty, OR present but every row lost its studied flags
            // (e.g. after a bad sync/migration). The import upserts in place, so it
            // repopulates studied/mastered status without creating duplicates.
            let hasStudied = progressCache.values.contains { $0.hasSeenOnce }
            if !hasStudied {
                restoreFromAutoBackupIfNeeded()
                if let restored = try? context.fetch(descriptor) {
                    progressCache = deduplicated(restored, in: context)
                }
            }

            print("✅ Loaded progress for \(progressCache.count) words")
        }
    }

    /// CloudKit has no unique constraint, so the same `word` can land as multiple
    /// rows (local + synced, or two devices). Collapse to one row per word —
    /// keeping the most-studied — and delete the rest so difficulty tiers stay correct.
    private func deduplicated(_ rows: [WordProgress], in context: ModelContext) -> [String: WordProgress] {
        var kept: [String: WordProgress] = [:]
        var doomed: [WordProgress] = []

        func score(_ p: WordProgress) -> Int {
            (p.hasSeenOnce ? 1 : 0) + p.wrongCount + p.consecutiveCorrectCount
                + (p.wasPromotedToEasy ? 5 : 0) + (p.knewOnFirstTry ? 5 : 0)
        }

        for row in rows {
            if let existing = kept[row.word] {
                if score(row) > score(existing) {
                    doomed.append(existing)
                    kept[row.word] = row
                } else {
                    doomed.append(row)
                }
            } else {
                kept[row.word] = row
            }
        }

        if !doomed.isEmpty {
            doomed.forEach { context.delete($0) }
            try? context.save()
            print("🧹 Merged \(doomed.count) duplicate WordProgress row(s)")
        }
        return kept
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
        // Primary location (written by the app on every save).
        let appSupport = URL.applicationSupportDirectory.appending(path: autoBackupFileName)
        if FileManager.default.fileExists(atPath: appSupport.path) { return appSupport }
        // Fallback: file pushed via devicectl to Documents during a manual restore.
        let docs = URL.documentsDirectory.appending(path: autoBackupFileName)
        return docs
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
                progress.masteredDate = item.masteredDate
            }

            try context.save()
            print("♻️ Restored progress from auto-backup (\(backup.count) words)")
        } catch {
            print("⚠️ Failed to restore from auto-backup: \(error)")
        }
    }
    
    /// Words the user struggles with, hardest first. Reads only the in-memory
    /// cache (already-studied words) so it never inserts new WordProgress rows.
    /// Hard tier (20+ wrong) ranks above Medium; within a tier, more wrong = earlier.
    func strugglingWords() -> [String] {
        progressCache.values
            .filter { $0.hasSeenOnce && ($0.difficultyTier == .hard || $0.difficultyTier == .medium) }
            .sorted { lhs, rhs in
                if lhs.difficultyTier == rhs.difficultyTier { return lhs.wrongCount > rhs.wrongCount }
                return lhs.difficultyTier == .hard   // hard before medium
            }
            .map { $0.word }
    }

    /// How many words the user moved into an Easy tier (Natural or Mastered)
    /// today. This is the daily streak metric — "words learned today".
    func masteredTodayCount() -> Int {
        progressCache.values.filter { p in
            guard let date = p.masteredDate, Calendar.current.isDateInToday(date) else { return false }
            return p.difficultyTier == .easyNatural || p.difficultyTier == .easyMastered
        }.count
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
                    lastReviewedDate: progress.lastReviewedDate,
                    masteredDate: progress.masteredDate
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
            progress.masteredDate = item.masteredDate
        }
        
        saveContext()
        loadAllProgress() // Refresh cache
    }
}
