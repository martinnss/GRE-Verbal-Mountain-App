import SwiftUI
import SwiftData

struct DrillSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm = DrillTimerViewModel()
    @Query(sort: \DrillSession.date, order: .reverse) private var history: [DrillSession]

    var body: some View {
        ZStack {
            Color(hex: "0D0D1A").ignoresSafeArea()
            StarfieldBackground()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    setupCard
                    if !history.isEmpty {
                        historySection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { vm.phase == .active },
            set: { if !$0 { vm.resetDrill() } }
        )) {
            DrillActiveView(vm: vm)
        }
        .onAppear {
            vm.configure(modelContext: modelContext)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("Quant Timer")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Track your time per question")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Setup Card

    private var setupCard: some View {
        VStack(spacing: 20) {
            // Question count
            VStack(alignment: .leading, spacing: 8) {
                Label("Number of questions", systemImage: "number")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)

                HStack {
                    Button { if vm.questionCount > 1 { vm.questionCount -= 1 } } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                    Spacer()
                    Text("\(vm.questionCount)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .frame(minWidth: 60)
                    Spacer()
                    Button { vm.questionCount += 1 } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                }
            }

            Divider().background(.white.opacity(0.15))

            // Time per question
            VStack(alignment: .leading, spacing: 8) {
                Label("Time per question", systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)

                HStack {
                    Button {
                        if vm.secondsPerQuestion > 10 { vm.secondsPerQuestion -= 10 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                    Spacer()
                    Text(minutesLabel)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .frame(minWidth: 80)
                    Spacer()
                    Button { vm.secondsPerQuestion += 10 } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                }
            }

            Divider().background(.white.opacity(0.15))

            // Summary
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow.opacity(0.8))
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Start button
            Button {
                vm.startDrill()
            } label: {
                Label("Start Drill", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.cyan, Color(hex: "00BFFF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .cyan.opacity(0.4), radius: 10, y: 4)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.4))
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Drills")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))

            ForEach(history) { session in
                DrillHistoryRow(session: session)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: - Helpers

    private var minutesLabel: String {
        let s = Int(vm.secondsPerQuestion)
        if s < 60 { return "\(s)s" }
        let m = s / 60; let r = s % 60
        return r == 0 ? "\(m)m" : "\(m)m \(r)s"
    }

    private var summaryText: String {
        let totalSec = vm.secondsPerQuestion * Double(vm.questionCount)
        let totalMin = totalSec / 60
        let totalStr = totalMin == totalMin.rounded() ? "\(Int(totalMin))" : String(format: "%.1f", totalMin)
        return "\(vm.questionCount) questions × \(minutesLabel) = \(totalStr) min set"
    }
}

// MARK: - History Row

struct DrillHistoryRow: View {
    let session: DrillSession

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(Self.dateFormatter.string(from: session.date))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(session.questionCount) Qs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
            }

            HStack(spacing: 0) {
                statCell(
                    label: "Total",
                    value: DrillTimerViewModel.format(seconds: session.totalElapsedTime),
                    color: .white
                )
                Divider().background(.white.opacity(0.15)).frame(height: 30)
                statCell(
                    label: "Avg/Q",
                    value: DrillTimerViewModel.format(seconds: session.avgTimePerQuestion),
                    color: .cyan
                )
                Divider().background(.white.opacity(0.15)).frame(height: 30)
                statCell(
                    label: "Errors",
                    value: "\(session.wrongQuestions.count)",
                    color: session.wrongQuestions.isEmpty ? .green : .red
                )
                Divider().background(.white.opacity(0.15)).frame(height: 30)
                statCell(
                    label: "Error %",
                    value: String(format: "%.0f%%", session.errorRate * 100),
                    color: session.errorRate > 0.3 ? .orange : .mint
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DrillSetupView()
        .modelContainer(for: [DrillSession.self], inMemory: true)
}
