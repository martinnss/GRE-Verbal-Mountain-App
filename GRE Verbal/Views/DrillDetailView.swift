import SwiftUI
import SwiftData

struct DrillDetailView: View {
    let session: DrillSession
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            Color(hex: "060D07").ignoresSafeArea()
            StarfieldBackground()

            VStack(spacing: 0) {
                // Navigation bar
                navBar
                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        summaryRow
                        questionList
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Color(hex: "4ADE80"))
            }
            Spacer()
        }
        .overlay(
            Text("Drill Detail")
                .font(.headline)
                .foregroundStyle(.white)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.3))
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Self.dateFormatter.string(from: session.date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("\(session.questionCount) questions")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(DrillTimerViewModel.format(seconds: session.totalElapsedTime))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "4ADE80"))
                    Text("total")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            HStack(spacing: 0) {
                metaStat(
                    label: "Avg/Q",
                    value: DrillTimerViewModel.format(seconds: session.avgTimePerQuestion),
                    color: Color(hex: "4ADE80")
                )
                Divider().background(.white.opacity(0.12)).frame(height: 22)
                metaStat(
                    label: "Error %",
                    value: String(format: "%.0f%%", session.errorRate * 100),
                    color: session.errorRate > 0.3 ? .orange : .mint
                )
                Divider().background(.white.opacity(0.12)).frame(height: 22)
                metaStat(
                    label: "Est/Q",
                    value: DrillTimerViewModel.format(seconds: session.estimatedTimePerQuestion),
                    color: .white.opacity(0.5)
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.4))
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        return HStack(spacing: 10) {
            summaryPill(icon: "checkmark.circle.fill", label: "Correct", count: session.displayCorrectCount, color: .green)
            summaryPill(icon: "xmark.circle.fill", label: "Wrong", count: session.displayWrongCount, color: .red)
            summaryPill(icon: "minus.circle.fill", label: "Skipped", count: session.displayUnansweredCount, color: .orange)
        }
    }

    // MARK: - Question List

    private var questionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Question Breakdown")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .kerning(0.8)

            if session.perQuestionStates.isEmpty {
                legacyListView
            } else {
                detailedListView
            }
        }
    }

    private var detailedListView: some View {
        VStack(spacing: 8) {
            ForEach(0..<session.questionCount, id: \.self) { idx in
                let stateStr = session.displayState(forQuestionAt: idx)
                let elapsed = idx < session.perQuestionElapsed.count
                    ? session.perQuestionElapsed[idx] : 0.0

                questionRow(
                    number: idx + 1,
                    stateStr: stateStr,
                    elapsed: elapsed
                )
            }
        }
    }

    private var legacyListView: some View {
        VStack(spacing: 8) {
            // Show wrong questions from old data
            if session.wrongQuestions.isEmpty {
                Text("No errors recorded.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(session.wrongQuestions.sorted(), id: \.self) { num in
                    questionRow(number: num, stateStr: "wrong", elapsed: nil)
                }
            }

            // Legacy notice
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                Text("Per-question timing not available for drills recorded before this update.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func questionRow(number: Int, stateStr: String, elapsed: Double?) -> some View {
        HStack(spacing: 14) {
            // Q number circle
            ZStack {
                Circle()
                    .fill(rowCircleColor(stateStr).opacity(0.15))
                    .overlay(Circle().strokeBorder(rowCircleColor(stateStr).opacity(0.5), lineWidth: 1.5))
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(rowCircleColor(stateStr))
            }
            .frame(width: 36, height: 36)

            // Status badge
            Label(rowLabel(stateStr), systemImage: rowIcon(stateStr))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(rowCircleColor(stateStr))

            Spacer()

            // Time
            if stateStr == "unanswered" || elapsed == nil {
                Text("—")
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            } else if let t = elapsed {
                Text(DrillTimerViewModel.format(seconds: t))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(timeColor(t))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(rowCircleColor(stateStr).opacity(0.12), lineWidth: 1))
    }

    // MARK: - Helpers

    private func rowCircleColor(_ state: String) -> Color {
        switch state {
        case "correct":    return .green
        case "wrong":      return .red
        default:           return .orange
        }
    }

    private func rowLabel(_ state: String) -> String {
        switch state {
        case "correct":    return "Correct"
        case "wrong":      return "Wrong"
        default:           return "Unanswered"
        }
    }

    private func rowIcon(_ state: String) -> String {
        switch state {
        case "correct":    return "checkmark.circle.fill"
        case "wrong":      return "xmark.circle.fill"
        default:           return "minus.circle.fill"
        }
    }

    private func timeColor(_ seconds: Double) -> Color {
        let ratio = seconds / max(1, session.estimatedTimePerQuestion)
        if ratio < 0.75 { return Color(hex: "4ADE80") }
        if ratio < 1.0  { return .mint }
        if ratio < 1.5  { return .orange }
        return .red
    }

    private func metaStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryPill(icon: String, label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.2), lineWidth: 1))
    }
}

#Preview {
    let session = DrillSession(
        questionCount: 10,
        estimatedTimePerQuestion: 120,
        totalElapsedTime: 843,
        questionTimes: [95, 130, 80, 145, 60, 200, 55, 78],
        wrongQuestions: [2, 6],
        perQuestionStates: ["correct","wrong","correct","correct","correct","wrong","correct","correct","unanswered","unanswered"],
        perQuestionElapsed: [95, 130, 80, 145, 60, 200, 55, 78, 0, 0]
    )
    return DrillDetailView(session: session)
        .modelContainer(for: [DrillSession.self], inMemory: true)
}
