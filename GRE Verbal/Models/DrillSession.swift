import Foundation
import SwiftData

@Model
final class DrillSession {
    var date: Date
    var questionCount: Int
    var estimatedTimePerQuestion: Double  // seconds
    var totalElapsedTime: Double          // seconds
    var questionTimes: [Double]           // legacy: locked-in times in locking order
    var wrongQuestions: [Int]             // legacy: 1-based question numbers marked wrong

    // Per-question detail (populated for new sessions only; empty = legacy session)
    var perQuestionStates: [String]       // 0-based: "correct" | "wrong" | "unanswered"
    var perQuestionElapsed: [Double]      // 0-based: seconds spent on each question (0 = unanswered)

    private static let correctAliases: Set<String> = ["correct", "right"]
    private static let wrongAliases: Set<String> = ["wrong", "incorrect", "x"]
    private static let unansweredAliases: Set<String> = ["unanswered", "pending", "skipped", "skip", "-"]

    init(
        date: Date = .now,
        questionCount: Int,
        estimatedTimePerQuestion: Double,
        totalElapsedTime: Double,
        questionTimes: [Double],
        wrongQuestions: [Int],
        perQuestionStates: [String] = [],
        perQuestionElapsed: [Double] = []
    ) {
        self.date = date
        self.questionCount = questionCount
        self.estimatedTimePerQuestion = estimatedTimePerQuestion
        self.totalElapsedTime = totalElapsedTime
        self.questionTimes = questionTimes
        self.wrongQuestions = wrongQuestions
        self.perQuestionStates = perQuestionStates
        self.perQuestionElapsed = perQuestionElapsed
    }

    // MARK: - Computed (new-session)

    var correctQuestions: [Int] {
        normalizedPerQuestionStates.enumerated().compactMap { idx, s in s == "correct" ? idx + 1 : nil }
    }

    var unansweredQuestions: [Int] {
        normalizedPerQuestionStates.enumerated().compactMap { idx, s in s == "unanswered" ? idx + 1 : nil }
    }

    var displayCorrectCount: Int {
        if normalizedPerQuestionStates.isEmpty {
            return max(0, questionCount - wrongQuestions.count)
        }
        return normalizedPerQuestionStates.filter { $0 == "correct" }.count
    }

    var displayWrongCount: Int {
        if normalizedPerQuestionStates.isEmpty {
            return wrongQuestions.count
        }
        return normalizedPerQuestionStates.filter { $0 == "wrong" }.count
    }

    var displayUnansweredCount: Int {
        if normalizedPerQuestionStates.isEmpty {
            return 0
        }
        return normalizedPerQuestionStates.filter { $0 == "unanswered" }.count
    }

    // MARK: - Computed (both)

    var errorRate: Double {
        // New sessions: error rate is based on answered questions only (correct + wrong).
        if !normalizedPerQuestionStates.isEmpty {
            let wrongCount = displayWrongCount
            let answeredCount = displayCorrectCount + wrongCount
            guard answeredCount > 0 else { return 0 }
            return Double(wrongCount) / Double(answeredCount)
        }

        // Legacy sessions: unanswered count is not available, keep original behavior.
        guard questionCount > 0 else { return 0 }
        return Double(wrongQuestions.count) / Double(questionCount)
    }

    var avgTimePerQuestion: Double {
        if !perQuestionElapsed.isEmpty {
            let answered = perQuestionElapsed.filter { $0 > 0 }
            guard !answered.isEmpty else { return 0 }
            return answered.reduce(0, +) / Double(answered.count)
        }
        guard !questionTimes.isEmpty else { return 0 }
        return questionTimes.reduce(0, +) / Double(questionTimes.count)
    }

    func displayState(forQuestionAt index: Int) -> String {
        guard index >= 0, index < normalizedPerQuestionStates.count else {
            return "unanswered"
        }
        return normalizedPerQuestionStates[index]
    }

    // Canonicalize legacy or variant values so analytics remain stable across old sessions.
    private var normalizedPerQuestionStates: [String] {
        perQuestionStates.enumerated().map { idx, rawState in
            normalizeState(rawState, questionNumber: idx + 1)
        }
    }

    private func normalizeState(_ rawState: String, questionNumber: Int) -> String {
        let key = rawState
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if Self.correctAliases.contains(key) { return "correct" }
        if Self.wrongAliases.contains(key) { return "wrong" }
        if Self.unansweredAliases.contains(key) { return "unanswered" }

        // Fallback for old sessions with non-canonical strings.
        if wrongQuestions.contains(questionNumber) {
            return "wrong"
        }

        return "unanswered"
    }
}
