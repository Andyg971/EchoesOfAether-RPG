import SpriteKit

@MainActor
final class DeathOverlay {
    private let root = SKNode()

    var onRetry: (() -> Void)?
    var onReturnToCrystal: (() -> Void)?

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 2_000
        root.isHidden = true
        scene.addChild(root)
    }

    func show(in scene: SKScene) {
        root.removeAllChildren()
        root.isHidden = false

        // Fond noir semi-transparent
        let scrim = SKShapeNode(rectOf: scene.size)
        scrim.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.88)
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        root.addChild(scrim)

        // Titre — TOMBÉ —
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = String(localized: "death.title")
        title.fontSize = 36
        title.fontColor = SKColor(red: 0.75, green: 0.15, blue: 0.15, alpha: 1)
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.62)
        title.alpha = 0
        root.addChild(title)

        // Sous-titre
        let sub = SKLabelNode(fontNamed: "AvenirNext-Medium")
        sub.text = String(localized: "death.subtitle")
        sub.fontSize = 14
        sub.fontColor = SKColor(white: 0.55, alpha: 1)
        sub.horizontalAlignmentMode = .center
        sub.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.55)
        sub.alpha = 0
        root.addChild(sub)

        // Bouton Réessayer
        let retryBtn = makeButton(
            label: String(localized: "death.retry"),
            fill: SKColor(red: 0.18, green: 0.08, blue: 0.08, alpha: 1),
            stroke: SKColor(red: 0.65, green: 0.20, blue: 0.20, alpha: 1),
            name: "deathRetry"
        )
        retryBtn.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.42)
        retryBtn.alpha = 0
        root.addChild(retryBtn)

        // Bouton Revenir au cristal
        let crystalBtn = makeButton(
            label: String(localized: "death.returnCrystal"),
            fill: SKColor(red: 0.06, green: 0.06, blue: 0.18, alpha: 1),
            stroke: SKColor(red: 0.30, green: 0.40, blue: 0.80, alpha: 0.9),
            name: "deathCrystal"
        )
        crystalBtn.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.31)
        crystalBtn.alpha = 0
        root.addChild(crystalBtn)

        // Animate entrée
        let fadeIn = SKAction.fadeIn(withDuration: 0.5)
        title.run(.sequence([.wait(forDuration: 0.2), fadeIn]))
        sub.run(.sequence([.wait(forDuration: 0.5), fadeIn]))
        retryBtn.run(.sequence([.wait(forDuration: 0.7), fadeIn]))
        crystalBtn.run(.sequence([.wait(forDuration: 0.85), fadeIn]))
    }

    func hide() {
        root.isHidden = true
        root.removeAllChildren()
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)

        if let btn = root.childNode(withName: "deathRetry") as? SKShapeNode,
           btn.contains(local) {
            onRetry?()
            return true
        }
        if let btn = root.childNode(withName: "deathCrystal") as? SKShapeNode,
           btn.contains(local) {
            onReturnToCrystal?()
            return true
        }
        return true // absorb
    }

    // MARK: - Private

    private func makeButton(label: String, fill: SKColor,
                            stroke: SKColor, name: String) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: 220, height: 50), cornerRadius: 14)
        btn.fillColor = fill
        btn.strokeColor = stroke
        btn.lineWidth = 1.8
        btn.name = name

        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = label
        lbl.fontSize = 16
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }
}
