import SwiftUI

struct StreakCard: View {
    var streakManager: StreakManager

    @State private var flamePulse = false

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            Divider().background(.white.opacity(0.1)).padding(.horizontal, 4)
            weekRow
        }
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.4))
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(flameColor.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: flameColor.opacity(0.12), radius: 16, y: 6)
        .onAppear { flamePulse = true }
    }

    // MARK: - Main Row

    private var mainRow: some View {
        HStack(spacing: 16) {
            // Flame icon
            ZStack {
                Circle()
                    .fill(flameColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "flame.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: flameGradient,
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .symbolEffect(.variableColor.iterative.reversing, value: flamePulse)
                    .scaleEffect(flamePulse ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: flamePulse
                    )

                // Completed badge
                if streakManager.todayCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.green)
                        .background(Circle().fill(Color(hex: "060D07")).frame(width: 18, height: 18))
                        .offset(x: 18, y: -18)
                }
            }

            // Streak count + subtitle
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streakManager.currentStreak)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(streakManager.currentStreak == 1 ? "day" : "days")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 2)
                }
                Text(motivationalSubtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(flameColor.opacity(0.9))
            }

            Spacer()

            // Best streak + status
            VStack(alignment: .trailing, spacing: 6) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(streakManager.longestStreak)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("best")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                }
                statusBadge
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Group {
            if streakManager.todayCompleted {
                Label("Done today!", systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Label("Study today", systemImage: "bell.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(flameColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(flameColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Week Row (last 7 days)

    private var weekRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let isToday = offset == 0
                let completed = offset < streakManager.last7DaysCompleted.count
                    ? streakManager.last7DaysCompleted[offset] : false
                let dayLabel = dayAbbreviation(daysAgo: offset)

                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(dotFill(completed: completed, isToday: isToday))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .strokeBorder(dotBorder(completed: completed, isToday: isToday), lineWidth: isToday ? 2 : 1)
                            )
                        if completed {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(isToday ? .white : flameColor.opacity(0.9))
                        }
                    }
                    Text(dayLabel)
                        .font(.system(size: 9, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? .white.opacity(0.9) : .white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 14)
    }

    // MARK: - Helpers

    private var flameColor: Color {
        let streak = streakManager.currentStreak
        if streak >= 30 { return Color(hex: "FF4500") }   // deep red-orange
        if streak >= 7  { return .orange }
        if streak >= 1  { return Color(hex: "FFA500") }   // amber
        return .white.opacity(0.3)
    }

    private var flameGradient: [Color] {
        let streak = streakManager.currentStreak
        if streak >= 30 { return [Color(hex: "FFD700"), Color(hex: "FF4500"), Color(hex: "8B0000")] }
        if streak >= 7  { return [Color(hex: "FFFF00"), Color(hex: "FF8C00"), Color(hex: "FF4500")] }
        if streak >= 1  { return [Color(hex: "FFE066"), Color(hex: "FFA500"), Color(hex: "FF6B00")] }
        return [.white.opacity(0.3), .white.opacity(0.15)]
    }

    private var motivationalSubtitle: String {
        if !streakManager.todayCompleted && streakManager.currentStreak == 0 {
            return "Start your streak today!"
        }
        switch streakManager.currentStreak {
        case 0:      return "Start your streak today!"
        case 1:      return "Great start!"
        case 2...6:  return "Keep it up!"
        case 7...13: return "One week strong 💪"
        case 14...29: return "You're on fire!"
        case 30...99: return "Legendary! 🔥"
        default:     return "Unstoppable! 🏆"
        }
    }

    private func dotFill(completed: Bool, isToday: Bool) -> Color {
        if completed && isToday { return flameColor.opacity(0.8) }
        if completed { return flameColor.opacity(0.25) }
        if isToday { return .white.opacity(0.08) }
        return .white.opacity(0.04)
    }

    private func dotBorder(completed: Bool, isToday: Bool) -> Color {
        if isToday { return completed ? flameColor : .white.opacity(0.3) }
        return completed ? flameColor.opacity(0.5) : .white.opacity(0.1)
    }

    private func dayAbbreviation(daysAgo: Int) -> String {
        if daysAgo == 0 { return "Today" }
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: -daysAgo, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(2))
    }
}

#Preview {
    ZStack {
        Color(hex: "060D07").ignoresSafeArea()
        VStack(spacing: 20) {
            StreakCard(streakManager: StreakManager.shared)
        }
        .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
}
