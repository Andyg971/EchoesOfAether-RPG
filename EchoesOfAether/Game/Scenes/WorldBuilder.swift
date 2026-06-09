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

        // NPC sur chemin/devant leur shop selon nouveau layout village.
        // Maisons aux x=0.20-0.80, zones distinctes par rôle.
        lyra.position    = CGPoint(x: w * 0.30, y: wh * 0.76)  // devant Victorian (quartier haut)
        dorin.position   = CGPoint(x: w * 0.70, y: wh * 0.76)  // devant Haunted (quartier haut)
        bram.position    = CGPoint(x: w * 0.50, y: wh * 0.56)  // devant armurerie centre
        mara.position    = CGPoint(x: w * 0.30, y: wh * 0.52)  // devant herboriste
        sage.position    = CGPoint(x: w * 0.70, y: wh * 0.52)  // devant auberge
        garen.position   = CGPoint(x: w * 0.50, y: wh * 0.89)  // porte nord (sentinelle)
        child.position   = CGPoint(x: w * 0.42, y: wh * 0.42)  // joue sur place centrale
        villager.position = CGPoint(x: w * 0.58, y: wh * 0.42)  // place centrale
        kael.position    = CGPoint(x: w * 0.50, y: wh * 0.04)  // spawn entrée sud

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

    /// Acte III — Le Seuil. Royaume du Vide où Kael franchit la frontière.
    /// Décor 100% assets existants (statues, piliers, escalier, arbres morts).
    func switchToThreshold(in scene: SKScene) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.02, blue: 0.08, alpha: 1)
        buildThreshold(in: scene)
    }

    // MARK: - Village Solis

    /// VILLAGE SOLIS — design game-dev (assets uniquement)
    /// Layout vertical scrollable (worldHeight = 2.5x screen):
    ///   y=0-15%   ENTRÉE SUD (porte, panneau, allée principale)
    ///   y=15-30%  RÉSIDENTIEL BAS (2 maisons + jardins)
    ///   y=30-50%  PLACE CENTRALE (statue, marché, bancs, fontaine)
    ///   y=50-70%  ZONE COMMERÇANTE (armurier, herboriste, auberge)
    ///   y=70-90%  QUARTIER HAUT (maire + maisons hautes)
    ///   y=90-100% SORTIE NORD (porte fortifiée vers forêt)
    private func buildVillage(in scene: SKScene) {
        let w = scene.size.width
        // Monde paysage : écran court → on allonge le couloir vertical (×3.5)
        // pour que les zones respirent et que les maisons ne se chevauchent pas.
        let h = scene.size.height * 3.5
        worldHeight = h

        // ── SOL : A2 grass tile (vert uniforme avec brins d'herbe) ──
        addTiledFloor(in: scene,
                      tileNames: ["a2_grass"],
                      fallbackColor: SKColor(red: 0.36, green: 0.58, blue: 0.30, alpha: 1),
                      tileScale: 1.0,
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // ── CHEMIN PRINCIPAL : a2_dirt vertical centre (entrée→sortie) ──
        addAssetPath(in: scene, rect: CGRect(x: w * 0.46, y: 0, width: w * 0.08, height: h * 0.95),
                      tileName: "a2_dirt")

        // ── PLACE CENTRALE : a2_stone pavé (zone marché) ──
        addAssetPath(in: scene, rect: CGRect(x: w * 0.32, y: h * 0.38, width: w * 0.36, height: h * 0.10),
                      tileName: "a2_stone")

        // ── ÉTANG : a2_water (bord ouest) ──
        addAssetPath(in: scene, rect: CGRect(x: w * 0.02, y: h * 0.42, width: w * 0.08, height: h * 0.06),
                      tileName: "a2_water")

        decorateVillage(in: scene)

        let bScale = buildingScale(for: w)

        // ═══════════ MAISONS ═══════════
        // Quartier nord (y=0.85) : maisons importantes + maire
        buildNorthGate(at: CGPoint(x: w * 0.50, y: h * 0.95), width: 80, in: scene)
        addVillageBuilding(asset: "village_house_victorian", scale: bScale * 1.1,
                            fallbackW: 70, fallbackH: 55,
                            wallColor: SKColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.30, green: 0.50, blue: 0.35, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.20, y: h * 0.82), in: scene)
        addVillageBuilding(asset: "village_house_haunted", scale: bScale,
                            fallbackW: 90, fallbackH: 65,
                            wallColor: SKColor(red: 0.25, green: 0.20, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.50, green: 0.40, blue: 0.18, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.80, y: h * 0.82), in: scene)
        // Chalet maire au centre haut (entre 2 maisons, recule sur le chemin)
        addPixelProp("mv_chalet", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.78), scale: 0.30)

        // Zone commerçante (y=0.55-0.68)
        addVillageBuilding(asset: "village_house_armory", scale: bScale * 1.1,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.50, y: h * 0.63), in: scene)
        addVillageBuilding(asset: "village_house_japanese", scale: bScale * 1.2,
                            fallbackW: 62, fallbackH: 50,
                            wallColor: SKColor(red: 0.14, green: 0.22, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.22, green: 0.40, blue: 0.22, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.22, y: h * 0.58), in: scene)
        addVillageBuilding(asset: "village_house_inn", scale: bScale * 1.1,
                            fallbackW: 88, fallbackH: 62,
                            wallColor: SKColor(red: 0.20, green: 0.14, blue: 0.10, alpha: 1),
                            roofColor: SKColor(red: 0.45, green: 0.25, blue: 0.12, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.78, y: h * 0.58), in: scene)

        // Résidentiel bas (y=0.22) : maisons habitants
        addVillageBuilding(asset: "village_house_country", scale: bScale * 1.1,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.22, y: h * 0.22), in: scene)
        addVillageBuilding(asset: "village_house_modern", scale: bScale * 1.1,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1),
                            roofColor: SKColor(red: 0.30, green: 0.30, blue: 0.40, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.78, y: h * 0.22), in: scene)
        // Maison onestory déplacée à l'ouest (hors de l'axe central) pour
        // dégager l'approche sud vers la fontaine de la place.
        addVillageBuilding(asset: "village_house_onestory", scale: bScale * 1.2,
                            fallbackW: 62, fallbackH: 50,
                            wallColor: SKColor(red: 0.18, green: 0.16, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.35, green: 0.28, blue: 0.18, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.30, y: h * 0.15), in: scene)

        // Crystal save proche auberge (UX : safe spot évident)
        addSaveCrystal(at: CGPoint(x: w * 0.85, y: h * 0.50), in: scene)

        addAtmosphere(ParticleFactory.ambientDust(in: CGSize(width: w, height: h)), to: scene)
    }

    /// Helper : tile rect avec un asset donné (path, water, stone, etc.)
    private func addAssetPath(in scene: SKScene, rect: CGRect, tileName: String) {
        let tileSize: CGFloat = 24
        let cols = max(1, Int(ceil(rect.width / tileSize)))
        let rows = max(1, Int(ceil(rect.height / tileSize)))
        for r in 0..<rows {
            for c in 0..<cols {
                guard let tile = PixelArtSprites.still(name: tileName, scale: 0.5,
                                                        anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
                tile.position = CGPoint(x: rect.minX + (CGFloat(c) + 0.5) * tileSize,
                                         y: rect.minY + (CGFloat(r) + 0.5) * tileSize)
                tile.zPosition = -9.5
                add(tile, to: scene)
            }
        }
    }

    // MARK: - Forêt d'Ébène

    private func buildForest(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        let forestBase = SKShapeNode(rectOf: CGSize(width: w + 96, height: h + 96))
        forestBase.fillColor = SKColor(red: 0.12, green: 0.26, blue: 0.14, alpha: 1)
        forestBase.strokeColor = .clear
        forestBase.position = CGPoint(x: (w + 96) / 2 - 48, y: (h + 96) / 2 - 48)
        forestBase.zPosition = -11
        add(forestBase, to: scene)

        addTiledFloor(in: scene,
                      tileNames: ["me_landscape_grass"],
                      fallbackColor: SKColor(red: 0.12, green: 0.26, blue: 0.14, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.04, green: 0.14, blue: 0.06, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))
        addDirtPath(in: scene, from: CGPoint(x: w * 0.50, y: 0),
                    to: CGPoint(x: w * 0.58, y: h * 0.86),
                    width: 72)
        addDirtPatch(at: CGPoint(x: w * 0.48, y: h * 0.48),
                     size: CGSize(width: w * 0.28, height: h * 0.18),
                     in: scene)

// --- Arbres MV (T26 light + T27 dark forest) ---
        // MV trees natifs 144-192px : cible ~100pt iPhone / ~130pt iPad pour
        // une vraie canopée dense. L'ancien `* 0.55` donnait des arbres de 23pt.
        let treeScale = max(0.45, min(0.68, w / 760))
        let meTreeAssets = ["mv_forest_tree_1", "mv_forest_tree_2", "mv_forest_tree_3",
                            "mv_forest_tree_4", "mv_forest_tree_wide", "mv_forest_pines",
                            "mv_dark_tree", "mv_tall_pine", "mv_dead_tree",
                            "mv_oak_tree", "mv_apple_tree_tall"]

        // 2 statues angel dans clairières
        addPixelProp("me_angel_statue_1", in: scene, at: CGPoint(x: w * 0.30, y: h * 0.30), scale: 0.28)
        addPixelProp("me_angel_statue_2", in: scene, at: CGPoint(x: w * 0.70, y: h * 0.65), scale: 0.28)
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
            guard let tree = PixelArtSprites.still(name: "mv_dead_tree", scale: treeScale * p.scale,
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
            (0.08, 0.12, 1.7), (0.30, 0.11, 1.5), (0.72, 0.12, 1.6), (0.93, 0.11, 1.75)
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

    // Pose un groupe de props serrés autour d'un point (cohérence : on
    // regroupe ce qui va ensemble plutôt que d'éparpiller sur la pelouse).
    func group(_ items: [(String, CGFloat, CGFloat, CGFloat)], at c: CGPoint) {
        for (name, dx, dy, s) in items {
            addPixelProp(name, in: scene,
                         at: CGPoint(x: c.x + w * dx, y: c.y + h * dy), scale: s)
        }
    }

    // ═══ ENTRÉE SUD — portail d'accueil serré contre le chemin ═══
    group([("me_sign_1", -0.05, 0.005, 0.40), ("me_sign_2", 0.05, 0.005, 0.40),
           ("me_lamp_1", -0.05, 0.055, 0.26), ("me_lamp_1", 0.05, 0.055, 0.26),
           ("me_flower_red", -0.02, 0.03, 0.32), ("me_flower_yellow", 0.02, 0.03, 0.32)],
          at: CGPoint(x: w * 0.50, y: h * 0.045))
    addPixelProp("mv_tree_potted", in: scene, at: CGPoint(x: w * 0.40, y: h * 0.12), scale: 0.42)
    addPixelProp("mv_tree_alt", in: scene, at: CGPoint(x: w * 0.60, y: h * 0.12), scale: 0.42)

    // ═══ RÉSIDENTIEL BAS — chaque maison a SA cour (props collés au pied) ═══
    // Country (gauche) : boîte aux lettres côté chemin, massif + nichoir.
    group([("me_mailbox_1", 0.05, -0.035, 0.28), ("me_hanging_flowers", -0.05, -0.05, 0.30),
           ("me_flower_pink", -0.02, -0.055, 0.32), ("me_flower_white", 0.02, -0.05, 0.32),
           ("me_birdhouse_brown", -0.06, -0.02, 0.30)],
          at: CGPoint(x: w * 0.22, y: h * 0.22))
    // Modern (droite) : symétrique + banc devant la porte.
    group([("me_mailbox_1", -0.05, -0.035, 0.28), ("me_hanging_flowers", 0.05, -0.05, 0.30),
           ("me_flower_blue", 0.02, -0.055, 0.32), ("me_flower_yellow", -0.02, -0.05, 0.32),
           ("me_garden_bench", 0.06, -0.02, 0.30)],
          at: CGPoint(x: w * 0.78, y: h * 0.22))
    // Cour de la maison onestory (ouest, près de l'entrée).
    group([("mv_garden_bed", 0.0, -0.045, 0.34), ("me_birdhouse_blue", -0.05, -0.02, 0.30),
           ("me_flower_white", 0.04, -0.05, 0.30), ("me_birdhouse_big", -0.05, -0.05, 0.30)],
          at: CGPoint(x: w * 0.30, y: h * 0.15))
    // Approche sud de la place : massifs fleuris encadrant le chemin (mène l'œil à la fontaine).
    group([("mv_flowers_row", -0.09, 0.0, 0.30), ("me_flower_red", -0.12, 0.012, 0.30),
           ("mv_flowers_row", 0.09, 0.0, 0.30), ("me_flower_yellow", 0.12, 0.012, 0.30)],
          at: CGPoint(x: w * 0.50, y: h * 0.34))

    // ═══ PLACE CENTRALE — fontaine au cœur, bancs en cercle, lampes aux coins ═══
    addPixelProp("village_fountain", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.43), scale: 0.62)
    group([("me_bench_1", -0.07, -0.045, 0.30), ("me_bench_2", 0.07, -0.045, 0.30),
           ("me_garden_bench", -0.07, 0.04, 0.30), ("me_bench_3", 0.07, 0.04, 0.30),
           ("me_lamp_2", -0.10, -0.05, 0.24), ("me_lamp_2", 0.10, -0.05, 0.24),
           ("me_lamp_2", -0.10, 0.05, 0.24), ("me_lamp_2", 0.10, 0.05, 0.24),
           ("me_vase_red", -0.10, 0.0, 0.28), ("me_vase_sunflower", 0.10, 0.0, 0.28)],
          at: CGPoint(x: w * 0.50, y: h * 0.43))

    // ═══ MARCHÉ — UN seul étal regroupé sur le pavé ouest de la place ═══
    group([("me_wood_cart", 0.0, 0.0, 0.34), ("village_crate_1", -0.04, -0.025, 0.30),
           ("village_crate_2", 0.04, -0.02, 0.30), ("me_barrel_1", -0.05, 0.02, 0.30),
           ("me_basket", 0.03, 0.025, 0.28), ("me_apples", 0.0, 0.035, 0.26)],
          at: CGPoint(x: w * 0.29, y: h * 0.44))

    // ═══ COMMERÇANTE — props serrés devant chaque échoppe ═══
    // Herboriste (Mara) : potager CLÔTURÉ devant la maison japonaise.
    addFenceRect(in: scene, at: CGPoint(x: w * 0.20, y: h * 0.53),
                 size: CGSize(width: w * 0.14, height: h * 0.06))
    group([("me_vase_red", -0.04, 0.01, 0.30), ("me_vase_yellow", 0.04, 0.01, 0.30),
           ("me_mushrooms_1", -0.04, -0.01, 0.28), ("me_big_sprout_4", 0.04, -0.01, 0.30),
           ("me_mushrooms_2", 0.0, 0.0, 0.28)],
          at: CGPoint(x: w * 0.20, y: h * 0.53))
    // Auberge (Sage) : tonneaux, marmite, lanterne, stand.
    group([("me_barrel_3", -0.04, -0.03, 0.30), ("me_barrel_4", 0.04, -0.03, 0.30),
           ("me_hanging_pot", 0.0, -0.045, 0.30), ("village_lantern_1", 0.07, -0.02, 0.32),
           ("me_lemonade_stand", -0.07, -0.06, 0.34)],
          at: CGPoint(x: w * 0.78, y: h * 0.58))
    // Armurier (Bram) : bois empilé + tonneaux devant la forge.
    group([("me_cut_wood", -0.04, -0.035, 0.30), ("me_cut_wood_2", 0.04, -0.035, 0.30),
           ("me_barrel_1", -0.06, -0.05, 0.30), ("me_barrel_2", 0.06, -0.05, 0.30),
           ("me_cut_wood_bench", 0.0, -0.055, 0.30)],
          at: CGPoint(x: w * 0.50, y: h * 0.63))

    // ═══ QUARTIER HAUT — mairie civique : 2 anges encadrent le chalet ═══
    addPixelProp("me_angel_statue_1", in: scene, at: CGPoint(x: w * 0.40, y: h * 0.78), scale: 0.24)
    addPixelProp("me_angel_statue_2", in: scene, at: CGPoint(x: w * 0.60, y: h * 0.78), scale: 0.24)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.43, y: h * 0.74), scale: 0.24)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.57, y: h * 0.74), scale: 0.24)
    group([("me_mailbox_1", 0.05, -0.035, 0.28), ("me_hanging_flowers", -0.04, -0.05, 0.30),
           ("me_flower_red", -0.02, -0.055, 0.32)],
          at: CGPoint(x: w * 0.20, y: h * 0.82))
    group([("me_mailbox_1", -0.05, -0.035, 0.28), ("me_hanging_flowers", 0.04, -0.05, 0.30),
           ("me_flower_blue", 0.02, -0.055, 0.32)],
          at: CGPoint(x: w * 0.80, y: h * 0.82))

    // ═══ SORTIE NORD — porte gardée : statues + lampes + panneau ═══
    addPixelProp("me_statue_angel", in: scene, at: CGPoint(x: w * 0.40, y: h * 0.93), scale: 0.30)
    addPixelProp("me_statue_grey", in: scene, at: CGPoint(x: w * 0.60, y: h * 0.93), scale: 0.30)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.44, y: h * 0.91), scale: 0.24)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.56, y: h * 0.91), scale: 0.24)
    addPixelProp("me_sign_3", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.97), scale: 0.36)

    // ═══ FERME (coin est) — champ + potager CLÔTURÉS, grange, épouvantail ═══
    addFenceRect(in: scene, at: CGPoint(x: w * 0.90, y: h * 0.37),
                 size: CGSize(width: w * 0.14, height: h * 0.12))
    group([("mv_field", 0.0, 0.02, 0.40), ("mv_garden_bed", 0.0, -0.04, 0.34),
           ("mv_flowers_row", 0.0, 0.05, 0.30)],
          at: CGPoint(x: w * 0.90, y: h * 0.37))
    addPixelProp("me_wood_storage", in: scene, at: CGPoint(x: w * 0.92, y: h * 0.48), scale: 0.42)
    addPixelProp("me_statue_grass_1", in: scene, at: CGPoint(x: w * 0.85, y: h * 0.30), scale: 0.26)

    // ═══ ÉTANG OUEST — roseaux au bord de l'eau ═══
    group([("me_big_sprout_1", 0.02, 0.01, 0.32), ("me_big_sprout_2", 0.03, -0.01, 0.30),
           ("me_mushrooms_1", 0.04, 0.02, 0.26)],
          at: CGPoint(x: w * 0.07, y: h * 0.45))

    // ═══ BORDURES forêt (gauche dense, droite plus clairsemée) ═══
    let leftTrees: [(String, CGFloat)] = [
        ("mv_forest_tree_1", 0.10), ("mv_forest_tree_2", 0.20),
        ("mv_forest_tree_3", 0.30), ("mv_forest_tree_4", 0.40),
        ("mv_forest_pines", 0.52), ("mv_dark_tree", 0.64),
        ("mv_oak_tree", 0.74), ("mv_forest_tree_wide", 0.86),
        ("mv_apple_tree_tall", 0.95)
    ]
    for (asset, y) in leftTrees {
        addPixelProp(asset, in: scene, at: CGPoint(x: w * 0.045, y: h * y), scale: 0.34)
    }
    let rightTrees: [(String, CGFloat)] = [
        ("mv_forest_tree_2", 0.10), ("mv_apple_tree_tall", 0.22),
        ("mv_oak_tree", 0.68), ("mv_forest_tree_3", 0.90)
    ]
    for (asset, y) in rightTrees {
        addPixelProp(asset, in: scene, at: CGPoint(x: w * 0.955, y: h * y), scale: 0.34)
    }
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

    /// LE SEUIL (Acte III) — arène finale. Uniquement des assets existants :
    /// sol pierre teinté vide, escalier central (le Seuil), statues d'anges
    /// gardiens, piliers, arbres morts et ossements. Aucune forme custom.
    private func buildThreshold(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : pierre a2 teintée bleu-vide très sombre
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.06, green: 0.05, blue: 0.12, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.16, green: 0.13, blue: 0.30, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Titre de zone
        let zoneLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        zoneLabel.text = String(localized: "world.threshold.title")
        zoneLabel.fontSize = 11
        zoneLabel.fontColor = SKColor(red: 0.55, green: 0.45, blue: 0.85, alpha: 0.65)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.93)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        let statueScale = max(2.2, w / 220)
        let pillarScale = max(2.5, w / 200)
        let treeScale   = max(0.30, w / 1300)
        let bonesScale  = max(1.8, w / 280)

        // ── LE SEUIL : escalier central qui monte vers le Vide ──
        addPixelProp("me_stairs", in: scene,
                     at: CGPoint(x: w * 0.50, y: h * 0.84), scale: max(0.5, w / 760))

        // Statues d'anges gardiens flanquant le Seuil
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.34, y: h * 0.82), scale: statueScale)
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.66, y: h * 0.82), scale: statueScale, flipped: true)

        // Allée de piliers (gauche / droite) cadrant l'arène
        let pillarRows: [CGFloat] = [0.40, 0.55, 0.70]
        for (i, py) in pillarRows.enumerated() {
            let leftName = i % 2 == 0 ? "pillar_grey_1" : "column_broken_1"
            let rightName = i % 2 == 0 ? "pillar_grey_2" : "column_broken_1"
            addPixelProp(leftName, in: scene,
                         at: CGPoint(x: w * 0.13, y: h * py), scale: pillarScale)
            addPixelProp(rightName, in: scene,
                         at: CGPoint(x: w * 0.87, y: h * py), scale: pillarScale)
        }

        // Lanternes spectrales près du Seuil
        addPixelProp("village_lantern_1", in: scene,
                     at: CGPoint(x: w * 0.42, y: h * 0.74), scale: max(0.4, w / 900))
        addPixelProp("village_lantern_1", in: scene,
                     at: CGPoint(x: w * 0.58, y: h * 0.74), scale: max(0.4, w / 900), flipped: true)

        // Arbres morts dans les coins (le Vide consume la vie)
        addPixelProp("mv_dead_tree", in: scene,
                     at: CGPoint(x: w * 0.10, y: h * 0.28), scale: treeScale)
        addPixelProp("mv_dark_tree", in: scene,
                     at: CGPoint(x: w * 0.90, y: h * 0.30), scale: treeScale)

        // Ossements épars (les âmes absorbées)
        for p in [(0.30, 0.45), (0.66, 0.42), (0.48, 0.30)] {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: bonesScale,
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            bones.position = CGPoint(x: w * p.0, y: h * p.1)
            bones.zPosition = -2
            bones.alpha = 0.85
            add(bones, to: scene)
        }

        // Marqueur de rencontre Eran (centre) — réutilise makeDangerZone (bleu)
        let eranMark = makeDangerZone(
            at: CGPoint(x: w * 0.50, y: h * 0.62), radius: 34,
            color: SKColor(red: 0.40, green: 0.55, blue: 0.95, alpha: 1))
        add(eranMark, to: scene)

        // Cristal de sauvegarde (entrée du Seuil, bas droite)
        addSaveCrystal(at: CGPoint(x: w * 0.85, y: h * 0.20), in: scene)

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
            return CGPoint(x: size.width * 0.50, y: wh * 0.63 + 12)
        case .apothecary:
            return CGPoint(x: size.width * 0.22, y: wh * 0.58 + 12)
        case .inn:
            return CGPoint(x: size.width * 0.78, y: wh * 0.58 + 12)
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
        // Comptoir armurier (fond)
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX, y: room.maxY - 70), scale: 0.28)

        // Tonneaux + caisses (assets)
        addInteriorSprite("me_barrel_1", in: scene, at: CGPoint(x: room.minX + 32, y: room.maxY - 50), scale: 0.40)
        addInteriorSprite("me_barrel_2", in: scene, at: CGPoint(x: room.minX + 56, y: room.maxY - 52), scale: 0.36)
        addInteriorSprite("me_barrel_3", in: scene, at: CGPoint(x: room.maxX - 32, y: room.maxY - 50), scale: 0.40)
        addInteriorSprite("me_barrel_4", in: scene, at: CGPoint(x: room.maxX - 56, y: room.maxY - 52), scale: 0.36)

        // Bois empilé + banc bois coupé
        addInteriorSprite("me_cut_wood_2", in: scene, at: CGPoint(x: room.minX + 36, y: room.midY - 10), scale: 0.40)
        addInteriorSprite("me_cut_wood_bench", in: scene, at: CGPoint(x: room.maxX - 36, y: room.midY - 10), scale: 0.40)

        // Établi central (asset bench_table)
        addInteriorSprite("interior_bench_table", in: scene, at: CGPoint(x: room.midX, y: room.midY - 30), scale: 0.55)

        // Marmite (assimile à forge)
        addInteriorSprite("me_hanging_pot", in: scene, at: CGPoint(x: room.midX, y: room.maxY - 110), scale: 0.40)

        addServiceMarker(in: scene, at: CGPoint(x: room.midX, y: room.maxY - 130), text: String(localized: "interior.armory.forge"))
    }

    private func buildApothecaryInterior(in scene: SKScene, room: CGRect) {
        // Comptoir herboriste
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX, y: room.maxY - 70), scale: 0.26)

        // Plantes en pots assets
        addInteriorSprite("me_vase_red", in: scene, at: CGPoint(x: room.minX + 30, y: room.maxY - 55), scale: 0.40)
        addInteriorSprite("me_vase_pink", in: scene, at: CGPoint(x: room.maxX - 30, y: room.maxY - 55), scale: 0.40)
        addInteriorSprite("me_vase_yellow", in: scene, at: CGPoint(x: room.minX + 30, y: room.midY + 5), scale: 0.40)
        addInteriorSprite("me_vase_sunflower", in: scene, at: CGPoint(x: room.maxX - 30, y: room.midY + 5), scale: 0.40)

        // Plantes assets
        addInteriorSprite("interior_plant", in: scene, at: CGPoint(x: room.minX + 55, y: room.midY - 10), scale: 0.40)
        addInteriorSprite("interior_plant", in: scene, at: CGPoint(x: room.maxX - 55, y: room.midY - 10), scale: 0.40, flipped: true)

        // Table potions (asset)
        addInteriorSprite("interior_potion_table", in: scene, at: CGPoint(x: room.midX, y: room.midY - 25), scale: 0.42)

        // Champignons assets (botaniste)
        addInteriorSprite("me_mushrooms_1", in: scene, at: CGPoint(x: room.minX + 50, y: room.midY - 35), scale: 0.40)
        addInteriorSprite("me_mushrooms_2", in: scene, at: CGPoint(x: room.maxX - 50, y: room.midY - 35), scale: 0.40)

        // Pousses
        addInteriorSprite("me_big_sprout_4", in: scene, at: CGPoint(x: room.midX - 30, y: room.midY - 50), scale: 0.40)
        addInteriorSprite("me_big_sprout_5", in: scene, at: CGPoint(x: room.midX + 30, y: room.midY - 50), scale: 0.40)

        addServiceMarker(in: scene, at: CGPoint(x: room.midX, y: room.maxY - 130), text: String(localized: "interior.apothecary.potions"))
    }

    private func buildInnInterior(in scene: SKScene, room: CGRect) {
        // Comptoir/bar (asset counter)
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.maxX - 60, y: room.maxY - 70), scale: 0.32)

        // Tonneaux derrière bar
        addInteriorSprite("me_barrel_1", in: scene, at: CGPoint(x: room.maxX - 90, y: room.maxY - 50), scale: 0.36)
        addInteriorSprite("me_barrel_2", in: scene, at: CGPoint(x: room.maxX - 70, y: room.maxY - 50), scale: 0.36)
        addInteriorSprite("me_barrel_3", in: scene, at: CGPoint(x: room.maxX - 30, y: room.maxY - 50), scale: 0.36)

        // Paniers + pommes (auberge nourriture)
        addInteriorSprite("me_basket", in: scene, at: CGPoint(x: room.minX + 80, y: room.maxY - 65), scale: 0.40)
        addInteriorSprite("me_apples", in: scene, at: CGPoint(x: room.minX + 105, y: room.maxY - 70), scale: 0.36)

        // Cheminée — marmite suspendue + bois
        addInteriorSprite("me_hanging_pot", in: scene, at: CGPoint(x: room.minX + 44, y: room.maxY - 60), scale: 0.45)
        addInteriorSprite("me_cut_wood_2", in: scene, at: CGPoint(x: room.minX + 44, y: room.maxY - 85), scale: 0.36)

        // Table centrale + chaises
        addInteriorSprite("interior_table", in: scene, at: CGPoint(x: room.midX - 20, y: room.midY - 6), scale: 0.65)
        addInteriorSprite("interior_chair", in: scene, at: CGPoint(x: room.midX - 48, y: room.midY - 12), scale: 0.45)
        addInteriorSprite("interior_chair", in: scene, at: CGPoint(x: room.midX + 8, y: room.midY - 12), scale: 0.45, flipped: true)

        // Lits (chambres)
        addInteriorSprite("interior_bed", in: scene, at: CGPoint(x: room.minX + 42, y: room.midY - 34), scale: 0.28)
        addInteriorSprite("interior_bed", in: scene, at: CGPoint(x: room.minX + 42, y: room.midY - 58), scale: 0.28)

        // Banc bois
        addInteriorSprite("interior_wood_bench", in: scene, at: CGPoint(x: room.maxX - 50, y: room.midY - 20), scale: 0.45)

        addServiceMarker(in: scene, at: CGPoint(x: room.maxX - 60, y: room.maxY - 100), text: String(localized: "interior.inn.rest"))
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
/// Chemin construit à partir de tiles de terre uniformes (me_dirt_clean_*).
private func addCleanPath(in scene: SKScene, rect: CGRect) {
    let tileSize: CGFloat = 24  // 48px × 0.5 scale
    let cols = max(1, Int(ceil(rect.width / tileSize)))
    let rows = max(1, Int(ceil(rect.height / tileSize)))
    var rng = SystemRandomNumberGenerator()
    let dirtTiles = ["me_dirt_clean_1", "me_dirt_clean_2"]
    for r in 0..<rows {
        for c in 0..<cols {
            let name = dirtTiles[Int.random(in: 0..<dirtTiles.count, using: &rng)]
            let pos = CGPoint(x: rect.minX + (CGFloat(c) + 0.5) * tileSize,
                              y: rect.minY + (CGFloat(r) + 0.5) * tileSize)
            guard let tile = PixelArtSprites.still(name: name,
                                                    scale: 0.5,
                                                    anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
            tile.position = pos
            tile.zPosition = -9.8
            add(tile, to: scene)
        }
    }
}

private func addDirtPath(in scene: SKScene, from a: CGPoint, to b: CGPoint,
                          width: CGFloat) {
    // Sentier de terre PLEINE (a2_dirt opaque) au lieu des décals
    // transparents ext_dirt (mottes + pousses) qui jonchaient le sol.
    let tiles = availableTiles(["a2_dirt"],
                               fallback: ["tile_dirt_1", "tile_dirt_2", "tile_dirt_3"])
    let length = hypot(b.x - a.x, b.y - a.y)
    guard length > 0 else { return }
    let tileScale: CGFloat = 0.9   // 48px → ~43pt, sol plein et crisp
    let stepSize: CGFloat = 18
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

    /// Scale des sprites de maisons. Les assets font 576-1200 px de haut ;
    /// en paysage le monde est court, donc on plafonne bas (~0.14 iPhone,
    /// ~0.16 iPad) pour des maisons de ~110-170 pt qui n'écrasent pas la
    /// colonne verticale ni ne masquent la place centrale.
    private func buildingScale(for sceneWidth: CGFloat) -> CGFloat {
        max(0.11, min(0.16, sceneWidth / 6000))
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
    // Clairière de terre pleine (a2_dirt) au lieu des décals transparents.
    let tiles = availableTiles(["a2_dirt"],
                               fallback: ["tile_dirt_1", "tile_dirt_2", "tile_dirt_3"])
    let scale: CGFloat = 0.9
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

    // MARK: - Clôture (rectangle d'assets fence ME)
    private func addFenceRect(in scene: SKScene, at center: CGPoint, size: CGSize) {
        let tile: CGFloat = 16  // 48px × 0.33
        let scale: CGFloat = 0.33
        let halfW = size.width / 2
        let halfH = size.height / 2
        let cols = max(2, Int(size.width / tile))
        let rows = max(2, Int(size.height / tile))

        // Top + bottom
        for c in 0..<cols {
            let x = center.x - halfW + (CGFloat(c) + 0.5) * tile
            let name = c == 0 ? "me_fence_top_left" : (c == cols - 1 ? "me_fence_top_right" : "me_fence_top_mid")
            if let t = PixelArtSprites.still(name: name, scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: x, y: center.y + halfH)
                t.zPosition = -3
                add(t, to: scene)
            }
            let nb = c == 0 ? "me_fence_bot_left" : (c == cols - 1 ? "me_fence_bot_right" : "me_fence_bot_mid")
            if let t = PixelArtSprites.still(name: nb, scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: x, y: center.y - halfH)
                t.zPosition = -3
                add(t, to: scene)
            }
        }
        // Sides (middle row only — skip corners already placed)
        for r in 1..<(rows - 1) {
            let y = center.y - halfH + (CGFloat(r) + 0.5) * tile
            if let t = PixelArtSprites.still(name: "me_fence_mid_left", scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: center.x - halfW, y: y)
                t.zPosition = -3
                add(t, to: scene)
            }
            if let t = PixelArtSprites.still(name: "me_fence_mid_right", scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: center.x + halfW, y: y)
                t.zPosition = -3
                add(t, to: scene)
            }
        }
    }

    // MARK: - Étang (rectangle tiles eau asset)
    private func addWaterPond(in scene: SKScene, at center: CGPoint, size: CGSize) {
        let tile: CGFloat = 24  // 48px × 0.5
        let cols = max(1, Int(ceil(size.width / tile)))
        let rows = max(1, Int(ceil(size.height / tile)))
        let halfW = size.width / 2
        let halfH = size.height / 2
        for r in 0..<rows {
            for c in 0..<cols {
                guard let t = PixelArtSprites.still(name: "me_landscape_water",
                                                     scale: 0.5,
                                                     anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
                t.position = CGPoint(x: center.x - halfW + (CGFloat(c) + 0.5) * tile,
                                      y: center.y - halfH + (CGFloat(r) + 0.5) * tile)
                t.zPosition = -9.5
                add(t, to: scene)
            }
        }
    }
}
