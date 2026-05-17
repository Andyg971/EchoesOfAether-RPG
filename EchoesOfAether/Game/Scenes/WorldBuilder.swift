import SpriteKit

@MainActor
final class WorldBuilder {
    // Personnages principaux
    let kael: SKNode
    let lyra: SKNode
    let dorin: SKNode
    // PNJ village
    let bram: SKNode
    let mara: SKNode
    let garen: SKNode
    let sage: SKNode
    let child: SKNode
    let villager: SKNode

    private var backdropNodes: [SKNode] = []
    private var atmosphereNode: SKNode?

    init() {
        kael    = WorldNode.kael()
        lyra    = WorldNode.lyra()
        dorin   = WorldNode.dorin()
        bram    = WorldNode.bram()
        mara    = WorldNode.mara()
        garen   = WorldNode.garen()
        sage    = WorldNode.sage()
        child   = WorldNode.child()
        villager = WorldNode.scaredVillager()
    }

    func build(in scene: SKScene) {
        buildVillage(in: scene)
        for node in [kael, lyra, dorin, bram, mara, garen, sage, child, villager] {
            scene.addChild(node)
        }
        layout(in: scene.size)
    }

    func layout(in size: CGSize) {
        // Zone résidentielle (haut gauche)
        lyra.position    = CGPoint(x: size.width * 0.22, y: size.height * 0.58)
        dorin.position   = CGPoint(x: size.width * 0.78, y: size.height * 0.60)
        // Zone marché (centre)
        bram.position    = CGPoint(x: size.width * 0.55, y: size.height * 0.50)
        mara.position    = CGPoint(x: size.width * 0.35, y: size.height * 0.44)
        // Porte nord (haut)
        garen.position   = CGPoint(x: size.width * 0.50, y: size.height * 0.72)
        // Auberge (droite)
        sage.position    = CGPoint(x: size.width * 0.82, y: size.height * 0.44)
        // PNJ décoratifs
        child.position   = CGPoint(x: size.width * 0.42, y: size.height * 0.33)
        villager.position = CGPoint(x: size.width * 0.65, y: size.height * 0.36)
        // Kael démarre en bas à gauche
        kael.position    = CGPoint(x: size.width * 0.18, y: size.height * 0.35)
    }

    // MARK: - Zone Backgrounds

    func switchToForest(in scene: SKScene) {
        clearBackdrop()
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.06, blue: 0.04, alpha: 1)
        buildForest(in: scene)
    }

    func switchToShrine(in scene: SKScene) {
        clearBackdrop()
        scene.backgroundColor = SKColor(red: 0.03, green: 0.02, blue: 0.07, alpha: 1)
        buildShrine(in: scene)
    }

    // MARK: - Village Solis

    private func buildVillage(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
        ground.fillColor = SKColor(red: 0.08, green: 0.10, blue: 0.11, alpha: 1)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: 500, y: 500)
        ground.zPosition = -10
        add(ground, to: scene)

        // Chemin central (cobblestone)
        for i in 0..<6 {
            let stone = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 30...50),
                                                    height: CGFloat.random(in: 18...28)),
                                    cornerRadius: 4)
            stone.fillColor = SKColor(white: 0.13, alpha: 1)
            stone.strokeColor = SKColor(white: 0.18, alpha: 0.4)
            stone.lineWidth = 1
            stone.position = CGPoint(x: w * 0.48 + CGFloat(i % 3 - 1) * 35,
                                     y: h * 0.35 + CGFloat(i / 3) * 30)
            stone.zPosition = -3
            add(stone, to: scene)
        }

        // --- Bâtiments ---

        // Maison de Lyra (haut gauche)
        let lyraHouse = makeBuilding(w: 70, h: 55,
                                     wallColor: SKColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1),
                                     roofColor: SKColor(red: 0.30, green: 0.50, blue: 0.35, alpha: 1),
                                     label: nil)
        lyraHouse.position = CGPoint(x: w * 0.18, y: h * 0.68)
        lyraHouse.zPosition = -4
        add(lyraHouse, to: scene)

        // Maison de Dorin (haut droite, plus grande)
        let dorinHouse = makeBuilding(w: 90, h: 65,
                                      wallColor: SKColor(red: 0.25, green: 0.20, blue: 0.12, alpha: 1),
                                      roofColor: SKColor(red: 0.50, green: 0.40, blue: 0.18, alpha: 1),
                                      label: nil)
        dorinHouse.position = CGPoint(x: w * 0.78, y: h * 0.72)
        dorinHouse.zPosition = -4
        add(dorinHouse, to: scene)

        // Armurerie (centre, enseigne)
        let armory = makeBuilding(w: 76, h: 58,
                                   wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                                   roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                                   label: "⚔")
        armory.position = CGPoint(x: w * 0.55, y: h * 0.62)
        armory.zPosition = -4
        add(armory, to: scene)

        // Herboriste (gauche centre)
        let herbShop = makeBuilding(w: 62, h: 50,
                                     wallColor: SKColor(red: 0.14, green: 0.22, blue: 0.14, alpha: 1),
                                     roofColor: SKColor(red: 0.22, green: 0.40, blue: 0.22, alpha: 1),
                                     label: "🌿")
        herbShop.position = CGPoint(x: w * 0.30, y: h * 0.57)
        herbShop.zPosition = -4
        add(herbShop, to: scene)

        // Auberge (droite, plus large)
        let inn = makeBuilding(w: 88, h: 62,
                                wallColor: SKColor(red: 0.20, green: 0.14, blue: 0.10, alpha: 1),
                                roofColor: SKColor(red: 0.45, green: 0.25, blue: 0.12, alpha: 1),
                                label: "🏠")
        inn.position = CGPoint(x: w * 0.84, y: h * 0.55)
        inn.zPosition = -4
        add(inn, to: scene)

        // Porte nord (haut centre)
        buildNorthGate(at: CGPoint(x: w * 0.50, y: h * 0.80), width: 80, in: scene)

        // Torches
        let torchPositions: [CGPoint] = [
            CGPoint(x: w * 0.12, y: h * 0.55),
            CGPoint(x: w * 0.30, y: h * 0.70),
            CGPoint(x: w * 0.50, y: h * 0.65),
            CGPoint(x: w * 0.68, y: h * 0.65),
            CGPoint(x: w * 0.88, y: h * 0.62),
            CGPoint(x: w * 0.45, y: h * 0.78)
        ]
        for pos in torchPositions {
            let t = makeTorch()
            t.position = pos
            add(t, to: scene)
        }

        // Pierres décoratives
        for i in 0..<10 {
            let radius = CGFloat(12 + (i % 4) * 5)
            let stone = SKShapeNode(circleOfRadius: radius)
            stone.fillColor = SKColor(white: 0.10 + CGFloat(i % 3) * 0.02, alpha: 1)
            stone.strokeColor = .clear
            stone.position = CGPoint(x: CGFloat(30 + i * 65), y: CGFloat(60 + (i * 113) % 220))
            stone.zPosition = -5
            add(stone, to: scene)
        }

        // Puit au centre
        buildWell(at: CGPoint(x: w * 0.50, y: h * 0.42), in: scene)

        addAtmosphere(ParticleFactory.ambientDust(in: scene.size), to: scene)
    }

    // MARK: - Forêt d'Ébène

    private func buildForest(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol sombre
        let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
        ground.fillColor = SKColor(red: 0.04, green: 0.07, blue: 0.05, alpha: 1)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: 500, y: 500)
        ground.zPosition = -10
        add(ground, to: scene)

        // Sentier sinueux (pierres sombres du sud au nord)
        let pathPoints: [(CGFloat, CGFloat)] = [
            (0.48, 0.18), (0.45, 0.28), (0.42, 0.38),
            (0.38, 0.48), (0.35, 0.55), (0.40, 0.62),
            (0.50, 0.68), (0.58, 0.74), (0.62, 0.80)
        ]
        for (px, py) in pathPoints {
            let stone = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 22...36),
                                                    height: CGFloat.random(in: 12...20)),
                                    cornerRadius: 3)
            stone.fillColor = SKColor(red: 0.07, green: 0.09, blue: 0.06, alpha: 1)
            stone.strokeColor = SKColor(white: 0.12, alpha: 0.3)
            stone.lineWidth = 1
            stone.position = CGPoint(x: w * px, y: h * py)
            stone.zPosition = -8
            add(stone, to: scene)
        }

        // --- Arbres normaux (bordures) ---
        for i in 0..<10 {
            let tree = makeTree(height: CGFloat.random(in: 90...150))
            let side: CGFloat = i < 5 ? 0.08 + CGFloat(i) * 0.04 : 0.75 + CGFloat(i - 5) * 0.05
            tree.position = CGPoint(x: w * side + CGFloat.random(in: -10...10),
                                    y: h * CGFloat.random(in: 0.25...0.80))
            add(tree, to: scene)
        }

        // --- Arbres corrompus (violet/noir, au centre) ---
        for i in 0..<6 {
            let tree = makeCorruptedTree(height: CGFloat.random(in: 70...120))
            let tx = w * (0.30 + CGFloat(i % 3) * 0.15) + CGFloat.random(in: -15...15)
            let ty = h * (0.45 + CGFloat(i / 3) * 0.18) + CGFloat.random(in: -10...10)
            tree.position = CGPoint(x: tx, y: ty)
            add(tree, to: scene)
        }

        // --- Zone 1 : Bosquet corrompu (centre-gauche) ---
        let groveZone = makeDangerZone(
            at: CGPoint(x: w * 0.30, y: h * 0.45),
            radius: 35,
            color: SKColor(red: 0.50, green: 0.10, blue: 0.10, alpha: 1)
        )
        add(groveZone, to: scene)

        // --- Zone 2 : Clairière sombre (centre-droite) ---
        let clearingZone = makeDangerZone(
            at: CGPoint(x: w * 0.65, y: h * 0.55),
            radius: 40,
            color: SKColor(red: 0.40, green: 0.08, blue: 0.45, alpha: 1)
        )
        add(clearingZone, to: scene)

        // --- Zone 3 : Sentier profond (nord) → vers sanctuaire ---
        let deepPath = SKShapeNode(rectOf: CGSize(width: 60, height: 30), cornerRadius: 8)
        deepPath.fillColor = SKColor(red: 0.12, green: 0.05, blue: 0.18, alpha: 0.15)
        deepPath.strokeColor = SKColor(red: 0.50, green: 0.25, blue: 0.75, alpha: 0.30)
        deepPath.lineWidth = 1.5
        deepPath.position = CGPoint(x: w * 0.60, y: h * 0.82)
        deepPath.zPosition = -2
        add(deepPath, to: scene)
        JuiceEngine.pulse(deepPath, scale: 1.15)

        let pathLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        pathLabel.text = String(localized: "world.deepPath")
        pathLabel.fontSize = 10
        pathLabel.fontColor = SKColor(red: 0.55, green: 0.35, blue: 0.80, alpha: 0.7)
        pathLabel.position = CGPoint(x: w * 0.60, y: h * 0.87)
        pathLabel.zPosition = -1
        add(pathLabel, to: scene)

        // --- Mares d'Aether noir ---
        let poolPositions: [CGPoint] = [
            CGPoint(x: w * 0.22, y: h * 0.60),
            CGPoint(x: w * 0.55, y: h * 0.38),
            CGPoint(x: w * 0.75, y: h * 0.70)
        ]
        for pos in poolPositions {
            let pool = makeAetherPool(at: pos)
            add(pool, to: scene)
        }

        // --- Champignons lumineux (ambiance) ---
        let mushPositions: [CGPoint] = [
            CGPoint(x: w * 0.15, y: h * 0.35),
            CGPoint(x: w * 0.70, y: h * 0.30),
            CGPoint(x: w * 0.85, y: h * 0.50),
            CGPoint(x: w * 0.25, y: h * 0.75)
        ]
        for pos in mushPositions {
            let m = makeGlowMushroom(at: pos)
            add(m, to: scene)
        }

        // Arbres fond (foreground parallax feel)
        for i in 0..<4 {
            let tree = makeTree(height: CGFloat.random(in: 50...80))
            tree.position = CGPoint(x: CGFloat(50 + i * 140), y: h * 0.15 + CGFloat.random(in: -10...10))
            tree.alpha = 0.3
            tree.zPosition = 5
            add(tree, to: scene)
        }

        addAtmosphere(ParticleFactory.forestFog(in: scene.size), to: scene)
    }

    // MARK: - Forest Building Blocks

    private func makeCorruptedTree(height: CGFloat) -> SKNode {
        let tree = SKNode()
        tree.zPosition = -4

        let trunk = SKShapeNode(rectOf: CGSize(width: 10, height: height * 0.45), cornerRadius: 2)
        trunk.fillColor = SKColor(red: 0.10, green: 0.06, blue: 0.12, alpha: 1)
        trunk.strokeColor = .clear
        tree.addChild(trunk)

        let colors: [SKColor] = [
            SKColor(red: 0.12, green: 0.06, blue: 0.18, alpha: 1),
            SKColor(red: 0.08, green: 0.04, blue: 0.14, alpha: 1),
            SKColor(red: 0.14, green: 0.08, blue: 0.22, alpha: 0.8)
        ]
        for i in 0..<3 {
            let leaf = SKShapeNode(circleOfRadius: CGFloat(16 - i * 3))
            leaf.fillColor = colors[i]
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: 0, y: height * 0.22 + CGFloat(i) * 12)
            tree.addChild(leaf)
        }

        // Lueur violette subtile
        let glow = SKShapeNode(circleOfRadius: 22)
        glow.fillColor = SKColor(red: 0.35, green: 0.10, blue: 0.50, alpha: 0.06)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: height * 0.30)
        tree.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)

        return tree
    }

    private func makeDangerZone(at pos: CGPoint, radius: CGFloat, color: SKColor) -> SKNode {
        let zone = SKNode()
        zone.position = pos
        zone.zPosition = -2

        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = color.withAlphaComponent(0.06)
        circle.strokeColor = color.withAlphaComponent(0.18)
        circle.lineWidth = 1.5
        zone.addChild(circle)
        JuiceEngine.pulse(circle, scale: 1.2)

        // Icône crâne (placeholder)
        let icon = SKLabelNode(text: "☠")
        icon.fontSize = 18
        icon.position = CGPoint(x: 0, y: -6)
        zone.addChild(icon)
        JuiceEngine.float(icon, distance: 4)

        return zone
    }

    private func makeAetherPool(at pos: CGPoint) -> SKNode {
        let pool = SKNode()
        pool.position = pos
        pool.zPosition = -6

        let water = SKShapeNode(circleOfRadius: 12)
        water.fillColor = SKColor(red: 0.08, green: 0.02, blue: 0.15, alpha: 0.8)
        water.strokeColor = SKColor(red: 0.40, green: 0.15, blue: 0.65, alpha: 0.3)
        water.lineWidth = 1
        pool.addChild(water)

        let glow = SKShapeNode(circleOfRadius: 18)
        glow.fillColor = SKColor(red: 0.30, green: 0.08, blue: 0.50, alpha: 0.05)
        glow.strokeColor = .clear
        pool.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.5)

        return pool
    }

    private func makeGlowMushroom(at pos: CGPoint) -> SKNode {
        let mush = SKNode()
        mush.position = pos
        mush.zPosition = -3

        let stem = SKShapeNode(rectOf: CGSize(width: 3, height: 8), cornerRadius: 1)
        stem.fillColor = SKColor(white: 0.15, alpha: 1)
        stem.strokeColor = .clear
        mush.addChild(stem)

        let cap = SKShapeNode(circleOfRadius: 5)
        cap.fillColor = SKColor(red: 0.20, green: 0.55, blue: 0.30, alpha: 0.9)
        cap.strokeColor = .clear
        cap.glowWidth = 3
        cap.position = CGPoint(x: 0, y: 7)
        mush.addChild(cap)
        JuiceEngine.pulse(cap, scale: 1.3)

        return mush
    }

    // MARK: - Sanctuaire

    private func buildShrine(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
        ground.fillColor = SKColor(red: 0.04, green: 0.03, blue: 0.08, alpha: 1)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: 500, y: 500)
        ground.zPosition = -10
        add(ground, to: scene)

        let altar = SKShapeNode(rectOf: CGSize(width: 80, height: 50), cornerRadius: 6)
        altar.fillColor = SKColor(red: 0.12, green: 0.08, blue: 0.18, alpha: 1)
        altar.strokeColor = SKColor(red: 0.50, green: 0.30, blue: 0.80, alpha: 0.6)
        altar.lineWidth = 2
        altar.position = CGPoint(x: w * 0.70, y: h * 0.55)
        altar.zPosition = -2
        add(altar, to: scene)

        let altarGlow = SKShapeNode(circleOfRadius: 50)
        altarGlow.fillColor = SKColor(red: 0.30, green: 0.10, blue: 0.50, alpha: 0.08)
        altarGlow.strokeColor = .clear
        altarGlow.position = altar.position
        altarGlow.zPosition = -3
        add(altarGlow, to: scene)
        JuiceEngine.pulse(altarGlow, scale: 1.3)

        for i in 0..<4 {
            let pillar = SKShapeNode(rectOf: CGSize(width: 10, height: 70), cornerRadius: 3)
            pillar.fillColor = SKColor(red: 0.15, green: 0.10, blue: 0.22, alpha: 1)
            pillar.strokeColor = SKColor(red: 0.45, green: 0.25, blue: 0.70, alpha: 0.4)
            pillar.lineWidth = 1
            let px = w * 0.25 + CGFloat(i) * w * 0.17
            pillar.position = CGPoint(x: px, y: h * 0.60)
            pillar.zPosition = -4
            add(pillar, to: scene)

            let orb = SKShapeNode(circleOfRadius: 4)
            orb.fillColor = SKColor(red: 0.55, green: 0.30, blue: 0.90, alpha: 0.8)
            orb.strokeColor = .clear
            orb.glowWidth = 4
            orb.position = CGPoint(x: px, y: h * 0.60 + 40)
            orb.zPosition = -3
            add(orb, to: scene)
            JuiceEngine.pulse(orb, scale: 1.5)
        }

        addAtmosphere(ParticleFactory.shrineAura(in: scene.size), to: scene)
    }

    // MARK: - Building Blocks

    private func makeBuilding(w: CGFloat, h: CGFloat, wallColor: SKColor, roofColor: SKColor, label: String?) -> SKNode {
        let bld = SKNode()

        let wall = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 4)
        wall.fillColor = wallColor
        wall.strokeColor = SKColor(white: 0.22, alpha: 0.5)
        wall.lineWidth = 1
        bld.addChild(wall)

        let roof = SKShapeNode(rectOf: CGSize(width: w + 12, height: 14), cornerRadius: 3)
        roof.fillColor = roofColor
        roof.strokeColor = .clear
        roof.position = CGPoint(x: 0, y: h / 2 + 5)
        bld.addChild(roof)

        let door = SKShapeNode(rectOf: CGSize(width: 12, height: 18), cornerRadius: 2)
        door.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1)
        door.strokeColor = SKColor(white: 0.18, alpha: 0.5)
        door.lineWidth = 1
        door.position = CGPoint(x: 0, y: -h / 2 + 9)
        bld.addChild(door)

        let winL = SKShapeNode(rectOf: CGSize(width: 10, height: 8), cornerRadius: 2)
        winL.fillColor = SKColor(red: 0.60, green: 0.50, blue: 0.25, alpha: 0.2)
        winL.strokeColor = SKColor(white: 0.30, alpha: 0.4)
        winL.position = CGPoint(x: -w * 0.28, y: 4)
        bld.addChild(winL)

        let winR = SKShapeNode(rectOf: CGSize(width: 10, height: 8), cornerRadius: 2)
        winR.fillColor = winL.fillColor
        winR.strokeColor = winL.strokeColor
        winR.position = CGPoint(x: w * 0.28, y: 4)
        bld.addChild(winR)

        if let lbl = label {
            let sign = SKLabelNode(text: lbl)
            sign.fontSize = 16
            sign.position = CGPoint(x: 0, y: h / 2 + 20)
            bld.addChild(sign)
        }

        return bld
    }

    private func buildNorthGate(at pos: CGPoint, width: CGFloat, in scene: SKScene) {
        let gate = SKNode()
        gate.position = pos
        gate.zPosition = -3

        let pillarL = SKShapeNode(rectOf: CGSize(width: 14, height: 50), cornerRadius: 3)
        pillarL.fillColor = SKColor(red: 0.28, green: 0.22, blue: 0.14, alpha: 1)
        pillarL.strokeColor = SKColor(white: 0.30, alpha: 0.4)
        pillarL.position = CGPoint(x: -width / 2, y: 0)
        gate.addChild(pillarL)

        let pillarR = pillarL.copy() as! SKShapeNode
        pillarR.position = CGPoint(x: width / 2, y: 0)
        gate.addChild(pillarR)

        let bar = SKShapeNode(rectOf: CGSize(width: width, height: 6), cornerRadius: 2)
        bar.fillColor = SKColor(red: 0.35, green: 0.28, blue: 0.18, alpha: 1)
        bar.strokeColor = SKColor(white: 0.25, alpha: 0.4)
        bar.position = CGPoint(x: 0, y: 24)
        gate.addChild(bar)

        let northSign = SKLabelNode(fontNamed: "AvenirNext-Medium")
        northSign.text = String(localized: "world.northGate")
        northSign.fontSize = 11
        northSign.fontColor = SKColor(white: 0.55, alpha: 1)
        northSign.position = CGPoint(x: 0, y: 34)
        gate.addChild(northSign)

        add(gate, to: scene)
    }

    private func buildWell(at pos: CGPoint, in scene: SKScene) {
        let well = SKNode()
        well.position = pos
        well.zPosition = -3

        let base = SKShapeNode(circleOfRadius: 14)
        base.fillColor = SKColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1)
        base.strokeColor = SKColor(white: 0.28, alpha: 0.5)
        base.lineWidth = 2
        well.addChild(base)

        let water = SKShapeNode(circleOfRadius: 10)
        water.fillColor = SKColor(red: 0.10, green: 0.25, blue: 0.40, alpha: 0.8)
        water.strokeColor = .clear
        well.addChild(water)

        let glow = SKShapeNode(circleOfRadius: 10)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.30, green: 0.55, blue: 0.80, alpha: 0.15)
        glow.lineWidth = 2
        well.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)

        add(well, to: scene)
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

        return torch
    }

    private func makeTree(height: CGFloat) -> SKNode {
        let tree = SKNode()
        tree.zPosition = -4

        let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: height * 0.4), cornerRadius: 2)
        trunk.fillColor = SKColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 1)
        trunk.strokeColor = .clear
        tree.addChild(trunk)

        let colors: [SKColor] = [
            SKColor(red: 0.08, green: 0.20, blue: 0.10, alpha: 1),
            SKColor(red: 0.06, green: 0.18, blue: 0.08, alpha: 1),
            SKColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 1)
        ]
        for i in 0..<3 {
            let leaf = SKShapeNode(circleOfRadius: CGFloat(18 - i * 4))
            leaf.fillColor = colors[i]
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: 0, y: height * 0.2 + CGFloat(i) * 14)
            tree.addChild(leaf)
        }

        return tree
    }

    // MARK: - Helpers

    private func add(_ node: SKNode, to scene: SKScene) {
        scene.addChild(node)
        backdropNodes.append(node)
    }

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
