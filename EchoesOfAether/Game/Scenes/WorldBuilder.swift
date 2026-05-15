import SpriteKit

@MainActor
final class WorldBuilder {
    let kael: SKShapeNode
    let lyra: SKShapeNode
    let dorin: SKShapeNode

    init() {
        kael = WorldNode.kael()
        lyra = WorldNode.lyra()
        dorin = WorldNode.dorin()
    }

    func build(in scene: SKScene) {
        addBackdrop(to: scene)
        scene.addChild(kael)
        scene.addChild(lyra)
        scene.addChild(dorin)
        layout(in: scene.size)
    }

    func layout(in size: CGSize) {
        kael.position = CGPoint(x: size.width * 0.18, y: size.height * 0.44)
        lyra.position = CGPoint(x: size.width * 0.34, y: size.height * 0.52)
        dorin.position = CGPoint(x: size.width * 0.68, y: size.height * 0.52)
    }

    private func addBackdrop(to scene: SKScene) {
        let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
        ground.fillColor = SKColor(red: 0.08, green: 0.12, blue: 0.13, alpha: 1)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: 500, y: 500)
        ground.zPosition = -10
        scene.addChild(ground)

        for index in 0..<18 {
            let radius = CGFloat(22 + (index % 4) * 8)
            let stone = SKShapeNode(circleOfRadius: radius)
            stone.fillColor = SKColor(white: 0.12 + CGFloat(index % 3) * 0.02, alpha: 1)
            stone.strokeColor = .clear
            stone.position = CGPoint(
                x: CGFloat(60 + index * 73),
                y: CGFloat(90 + (index * 97) % 360)
            )
            stone.zPosition = -5
            scene.addChild(stone)
        }
    }
}
