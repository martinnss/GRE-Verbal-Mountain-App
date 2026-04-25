import SwiftUI
import SwiftData

// MARK: - Question State

enum QuestionState {
    case pending
    case correct
    case wrong
}

// MARK: - Drill Phase

enum DrillPhase {
    case setup
    case active
    case ended
}

// MARK: - ViewModel

@Observable
final class DrillTimerViewModel {

    // Setup inputs
    var questionCount: Int = 20
    var secondsPerQuestion: Double = 120  // default 2 minutes, steps by 10s

    // Phase control
    var phase: DrillPhase = .setup

    // Timer state
    var started: Bool = false
    var paused: Bool = false
    var totalElapsed: Double = 0      // seconds

    // Per-question elapsed times — one slot per question, accumulates only for currentQuestion
    var questionElapsedTimes: [Double] = []

    // Question tracking
    var questionStates: [QuestionState] = []
    var questionTimes: [Double] = []   // legacy persisted field for old sessions
    var currentQuestion: Int = 1       // 1-based

    // Saved session (set after endDrill)
    var lastSession: DrillSession?

    private var timer: Timer?
    private var lastTickDate: Date?
    private let timerInterval: TimeInterval = 0.25
    private var modelContext: ModelContext?

    // MARK: - Computed

    var totalSeconds: Double {
        secondsPerQuestion * Double(questionCount)
    }

    /// Time spent on the currently focused question
    var currentQuestionElapsed: Double {
        let idx = currentQuestion - 1
        guard idx >= 0, idx < questionElapsedTimes.count else { return 0 }
        return questionElapsedTimes[idx]
    }

    var avgCompletedTime: Double {
        let completedTimes = questionStates.enumerated().compactMap { idx, state -> Double? in
            switch state {
            case .pending:
                return nil
            case .correct, .wrong:
                return idx < questionElapsedTimes.count ? questionElapsedTimes[idx] : nil
            }
        }
        guard !completedTimes.isEmpty else { return 0 }
        return completedTimes.reduce(0, +) / Double(completedTimes.count)
    }

    // Time remaining divided by pending (not-yet-done) questions
    var avgTimeRemaining: Double {
        let pendingCount = questionStates.reduce(0) { partial, state in
            switch state {
            case .pending: return partial + 1
            case .correct, .wrong: return partial
            }
        }
        guard pendingCount > 0, totalElapsed > 0 else { return 0 }
        let remaining = max(0, totalSeconds - totalElapsed)
        return remaining / Double(pendingCount)
    }

    var completedCount: Int {
        questionStates.reduce(0) { partial, state in
            switch state {
            case .pending: return partial
            case .correct, .wrong: return partial + 1
            }
        }
    }

    var wrongQuestions: [Int] {
        questionStates.enumerated().compactMap { idx, state in
            switch state {
            case .wrong: return idx + 1
            case .pending, .correct: return nil
            }
        }
    }

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startDrill() {
        questionStates = Array(repeating: .pending, count: questionCount)
        questionElapsedTimes = Array(repeating: 0.0, count: questionCount)
        questionTimes = []
        currentQuestion = 1
        totalElapsed = 0
        started = false
        lastSession = nil
        phase = .active
    }

    // MARK: - Timer Control

    func startTimers() {
        guard !started else { return }
        started = true
        paused = false
        lastTickDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
            guard let self else { return }

            let now = Date()
            let previousTick = self.lastTickDate ?? now
            self.lastTickDate = now

            if self.paused { return }

            let delta = min(1.0, max(0.0, now.timeIntervalSince(previousTick)))
            self.totalElapsed += delta

            // Only accumulate time for the currently focused question (if still pending)
            let idx = self.currentQuestion - 1
            if idx >= 0, idx < self.questionElapsedTimes.count {
                if case .pending = self.questionStates[idx] {
                    self.questionElapsedTimes[idx] += delta
                }
            }
        }
    }

    func pauseToggle() {
        guard started else { return }
        paused.toggle()
        if !paused {
            lastTickDate = Date()
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        lastTickDate = nil
    }

    // MARK: - Question Interactions

    /// Single tap:
    ///   - If tapping the current (focused) question -> mark it correct
    ///   - If tapping any other pending question -> navigate (focus) without marking
    func tapQuestion(_ number: Int) {
        let idx = number - 1
        guard idx >= 0, idx < questionStates.count, started else { return }

        if number == currentQuestion {
            guard isPending(questionStates[idx]) else { return }
            lockQuestion(idx, state: .correct)
        } else {
            // Navigate: only move focus to pending questions
            guard isPending(questionStates[idx]) else { return }
            currentQuestion = number
        }
    }

    /// Double tap:
    ///   - If question is pending -> mark it wrong (and advance)
    ///   - If question is correct -> change it to wrong
    ///   - If question is wrong -> revert to pending (default state)
    func longPressQuestion(_ number: Int) {
        let idx = number - 1
        guard idx >= 0, idx < questionStates.count, started else { return }

        switch questionStates[idx] {
        case .pending:
            currentQuestion = number
            lockQuestion(idx, state: .wrong)
        case .correct:
            questionStates[idx] = .wrong
            currentQuestion = number
        case .wrong:
            questionStates[idx] = .pending
            currentQuestion = number
        }
    }

    private func lockQuestion(_ idx: Int, state: QuestionState) {
        questionStates[idx] = state

        // Advance currentQuestion to next pending
        let next = (idx + 1 ..< questionStates.count).first { isPending(questionStates[$0]) }
            ?? (0 ..< idx).first { isPending(questionStates[$0]) }

        if let next {
            currentQuestion = next + 1
        } else {
            currentQuestion = questionCount + 1  // all done
        }
    }

    private func isPending(_ state: QuestionState) -> Bool {
        if case .pending = state {
            return true
        }
        return false
    }

    // MARK: - End / Reset

    func endDrill() {
        stopTimers()
        saveDrillSession()
        phase = .ended
    }

    func resetDrill() {
        stopTimers()
        paused = false
        questionStates = []
        questionElapsedTimes = []
        questionTimes = []
        totalElapsed = 0
        currentQuestion = 1
        started = false
        lastSession = nil
        phase = .setup
    }

    private func saveDrillSession() {
        guard let modelContext else { return }

        let completedTimes: [Double] = questionStates.enumerated().compactMap { idx, state in
            switch state {
            case .pending:
                return nil
            case .correct, .wrong:
                return idx < questionElapsedTimes.count ? questionElapsedTimes[idx] : nil
            }
        }

        // Build per-question state strings (pending -> unanswered at save time)
        let states: [String] = questionStates.map { state in
            switch state {
            case .correct:  return "correct"
            case .wrong:    return "wrong"
            case .pending:  return "unanswered"
            }
        }

        let session = DrillSession(
            questionCount: questionCount,
            estimatedTimePerQuestion: secondsPerQuestion,
            totalElapsedTime: totalElapsed,
            questionTimes: completedTimes,
            wrongQuestions: wrongQuestions,
            perQuestionStates: states,
            perQuestionElapsed: questionElapsedTimes
        )
        modelContext.insert(session)
        try? modelContext.save()
        lastSession = session
    }

    // MARK: - Formatting Helpers

    static func format(seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
