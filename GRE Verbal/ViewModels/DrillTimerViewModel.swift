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
    var questionElapsed: Double = 0   // seconds, resets per question

    // Question tracking
    var questionStates: [QuestionState] = []
    var questionTimes: [Double] = []   // locked-in time for each completed question
    var currentQuestion: Int = 1       // 1-based

    // Saved session (set after endDrill)
    var lastSession: DrillSession?

    private var timer: Timer?
    private var modelContext: ModelContext?

    // MARK: - Computed

    var totalSeconds: Double {
        secondsPerQuestion * Double(questionCount)
    }

    var avgCompletedTime: Double {
        guard !questionTimes.isEmpty else { return 0 }
        return questionTimes.reduce(0, +) / Double(questionTimes.count)
    }

    // Time remaining divided by pending (not-yet-done) questions
    var avgTimeRemaining: Double {
        let pendingCount = questionStates.filter { $0 == .pending }.count
        guard pendingCount > 0, totalElapsed > 0 else { return 0 }
        let remaining = max(0, totalSeconds - totalElapsed)
        return remaining / Double(pendingCount)
    }

    var completedCount: Int { questionTimes.count }

    var wrongQuestions: [Int] {
        questionStates.enumerated().compactMap { idx, state in
            state == .wrong ? idx + 1 : nil
        }
    }

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startDrill() {
        questionStates = Array(repeating: .pending, count: questionCount)
        questionTimes = []
        currentQuestion = 1
        totalElapsed = 0
        questionElapsed = 0
        started = false
        lastSession = nil
        phase = .active
    }

    // MARK: - Timer Control

    func startTimers() {
        guard !started else { return }
        started = true
        paused = false
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, !self.paused else { return }
            self.totalElapsed += 0.1
            self.questionElapsed += 0.1
        }
    }

    func pauseToggle() {
        guard started else { return }
        paused.toggle()
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Question Interactions

    func tapQuestion(_ number: Int) {
        let idx = number - 1
        guard idx >= 0, idx < questionStates.count else { return }
        guard questionStates[idx] == .pending else { return }
        lockQuestion(idx, state: .correct)
    }

    func longPressQuestion(_ number: Int) {
        let idx = number - 1
        guard idx >= 0, idx < questionStates.count else { return }
        guard questionStates[idx] == .pending else { return }
        lockQuestion(idx, state: .wrong)
    }

    private func lockQuestion(_ idx: Int, state: QuestionState) {
        questionStates[idx] = state
        questionTimes.append(questionElapsed)
        questionElapsed = 0

        // Advance currentQuestion to next pending
        let next = (idx + 1 ..< questionStates.count).first { questionStates[$0] == .pending }
        if let next {
            currentQuestion = next + 1
        } else {
            // All done — advance past last
            currentQuestion = questionCount + 1
        }
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
        questionTimes = []
        totalElapsed = 0
        questionElapsed = 0
        currentQuestion = 1
        started = false
        lastSession = nil
        phase = .setup
    }

    private func saveDrillSession() {
        guard let modelContext else { return }
        let session = DrillSession(
            questionCount: questionCount,
            estimatedTimePerQuestion: secondsPerQuestion,
            totalElapsedTime: totalElapsed,
            questionTimes: questionTimes,
            wrongQuestions: wrongQuestions
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
