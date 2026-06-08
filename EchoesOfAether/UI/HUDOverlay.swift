import SpriteKit

@MainActor
final class HUDOverlay {
    private let root = SKNode()
    private let objectivePlate = SKShapeNode()
    private let resourcePlate = SKShapeNode()
    private let statsPlate = SKShapeNode()
    private let interactionPlate = SKShapeNode()
    private let objectiveLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let resonanceLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let goldLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let questLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let interactionHintLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let hpLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let levelLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let xpLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let xpBarBack = SKShapeNode()
    private let xpBarFill = SKShapeNode()
    private let xpBarWidth: CGFloat = 88
    private let xpBarHeight: CGFloat = 4
    let inventoryButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44), cornerRadius: 10)
    let pauseButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44), cornerRadius: 10)
    let loreButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44), cornerRadius: 10)

    var onInventoryTap: (() -> Void)?
    var onPauseTap: (() -> Void)?
    var onLoreTap: (() -> Void)?

    var objectiveText: String = "" {
        didSet { objectiveLabel.text = objectiveText }
    }

    var resonanceValue: Int = 0 {
        didSet { resonanceLabel.text = String(localized: "hud.resonance \(resonanceValue)") }
    }

    var goldValue: Int = 0 {
        didSet { goldLabel.text = String(localized: "hud.gold \(goldValue)") }
    }

    var questText: String = "" {
        didSet {
            questLabel.text = questText
            questLabel.isHidden = questText.isEmpty
        }
    }

    var interactionHint: String = "" {
        didSet {
            interactionHintLabel.text = interactionHint
            let hidden = interactionHint.isEmpty
            interactionHintLabel.isHidden = hidden
            interactionPlate.isHidden = hidden
        }
    }

    var hpValue: String = "" {
        didSet { hpLabel.text = hpValue }
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
    }

    func attach(to scene: SKScene) {
        root.zPosition = 100

        [objectivePlate, resourcePlate, statsPlate, interactionPlate].forEach {
            configurePlate($0)
            root.addChild($0)
        }
        interactionPlate.isHidden = true

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
        let xpPath = CGPath(roundedRect: xpRect,
                             cornerWidth: xpBarHeight / 2,
                             cornerHeight: xpBarHeight / 2, transform: nil)
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

        scene.addChild(root)
        layout(in: scene.size)
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

        let objectiveWidth = min(size.width * 0.58, 250 * s)
        setPlate(objectivePlate, size: CGSize(width: objectiveWidth, height: 42 * s), radius: 8 * s)
        objectivePlate.position = CGPoint(x: leftEdge + objectiveWidth / 2, y: topY - 10 * s)
        objectiveLabel.position = CGPoint(x: leftEdge + 13 * s, y: topY - 5 * s)
        questLabel.position = CGPoint(x: leftEdge + 13 * s, y: topY - 24 * s)

        let resourceWidth = min(132 * s, size.width * 0.32)
        setPlate(resourcePlate, size: CGSize(width: resourceWidth, height: 44 * s), radius: 8 * s)
        resourcePlate.position = CGPoint(x: rightEdge - resourceWidth / 2, y: topY - 10 * s)
        resonanceLabel.position = CGPoint(x: rightEdge - 12 * s, y: topY - 2 * s)
        goldLabel.position = CGPoint(x: rightEdge - 12 * s, y: topY - 21 * s)

        let statsWidth = min(178 * s, size.width * 0.48)
        setPlate(statsPlate, size: CGSize(width: statsWidth, height: 50 * s), radius: 8 * s)
        statsPlate.position = CGPoint(x: leftEdge + statsWidth / 2, y: topY - 68 * s)
        let statsX = leftEdge + 14 * s
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

        let promptWidth = min(size.width - 48 * s, 300 * s)
        setPlate(interactionPlate, size: CGSize(width: promptWidth, height: 34 * s), radius: 8 * s)
        interactionPlate.position = CGPoint(x: size.width / 2, y: size.height * 0.19)
        interactionHintLabel.position = interactionPlate.position
    }

    // MARK: - Private

    private func configurePlate(_ node: SKShapeNode) {
        node.fillColor = SKColor(red: 0.055, green: 0.045, blue: 0.07, alpha: 0.78)
        node.strokeColor = SKColor(red: 0.55, green: 0.43, blue: 0.75, alpha: 0.42)
        node.lineWidth = 1.2
        node.glowWidth = 1.2
        node.zPosition = -1
    }

    private func setPlate(_ node: SKShapeNode, size: CGSize, radius: CGFloat) {
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2,
                          width: size.width, height: size.height)
        node.path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    private func setButton(_ node: SKShapeNode, size: CGFloat) {
        let rect = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        node.path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
    }

    private func setupPauseButton() {
        styleButton(pauseButton)
        for x in [-5.0, 5.0] {
            let bar = SKShapeNode(rectOf: CGSize(width: 4, height: 18), cornerRadius: 1)
            bar.fillColor = SKColor(red: 0.92, green: 0.86, blue: 1, alpha: 1)
            bar.strokeColor = .clear
            bar.position = CGPoint(x: x, y: 0)
            pauseButton.addChild(bar)
        }
        root.addChild(pauseButton)
    }

    private func setupInventoryButton() {
        styleButton(inventoryButton)
        let pack = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 5)
        pack.fillColor = SKColor(red: 0.42, green: 0.28, blue: 0.14, alpha: 1)
        pack.strokeColor = SKColor(red: 0.90, green: 0.72, blue: 0.38, alpha: 0.9)
        pack.lineWidth = 1.4
        inventoryButton.addChild(pack)

        let flap = SKShapeNode(rectOf: CGSize(width: 14, height: 5), cornerRadius: 2)
        flap.fillColor = SKColor(red: 0.25, green: 0.16, blue: 0.08, alpha: 1)
        flap.strokeColor = .clear
        flap.position = CGPoint(x: 0, y: 3)
        inventoryButton.addChild(flap)

        let handle = SKShapeNode(ellipseOf: CGSize(width: 12, height: 7))
        handle.fillColor = .clear
        handle.strokeColor = SKColor(red: 0.90, green: 0.72, blue: 0.38, alpha: 0.85)
        handle.lineWidth = 1.3
        handle.position = CGPoint(x: 0, y: 12)
        inventoryButton.addChild(handle)

        root.addChild(inventoryButton)
    }

    private func setupLoreButton() {
        styleButton(loreButton)
        // Icône livre : couverture + tranche + ligne de reliure
        let cover = SKShapeNode(rectOf: CGSize(width: 20, height: 22), cornerRadius: 3)
        cover.fillColor = SKColor(red: 0.16, green: 0.20, blue: 0.34, alpha: 1)
        cover.strokeColor = SKColor(red: 0.55, green: 0.72, blue: 1.0, alpha: 0.9)
        cover.lineWidth = 1.4
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

    private func styleButton(_ button: SKShapeNode) {
        button.fillColor = SKColor(red: 0.08, green: 0.06, blue: 0.11, alpha: 0.88)
        button.strokeColor = SKColor(red: 0.62, green: 0.50, blue: 0.85, alpha: 0.75)
        button.lineWidth = 1.5
        button.glowWidth = 1
    }
}
