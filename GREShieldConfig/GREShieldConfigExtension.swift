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
        let entry = pickWord()

        // The icon slot is treated by iOS as an app-icon — it is displayed at
        // ~60-80 pt regardless of image size. All readable content therefore
        // goes into title + subtitle, which iOS renders large and fills the
        // space above the buttons correctly.
        let badge = renderBadge()

        // Title → the GRE headword. iOS renders this in large bold type.
        let titleLabel = ShieldConfiguration.Label(
            text: entry.word.lowercased(),
            color: Palette.white
        )

        // Subtitle → part of speech, definition, example sentence, unlock line.
        // iOS renders this in smaller type, centered, multi-line.
        let subtitleText = [
            entry.pos,
            "",
            entry.def,
            "",
            "« \(entry.sentence) »",
            "",
            "Complete one verbal drill → 15 min unlocked."
        ].joined(separator: "\n")

        let subtitleLabel = ShieldConfiguration.Label(
            text: subtitleText,
            color: Palette.ink
        )

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: Palette.bg,
            icon: badge,
            title: titleLabel,
            subtitle: subtitleLabel,
            // Solid green fill with dark ink. A near-transparent fill (low alpha)
            // is treated by iOS as "unset" and falls back to system blue, so the
            // background color MUST be fully opaque.
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Unlock with one drill",
                color: Palette.bg
            ),
            primaryButtonBackgroundColor: Palette.green,
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
            def: "Carried out with a minimum of effort or thought.",
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
        static let green    = UIColor(red: 0.290, green: 0.867, blue: 0.502, alpha: 1)  // #4ADE80
        static let greenDim = UIColor(red: 0.169, green: 0.659, blue: 0.357, alpha: 1)  // #2BA85B
        static let bg       = UIColor(red: 0.024, green: 0.051, blue: 0.027, alpha: 1)  // #060D07
        static let ink      = UIColor(red: 0.855, green: 0.910, blue: 0.871, alpha: 1)  // #DAE8DE
        static let white    = UIColor(red: 0.980, green: 1.000, blue: 0.984, alpha: 1)
        static let muted    = UIColor(red: 0.494, green: 0.596, blue: 0.522, alpha: 1)  // #7E9885
    }

    // MARK: - Badge icon
    // Rendered at 80×80 pt — displayed at ~60-80 pt in the icon slot.
    // Keeps the GRE wordmark visible without wasting the content area.

    nonisolated private func renderBadge() -> UIImage {
        let size: CGFloat = 80
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)

        return renderer.image { _ in
            // Dark circle background
            let bgPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size))
            Palette.bg.setFill()
            bgPath.fill()

            // Green ring
            let ringPath = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: size - 4, height: size - 4))
            ringPath.lineWidth = 2.5
            Palette.green.setStroke()
            ringPath.stroke()

            // "GRE" label centered
            let greAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: Palette.white,
                .kern: 2.0
            ]
            let greStr = "GRE" as NSString
            let greSize = greStr.size(withAttributes: greAttr)
            greStr.draw(at: CGPoint(x: (size - greSize.width) / 2,
                                    y: (size - greSize.height) / 2 - 8),
                        withAttributes: greAttr)

            // "VERBAL" label centered below
            let verbalAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                .foregroundColor: Palette.muted,
                .kern: 1.5
            ]
            let verbalStr = "VERBAL" as NSString
            let verbalSize = verbalStr.size(withAttributes: verbalAttr)
            verbalStr.draw(at: CGPoint(x: (size - verbalSize.width) / 2,
                                       y: (size - greSize.height) / 2 + greSize.height - 6),
                           withAttributes: verbalAttr)
        }
    }

    nonisolated private func shorten(_ name: String) -> String {
        name.count > 18 ? String(name.prefix(17)) + "…" : name
    }
}
