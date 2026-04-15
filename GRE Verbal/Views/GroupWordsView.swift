import SwiftUI

// MARK: - Group Words View

struct GroupWordsView: View {
    let groupNumber: Int
    @Bindable var viewModel: FlashcardViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var words: [VocabWord] {
        viewModel.repository.words(forGroups: [groupNumber])
    }
    
    var body: some View {
        ZStack {
            // Animated starfield background
            StarfieldBackground()
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(words, id: \.word) { word in
                        WordCard(
                            word: word,
                            tier: viewModel.progressManager.getDifficultyTier(for: word.word)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Group \(groupNumber)")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.clear, for: .navigationBar)
    }
}

// MARK: - Word Card

struct WordCard: View {
    let word: VocabWord
    let tier: DifficultyTier
    @State private var isFlipped = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }) {
            ZStack {
                // Front - Word only
                frontCard
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                
                // Back - Definition
                backCard
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .buttonStyle(.plain)
    }
    
    private var frontCard: some View {
        VStack(spacing: 10) {
            // Tier indicator at top
            HStack {
                tierBadge
                Spacer()
            }
            
            Spacer()
            
            // Word centered
            Text(word.word)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(.ultraThinMaterial.opacity(0.7))
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tierColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var backCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with word
            HStack {
                Text(word.word)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                tierBadge
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // First definition only (to fit in square)
            if let definition = word.definitions.first {
                Text(definition.partOfSpeech)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Capsule())
                
                Text(definition.definition)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tierColor.opacity(0.4), lineWidth: 1)
        )
    }
    
    private var tierBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: tierIcon)
                .font(.system(size: 8, weight: .bold))
            
            Text(tierLabel)
                .font(.system(size: 8, weight: .semibold))
        }
        .foregroundStyle(tierColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(tierColor.opacity(0.15))
        .clipShape(Capsule())
    }
    
    private var tierColor: Color {
        switch tier {
        case .unlocked: return .purple
        case .easyNatural: return .green
        case .easyMastered: return .mint
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
    private var tierIcon: String {
        switch tier {
        case .unlocked: return "sparkles"
        case .easyNatural: return "checkmark.seal.fill"
        case .easyMastered: return "star.fill"
        case .medium: return "flame.fill"
        case .hard: return "bolt.fill"
        }
    }
    
    private var tierLabel: String {
        switch tier {
        case .unlocked: return "New"
        case .easyNatural: return "Natural"
        case .easyMastered: return "Mastered"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

// MARK: - Definition Item View

struct DefinitionItemView: View {
    let index: Int
    let definition: Definition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
            definitionText
            exampleText
        }
    }
    
    private var headerRow: some View {
        HStack(spacing: 6) {
            Text("\(index + 1).")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            
            Text(definition.partOfSpeech)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.cyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.cyan.opacity(0.15))
                .clipShape(Capsule())
        }
    }
    
    private var definitionText: some View {
        Text(definition.definition)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private var exampleText: some View {
        if definition.hasSentence {
            Text("\"\(definition.sentence)\"")
                .font(.caption)
                .italic()
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        let repo = VocabRepository()
        let progress = ProgressManager()
        let viewModel = FlashcardViewModel(repository: repo, progressManager: progress)
        GroupWordsView(groupNumber: 1, viewModel: viewModel)
    }
}
