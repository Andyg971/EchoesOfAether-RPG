import SpriteKit

@MainActor
final class HUDOverlay {
    private let root = SKNode()
    private let objectiveLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let resonanceLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")

    var objectiveText: String = "" {
        didSet { objectiveLabel.text = objectiveText }
    }

    var resonanceValue: Int = 0 {
        didSet { resonanceLabel.text = "Résonance noire: \(resonanceValue)" }
    }

    func attach(to scene: SKScene) {
        root.zPosition = 100

        objectiveLabel.fontSize = 14
        objectiveLabel.fontColor = .white
        objectiveLabel.horizontalAlignmentMode = .left
        root.addChild(objectiveLabel)

        resonanceLabel.fontSize = 13
        resonanceLabel.fontColor = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        resonanceLabel.horizontalAlignmentMode = .right
        root.addChild(resonanceLabel)

        scene.addChild(root)
        layout(in: scene.size)
    }

    func layout(in size: CGSize, safeTop: CGFloat = 0) {
        let topY = size.height - 48 - safeTop
        objectiveLabel.position = CGPoint(x: 24, y: topY)
        resonanceLabel.position = CGPoint(x: size.width - 24, y: topY)
    }
}
