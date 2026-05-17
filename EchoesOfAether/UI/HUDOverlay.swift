import SpriteKit

@MainActor
final class HUDOverlay {
    private let root = SKNode()
    private let objectiveLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let resonanceLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let goldLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let questLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    let inventoryButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44), cornerRadius: 10)

    var onInventoryTap: (() -> Void)?

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

        setupInventoryButton()

        scene.addChild(root)
        layout(in: scene.size)
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        let local = root.convert(point, from: scene)
        if inventoryButton.contains(local) {
            onInventoryTap?()
            return true
        }
        return false
    }

    func layout(in size: CGSize, safeTop: CGFloat = 0) {
        let topY = size.height - 48 - safeTop
        objectiveLabel.position = CGPoint(x: 20, y: topY)
        resonanceLabel.position = CGPoint(x: size.width - 20, y: topY)
        goldLabel.position = CGPoint(x: size.width - 20, y: topY - 20)
        questLabel.position = CGPoint(x: 20, y: topY - 20)
        inventoryButton.position = CGPoint(x: size.width - 36, y: topY - 52)
    }

    // MARK: - Private

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
