import SpriteKit

// TransitionManager — l'écran de fin d'Acte II.
extension TransitionManager {
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

        overlay.run(.fadeAlpha(to: 1, duration: 1.2))
        for child in overlay.children {
            JuiceEngine.popIn(child, delay: Double(overlay.children.firstIndex(of: child) ?? 0) * 0.20)
        }
    }
}
