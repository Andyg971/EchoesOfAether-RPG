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

    let worldNode = SKNode()
    private(set) var worldHeight: CGFloat = 0
    private var backdropNodes: [SKNode] = []
    private var atmosphereNode: SKNode?
    private var toyMarker: SKNode?
    private var activeInterior: HouseInteriorKind?

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
        worldNode.name = "worldNode"
        scene.addChild(worldNode)
        buildVillage(in: scene)
        for node in [kael, lyra, dorin, bram, mara, garen, sage, child, villager] {
            worldNode.addChild(node)
        }
        layout(in: scene.size)
    }

    func layout(in size: CGSize) {
        let w = size.width
        let wh = worldHeight > 0 ? worldHeight : size.height

        lyra.position    = CGPoint(x: w * 0.24, y: wh * 0.72)
        dorin.position   = CGPoint(x: w * 0.76, y: wh * 0.72)
        bram.position    = CGPoint(x: w * 0.50, y: wh * 0.55)
        mara.position    = CGPoint(x: w * 0.24, y: wh * 0.40)
        sage.position    = CGPoint(x: w * 0.76, y: wh * 0.40)
        garen.position   = CGPoint(x: w * 0.50, y: wh * 0.90)
        child.position   = CGPoint(x: w * 0.38, y: wh * 0.25)
        villager.position = CGPoint(x: w * 0.62, y: wh * 0.25)
        kael.position    = CGPoint(x: w * 0.50, y: wh * 0.08)

        [lyra, dorin, bram, mara, sage, garen, child, villager, kael].forEach {
            $0.zPosition = actorLayer(for: $0.position.y)
        }
    }

    // MARK: - Camera

    func updateCamera(in sceneSize: CGSize) {
        guard worldHeight > sceneSize.height else { return }
        let targetY = kael.position.y
        let minY: CGFloat = 0
        let maxY = worldHeight - sceneSize.height
        let clamped = min(max(targetY - sceneSize.height / 2, minY), maxY)
        worldNode.position.y = -clamped
    }

    // MARK: - Zone Backgrounds

    func switchToForest(in scene: SKScene) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.06, blue: 0.04, alpha: 1)
        buildForest(in: scene)
    }

    func switchToShrine(in scene: SKScene) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.02, blue: 0.07, alpha: 1)
        buildShrine(in: scene)
    }

    func switchToVillage(in scene: SKScene) {
        clearBackdrop()
        worldNode.position = .zero
        scene.backgroundColor = SKColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1)
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = false }
        buildVillage(in: scene)
    }

    func switchToRuins(in scene: SKScene) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.04, green: 0.02, blue: 0.03, alpha: 1)
        buildRuins(in: scene)
    }

    // MARK: - Village Solis

    private func buildVillage(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height * 2.5
        worldHeight = h

        // Sol vert plat (style Octopath/FF7 — pas de tiles répétitives)
        addFlatGroundVillage(in: scene, size: CGSize(width: w + 96, height: h + 96))

        // Chemin principal vertical (centre)
        addCleanPath(in: scene, rect: CGRect(x: w * 0.47, y: 0, width: w * 0.06, height: h * 0.93))
        // Petits accès terre vers chaque maison
        addCleanPath(in: scene, rect: CGRect(x: w * 0.30, y: h * 0.36, width: w * 0.20, height: 12))
        addCleanPath(in: scene, rect: CGRect(x: w * 0.50, y: h * 0.36, width: w * 0.20, height: 12))
        addCleanPath(in: scene, rect: CGRect(x: w * 0.30, y: h * 0.64, width: w * 0.20, height: 12))
        addCleanPath(in: scene, rect: CGRect(x: w * 0.50, y: h * 0.64, width: w * 0.20, height: 12))
        addCleanPath(in: scene, rect: CGRect(x: w * 0.30, y: h * 0.80, width: w * 0.20, height: 12))
        addCleanPath(in: scene, rect: CGRect(x: w * 0.50, y: h * 0.80, width: w * 0.20, height: 12))

        decorateVillage(in: scene)

        let bScale = buildingScale(for: w)
        let tallS = bScale
        let wideS = bScale * 1.1
        let compactS = bScale * 1.2

        // Row 5 (top) — Porte nord
        buildNorthGate(at: CGPoint(x: w * 0.50, y: h * 0.92), width: 80, in: scene)

        // Row 4 — Victorian (Lyra) + Haunted (Dorin)
        addVillageBuilding(asset: "village_house_victorian", scale: tallS,
                            fallbackW: 70, fallbackH: 55,
                            wallColor: SKColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.30, green: 0.50, blue: 0.35, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.24, y: h * 0.80), in: scene)
        addVillageBuilding(asset: "village_house_haunted", scale: tallS * 0.88,
                            fallbackW: 90, fallbackH: 65,
                            wallColor: SKColor(red: 0.25, green: 0.20, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.50, green: 0.40, blue: 0.18, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.76, y: h * 0.80), in: scene)

        // Row 3 — Country house (décoration) + Modern house (décoration)
        addVillageBuilding(asset: "village_house_country", scale: wideS,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.24, y: h * 0.64), in: scene)
        addVillageBuilding(asset: "village_house_modern", scale: wideS,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1),
                            roofColor: SKColor(red: 0.30, green: 0.30, blue: 0.40, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.76, y: h * 0.64), in: scene)

        // Row 2 — Armurerie (Bram) centre
        addVillageBuilding(asset: "village_house_armory", scale: wideS,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.50, y: h * 0.50), in: scene)

        // Row 1 — Japanese herboriste (Mara) + Auberge (Sage)
        addVillageBuilding(asset: "village_house_japanese", scale: compactS,
                            fallbackW: 62, fallbackH: 50,
                            wallColor: SKColor(red: 0.14, green: 0.22, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.22, green: 0.40, blue: 0.22, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.24, y: h * 0.36), in: scene)
        addVillageBuilding(asset: "village_house_inn", scale: wideS,
                            fallbackW: 88, fallbackH: 62,
                            wallColor: SKColor(red: 0.20, green: 0.14, blue: 0.10, alpha: 1),
                            roofColor: SKColor(red: 0.45, green: 0.25, blue: 0.12, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.76, y: h * 0.36), in: scene)

        // Row 0 — One Story house (décoration) bas du village
        addVillageBuilding(asset: "village_house_onestory", scale: compactS,
                            fallbackW: 62, fallbackH: 50,
                            wallColor: SKColor(red: 0.18, green: 0.16, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.35, green: 0.28, blue: 0.18, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.24, y: h * 0.18), in: scene)

        addSaveCrystal(at: CGPoint(x: w * 0.76, y: h * 0.18), in: scene)

        addAtmosphere(ParticleFactory.ambientDust(in: CGSize(width: w, height: h)), to: scene)
    }

    // MARK: - Forêt d'Ébène

    private func buildForest(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        addFlatGroundForest(in: scene, size: CGSize(width: w + 96, height: h + 96))
        addDirtPath(in: scene, from: CGPoint(x: w * 0.50, y: 0),
                    to: CGPoint(x: w * 0.58, y: h * 0.86),
                    width: 72)
        addDirtPatch(at: CGPoint(x: w * 0.48, y: h * 0.48),
                     size: CGSize(width: w * 0.28, height: h * 0.18),
                     in: scene)

// --- Arbres normaux (bordures) — Modern Exteriors ---
        let treeScale = forestTreeScale(for: w)
        let meTreeAssets = ["me_tree_1", "me_tree_2", "me_tree_3", "me_tree_4", "me_tree_5",
                            "me_tree_6", "me_tree_7", "me_tree_8", "me_tree_9", "me_tree_10"]
        // Bordure gauche dense (x ~0.06) : 6 arbres
        for (i, y) in [CGFloat(0.12), 0.26, 0.40, 0.54, 0.68, 0.82].enumerated() {
            let name = meTreeAssets[i % meTreeAssets.count]
            let tree = PixelArtSprites.still(name: name, scale: treeScale,
                                              anchor: CGPoint(x: 0.5, y: 0.0))
                ?? makeTree(height: 60)
            tree.position = CGPoint(x: w * 0.06, y: h * y)
            tree.zPosition = propLayer(for: tree.position.y, in: h)
            addGroundShadow(under: tree, width: 18, height: 6)
            add(tree, to: scene)
        }
        // Deuxième rangée gauche (x ~0.16)
        for (i, y) in [CGFloat(0.20), 0.38, 0.58, 0.76].enumerated() {
            let name = meTreeAssets[(i + 3) % meTreeAssets.count]
            let tree = PixelArtSprites.still(name: name, scale: treeScale * 0.85,
                                              anchor: CGPoint(x: 0.5, y: 0.0))
                ?? makeTree(height: 50)
            tree.position = CGPoint(x: w * 0.16, y: h * y)
            tree.zPosition = propLayer(for: tree.position.y, in: h)
            tree.alpha = 0.9
            addGroundShadow(under: tree, width: 14, height: 5)
            add(tree, to: scene)
        }
        // Bordure droite dense (x ~0.94)
        for (i, y) in [CGFloat(0.12), 0.26, 0.40, 0.54, 0.68, 0.82].enumerated() {
            let name = meTreeAssets[(i + 5) % meTreeAssets.count]
            let tree = PixelArtSprites.still(name: name, scale: treeScale,
                                              anchor: CGPoint(x: 0.5, y: 0.0))
                ?? makeTree(height: 60)
            tree.position = CGPoint(x: w * 0.94, y: h * y)
            tree.zPosition = propLayer(for: tree.position.y, in: h)
            addGroundShadow(under: tree, width: 18, height: 6)
            add(tree, to: scene)
        }
        // Deuxième rangée droite (x ~0.84)
        for (i, y) in [CGFloat(0.20), 0.38, 0.58, 0.76].enumerated() {
            let name = meTreeAssets[(i + 7) % meTreeAssets.count]
            let tree = PixelArtSprites.still(name: name, scale: treeScale * 0.85,
                                              anchor: CGPoint(x: 0.5, y: 0.0))
                ?? makeTree(height: 50)
            tree.position = CGPoint(x: w * 0.84, y: h * y)
            tree.zPosition = propLayer(for: tree.position.y, in: h)
            tree.alpha = 0.9
            addGroundShadow(under: tree, width: 14, height: 5)
            add(tree, to: scene)
        }
        // Arbres intérieurs (zone jouable) — épars
        let scatterPositions: [(x: CGFloat, y: CGFloat, idx: Int)] = [
            (0.28, 0.80, 1), (0.72, 0.76, 3), (0.78, 0.28, 5),
            (0.24, 0.42, 7), (0.68, 0.60, 9)
        ]
        for p in scatterPositions {
            let tree = PixelArtSprites.still(name: meTreeAssets[p.idx % meTreeAssets.count],
                                              scale: treeScale * 0.80,
                                              anchor: CGPoint(x: 0.5, y: 0.0))
                ?? makeTree(height: 45)
            tree.position = CGPoint(x: w * p.x, y: h * p.y)
            tree.zPosition = propLayer(for: tree.position.y, in: h)
            tree.alpha = 0.92
            addGroundShadow(under: tree, width: 12, height: 4)
            add(tree, to: scene)
        }


        let corruptedTreePositions: [(x: CGFloat, y: CGFloat, scale: CGFloat)] = [
            (0.34, 0.46, 0.78), (0.50, 0.55, 0.86), (0.66, 0.46, 0.78)
        ]
        for p in corruptedTreePositions {
            guard let tree = PixelArtSprites.still(name: "me_tree_5", scale: treeScale * p.scale,
                                                   anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            tree.position = CGPoint(x: w * p.x, y: h * p.y)
            tree.zPosition = propLayer(for: tree.position.y, in: h)
            tree.enumerateChildNodes(withName: "//*") { node, _ in
                if let sprite = node as? SKSpriteNode {
                    sprite.color = SKColor(red: 0.28, green: 0.12, blue: 0.42, alpha: 1)
                    sprite.colorBlendFactor = 0.50
                }
            }
            addGroundShadow(under: tree, width: 46 * treeScale, height: 13 * treeScale)
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


        let foregroundTrees: [(x: CGFloat, y: CGFloat, scale: CGFloat)] = [
            (0.10, 0.13, 0.70), (0.32, 0.12, 0.62), (0.70, 0.13, 0.66), (0.91, 0.12, 0.72)
        ]
        for p in foregroundTrees {
            guard let tree = PixelArtSprites.still(name: "ext_tree_3", scale: treeScale * p.scale,
                                                   anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            tree.position = CGPoint(x: w * p.x, y: h * p.y)
            tree.alpha = 0.55
            tree.zPosition = 5
            add(tree, to: scene)
        }

        decorateForestFloor(in: scene)

        // Cristal de sauvegarde (bas centre)
        addSaveCrystal(at: CGPoint(x: w * 0.50, y: h * 0.15), in: scene)

        addAtmosphere(ParticleFactory.forestFog(in: scene.size), to: scene)
    }

    /// Scale dynamique des arbres pixel art de la forêt selon la largeur.
    /// Cible ~70 pt iPhone, ~110 pt iPad pour les arbres de bordure.
    private func forestTreeScale(for sceneWidth: CGFloat) -> CGFloat {
        let s = sceneWidth / 2400
        return max(0.22, min(0.45, s))
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

        worldNode.addChild(toy)
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

private func decorateVillage(in scene: SKScene) {
    let w = scene.size.width
    let h = worldHeight > 0 ? worldHeight : scene.size.height

    // Arbres (bordures + intérieur)
    let treePositions: [(String, CGFloat, CGFloat)] = [
        ("me_tree_1", 0.08, 0.14), ("me_tree_3", 0.92, 0.14),
        ("me_tree_2", 0.08, 0.30), ("me_tree_4", 0.92, 0.30),
        ("me_tree_5", 0.08, 0.52), ("me_tree_6", 0.92, 0.52),
        ("me_tree_7", 0.08, 0.68), ("me_tree_8", 0.92, 0.68),
        ("me_tree_9", 0.08, 0.84), ("me_tree_10", 0.92, 0.84),
        ("me_tree_2", 0.20, 0.10), ("me_tree_6", 0.80, 0.10),
        ("me_tree_4", 0.20, 0.88), ("me_tree_8", 0.80, 0.88),
        ("me_tree_1", 0.38, 0.05)
    ]
    for t in treePositions {
        addPixelProp(t.0, in: scene, at: CGPoint(x: w * t.1, y: h * t.2), scale: 0.42)
    }

    // Fontaine centre
    addPixelProp("me_fountain", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.46), scale: 0.45)

    // Lampadaires
    let lampPositions: [(CGFloat, CGFloat)] = [
        (0.42, 0.22), (0.58, 0.22), (0.42, 0.42), (0.58, 0.42),
        (0.42, 0.60), (0.58, 0.60), (0.42, 0.76), (0.58, 0.76)
    ]
    for (i, p) in lampPositions.enumerated() {
        addPixelProp("me_lamp_\((i % 3) + 1)", in: scene, at: CGPoint(x: w * p.0, y: h * p.1), scale: 0.22)
    }

    // Chariot marchand
    addPixelProp("me_wood_cart", in: scene, at: CGPoint(x: w * 0.82, y: h * 0.26), scale: 0.35)

    // Bancs
    addPixelProp("me_bench_1", in: scene, at: CGPoint(x: w * 0.40, y: h * 0.50), scale: 0.30)
    addPixelProp("me_bench_2", in: scene, at: CGPoint(x: w * 0.60, y: h * 0.42), scale: 0.30)
    addPixelProp("me_garden_bench", in: scene, at: CGPoint(x: w * 0.34, y: h * 0.68), scale: 0.30)

    // Tonneaux
    addPixelProp("me_barrel_1", in: scene, at: CGPoint(x: w * 0.14, y: h * 0.40), scale: 0.30)
    addPixelProp("me_barrel_2", in: scene, at: CGPoint(x: w * 0.86, y: h * 0.40), scale: 0.30)
    addPixelProp("me_barrel_3", in: scene, at: CGPoint(x: w * 0.18, y: h * 0.58), scale: 0.28)
}

private func decorateForestFloor(in scene: SKScene) {
    let w = scene.size.width
    let h = scene.size.height

    // Bois coupé (48×96px → 0.30 ≈ 14×29pt)
    addPixelProp("me_cut_wood", in: scene, at: CGPoint(x: w * 0.18, y: h * 0.22), scale: 0.30)
    addPixelProp("me_cut_wood", in: scene, at: CGPoint(x: w * 0.82, y: h * 0.32), scale: 0.28)

    // Pousses (48×48px → 0.40 ≈ 19pt)
    addPixelProp("me_big_sprout_1", in: scene, at: CGPoint(x: w * 0.15, y: h * 0.48), scale: 0.40)
    addPixelProp("me_big_sprout_2", in: scene, at: CGPoint(x: w * 0.85, y: h * 0.56), scale: 0.38)
    addPixelProp("me_big_sprout_3", in: scene, at: CGPoint(x: w * 0.42, y: h * 0.18), scale: 0.35)
    addPixelProp("me_big_sprout_1", in: scene, at: CGPoint(x: w * 0.68, y: h * 0.72), scale: 0.36)

    // Feu de camp (48×96px → 0.35)
    addPixelProp("me_campfire", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.30), scale: 0.35)

    // Fallback anciens props si existants
    addPixelProp("forest_mushroom_1", in: scene, at: CGPoint(x: w * 0.25, y: h * 0.58), scale: 0.40)
    addPixelProp("forest_mushroom_2", in: scene, at: CGPoint(x: w * 0.75, y: h * 0.38), scale: 0.40)
    addPixelProp("forest_stump_1", in: scene, at: CGPoint(x: w * 0.38, y: h * 0.65), scale: 0.45)
}

    // MARK: - Forest Building Blocks

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

    // MARK: - Ruines de la Source (Acte II)

    private func buildRuins(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : dalle craquelée pixel art mix 3 dirts teintée rouge
        // sombre (ruines = pierre fragmentée corrompue par l'Aether).
        if let stone = PixelArtSprites.tiledFloor(
            tileNames: ["tile_dirt_1", "tile_dirt_2", "tile_dirt_3"],
            in: CGSize(width: w + 32, height: h + 32),
            tileScale: 2.0,
            tint: SKColor(red: 0.28, green: 0.10, blue: 0.06, alpha: 1)) {
            stone.position = CGPoint(x: -16, y: -16)
            stone.zPosition = -10
            add(stone, to: scene)
        } else {
            let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
            ground.fillColor = SKColor(red: 0.06, green: 0.03, blue: 0.04, alpha: 1)
            ground.strokeColor = .clear
            ground.position = CGPoint(x: 500, y: 500)
            ground.zPosition = -10
            add(ground, to: scene)
        }

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

        // Piliers brisés : sprite pixel art (column natif 16×32 →
        // scale dédié pour atteindre ~50pt iPhone, ~80pt iPad).
        // Bordures gauche/droite + 1 au centre pour cadrer l'arène.
        let columnScale = max(2.5, w / 200)   // 2.5 iPhone, 4.1 iPad
        let bonesScale = max(1.8, w / 280)
        let pillarData: [(CGFloat, CGFloat, Bool)] = [
            (0.10, 0.75, false), (0.22, 0.55, true),
            (0.78, 0.55, true),  (0.90, 0.75, false),
            (0.50, 0.85, false)
        ]
        for (px, py, fallen) in pillarData {
            let pos = CGPoint(x: w * px, y: h * py)
            if !fallen, let column = PixelArtSprites.still(
                name: "column_broken_1", scale: columnScale,
                anchor: CGPoint(x: 0.5, y: 0.0)) {
                column.position = pos
                column.zPosition = -3
                add(column, to: scene)
            } else {
                let pillar = makeBrokenPillar(fallen: fallen)
                pillar.position = pos
                add(pillar, to: scene)
            }
        }

        // Ossements éparpillés (ambiance "ruines mortes")
        let bonesLayout: [(x: CGFloat, y: CGFloat)] = [
            (0.30, 0.42), (0.65, 0.38), (0.45, 0.62), (0.55, 0.25)
        ]
        for p in bonesLayout {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: bonesScale,
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            bones.position = CGPoint(x: w * p.x, y: h * p.y)
            bones.zPosition = -2
            bones.alpha = 0.9
            add(bones, to: scene)
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

        // Sol : pierres sombres mix 3 dirts teintés violet pour casser
        // la grille monotone (sanctuaire = pierre ancienne mystique).
        if let stone = PixelArtSprites.tiledFloor(
            tileNames: ["tile_dirt_1", "tile_dirt_2", "tile_dirt_3"],
            in: CGSize(width: w + 32, height: h + 32),
            tileScale: 2.0,
            tint: SKColor(red: 0.22, green: 0.12, blue: 0.38, alpha: 1)) {
            stone.position = CGPoint(x: -16, y: -16)
            stone.zPosition = -10
            add(stone, to: scene)
        } else {
            let ground = SKShapeNode(rectOf: CGSize(width: 2_000, height: 2_000))
            ground.fillColor = SKColor(red: 0.04, green: 0.03, blue: 0.08, alpha: 1)
            ground.strokeColor = .clear
            ground.position = CGPoint(x: 500, y: 500)
            ground.zPosition = -10
            add(ground, to: scene)
        }

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

        // Statues anges pixel art encadrant l'autel — scale modéré pour
        // ne pas écraser la composition (~80 pt de haut).
        let statueScale = forestTreeScale(for: w) * 0.85
        for (i, asset) in ["angel_statue_1", "angel_statue_2"].enumerated() {
            if let statue = PixelArtSprites.still(name: asset, scale: statueScale,
                                                   anchor: CGPoint(x: 0.5, y: 0.0)) {
                let dx: CGFloat = i == 0 ? -70 : 70
                statue.position = CGPoint(x: altar.position.x + dx, y: altar.position.y - 30)
                statue.zPosition = -3
                statue.alpha = 0.95
                add(statue, to: scene)
            }
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
        gate.zPosition = propLayer(for: pos.y, in: scene.size.height)
        addGroundShadow(under: gate, width: width + 32, height: 14)

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
        well.zPosition = propLayer(for: pos.y, in: scene.size.height)
        addGroundShadow(under: well, width: 42, height: 16)

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

    private func addGroundShadow(under node: SKNode, width: CGFloat, height: CGFloat) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        shadow.fillColor = SKColor.black.withAlphaComponent(0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 3)
        shadow.zPosition = -0.5
        node.addChild(shadow)
    }

    private func actorLayer(for y: CGFloat) -> CGFloat {
        40 - y / 20
    }

    private func propLayer(for y: CGFloat, in sceneHeight: CGFloat) -> CGFloat {
        -2 - (y / max(sceneHeight, 1)) * 6
    }

    // MARK: - House Interiors

    func houseDoorPosition(for kind: HouseInteriorKind, in size: CGSize) -> CGPoint {
        let wh = worldHeight > 0 ? worldHeight : size.height
        switch kind {
        case .armory:
            return CGPoint(x: size.width * 0.50, y: wh * 0.50 + 12)
        case .apothecary:
            return CGPoint(x: size.width * 0.24, y: wh * 0.36 + 12)
        case .inn:
            return CGPoint(x: size.width * 0.76, y: wh * 0.36 + 12)
        }
    }

    func interiorExitPosition(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.50, y: size.height * 0.16)
    }

    func switchToInterior(_ kind: HouseInteriorKind, in scene: SKScene) {
        activeInterior = kind
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.035, green: 0.027, blue: 0.025, alpha: 1)
        buildInterior(kind, in: scene)
        kael.position = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.23)
        kael.zPosition = 20
    }

    func returnToVillageFromInterior(in scene: SKScene) {
        let previous = activeInterior
        activeInterior = nil
        clearBackdrop()
        scene.backgroundColor = SKColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1)
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = false }
        buildVillage(in: scene)
        layout(in: scene.size)
        if let previous {
            let door = houseDoorPosition(for: previous, in: scene.size)
            kael.position = CGPoint(x: door.x, y: max(58, door.y - 58))
            kael.zPosition = actorLayer(for: kael.position.y)
        }
    }

    private func buildInterior(_ kind: HouseInteriorKind, in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height
        let room = CGRect(x: w * 0.15, y: h * 0.16, width: w * 0.70, height: h * 0.66)

        let outerShadow = SKShapeNode(rectOf: CGSize(width: room.width + 12, height: room.height + 12), cornerRadius: 8)
        outerShadow.position = CGPoint(x: room.midX, y: room.midY - 4)
        outerShadow.fillColor = SKColor(white: 0, alpha: 0.32)
        outerShadow.strokeColor = .clear
        outerShadow.zPosition = -10
        add(outerShadow, to: scene)

        let floor = SKShapeNode(rectOf: room.size, cornerRadius: 8)
        floor.position = CGPoint(x: room.midX, y: room.midY)
        floor.fillColor = interiorFloorColor(for: kind)
        floor.strokeColor = SKColor(red: 0.42, green: 0.30, blue: 0.20, alpha: 0.75)
        floor.lineWidth = 3
        floor.zPosition = -9
        add(floor, to: scene)

        addInteriorFloorBoards(in: scene, room: room)
        addInteriorWallBand(in: scene, room: room, kind: kind)
        addInteriorExitDoor(in: scene, room: room)
        addInteriorTitle(kind, in: scene, room: room)

        switch kind {
        case .armory:
            buildArmoryInterior(in: scene, room: room)
        case .apothecary:
            buildApothecaryInterior(in: scene, room: room)
        case .inn:
            buildInnInterior(in: scene, room: room)
        }
    }

    private func interiorFloorColor(for kind: HouseInteriorKind) -> SKColor {
        switch kind {
        case .armory:
            return SKColor(red: 0.18, green: 0.13, blue: 0.10, alpha: 1)
        case .apothecary:
            return SKColor(red: 0.12, green: 0.16, blue: 0.11, alpha: 1)
        case .inn:
            return SKColor(red: 0.19, green: 0.12, blue: 0.08, alpha: 1)
        }
    }

    private func addInteriorFloorBoards(in scene: SKScene, room: CGRect) {
        for i in 0..<9 {
            let y = room.minY + CGFloat(i + 1) * room.height / 10
            let line = SKShapeNode(rectOf: CGSize(width: room.width - 20, height: 2), cornerRadius: 1)
            line.position = CGPoint(x: room.midX, y: y)
            line.fillColor = SKColor(white: 0, alpha: 0.10)
            line.strokeColor = .clear
            line.zPosition = -8
            add(line, to: scene)
        }
        for i in 0..<5 {
            let x = room.minX + CGFloat(i + 1) * room.width / 6
            let line = SKShapeNode(rectOf: CGSize(width: 2, height: room.height - 96), cornerRadius: 1)
            line.position = CGPoint(x: x, y: room.midY - 30)
            line.fillColor = SKColor(white: 1, alpha: 0.035)
            line.strokeColor = .clear
            line.zPosition = -8
            add(line, to: scene)
        }
    }

    private func addInteriorWallBand(in scene: SKScene, room: CGRect, kind: HouseInteriorKind) {
        let wallColor: SKColor
        switch kind {
        case .armory:
            wallColor = SKColor(red: 0.23, green: 0.18, blue: 0.15, alpha: 1)
        case .apothecary:
            wallColor = SKColor(red: 0.13, green: 0.22, blue: 0.15, alpha: 1)
        case .inn:
            wallColor = SKColor(red: 0.25, green: 0.16, blue: 0.10, alpha: 1)
        }
        let backWall = SKShapeNode(rectOf: CGSize(width: room.width, height: room.height * 0.22), cornerRadius: 8)
        backWall.position = CGPoint(x: room.midX, y: room.maxY - room.height * 0.11)
        backWall.fillColor = wallColor
        backWall.strokeColor = SKColor(white: 0.55, alpha: 0.14)
        backWall.lineWidth = 1
        backWall.zPosition = -7
        add(backWall, to: scene)
    }

    private func addInteriorExitDoor(in scene: SKScene, room: CGRect) {
        let exit = SKNode()
        exit.position = interiorExitPosition(in: scene.size)
        exit.name = "interiorExit"
        exit.zPosition = -1

        let mat = SKShapeNode(ellipseOf: CGSize(width: 64, height: 18))
        mat.fillColor = SKColor(red: 0.11, green: 0.075, blue: 0.045, alpha: 0.85)
        mat.strokeColor = SKColor(red: 0.55, green: 0.42, blue: 0.25, alpha: 0.5)
        mat.lineWidth = 1
        exit.addChild(mat)

        let icon = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        icon.text = String(localized: "interior.exit")
        icon.fontSize = 9
        icon.fontColor = SKColor(red: 0.92, green: 0.78, blue: 0.48, alpha: 0.9)
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = CGPoint(x: 0, y: -1)
        exit.addChild(icon)
        JuiceEngine.pulse(mat, scale: 1.06)

        add(exit, to: scene)
    }

    private func addInteriorTitle(_ kind: HouseInteriorKind, in scene: SKScene, room: CGRect) {
        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        switch kind {
        case .armory: title.text = String(localized: "interior.armory.title")
        case .apothecary: title.text = String(localized: "interior.apothecary.title")
        case .inn: title.text = String(localized: "interior.inn.title")
        }
        title.fontSize = 11
        title.fontColor = SKColor(red: 0.88, green: 0.78, blue: 0.58, alpha: 0.95)
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: room.midX, y: room.maxY - 36)
        title.zPosition = 4
        add(title, to: scene)
    }


    private func addInteriorSprite(_ name: String, in scene: SKScene, at position: CGPoint,
                                   scale: CGFloat, flipped: Bool = false) {
        guard let node = PixelArtSprites.still(name: name, scale: scale,
                                               anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        node.position = position
        if flipped { node.xScale = -abs(node.xScale == 0 ? 1 : node.xScale) }
        node.zPosition = propLayer(for: position.y, in: scene.size.height)
        addGroundShadow(under: node, width: 32 * scale, height: 8 * scale)
        add(node, to: scene)
    }

    private func buildArmoryInterior(in scene: SKScene, room: CGRect) {
        // Forge (fond centre) — braise rougeoyante
        let forge = SKShapeNode(rectOf: CGSize(width: 56, height: 28), cornerRadius: 4)
        forge.position = CGPoint(x: room.midX, y: room.maxY - 62)
        forge.fillColor = SKColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1)
        forge.strokeColor = SKColor(red: 0.40, green: 0.22, blue: 0.10, alpha: 0.8)
        forge.lineWidth = 2
        forge.zPosition = 2
        add(forge, to: scene)
        let ember = SKShapeNode(rectOf: CGSize(width: 36, height: 12), cornerRadius: 3)
        ember.position = CGPoint(x: room.midX, y: room.maxY - 60)
        ember.fillColor = SKColor(red: 0.85, green: 0.25, blue: 0.05, alpha: 0.7)
        ember.strokeColor = .clear
        ember.zPosition = 3
        add(ember, to: scene)
        JuiceEngine.pulse(ember, scale: 1.08)

        // Enclume (devant forge)
        let anvil = SKShapeNode(rectOf: CGSize(width: 22, height: 14), cornerRadius: 2)
        anvil.position = CGPoint(x: room.midX, y: room.maxY - 96)
        anvil.fillColor = SKColor(red: 0.28, green: 0.28, blue: 0.30, alpha: 1)
        anvil.strokeColor = SKColor(red: 0.45, green: 0.45, blue: 0.50, alpha: 0.6)
        anvil.lineWidth = 1
        anvil.zPosition = 3
        add(anvil, to: scene)

        // Râteliers d'armes (mur gauche)
        for i in 0..<3 {
            let sword = SKShapeNode(rectOf: CGSize(width: 3, height: 28), cornerRadius: 1)
            sword.position = CGPoint(x: room.minX + 32 + CGFloat(i) * 14, y: room.maxY - 50)
            sword.fillColor = SKColor(red: 0.55, green: 0.55, blue: 0.62, alpha: 0.9)
            sword.strokeColor = .clear
            sword.zPosition = 1
            add(sword, to: scene)
        }

        // Boucliers (mur droit)
        for i in 0..<2 {
            let shield = SKShapeNode(circleOfRadius: 10)
            shield.position = CGPoint(x: room.maxX - 40 + CGFloat(i) * 24, y: room.maxY - 48)
            shield.fillColor = SKColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 0.9)
            shield.strokeColor = SKColor(red: 0.55, green: 0.40, blue: 0.20, alpha: 0.7)
            shield.lineWidth = 2
            shield.zPosition = 1
            add(shield, to: scene)
        }

        // Tonneaux côté gauche
        addInteriorSprite("village_barrel_1", in: scene, at: CGPoint(x: room.minX + 30, y: room.midY + 6), scale: 0.50)
        addInteriorSprite("village_barrel_2", in: scene, at: CGPoint(x: room.minX + 56, y: room.midY + 6), scale: 0.45)

        // Caisses côté droit
        addInteriorSprite("village_crate_1", in: scene, at: CGPoint(x: room.maxX - 34, y: room.midY + 6), scale: 0.50)
        addInteriorSprite("village_crate_2", in: scene, at: CGPoint(x: room.maxX - 58, y: room.midY + 6), scale: 0.45)

        // Établi (milieu-bas)
        let workbench = SKShapeNode(rectOf: CGSize(width: 64, height: 20), cornerRadius: 3)
        workbench.position = CGPoint(x: room.midX, y: room.midY - 22)
        workbench.fillColor = SKColor(red: 0.30, green: 0.20, blue: 0.12, alpha: 1)
        workbench.strokeColor = SKColor(red: 0.42, green: 0.30, blue: 0.18, alpha: 0.7)
        workbench.lineWidth = 1
        workbench.zPosition = 3
        add(workbench, to: scene)

        addServiceMarker(in: scene, at: CGPoint(x: room.midX, y: room.maxY - 110), text: String(localized: "interior.armory.forge"))
    }

    private func buildApothecaryInterior(in scene: SKScene, room: CGRect) {
        // Comptoir herboriste (fond)
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX, y: room.maxY - 80), scale: 0.26)

        // Étagères potions (mur gauche)
        for i in 0..<3 {
            let shelf = SKShapeNode(rectOf: CGSize(width: 32, height: 6), cornerRadius: 1)
            shelf.position = CGPoint(x: room.minX + 36, y: room.maxY - 42 - CGFloat(i) * 18)
            shelf.fillColor = SKColor(red: 0.28, green: 0.20, blue: 0.12, alpha: 1)
            shelf.strokeColor = .clear
            shelf.zPosition = 1
            add(shelf, to: scene)
            // Fioles sur étagère
            for j in 0..<3 {
                let potion = SKShapeNode(rectOf: CGSize(width: 5, height: 9), cornerRadius: 2)
                potion.position = CGPoint(x: room.minX + 24 + CGFloat(j) * 12, y: room.maxY - 38 - CGFloat(i) * 18)
                let colors: [SKColor] = [
                    SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 0.85),
                    SKColor(red: 0.6, green: 0.2, blue: 0.7, alpha: 0.85),
                    SKColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.85)
                ]
                potion.fillColor = colors[(i + j) % 3]
                potion.strokeColor = .clear
                potion.zPosition = 2
                add(potion, to: scene)
            }
        }

        // Étagères (mur droit)
        for i in 0..<3 {
            let shelf = SKShapeNode(rectOf: CGSize(width: 32, height: 6), cornerRadius: 1)
            shelf.position = CGPoint(x: room.maxX - 36, y: room.maxY - 42 - CGFloat(i) * 18)
            shelf.fillColor = SKColor(red: 0.28, green: 0.20, blue: 0.12, alpha: 1)
            shelf.strokeColor = .clear
            shelf.zPosition = 1
            add(shelf, to: scene)
            // Livres/bocaux
            for j in 0..<2 {
                let book = SKShapeNode(rectOf: CGSize(width: 7, height: 10), cornerRadius: 1)
                book.position = CGPoint(x: room.maxX - 44 + CGFloat(j) * 16, y: room.maxY - 38 - CGFloat(i) * 18)
                book.fillColor = SKColor(red: 0.35 + CGFloat(j) * 0.15, green: 0.18, blue: 0.12, alpha: 0.9)
                book.strokeColor = .clear
                book.zPosition = 2
                add(book, to: scene)
            }
        }

        // Chaudron (centre)
        let cauldron = SKShapeNode(circleOfRadius: 14)
        cauldron.position = CGPoint(x: room.midX, y: room.midY - 8)
        cauldron.fillColor = SKColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
        cauldron.strokeColor = SKColor(red: 0.30, green: 0.30, blue: 0.35, alpha: 0.8)
        cauldron.lineWidth = 2
        cauldron.zPosition = 3
        add(cauldron, to: scene)
        let brew = SKShapeNode(circleOfRadius: 9)
        brew.position = CGPoint(x: room.midX, y: room.midY - 6)
        brew.fillColor = SKColor(red: 0.15, green: 0.55, blue: 0.25, alpha: 0.7)
        brew.strokeColor = .clear
        brew.zPosition = 4
        add(brew, to: scene)
        JuiceEngine.pulse(brew, scale: 1.05)

        // Plantes
        addInteriorSprite("interior_plant", in: scene, at: CGPoint(x: room.minX + 30, y: room.midY - 32), scale: 0.34)
        addInteriorSprite("interior_plant", in: scene, at: CGPoint(x: room.maxX - 30, y: room.midY - 32), scale: 0.34, flipped: true)

        // Herbes séchées (pendues au plafond)
        for i in 0..<4 {
            let herb = SKShapeNode(rectOf: CGSize(width: 4, height: 14), cornerRadius: 1)
            herb.position = CGPoint(x: room.midX - 30 + CGFloat(i) * 20, y: room.maxY - 30)
            herb.fillColor = SKColor(red: 0.22, green: 0.38, blue: 0.18, alpha: 0.8)
            herb.strokeColor = .clear
            herb.zPosition = 1
            add(herb, to: scene)
        }

        addServiceMarker(in: scene, at: CGPoint(x: room.midX, y: room.maxY - 110), text: String(localized: "interior.apothecary.potions"))
    }

    private func buildInnInterior(in scene: SKScene, room: CGRect) {
        // Comptoir/bar (fond droit)
        let bar = SKShapeNode(rectOf: CGSize(width: 70, height: 18), cornerRadius: 3)
        bar.position = CGPoint(x: room.maxX - 60, y: room.maxY - 68)
        bar.fillColor = SKColor(red: 0.32, green: 0.20, blue: 0.10, alpha: 1)
        bar.strokeColor = SKColor(red: 0.45, green: 0.30, blue: 0.15, alpha: 0.7)
        bar.lineWidth = 2
        bar.zPosition = 3
        add(bar, to: scene)

        // Fûts derrière le bar
        for i in 0..<3 {
            let keg = SKShapeNode(rectOf: CGSize(width: 12, height: 16), cornerRadius: 4)
            keg.position = CGPoint(x: room.maxX - 82 + CGFloat(i) * 18, y: room.maxY - 44)
            keg.fillColor = SKColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 1)
            keg.strokeColor = SKColor(red: 0.50, green: 0.35, blue: 0.18, alpha: 0.6)
            keg.lineWidth = 1
            keg.zPosition = 1
            add(keg, to: scene)
        }

        // Cheminée (fond gauche)
        let fireplace = SKShapeNode(rectOf: CGSize(width: 40, height: 32), cornerRadius: 3)
        fireplace.position = CGPoint(x: room.minX + 44, y: room.maxY - 54)
        fireplace.fillColor = SKColor(red: 0.16, green: 0.10, blue: 0.08, alpha: 1)
        fireplace.strokeColor = SKColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 0.8)
        fireplace.lineWidth = 2
        fireplace.zPosition = 1
        add(fireplace, to: scene)
        let fire = SKShapeNode(rectOf: CGSize(width: 24, height: 14), cornerRadius: 4)
        fire.position = CGPoint(x: room.minX + 44, y: room.maxY - 58)
        fire.fillColor = SKColor(red: 0.90, green: 0.45, blue: 0.08, alpha: 0.8)
        fire.strokeColor = .clear
        fire.zPosition = 2
        add(fire, to: scene)
        JuiceEngine.pulse(fire, scale: 1.10)

        // Table centrale avec chaises
        addInteriorSprite("interior_table", in: scene, at: CGPoint(x: room.midX - 20, y: room.midY - 6), scale: 0.65)
        addInteriorSprite("interior_chair", in: scene, at: CGPoint(x: room.midX - 48, y: room.midY - 12), scale: 0.45)
        addInteriorSprite("interior_chair", in: scene, at: CGPoint(x: room.midX + 8, y: room.midY - 12), scale: 0.45, flipped: true)

        // Seconde table (droite)
        let table2 = SKShapeNode(rectOf: CGSize(width: 32, height: 18), cornerRadius: 3)
        table2.position = CGPoint(x: room.maxX - 50, y: room.midY - 14)
        table2.fillColor = SKColor(red: 0.30, green: 0.20, blue: 0.12, alpha: 1)
        table2.strokeColor = SKColor(red: 0.42, green: 0.30, blue: 0.16, alpha: 0.6)
        table2.lineWidth = 1
        table2.zPosition = 3
        add(table2, to: scene)

        // Lits (alcôve gauche bas)
        addInteriorSprite("interior_bed", in: scene, at: CGPoint(x: room.minX + 42, y: room.midY - 34), scale: 0.26)
        addInteriorSprite("interior_bed", in: scene, at: CGPoint(x: room.minX + 42, y: room.midY - 58), scale: 0.26)

        // Tapis décoratif centre
        let rug = SKShapeNode(rectOf: CGSize(width: 60, height: 28), cornerRadius: 6)
        rug.position = CGPoint(x: room.midX, y: room.midY - 36)
        rug.fillColor = SKColor(red: 0.45, green: 0.15, blue: 0.10, alpha: 0.35)
        rug.strokeColor = SKColor(red: 0.55, green: 0.25, blue: 0.12, alpha: 0.3)
        rug.lineWidth = 1
        rug.zPosition = -6
        add(rug, to: scene)

        addServiceMarker(in: scene, at: CGPoint(x: room.maxX - 60, y: room.maxY - 92), text: String(localized: "interior.inn.rest"))
    }

    private func addServiceMarker(in scene: SKScene, at position: CGPoint, text: String) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = text
        label.fontSize = 9
        label.fontColor = SKColor(red: 0.96, green: 0.84, blue: 0.52, alpha: 0.9)
        label.horizontalAlignmentMode = .center
        label.position = position
        label.zPosition = 3
        add(label, to: scene)
        JuiceEngine.float(label, distance: 3)
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

    /// Acte II : Dorin garde personnellement la porte nord ; Garen relevé du poste.
    /// Évite le conflit de tap (Dorin/Garen étaient à <8% width l'un de l'autre).
    func repositionDorinToGate(in scene: SKScene) {
        dorin.position = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.72)
        garen.isHidden = true
    }

    // MARK: - Helpers

    private func add(_ node: SKNode, to scene: SKScene) {
        worldNode.addChild(node)
        backdropNodes.append(node)
    }

private func availableTiles(_ preferred: [String], fallback: [String]) -> [String] {
    let available = preferred.filter { PixelArtSprites.exists($0) }
    return available.isEmpty ? fallback : available
}

private func addTiledFloor(in scene: SKScene, tileNames: [String], fallbackColor: SKColor,
                           tileScale: CGFloat, tint: SKColor? = nil, z: CGFloat,
                           overrideSize: CGSize? = nil) {
    let available = availableTiles(tileNames, fallback: ["tile_grass", "tile_grass_dark"])
    let floorSize = overrideSize ?? CGSize(width: scene.size.width + 96,
                                            height: scene.size.height + 96)
    if let floor = PixelArtSprites.tiledFloor(tileNames: available,
                                              in: floorSize,
                                              tileScale: tileScale,
                                              tint: tint) {
        floor.position = CGPoint(x: -48, y: -48)
        floor.zPosition = z
        add(floor, to: scene)
    } else {
        let ground = SKShapeNode(rectOf: floorSize)
        ground.fillColor = fallbackColor
        ground.strokeColor = .clear
        ground.position = CGPoint(x: floorSize.width / 2, y: floorSize.height / 2)
        ground.zPosition = z
        add(ground, to: scene)
    }
}

private func addPixelProp(_ name: String, in scene: SKScene, at position: CGPoint,
                          scale: CGFloat, flipped: Bool = false) {
    guard let node = PixelArtSprites.still(name: name, scale: scale,
                                           anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
    node.position = position
    if flipped { node.xScale = -abs(node.xScale == 0 ? 1 : node.xScale) }
    node.zPosition = propLayer(for: position.y, in: scene.size.height)
    addGroundShadow(under: node, width: 34 * scale, height: 9 * scale)
    add(node, to: scene)
}

/// Trace un chemin de terre pixel art entre 2 points (vertical pour
/// la rue principale du village). Tiles dirt aleatoires pour variete.
/// Chemin construit à partir de tiles d'asset (me_path_1..6).
private func addCleanPath(in scene: SKScene, rect: CGRect) {
    let tileSize: CGFloat = 24  // 48px × 0.5 scale = 24pt par tile
    let cols = max(1, Int(ceil(rect.width / tileSize)))
    let rows = max(1, Int(ceil(rect.height / tileSize)))
    var rng = SystemRandomNumberGenerator()
    for r in 0..<rows {
        for c in 0..<cols {
            let idx = Int.random(in: 1...6, using: &rng)
            let pos = CGPoint(x: rect.minX + (CGFloat(c) + 0.5) * tileSize,
                              y: rect.minY + (CGFloat(r) + 0.5) * tileSize)
            guard let tile = PixelArtSprites.still(name: "me_path_\(idx)",
                                                    scale: 0.5,
                                                    anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
            tile.position = pos
            tile.zPosition = -8
            add(tile, to: scene)
        }
    }
}

private func addDirtPath(in scene: SKScene, from a: CGPoint, to b: CGPoint,
                          width: CGFloat) {
    let tiles = availableTiles(["ext_dirt_1", "ext_dirt_2", "ext_dirt_3"],
                               fallback: ["tile_dirt_1", "tile_dirt_2", "tile_dirt_3"])
    let length = hypot(b.x - a.x, b.y - a.y)
    guard length > 0 else { return }
    let tileScale: CGFloat = tiles.first?.hasPrefix("ext_") == true ? 0.55 : 1.5
    let stepSize: CGFloat = tiles.first?.hasPrefix("ext_") == true ? 22 : 20
    let count = Int(ceil(length / stepSize))
    for i in 0...count {
        let t = CGFloat(i) / CGFloat(count)
        let cx = a.x + (b.x - a.x) * t
        let cy = a.y + (b.y - a.y) * t
        for dx in stride(from: -width/2, through: width/2, by: stepSize) {
            let raw = (i + Int(dx)) % tiles.count
            let idx = (raw + tiles.count) % tiles.count
            let assetName = tiles[idx]
            guard let tile = PixelArtSprites.still(
                name: assetName, scale: tileScale,
                anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
            tile.position = CGPoint(x: cx + dx + CGFloat.random(in: -3...3),
                                     y: cy + CGFloat.random(in: -3...3))
            tile.zPosition = -9
            tile.alpha = 0.96
            add(tile, to: scene)
        }
    }
}

    /// Scale dynamique pour les sprites de maisons. Les assets Modern
    /// Exteriors font 288 px de large: en dessous de ~115 pt sur iPhone,
    /// la maison devient un accessoire. On cible donc une vraie masse de
    /// bâtiment tout en gardant 3 colonnes lisibles en portrait.
    private func buildingScale(for sceneWidth: CGFloat) -> CGFloat {
        let targetWidth = sceneWidth * 0.14
        let s = targetWidth / 288
        return max(0.12, min(0.22, s))
    }

    /// Pose un bâtiment de village : sprite pixel art si l'asset existe,
    /// sinon fallback sur le rectangle programmatique d'origine.
    /// Anchor (0.5, 0) → la position passée est le pied de la maison.
    private func addVillageBuilding(asset: String, scale: CGFloat,
                                     fallbackW: CGFloat, fallbackH: CGFloat,
                                     wallColor: SKColor, roofColor: SKColor,
                                     label: String?,
                                     at position: CGPoint, in scene: SKScene) {
        let node: SKNode
        if let sprite = PixelArtSprites.still(name: asset, scale: scale,
                                               anchor: CGPoint(x: 0.5, y: 0.0)) {
            node = sprite
            addGroundShadow(to: node, width: 160 * scale, height: 20 * scale, y: 4 * scale)
            // Enseigne au-dessus du sprite (offset adapté au scale)
            if let label {
                let sign = SKLabelNode(text: label)
                sign.fontSize = max(8, 14 * scale)
                sign.verticalAlignmentMode = .center
                sign.position = CGPoint(x: 0, y: 120 * scale)
                sign.zPosition = 3
                node.addChild(sign)
            }
        } else {
            node = makeBuilding(w: fallbackW, h: fallbackH,
                                 wallColor: wallColor, roofColor: roofColor,
                                 label: label)
            addGroundShadow(to: node, width: fallbackW * 1.15, height: 16, y: -fallbackH / 2)
        }
        node.position = position
        node.zPosition = propLayer(for: position.y, in: scene.size.height)
        add(node, to: scene)
    }

    private func addGroundShadow(to node: SKNode, width: CGFloat, height: CGFloat, y: CGFloat) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        shadow.fillColor = SKColor(white: 0.0, alpha: 0.24)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: y)
        shadow.zPosition = -2
        node.addChild(shadow)
    }

private func addDirtPatch(at center: CGPoint, size: CGSize, in scene: SKScene) {
    let tiles = availableTiles(["ext_dirt_1", "ext_dirt_2", "ext_dirt_3"],
                               fallback: ["tile_dirt_1", "tile_dirt_2", "tile_dirt_3"])
    let scale: CGFloat = tiles.first?.hasPrefix("ext_") == true ? 0.55 : 1.5
    guard let patch = PixelArtSprites.tiledFloor(tileNames: tiles, in: size,
                                                 tileScale: scale) else { return }
    patch.position = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
    patch.zPosition = -9
    patch.alpha = 0.94
    add(patch, to: scene)
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
        worldNode.addChild(node)
    }

    // MARK: - Sol plat (fond uni, sans tiles répétitives)

    private func addFlatGroundVillage(in scene: SKScene, size: CGSize) {
        let base = SKShapeNode(rectOf: size)
        base.fillColor = SKColor(red: 0.32, green: 0.55, blue: 0.28, alpha: 1)
        base.strokeColor = .clear
        base.position = CGPoint(x: size.width / 2 - 48, y: size.height / 2 - 48)
        base.zPosition = -10
        add(base, to: scene)
    }

    private func addFlatGroundForest(in scene: SKScene, size: CGSize) {
        let base = SKShapeNode(rectOf: size)
        base.fillColor = SKColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 1)
        base.strokeColor = .clear
        base.position = CGPoint(x: size.width / 2 - 48, y: size.height / 2 - 48)
        base.zPosition = -10
        add(base, to: scene)
    }
}
