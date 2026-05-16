import SpriteKit

@MainActor
final class WorldBuilder {
    let kael: SKNode
    let lyra: SKNode
    let dorin: SKNode

    private var backdropNodes: [SKNode] = []
    private var atmosphereNode: SKNode?

    init() {
        kael = WorldNode.kael()
        lyra = WorldNode.lyra()
        dorin = WorldNode.dorin()
    }

    func build(in scene: SKScene) {
        buildVillage(in: scene)
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

    // MARK: - Zone Backgrounds

    func switchToForest(in scene: SKScene) {
        clearBackdrop()
        lyra.isHidden = true
        dorin.isHidden = true
        scene.backgroundColor = SKColor(red: 0.03, green: 0.06, blue: 0.04, alpha: 1)
        buildForest(in: scene)
    }

    func switchToShrine(in scene: SKScene) {
        clearBackdrop()
        scene.backgroundColor = SKColor(red: 0.03, green: 0.02, blue: 0.07, alpha: 1)
        buildShrine(in: scene)
    }

    // MARK: - Village

    private func buildVillage(in scene: SKScene) {
        let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
        ground.fillColor = SKColor(red: 0.08, green: 0.10, blue: 0.11, alpha: 1)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: 500, y: 500)
        ground.zPosition = -10
        scene.addChild(ground)
        backdropNodes.append(ground)

        let hut1 = makeHut(width: 60, height: 40, roofColor: SKColor(red: 0.35, green: 0.18, blue: 0.10, alpha: 1))
        hut1.position = CGPoint(x: scene.size.width * 0.52, y: scene.size.height * 0.72)
        scene.addChild(hut1)
        backdropNodes.append(hut1)

        let hut2 = makeHut(width: 50, height: 34, roofColor: SKColor(red: 0.28, green: 0.22, blue: 0.12, alpha: 1))
        hut2.position = CGPoint(x: scene.size.width * 0.82, y: scene.size.height * 0.65)
        scene.addChild(hut2)
        backdropNodes.append(hut2)

        let hut3 = makeHut(width: 44, height: 30, roofColor: SKColor(red: 0.30, green: 0.15, blue: 0.08, alpha: 1))
        hut3.position = CGPoint(x: scene.size.width * 0.25, y: scene.size.height * 0.75)
        scene.addChild(hut3)
        backdropNodes.append(hut3)

        for i in 0..<6 {
            let torch = makeTorch()
            torch.position = CGPoint(
                x: CGFloat(60 + i * 110 + (i % 2) * 30),
                y: scene.size.height * 0.60 + CGFloat(i % 3) * 25
            )
            scene.addChild(torch)
            backdropNodes.append(torch)
        }

        for i in 0..<12 {
            let radius = CGFloat(18 + (i % 4) * 6)
            let stone = SKShapeNode(circleOfRadius: radius)
            stone.fillColor = SKColor(white: 0.10 + CGFloat(i % 3) * 0.02, alpha: 1)
            stone.strokeColor = .clear
            stone.position = CGPoint(
                x: CGFloat(50 + i * 80),
                y: CGFloat(70 + (i * 97) % 280)
            )
            stone.zPosition = -5
            scene.addChild(stone)
            backdropNodes.append(stone)
        }

        addAtmosphere(ParticleFactory.ambientDust(in: scene.size), to: scene)
    }

    // MARK: - Forest

    private func buildForest(in scene: SKScene) {
        let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
        ground.fillColor = SKColor(red: 0.04, green: 0.07, blue: 0.05, alpha: 1)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: 500, y: 500)
        ground.zPosition = -10
        scene.addChild(ground)
        backdropNodes.append(ground)

        for i in 0..<8 {
            let tree = makeTree(height: CGFloat.random(in: 80...140))
            tree.position = CGPoint(
                x: CGFloat(30 + i * 85 + Int.random(in: -15...15)),
                y: scene.size.height * 0.68 + CGFloat.random(in: -30...30)
            )
            scene.addChild(tree)
            backdropNodes.append(tree)
        }

        for i in 0..<5 {
            let tree = makeTree(height: CGFloat.random(in: 60...100))
            tree.position = CGPoint(
                x: CGFloat(60 + i * 120),
                y: scene.size.height * 0.30 + CGFloat.random(in: -20...20)
            )
            tree.alpha = 0.4
            tree.zPosition = -3
            scene.addChild(tree)
            backdropNodes.append(tree)
        }

        for i in 0..<6 {
            let root = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 30...60), height: 3), cornerRadius: 1)
            root.fillColor = SKColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 0.5)
            root.strokeColor = .clear
            root.position = CGPoint(x: CGFloat(50 + i * 100), y: scene.size.height * 0.38)
            root.zPosition = -4
            scene.addChild(root)
            backdropNodes.append(root)
        }

        addAtmosphere(ParticleFactory.forestFog(in: scene.size), to: scene)
    }

    // MARK: - Shrine

    private func buildShrine(in scene: SKScene) {
        let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
        ground.fillColor = SKColor(red: 0.04, green: 0.03, blue: 0.08, alpha: 1)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: 500, y: 500)
        ground.zPosition = -10
        scene.addChild(ground)
        backdropNodes.append(ground)

        let altar = SKShapeNode(rectOf: CGSize(width: 80, height: 50), cornerRadius: 6)
        altar.fillColor = SKColor(red: 0.12, green: 0.08, blue: 0.18, alpha: 1)
        altar.strokeColor = SKColor(red: 0.50, green: 0.30, blue: 0.80, alpha: 0.6)
        altar.lineWidth = 2
        altar.position = CGPoint(x: scene.size.width * 0.70, y: scene.size.height * 0.55)
        altar.zPosition = -2
        scene.addChild(altar)
        backdropNodes.append(altar)

        let altarGlow = SKShapeNode(circleOfRadius: 50)
        altarGlow.fillColor = SKColor(red: 0.30, green: 0.10, blue: 0.50, alpha: 0.08)
        altarGlow.strokeColor = .clear
        altarGlow.position = altar.position
        altarGlow.zPosition = -3
        scene.addChild(altarGlow)
        backdropNodes.append(altarGlow)
        JuiceEngine.pulse(altarGlow, scale: 1.3)

        for i in 0..<4 {
            let pillar = SKShapeNode(rectOf: CGSize(width: 10, height: 70), cornerRadius: 3)
            pillar.fillColor = SKColor(red: 0.15, green: 0.10, blue: 0.22, alpha: 1)
            pillar.strokeColor = SKColor(red: 0.45, green: 0.25, blue: 0.70, alpha: 0.4)
            pillar.lineWidth = 1
            let px = scene.size.width * 0.3 + CGFloat(i) * scene.size.width * 0.15
            pillar.position = CGPoint(x: px, y: scene.size.height * 0.60)
            pillar.zPosition = -4
            scene.addChild(pillar)
            backdropNodes.append(pillar)

            let orb = SKShapeNode(circleOfRadius: 4)
            orb.fillColor = SKColor(red: 0.55, green: 0.30, blue: 0.90, alpha: 0.8)
            orb.strokeColor = .clear
            orb.glowWidth = 4
            orb.position = CGPoint(x: px, y: scene.size.height * 0.60 + 40)
            orb.zPosition = -3
            scene.addChild(orb)
            backdropNodes.append(orb)
            JuiceEngine.pulse(orb, scale: 1.5)
        }

        addAtmosphere(ParticleFactory.shrineAura(in: scene.size), to: scene)
    }

    // MARK: - Building Blocks

    private func makeHut(width: CGFloat, height: CGFloat, roofColor: SKColor) -> SKNode {
        let hut = SKNode()
        hut.zPosition = -4

        let wall = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 4)
        wall.fillColor = SKColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 1)
        wall.strokeColor = SKColor(white: 0.22, alpha: 0.5)
        wall.lineWidth = 1
        hut.addChild(wall)

        let roof = SKShapeNode(rectOf: CGSize(width: width + 10, height: 12), cornerRadius: 3)
        roof.fillColor = roofColor
        roof.strokeColor = .clear
        roof.position = CGPoint(x: 0, y: height / 2 + 4)
        hut.addChild(roof)

        let door = SKShapeNode(rectOf: CGSize(width: 10, height: 16), cornerRadius: 2)
        door.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1)
        door.strokeColor = .clear
        door.position = CGPoint(x: 0, y: -height / 2 + 8)
        hut.addChild(door)

        return hut
    }

    private func makeTorch() -> SKNode {
        let torch = SKNode()
        torch.zPosition = -3

        let pole = SKShapeNode(rectOf: CGSize(width: 3, height: 28), cornerRadius: 1)
        pole.fillColor = SKColor(red: 0.30, green: 0.20, blue: 0.10, alpha: 1)
        pole.strokeColor = .clear
        torch.addChild(pole)

        let flame = SKShapeNode(circleOfRadius: 5)
        flame.fillColor = SKColor(red: 0.90, green: 0.55, blue: 0.15, alpha: 0.9)
        flame.strokeColor = .clear
        flame.glowWidth = 6
        flame.position = CGPoint(x: 0, y: 18)
        torch.addChild(flame)
        JuiceEngine.pulse(flame, scale: 1.4)

        let glow = SKShapeNode(circleOfRadius: 30)
        glow.fillColor = SKColor(red: 0.80, green: 0.50, blue: 0.15, alpha: 0.04)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: 18)
        torch.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.2)

        return torch
    }

    private func makeTree(height: CGFloat) -> SKNode {
        let tree = SKNode()
        tree.zPosition = -4

        let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: height * 0.4), cornerRadius: 2)
        trunk.fillColor = SKColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 1)
        trunk.strokeColor = .clear
        tree.addChild(trunk)

        let foliageColors: [SKColor] = [
            SKColor(red: 0.08, green: 0.20, blue: 0.10, alpha: 1),
            SKColor(red: 0.06, green: 0.18, blue: 0.08, alpha: 1),
            SKColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 1)
        ]

        for i in 0..<3 {
            let radius = CGFloat(18 - i * 4)
            let leaf = SKShapeNode(circleOfRadius: radius)
            leaf.fillColor = foliageColors[i]
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: 0, y: height * 0.2 + CGFloat(i) * 14)
            tree.addChild(leaf)
        }

        return tree
    }

    // MARK: - Helpers

    private func clearBackdrop() {
        backdropNodes.forEach { $0.removeFromParent() }
        backdropNodes.removeAll()
        atmosphereNode?.removeFromParent()
        atmosphereNode = nil
    }

    private func addAtmosphere(_ node: SKNode, to scene: SKScene) {
        atmosphereNode?.removeFromParent()
        atmosphereNode = node
        scene.addChild(node)
    }
}
