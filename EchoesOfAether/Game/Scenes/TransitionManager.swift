import SpriteKit

@MainActor
enum TransitionManager {

    // MARK: - End Screen State
    private static var endOverlay: SKShapeNode?
    private static var continuationClosure: (() -> Void)?

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

        if onContinue != nil {
            let btn = SKShapeNode(rectOf: CGSize(width: 200, height: 46), cornerRadius: 12)
            btn.fillColor = SKColor(red: 0.18, green: 0.10, blue: 0.30, alpha: 1)
            btn.strokeColor = SKColor(red: 0.50, green: 0.35, blue: 0.80, alpha: 0.75)
            btn.lineWidth = 1.5
            btn.name = "continueBtn"
            btn.position = CGPoint(x: 0, y: -100)
            overlay.addChild(btn)

            let btnLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            btnLabel.text = String(localized: "endscreen.act1.continue")
            btnLabel.fontSize = 15
            btnLabel.fontColor = .white
            btnLabel.verticalAlignmentMode = .center
            btnLabel.name = "continueBtn"
            btn.addChild(btnLabel)
            JuiceEngine.pulse(btn, scale: 1.04)
        }

        overlay.run(.fadeAlpha(to: 1, duration: 0.8))
        for child in overlay.children {
            JuiceEngine.popIn(child, delay: Double(overlay.children.firstIndex(of: child) ?? 0) * 0.15)
        }
    }

    // MARK: - Acte II End Screen

    static func showAct2EndScreen(in scene: SKScene) {
        let overlay = SKShapeNode(rectOf: scene.size)
        overlay.fillColor = SKColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 0.97)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        overlay.zPosition = 2000
        overlay.alpha = 0
        scene.addChild(overlay)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = String(localized: "endscreen.act2.title")
        title.fontSize = 30
        title.fontColor = SKColor(red: 0.85, green: 0.20, blue: 0.15, alpha: 1)
        title.position = CGPoint(x: 0, y: 90)
        overlay.addChild(title)

        let act2Sub = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        act2Sub.text = String(localized: "endscreen.act2.subtitle")
        act2Sub.fontSize = 14
        act2Sub.fontColor = SKColor(white: 0.45, alpha: 1)
        act2Sub.position = CGPoint(x: 0, y: 58)
        overlay.addChild(act2Sub)

        let divider = SKShapeNode(rectOf: CGSize(width: 200, height: 1))
        divider.fillColor = SKColor(red: 0.50, green: 0.12, blue: 0.10, alpha: 0.6)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: 32)
        overlay.addChild(divider)

        let lyraLabel = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
        lyraLabel.text = String(localized: "endscreen.act2.lyra")
        lyraLabel.fontSize = 16
        lyraLabel.fontColor = SKColor(white: 0.65, alpha: 1)
        lyraLabel.position = CGPoint(x: 0, y: 4)
        overlay.addChild(lyraLabel)

        let divider2 = SKShapeNode(rectOf: CGSize(width: 160, height: 1))
        divider2.fillColor = SKColor(white: 0.20, alpha: 0.5)
        divider2.strokeColor = .clear
        divider2.position = CGPoint(x: 0, y: -24)
        overlay.addChild(divider2)

        let eranHint = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
        eranHint.text = String(localized: "endscreen.act2.eranHint")
        eranHint.fontSize = 12
        eranHint.fontColor = SKColor(white: 0.55, alpha: 1)
        eranHint.position = CGPoint(x: 0, y: -52)
        overlay.addChild(eranHint)

        let eranSig = SKLabelNode(fontNamed: "AvenirNext-Medium")
        eranSig.text = String(localized: "endscreen.act2.eranSig")
        eranSig.fontSize = 13
        eranSig.fontColor = SKColor(red: 0.45, green: 0.65, blue: 0.90, alpha: 0.90)
        eranSig.position = CGPoint(x: 0, y: -78)
        overlay.addChild(eranSig)

        overlay.run(.fadeAlpha(to: 1, duration: 1.2))
        for child in overlay.children {
            JuiceEngine.popIn(child, delay: Double(overlay.children.firstIndex(of: child) ?? 0) * 0.20)
        }
    }
}
