import SpriteKit

enum WorldNode {
    static func kael() -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: 34, height: 44), cornerRadius: 8)
        node.fillColor = SKColor(red: 0.16, green: 0.16, blue: 0.20, alpha: 1)
        node.strokeColor = SKColor(red: 0.58, green: 0.52, blue: 0.94, alpha: 1)
        node.lineWidth = 3
        node.name = "kael"
        return node
    }

    static func lyra() -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: 20)
        node.fillColor = SKColor(red: 0.14, green: 0.55, blue: 0.43, alpha: 1)
        node.strokeColor = .white.withAlphaComponent(0.5)
        node.name = "lyra"
        return node
    }

    static func dorin() -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: 22)
        node.fillColor = SKColor(red: 0.72, green: 0.58, blue: 0.32, alpha: 1)
        node.strokeColor = .white.withAlphaComponent(0.5)
        node.name = "dorin"
        return node
    }
}
