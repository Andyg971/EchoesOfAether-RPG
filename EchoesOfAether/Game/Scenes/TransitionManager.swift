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

        let title = SKLabelNode(fontNamed: PixelUI.uiFont)
        title.text = String(localized: "endscreen.title")
        title.fontSize = 35
        title.fontColor = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
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
            JuiceEngine.pulse(btn, scale: 1.04)
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

    // MARK: - Crédits

    static func showCredits(in scene: SKScene, onClose: @escaping () -> Void) {
        let overlay = SKShapeNode(rectOf: scene.size)
        overlay.fillColor = SKColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 0.98)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        overlay.zPosition = 4_000
        overlay.alpha = 0
        overlay.name = "creditsOverlay"
        scene.addChild(overlay)

        let credits: [(String, String)] = [
            (String(localized: "credits.game"),    "Echoes of Aether"),
            (String(localized: "credits.design"),  "AppMaker Studio"),
            (String(localized: "credits.code"),    "Swift 6 + SpriteKit"),
            (String(localized: "credits.music"),   String(localized: "credits.procedural")),
            (String(localized: "credits.tools"),   "Xcode 16 + Claude Code"),
            (String(localized: "credits.thanks"),  String(localized: "credits.thanksText"))
        ]

        var y: CGFloat = CGFloat(credits.count) * 28
        for (role, name) in credits {
            let roleL = SKLabelNode(fontNamed: PixelUI.uiFont)
            roleL.text = role
            roleL.fontSize = 14
            roleL.fontColor = SKColor(white: 0.40, alpha: 1)
            roleL.position = CGPoint(x: 0, y: y)
            overlay.addChild(roleL)

            let nameL = SKLabelNode(fontNamed: PixelUI.uiFont)
            nameL.text = name
            nameL.fontSize = 18
            nameL.fontColor = SKColor(white: 0.85, alpha: 1)
            nameL.position = CGPoint(x: 0, y: y - 18)
            overlay.addChild(nameL)
            y -= 52
        }

        // Quote finale
        let quote = SKLabelNode(fontNamed: PixelUI.uiFont)
        quote.text = String(localized: "credits.quote")
        quote.fontSize = 16
        quote.fontColor = SKColor(red: 0.65, green: 0.50, blue: 0.90, alpha: 0.85)
        quote.position = CGPoint(x: 0, y: -CGFloat(credits.count) * 26 - 20)
        overlay.addChild(quote)

        // Bouton fermer
        let closeBtn = SKShapeNode()
        PixelUI.stylePanel(closeBtn, size: CGSize(width: 140, height: 40),
                           fill: SKColor(red: 0.10, green: 0.08, blue: 0.18, alpha: 1),
                           accent: SKColor(red: 0.40, green: 0.35, blue: 0.65, alpha: 1))
        closeBtn.name = "creditsClose"
        closeBtn.position = CGPoint(x: 0, y: -CGFloat(credits.count) * 26 - 65)
        let closeLbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        closeLbl.text = String(localized: "credits.close")
        closeLbl.fontSize = 16
        closeLbl.fontColor = .white
        closeLbl.verticalAlignmentMode = .center
        closeLbl.isUserInteractionEnabled = false
        closeBtn.addChild(closeLbl)
        overlay.addChild(closeBtn)
        JuiceEngine.pulse(closeBtn, scale: 1.04)

        overlay.run(.fadeIn(withDuration: 0.6))
        for (i, child) in overlay.children.enumerated() {
            JuiceEngine.popIn(child, delay: Double(i) * 0.06)
        }

        // Store closure for tap
        creditsClosureClosure = onClose
        creditsOverlayRef = overlay
    }

    private static var creditsClosureClosure: (() -> Void)?
    private static var creditsOverlayRef: SKShapeNode?

    static func handleCreditsTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard let overlay = creditsOverlayRef else { return false }
        let local = overlay.convert(point, from: scene)
        guard let btn = overlay.childNode(withName: "creditsClose") as? SKShapeNode,
              btn.contains(local) else { return false }
        let closure = creditsClosureClosure
        creditsClosureClosure = nil
        creditsOverlayRef = nil
        overlay.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        closure?()
        return true
    }

    // MARK: - Acte II End Screen

    /// Écran de fin d'Acte II. `onContinue` est OBLIGATOIRE pour la suite :
    /// sans bouton Continuer, l'overlay opaque (zPos 2000) restait à l'écran
    /// pour toujours — les dialogues (zPos 1000) se jouaient invisibles
    /// derrière, Actes III–IV inatteignables.
    static func showAct2EndScreen(in scene: SKScene, onContinue: @escaping () -> Void) {
        let overlay = SKShapeNode(rectOf: scene.size)
        overlay.fillColor = SKColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 0.97)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        overlay.zPosition = 2000
        overlay.alpha = 0
        scene.addChild(overlay)
        // Réutilise le canal de tap de l'écran d'Acte I (handleEndScreenTap).
        endOverlay = overlay
        continuationClosure = onContinue

        let title = SKLabelNode(fontNamed: PixelUI.uiFont)
        title.text = String(localized: "endscreen.act2.title")
        title.fontSize = 38
        title.fontColor = SKColor(red: 0.85, green: 0.20, blue: 0.15, alpha: 1)
        title.position = CGPoint(x: 0, y: 90)
        overlay.addChild(title)

        let act2Sub = SKLabelNode(fontNamed: PixelUI.uiFont)
        act2Sub.text = String(localized: "endscreen.act2.subtitle")
        act2Sub.fontSize = 18
        act2Sub.fontColor = SKColor(white: 0.45, alpha: 1)
        act2Sub.position = CGPoint(x: 0, y: 58)
        overlay.addChild(act2Sub)

        let divider = SKShapeNode(rectOf: CGSize(width: 200, height: 1))
        divider.fillColor = SKColor(red: 0.50, green: 0.12, blue: 0.10, alpha: 0.6)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: 32)
        overlay.addChild(divider)

        let lyraLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        lyraLabel.text = String(localized: "endscreen.act2.lyra")
        lyraLabel.fontSize = 20
        lyraLabel.fontColor = SKColor(white: 0.65, alpha: 1)
        lyraLabel.position = CGPoint(x: 0, y: 4)
        overlay.addChild(lyraLabel)

        let divider2 = SKShapeNode(rectOf: CGSize(width: 160, height: 1))
        divider2.fillColor = SKColor(white: 0.20, alpha: 0.5)
        divider2.strokeColor = .clear
        divider2.position = CGPoint(x: 0, y: -24)
        overlay.addChild(divider2)

        let eranHint = SKLabelNode(fontNamed: PixelUI.uiFont)
        eranHint.text = String(localized: "endscreen.act2.eranHint")
        eranHint.fontSize = 15
        eranHint.fontColor = SKColor(white: 0.55, alpha: 1)
        eranHint.position = CGPoint(x: 0, y: -52)
        overlay.addChild(eranHint)

        let eranSig = SKLabelNode(fontNamed: PixelUI.uiFont)
        eranSig.text = String(localized: "endscreen.act2.eranSig")
        eranSig.fontSize = 16
        eranSig.fontColor = SKColor(red: 0.45, green: 0.65, blue: 0.90, alpha: 0.90)
        eranSig.position = CGPoint(x: 0, y: -78)
        overlay.addChild(eranSig)

        let btn = SKShapeNode()
        PixelUI.stylePanel(btn, size: CGSize(width: 210, height: 46),
                           fill: SKColor(red: 0.22, green: 0.08, blue: 0.10, alpha: 1),
                           accent: SKColor(red: 0.75, green: 0.30, blue: 0.25, alpha: 1))
        btn.name = "continueBtn"
        btn.position = CGPoint(x: 0, y: -126)
        overlay.addChild(btn)

        let btnLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        btnLabel.text = String(localized: "endscreen.act2.continue")
        btnLabel.fontSize = 19
        btnLabel.fontColor = .white
        btnLabel.verticalAlignmentMode = .center
        btnLabel.name = "continueBtn"
        btn.addChild(btnLabel)
        JuiceEngine.pulse(btn, scale: 1.04)

        overlay.run(.fadeAlpha(to: 1, duration: 1.2))
        for child in overlay.children {
            JuiceEngine.popIn(child, delay: Double(overlay.children.firstIndex(of: child) ?? 0) * 0.20)
        }
    }
}
