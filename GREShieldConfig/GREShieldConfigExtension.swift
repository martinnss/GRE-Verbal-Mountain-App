import ManagedSettings
import ManagedSettingsUI
import UIKit

// All methods are nonisolated to avoid Swift 6 @MainActor isolation issues —
// ShieldConfigurationDataSource calls these from a non-main context.
final class GREShieldConfig: ShieldConfigurationDataSource {

    nonisolated override init() { super.init() }

    // MARK: - Shield entry points

    nonisolated override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeShield(appName: application.localizedDisplayName ?? "This app")
    }

    nonisolated override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeShield(appName: webDomain.domain ?? "This site")
    }

    // MARK: - Shield assembly

    nonisolated private func makeShield(appName: String) -> ShieldConfiguration {
        let word  = pickWord()
        let icon  = renderEntry(word, appName: appName)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: Palette.bg.withAlphaComponent(0.93),
            icon: icon,
            title: nil,
            subtitle: ShieldConfiguration.Label(
                text: "One verbal drill unlocks 15 minutes.",
                color: Palette.muted
            ),
            // Button B — tonal: translucent green fill + green text (native buttons
            // can't carry a border, so the tint stands in for the outline).
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Unlock with one drill",
                color: Palette.green
            ),
            primaryButtonBackgroundColor: Palette.green.withAlphaComponent(0.16),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Not now",
                color: Palette.muted
            )
        )
    }

    // MARK: - Word selection

    // Mirror of the main app's ShieldWord. JSON keys are the wire contract —
    // keep in sync with ScreenTimeManager.ShieldWord.
    private struct ShieldWord: Codable {
        let word: String
        let pos: String
        let def: String
        let sentence: String

        static let fallback = ShieldWord(
            word: "perfunctory",
            pos: "adjective",
            def: "carried out with a minimum of effort or thought.",
            sentence: "A perfunctory glance at the screen told him nothing."
        )
    }

    nonisolated private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.molivares.GRE-Verbal")
    }

    /// Struggling words first (the main app writes them hardest-first); a random
    /// pick among them gives variety. Falls back to the random sample, then a
    /// built-in word so the shield is never blank.
    nonisolated private func pickWord() -> ShieldWord {
        if let hard = decode(key: "shieldHardWords"), let pick = hard.randomElement() {
            return pick
        }
        if let all = decode(key: "shieldAllWords"), let pick = all.randomElement() {
            return pick
        }
        return .fallback
    }

    nonisolated private func decode(key: String) -> [ShieldWord]? {
        guard let data = sharedDefaults?.data(forKey: key),
              let words = try? JSONDecoder().decode([ShieldWord].self, from: data),
              !words.isEmpty else { return nil }
        return words
    }

    // MARK: - Palette

    private enum Palette {
        static let green   = UIColor(red: 0.290, green: 0.867, blue: 0.502, alpha: 1)   // #4ADE80
        static let greenDim = UIColor(red: 0.169, green: 0.659, blue: 0.357, alpha: 1)  // #2BA85B
        static let bg      = UIColor(red: 0.024, green: 0.051, blue: 0.027, alpha: 1)   // #060D07
        static let ink     = UIColor(red: 0.855, green: 0.910, blue: 0.871, alpha: 1)   // #DAE8DE
        static let white   = UIColor(red: 0.980, green: 1.000, blue: 0.984, alpha: 1)
        static let muted   = UIColor(red: 0.494, green: 0.596, blue: 0.522, alpha: 1)   // #7E9885
        static let faint   = UIColor(red: 0.337, green: 0.439, blue: 0.365, alpha: 1)   // #56705D
        static let hair    = UIColor(white: 0.92, alpha: 0.10)
    }

    // MARK: - Fonts

    nonisolated private func serif(_ size: CGFloat, weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
        var desc = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        if let d = desc.withDesign(.serif) { desc = d }
        if italic {
            let traits = desc.symbolicTraits.union(.traitItalic)
            if let d = desc.withSymbolicTraits(traits) { desc = d }
        }
        return UIFont(descriptor: desc, size: size)
    }

    nonisolated private func sans(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }

    // MARK: - Rendering

    /// Draw the whole editorial entry into one image — the shield's only custom
    /// surface. Native title/subtitle are centered system text, so all the
    /// left-aligned dictionary styling has to live here.
    nonisolated private func renderEntry(_ entry: ShieldWord, appName: String) -> UIImage {
        let width: CGFloat   = 340
        let pad: CGFloat     = 26
        let contentW         = width - pad * 2

        // Headword auto-shrinks so long GRE words still fit one line.
        let wordFont = fittedSerif(entry.word.lowercased(), max: 42, min: 24, width: contentW, weight: .semibold)

        // Build the attributed blocks once (used for both measuring and drawing).
        let posAttr = NSAttributedString(string: entry.pos, attributes: [
            .font: serif(13, weight: .medium, italic: true),
            .foregroundColor: Palette.green
        ])

        let defPara = NSMutableParagraphStyle(); defPara.lineSpacing = 3
        let defAttr = NSMutableAttributedString()
        defAttr.append(NSAttributedString(string: "1   ", attributes: [
            .font: sans(13, weight: .bold), .foregroundColor: Palette.green
        ]))
        defAttr.append(NSAttributedString(string: entry.def, attributes: [
            .font: serif(18), .foregroundColor: Palette.ink, .paragraphStyle: defPara
        ]))

        let asInAttr = NSAttributedString(string: "AS IN", attributes: [
            .font: sans(10, weight: .bold),
            .foregroundColor: Palette.faint,
            .kern: 1.4
        ])

        let sentPara = NSMutableParagraphStyle(); sentPara.lineSpacing = 2
        let sentAttr = NSMutableAttributedString(string: entry.sentence, attributes: [
            .font: serif(15, italic: true),
            .foregroundColor: Palette.muted,
            .paragraphStyle: sentPara
        ])
        if let r = entry.sentence.range(of: entry.word, options: .caseInsensitive) {
            sentAttr.addAttributes([
                .font: serif(15, weight: .semibold, italic: true),
                .foregroundColor: Palette.ink
            ], range: NSRange(r, in: entry.sentence))
        }

        // Vertical layout math.
        let defH  = measure(defAttr, contentW)
        let sentH = measure(sentAttr, contentW)

        var y: CGFloat = pad
        let headerH: CGFloat = 16
        y += headerH + 30                         // header, then breathing room
        let posY = y;   y += ceil(serif(13).lineHeight) + 8
        let wordY = y;  y += ceil(wordFont.lineHeight) + 18
        let ruleY = y;  y += 1 + 18
        let defY = y;   y += defH + 18
        let asInY = y;  y += 14 + 6
        let sentY = y;  y += sentH
        let totalH = y + pad

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalH), format: format)

        return renderer.image { _ in
            // Header: wordmark left, "{App} paused" right with a green dot.
            let markY = pad
            let mark = NSMutableAttributedString()
            mark.append(NSAttributedString(string: "GRE", attributes: [
                .font: sans(12, weight: .bold), .foregroundColor: Palette.greenDim, .kern: 1.6
            ]))
            mark.append(NSAttributedString(string: " VERBAL", attributes: [
                .font: sans(12, weight: .bold), .foregroundColor: Palette.faint, .kern: 1.6
            ]))
            mark.draw(at: CGPoint(x: pad, y: markY))

            let pausedText = NSAttributedString(string: shorten(appName) + " paused", attributes: [
                .font: sans(12, weight: .regular), .foregroundColor: Palette.muted
            ])
            let pw = pausedText.size().width
            let dotR: CGFloat = 5
            let dotX = width - pad - pw - dotR - 7
            let dotPath = UIBezierPath(ovalIn: CGRect(x: dotX, y: markY + 4, width: dotR, height: dotR))
            Palette.green.setFill(); dotPath.fill()
            pausedText.draw(at: CGPoint(x: width - pad - pw, y: markY))

            // Entry
            posAttr.draw(at: CGPoint(x: pad, y: posY))

            NSAttributedString(string: entry.word.lowercased(), attributes: [
                .font: wordFont, .foregroundColor: Palette.white
            ]).draw(at: CGPoint(x: pad, y: wordY))

            let rule = UIBezierPath(rect: CGRect(x: pad, y: ruleY, width: contentW, height: 1))
            Palette.hair.setFill(); rule.fill()

            defAttr.draw(with: CGRect(x: pad, y: defY, width: contentW, height: defH),
                         options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

            asInAttr.draw(at: CGPoint(x: pad, y: asInY))

            sentAttr.draw(with: CGRect(x: pad, y: sentY, width: contentW, height: sentH),
                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
    }

    nonisolated private func measure(_ a: NSAttributedString, _ w: CGFloat) -> CGFloat {
        ceil(a.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            context: nil).height)
    }

    nonisolated private func fittedSerif(_ text: String, max: CGFloat, min: CGFloat,
                                         width: CGFloat, weight: UIFont.Weight) -> UIFont {
        var size = max
        while size > min {
            let f = serif(size, weight: weight)
            let w = (text as NSString).size(withAttributes: [.font: f]).width
            if w <= width { break }
            size -= 1
        }
        return serif(size, weight: weight)
    }

    nonisolated private func shorten(_ name: String) -> String {
        name.count > 18 ? String(name.prefix(17)) + "…" : name
    }
}
