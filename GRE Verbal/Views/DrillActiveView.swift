import SwiftUI

struct DrillActiveView: View {
    @Bindable var vm: DrillTimerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showEndAlert = false
    @State private var showResetAlert = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    private let currentQuestionAccent = Color(hex: "C4935A")

    var body: some View {
        ZStack {
            Color(hex: "060D07").ignoresSafeArea()
            StarfieldBackground(showAnimatedStars: false)

            VStack(spacing: 0) {
                // Top ~33%: Dual clock panel
                clockPanel
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.33)

                // Bottom ~67%: Question grid + toolbar
                VStack(spacing: 16) {
                    questionGrid
                    toolbarRow
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("End Drill?", isPresented: $showEndAlert) {
            Button("End & Save", role: .destructive) {
                vm.endDrill()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your drill will be saved to history.")
        }
        .alert("Reset Drill?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                vm.resetDrill()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Progress will be lost and nothing will be saved.")
        }
    }

    // MARK: - Clock Panel

    private var clockPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(.ultraThinMaterial.opacity(0.3))
                .background(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 8) {
                // Tap-to-start overlay
                if !vm.started {
                    tapToStartOverlay
                } else if vm.paused {
                    pausedOverlay
                } else {
                    clocksRow
                    statsRow
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !vm.started {
                vm.startTimers()
            } else if vm.paused {
                vm.pauseToggle()
            }
        }
    }

    private var tapToStartOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: "4ADE80").opacity(0.8))
            Text("TAP TO START")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .kerning(3)
            Text("\(vm.questionCount) questions · \(minutesLabel) each")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            Text("tap current = ✓  ·  tap other = navigate  ·  double-tap = ✗")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
                .kerning(0.5)
        }
    }

    private var pausedOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: "4ADE80").opacity(0.8))
            Text("PAUSED")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .kerning(3)
            Text("Tap the clock area or Resume to continue")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var clocksRow: some View {
        HStack(spacing: 0) {
            // Total set timer
            VStack(spacing: 4) {
                Text("SET")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .kerning(2)
                Text(DrillTimerViewModel.format(seconds: vm.totalElapsed))
                    .font(.system(size: 46, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1, height: 60)

            // Per-question timer
            VStack(spacing: 4) {
                Text("QUESTION")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .kerning(2)
                Text(DrillTimerViewModel.format(seconds: vm.currentQuestionElapsed))
                    .font(.system(size: 46, weight: .bold, design: .monospaced))
                    .foregroundStyle(questionTimerColor)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var questionTimerColor: Color {
        let estimate = vm.secondsPerQuestion
        guard estimate > 0 else { return Color(hex: "4ADE80") }
        let ratio = vm.currentQuestionElapsed / estimate
        if ratio < 0.75 { return Color(hex: "4ADE80") }
        if ratio < 1.0  { return .orange }
        return .red
    }

    private var statsRow: some View {
        HStack {
            // Avg completed
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption2)
                    .foregroundStyle(.mint.opacity(0.7))
                Text("Avg \(DrillTimerViewModel.format(seconds: vm.avgCompletedTime))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }

            Spacer()

            // Current question counter
            let current = min(vm.currentQuestion, vm.questionCount)
            Text("Q \(current) / \(vm.questionCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(currentQuestionAccent.opacity(0.85))

            Spacer()

            // Avg time remaining per pending question
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .font(.caption2)
                    .foregroundStyle(.orange.opacity(0.7))
                Text("Left \(DrillTimerViewModel.format(seconds: vm.avgTimeRemaining))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Question Grid

    private var questionGrid: some View {
        Group {
            if !vm.questionStates.isEmpty {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(1...vm.questionCount, id: \.self) { number in
                        questionCircle(number: number)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    @ViewBuilder
    private func questionCircle(number: Int) -> some View {
        let idx = number - 1
        // Guard against the frame where SwiftUI evaluates children of a
        // LazyVGrid that is mid-removal (questionStates already cleared).
        if idx >= 0, idx < vm.questionStates.count {
            let state = vm.questionStates[idx]
            let isCurrent = number == vm.currentQuestion && vm.started

            ZStack {
                Circle()
                    .fill(circleFill(state: state, isCurrent: isCurrent))
                    .overlay(
                        Circle()
                            .strokeBorder(circleBorder(state: state, isCurrent: isCurrent), lineWidth: isCurrent ? 2.5 : 1.5)
                    )
                    .shadow(color: circleShadow(state: state, isCurrent: isCurrent), radius: isCurrent ? 10 : 4)

                Text("\(number)")
                    .font(.system(size: circleFont(count: vm.questionCount), weight: .bold, design: .rounded))
                    .foregroundStyle(circleTextColor(state: state, isCurrent: isCurrent))
            }
            .frame(width: circleSize(count: vm.questionCount), height: circleSize(count: vm.questionCount))
            .scaleEffect(isCurrent ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCurrent)
            .onTapGesture(count: 2) {
                if vm.started {
                    vm.longPressQuestion(number)
                }
            }
            .onTapGesture(count: 1) {
                if state == .pending && vm.started {
                    vm.tapQuestion(number)
                }
            }
        } // end bounds guard
    }

    // MARK: - Circle Styling

    private func circleSize(count: Int) -> CGFloat {
        count <= 20 ? 56 : count <= 30 ? 48 : 42
    }

    private func circleFont(count: Int) -> CGFloat {
        count <= 20 ? 18 : count <= 30 ? 15 : 13
    }

    private func circleFill(state: QuestionState, isCurrent: Bool) -> Color {
        switch state {
        case .pending: return isCurrent ? currentQuestionAccent.opacity(0.18) : Color.white.opacity(0.05)
        case .correct: return Color.green.opacity(0.25)
        case .wrong:   return Color.red.opacity(0.25)
        }
    }

    private func circleBorder(state: QuestionState, isCurrent: Bool) -> Color {
        switch state {
        case .pending: return isCurrent ? currentQuestionAccent : .white.opacity(0.25)
        case .correct: return .green.opacity(0.7)
        case .wrong:   return .red.opacity(0.7)
        }
    }

    private func circleShadow(state: QuestionState, isCurrent: Bool) -> Color {
        switch state {
        case .pending: return isCurrent ? currentQuestionAccent.opacity(0.45) : .clear
        case .correct: return .green.opacity(0.3)
        case .wrong:   return .red.opacity(0.3)
        }
    }

    private func circleTextColor(state: QuestionState, isCurrent: Bool) -> Color {
        switch state {
        case .pending: return isCurrent ? currentQuestionAccent : .white.opacity(0.7)
        case .correct: return .green
        case .wrong:   return .red
        }
    }

    // MARK: - Toolbar

    private var toolbarRow: some View {
        HStack(spacing: 12) {
            Button {
                showResetAlert = true
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
            }

            // Pause / Resume — only visible after drill starts
            if vm.started {
                Button {
                    vm.pauseToggle()
                } label: {
                    Label(vm.paused ? "Resume" : "Pause",
                          systemImage: vm.paused ? "play.fill" : "pause.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(vm.paused ? .black : .white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            vm.paused
                            ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "4ADE80"), Color(hex: "22C55E")], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white.opacity(0.08))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )
                }
            }

            Button {
                showEndAlert = true
            } label: {
                Label("End Drill", systemImage: "stop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "4ADE80"), Color(hex: "22C55E")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color(hex: "4ADE80").opacity(0.3), radius: 8, y: 3)
            }
        }
    }

    // MARK: - Helpers

    private var minutesLabel: String {
        let s = Int(vm.secondsPerQuestion)
        if s < 60 { return "\(s)s" }
        let m = s / 60
        let r = s % 60
        return r == 0 ? "\(m)m" : "\(m)m \(r)s"
    }
}

#Preview {
    let vm = DrillTimerViewModel()
    vm.questionCount = 10
    vm.secondsPerQuestion = 120
    vm.startDrill()
    return DrillActiveView(vm: vm)
}
