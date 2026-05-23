import SpriteKit

@MainActor
final class HUDOverlay {
    private let root = SKNode()
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

    var onInventoryTap: (() -> Void)?
    var onPauseTap: (() -> Void)?

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
            interactionHintLabel.isHidden = interactionHint.isEmpty
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

        objectiveLabel.fontSize = 13
        objectiveLabel.fontColor = .white
        objectiveLabel.horizontalAlignmentMode = .left
        root.addChild(objectiveLabel)

        resonanceLabel.fontSize = 12
        resonanceLabel.fontColor = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        resonanceLabel.horizontalAlignmentMode = .right
        root.addChild(resonanceLabel)

        goldLabel.fontSize = 13
        goldLabel.fontColor = SKColor(red: 0.90, green: 0.78, blue: 0.30, alpha: 1)
        goldLabel.horizontalAlignmentMode = .right
        root.addChild(goldLabel)

        questLabel.fontSize = 11
        questLabel.fontColor = SKColor(red: 0.65, green: 0.80, blue: 0.65, alpha: 1)
        questLabel.horizontalAlignmentMode = .left
        questLabel.isHidden = true
        root.addChild(questLabel)

        interactionHintLabel.fontSize = 13
        interactionHintLabel.fontColor = SKColor(red: 0.90, green: 0.85, blue: 0.55, alpha: 0.9)
        interactionHintLabel.horizontalAlignmentMode = .center
        interactionHintLabel.isHidden = true
        root.addChild(interactionHintLabel)
        JuiceEngine.pulse(interactionHintLabel, scale: 1.05)

        hpLabel.fontSize = 12
        hpLabel.fontColor = SKColor(red: 0.50, green: 0.90, blue: 0.60, alpha: 1)
        hpLabel.horizontalAlignmentMode = .left
        root.addChild(hpLabel)

        // Niveau + barre XP
        levelLabel.fontSize = 13
        levelLabel.fontColor = SKColor(red: 0.85, green: 0.70, blue: 1, alpha: 1)
        levelLabel.horizontalAlignmentMode = .left
        root.addChild(levelLabel)

        xpLabel.fontSize = 10
        xpLabel.fontColor = SKColor(white: 0.65, alpha: 1)
        xpLabel.horizontalAlignmentMode = .left
        root.addChild(xpLabel)

        let xpRect = CGRect(x: -xpBarWidth / 2, y: -xpBarHeight / 2,
                             width: xpBarWidth, height: xpBarHeight)
        let xpPath = CGPath(roundedRect: xpRect,
                             cornerWidth: xpBarHeight / 2,
                             cornerHeight: xpBarHeight / 2, transform: nil)
        xpBarBack.path = xpPath
        xpBarBack.fillColor = SKColor(white: 0.15, alpha: 1)
        xpBarBack.strokeColor = SKColor(white: 0.30, alpha: 0.6)
        xpBarBack.lineWidth = 1
        root.addChild(xpBarBack)

        xpBarFill.path = xpPath
        xpBarFill.fillColor = SKColor(red: 0.55, green: 0.80, blue: 1, alpha: 1)
        xpBarFill.strokeColor = .clear
        xpBarFill.xScale = 0.02
        root.addChild(xpBarFill)

        setupInventoryButton()
        setupPauseButton()

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
        return false
    }

    func layout(in size: CGSize, safeTop: CGFloat = 0) {
        // iPad : width > 500 → scale factor proportionnel
        let s: CGFloat = size.width > 500 ? min(size.width, size.height) / 390 : 1.0

        objectiveLabel.fontSize = 13 * s
        resonanceLabel.fontSize = 12 * s
        goldLabel.fontSize = 13 * s
        questLabel.fontSize = 11 * s
        interactionHintLabel.fontSize = 13 * s
        hpLabel.fontSize = 12 * s

        let margin: CGFloat = 20 * s
        let topY = size.height - 48 * s - safeTop

        objectiveLabel.position = CGPoint(x: margin, y: topY)
        resonanceLabel.position = CGPoint(x: size.width - margin, y: topY)
        goldLabel.position = CGPoint(x: size.width - margin, y: topY - 20 * s)
        questLabel.position = CGPoint(x: margin, y: topY - 20 * s)
        // Stats joueur décalées à droite des boutons (pause à x=36)
        // pour éviter la collision visuelle.
        let statsX = margin + 50 * s
        hpLabel.position = CGPoint(x: statsX, y: topY - 38 * s)

        // Niveau + barre XP sur une ligne compacte sous le HP
        levelLabel.fontSize = 12 * s
        xpLabel.fontSize = 9 * s
        let levelY = topY - 56 * s
        levelLabel.position = CGPoint(x: statsX, y: levelY)
        let barX = statsX + 42 * s + xpBarWidth / 2
        xpBarBack.position = CGPoint(x: barX, y: levelY + 4)
        xpBarFill.position = xpBarBack.position
        xpLabel.position = CGPoint(x: statsX + 42 * s, y: levelY - 11)

        inventoryButton.position = CGPoint(x: size.width - 36 * s, y: topY - 52 * s)
        pauseButton.position = CGPoint(x: 36 * s, y: topY - 38 * s)
        interactionHintLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
    }

    // MARK: - Private

    private func setupPauseButton() {
        pauseButton.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.16, alpha: 0.85)
        pauseButton.strokeColor = SKColor(red: 0.50, green: 0.40, blue: 0.80, alpha: 0.7)
        pauseButton.lineWidth = 1.5

        let icon = SKLabelNode(text: "⏸")
        icon.fontSize = 18
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        pauseButton.addChild(icon)
        root.addChild(pauseButton)
    }

    private func setupInventoryButton() {
        inventoryButton.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.16, alpha: 0.85)
        inventoryButton.strokeColor = SKColor(red: 0.50, green: 0.40, blue: 0.80, alpha: 0.7)
        inventoryButton.lineWidth = 1.5

        let icon = SKLabelNode(text: "🎒")
        icon.fontSize = 20
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        inventoryButton.addChild(icon)
        root.addChild(inventoryButton)
    }
}
