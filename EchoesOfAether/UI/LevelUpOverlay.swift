import SpriteKit

/// Pop-up "Niveau X !" affiché après un combat qui déclenche un level-up.
/// Mode tap-to-dismiss + auto-dismiss après 3.5s en sécurité.
@MainActor
final class LevelUpOverlay {
    private let root = SKNode()
    private let scrim = SKShapeNode()
    private let panel = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let subtitleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let statsLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let hintLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var onDismiss: (() -> Void)?

    var isVisible: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_500
        root.isHidden = true
        scene.addChild(root)

        scrim.fillColor = SKColor(red: 0.02, green: 0.01, blue: 0.05, alpha: 0.78)
        scrim.strokeColor = .clear
        root.addChild(scrim)

        panel.fillColor = SKColor(red: 0.10, green: 0.06, blue: 0.18, alpha: 0.98)
        panel.strokeColor = SKColor(red: 0.75, green: 0.45, blue: 1, alpha: 1)
        panel.lineWidth = 3
        root.addChild(panel)

        titleLabel.fontSize = 36
        titleLabel.fontColor = SKColor(red: 0.95, green: 0.70, blue: 1, alpha: 1)
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        root.addChild(titleLabel)

        subtitleLabel.fontSize = 15
        subtitleLabel.fontColor = SKColor(white: 0.85, alpha: 1)
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.horizontalAlignmentMode = .center
        root.addChild(subtitleLabel)

        statsLabel.fontSize = 14
        statsLabel.fontColor = SKColor(red: 0.55, green: 0.85, blue: 0.65, alpha: 1)
        statsLabel.verticalAlignmentMode = .center
        statsLabel.horizontalAlignmentMode = .center
        root.addChild(statsLabel)

        hintLabel.fontSize = 12
        hintLabel.fontColor = SKColor(white: 0.55, alpha: 1)
        hintLabel.verticalAlignmentMode = .center
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.text = String(localized: "levelUp.tapToContinue")
        root.addChild(hintLabel)
        JuiceEngine.pulse(hintLabel, scale: 1.1)

        layout(in: scene.size)
    }

    func layout(in size: CGSize) {
        scrim.path = CGPath(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                            transform: nil)
        scrim.position = .zero

        let panelWidth = min(size.width - 48, 380)
        let panelHeight: CGFloat = 220
        panel.path = CGPath(
            roundedRect: CGRect(x: -panelWidth / 2, y: -panelHeight / 2,
                                width: panelWidth, height: panelHeight),
            cornerWidth: 20, cornerHeight: 20, transform: nil
        )
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)

        titleLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 60)
        subtitleLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 22)
        statsLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 22)
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 76)

        // iPad : agrandit l'overlay (centre fixe). iPhone → facteur 1.
        UIScale.apply(to: root, sceneSize: size)
    }

    /// Affiche l'overlay avec le nouveau niveau et la ligne de gains.
    /// `isMax` → niveau plafond atteint (cache la ligne de stats).
    func show(newLevel: Int, isMax: Bool, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        titleLabel.text = String(localized: "levelUp.title \(newLevel)")
        subtitleLabel.text = String(localized: "levelUp.subtitle")
        statsLabel.text = isMax
            ? String(localized: "levelUp.maxReached")
            : String(localized: "levelUp.stats")
        statsLabel.fontColor = isMax
            ? SKColor(red: 0.95, green: 0.70, blue: 0.30, alpha: 1)
            : SKColor(red: 0.55, green: 0.85, blue: 0.65, alpha: 1)

        root.isHidden = false
        root.alpha = 0
        panel.setScale(0.7)
        titleLabel.setScale(0.5)

        root.run(.fadeIn(withDuration: 0.18))
        panel.run(.sequence([
            .scale(to: 1.05, duration: 0.22),
            .scale(to: 1.0, duration: 0.12)
        ]))
        titleLabel.run(.sequence([
            .wait(forDuration: 0.08),
            .scale(to: 1.15, duration: 0.18),
            .scale(to: 1.0, duration: 0.12)
        ]))

        HapticsEngine.heavy()
        AudioEngine.shared.playVictory()

        // Sécurité : auto-dismiss après 3.5s si pas tapé
        root.run(.sequence([
            .wait(forDuration: 3.5),
            .run { [weak self] in self?.dismiss() }
        ]), withKey: "autoDismiss")
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isVisible else { return false }
        dismiss()
        return true
    }

    private func dismiss() {
        guard isVisible else { return }
        root.removeAction(forKey: "autoDismiss")
        root.run(.sequence([
            .fadeOut(withDuration: 0.2),
            .run { [weak self] in
                guard let self else { return }
                self.root.isHidden = true
                let cb = self.onDismiss
                self.onDismiss = nil
                cb?()
            }
        ]))
    }
}
