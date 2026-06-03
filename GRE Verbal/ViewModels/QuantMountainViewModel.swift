import Foundation
import Observation

@Observable
class QuantMountainViewModel {

    // MARK: - Raw data
    private(set) var cards: [QuantCard] = []
    private(set) var groupedCards: [String: [QuantCard]] = [:]     // "Arithmetic 1" → [cards]

    // MARK: - All ordered mountain groups  ("Arithmetic 1", "Arithmetic 2", …)
    private(set) var mountainGroups: [String] = []

    // MARK: - Distinct categories in order  ("Arithmetic", "Algebra", …)
    private(set) var categories: [String] = []

    // MARK: - Selection state  (home screen)
    var selectedCategory: String = ""
    var selectedMountainRange: ClosedRange<Int> = 1...1

    // MARK: - Init
    init() { loadCards() }

    // MARK: - Load

    private func loadCards() {
        guard
            let url  = Bundle.main.url(forResource: "quant_mountain", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([QuantCard].self, from: data)
        else { return }

        cards = decoded
        groupedCards = Dictionary(grouping: decoded) { $0.mountain_group }

        // Preserve original order (first occurrence wins)
        var seenGroups    = Set<String>()
        var seenCats      = Set<String>()
        var orderedGroups = [String]()
        var orderedCats   = [String]()

        for card in decoded {
            if !seenGroups.contains(card.mountain_group) {
                seenGroups.insert(card.mountain_group)
                orderedGroups.append(card.mountain_group)
            }
            let cat = categoryName(from: card.mountain_group)
            if !seenCats.contains(cat) {
                seenCats.insert(cat)
                orderedCats.append(cat)
            }
        }
        mountainGroups = orderedGroups
        categories     = orderedCats
        selectedCategory = orderedCats.first ?? ""
    }

    // MARK: - Helpers

    /// "Arithmetic 3"  →  "Arithmetic"
    func categoryName(from group: String) -> String {
        let parts = group.components(separatedBy: " ")
        // Last component is usually the number; everything before is the category
        guard parts.count > 1, Int(parts.last ?? "") != nil else { return group }
        return parts.dropLast().joined(separator: " ")
    }

    /// "Arithmetic 3"  →  3
    func mountainNumber(from group: String) -> Int {
        Int(group.components(separatedBy: " ").last ?? "") ?? 0
    }

    /// How many mountains exist for the currently selected category
    var mountainCountForCategory: Int {
        mountainGroups
            .filter { categoryName(from: $0) == selectedCategory }
            .count
    }

    /// Cards that belong to the selected category + range
    var cardsForSelection: [QuantCard] {
        let lo = selectedMountainRange.lowerBound
        let hi = selectedMountainRange.upperBound
        return (lo...hi).flatMap { n in
            groupedCards["\(selectedCategory) \(n)"] ?? []
        }
    }

    /// Reset range when category changes
    func selectCategory(_ cat: String) {
        selectedCategory = cat
        selectedMountainRange = 1...1
    }
}
