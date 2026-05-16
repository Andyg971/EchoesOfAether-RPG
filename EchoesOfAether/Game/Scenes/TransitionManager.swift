import SpriteKit

@MainActor
enum TransitionManager {

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

    static func showEndScreen(in scene: SKScene, resonance: Int) {
        let overlay = SKShapeNode(rectOf: scene.size)
        overlay.fillColor = SKColor(red: 0.03, green: 0.03, blue: 0.06, alpha: 0.95)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        overlay.zPosition = 2000
        overlay.alpha = 0
        scene.addChild(overlay)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = String(localized: "endscreen.title")
        title.fontSize = 28
        title.fontColor = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        title.position = CGPoint(x: 0, y: 80)
        overlay.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subtitle.text = String(localized: "endscreen.subtitle")
        subtitle.fontSize = 16
        subtitle.fontColor = SKColor(white: 0.6, alpha: 1)
        subtitle.position = CGPoint(x: 0, y: 48)
        overlay.addChild(subtitle)

        let resonanceLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        resonanceLabel.text = String(localized: "endscreen.resonance \(resonance)")
        resonanceLabel.fontSize = 18
        resonanceLabel.fontColor = SKColor(red: 0.65, green: 0.45, blue: 0.90, alpha: 1)
        resonanceLabel.position = CGPoint(x: 0, y: 4)
        overlay.addChild(resonanceLabel)

        let divider = SKShapeNode(rectOf: CGSize(width: 200, height: 1))
        divider.fillColor = SKColor(white: 0.25, alpha: 1)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: -24)
        overlay.addChild(divider)

        let betrayal = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
        betrayal.text = String(localized: "endscreen.betrayal")
        betrayal.fontSize = 15
        betrayal.fontColor = SKColor(white: 0.75, alpha: 1)
        betrayal.position = CGPoint(x: 0, y: -52)
        overlay.addChild(betrayal)

        overlay.run(.fadeAlpha(to: 1, duration: 0.8))

        for child in overlay.children {
            JuiceEngine.popIn(child, delay: Double(overlay.children.firstIndex(of: child) ?? 0) * 0.15)
        }
    }
}
