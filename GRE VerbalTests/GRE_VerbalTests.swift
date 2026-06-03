//
//  GRE_VerbalTests.swift
//  GRE VerbalTests
//
//  Created by Martin Olivares on 23-01-26.
//

import Testing
import Foundation
import SwiftData
@testable import GRE_Verbal

struct GRE_VerbalTests {

    // MARK: - Helpers

    private func makeProgressManager(_ words: [WordProgress]) throws -> ProgressManager {
        let schema = Schema([WordProgress.self, AppSettings.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        for w in words { context.insert(w) }
        try context.save()

        let pm = ProgressManager()
        pm.configure(with: context)
        return pm
    }

    private func progress(_ word: String, wrongCount: Int, seen: Bool = true,
                          knewFirst: Bool = false) -> WordProgress {
        let p = WordProgress(word: word)
        p.hasSeenOnce = seen
        p.wrongCount = wrongCount
        p.knewOnFirstTry = knewFirst
        return p
    }

    private func vocab(_ word: String, pos: String = "adjective",
                       def: String = "a definition", sentence: String = "A sentence.") -> VocabWord {
        VocabWord(group: "Group 1", word: word, pronunciation: "http://x.mp3",
                  definitions: [Definition(partOfSpeech: pos, definition: def,
                                           sentence: sentence, synonyms: [])])
    }

    // MARK: - strugglingWords() ordering (the shield "hard words first" source)

    @Test func strugglingWordsRanksHardBeforeMediumByWrongCount() throws {
        let pm = try makeProgressManager([
            progress("cogent",   wrongCount: 5),    // medium
            progress("aberrant", wrongCount: 25),   // hard
            progress("laconic",  wrongCount: 12),   // medium
            progress("zenith",   wrongCount: 30),   // hard
            progress("abound",   wrongCount: 0, knewFirst: true), // easy → excluded
        ])

        let result = pm.strugglingWords()

        // Hard tier first (hardest by wrongCount), then medium (most-wrong first).
        #expect(result == ["zenith", "aberrant", "laconic", "cogent"])
    }

    @Test func strugglingWordsExcludesEasyAndUnseen() throws {
        let pm = try makeProgressManager([
            progress("abound", wrongCount: 0, knewFirst: true),   // easy
            progress("ghost",  wrongCount: 9, seen: false),       // never seen → unlocked
        ])
        #expect(pm.strugglingWords().isEmpty)
    }

    // MARK: - ShieldWord (the wire contract the extension decodes)

    @Test func shieldWordTakesFirstDefinition() {
        let sw = ShieldWord(vocab("perfunctory", pos: "adjective",
                                  def: "carried out with minimum effort", sentence: "A perfunctory nod."))
        #expect(sw?.word == "perfunctory")
        #expect(sw?.pos == "adjective")
        #expect(sw?.def == "carried out with minimum effort")
        #expect(sw?.sentence == "A perfunctory nod.")
    }

    @Test func shieldWordIsNilWithoutDefinitions() {
        let empty = VocabWord(group: "g", word: "x", pronunciation: "", definitions: [])
        #expect(ShieldWord(empty) == nil)
    }

    /// The shield extension decodes JSON with keys word/pos/def/sentence. If the
    /// main app's encoding drifts from those keys, the shield silently shows the
    /// fallback word. Lock the contract.
    @Test func shieldWordJSONUsesExpectedKeys() throws {
        let sw = ShieldWord(vocab("laconic"))!
        let data = try JSONEncoder().encode(sw)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(obj?["word"] != nil)
        #expect(obj?["pos"] != nil)
        #expect(obj?["def"] != nil)
        #expect(obj?["sentence"] != nil)
    }

    // MARK: - buildDeck resets session state

    /// Regression: starting a new drill must clear the previous session's
    /// completion overlay. Otherwise a second drill opens straight into
    /// "Session Complete, 0 known" until the app is relaunched.
    @MainActor
    @Test func buildDeckClearsStaleSessionCompleteFlag() throws {
        let schema = Schema([WordProgress.self, AppSettings.self])
        let container = try ModelContainer(for: schema,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let pm = ProgressManager()
        pm.configure(with: ModelContext(container))

        let vm = FlashcardViewModel(repository: VocabRepository(), progressManager: pm)
        vm.showingSessionComplete = true   // simulate a just-finished session
        vm.knownCount = 12

        vm.buildDeck()

        #expect(vm.showingSessionComplete == false)
        #expect(vm.knownCount == 0)
        #expect(vm.currentIndex == 0)
    }

    // MARK: - Daily streak goal (2% of the deck)

    @Test func dailyGoalIsTwoPercentRoundedUp() {
        let s = StreakManager.shared
        #expect(s.dailyGoal(totalWords: 1020) == 21)   // 20.4 → 21
        #expect(s.dailyGoal(totalWords: 1000) == 20)   // exactly 20
        #expect(s.dailyGoal(totalWords: 50) == 1)      // 1.0 → 1
        #expect(s.dailyGoal(totalWords: 0) == 1)       // guard
    }

    @Test func masteredTodayCountsOnlyEasyWordsLearnedToday() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let naturalToday = progress("abound", wrongCount: 0, knewFirst: true)
        naturalToday.masteredDate = today

        let masteredYesterday = progress("cogent", wrongCount: 0, knewFirst: true)
        masteredYesterday.masteredDate = yesterday      // learned, but not today

        let mediumToday = progress("laconic", wrongCount: 5)
        mediumToday.masteredDate = today                // wrong tier (medium), shouldn't count

        let pm = try makeProgressManager([naturalToday, masteredYesterday, mediumToday])
        #expect(pm.masteredTodayCount() == 1)
    }

    @Test func shieldWordRoundTripsThroughJSON() throws {
        let original = ShieldWord(vocab("ephemeral", pos: "adjective",
                                        def: "lasting a very short time", sentence: "Ephemeral joy."))!
        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([ShieldWord].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded.first?.word == "ephemeral")
        #expect(decoded.first?.sentence == "Ephemeral joy.")
    }
}
