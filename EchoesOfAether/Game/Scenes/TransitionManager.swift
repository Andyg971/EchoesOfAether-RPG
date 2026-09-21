import SpriteKit

@MainActor
enum TransitionManager {

    // MARK: - End Screen State
    static var endOverlay: SKShapeNode?
    static var continuationClosure: (() -> Void)?

    /// Called from GameManager.handleTap — intercepts taps on the Act 1 "Continue" button.
    static func handleEndScreenTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard let overlay = endOverlay else { return false }
        let local = overlay.convert(point, from: scene)
        guard let btn = overlay.childNode(withName: "continueBtn") as? SKShapeNode,
              btn.contains(local) else { return false }
        let closure = continuationClosure
        continuationClosure = nil
        endOverlay = nil
        overlay.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
        closure?()
        return true
    }

    static func fade(in scene: SKScene, duration: TimeInterval = 0.4,
                     midAction: @escaping () -> Void, completion: (() -> Void)? = nil) {
        let overlay = SKShapeNode(rectOf: scene.size)
        overlay.fillColor = .black
        overlay.strokeColor = .clear
        overlay.alpha = 0
        overlay.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        overlay.zPosition = 2000
        scene.addChild(overlay)

        overlay.run(.sequence([
            .fadeAlpha(to: 1, duration: duration),
            .run { midAction() },
            .wait(forDuration: 0.15),
            .fadeAlpha(to: 0, duration: duration),
            .removeFromParent(),
            .run { completion?() }
        ]))
    }

    static func showEndScreen(in scene: SKScene, resonance: Int, onContinue: (() -> Void)? = nil) {
        let overlay = SKShapeNode(rectOf: scene.size)
        overlay.fillColor = SKColor(red: 0.03, green: 0.03, blue: 0.06, alpha: 0.95)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        overlay.zPosition = 2000
        overlay.alpha = 0
        scene.addChild(overlay)
        endOverlay = overlay
        continuationClosure = onContinue

        let title = SKLabelNode(fontNamed: PixelUI.uiFont)
        title.text = String(localized: "endscreen.title")
        title.fontSize = 35
        title.fontColor = Palette.aether
        title.position = CGPoint(x: 0, y: 80)
        overlay.addChild(title)

        let subtitle = SKLabelNode(fontNamed: PixelUI.uiFont)
        subtitle.text = String(localized: "endscreen.subtitle")
        subtitle.fontSize = 20
        subtitle.fontColor = SKColor(white: 0.6, alpha: 1)
        subtitle.position = CGPoint(x: 0, y: 48)
        overlay.addChild(subtitle)

        let resonanceLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        resonanceLabel.text = String(localized: "endscreen.resonance \(resonance)")
        resonanceLabel.fontSize = 22
        resonanceLabel.fontColor = SKColor(red: 0.65, green: 0.45, blue: 0.90, alpha: 1)
        resonanceLabel.position = CGPoint(x: 0, y: 4)
        overlay.addChild(resonanceLabel)

        let divider = SKShapeNode(rectOf: CGSize(width: 200, height: 1))
        divider.fillColor = SKColor(white: 0.25, alpha: 1)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: -24)
        overlay.addChild(divider)

        let betrayal = SKLabelNode(fontNamed: PixelUI.uiFont)
        betrayal.text = String(localized: "endscreen.betrayal")
        betrayal.fontSize = 19
        betrayal.fontColor = SKColor(white: 0.75, alpha: 1)
        betrayal.position = CGPoint(x: 0, y: -52)
        overlay.addChild(betrayal)

        if onContinue != nil {
            let btn = SKShapeNode()
            PixelUI.stylePanel(btn, size: CGSize(width: 200, height: 46),
                               fill: SKColor(red: 0.18, green: 0.10, blue: 0.30, alpha: 1),
                               accent: SKColor(red: 0.50, green: 0.35, blue: 0.80, alpha: 1))
            btn.name = "continueBtn"
            btn.position = CGPoint(x: 0, y: -100)
            overlay.addChild(btn)

            let btnLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
            btnLabel.text = String(localized: "endscreen.act1.continue")
            btnLabel.fontSize = 19
            btnLabel.fontColor = .white
            btnLabel.verticalAlignmentMode = .center
            btnLabel.name = "continueBtn"
            btn.addChild(btnLabel)
        }

        overlay.run(.fadeAlpha(to: 1, duration: 0.8))
        for child in overlay.children {
            JuiceEngine.popIn(child, delay: Double(overlay.children.firstIndex(of: child) ?? 0) * 0.15)
        }
    }

    // MARK: - Corruption Cinematic (niv. 3)

    /// Flash séquence quand corruption atteint niveau 3 — appelé depuis GameManager.
    static func showCorruptionCinematic(in scene: SKScene, completion: @escaping () -> Void) {
        let overlay = SKShapeNode(rectOf: scene.size)
        overlay.fillColor = .black
        overlay.strokeColor = .clear
        overlay.alpha = 0
        overlay.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        overlay.zPosition = 3_000
        scene.addChild(overlay)

        // Message centré
        let msg = SKLabelNode(fontNamed: PixelUI.uiFont)
        msg.text = String(localized: "corruption.cinematic.line1")
        msg.fontSize = 28
        msg.fontColor = SKColor(red: 0.80, green: 0.12, blue: 0.10, alpha: 1)
        msg.horizontalAlignmentMode = .center
        msg.alpha = 0
        msg.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2 + 20)
        msg.zPosition = 3_001
        scene.addChild(msg)

        let msg2 = SKLabelNode(fontNamed: PixelUI.uiFont)
        msg2.text = String(localized: "corruption.cinematic.line2")
        msg2.fontSize = 19
        msg2.fontColor = SKColor(white: 0.55, alpha: 1)
        msg2.horizontalAlignmentMode = .center
        msg2.alpha = 0
        msg2.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2 - 16)
        msg2.zPosition = 3_001
        scene.addChild(msg2)

        HapticsEngine.heavy()
        overlay.run(.sequence([
            .fadeAlpha(to: 0.95, duration: 0.4),
            .run { msg.run(.fadeIn(withDuration: 0.3)); msg2.run(.fadeIn(withDuration: 0.5)) },
            .wait(forDuration: 1.6),
            .fadeOut(withDuration: 0.5),
            .run {
                msg.removeFromParent()
                msg2.removeFromParent()
                overlay.removeFromParent()
                completion()
            }
        ]))
    }

}
