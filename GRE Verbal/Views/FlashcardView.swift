import SwiftUI

// MARK: - Flashcard View

struct FlashcardView: View {
    @Bindable var viewModel: FlashcardViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Spacer()
            
            // Card area
            if let word = viewModel.currentWord {
                cardArea(word: word)
            } else {
                emptyState
            }
            
            Spacer()
            
            // Actions
            actionBar
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.playCurrentWordAudio()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 14) {
            HStack {
                Text("\(viewModel.currentIndex + 1) of \(viewModel.currentDeck.count)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("\(viewModel.knownCount)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("\(viewModel.unknownCount)")
                            .fontWeight(.semibold)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 24)
            .padding(.top, 70)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4ADE80"), Color(hex: "22C55E")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * viewModel.progress, height: 4)
                        .animation(.easeOut(duration: 0.3), value: viewModel.progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Card Area
    
    private func cardArea(word: VocabWord) -> some View {
        ZStack {
            // Swipe indicators
            HStack {
                SwipeIndicator(icon: "xmark", color: .red, isActive: viewModel.cardOffset.width < -40)
                Spacer()
                SwipeIndicator(icon: "checkmark", color: .green, isActive: viewModel.cardOffset.width > 40)
            }
            .padding(.horizontal, 16)
            .animation(.easeOut(duration: 0.15), value: viewModel.cardOffset)
            
            // Card
            CardView(
                word: word,
                isFlipped: viewModel.isCardFlipped,
                tier: viewModel.progressManager.getDifficultyTier(for: word.word),
                onTap: { viewModel.flipCard() },
                onAudio: { viewModel.playCurrentWordAudio() },
                isPlaying: viewModel.audioManager.isPlaying,
                isLoading: viewModel.audioManager.isLoading
            )
            .offset(viewModel.cardOffset)
            .rotationEffect(.degrees(viewModel.cardRotation))
            .gesture(
                DragGesture()
                    .onChanged { viewModel.handleDragChange($0) }
                    .onEnded { viewModel.handleDragEnd($0) }
            )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        VStack(spacing: 16) {
            // Hints
            HStack(spacing: 40) {
                HintLabel(icon: "arrow.left", text: "Don't know")
                HintLabel(icon: "hand.tap", text: "Flip card")
                HintLabel(icon: "arrow.right", text: "Know it")
            }
            
            // Buttons
            HStack(spacing: 20) {
                ActionButton(icon: "xmark", color: .red) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.cardOffset = CGSize(width: -500, height: 0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewModel.markCurrentAsUnknown()
                    }
                }
                
                // Audio
                Button(action: { viewModel.playCurrentWordAudio() }) {
                    Image(systemName: viewModel.audioManager.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "4ADE80"))
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                ActionButton(icon: "checkmark", color: .green) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.cardOffset = CGSize(width: 500, height: 0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewModel.markCurrentAsKnown()
                    }
                }
            }
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No cards available")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.6))
            
            Text("Adjust your filters")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: - Swipe Indicator

struct SwipeIndicator: View {
    let icon: String
    let color: Color
    let isActive: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(isActive ? 0.25 : 0.1))
                .frame(width: 56, height: 56)
            
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
        }
        .opacity(isActive ? 1 : 0.4)
        .scaleEffect(isActive ? 1.1 : 1)
    }
}

// MARK: - Hint Label

struct HintLabel: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(.white.opacity(0.4))
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(color)
                .clipShape(Circle())
                .shadow(color: color.opacity(0.5), radius: 12, y: 6)
        }
    }
}

// MARK: - Card View

struct CardView: View {
    let word: VocabWord
    let isFlipped: Bool
    let tier: DifficultyTier
    let onTap: () -> Void
    let onAudio: () -> Void
    let isPlaying: Bool
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            if isFlipped {
                backSide
            } else {
                frontSide
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 460)
        .background(.ultraThinMaterial.opacity(0.7))
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onTapGesture(perform: onTap)
    }
    
    // MARK: - Front
    
    private var frontSide: some View {
        VStack(spacing: 20) {
            // Badge
            HStack {
                Spacer()
                tierBadge
            }
            
            Spacer()
            
            // Word
            Text(word.word)
                .font(.system(size: 38, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            // Audio
            Button(action: onAudio) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    }
                    Text("Listen")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color(hex: "4ADE80"))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color(hex: "4ADE80").opacity(0.15))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Hint
            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                Text("Tap to reveal")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.35))
        }
        .padding(24)
    }
    
    // MARK: - Back
    
    private var backSide: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.word)
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        
                        Text(word.group)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Button(action: onAudio) {
                        Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(Color(hex: "4ADE80"))
                            .frame(width: 42, height: 42)
                            .background(Color(hex: "4ADE80").opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                
                Divider().background(Color.white.opacity(0.15))
                
                // Definitions
                ForEach(Array(word.definitions.enumerated()), id: \.offset) { i, def in
                    DefinitionCard(definition: def, index: i + 1)
                    
                    if i < word.definitions.count - 1 {
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Tier Badge
    
    private var tierBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: tier.icon)
                .font(.caption2)
            Text(tier.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(tierColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tierColor.opacity(0.2))
        .clipShape(Capsule())
    }
    
    private var tierColor: Color {
        switch tier {
        case .unlocked: return Color(hex: "C4935A")
        case .easyNatural: return .green
        case .easyMastered: return .mint
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

// MARK: - Definition Card

struct DefinitionCard: View {
    let definition: Definition
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // POS
            HStack(spacing: 8) {
                Text("\(index).")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                
                Text(definition.partOfSpeech)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "22C55E"))
                    .clipShape(Capsule())
            }
            
            // Definition
            Text(definition.definition)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            
            // Example
            if definition.hasSentence {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Example")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text("\"\(definition.sentence)\"")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Synonyms
            if !definition.synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Synonyms")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    FlowLayout(spacing: 6) {
                        ForEach(definition.synonyms, id: \.self) { syn in
                            Text(syn)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color(hex: "4ADE80"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "4ADE80").opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (i, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[i].x, y: bounds.minY + result.positions[i].y), proposal: .unspecified)
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
                self.size.width = max(self.size.width, x)
            }
            self.size.height = y + rowHeight
        }
    }
}

#Preview {
    let repo = VocabRepository()
    let progress = ProgressManager()
    let viewModel = FlashcardViewModel(repository: repo, progressManager: progress)
    viewModel.buildDeck()
    
    return ZStack {
        Color(hex: "060D07").ignoresSafeArea()
        FlashcardView(viewModel: viewModel)
    }
    .preferredColorScheme(.dark)
}
