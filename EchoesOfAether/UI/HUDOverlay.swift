import SpriteKit

@MainActor
final class HUDOverlay {
    private let root = SKNode()
    // Lisibilité sans plaques : chaque label a une ombre portée dure
    // (décalage 1.5 px, noir) — fini les gros rectangles sombres.
    private var shadowPairs: [(main: SKLabelNode, shadow: SKLabelNode)] = []
    private let objectiveLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let resonanceLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let goldLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let questLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let interactionHintLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let hpLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let levelLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let xpLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let xpBarBack = SKShapeNode()
    private let xpBarFill = SKShapeNode()
    private let xpBarWidth: CGFloat = 88
    private let xpBarHeight: CGFloat = 4
    let inventoryButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44))
    let pauseButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44))
    let loreButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44))
    let questLogButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44))

    var onInventoryTap: (() -> Void)?
    var onPauseTap: (() -> Void)?
    var onLoreTap: (() -> Void)?
    var onQuestLogTap: (() -> Void)?

    var objectiveText: String = "" {
        didSet { objectiveLabel.text = objectiveText; refreshShadows() }
    }

    var resonanceValue: Int = 0 {
        didSet {
            resonanceLabel.text = String(localized: "hud.resonance \(resonanceValue)")
            refreshShadows()
        }
    }

    var goldValue: Int = 0 {
        didSet {
            goldLabel.text = String(localized: "hud.gold \(goldValue)")
            refreshShadows()
        }
    }

    var questText: String = "" {
        didSet {
            questLabel.text = questText
            questLabel.isHidden = questText.isEmpty
            refreshShadows()
        }
    }

    var interactionHint: String = "" {
        didSet {
            interactionHintLabel.text = interactionHint
            interactionHintLabel.isHidden = interactionHint.isEmpty
            refreshShadows()
        }
    }

    var hpValue: String = "" {
        didSet { hpLabel.text = hpValue; refreshShadows() }
    }

    /// Met à jour le niveau + la barre d'XP. `progress` ∈ [0, 1].
    /// `isMax = true` → masque les chiffres XP et remplit la barre en doré.
    func setLevel(_ level: Int, xp: Int, xpToNext: Int,
                  progress: CGFloat, isMax: Bool) {
        levelLabel.text = String(localized: "hud.level \(level)")
        if isMax {
            xpLabel.text = String(localized: "hud.xp.max")
            xpBarFill.fillColor = SKColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 1)
        } else {
            xpLabel.text = String(localized: "hud.xp \(xp) \(xpToNext)")
            xpBarFill.fillColor = SKColor(red: 0.55, green: 0.80, blue: 1, alpha: 1)
        }
        xpBarFill.xScale = max(0.02, min(1, isMax ? 1 : progress))
        refreshShadows()
    }

    /// Masque/affiche tout le HUD d'exploration (le combat occupe
    /// l'écran entier : cœur, XP et plaques ne doivent pas transparaître).
    func setVisible(_ visible: Bool) {
        root.run(.fadeAlpha(to: visible ? 1 : 0, duration: 0.20))
    }

    func attach(to scene: SKScene) {
        root.zPosition = 100

        objectiveLabel.fontSize = 13
        objectiveLabel.fontColor = .white
        objectiveLabel.horizontalAlignmentMode = .left
        objectiveLabel.verticalAlignmentMode = .center
        root.addChild(objectiveLabel)

        resonanceLabel.fontSize = 12
        resonanceLabel.fontColor = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        resonanceLabel.horizontalAlignmentMode = .right
        resonanceLabel.verticalAlignmentMode = .center
        root.addChild(resonanceLabel)

        goldLabel.fontSize = 13
        goldLabel.fontColor = SKColor(red: 0.90, green: 0.78, blue: 0.30, alpha: 1)
        goldLabel.horizontalAlignmentMode = .right
        goldLabel.verticalAlignmentMode = .center
        root.addChild(goldLabel)

        questLabel.fontSize = 11
        questLabel.fontColor = SKColor(red: 0.65, green: 0.80, blue: 0.65, alpha: 1)
        questLabel.horizontalAlignmentMode = .left
        questLabel.verticalAlignmentMode = .center
        questLabel.isHidden = true
        root.addChild(questLabel)

        interactionHintLabel.fontSize = 13
        interactionHintLabel.fontColor = SKColor(red: 0.96, green: 0.88, blue: 0.54, alpha: 0.95)
        interactionHintLabel.horizontalAlignmentMode = .center
        interactionHintLabel.verticalAlignmentMode = .center
        interactionHintLabel.isHidden = true
        root.addChild(interactionHintLabel)
        JuiceEngine.pulse(interactionHintLabel, scale: 1.05)

        hpLabel.fontSize = 12
        hpLabel.fontColor = SKColor(red: 0.50, green: 0.90, blue: 0.60, alpha: 1)
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.verticalAlignmentMode = .center
        root.addChild(hpLabel)

        levelLabel.fontSize = 13
        levelLabel.fontColor = SKColor(red: 0.85, green: 0.70, blue: 1, alpha: 1)
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.verticalAlignmentMode = .center
        root.addChild(levelLabel)

        xpLabel.fontSize = 10
        xpLabel.fontColor = SKColor(white: 0.68, alpha: 1)
        xpLabel.horizontalAlignmentMode = .left
        xpLabel.verticalAlignmentMode = .center
        root.addChild(xpLabel)

        let xpRect = CGRect(x: -xpBarWidth / 2, y: -xpBarHeight / 2,
                             width: xpBarWidth, height: xpBarHeight)
        // Barre rectangulaire nette : pas de bouts arrondis en pixel art.
        let xpPath = CGPath(rect: xpRect, transform: nil)
        xpBarBack.path = xpPath
        xpBarBack.fillColor = SKColor(white: 0.10, alpha: 1)
        xpBarBack.strokeColor = SKColor(white: 0.45, alpha: 0.45)
        xpBarBack.lineWidth = 1
        root.addChild(xpBarBack)

        xpBarFill.path = xpPath
        xpBarFill.fillColor = SKColor(red: 0.55, green: 0.80, blue: 1, alpha: 1)
        xpBarFill.strokeColor = .clear
        xpBarFill.xScale = 0.02
        root.addChild(xpBarFill)

        setupInventoryButton()
        setupPauseButton()
        setupLoreButton()
        setupQuestLogButton()

        // Ombres portées de tous les labels (lisibilité sans plaques)
        for label in [objectiveLabel, resonanceLabel, goldLabel, questLabel,
                      interactionHintLabel, hpLabel, levelLabel, xpLabel] {
            addShadow(for: label)
        }

        scene.addChild(root)
        layout(in: scene.size)
    }

    private func addShadow(for label: SKLabelNode) {
        let shadow = SKLabelNode(fontNamed: PixelUI.uiFont)
        shadow.fontColor = SKColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 0.92)
        shadow.zPosition = -0.5
        root.addChild(shadow)
        shadowPairs.append((label, shadow))
    }

    /// Synchronise texte/position/visibilité des ombres avec leurs labels.
    private func refreshShadows() {
        for (main, shadow) in shadowPairs {
            shadow.text = main.text
            shadow.fontSize = main.fontSize
            shadow.horizontalAlignmentMode = main.horizontalAlignmentMode
            shadow.verticalAlignmentMode = main.verticalAlignmentMode
            shadow.position = CGPoint(x: main.position.x + 1.5,
                                      y: main.position.y - 1.5)
            shadow.isHidden = main.isHidden
        }
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        let local = root.convert(point, from: scene)
        if inventoryButton.contains(local) {
            onInventoryTap?()
            return true
        }
        if pauseButton.contains(local) {
            onPauseTap?()
            return true
        }
        if loreButton.contains(local) {
            onLoreTap?()
            return true
        }
        if questLogButton.contains(local) {
            onQuestLogTap?()
            return true
        }
        return false
    }

    func layout(in size: CGSize, safeTop: CGFloat = 0, safeLeft: CGFloat = 0, safeRight: CGFloat = 0) {
        let s: CGFloat = size.width > 500 ? min(size.width, size.height) / 390 : 1.0
        let margin: CGFloat = 16 * s
        let leftEdge = safeLeft + margin
        let rightEdge = size.width - safeRight - margin
        let topY = size.height - safeTop - 26 * s
        // Accessibilité « gros texte » : agrandit uniquement les polices.
        let f = s * AccessibilitySettings.textScale

        objectiveLabel.fontSize = 13 * f
        resonanceLabel.fontSize = 12 * f
        goldLabel.fontSize = 13 * f
        questLabel.fontSize = 11 * f
        interactionHintLabel.fontSize = 13 * f
        hpLabel.fontSize = 12 * f
        levelLabel.fontSize = 12 * f
        xpLabel.fontSize = 9 * f

        objectiveLabel.position = CGPoint(x: leftEdge + 2 * s, y: topY - 5 * s)
        questLabel.position = CGPoint(x: leftEdge + 2 * s, y: topY - 24 * s)

        resonanceLabel.position = CGPoint(x: rightEdge - 2 * s, y: topY - 2 * s)
        goldLabel.position = CGPoint(x: rightEdge - 2 * s, y: topY - 21 * s)

        let statsX = leftEdge + 2 * s
        hpLabel.position = CGPoint(x: statsX, y: topY - 52 * s)
        levelLabel.position = CGPoint(x: statsX, y: topY - 70 * s)
        let barX = statsX + 44 * s + xpBarWidth / 2
        xpBarBack.position = CGPoint(x: barX, y: topY - 69 * s)
        xpBarFill.position = xpBarBack.position
        xpLabel.position = CGPoint(x: statsX + 44 * s, y: topY - 84 * s)

        let buttonSize = 46 * s
        setButton(pauseButton, size: buttonSize)
        pauseButton.position = CGPoint(x: leftEdge + buttonSize / 2, y: topY - 122 * s)
        setButton(inventoryButton, size: buttonSize)
        inventoryButton.position = CGPoint(x: rightEdge - buttonSize / 2, y: topY - 68 * s)
        setButton(loreButton, size: buttonSize)
        loreButton.position = CGPoint(x: rightEdge - buttonSize / 2, y: topY - 122 * s)
        setButton(questLogButton, size: buttonSize)
        questLogButton.position = CGPoint(x: leftEdge + buttonSize / 2, y: topY - 176 * s)

        interactionHintLabel.position = CGPoint(x: size.width / 2,
                                                y: size.height * 0.19)
        refreshShadows()
    }

    // MARK: - Private

    private func setButton(_ node: SKShapeNode, size: CGFloat) {
        let rect = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        node.path = CGPath(rect: rect, transform: nil)
    }

    private func setupPauseButton() {
        styleButton(pauseButton)
        for x in [-5.0, 5.0] {
            let bar = SKShapeNode(rectOf: CGSize(width: 4, height: 18))
            bar.fillColor = SKColor(red: 0.92, green: 0.86, blue: 1, alpha: 1)
            bar.strokeColor = .clear
            bar.position = CGPoint(x: x, y: 0)
            pauseButton.addChild(bar)
        }
        root.addChild(pauseButton)
    }

    private func setupInventoryButton() {
        styleButton(inventoryButton)
        let pack = SKShapeNode(rectOf: CGSize(width: 20, height: 20))
        pack.fillColor = SKColor(red: 0.42, green: 0.28, blue: 0.14, alpha: 1)
        pack.strokeColor = SKColor(red: 0.90, green: 0.72, blue: 0.38, alpha: 0.9)
        pack.lineWidth = 1.4
        pack.glowWidth = 0
        inventoryButton.addChild(pack)

        let flap = SKShapeNode(rectOf: CGSize(width: 14, height: 5))
        flap.fillColor = SKColor(red: 0.25, green: 0.16, blue: 0.08, alpha: 1)
        flap.strokeColor = .clear
        flap.position = CGPoint(x: 0, y: 3)
        inventoryButton.addChild(flap)

        // Anse carrée (pas d'ellipse en pixel art)
        let handle = SKShapeNode(rectOf: CGSize(width: 12, height: 6))
        handle.fillColor = .clear
        handle.strokeColor = SKColor(red: 0.90, green: 0.72, blue: 0.38, alpha: 0.85)
        handle.lineWidth = 1.3
        handle.glowWidth = 0
        handle.position = CGPoint(x: 0, y: 12)
        inventoryButton.addChild(handle)

        root.addChild(inventoryButton)
    }

    private func setupLoreButton() {
        styleButton(loreButton)
        // Icône livre : couverture + tranche + ligne de reliure
        let cover = SKShapeNode(rectOf: CGSize(width: 20, height: 22))
        cover.fillColor = SKColor(red: 0.16, green: 0.20, blue: 0.34, alpha: 1)
        cover.strokeColor = SKColor(red: 0.55, green: 0.72, blue: 1.0, alpha: 0.9)
        cover.lineWidth = 1.4
        cover.glowWidth = 0
        loreButton.addChild(cover)

        let spine = SKShapeNode(rectOf: CGSize(width: 3, height: 22))
        spine.fillColor = SKColor(red: 0.55, green: 0.72, blue: 1.0, alpha: 0.9)
        spine.strokeColor = .clear
        spine.position = CGPoint(x: -8.5, y: 0)
        loreButton.addChild(spine)

        for dy in [-4.0, 0.0, 4.0] {
            let line = SKShapeNode(rectOf: CGSize(width: 11, height: 1.4))
            line.fillColor = SKColor(red: 0.70, green: 0.82, blue: 1.0, alpha: 0.65)
            line.strokeColor = .clear
            line.position = CGPoint(x: 1, y: dy)
            loreButton.addChild(line)
        }
        root.addChild(loreButton)
    }

    private func setupQuestLogButton() {
        styleButton(questLogButton)
        // Icône parchemin : rouleau doré + lignes de texte + « ! »
        let scroll = SKShapeNode(rectOf: CGSize(width: 18, height: 22))
        scroll.fillColor = SKColor(red: 0.28, green: 0.22, blue: 0.12, alpha: 1)
        scroll.strokeColor = PixelUI.gold.withAlphaComponent(0.9)
        scroll.lineWidth = 1.4
        scroll.glowWidth = 0
        questLogButton.addChild(scroll)

        for dy in [4.0, 0.0, -4.0] {
            let line = SKShapeNode(rectOf: CGSize(width: 11, height: 1.4))
            line.fillColor = PixelUI.gold.withAlphaComponent(0.7)
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: dy)
            questLogButton.addChild(line)
        }
        // Rouleaux haut/bas
        for dy in [11.0, -11.0] {
            let roll = SKShapeNode(rectOf: CGSize(width: 20, height: 3))
            roll.fillColor = PixelUI.gold
            roll.strokeColor = .clear
            roll.position = CGPoint(x: 0, y: dy)
            questLogButton.addChild(roll)
        }
        root.addChild(questLogButton)
    }

    private func styleButton(_ button: SKShapeNode) {
        button.fillColor = SKColor(red: 0.07, green: 0.06, blue: 0.07, alpha: 0.88)
        button.strokeColor = PixelUI.goldDim
        button.lineWidth = 1.5
        button.glowWidth = 0
    }
}
