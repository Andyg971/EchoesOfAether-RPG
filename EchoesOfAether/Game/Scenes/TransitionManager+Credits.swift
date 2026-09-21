import SpriteKit

// TransitionManager — le générique de fin, tap pour fermer.
extension TransitionManager {
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

        // MISE EN PAGE — l'écran est en PAYSAGE : ~400 pt de haut, pas 800.
        //
        // Les entrées descendaient de 52 pt chacune, mais la citation et le
        // bouton se plaçaient sur une formule séparée à 26 pt par entrée.
        // Deux pas différents pour une seule colonne : le bouton « Fermer »
        // tombait à −221 alors que le bas de l'écran est à −201. Il était
        // hors champ, et les crédits ne se fermaient plus.
        //
        // Désormais un seul curseur descend la colonne, et le pas se resserre
        // si la place manque — ajouter une ligne aux crédits ne peut plus
        // repousser le bouton dehors.
        let quoteGap: CGFloat = 34
        let buttonGap: CGFloat = 52
        let margin: CGFloat = 22
        let available = scene.size.height - margin * 2 - quoteGap - buttonGap
        let rowGap = min(52, max(34, available / CGFloat(credits.count)))
        let blockHeight = rowGap * CGFloat(credits.count) + quoteGap + buttonGap

        var y = blockHeight / 2 - 14
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
            y -= rowGap
        }

        // Quote finale — sous la dernière entrée, sur le MÊME curseur.
        let quote = SKLabelNode(fontNamed: PixelUI.uiFont)
        quote.text = String(localized: "credits.quote")
        quote.fontSize = 16
        quote.fontColor = SKColor(red: 0.65, green: 0.50, blue: 0.90, alpha: 0.85)
        quote.position = CGPoint(x: 0, y: y - 6)
        overlay.addChild(quote)
        y -= quoteGap

        // Bouton fermer
        let closeBtn = SKShapeNode()
        PixelUI.stylePanel(closeBtn, size: CGSize(width: 140, height: 40),
                           fill: Palette.panelNight,
                           accent: SKColor(red: 0.40, green: 0.35, blue: 0.65, alpha: 1))
        closeBtn.name = "creditsClose"
        closeBtn.position = CGPoint(x: 0, y: y - 12)
        let closeLbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        closeLbl.text = String(localized: "credits.close")
        closeLbl.fontSize = 16
        closeLbl.fontColor = .white
        closeLbl.verticalAlignmentMode = .center
        closeLbl.isUserInteractionEnabled = false
        closeBtn.addChild(closeLbl)
        overlay.addChild(closeBtn)

        overlay.run(.fadeIn(withDuration: 0.6))
        for (i, child) in overlay.children.enumerated() {
            JuiceEngine.popIn(child, delay: Double(i) * 0.06)
        }

        // Store closure for tap
        creditsClosureClosure = onClose
        creditsOverlayRef = overlay
    }

    static var creditsClosureClosure: (() -> Void)?
    static var creditsOverlayRef: SKShapeNode?

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
}
