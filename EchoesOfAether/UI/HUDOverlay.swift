import SpriteKit

@MainActor
final class HUDOverlay {
    private let root = SKNode()
    private let objectiveLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let resonanceLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let goldLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let questLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")

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

        scene.addChild(root)
        layout(in: scene.size)
    }

    func layout(in size: CGSize, safeTop: CGFloat = 0) {
        let topY = size.height - 48 - safeTop
        objectiveLabel.position = CGPoint(x: 20, y: topY)
        resonanceLabel.position = CGPoint(x: size.width - 20, y: topY)
        goldLabel.position = CGPoint(x: size.width - 20, y: topY - 20)
        questLabel.position = CGPoint(x: 20, y: topY - 20)
    }
}
