import SpriteKit

@MainActor
final class HUDOverlay {
    let root = SKNode()
    // Lisibilité sans plaques : chaque label a une ombre portée dure
    // (décalage 1.5 px, noir) — fini les gros rectangles sombres.
    private var shadowPairs: [(main: SKLabelNode, shadow: SKLabelNode)] = []
    let objectiveLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let resonanceLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let goldLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let questLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let interactionHintLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let hpLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let levelLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let xpLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let xpBarBack = SKShapeNode()
    let xpBarFill = SKShapeNode()
    let xpBarWidth: CGFloat = 88
    private let xpBarHeight: CGFloat = 4
    let inventoryButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44))
    let pauseButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44))
    let loreButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44))
    let questLogButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44))
    let mapButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44))

    var onInventoryTap: (() -> Void)?
    var onPauseTap: (() -> Void)?
    var onLoreTap: (() -> Void)?
    var onQuestLogTap: (() -> Void)?
    var onMapTap: (() -> Void)?

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
        resonanceLabel.fontColor = Palette.aether
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
        setupMapButton()

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
    func refreshShadows() {
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

    /// Le point tombe-t-il sur un bouton VISIBLE du HUD ?
    ///
    /// Le joystick flottant capture tout le quart bas-gauche de l'écran, et la
    /// colonne de boutons du HUD descend dans ce quart (le journal de quêtes
    /// est le plus bas) : sans ce test préalable, poser le doigt sur l'icône
    /// faisait apparaître le joystick au lieu d'ouvrir le journal.
}
