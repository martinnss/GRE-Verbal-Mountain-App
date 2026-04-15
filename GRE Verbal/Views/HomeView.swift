import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @Bindable var viewModel: FlashcardViewModel
    @State private var showingFlashcards = false
    @State private var selectedGroupRange: ClosedRange<Int> = 1...1
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated starfield background
                StarfieldBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Statistics card
                        statisticsCard
                        
                        // Practice configuration
                        practiceConfigCard
                        
                        // Start button
                        startPracticeButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("GRE Vocab")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .fullScreenCover(isPresented: $showingFlashcards) {
                FlashcardSessionView(viewModel: viewModel, isPresented: $showingFlashcards)
            }
            .onAppear {
                if let min = viewModel.selectedGroups.min(), let max = viewModel.selectedGroups.max() {
                    selectedGroupRange = min...max
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        let stats = viewModel.getOverallStatistics()
        let totalEasy = stats.easyNatural + stats.easyMastered
        let total = totalEasy + stats.medium + stats.hard + stats.unlocked
        let masteredPercent = total > 0 ? Int((Double(totalEasy) / Double(total)) * 100) : 0
        
        return VStack(spacing: 24) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                    .frame(width: 110, height: 110)
                
                Circle()
                    .trim(from: 0, to: CGFloat(masteredPercent) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(masteredPercent)%")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Mastered")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            // Stats grid - 5 items now
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    StatItem(value: stats.easyNatural, label: "Natural", color: .green)
                    StatItem(value: stats.easyMastered, label: "Mastered", color: .mint)
                    StatItem(value: stats.medium, label: "Medium", color: .orange)
                }
                HStack(spacing: 0) {
                    Spacer()
                    StatItem(value: stats.hard, label: "Hard", color: .red)
                    StatItem(value: stats.unlocked, label: "New", color: .purple)
                    Spacer()
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial.opacity(0.8))
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Practice Config Card
    
    private var practiceConfigCard: some View {
        VStack(spacing: 20) {
            // Group Selection
            VStack(alignment: .leading, spacing: 14) {
                Label("Groups", systemImage: "folder.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                
                GroupRangePicker(
                    totalGroups: viewModel.repository.totalGroups,
                    selectedRange: $selectedGroupRange,
                    onRangeChange: { range in
                        viewModel.selectedGroups = Set(range)
                    }
                )
            }
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            
            // Difficulty Selection
            VStack(alignment: .leading, spacing: 12) {
                Label("Difficulty", systemImage: "slider.horizontal.3")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                
                // Wrap layout for all difficulty options
                DifficultyFlowLayout(spacing: 8) {
                    DifficultyChip(
                        title: "New",
                        icon: "sparkles",
                        color: .purple,
                        isSelected: viewModel.selectedDifficulties.contains(.unlocked),
                        onTap: { viewModel.toggleDifficulty(.unlocked) }
                    )
                    
                    DifficultyChip(
                        title: "Natural",
                        icon: "checkmark.seal.fill",
                        color: .green,
                        isSelected: viewModel.selectedDifficulties.contains(.easyNatural),
                        onTap: { viewModel.toggleDifficulty(.easyNatural) }
                    )
                    
                    DifficultyChip(
                        title: "Mastered",
                        icon: "star.fill",
                        color: .mint,
                        isSelected: viewModel.selectedDifficulties.contains(.easyMastered),
                        onTap: { viewModel.toggleDifficulty(.easyMastered) }
                    )
                    
                    DifficultyChip(
                        title: "Medium",
                        icon: "flame.fill",
                        color: .orange,
                        isSelected: viewModel.selectedDifficulties.contains(.medium),
                        onTap: { viewModel.toggleDifficulty(.medium) }
                    )
                    
                    DifficultyChip(
                        title: "Hard",
                        icon: "bolt.fill",
                        color: .red,
                        isSelected: viewModel.selectedDifficulties.contains(.hard),
                        onTap: { viewModel.toggleDifficulty(.hard) }
                    )
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.8))
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Start Button
    
    private var startPracticeButton: some View {
        let wordCount = calculateWordCount()
        
        return Button(action: startPractice) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Practice")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if wordCount > 0 {
                        Text("\(wordCount) words")
                            .font(.caption)
                            .opacity(0.8)
                    }
                }
                
                Spacer()
                
                Image(systemName: "play.fill")
                    .font(.title2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.purple.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .blue.opacity(0.4), radius: 15, y: 8)
        }
        .disabled(viewModel.selectedGroups.isEmpty || viewModel.selectedDifficulties.isEmpty)
        .opacity(viewModel.selectedGroups.isEmpty || viewModel.selectedDifficulties.isEmpty ? 0.4 : 1)
    }
    
    private func calculateWordCount() -> Int {
        var words: [VocabWord]
        if viewModel.isCumulativeMode {
            let maxGroup = viewModel.selectedGroups.max() ?? 1
            words = viewModel.repository.wordsCumulative(upToGroup: maxGroup)
        } else {
            words = viewModel.repository.words(forGroups: Array(viewModel.selectedGroups))
        }
        return viewModel.progressManager.filterWords(words, byTiers: Array(viewModel.selectedDifficulties)).count
    }
    
    private func startPractice() {
        viewModel.buildDeck()
        showingFlashcards = true
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Difficulty Chip (Compact)

struct DifficultyChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color.white.opacity(0.05))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : color.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Difficulty Flow Layout

struct DifficultyFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(x: bounds.minX + result.positions[index].x,
                                y: bounds.minY + result.positions[index].y)
            subview.place(at: point, anchor: .topLeading, proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x - spacing)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Group Range Picker

struct GroupRangePicker: View {
    let totalGroups: Int
    @Binding var selectedRange: ClosedRange<Int>
    let onRangeChange: (ClosedRange<Int>) -> Void
    
    @State private var fromGroup: Int = 1
    @State private var toGroup: Int = 1
    
    var body: some View {
        VStack(spacing: 12) {
            // Range bar
            HStack(spacing: 1) {
                ForEach(1...totalGroups, id: \.self) { group in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isInRange(group) ? Color.cyan : Color.white.opacity(0.15))
                        .frame(height: 6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            
            // Pickers row
            HStack(spacing: 10) {
                GroupPicker(label: "From", value: $fromGroup, range: 1...totalGroups) { newValue in
                    if toGroup < newValue { toGroup = newValue }
                    updateRange()
                }
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                
                GroupPicker(label: "To", value: $toGroup, range: fromGroup...totalGroups) { _ in
                    updateRange()
                }
            }
        }
        .onAppear {
            fromGroup = selectedRange.lowerBound
            toGroup = selectedRange.upperBound
        }
    }
    
    private func isInRange(_ group: Int) -> Bool {
        group >= fromGroup && group <= toGroup
    }
    
    private func updateRange() {
        selectedRange = fromGroup...toGroup
        onRangeChange(selectedRange)
    }
}

struct GroupPicker: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            
            Menu {
                ForEach(range, id: \.self) { num in
                    Button("Group \(num)") { value = num; onChange(num) }
                }
            } label: {
                HStack {
                    Text("Group \(value)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - Session View

struct FlashcardSessionView: View {
    @Bindable var viewModel: FlashcardViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Animated starfield background
            StarfieldBackground()
            
            if viewModel.showingSessionComplete {
                SessionCompleteView(viewModel: viewModel, onDismiss: { isPresented = false })
            } else {
                FlashcardView(viewModel: viewModel)
            }
        }
        .overlay(alignment: .topLeading) {
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.leading, 20)
            .padding(.top, 60)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Session Complete

struct SessionCompleteView: View {
    @Bindable var viewModel: FlashcardViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Trophy
            Image(systemName: "trophy.fill")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .orange.opacity(0.5), radius: 20)
            
            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            // Stats
            HStack(spacing: 20) {
                ResultCard(value: viewModel.knownCount, label: "Known", color: .green)
                ResultCard(value: viewModel.unknownCount, label: "Learning", color: .red)
            }
            .padding(.horizontal, 30)
            
            Text("Duration: \(viewModel.sessionDuration)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    viewModel.showingSessionComplete = false
                    viewModel.buildDeck()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Practice Again")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Button(action: onDismiss) {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

struct ResultCard: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial.opacity(0.5))
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

#Preview {
    let repo = VocabRepository()
    let progress = ProgressManager()
    let viewModel = FlashcardViewModel(repository: repo, progressManager: progress)
    return HomeView(viewModel: viewModel)
}
