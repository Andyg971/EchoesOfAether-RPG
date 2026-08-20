import SpriteKit

/// Onboarding affiché à la première partie (flag UserDefaults "tutorialSeen").
/// Explique les bases en 4 panneaux : déplacement, interactions PNJ, combat
/// au tour par tour, sauvegarde aux cristaux. Relançable depuis les Options.
@MainActor
final class TutorialOverlay {

    static let seenKey = "tutorialSeen"

    private let root = SKNode()
    private weak var scene: SKScene?
    private var index = 0
    private var completion: (() -> Void)?

    var isActive: Bool { root.parent != nil && !root.isHidden }

    private struct Panel {
        let title: String
        let body: String
    }

    private var panels: [Panel] {
        [
            Panel(title: String(localized: "tutorial.move.title"),
                  body: String(localized: "tutorial.move.body")),
            Panel(title: String(localized: "tutorial.npc.title"),
                  body: String(localized: "tutorial.npc.body")),
            Panel(title: String(localized: "tutorial.combat.title"),
                  body: String(localized: "tutorial.combat.body")),
            Panel(title: String(localized: "tutorial.save.title"),
                  body: String(localized: "tutorial.save.body"))
        ]
    }

    func attach(to scene: SKScene) {
        self.scene = scene
        root.zPosition = 1_800
        root.isHidden = true
        scene.addChild(root)
    }

    /// `startAt` sert à l'audit visuel (`--overlay-test tutorial:2`) : chaque
    /// panneau a sa propre longueur de texte, il faut pouvoir les regarder un
    /// par un sans cliquer « Suivant ».
    func show(in scene: SKScene, startAt: Int = 0, completion: (() -> Void)? = nil) {
        self.scene = scene
        self.index = min(max(0, startAt), panels.count - 1)
        self.completion = completion
        root.isHidden = false
        build()
    }

    func hide() {
        root.isHidden = true
        root.removeAllChildren()
    }

    // MARK: - Build

    private func build() {
        guard let scene else { return }
        root.removeAllChildren()
        root.setScale(1)
        root.position = .zero

        let w = scene.size.width, h = scene.size.height
        let cx = w / 2, cy = h / 2

        let scrim = SKShapeNode(rectOf: scene.size)
        scrim.fillColor = SKColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 0.88)
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: cx, y: cy)
        root.addChild(scrim)

        let panelW: CGFloat = 320, panelH: CGFloat = 372
        let panel = SKShapeNode()
        PixelUI.stylePanel(panel, size: CGSize(width: panelW, height: panelH))
        panel.position = CGPoint(x: cx, y: cy)
        root.addChild(panel)

        let currentPanel = self.panels[min(index, panels.count - 1)]
        let top = cy + panelH / 2

        let stepLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        stepLabel.text = String(localized: "tutorial.progress \(index + 1) \(panels.count)")
        stepLabel.fontSize = 15
        stepLabel.fontColor = PixelUI.gold
        stepLabel.horizontalAlignmentMode = .center
        stepLabel.verticalAlignmentMode = .center
        stepLabel.position = CGPoint(x: cx, y: top - 28)
        root.addChild(stepLabel)

        let titleLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        titleLabel.text = currentPanel.title
        titleLabel.fontSize = 25
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.preferredMaxLayoutWidth = panelW - 36
        titleLabel.numberOfLines = 2
        titleLabel.position = CGPoint(x: cx, y: top - 58)
        root.addChild(titleLabel)

        // Illustration pixel du panneau (joystick, dialogue, épée, cristal).
        let illustration = makeIllustration(for: index)
        illustration.position = CGPoint(x: cx, y: top - 108)
        root.addChild(illustration)

        let bodyLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        bodyLabel.text = currentPanel.body
        bodyLabel.fontSize = 17
        bodyLabel.fontColor = SKColor(white: 0.86, alpha: 1)
        bodyLabel.horizontalAlignmentMode = .center
        bodyLabel.verticalAlignmentMode = .top
        bodyLabel.preferredMaxLayoutWidth = panelW - 44
        bodyLabel.numberOfLines = 0
        bodyLabel.position = CGPoint(x: cx, y: top - 148)
        root.addChild(bodyLabel)

        let isLast = index >= panels.count - 1
        let nextBtn = PixelUI.makeButton(
            isLast ? String(localized: "tutorial.finish") : String(localized: "tutorial.next"),
            size: CGSize(width: 200, height: 44),
            fill: SKColor(red: 0.14, green: 0.11, blue: 0.07, alpha: 1),
            accent: PixelUI.gold,
            fontSize: 20, name: "tutorialNext")
        // +3/-3 vs l'ancien pas (74/30) : la double bordure du bouton pixel
        // (liseré sombre extérieur) se touchait avec celle de "Passer" juste
        // en dessous sans cet écart.
        nextBtn.position = CGPoint(x: cx, y: cy - panelH / 2 + 77)
        root.addChild(nextBtn)

        if !isLast {
            let skipBtn = PixelUI.makeButton(
                String(localized: "tutorial.skip"),
                size: CGSize(width: 140, height: 44),
                fill: SKColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 1),
                accent: SKColor(red: 0.40, green: 0.35, blue: 0.55, alpha: 0.8),
                fontSize: 20, name: "tutorialSkip")
            skipBtn.position = CGPoint(x: cx, y: cy - panelH / 2 + 27)
            root.addChild(skipBtn)
        }

        // Animate + scale iPad
        for (i, child) in root.children.enumerated() where child !== scrim {
            JuiceEngine.popIn(child, delay: Double(i) * 0.04)
        }
        UIScale.apply(to: root, sceneSize: scene.size)
        AccessibilitySettings.announce("\(currentPanel.title). \(currentPanel.body)")
    }

    // MARK: - Tap

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)

        if let btn = root.childNode(withName: "tutorialSkip") as? SKShapeNode,
           btn.contains(local) {
            HapticsEngine.light()
            finish()
            return true
        }
        if let btn = root.childNode(withName: "tutorialNext") as? SKShapeNode,
           btn.contains(local) {
            HapticsEngine.light()
            index += 1
            if index >= panels.count {
                finish()
            } else {
                build()
            }
            return true
        }
        return true   // absorbe les taps tant que le tutoriel est visible
    }

    /// Bouton A : panneau suivant (ou terminer au dernier).
    func advanceExternally() {
        guard isActive else { return }
        HapticsEngine.light()
        index += 1
        if index >= panels.count { finish() } else { build() }
    }

    /// Bouton B : passe le tutoriel.
    func skipExternally() {
        guard isActive else { return }
        HapticsEngine.light()
        finish()
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        hide()
        let done = completion
        completion = nil
        done?()
    }

    // MARK: - Illustrations pixel

    /// Diagramme pixel du panneau : montrer plutôt que décrire.
    private func makeIllustration(for index: Int) -> SKNode {
        switch index {
        case 0:  return joystickDiagram()        // déplacement
        case 1:  return PixelIcons.node(.chat, pixel: 5)   // parler aux PNJ
        case 2:  return PixelIcons.node(.sword, pixel: 5)  // combat
        default: return PixelIcons.node(.gem, pixel: 5)    // sauvegarde (cristal)
        }
    }

    /// Manette pixel : socle circulaire (dessiné carré-par-carré) + stick
    /// violet + croix directionnelle. Aide le joueur à identifier le joystick.
    private func joystickDiagram() -> SKNode {
        let map = [
            "....t....",
            "..RRRRR..",
            ".R..t..R.",
            ".RtKKKtR.",
            ".R..t..R.",
            "..RRRRR..",
            "....t...."
        ]
        let palette: [Character: SKColor] = [
            "R": SKColor(red: 0.30, green: 0.28, blue: 0.38, alpha: 1),   // socle
            "K": SKColor(red: 0.62, green: 0.42, blue: 0.96, alpha: 1),   // stick
            "t": SKColor(red: 0.85, green: 0.80, blue: 0.55, alpha: 0.9)  // ticks directionnels
        ]
        return PixelIcons.custom(map: map, palette: palette, pixel: 5)
    }

}
