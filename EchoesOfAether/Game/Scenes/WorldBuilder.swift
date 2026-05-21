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
    private var toyMarker: SKNode?

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

    func switchToVillage(in scene: SKScene) {
        clearBackdrop()
        scene.backgroundColor = SKColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1)
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = false }
        buildVillage(in: scene)
    }

    func switchToRuins(in scene: SKScene) {
        clearBackdrop()
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.04, green: 0.02, blue: 0.03, alpha: 1)
        buildRuins(in: scene)
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

        // Cristal de sauvegarde (bas gauche, facile d'accès)
        addSaveCrystal(at: CGPoint(x: w * 0.12, y: h * 0.22), in: scene)

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

        // Cristal de sauvegarde (bas centre)
        addSaveCrystal(at: CGPoint(x: w * 0.50, y: h * 0.15), in: scene)

        addAtmosphere(ParticleFactory.forestFog(in: scene.size), to: scene)
    }

    /// Place le jouet visible en forêt (si quête active)
    func addToyMarker(in scene: SKScene) {
        guard toyMarker == nil else { return }
        let w = scene.size.width
        let h = scene.size.height

        let toy = SKNode()
        toy.position = CGPoint(x: w * 0.80, y: h * 0.28)
        toy.zPosition = 3

        // Petit ours en bois (placeholder)
        let body = SKShapeNode(rectOf: CGSize(width: 12, height: 14), cornerRadius: 3)
        body.fillColor = SKColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1)
        body.strokeColor = SKColor(red: 0.70, green: 0.45, blue: 0.20, alpha: 0.6)
        body.lineWidth = 1
        toy.addChild(body)

        let head = SKShapeNode(circleOfRadius: 6)
        head.fillColor = SKColor(red: 0.60, green: 0.40, blue: 0.18, alpha: 1)
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: 12)
        toy.addChild(head)

        // Lueur dorée pour attirer l'œil
        let glow = SKShapeNode(circleOfRadius: 18)
        glow.fillColor = SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.08)
        glow.strokeColor = SKColor(red: 1, green: 0.80, blue: 0.2, alpha: 0.20)
        glow.lineWidth = 1
        toy.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.5)

        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = "✦"
        label.fontSize = 14
        label.position = CGPoint(x: 0, y: 24)
        toy.addChild(label)
        JuiceEngine.float(label, distance: 4)

        scene.addChild(toy)
        backdropNodes.append(toy)
        toyMarker = toy
    }

    func removeToyMarker() {
        toyMarker?.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
        if let t = toyMarker, let idx = backdropNodes.firstIndex(where: { $0 === t }) {
            backdropNodes.remove(at: idx)
        }
        toyMarker = nil
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

    // MARK: - Ruines de la Source (Acte II)

    private func buildRuins(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : dalle craquelée noire-rouge
        let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
        ground.fillColor = SKColor(red: 0.06, green: 0.03, blue: 0.04, alpha: 1)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: 500, y: 500)
        ground.zPosition = -10
        add(ground, to: scene)

        // Fissures d'Aether rouge dans le sol
        let crackPositions: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.20, 0.25, 0.38, 0.32), (0.45, 0.18, 0.58, 0.30),
            (0.62, 0.42, 0.78, 0.50), (0.15, 0.55, 0.32, 0.63),
            (0.50, 0.65, 0.68, 0.72)
        ]
        for (x1, y1, x2, y2) in crackPositions {
            let crack = makeCrack(from: CGPoint(x: w * x1, y: h * y1),
                                  to:   CGPoint(x: w * x2, y: h * y2))
            add(crack, to: scene)
        }

        // Piliers brisés (certains debout, certains tombés)
        let pillarData: [(CGFloat, CGFloat, Bool)] = [
            (0.18, 0.65, false), (0.28, 0.72, true),
            (0.48, 0.78, false), (0.62, 0.75, true),
            (0.80, 0.68, false), (0.85, 0.52, true)
        ]
        for (px, py, fallen) in pillarData {
            let pillar = makeBrokenPillar(fallen: fallen)
            pillar.position = CGPoint(x: w * px, y: h * py)
            add(pillar, to: scene)
        }

        // Titre de zone
        let zoneLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        zoneLabel.text = String(localized: "world.ruins.title")
        zoneLabel.fontSize = 11
        zoneLabel.fontColor = SKColor(red: 0.70, green: 0.25, blue: 0.25, alpha: 0.60)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.90)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // Zone combat 1 : Gardiens (centre-gauche)
        let zone1 = makeDangerZone(
            at: CGPoint(x: w * 0.28, y: h * 0.50),
            radius: 38,
            color: SKColor(red: 0.70, green: 0.15, blue: 0.10, alpha: 1)
        )
        add(zone1, to: scene)

        // Zone combat 2 : Âmes piégées (centre-droite)
        let zone2 = makeDangerZone(
            at: CGPoint(x: w * 0.62, y: h * 0.60),
            radius: 38,
            color: SKColor(red: 0.55, green: 0.10, blue: 0.35, alpha: 1)
        )
        add(zone2, to: scene)

        // Inscription secondaire d'Eran (coins bas-gauche)
        let eranInscription = makeEranInscription(at: CGPoint(x: w * 0.15, y: h * 0.65))
        add(eranInscription, to: scene)

        // Mur d'inscription (discovery) — haut-droite
        let inscriptionWall = makeInscriptionWall(
            at: CGPoint(x: w * 0.70, y: h * 0.65)
        )
        add(inscriptionWall, to: scene)

        // Mares d'Aether rouge (ambiance)
        for (px, py) in [(0.15, 0.38), (0.55, 0.35), (0.82, 0.42)] {
            let pool = makeRedAetherPool(at: CGPoint(x: w * px, y: h * py))
            add(pool, to: scene)
        }

        // Cristal de sauvegarde (entrée des ruines, bas droite)
        addSaveCrystal(at: CGPoint(x: w * 0.88, y: h * 0.22), in: scene)

        addAtmosphere(ParticleFactory.ruinsAsh(in: scene.size), to: scene)
    }

    private func makeCrack(from start: CGPoint, to end: CGPoint) -> SKNode {
        let crack = SKNode()
        crack.zPosition = -8

        let path = CGMutablePath()
        path.move(to: start)
        let midX = (start.x + end.x) / 2 + CGFloat.random(in: -10...10)
        let midY = (start.y + end.y) / 2 + CGFloat.random(in: -8...8)
        path.addLine(to: CGPoint(x: midX, y: midY))
        path.addLine(to: end)

        let line = SKShapeNode(path: path)
        line.strokeColor = SKColor(red: 0.70, green: 0.15, blue: 0.10, alpha: 0.45)
        line.lineWidth = 1.5
        line.glowWidth = 2
        crack.addChild(line)

        let glowLine = SKShapeNode(path: path)
        glowLine.strokeColor = SKColor(red: 0.90, green: 0.25, blue: 0.15, alpha: 0.08)
        glowLine.lineWidth = 5
        crack.addChild(glowLine)

        return crack
    }

    private func makeBrokenPillar(fallen: Bool) -> SKNode {
        let pillar = SKNode()
        pillar.zPosition = -4

        if fallen {
            let body = SKShapeNode(rectOf: CGSize(width: 55, height: 12), cornerRadius: 3)
            body.fillColor = SKColor(red: 0.20, green: 0.14, blue: 0.16, alpha: 1)
            body.strokeColor = SKColor(red: 0.40, green: 0.20, blue: 0.22, alpha: 0.6)
            body.lineWidth = 1.5
            body.zRotation = CGFloat.random(in: -0.2...0.3)
            pillar.addChild(body)

            let crack = SKShapeNode(rectOf: CGSize(width: 3, height: 12), cornerRadius: 1)
            crack.fillColor = SKColor(red: 0.70, green: 0.15, blue: 0.12, alpha: 0.5)
            crack.strokeColor = .clear
            crack.position = CGPoint(x: CGFloat.random(in: -15...15), y: 0)
            pillar.addChild(crack)
        } else {
            let body = SKShapeNode(rectOf: CGSize(width: 14, height: 60), cornerRadius: 3)
            body.fillColor = SKColor(red: 0.18, green: 0.12, blue: 0.14, alpha: 1)
            body.strokeColor = SKColor(red: 0.40, green: 0.20, blue: 0.25, alpha: 0.5)
            body.lineWidth = 1.5
            pillar.addChild(body)

            let top = SKShapeNode(rectOf: CGSize(width: 22, height: 8), cornerRadius: 2)
            top.fillColor = SKColor(red: 0.25, green: 0.15, blue: 0.18, alpha: 1)
            top.strokeColor = .clear
            top.position = CGPoint(x: 0, y: 34)
            pillar.addChild(top)

            let redGlow = SKShapeNode(circleOfRadius: 4)
            redGlow.fillColor = SKColor(red: 0.80, green: 0.20, blue: 0.10, alpha: 0.6)
            redGlow.strokeColor = .clear
            redGlow.glowWidth = 5
            redGlow.position = CGPoint(x: 0, y: 38)
            pillar.addChild(redGlow)
            JuiceEngine.pulse(redGlow, scale: 1.5)
        }

        return pillar
    }

    private func makeInscriptionWall(at pos: CGPoint) -> SKNode {
        let wall = SKNode()
        wall.position = pos
        wall.zPosition = 1

        let stone = SKShapeNode(rectOf: CGSize(width: 72, height: 55), cornerRadius: 5)
        stone.fillColor = SKColor(red: 0.14, green: 0.08, blue: 0.10, alpha: 1)
        stone.strokeColor = SKColor(red: 0.60, green: 0.20, blue: 0.18, alpha: 0.7)
        stone.lineWidth = 2
        wall.addChild(stone)

        let glow = SKShapeNode(rectOf: CGSize(width: 80, height: 63), cornerRadius: 8)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.80, green: 0.25, blue: 0.15, alpha: 0.12)
        glow.lineWidth = 4
        wall.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.08)

        let runeLines: [(CGFloat, CGFloat, CGFloat)] = [(-16, 14, 32), (0, 2, 40), (0, -10, 28), (0, -22, 36)]
        for (x, y, width) in runeLines {
            let rune = SKShapeNode(rectOf: CGSize(width: width, height: 2), cornerRadius: 1)
            rune.fillColor = SKColor(red: 0.70, green: 0.20, blue: 0.15, alpha: 0.6)
            rune.strokeColor = .clear
            rune.position = CGPoint(x: x, y: y)
            wall.addChild(rune)
        }

        let labelNode = SKLabelNode(fontNamed: "AvenirNext-Medium")
        labelNode.text = String(localized: "world.ruins.inscription")
        labelNode.fontSize = 9
        labelNode.fontColor = SKColor(red: 0.70, green: 0.30, blue: 0.25, alpha: 0.70)
        labelNode.position = CGPoint(x: 0, y: -38)
        wall.addChild(labelNode)
        JuiceEngine.float(labelNode, distance: 3)

        return wall
    }

    private func makeEranInscription(at pos: CGPoint) -> SKNode {
        let wall = SKNode()
        wall.position = pos
        wall.zPosition = 1

        // Pierre plus petite, style griffonné
        let stone = SKShapeNode(rectOf: CGSize(width: 44, height: 34), cornerRadius: 3)
        stone.fillColor = SKColor(red: 0.10, green: 0.06, blue: 0.08, alpha: 1)
        stone.strokeColor = SKColor(red: 0.35, green: 0.55, blue: 0.80, alpha: 0.5)
        stone.lineWidth = 1.5
        wall.addChild(stone)

        let glow = SKShapeNode(rectOf: CGSize(width: 52, height: 42), cornerRadius: 6)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.40, green: 0.60, blue: 0.90, alpha: 0.08)
        glow.lineWidth = 3
        wall.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.12)

        // Lignes griffonnées (style main, irrégulières)
        let lineData: [(CGFloat, CGFloat, CGFloat)] = [(-8, 10, 22), (0, 2, 30), (0, -6, 18)]
        for (x, y, w2) in lineData {
            let line = SKShapeNode(rectOf: CGSize(width: w2, height: 1.5), cornerRadius: 0.5)
            line.fillColor = SKColor(red: 0.45, green: 0.65, blue: 0.90, alpha: 0.5)
            line.strokeColor = .clear
            line.position = CGPoint(x: x, y: y)
            wall.addChild(line)
        }

        let labelNode = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
        labelNode.text = String(localized: "world.ruins.eranInscription")
        labelNode.fontSize = 8
        labelNode.fontColor = SKColor(red: 0.50, green: 0.68, blue: 0.90, alpha: 0.70)
        labelNode.position = CGPoint(x: 0, y: -26)
        wall.addChild(labelNode)
        JuiceEngine.float(labelNode, distance: 2)

        return wall
    }

    private func makeRedAetherPool(at pos: CGPoint) -> SKNode {
        let pool = SKNode()
        pool.position = pos
        pool.zPosition = -6

        let water = SKShapeNode(circleOfRadius: 10)
        water.fillColor = SKColor(red: 0.15, green: 0.02, blue: 0.05, alpha: 0.9)
        water.strokeColor = SKColor(red: 0.60, green: 0.15, blue: 0.10, alpha: 0.4)
        water.lineWidth = 1
        pool.addChild(water)

        let glow = SKShapeNode(circleOfRadius: 16)
        glow.fillColor = SKColor(red: 0.50, green: 0.08, blue: 0.05, alpha: 0.06)
        glow.strokeColor = .clear
        pool.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.5)

        return pool
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

        // Boss — Gardien de l'Aether
        let boss = makeBossGuardian()
        boss.position = CGPoint(x: w * 0.70, y: h * 0.45)
        add(boss, to: scene)

        // Cristal de sauvegarde (bas gauche du sanctuaire)
        addSaveCrystal(at: CGPoint(x: w * 0.18, y: h * 0.20), in: scene)

        addAtmosphere(ParticleFactory.shrineAura(in: scene.size), to: scene)
    }

    private func makeBossGuardian() -> SKNode {
        let guardian = SKNode()
        guardian.zPosition = 2

        // Body — large dark shape
        let body = SKShapeNode(rectOf: CGSize(width: 32, height: 48), cornerRadius: 6)
        body.fillColor = SKColor(red: 0.08, green: 0.04, blue: 0.14, alpha: 1)
        body.strokeColor = SKColor(red: 0.50, green: 0.20, blue: 0.80, alpha: 0.6)
        body.lineWidth = 2
        guardian.addChild(body)

        // Head
        let head = SKShapeNode(circleOfRadius: 14)
        head.fillColor = SKColor(red: 0.12, green: 0.06, blue: 0.20, alpha: 1)
        head.strokeColor = SKColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 0.5)
        head.lineWidth = 1.5
        head.position = CGPoint(x: 0, y: 32)
        guardian.addChild(head)

        // Eyes — glowing red
        for dx: CGFloat in [-5, 5] {
            let eye = SKShapeNode(circleOfRadius: 2.5)
            eye.fillColor = SKColor(red: 0.90, green: 0.15, blue: 0.10, alpha: 1)
            eye.strokeColor = .clear
            eye.glowWidth = 4
            eye.position = CGPoint(x: dx, y: 34)
            guardian.addChild(eye)
            JuiceEngine.pulse(eye, scale: 1.4)
        }

        // Aether aura
        let aura = SKShapeNode(circleOfRadius: 38)
        aura.fillColor = SKColor(red: 0.35, green: 0.10, blue: 0.55, alpha: 0.06)
        aura.strokeColor = SKColor(red: 0.45, green: 0.15, blue: 0.70, alpha: 0.12)
        aura.lineWidth = 1
        guardian.addChild(aura)
        JuiceEngine.pulse(aura, scale: 1.4)

        // Float animation
        JuiceEngine.float(guardian, distance: 5)

        return guardian
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

    // MARK: - Save Crystal

    /// Ajoute un cristal de sauvegarde dans la scène courante.
    /// Retourne la position du cristal pour que GameManager puisse détecter le tap.
    @discardableResult
    func addSaveCrystal(at position: CGPoint, in scene: SKScene) -> CGPoint {
        let crystal = SKNode()
        crystal.position = position
        crystal.zPosition = 2
        crystal.name = "saveCrystal"

        // Corps du cristal (losange)
        let gem = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 18))
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -10))
        path.addLine(to: CGPoint(x: -10, y: 0))
        path.closeSubpath()
        gem.path = path
        gem.fillColor = SKColor(red: 0.50, green: 0.80, blue: 1.0, alpha: 0.85)
        gem.strokeColor = SKColor(red: 0.70, green: 0.90, blue: 1.0, alpha: 1.0)
        gem.lineWidth = 1.5
        gem.glowWidth = 6
        crystal.addChild(gem)
        JuiceEngine.pulse(gem, scale: 1.12)

        // Aura externe
        let aura = SKShapeNode(circleOfRadius: 22)
        aura.fillColor = SKColor(red: 0.40, green: 0.70, blue: 1.0, alpha: 0.06)
        aura.strokeColor = SKColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 0.18)
        aura.lineWidth = 1.5
        crystal.addChild(aura)
        JuiceEngine.pulse(aura, scale: 1.25)

        // Label
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = String(localized: "world.saveCrystal.label")
        label.fontSize = 9
        label.fontColor = SKColor(red: 0.65, green: 0.88, blue: 1.0, alpha: 0.80)
        label.position = CGPoint(x: 0, y: -26)
        crystal.addChild(label)
        JuiceEngine.float(label, distance: 3)

        scene.addChild(crystal)
        backdropNodes.append(crystal)
        return position
    }

    // MARK: - Kael Corruption (Acte II)

    /// Applique visuellement la corruption de Kael (niveau 1-3).
    /// Supprime les noeuds précédents avant d'ajouter le nouveau niveau.
    func applyKaelCorruption(level: Int) {
        // Supprimer l'ancienne corruption
        kael.children
            .filter { $0.name == "kaelCorruption" }
            .forEach { $0.removeFromParent() }

        guard level > 0 else { return }

        // Niveau 1 : aura sombre violette élargie
        let aura = SKShapeNode(circleOfRadius: CGFloat(34 + level * 8))
        aura.fillColor = SKColor(red: 0.20, green: 0.04, blue: 0.32, alpha: CGFloat(level) * 0.05)
        aura.strokeColor = SKColor(red: 0.45, green: 0.10, blue: 0.70, alpha: CGFloat(level) * 0.14)
        aura.lineWidth = 1.5
        aura.glowWidth = CGFloat(level) * 2
        aura.name = "kaelCorruption"
        aura.zPosition = -1
        kael.addChild(aura)
        JuiceEngine.pulse(aura, scale: 1.0 + CGFloat(level) * 0.08)

        // Niveau 2+ : vrilles sombres (4 tentacules)
        if level >= 2 {
            for i in 0..<4 {
                let angle = CGFloat(i) * (.pi / 2)
                let tendril = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: .zero)
                let ex = cos(angle) * 28
                let ey = sin(angle) * 28
                path.addQuadCurve(
                    to: CGPoint(x: ex, y: ey),
                    control: CGPoint(x: cos(angle + 0.5) * 18, y: sin(angle + 0.5) * 18)
                )
                tendril.path = path
                tendril.strokeColor = SKColor(red: 0.25, green: 0.04, blue: 0.40, alpha: 0.55)
                tendril.lineWidth = 1.5
                tendril.glowWidth = 2
                tendril.name = "kaelCorruption"
                tendril.zPosition = -1
                kael.addChild(tendril)
                JuiceEngine.pulse(tendril, scale: 1.06)
            }
        }

        // Niveau 3 : yeux rouges par-dessus les yeux violets
        if level >= 3 {
            for dx: CGFloat in [-5, 5] {
                let redEye = SKShapeNode(circleOfRadius: 3)
                redEye.fillColor = SKColor(red: 0.95, green: 0.12, blue: 0.08, alpha: 1)
                redEye.strokeColor = .clear
                redEye.glowWidth = 5
                redEye.position = CGPoint(x: dx, y: 35)
                redEye.name = "kaelCorruption"
                redEye.zPosition = 3
                kael.addChild(redEye)
                JuiceEngine.pulse(redEye, scale: 1.4)
            }
        }
    }

    /// Déplace Dorin près de la porte nord (garde la porte Acte II).
    func repositionDorinToGate(in scene: SKScene) {
        dorin.position = CGPoint(x: scene.size.width * 0.42, y: scene.size.height * 0.74)
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
