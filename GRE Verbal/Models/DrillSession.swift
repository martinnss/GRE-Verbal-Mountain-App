import Foundation
import SwiftData

@Model
final class DrillSession {
    var date: Date
    var questionCount: Int
    var estimatedTimePerQuestion: Double  // seconds
    var totalElapsedTime: Double          // seconds
    var questionTimes: [Double]           // per-question elapsed times (seconds), indexed 0-based
    var wrongQuestions: [Int]             // 1-based question numbers marked wrong

    init(
        date: Date = .now,
        questionCount: Int,
        estimatedTimePerQuestion: Double,
        totalElapsedTime: Double,
        questionTimes: [Double],
        wrongQuestions: [Int]
    ) {
        self.date = date
        self.questionCount = questionCount
        self.estimatedTimePerQuestion = estimatedTimePerQuestion
        self.totalElapsedTime = totalElapsedTime
        self.questionTimes = questionTimes
        self.wrongQuestions = wrongQuestions
    }

    var errorRate: Double {
        guard questionCount > 0 else { return 0 }
        return Double(wrongQuestions.count) / Double(questionCount)
    }

    var avgTimePerQuestion: Double {
        guard !questionTimes.isEmpty else { return 0 }
        return questionTimes.reduce(0, +) / Double(questionTimes.count)
    }
}
