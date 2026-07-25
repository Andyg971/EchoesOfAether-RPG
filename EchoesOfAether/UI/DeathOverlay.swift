import SpriteKit

@MainActor
final class DeathOverlay {
    private let root = SKNode()

    var onRetry: (() -> Void)?
    var onReturnToCrystal: (() -> Void)?

    var isActive: Bool { root.parent != nil && !root.isHidden }

    // Curseur (contrôles classiques) : Réessayer / Revenir au cristal.
    private var selection = 0
    private let buttonNames = ["deathRetry", "deathCrystal"]

    /// Joystick haut/bas : déplace le curseur entre les deux choix.
    func moveSelection(_ dy: Int) {
        guard isActive else { return }
        selection = (selection - dy + buttonNames.count) % buttonNames.count
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        refreshHighlight()
        if let btn = root.childNode(withName: buttonNames[selection]),
           let lbl = btn.children.compactMap({ $0 as? SKLabelNode }).first {
            AccessibilitySettings.announce(lbl.text ?? "")
        }
    }

    /// Bouton A : valide le choix sélectionné.
    func confirmSelection() {
        guard isActive else { return }
        selection == 0 ? onRetry?() : onReturnToCrystal?()
    }

    private func refreshHighlight() {
        for (i, name) in buttonNames.enumerated() {
            guard let btn = root.childNode(withName: name) as? SKShapeNode else { continue }
            let selected = i == selection
            btn.lineWidth = selected ? 3 : 2
            btn.setScale(selected ? 1.06 : 1.0)
        }
    }

    func attach(to scene: SKScene) {
        root.zPosition = 2_000
        root.isHidden = true
        scene.addChild(root)
    }

    func show(in scene: SKScene) {
        root.removeAllChildren()
        root.isHidden = false
        selection = 0

        // Fond noir semi-transparent
        let scrim = SKShapeNode(rectOf: scene.size)
        scrim.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.88)
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        root.addChild(scrim)

        // Mémorial pixel : épée plantée dans un tertre, au-dessus du titre.
        let memorial = makeFallenMemorial()
        memorial.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.78)
        memorial.alpha = 0
        memorial.setScale(0.6)
        root.addChild(memorial)

        // Titre — TOMBÉ —
        let title = SKLabelNode(fontNamed: PixelUI.uiFont)
        title.text = String(localized: "death.title")
        title.fontSize = 46
        title.fontColor = SKColor(red: 0.75, green: 0.15, blue: 0.15, alpha: 1)
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.62)
        title.alpha = 0
        root.addChild(title)

        // Sous-titre
        let sub = SKLabelNode(fontNamed: PixelUI.uiFont)
        sub.text = String(localized: "death.subtitle")
        sub.fontSize = 18
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
        memorial.run(.group([
            fadeIn,
            .scale(to: 1.0, duration: 0.6)
        ]))
        title.run(.sequence([.wait(forDuration: 0.2), fadeIn]))
        sub.run(.sequence([.wait(forDuration: 0.5), fadeIn]))
        retryBtn.run(.sequence([.wait(forDuration: 0.7), fadeIn]))
        crystalBtn.run(.sequence([.wait(forDuration: 0.85), fadeIn]))
        refreshHighlight()

        // iPad : agrandit l'overlay (centre fixe). iPhone → facteur 1.
        UIScale.apply(to: root, sceneSize: scene.size)
        AccessibilitySettings.announce(
            "\(String(localized: "death.title")). \(String(localized: "death.subtitle"))")
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

    /// Épée plantée dans un tertre — mémorial pixel art dessiné en code.
    /// Lame vers le bas (point-down), garde en croix, poignée en cuir.
    private func makeFallenMemorial() -> SKNode {
        let map = [
            "....HHH....",
            "....HHH....",
            "..GGGGGGG..",
            "....XeX....",
            "....XeX....",
            "....XeX....",
            "..mmXeXmm..",
            ".mmmmmmmmm.",
            "mmmmmmmmmmm"
        ]
        let palette: [Character: SKColor] = [
            "H": SKColor(red: 0.42, green: 0.30, blue: 0.20, alpha: 1),   // cuir
            "G": SKColor(red: 0.58, green: 0.48, blue: 0.28, alpha: 1),   // garde (or terni)
            "X": SKColor(red: 0.50, green: 0.54, blue: 0.62, alpha: 1),   // acier
            "e": SKColor(red: 0.70, green: 0.74, blue: 0.82, alpha: 1),   // reflet de lame
            "m": SKColor(red: 0.17, green: 0.15, blue: 0.20, alpha: 1)    // terre sombre
        ]
        return PixelIcons.custom(map: map, palette: palette, pixel: 4)
    }

    private func makeButton(label: String, fill: SKColor,
                            stroke: SKColor, name: String) -> SKShapeNode {
        // Bouton pixel : rectangle net, zéro coin arrondi, zéro glow.
        let btn = SKShapeNode(rectOf: CGSize(width: 220, height: 50))
        btn.fillColor = fill
        btn.strokeColor = stroke
        btn.lineWidth = 2
        btn.glowWidth = 0
        btn.name = name

        let lbl = SKLabelNode(fontNamed: PixelUI.uiFont)
        lbl.text = label
        lbl.fontSize = 21
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }
}
