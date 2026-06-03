import SwiftUI
import WebKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Tab root — the "Home" screen
// ─────────────────────────────────────────────────────────────────────────────

struct QuantMountainView: View {
    @State private var vm  = QuantMountainViewModel()
    @State private var showSession = false

    var body: some View {
        NavigationStack {
            ZStack {
                StarfieldBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        configCard
                        startButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Quant Mountain")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .fullScreenCover(isPresented: $showSession) {
                QuantSessionView(cards: vm.cardsForSelection, isPresented: $showSession)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Config card

    private var configCard: some View {
        VStack(spacing: 20) {

            // ── Subject picker ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 14) {
                Label("Subject", systemImage: "books.vertical.fill")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))

                // Abbreviated category chips
                DifficultyFlowLayout(spacing: 8) {
                    ForEach(vm.categories, id: \.self) { cat in
                        let isSelected = vm.selectedCategory == cat
                        Button { vm.selectCategory(cat) } label: {
                            Text(abbreviate(cat))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : Color(hex: "4ADE80"))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(isSelected ? Color(hex: "4ADE80") : Color.white.opacity(0.05))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(
                                    isSelected ? Color.clear : Color(hex: "4ADE80").opacity(0.4),
                                    lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .animation(.easeOut(duration: 0.15), value: isSelected)
                    }
                }
            }

            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)

            // ── Mountain range picker ─────────────────────────────────────
            VStack(alignment: .leading, spacing: 14) {
                Label("Mountain", systemImage: "mountain.2.fill")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))

                QuantMountainRangePicker(
                    total: vm.mountainCountForCategory,
                    selectedRange: $vm.selectedMountainRange
                )
            }
        }
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.8))
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: Start button

    private var startButton: some View {
        let count = vm.cardsForSelection.count

        return Button { showSession = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Practice")
                        .font(.headline).fontWeight(.bold)
                    if count > 0 {
                        Text("\(count) cards")
                            .font(.caption).opacity(0.8)
                    }
                }
                Spacer()
                Image(systemName: "play.fill").font(.title2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24).padding(.vertical, 18)
            .background(LinearGradient(
                colors: [Color(hex: "22C55E"), Color(hex: "8B5E3C")],
                startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color(hex: "4ADE80").opacity(0.35), radius: 15, y: 8)
        }
        .disabled(count == 0)
        .opacity(count == 0 ? 0.4 : 1)
    }

    private func abbreviate(_ cat: String) -> String {
        switch cat {
        case "Coordinate Geometry": return "Coord. Geo."
        case "Data Analysis":       return "Data"
        default:                    return cat
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Mountain Range Picker  (mirrors GroupRangePicker)
// ─────────────────────────────────────────────────────────────────────────────

struct QuantMountainRangePicker: View {
    let total: Int
    @Binding var selectedRange: ClosedRange<Int>

    @State private var fromN: Int = 1
    @State private var toN:   Int = 1

    var body: some View {
        VStack(spacing: 12) {
            // Range bar
            HStack(spacing: 1) {
                ForEach(1...max(1, total), id: \.self) { n in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(n >= fromN && n <= toN
                              ? Color(hex: "4ADE80")
                              : Color.white.opacity(0.15))
                        .frame(height: 6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))

            // From / To menus
            HStack(spacing: 10) {
                mountainMenu(label: "From", value: $fromN,
                             range: 1...max(1, total)) { _ in
                    if toN < fromN { toN = fromN }
                    commit()
                }

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))

                mountainMenu(label: "To", value: $toN,
                             range: max(1, fromN)...max(1, total)) { _ in
                    commit()
                }
            }
        }
        .onAppear {
            fromN = selectedRange.lowerBound
            toN   = selectedRange.upperBound
        }
        .onChange(of: total) { _, newTotal in
            // Clamp when category changes
            fromN = min(fromN, max(1, newTotal))
            toN   = min(toN,   max(1, newTotal))
            commit()
        }
    }

    private func commit() {
        selectedRange = fromN...max(fromN, toN)
    }

    @ViewBuilder
    private func mountainMenu(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2).foregroundStyle(.white.opacity(0.5))

            Menu {
                ForEach(range, id: \.self) { n in
                    Button("Mountain \(n)") { value.wrappedValue = n; onChange(n) }
                }
            } label: {
                HStack {
                    Text("Mountain \(value.wrappedValue)")
                        .font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2).foregroundStyle(.white.opacity(0.4))
                }
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Session container  (mirrors FlashcardSessionView)
// ─────────────────────────────────────────────────────────────────────────────

struct QuantSessionView: View {
    let cards: [QuantCard]
    @Binding var isPresented: Bool
    @State private var showComplete = false
    @State private var knownCount   = 0
    @State private var unknownCount = 0

    var body: some View {
        ZStack {
            StarfieldBackground()

            if showComplete {
                QuantSessionCompleteView(
                    known:   knownCount,
                    unknown: unknownCount,
                    onAgain: { showComplete = false; knownCount = 0; unknownCount = 0 },
                    onDone:  { isPresented = false }
                )
            } else {
                QuantFlashcardView(
                    cards:         cards,
                    onKnown:       { knownCount += 1 },
                    onUnknown:     { unknownCount += 1 },
                    onFinished:    { showComplete = true },
                    knownCount:    knownCount,
                    unknownCount:  unknownCount
                )
            }
        }
        .overlay(alignment: .topLeading) {
            Button { isPresented = false } label: {
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Flashcard swipe view  (mirrors FlashcardView)
// ─────────────────────────────────────────────────────────────────────────────

struct QuantFlashcardView: View {
    let cards: [QuantCard]
    let onKnown:    () -> Void
    let onUnknown:  () -> Void
    let onFinished: () -> Void
    let knownCount:   Int
    let unknownCount: Int

    @State private var currentIndex: Int    = 0
    @State private var cardOffset: CGSize   = .zero
    @State private var cardRotation: Double = 0
    @State private var isFlipped: Bool      = false

    private var progress: Double {
        cards.isEmpty ? 0 : Double(currentIndex) / Double(cards.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Spacer()
            cardArea
            Spacer()
            actionBar
        }
    }

    // MARK: Header

    private var headerView: some View {
        VStack(spacing: 14) {
            HStack {
                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("\(knownCount)").fontWeight(.semibold)
                    }
                    HStack(spacing: 5) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("\(unknownCount)").fontWeight(.semibold)
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
                        .fill(LinearGradient(
                            colors: [Color(hex: "4ADE80"), Color(hex: "22C55E")],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.easeOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 24)
        }
    }

    // MARK: Card area

    private var cardArea: some View {
        ZStack {
            HStack {
                SwipeIndicator(icon: "xmark",     color: .red,   isActive: cardOffset.width < -40)
                Spacer()
                SwipeIndicator(icon: "checkmark", color: .green, isActive: cardOffset.width >  40)
            }
            .padding(.horizontal, 16)
            .animation(.easeOut(duration: 0.15), value: cardOffset)

            if currentIndex < cards.count {
                QuantSwipeCard(
                    card:      cards[currentIndex],
                    isFlipped: isFlipped,
                    onFlip:    { isFlipped.toggle() }
                )
                .offset(cardOffset)
                .rotationEffect(.degrees(cardRotation))
                .gesture(
                    DragGesture()
                        .onChanged { drag in
                            cardOffset   = drag.translation
                            cardRotation = Double(drag.translation.width / 20)
                        }
                        .onEnded { drag in
                            if drag.translation.width > 100 {
                                swipe(direction: .right)
                            } else if drag.translation.width < -100 {
                                swipe(direction: .left)
                            } else {
                                withAnimation(.spring(response: 0.4)) {
                                    cardOffset   = .zero
                                    cardRotation = 0
                                }
                            }
                        }
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Action bar

    private var actionBar: some View {
        VStack(spacing: 16) {
            HStack(spacing: 40) {
                HintLabel(icon: "arrow.left",  text: "Skip")
                HintLabel(icon: "hand.tap",    text: "Flip card")
                HintLabel(icon: "arrow.right", text: "Got it")
            }
            HStack(spacing: 20) {
                ActionButton(icon: "xmark",     color: .red)   { swipe(direction: .left)  }
                Spacer().frame(width: 50)   // placeholder where audio button was
                ActionButton(icon: "checkmark", color: .green) { swipe(direction: .right) }
            }
        }
        .padding(.bottom, 30)
    }

    // MARK: Swipe logic

    private enum SwipeDirection { case left, right }

    private func swipe(direction: SwipeDirection) {
        let targetX: CGFloat = direction == .right ? 500 : -500
        withAnimation(.spring(response: 0.3)) {
            cardOffset   = CGSize(width: targetX, height: 0)
            cardRotation = direction == .right ? 15 : -15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            direction == .right ? onKnown() : onUnknown()
            advance()
        }
    }

    private func advance() {
        let next = currentIndex + 1
        if next >= cards.count {
            onFinished()
        } else {
            // Reset card state before showing next
            cardOffset   = .zero
            cardRotation = 0
            isFlipped    = false
            withAnimation(.none) { currentIndex = next }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - The swipe card  (mirrors CardView)
// ─────────────────────────────────────────────────────────────────────────────

private struct QuantSwipeCard: View {
    let card:     QuantCard
    let isFlipped: Bool
    let onFlip:   () -> Void

    var body: some View {
        ZStack {
            if isFlipped { backFace } else { frontFace }
        }
        .frame(maxWidth: .infinity, maxHeight: 480)
        .background(.ultraThinMaterial.opacity(0.7))
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28)
            .stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onTapGesture(perform: onFlip)
    }

    // MARK: Front — title only

    private var frontFace: some View {
        VStack(spacing: 20) {
            Spacer()

            // Mountain group badge
            Text(card.mountain_group.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "4ADE80"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "4ADE80").opacity(0.15))
                .clipShape(Capsule())

            // Title
            Text(card.title)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            // Flip hint
            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                Text("Tap to reveal")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.35))
            .padding(.bottom, 24)
        }
    }

    // MARK: Back — KaTeX WebView inside a scroll

    private var backFace: some View {
        VStack(spacing: 0) {
            // Mini header inside the card
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.mountain_group.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Color(hex: "4ADE80"))
                    Text(card.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.white.opacity(0.25))
                    .font(.title3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.12))

            // Content — scrollable within the card
            QuantCardContentWebView(segments: card.segments)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - KaTeX WebView — scrollable inside the card
// ─────────────────────────────────────────────────────────────────────────────

struct QuantCardContentWebView: UIViewRepresentable {
    let segments: [QuantSegment]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let wk  = WKWebView(frame: .zero, configuration: cfg)
        wk.isOpaque = false
        wk.backgroundColor  = .clear
        wk.scrollView.backgroundColor = .clear
        wk.scrollView.showsVerticalScrollIndicator = true
        wk.scrollView.bounces = true
        wk.scrollView.alwaysBounceVertical = true
        wk.navigationDelegate = context.coordinator
        wk.loadHTMLString(buildHTML(), baseURL: nil)
        return wk
    }

    func updateUIView(_ wk: WKWebView, context: Context) {
        let fp = segments.map { $0.type.rawValue + $0.content.prefix(20) }.joined()
        guard wk.customUserAgent != fp else { return }
        wk.customUserAgent = fp
        wk.loadHTMLString(buildHTML(), baseURL: nil)
    }

    // MARK: HTML builder

    private func buildHTML() -> String {
        var body = ""
        for seg in segments {
            switch seg.type {
            case .text:
                let isBullet1 = seg.content.hasPrefix("•")
                let isBullet2 = seg.content.hasPrefix("  ◦") || seg.content.hasPrefix("  ▸")
                let cls = isBullet1 ? "b1" : isBullet2 ? "b2" : "txt"
                let txt = seg.content.trimmingCharacters(in: .whitespaces).htmlEscaped
                body += "<p class=\"\(cls)\">\(txt)</p>\n"
            case .math:
                body += "<div class=\"math\">$$\(seg.content.htmlEscaped)$$</div>\n"
            case .image:
                body += "<img src=\"\(seg.content.htmlEscaped)\" class=\"img\" />\n"
            case .svg:
                body += "<div class=\"svg\">\(seg.content)</div>\n"
            case .divider:
                body += "<hr />\n"
            }
        }

        return """
        <!DOCTYPE html><html>
        <head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"
          onload="renderMathInElement(document.body,{delimiters:[{left:'$$',right:'$$',display:true},{left:'$',right:'$',display:false}],throwOnError:false});"></script>
        <style>
          *{box-sizing:border-box;margin:0;padding:0;}
          body{background:transparent;color:rgba(255,255,255,.88);font-family:-apple-system,'SF Pro Text',sans-serif;font-size:15px;line-height:1.6;padding:12px 16px 20px;}
          .txt{margin-bottom:10px;}
          .b1{color:#4ADE80;font-weight:600;font-size:14px;margin-top:8px;margin-bottom:3px;}
          .b2{padding-left:14px;color:rgba(255,255,255,.65);font-size:14px;margin-bottom:3px;}
          .math{background:rgba(74,222,128,.07);border:1px solid rgba(74,222,128,.22);border-radius:8px;padding:8px 12px;margin-bottom:8px;text-align:center;overflow-x:auto;}
          .math .katex{color:#4ADE80;}
          .math .katex-display{margin:0;}
          .img{max-width:100%;height:auto;border-radius:6px;display:block;margin:0 auto 12px;}
          .svg{background:#fff;border-radius:8px;padding:8px;margin-bottom:12px;display:flex;justify-content:center;}
          .svg svg{max-width:100%;height:auto;}
          hr{border:none;border-top:1px solid rgba(255,255,255,.1);margin:12px 0;}
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate {}
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Session complete  (mirrors SessionCompleteView)
// ─────────────────────────────────────────────────────────────────────────────

private struct QuantSessionCompleteView: View {
    let known:   Int
    let unknown: Int
    let onAgain: () -> Void
    let onDone:  () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 70))
                .foregroundStyle(LinearGradient(
                    colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                .shadow(color: .orange.opacity(0.5), radius: 20)

            Text("Session Complete!")
                .font(.title).fontWeight(.bold).foregroundStyle(.white)

            HStack(spacing: 20) {
                ResultCard(value: known,   label: "Got it",   color: .green)
                ResultCard(value: unknown, label: "Skipped",  color: .red)
            }
            .padding(.horizontal, 30)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onAgain) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Practice Again")
                    }
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(LinearGradient(
                        colors: [Color(hex: "22C55E"), Color(hex: "8B5E3C")],
                        startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: onDone) {
                    Text("Done")
                        .font(.headline).foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - String helper
// ─────────────────────────────────────────────────────────────────────────────

private extension String {
    var htmlEscaped: String {
        replacingOccurrences(of: "&",  with: "&amp;")
        .replacingOccurrences(of: "<",  with: "&lt;")
        .replacingOccurrences(of: ">",  with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'",  with: "&#39;")
    }
}

#Preview {
    QuantMountainView()
}
