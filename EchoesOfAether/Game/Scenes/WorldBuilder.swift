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
    /// Vrai pendant la veille du réveil : Lyra reste au chevet de Kael
    /// même si `layout()` est rejoué (rotation, resize, premier layout).
    private var lyraKeepsVigil = false

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

        // NPC sur chemin/devant leur lieu de vie selon le plan du village.
        if lyraKeepsVigil {
            placeLyraBesideKael(in: size)                      // réveil : au chevet
        } else {
            lyra.position = CGPoint(x: w * 0.40, y: wh * 0.43) // place, côté marché
        }
        dorin.position   = CGPoint(x: w * 0.56, y: wh * 0.88)  // approche porte nord
        bram.position    = CGPoint(x: w * 0.46, y: wh * 0.60)  // devant l'armurerie
        mara.position    = CGPoint(x: w * 0.27, y: wh * 0.555) // devant l'herboriste
        sage.position    = CGPoint(x: w * 0.73, y: wh * 0.555) // devant l'auberge
        garen.position   = CGPoint(x: w * 0.50, y: wh * 0.925) // porte nord (sentinelle)
        child.position   = CGPoint(x: w * 0.45, y: wh * 0.375) // joue près de la fontaine
        villager.position = CGPoint(x: w * 0.57, y: wh * 0.415) // place centrale
        kael.position    = CGPoint(x: w * 0.485, y: wh * 0.10) // spawn devant sa maison

        [lyra, dorin, bram, mara, sage, garen, child, villager, kael].forEach {
            $0.zPosition = actorLayer(for: $0.position.y)
        }
    }

    /// Réveil (phase wake) : Lyra veille au chevet de Kael devant sa
    /// maison, au lieu d'attendre à son poste de la place centrale.
    func placeLyraBesideKael(in size: CGSize) {
        lyraKeepsVigil = true
        let wh = worldHeight > 0 ? worldHeight : size.height
        lyra.position = CGPoint(x: size.width * 0.44, y: wh * 0.105)
        lyra.zPosition = actorLayer(for: lyra.position.y)
    }

    /// Fin de la veille : Lyra reprend son poste au prochain `layout()`.
    func endLyraVigil() {
        lyraKeepsVigil = false
    }

    // MARK: - Lyra compagne (forêt, sanctuaire, ruines)

    /// Fait apparaître Lyra aux côtés de Kael (elle l'accompagne dans
    /// les zones du pacte — le scénario la met à ses côtés).
    func showLyraCompanion() {
        lyra.isHidden = false
        lyra.position = CGPoint(x: kael.position.x - 46, y: kael.position.y - 8)
        lyra.zPosition = actorLayer(for: lyra.position.y)
    }

    /// Suivi doux : Lyra marche derrière Kael quand il s'éloigne.
    func updateLyraFollow(deltaTime: TimeInterval) {
        guard !lyra.isHidden, deltaTime > 0 else { return }
        let target = CGPoint(x: kael.position.x - 40, y: kael.position.y - 6)
        let dx = target.x - lyra.position.x
        let dy = target.y - lyra.position.y
        let dist = (dx * dx + dy * dy).squareRoot()
        guard dist > 54 else { return }
        let step = min(CGFloat(deltaTime) * 240, dist - 44)
        lyra.position.x += dx / dist * step
        lyra.position.y += dy / dist * step
        lyra.zPosition = actorLayer(for: lyra.position.y)
    }

    /// Recalcule la profondeur de Kael (déplacement continu au pad).
    func refreshKaelDepth() {
        kael.zPosition = actorLayer(for: kael.position.y)
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
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.06, blue: 0.04, alpha: 1)
        buildForest(in: scene)   // définit worldHeight (trek scrollable)
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

    /// VILLAGE SOLIS — vrai plan de village (assets Modern Exteriors).
    /// Monde vertical scrollable (worldHeight = 4.2× écran paysage),
    /// maisons à l'échelle des personnages, chemins de terre autotilés
    /// (transitions herbe/terre), étang avec berges, cours clôturées.
    ///   y=0-7%    ENTRÉE SUD (portail, panneau, allée)
    ///   y=7-25%   RÉSIDENTIEL (maison de Kael + 2 maisons + ferme est)
    ///   y=32-48%  PLACE CENTRALE (fontaine, marché, bancs) + ÉTANG ouest
    ///   y=52-77%  COMMERCES (herboriste, armurerie, auberge)
    ///   y=77-92%  QUARTIER HAUT (chalet du maire, villas)
    ///   y=92-100% PORTE NORD (sortie forêt)
    private func buildVillage(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height * 4.2
        worldHeight = h

        // ── SOL : variantes d'herbe ME (palette assortie aux transitions).
        // Les variantes "détail" sont dupliquées avec parcimonie pour un
        // sol vivant mais pas chargé.
        addTiledFloor(in: scene,
                      tileNames: ["me_grassvar_1", "me_grassvar_1", "me_grassvar_1",
                                  "me_grassvar_5", "me_grassvar_5",
                                  "me_grassvar_2", "me_grassvar_3", "me_grassvar_4"],
                      fallbackColor: SKColor(red: 0.36, green: 0.58, blue: 0.30, alpha: 1),
                      tileScale: 0.5,
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // ── RÉSEAU DE CHEMINS : terre battue autotilée ──
        var paths = VillageTileMap(width: w, height: h, tile: 24)
        // Allée principale sud → porte nord
        paths.stamp(rect: CGRect(x: w * 0.5 - 24, y: 0, width: 48, height: h * 0.945))
        // Place centrale en terre battue (ovale autour de la fontaine)
        paths.stampEllipse(center: CGPoint(x: w * 0.50, y: h * 0.40),
                           radiusX: w * 0.17, radiusY: h * 0.050)
        // Parvis du portail sud (évasement de l'allée à l'entrée)
        paths.stamp(rect: CGRect(x: w * 0.5 - 60, y: 0, width: 120, height: h * 0.035))
        // Branches : un sentier par porte de maison
        for branch in Self.villageBranches {
            let bx = w * branch.x
            let by = h * branch.y
            let x0 = min(bx, w * 0.5 - 12)
            let x1 = max(bx, w * 0.5 + 12)
            paths.stamp(rect: CGRect(x: x0, y: by - 4, width: x1 - x0, height: 30))
        }
        renderTileMap(paths, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -9.6)

        // ── ÉTANG OUEST : eau + berges autotilées ──
        var pond = VillageTileMap(width: w, height: h, tile: 24)
        pond.stampEllipse(center: CGPoint(x: w * 0.085, y: h * 0.46),
                          radiusX: w * 0.058, radiusY: h * 0.027)
        renderTileMap(pond, fullTile: "me_water_full", edgePrefix: "me_shore_",
                      in: scene, z: -9.5)

        decorateVillage(in: scene)

        // ═══════════ MAISONS (échelle perso : porte ≈ taille de Kael) ═══════════
        buildNorthGate(at: CGPoint(x: w * 0.50, y: h * 0.96), width: 90, in: scene)

        // Résidentiel sud — la maison de Kael en premier plan
        addVillageBuilding(asset: "village_house_onestory", scale: 0.28,
                            fallbackW: 62, fallbackH: 50,
                            wallColor: SKColor(red: 0.18, green: 0.16, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.35, green: 0.28, blue: 0.18, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.32, y: h * 0.075), in: scene)
        addVillageBuilding(asset: "village_house_country", scale: 0.30,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.14, y: h * 0.16), in: scene)
        addVillageBuilding(asset: "village_house_modern", scale: 0.26,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1),
                            roofColor: SKColor(red: 0.30, green: 0.30, blue: 0.40, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.80, y: h * 0.16), in: scene)

        // Commerces — portes alignées sur houseDoorPosition (NE PAS déplacer)
        addVillageBuilding(asset: "village_house_japanese", scale: 0.30,
                            fallbackW: 62, fallbackH: 50,
                            wallColor: SKColor(red: 0.14, green: 0.22, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.22, green: 0.40, blue: 0.22, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.22, y: h * 0.58), in: scene)
        addVillageBuilding(asset: "village_house_armory", scale: 0.32,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.50, y: h * 0.63), in: scene)
        addVillageBuilding(asset: "village_house_inn", scale: 0.32,
                            fallbackW: 88, fallbackH: 62,
                            wallColor: SKColor(red: 0.20, green: 0.14, blue: 0.10, alpha: 1),
                            roofColor: SKColor(red: 0.45, green: 0.25, blue: 0.12, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.78, y: h * 0.58), in: scene)

        // Quartier haut — villas autour d'un parc civique
        addVillageBuilding(asset: "village_house_victorian", scale: 0.24,
                            fallbackW: 70, fallbackH: 55,
                            wallColor: SKColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.30, green: 0.50, blue: 0.35, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.17, y: h * 0.78), in: scene)
        addVillageBuilding(asset: "village_house_country", scale: 0.26,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.82, y: h * 0.78), in: scene)

        // Crystal save proche auberge (UX : safe spot évident)
        addSaveCrystal(at: CGPoint(x: w * 0.88, y: h * 0.52), in: scene)

        addAtmosphere(ParticleFactory.ambientDust(in: CGSize(width: w, height: h)), to: scene)
    }

    /// Portes desservies par un sentier branché sur l'allée centrale
    /// (fractions de w/h — alignées sur les pieds de maisons).
    private static let villageBranches: [(x: CGFloat, y: CGFloat)] = [
        (0.32, 0.075),   // maison de Kael
        (0.14, 0.16),    // maison country sud
        (0.80, 0.16),    // maison moderne
        (0.22, 0.58),    // herboriste
        (0.78, 0.58),    // auberge
        (0.88, 0.52),    // crystal de sauvegarde
        (0.17, 0.78),    // villa victorienne
        (0.82, 0.78)     // maison haute est
    ]

    // MARK: - Forêt d'Ébène

    /// FORÊT D'ÉBÈNE — trek vertical sud→nord (worldHeight = 2.8× écran).
    /// Sentier sinueux autotilé reliant 4 clairières :
    ///   y≈0.31  BOSQUET CORROMPU (combat 1, ouest)
    ///   y≈0.52  CAMPEMENT (feu + cristal de sauvegarde, centre)
    ///   y≈0.66  CLAIRIÈRE SOMBRE (combat 2, est)
    ///   y≈0.90  SEUIL DU SANCTUAIRE (sortie nord)
    /// POI synchronisés avec GameManager.tryForestInteraction (worldHeight).
    private func buildForest(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height * 2.8
        worldHeight = h

        // ── SOL : herbe ME noyée d'ombre (palette assortie aux transitions) ──
        let forestShade = SKColor(red: 0.05, green: 0.13, blue: 0.08, alpha: 1)
        let forestBase = SKShapeNode(rectOf: CGSize(width: w + 96, height: h + 96))
        forestBase.fillColor = SKColor(red: 0.05, green: 0.12, blue: 0.07, alpha: 1)
        forestBase.strokeColor = .clear
        forestBase.position = CGPoint(x: (w + 96) / 2 - 48, y: (h + 96) / 2 - 48)
        forestBase.zPosition = -11
        add(forestBase, to: scene)

        addTiledFloor(in: scene,
                      tileNames: ["me_grassvar_1", "me_grassvar_1", "me_grassvar_5",
                                  "me_grassvar_2", "me_grassvar_3", "me_grassvar_4"],
                      fallbackColor: SKColor(red: 0.05, green: 0.12, blue: 0.07, alpha: 1),
                      tileScale: 0.5,
                      tint: forestShade,
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // ── SENTIER SINUEUX + CLAIRIÈRES (autotile assombri) ──
        var trail = VillageTileMap(width: w, height: h, tile: 24)
        // Entrée sud → premier virage
        trail.stamp(rect: CGRect(x: w * 0.50 - 24, y: 0, width: 48, height: h * 0.155))
        // Virage ouest vers le bosquet
        trail.stamp(rect: CGRect(x: w * 0.27, y: h * 0.12, width: w * 0.26, height: 44))
        trail.stamp(rect: CGRect(x: w * 0.27, y: h * 0.12, width: 48, height: h * 0.30))
        trail.stampEllipse(center: CGPoint(x: w * 0.30, y: h * 0.31),
                           radiusX: w * 0.13, radiusY: h * 0.045)
        // Vers le campement central
        trail.stamp(rect: CGRect(x: w * 0.27, y: h * 0.40, width: w * 0.25, height: 44))
        trail.stamp(rect: CGRect(x: w * 0.49, y: h * 0.40, width: 48, height: h * 0.13))
        trail.stampEllipse(center: CGPoint(x: w * 0.52, y: h * 0.52),
                           radiusX: w * 0.11, radiusY: h * 0.040)
        // Vers la clairière sombre (est)
        trail.stamp(rect: CGRect(x: w * 0.49, y: h * 0.52, width: 48, height: h * 0.12))
        trail.stamp(rect: CGRect(x: w * 0.49, y: h * 0.62, width: w * 0.24, height: 44))
        trail.stampEllipse(center: CGPoint(x: w * 0.70, y: h * 0.66),
                           radiusX: w * 0.12, radiusY: h * 0.045)
        // Remontée finale vers le seuil nord
        trail.stamp(rect: CGRect(x: w * 0.67, y: h * 0.66, width: 48, height: h * 0.13))
        trail.stamp(rect: CGRect(x: w * 0.52, y: h * 0.76, width: w * 0.20, height: 44))
        trail.stamp(rect: CGRect(x: w * 0.52, y: h * 0.76, width: 48, height: h * 0.16))
        trail.stampEllipse(center: CGPoint(x: w * 0.55, y: h * 0.90),
                           radiusX: w * 0.09, radiusY: h * 0.035)
        renderTileMap(trail, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -9.6,
                      tint: SKColor(red: 0.16, green: 0.10, blue: 0.07, alpha: 1))

        // ── CANOPÉE : double mur d'arbres ouest/est + lisières sud/nord ──
        // me_tree_1..6 UNIQUEMENT : arbres ME naturels complets.
        // (me_tree_7..10 = arbres en jardinière urbaine — réservés au
        // village ; mv_forest_* = tuiles de canopée non homogènes.)
        let treeScale = max(0.45, min(0.68, w / 760))
        let borderTrees = ["me_tree_1", "me_tree_5", "me_tree_2",
                           "me_tree_3", "me_tree_6", "me_tree_4"]
        var treeIdx = 0
        func plantTree(_ x: CGFloat, _ y: CGFloat, scaleMult: CGFloat = 1.0, dim: CGFloat = 1.0) {
            let name = borderTrees[treeIdx % borderTrees.count]
            treeIdx += 1
            let tree = PixelArtSprites.still(name: name, scale: treeScale * scaleMult,
                                              anchor: CGPoint(x: 0.5, y: 0.0))
                ?? makeTree(height: 60)
            tree.position = CGPoint(x: x, y: y)
            tree.zPosition = propLayer(for: y, in: h)
            tree.alpha = dim
            addGroundShadow(under: tree, width: 18 * scaleMult, height: 6)
            add(tree, to: scene)
        }
        var yCursor = h * 0.03
        var side = 0
        while yCursor < h * 0.97 {
            // jitter déterministe pour casser l'alignement
            let jitter = CGFloat((side * 7) % 13) / 13.0
            plantTree(w * (0.040 + 0.020 * jitter), yCursor, scaleMult: 1.0)
            plantTree(w * (0.125 + 0.025 * jitter), yCursor + h * 0.022, scaleMult: 0.85)
            plantTree(w * (0.960 - 0.020 * jitter), yCursor + h * 0.012, scaleMult: 1.0)
            plantTree(w * (0.875 - 0.025 * jitter), yCursor + h * 0.034, scaleMult: 0.85)
            yCursor += h * 0.052
            side += 1
        }
        // Lisière sud (entrée) et nord (seuil) : encadre sans bloquer le sentier
        for x in [0.22, 0.34, 0.64, 0.76] {
            plantTree(w * CGFloat(x), h * 0.015, scaleMult: 0.9)
        }
        for x in [0.24, 0.38, 0.70, 0.82] {
            plantTree(w * CGFloat(x), h * 0.965, scaleMult: 0.9)
        }
        // Arbres intérieurs épars (hors sentier)
        let innerTrees: [(CGFloat, CGFloat)] = [
            (0.62, 0.10), (0.78, 0.18), (0.22, 0.22), (0.58, 0.26),
            (0.80, 0.33), (0.24, 0.46), (0.70, 0.46), (0.30, 0.58),
            (0.78, 0.56), (0.24, 0.68), (0.40, 0.72), (0.80, 0.78),
            (0.30, 0.84), (0.74, 0.92)
        ]
        for (x, y) in innerTrees {
            plantTree(w * x, h * y, scaleMult: 0.82)
        }

        // ── ARBRES MORTS CORROMPUS près des zones de danger (teinte Aether) ──
        let corrupted: [(CGFloat, CGFloat, CGFloat)] = [
            (0.20, 0.295, 0.80), (0.40, 0.33, 0.74),
            (0.61, 0.645, 0.80), (0.79, 0.695, 0.74)
        ]
        for (x, y, s) in corrupted {
            // gy_tree = arbre mort ME complet (mv_dead_tree était une
            // spritesheet entière → « troncs coupés à moitié » à l'écran)
            guard let tree = PixelArtSprites.still(name: "gy_tree", scale: treeScale * s * 0.75,
                                                   anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            tree.position = CGPoint(x: w * x, y: h * y)
            tree.zPosition = propLayer(for: tree.position.y, in: h)
            tree.forEachDescendantSprite { sprite in
                sprite.color = SKColor(red: 0.28, green: 0.12, blue: 0.42, alpha: 1)
                sprite.colorBlendFactor = 0.50
            }
            addGroundShadow(under: tree, width: 46 * treeScale, height: 13 * treeScale)
            add(tree, to: scene)
        }

        // ── POI : zones de danger, campement, seuil, statues ──
        add(makeDangerZone(at: CGPoint(x: w * 0.30, y: h * 0.31), radius: 35,
                           color: SKColor(red: 0.50, green: 0.10, blue: 0.10, alpha: 1)),
            to: scene)
        add(makeDangerZone(at: CGPoint(x: w * 0.70, y: h * 0.66), radius: 40,
                           color: SKColor(red: 0.40, green: 0.08, blue: 0.45, alpha: 1)),
            to: scene)

        // Campement : feu, bois, banc — havre au milieu du trek
        addPixelProp("me_campfire", in: scene, at: CGPoint(x: w * 0.52, y: h * 0.515), scale: 0.50)
        addPixelProp("me_cut_wood", in: scene, at: CGPoint(x: w * 0.575, y: h * 0.505), scale: 0.42)
        addPixelProp("me_cut_wood_bench", in: scene, at: CGPoint(x: w * 0.465, y: h * 0.500), scale: 0.42)
        addSaveCrystal(at: CGPoint(x: w * 0.46, y: h * 0.540), in: scene)

        // Statues gardiennes oubliées le long du sentier
        addPixelProp("me_angel_statue_1", in: scene, at: CGPoint(x: w * 0.36, y: h * 0.355), scale: 0.26)
        addPixelProp("me_statue_grey", in: scene, at: CGPoint(x: w * 0.49, y: h * 0.875), scale: 0.26)

        // Seuil du sanctuaire (sortie nord)
        let deepPath = SKShapeNode(rectOf: CGSize(width: 64, height: 32), cornerRadius: 8)
        deepPath.fillColor = SKColor(red: 0.12, green: 0.05, blue: 0.18, alpha: 0.18)
        deepPath.strokeColor = SKColor(red: 0.50, green: 0.25, blue: 0.75, alpha: 0.35)
        deepPath.lineWidth = 1.5
        deepPath.position = CGPoint(x: w * 0.55, y: h * 0.90)
        deepPath.zPosition = -2
        add(deepPath, to: scene)
        JuiceEngine.pulse(deepPath, scale: 1.15)

        let pathLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        pathLabel.text = String(localized: "world.deepPath")
        pathLabel.fontSize = 11
        pathLabel.fontColor = SKColor(red: 0.60, green: 0.40, blue: 0.85, alpha: 0.8)
        pathLabel.position = CGPoint(x: w * 0.55, y: h * 0.925)
        pathLabel.zPosition = -1
        add(pathLabel, to: scene)

        scatterForestProps(in: scene, w: w, h: h)

        addAtmosphere(ParticleFactory.forestFog(in: CGSize(width: w, height: h)), to: scene)
    }

    /// Sous-bois : champignons, rochers, souches, pousses et os dispersés
    /// de façon déterministe, hors sentier et clairières.
    private func scatterForestProps(in scene: SKScene, w: CGFloat, h: CGFloat) {
        let reserved: [CGRect] = [
            CGRect(x: w * 0.44, y: 0, width: w * 0.12, height: h * 0.17),
            CGRect(x: w * 0.15, y: h * 0.25, width: w * 0.30, height: h * 0.13),  // bosquet
            CGRect(x: w * 0.39, y: h * 0.47, width: w * 0.26, height: h * 0.10),  // campement
            CGRect(x: w * 0.56, y: h * 0.60, width: w * 0.28, height: h * 0.12),  // clairière
            CGRect(x: w * 0.44, y: h * 0.85, width: w * 0.22, height: h * 0.10)   // seuil
        ]
        let props = ["me_mushrooms_1", "me_mushrooms_2", "forest_mushroom_1",
                     "forest_mushroom_2", "mushroom_1", "mushroom_3",
                     "rock_1", "rock_3", "rock_5", "village_rock_1",
                     "stump_1", "stump_2", "forest_stump_1",
                     "me_big_sprout_1", "me_big_sprout_2", "me_big_sprout_3",
                     "bones_1"]
        var seed: UInt64 = 0xF0E5_57_2026
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        var placed = 0
        var attempts = 0
        while placed < 52 && attempts < 420 {
            attempts += 1
            let p = CGPoint(x: w * 0.16 + next() * w * 0.68,
                            y: h * 0.02 + next() * h * 0.94)
            if reserved.contains(where: { $0.contains(p) }) { continue }
            let name = props[Int(next() * CGFloat(props.count)) % props.count]
            guard let node = PixelArtSprites.still(name: name, scale: 0.42,
                                                    anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            node.position = p
            node.zPosition = -8.8
            add(node, to: scene)
            placed += 1
        }
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
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let toy = SKNode()
        toy.position = CGPoint(x: w * 0.80, y: h * 0.45)
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

    // ═══ ENTRÉE SUD — portail d'accueil sur le parvis ═══
    group([("me_sign_1", -0.085, 0.0, 0.55), ("me_lamp_1", -0.085, 0.018, 0.40),
           ("me_lamp_1", 0.085, 0.018, 0.40), ("me_sign_2", 0.085, 0.0, 0.55),
           ("me_flower_red", -0.115, 0.008, 0.45), ("me_flower_yellow", 0.115, 0.008, 0.45)],
          at: CGPoint(x: w * 0.50, y: h * 0.012))

    // ═══ MAISON DE KAEL (onestory, 0.32/0.075) — cour familiale ═══
    addFenceRect(in: scene, at: CGPoint(x: w * 0.235, y: h * 0.085),
                 size: CGSize(width: w * 0.075, height: h * 0.026))
    group([("mv_garden_bed", 0.0, -0.002, 0.40)],
          at: CGPoint(x: w * 0.235, y: h * 0.085))
    group([("me_mailbox_1", 0.075, 0.002, 0.42), ("me_birdhouse_blue", 0.055, 0.022, 0.40),
           ("me_flower_white", -0.065, 0.002, 0.42)],
          at: CGPoint(x: w * 0.32, y: h * 0.075))

    // ═══ COUR COUNTRY SUD (0.14/0.16) ═══
    group([("me_mailbox_1", 0.075, 0.002, 0.42), ("me_hanging_flowers", -0.055, -0.004, 0.42),
           ("me_flower_pink", -0.075, 0.004, 0.42), ("me_birdhouse_brown", 0.10, 0.018, 0.40)],
          at: CGPoint(x: w * 0.14, y: h * 0.16))

    // ═══ COUR MODERNE (0.80/0.16) ═══
    group([("me_mailbox_1", -0.085, 0.002, 0.42), ("me_garden_bench", 0.085, 0.006, 0.42),
           ("me_flower_blue", 0.10, 0.0, 0.42), ("me_vase_yellow", -0.10, 0.004, 0.40)],
          at: CGPoint(x: w * 0.80, y: h * 0.16))

    // ═══ FERME EST (bas droite) — potager clôturé dense + remise ═══
    addFenceRect(in: scene, at: CGPoint(x: w * 0.62, y: h * 0.068),
                 size: CGSize(width: w * 0.115, height: h * 0.020))
    group([("mv_garden_bed", -0.032, -0.003, 0.52), ("mv_garden_bed", 0.012, -0.003, 0.52),
           ("me_sunflower", 0.042, -0.004, 0.45), ("me_big_sprout_5", -0.052, 0.002, 0.42),
           ("me_big_sprout_6", 0.030, 0.004, 0.42)],
          at: CGPoint(x: w * 0.62, y: h * 0.068))
    addPixelProp("me_wood_storage", in: scene, at: CGPoint(x: w * 0.73, y: h * 0.092), scale: 0.55)
    addPixelProp("me_cart_empty", in: scene, at: CGPoint(x: w * 0.71, y: h * 0.052), scale: 0.48)
    addPixelProp("me_basket_2", in: scene, at: CGPoint(x: w * 0.675, y: h * 0.058), scale: 0.45)

    // ═══ PLACE CENTRALE (0.50/0.40) — fontaine, bancs, lampes en anneau ═══
    addPixelProp("village_fountain", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.392), scale: 0.85)
    group([("me_bench_1", -0.075, -0.022, 0.45), ("me_bench_2", 0.075, -0.022, 0.45),
           ("me_garden_bench", -0.075, 0.022, 0.45), ("me_bench_3", 0.075, 0.022, 0.45),
           ("me_lamp_2", -0.135, -0.030, 0.40), ("me_lamp_2", 0.135, -0.030, 0.40),
           ("me_lamp_2", -0.135, 0.030, 0.40), ("me_lamp_2", 0.135, 0.030, 0.40),
           ("me_vase_red", -0.045, -0.030, 0.42), ("me_vase_sunflower", 0.045, -0.030, 0.42)],
          at: CGPoint(x: w * 0.50, y: h * 0.40))

    // ═══ MARCHÉ — étal groupé côté ouest de la place ═══
    group([("me_wood_cart", -0.01, 0.006, 0.50), ("me_lemonade_stand", 0.045, 0.014, 0.50),
           ("village_crate_1", -0.045, 0.0, 0.45), ("village_crate_2", -0.045, 0.012, 0.45),
           ("me_barrel_1", 0.0, -0.012, 0.45), ("me_basket", 0.035, -0.008, 0.42),
           ("me_apples", 0.02, -0.014, 0.40)],
          at: CGPoint(x: w * 0.385, y: h * 0.405))

    // ═══ ÉTANG OUEST (0.085/0.46) — roseaux et berge vivante ═══
    group([("me_big_sprout_1", 0.055, 0.012, 0.45), ("me_big_sprout_2", 0.065, -0.010, 0.42),
           ("me_big_sprout_3", -0.005, 0.030, 0.42), ("me_mushrooms_1", 0.075, 0.018, 0.40),
           ("me_flower_white", 0.02, -0.032, 0.42)],
          at: CGPoint(x: w * 0.085, y: h * 0.46))

    // ═══ HERBORISTE (Mara, 0.22/0.58) — potager clôturé devant ═══
    addFenceRect(in: scene, at: CGPoint(x: w * 0.155, y: h * 0.535),
                 size: CGSize(width: w * 0.10, height: h * 0.030))
    group([("me_vase_red", -0.02, -0.006, 0.42), ("me_vase_yellow", 0.02, -0.006, 0.42),
           ("me_mushrooms_1", -0.02, 0.006, 0.40), ("me_big_sprout_4", 0.02, 0.006, 0.42),
           ("me_sunflower", 0.0, 0.0, 0.42)],
          at: CGPoint(x: w * 0.155, y: h * 0.535))
    addPixelProp("me_sign_2", in: scene, at: CGPoint(x: w * 0.27, y: h * 0.575), scale: 0.50)

    // ═══ ARMURERIE (Bram, 0.50/0.63) — bois + tonneaux contre le mur ═══
    group([("me_cut_wood", -0.085, 0.004, 0.45), ("me_cut_wood_2", -0.105, -0.006, 0.45),
           ("me_barrel_1", 0.085, 0.0, 0.45), ("me_barrel_2", 0.105, 0.008, 0.45),
           ("me_cut_wood_bench", -0.095, 0.016, 0.45)],
          at: CGPoint(x: w * 0.50, y: h * 0.625))
    addPixelProp("me_sign_3", in: scene, at: CGPoint(x: w * 0.455, y: h * 0.622), scale: 0.50)

    // ═══ AUBERGE (Sage, 0.78/0.58) — tonneaux, lanterne, repos ═══
    group([("me_barrel_3", -0.085, 0.0, 0.45), ("me_barrel_4", -0.105, 0.008, 0.45),
           ("me_hanging_pot", 0.085, 0.002, 0.45), ("village_lantern_1", 0.10, 0.012, 0.48),
           ("me_bench_2", 0.0, -0.016, 0.45)],
          at: CGPoint(x: w * 0.78, y: h * 0.58))
    addPixelProp("me_sign_1", in: scene, at: CGPoint(x: w * 0.73, y: h * 0.575), scale: 0.50)

    // ═══ QUARTIER HAUT — parc civique entre les villas ═══
    addPixelProp("me_statue_putto", in: scene, at: CGPoint(x: w * 0.43, y: h * 0.790), scale: 0.42)
    addPixelProp("me_statue_putto", in: scene, at: CGPoint(x: w * 0.57, y: h * 0.790), scale: 0.42)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.43, y: h * 0.765), scale: 0.40)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.57, y: h * 0.765), scale: 0.40)
    addPixelProp("me_garden_bench", in: scene, at: CGPoint(x: w * 0.40, y: h * 0.775), scale: 0.45)
    addPixelProp("me_bench_1", in: scene, at: CGPoint(x: w * 0.60, y: h * 0.775), scale: 0.45)
    addPixelProp("me_vase_sunflower", in: scene, at: CGPoint(x: w * 0.46, y: h * 0.800), scale: 0.42)
    addPixelProp("me_vase_red", in: scene, at: CGPoint(x: w * 0.54, y: h * 0.800), scale: 0.42)
    group([("me_mailbox_1", 0.075, 0.002, 0.42), ("me_hanging_flowers", -0.055, -0.004, 0.42),
           ("me_flower_red", -0.075, 0.006, 0.42)],
          at: CGPoint(x: w * 0.17, y: h * 0.78))
    group([("me_mailbox_1", -0.075, 0.002, 0.42), ("me_hanging_flowers", 0.055, -0.004, 0.42),
           ("me_flower_blue", 0.075, 0.006, 0.42)],
          at: CGPoint(x: w * 0.82, y: h * 0.78))

    // ═══ SORTIE NORD — porte gardée : statues + lampes + panneau ═══
    addPixelProp("me_statue_angel", in: scene, at: CGPoint(x: w * 0.43, y: h * 0.945), scale: 0.20)
    addPixelProp("me_statue_grey", in: scene, at: CGPoint(x: w * 0.57, y: h * 0.945), scale: 0.20)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.44, y: h * 0.922), scale: 0.40)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.56, y: h * 0.922), scale: 0.40)
    addPixelProp("me_sign_3", in: scene, at: CGPoint(x: w * 0.565, y: h * 0.952), scale: 0.42)

    // ═══ ARBRES — bordures forestières + arbres ME dans le village ═══
    // Bordure forestière : me_tree_1..6 naturels uniquement (7..10 = arbres
    // en jardinière urbaine, réservés à l'intérieur du village).
    let borderTrees: [(String, CGFloat, CGFloat, CGFloat)] = [
        // (asset, x, y, scale) — colonnes ouest/est, espèces variées
        ("me_tree_1", 0.035, 0.055, 0.60), ("me_tree_5", 0.030, 0.13, 0.62),
        ("me_tree_2", 0.040, 0.22, 0.58), ("me_tree_6", 0.030, 0.30, 0.62),
        ("me_tree_3", 0.035, 0.38, 0.58), ("me_tree_6", 0.030, 0.56, 0.62),
        ("me_tree_4", 0.040, 0.64, 0.60), ("me_tree_4", 0.030, 0.72, 0.58),
        ("me_tree_5", 0.035, 0.83, 0.62), ("me_tree_1", 0.030, 0.92, 0.58),
        ("me_tree_3", 0.965, 0.05, 0.60), ("me_tree_2", 0.970, 0.13, 0.58),
        ("me_tree_5", 0.960, 0.24, 0.62), ("me_tree_1", 0.965, 0.33, 0.58),
        ("me_tree_6", 0.970, 0.42, 0.62), ("me_tree_3", 0.965, 0.50, 0.58),
        ("me_tree_6", 0.960, 0.64, 0.62), ("me_tree_2", 0.970, 0.72, 0.60),
        ("me_tree_4", 0.965, 0.82, 0.58), ("me_tree_5", 0.960, 0.92, 0.62)
    ]
    for (asset, x, y, s) in borderTrees {
        addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
    }
    // Quelques arbres à l'intérieur du village (respiration entre zones)
    let innerTrees: [(String, CGFloat, CGFloat)] = [
        ("me_tree_5", 0.42, 0.115), ("me_tree_2", 0.60, 0.135),
        ("me_tree_9", 0.16, 0.31), ("me_tree_3", 0.86, 0.33),
        ("me_tree_1", 0.30, 0.49), ("me_tree_6", 0.68, 0.475),
        ("me_tree_10", 0.13, 0.66), ("me_tree_5", 0.88, 0.665),
        ("me_tree_2", 0.30, 0.86), ("me_tree_8", 0.70, 0.855)
    ]
    for (asset, x, y) in innerTrees {
        addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: 0.58)
    }

    // ═══ FLEURS ÉPARSES (positions seedées, hors chemins/maisons) ═══
    scatterVillageFlowers(in: scene, w: w, h: h)
}

/// Fleurs et buissons dispersés de façon déterministe (LCG seedé) sur
/// l'herbe libre — jamais sur les chemins, maisons, place ou étang.
private func scatterVillageFlowers(in scene: SKScene, w: CGFloat, h: CGFloat) {
    let reserved: [CGRect] = [
        CGRect(x: w * 0.5 - 36, y: 0, width: 72, height: h),            // allée centrale
        CGRect(x: w * 0.30, y: h * 0.33, width: w * 0.40, height: h * 0.14), // place
        CGRect(x: 0, y: h * 0.42, width: w * 0.16, height: h * 0.08),   // étang
        CGRect(x: w * 0.02, y: h * 0.03, width: w * 0.42, height: h * 0.16), // maisons sud-ouest
        CGRect(x: w * 0.62, y: h * 0.10, width: w * 0.36, height: h * 0.10), // maison moderne
        CGRect(x: w * 0.54, y: h * 0.04, width: w * 0.26, height: h * 0.06), // ferme est
        CGRect(x: w * 0.08, y: h * 0.51, width: w * 0.28, height: h * 0.14), // herboriste
        CGRect(x: w * 0.36, y: h * 0.56, width: w * 0.28, height: h * 0.14), // armurerie
        CGRect(x: w * 0.64, y: h * 0.51, width: w * 0.28, height: h * 0.14), // auberge
        CGRect(x: w * 0.06, y: h * 0.72, width: w * 0.30, height: h * 0.14), // victorienne
        CGRect(x: w * 0.66, y: h * 0.72, width: w * 0.30, height: h * 0.14), // maison est
        CGRect(x: w * 0.38, y: h * 0.74, width: w * 0.24, height: h * 0.12)  // chalet maire
    ]
    let flowers = ["me_flower_red", "me_flower_yellow", "me_flower_blue",
                   "me_flower_pink", "me_flower_white", "me_sunflower",
                   "me_flower_bush_1", "me_flower_bush_2", "me_flower_bush_3"]
    var seed: UInt64 = 0x5EED_0501_15
    func next() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(seed >> 40) / CGFloat(1 << 24)
    }
    var placed = 0
    var attempts = 0
    while placed < 48 && attempts < 400 {
        attempts += 1
        let p = CGPoint(x: w * 0.06 + next() * w * 0.88,
                        y: h * 0.02 + next() * h * 0.94)
        if reserved.contains(where: { $0.contains(p) }) { continue }
        let name = flowers[Int(next() * CGFloat(flowers.count)) % flowers.count]
        guard let node = PixelArtSprites.still(name: name, scale: 0.45,
                                                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
        node.position = p
        node.zPosition = -8.8
        add(node, to: scene)
        placed += 1
    }
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

        // Sol : dalles de pierre teintées rouge-brun (la Source corrompue)
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.07, green: 0.04, blue: 0.04, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.30, green: 0.14, blue: 0.10, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

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

        // ── VESTIGES : chapelle effondrée, maison en ruine, portail brisé ──
        addPixelProp("house_ruins_1", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.78), scale: 0.62)
        addPixelProp("gy_gate_high", in: scene, at: CGPoint(x: w * 0.08, y: h * 0.76), scale: 0.48)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.90, y: h * 0.74), scale: 0.52, flipped: true)

        // Colonnes brisées cadrant les zones de combat (échelle pixel : ×2
        // sur du 16×32 natif → 32×64 pt, net, plus d'étirement flou)
        for (px, py) in [(0.10, 0.42), (0.38, 0.50), (0.72, 0.52), (0.90, 0.40)] {
            addPixelProp("column_broken_1", in: scene,
                         at: CGPoint(x: w * CGFloat(px), y: h * CGFloat(py)), scale: 2.0)
        }
        addPixelProp("pillar_grey_1", in: scene, at: CGPoint(x: w * 0.24, y: h * 0.30), scale: 1.8)
        addPixelProp("pillar_grey_2", in: scene, at: CGPoint(x: w * 0.66, y: h * 0.26), scale: 1.8)

        // ── CIMETIÈRE PROFANÉ : tombes de bois, croix, chandeliers éteints ──
        let relics: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("gy_grave_wood", 0.20, 0.36, 0.55), ("gy_cross_wood", 0.34, 0.28, 0.55),
            ("gy_tomb_brown", 0.48, 0.34, 0.55), ("gy_grave_wood", 0.58, 0.26, 0.50),
            ("gy_cross_wood", 0.76, 0.34, 0.55), ("gy_tomb_brown", 0.86, 0.28, 0.55),
            ("gy_candle_off", 0.30, 0.58, 0.50), ("gy_candle_off", 0.56, 0.54, 0.50),
            ("gy_stone_1", 0.42, 0.42, 0.50), ("gy_stone_3", 0.68, 0.44, 0.50),
            ("gy_stone_2", 0.16, 0.30, 0.50)
        ]
        for (asset, x, y, s) in relics {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
        }

        // Ossements nets à l'échelle pixel (16×32 natif → ×2)
        for p in [(0.30, 0.44), (0.65, 0.38), (0.45, 0.62)] {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: 2.0,
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            bones.position = CGPoint(x: w * p.0, y: h * p.1)
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

        // ── LE SEUIL : portail à orbe rouge au sommet de l'escalier ──
        addPixelProp("me_stairs", in: scene,
                     at: CGPoint(x: w * 0.50, y: h * 0.70), scale: 0.60)
        addPixelProp("gy_gate_big", in: scene,
                     at: CGPoint(x: w * 0.50, y: h * 0.84), scale: 0.55)
        let voidGlow = SKShapeNode(circleOfRadius: 52)
        voidGlow.fillColor = SKColor(red: 0.30, green: 0.08, blue: 0.45, alpha: 0.10)
        voidGlow.strokeColor = SKColor(red: 0.55, green: 0.20, blue: 0.85, alpha: 0.30)
        voidGlow.lineWidth = 1.5
        voidGlow.glowWidth = 8
        voidGlow.position = CGPoint(x: w * 0.50, y: h * 0.90)
        voidGlow.zPosition = -2
        add(voidGlow, to: scene)
        JuiceEngine.pulse(voidGlow, scale: 1.2)

        // Statues d'anges gardiens flanquant le Seuil (échelle pixel nette)
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.36, y: h * 0.80), scale: 0.24)
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.64, y: h * 0.80), scale: 0.24, flipped: true)

        // Allée de chandeliers spectraux + colonnes cadrant l'arène
        for (i, py) in [CGFloat(0.40), 0.55, 0.70].enumerated() {
            if i % 2 == 0 {
                addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * 0.14, y: h * py), scale: 0.55)
                addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * 0.86, y: h * py), scale: 0.55)
            } else {
                addPixelProp("column_broken_1", in: scene, at: CGPoint(x: w * 0.14, y: h * py), scale: 2.0)
                addPixelProp("column_broken_1", in: scene, at: CGPoint(x: w * 0.86, y: h * py), scale: 2.0)
            }
        }

        // Arches brisées + arbres morts (le Vide consume la vie)
        addPixelProp("gy_gate_high", in: scene, at: CGPoint(x: w * 0.10, y: h * 0.26), scale: 0.45)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.90, y: h * 0.26), scale: 0.50, flipped: true)

        // Tombes des âmes absorbées + ossements nets
        for (asset, px, py) in [("gy_tomb_black", 0.24, 0.34), ("gy_cross_black", 0.42, 0.26),
                                ("gy_tomb_grey_2", 0.60, 0.32), ("gy_tomb_black", 0.76, 0.28)] {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * CGFloat(px), y: h * CGFloat(py)), scale: 0.55)
        }
        for p in [(0.30, 0.45), (0.66, 0.42), (0.48, 0.30)] {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: 2.0,
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

    /// SANCTUAIRE DE LA SOURCE (Acte I) — parvis de dalles violettes,
    /// allée de chandeliers vers la chapelle gothique à l'est, portail à
    /// orbe rouge = seuil du boss (trigger gameplay : x > 0.55w).
    private func buildShrine(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : dalles de pierre teintées violet nuit
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.20, green: 0.12, blue: 0.34, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Allée processionnelle ouest→est (dalles plus claires vers le boss)
        let tile: CGFloat = 24
        for c in 0..<Int(ceil(w * 0.70 / tile)) {
            for r in 0..<3 {
                guard let t = PixelArtSprites.still(name: "a2_stone", scale: 0.5,
                                                     anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
                t.position = CGPoint(x: (CGFloat(c) + 0.5) * tile,
                                      y: h * 0.44 + (CGFloat(r) + 0.5) * tile)
                t.zPosition = -9.5
                t.forEachDescendantSprite { sprite in
                    sprite.color = SKColor(red: 0.42, green: 0.34, blue: 0.58, alpha: 1)
                    sprite.colorBlendFactor = 0.35
                }
                add(t, to: scene)
            }
        }

        // ── CHAPELLE DE LA SOURCE (fond est) + portail à orbe rouge ──
        addPixelProp("gy_chapel", in: scene, at: CGPoint(x: w * 0.84, y: h * 0.42), scale: 0.55)
        addPixelProp("gy_gate_big", in: scene, at: CGPoint(x: w * 0.66, y: h * 0.42), scale: 0.50)
        // Halo rouge menaçant sur le portail (le Gardien attend derrière)
        let menace = SKShapeNode(circleOfRadius: 46)
        menace.fillColor = SKColor(red: 0.65, green: 0.10, blue: 0.12, alpha: 0.10)
        menace.strokeColor = SKColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 0.30)
        menace.lineWidth = 1.5
        menace.glowWidth = 6
        menace.position = CGPoint(x: w * 0.66, y: h * 0.53)
        menace.zPosition = -2
        add(menace, to: scene)
        JuiceEngine.pulse(menace, scale: 1.25)

        // Statues anges gardant le portail
        addPixelProp("me_statue_angel", in: scene, at: CGPoint(x: w * 0.58, y: h * 0.30), scale: 0.22)
        addPixelProp("me_statue_angel", in: scene, at: CGPoint(x: w * 0.58, y: h * 0.58), scale: 0.22, flipped: true)

        // ── ALLÉE DE CHANDELIERS (guident vers l'est) ──
        for x in [0.16, 0.32, 0.48] {
            addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * CGFloat(x), y: h * 0.56), scale: 0.55)
            addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * CGFloat(x), y: h * 0.32), scale: 0.55)
        }

        // ── CIMETIÈRE ANCIEN (sud + nord du parvis) ──
        let graves: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("gy_cross_grey", 0.10, 0.72, 0.55), ("gy_tomb_grey_1", 0.20, 0.78, 0.55),
            ("gy_tomb_black", 0.30, 0.70, 0.55), ("gy_tomb_grey_2", 0.42, 0.76, 0.55),
            ("gy_cross_black", 0.54, 0.72, 0.55), ("gy_tomb_grey_1", 0.66, 0.78, 0.55),
            ("gy_tomb_grey_2", 0.12, 0.14, 0.55), ("gy_cross_grey", 0.26, 0.10, 0.55),
            ("gy_tomb_black", 0.40, 0.14, 0.55), ("gy_tomb_grey_1", 0.52, 0.10, 0.55),
            ("gy_stone_1", 0.35, 0.24, 0.50), ("gy_stone_2", 0.60, 0.68, 0.50),
            ("gy_stone_3", 0.08, 0.40, 0.50)
        ]
        for (asset, x, y, s) in graves {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
        }

        // Arbres morts tordus (la Source se meurt)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.06, y: h * 0.80), scale: 0.55)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.30, y: h * 0.86), scale: 0.48, flipped: true)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.10, y: h * 0.04), scale: 0.50)

        // Cristal de sauvegarde (entrée ouest — safe spot avant le boss)
        addSaveCrystal(at: CGPoint(x: w * 0.18, y: h * 0.20), in: scene)

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

    /// Profondeur acteurs : plage [20, 40], normalisée par la hauteur du
    /// MONDE (pas de l'écran) — sinon tout y > ~1,3 écran passe sous le sol.
    private func actorLayer(for y: CGFloat) -> CGFloat {
        let span = worldHeight > 0 ? worldHeight : 402
        return 40 - (y / span) * 20
    }

    /// Profondeur props : plage [-2, -8], même normalisation monde.
    private func propLayer(for y: CGFloat, in sceneHeight: CGFloat) -> CGFloat {
        let span = worldHeight > 0 ? worldHeight : max(sceneHeight, 1)
        return -2 - (y / span) * 6
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

        // Plancher en vraies tuiles (terre battue teintée par échoppe)
        if let boards = PixelArtSprites.tiledFloor(
            tileNames: ["tile_dirt_1", "tile_dirt_2", "tile_dirt_3"],
            in: CGSize(width: room.width - 8, height: room.height - 8),
            tileScale: 1.0,
            tint: interiorFloorColor(for: kind)) {
            boards.position = CGPoint(x: room.minX + 4, y: room.minY + 4)
            boards.zPosition = -8.5
            add(boards, to: scene)
        }
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

    private func addInteriorWallBand(in scene: SKScene, room: CGRect, kind: HouseInteriorKind) {
        // Mur du fond en vraies tuiles de pierre ME, teintées par échoppe.
        let wallTint: SKColor
        switch kind {
        case .armory:
            wallTint = SKColor(red: 0.30, green: 0.24, blue: 0.20, alpha: 1)
        case .apothecary:
            wallTint = SKColor(red: 0.18, green: 0.28, blue: 0.20, alpha: 1)
        case .inn:
            wallTint = SKColor(red: 0.32, green: 0.22, blue: 0.14, alpha: 1)
        }
        let tile: CGFloat = 24
        let cols = Int(ceil(room.width / tile))
        let wallNames = ["me_wall_1", "me_wall_2", "me_wall_3", "me_wall_5"]
        for r in 0..<2 {
            for c in 0..<cols {
                let name = wallNames[(c + r) % wallNames.count]
                guard let t = PixelArtSprites.still(name: name, scale: 0.5,
                                                     anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
                t.position = CGPoint(x: room.minX + (CGFloat(c) + 0.5) * tile,
                                      y: room.maxY - (CGFloat(r) + 0.5) * tile)
                t.zPosition = -7
                t.forEachDescendantSprite { sprite in
                    sprite.color = wallTint
                    sprite.colorBlendFactor = 0.40
                }
                add(t, to: scene)
            }
        }
    }

    private func addInteriorExitDoor(in scene: SKScene, room: CGRect) {
        let exit = SKNode()
        exit.position = interiorExitPosition(in: scene.size)
        exit.name = "interiorExit"
        exit.zPosition = -1

        let mat = SKShapeNode()
        PixelUI.stylePanel(mat, size: CGSize(width: 66, height: 20),
                           fill: SKColor(red: 0.11, green: 0.075, blue: 0.045, alpha: 0.90),
                           accent: SKColor(red: 0.60, green: 0.46, blue: 0.26, alpha: 0.9))
        exit.addChild(mat)

        let icon = SKLabelNode(fontNamed: PixelUI.uiFont)
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

    // MARK: - Rendu autotile (chemins de terre, étang du village)

    /// Pose les tuiles d'une `VillageTileMap` : tuiles pleines sur les
    /// cellules marquées, transitions nommées sur l'herbe adjacente
    /// (ex. `me_edge_n` = matière au nord de la cellule d'herbe).
    /// `tint` assombrit/teinte les tuiles (forêt sombre, etc.) pour
    /// rester assorti au sol teinté.
    private func renderTileMap(_ map: VillageTileMap, fullTile: String,
                               edgePrefix: String, in scene: SKScene, z: CGFloat,
                               tint: SKColor? = nil) {
        for piece in map.pieces() {
            let name = piece.suffix.map { edgePrefix + $0 } ?? fullTile
            guard let t = PixelArtSprites.still(name: name, scale: 0.5,
                                                 anchor: .zero) else { continue }
            t.position = CGPoint(x: CGFloat(piece.col) * map.tile,
                                  y: CGFloat(piece.row) * map.tile)
            t.zPosition = piece.suffix == nil ? z : z + 0.05
            if let tint {
                t.forEachDescendantSprite { sprite in
                    sprite.color = tint
                    sprite.colorBlendFactor = 0.45
                }
            }
            add(t, to: scene)
        }
    }
}

// MARK: - VillageTileMap (autotiler)

/// Grille binaire pour l'autotiling du village : on marque les cellules
/// "matière" (terre battue, eau), puis `pieces()` renvoie les tuiles
/// pleines + les transitions à poser sur les cellules d'herbe voisines,
/// nommées par la position de la matière (n, ne, e, se, s, sw, w, nw,
/// et cnw/cne/cse/csw pour les coins diagonaux isolés).
struct VillageTileMap {
    let tile: CGFloat
    let cols: Int
    let rows: Int
    private var cells: [Bool]

    init(width: CGFloat, height: CGFloat, tile: CGFloat) {
        self.tile = tile
        self.cols = Int(ceil(width / tile)) + 1
        self.rows = Int(ceil(height / tile)) + 1
        self.cells = Array(repeating: false, count: cols * rows)
    }

    private func isSet(_ c: Int, _ r: Int) -> Bool {
        guard c >= 0, c < cols, r >= 0, r < rows else { return false }
        return cells[r * cols + c]
    }

    /// Marque toutes les cellules intersectant le rectangle (points).
    mutating func stamp(rect: CGRect) {
        let c0 = max(0, Int(rect.minX / tile))
        let c1 = min(cols - 1, Int((rect.maxX - 0.5) / tile))
        let r0 = max(0, Int(rect.minY / tile))
        let r1 = min(rows - 1, Int((rect.maxY - 0.5) / tile))
        guard c0 <= c1, r0 <= r1 else { return }
        for r in r0...r1 {
            for c in c0...c1 { cells[r * cols + c] = true }
        }
    }

    /// Marque les cellules dont le centre est dans l'ellipse.
    mutating func stampEllipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) {
        guard radiusX > 0, radiusY > 0 else { return }
        for r in 0..<rows {
            for c in 0..<cols {
                let x = (CGFloat(c) + 0.5) * tile
                let y = (CGFloat(r) + 0.5) * tile
                let dx = (x - center.x) / radiusX
                let dy = (y - center.y) / radiusY
                if dx * dx + dy * dy <= 1 { cells[r * cols + c] = true }
            }
        }
    }

    /// Tuiles à poser : `suffix == nil` → tuile pleine, sinon suffixe de
    /// transition pour la cellule d'herbe (rangée = y vers le haut).
    func pieces() -> [(suffix: String?, col: Int, row: Int)] {
        var out: [(String?, Int, Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                if isSet(c, r) {
                    out.append((nil, c, r))
                    continue
                }
                let n = isSet(c, r + 1), s = isSet(c, r - 1)
                let e = isSet(c + 1, r), w = isSet(c - 1, r)
                let suffix: String?
                switch (n, s, e, w) {
                case (true, _, true, _):  suffix = "ne"
                case (true, _, _, true):  suffix = "nw"
                case (_, true, true, _):  suffix = "se"
                case (_, true, _, true):  suffix = "sw"
                case (true, _, _, _):     suffix = "n"
                case (_, true, _, _):     suffix = "s"
                case (_, _, true, _):     suffix = "e"
                case (_, _, _, true):     suffix = "w"
                default:
                    if isSet(c + 1, r + 1)      { suffix = "cne" }
                    else if isSet(c - 1, r + 1) { suffix = "cnw" }
                    else if isSet(c + 1, r - 1) { suffix = "cse" }
                    else if isSet(c - 1, r - 1) { suffix = "csw" }
                    else { suffix = nil }
                }
                if let suffix { out.append((suffix, c, r)) }
            }
        }
        return out
    }
}
