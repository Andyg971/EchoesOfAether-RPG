import SpriteKit

/// Onboarding affiché à la première partie (flag UserDefaults "tutorialSeen").
/// Explique les bases en 4 panneaux : déplacement, interactions PNJ, combat
/// ATB, sauvegarde aux cristaux. Relançable depuis les Options.
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

    func show(in scene: SKScene, completion: (() -> Void)? = nil) {
        self.scene = scene
        self.index = 0
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

        let panelW: CGFloat = 320, panelH: CGFloat = 320
        let panel = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -panelW/2, y: -panelH/2, width: panelW, height: panelH),
            cornerWidth: 20, cornerHeight: 20, transform: nil))
        panel.fillColor = SKColor(red: 0.06, green: 0.05, blue: 0.12, alpha: 0.98)
        panel.strokeColor = SKColor(red: 0.50, green: 0.40, blue: 0.85, alpha: 0.9)
        panel.lineWidth = 2
        panel.position = CGPoint(x: cx, y: cy)
        root.addChild(panel)

        let currentPanel = self.panels[min(index, panels.count - 1)]
        let top = cy + panelH / 2

        let stepLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        stepLabel.text = String(localized: "tutorial.progress \(index + 1) \(panels.count)")
        stepLabel.fontSize = 12
        stepLabel.fontColor = SKColor(red: 0.65, green: 0.55, blue: 0.95, alpha: 1)
        stepLabel.horizontalAlignmentMode = .center
        stepLabel.verticalAlignmentMode = .center
        stepLabel.position = CGPoint(x: cx, y: top - 30)
        root.addChild(stepLabel)

        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLabel.text = currentPanel.title
        titleLabel.fontSize = 19
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.preferredMaxLayoutWidth = panelW - 36
        titleLabel.numberOfLines = 2
        titleLabel.position = CGPoint(x: cx, y: top - 64)
        root.addChild(titleLabel)

        let bodyLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        bodyLabel.text = currentPanel.body
        bodyLabel.fontSize = 13
        bodyLabel.fontColor = SKColor(white: 0.86, alpha: 1)
        bodyLabel.horizontalAlignmentMode = .center
        bodyLabel.verticalAlignmentMode = .top
        bodyLabel.preferredMaxLayoutWidth = panelW - 44
        bodyLabel.numberOfLines = 0
        bodyLabel.position = CGPoint(x: cx, y: top - 100)
        root.addChild(bodyLabel)

        let isLast = index >= panels.count - 1
        let nextBtn = makeButton(
            isLast ? String(localized: "tutorial.finish") : String(localized: "tutorial.next"),
            fill: SKColor(red: 0.16, green: 0.10, blue: 0.28, alpha: 1),
            stroke: SKColor(red: 0.55, green: 0.42, blue: 0.92, alpha: 1),
            name: "tutorialNext", width: 200)
        nextBtn.position = CGPoint(x: cx, y: cy - panelH / 2 + 74)
        root.addChild(nextBtn)
        JuiceEngine.pulse(nextBtn, scale: 1.03)

        if !isLast {
            let skipBtn = makeButton(
                String(localized: "tutorial.skip"),
                fill: SKColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 1),
                stroke: SKColor(red: 0.40, green: 0.35, blue: 0.55, alpha: 0.8),
                name: "tutorialSkip", width: 140)
            skipBtn.position = CGPoint(x: cx, y: cy - panelH / 2 + 30)
            root.addChild(skipBtn)
        }

        // Animate + scale iPad
        for (i, child) in root.children.enumerated() where child !== scrim {
            JuiceEngine.popIn(child, delay: Double(i) * 0.04)
        }
        UIScale.apply(to: root, sceneSize: scene.size)
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

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        hide()
        let done = completion
        completion = nil
        done?()
    }

    // MARK: - Private

    private func makeButton(_ text: String, fill: SKColor, stroke: SKColor,
                            name: String, width: CGFloat) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: 44), cornerRadius: 12)
        btn.fillColor = fill
        btn.strokeColor = stroke
        btn.lineWidth = 1.8
        btn.name = name
        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = text
        lbl.fontSize = 15
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }
}
