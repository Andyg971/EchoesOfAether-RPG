import SpriteKit

@MainActor
final class PauseOverlay {
    private let root = SKNode()
    private var buttonsReady = false

    var onResume: (() -> Void)?
    var onSave: (() -> Void)?
    var onOptions: (() -> Void)?
    var onMainMenu: (() -> Void)?

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_500
        root.isHidden = true
        scene.addChild(root)
    }

    func show(in scene: SKScene) {
        root.removeAllChildren()
        root.isHidden = false
        buttonsReady = false

        // Fond flouté (semi-transparent)
        let scrim = SKShapeNode(rectOf: scene.size)
        scrim.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.72)
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        root.addChild(scrim)

        // Panel central
        let panelW: CGFloat = 280
        let panelH: CGFloat = 360
        let panel = SKShapeNode(
            path: CGPath(roundedRect: CGRect(x: -panelW/2, y: -panelH/2,
                                            width: panelW, height: panelH),
                         cornerWidth: 20, cornerHeight: 20, transform: nil)
        )
        panel.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 0.96)
        panel.strokeColor = SKColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 0.8)
        panel.lineWidth = 2
        panel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        panel.alpha = 0
        root.addChild(panel)

        // Titre
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = String(localized: "pause.title")
        title.fontSize = 22
        title.fontColor = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: scene.size.width / 2,
                                 y: scene.size.height / 2 + panelH / 2 - 40)
        title.alpha = 0
        root.addChild(title)

        // Boutons
        let centerX = scene.size.width / 2
        let centerY = scene.size.height / 2

        let resumeBtn = makeButton(String(localized: "pause.resume"),
            fill: SKColor(red: 0.10, green: 0.20, blue: 0.12, alpha: 1),
            stroke: SKColor(red: 0.30, green: 0.70, blue: 0.40, alpha: 1),
            name: "pauseResume")
        resumeBtn.position = CGPoint(x: centerX, y: centerY + 60)
        resumeBtn.alpha = 0
        root.addChild(resumeBtn)

        let saveBtn = makeButton(String(localized: "pause.save"),
            fill: SKColor(red: 0.06, green: 0.06, blue: 0.18, alpha: 1),
            stroke: SKColor(red: 0.30, green: 0.45, blue: 0.80, alpha: 1),
            name: "pauseSave")
        saveBtn.position = CGPoint(x: centerX, y: centerY)
        saveBtn.alpha = 0
        root.addChild(saveBtn)

        let optionsBtn = makeButton(String(localized: "pause.options"),
            fill: SKColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1),
            stroke: SKColor(red: 0.40, green: 0.35, blue: 0.65, alpha: 0.8),
            name: "pauseOptions")
        optionsBtn.position = CGPoint(x: centerX, y: centerY - 58)
        optionsBtn.alpha = 0
        root.addChild(optionsBtn)

        let menuBtn = makeButton(String(localized: "pause.mainMenu"),
            fill: SKColor(red: 0.12, green: 0.06, blue: 0.06, alpha: 1),
            stroke: SKColor(red: 0.55, green: 0.20, blue: 0.20, alpha: 0.9),
            name: "pauseMenu")
        menuBtn.position = CGPoint(x: centerX, y: centerY - 118)
        menuBtn.alpha = 0
        root.addChild(menuBtn)

        // Animate
        let fadeIn = SKAction.fadeIn(withDuration: 0.25)
        panel.run(fadeIn)
        title.run(fadeIn)
        resumeBtn.run(.sequence([.wait(forDuration: 0.08), fadeIn]))
        saveBtn.run(.sequence([.wait(forDuration: 0.14), fadeIn]))
        optionsBtn.run(.sequence([.wait(forDuration: 0.18), fadeIn]))
        menuBtn.run(.sequence([.wait(forDuration: 0.22), fadeIn, .run { [weak self] in self?.buttonsReady = true }]))
    }

    func hide() {
        root.isHidden = true
        root.removeAllChildren()
        buttonsReady = false
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive, buttonsReady else { return isActive }
        let local = root.convert(point, from: scene)

        if let btn = root.childNode(withName: "pauseResume") as? SKShapeNode,
           btn.contains(local) {
            onResume?()
            return true
        }
        if let btn = root.childNode(withName: "pauseSave") as? SKShapeNode,
           btn.contains(local) {
            onSave?()
            return true
        }
        if let btn = root.childNode(withName: "pauseOptions") as? SKShapeNode,
           btn.contains(local) {
            onOptions?()
            return true
        }
        if let btn = root.childNode(withName: "pauseMenu") as? SKShapeNode,
           btn.contains(local) {
            onMainMenu?()
            return true
        }
        return true
    }

    // MARK: - Private

    private func makeButton(_ label: String, fill: SKColor,
                            stroke: SKColor, name: String) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: 200, height: 48), cornerRadius: 14)
        btn.fillColor = fill
        btn.strokeColor = stroke
        btn.lineWidth = 1.8
        btn.name = name

        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = label
        lbl.fontSize = 15
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }
}
