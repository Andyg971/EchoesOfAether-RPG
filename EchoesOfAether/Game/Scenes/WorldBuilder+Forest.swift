import SpriteKit

// Forêt d'Ébène : trek scrollable, monstres baladeurs.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Forêt d'Ébène

    /// FORÊT D'ÉBÈNE — trek vertical sud→nord (worldHeight = 2.8× écran).
    /// Sentier sinueux autotilé reliant 4 clairières :
    ///   y≈0.31  BOSQUET CORROMPU (combat 1, ouest)
    ///   y≈0.52  CAMPEMENT (feu + cristal de sauvegarde, centre)
    ///   y≈0.66  CLAIRIÈRE SOMBRE (combat 2, est)
    ///   y≈0.90  SEUIL DU SANCTUAIRE (sortie nord)
    /// POI synchronisés avec GameManager.tryForestInteraction (worldHeight).
    func buildForest(in scene: SKScene) {
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

        // ── CANOPÉE ANIMÉE : double mur d'arbres ouest/est + lisières ──
        // Le feuillage RESPIRE : `atree_*` sont des cycles de 16 frames et
        // `apine_cool` de 8. Chaque arbre démarre sur une frame différente et
        // avec une cadence légèrement décalée — synchronisés, cent arbres
        // ondulent d'un seul bloc et l'œil lit la boucle au lieu du vent.
        // Repli `me_tree_1..6` (arbres ME naturels complets) si les planches
        // animées manquent. me_tree_7..10 = arbres en jardinière urbaine,
        // réservés au village ; mv_forest_* = canopée non homogène.
        let treeScale = max(0.45, min(0.68, w / 760))
        let canopyHeight = 144 * treeScale     // gabarit historique des me_tree_*
        // Vert froid et vert profond en alternance, un pin tous les cinq
        // arbres : une essence unique donnerait un mur de photocopies.
        let canopy: [(name: String, frames: Int, height: CGFloat)] = [
            ("atree_cool", 16, canopyHeight),
            ("atree_dark", 16, canopyHeight * 0.94),
            ("atree_cool", 16, canopyHeight * 1.06),
            ("atree_dark", 16, canopyHeight),
            ("apine_cool", 8, canopyHeight * 1.22)
        ]
        let borderTrees = ["me_tree_1", "me_tree_5", "me_tree_2",
                           "me_tree_3", "me_tree_6", "me_tree_4"]
        var treeIdx = 0
        func plantTree(_ x: CGFloat, _ y: CGFloat, scaleMult: CGFloat = 1.0, dim: CGFloat = 1.0) {
            let species = canopy[treeIdx % canopy.count]
            let idx = treeIdx
            treeIdx += 1
            let animated = PixelArtSprites.animated(
                name: species.name, frames: species.frames,
                scale: scaleFor("\(species.name)_idle_1",
                                height: species.height * scaleMult),
                timePerFrame: 0.14 + Double(idx % 4) * 0.018,
                anchor: CGPoint(x: 0.5, y: 0.0),
                startFrame: (idx * 5) % species.frames)
            let tree = animated
                ?? PixelArtSprites.still(name: borderTrees[idx % borderTrees.count],
                                         scale: treeScale * scaleMult,
                                         anchor: CGPoint(x: 0.5, y: 0.0))
                ?? makeTree(height: 60)
            tree.position = CGPoint(x: x, y: y)
            tree.zPosition = propLayer(for: y, in: h)
            tree.alpha = dim
            addGroundShadow(under: tree, width: 18 * scaleMult, height: 6)
            add(tree, to: scene)
            // Tronc infranchissable (la canopée reste traversable derrière)
            registerFootprint(of: tree, widthRatio: 0.62, depthRatio: 0.5, maxDepth: 34)
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
        // Arbres intérieurs (hors sentier et hors clairières) : entre les deux
        // murs de bordure, la forêt était une pelouse vide traversée d'un
        // chemin. Ce semis referme le couvert sans boucher le passage.
        let innerTrees: [(CGFloat, CGFloat)] = [
            (0.62, 0.10), (0.78, 0.18), (0.22, 0.22), (0.58, 0.26),
            (0.80, 0.33), (0.24, 0.46), (0.70, 0.46), (0.30, 0.58),
            (0.78, 0.56), (0.24, 0.68), (0.40, 0.72), (0.80, 0.78),
            (0.30, 0.84), (0.74, 0.92),
            (0.44, 0.155), (0.66, 0.22), (0.18, 0.375), (0.80, 0.40),
            (0.36, 0.50), (0.66, 0.52), (0.20, 0.55), (0.36, 0.78),
            (0.62, 0.84), (0.44, 0.90), (0.78, 0.88), (0.20, 0.94)
        ]
        for (x, y) in innerTrees {
            plantTree(w * x, h * y, scaleMult: 0.82)
        }

        // ── ARBRES MOURANTS : la corruption gagne par le feuillage avant de
        // tuer le tronc. Autour des zones de danger, la canopée passe au roux
        // (`atree_autumn`) — le joueur voit la contamination AVANT le combat.
        // Positions choisies HORS sentier et hors clairières : un arbre planté
        // dans une clairière de combat en bloque l'accès (il pose une
        // empreinte solide) et masque le monstre qui y patrouille.
        let dying: [(CGFloat, CGFloat, CGFloat)] = [
            (0.19, 0.230, 0.96), (0.44, 0.290, 0.88),
            (0.62, 0.470, 0.92), (0.84, 0.610, 0.86),
            (0.60, 0.720, 0.92), (0.36, 0.660, 0.86)
        ]
        for (x, y, s) in dying {
            guard let tree = PixelArtSprites.animated(
                name: "atree_autumn", frames: 16,
                scale: scaleFor("atree_autumn_idle_1", height: canopyHeight * s),
                timePerFrame: 0.16,
                anchor: CGPoint(x: 0.5, y: 0.0),
                startFrame: Int(x * 37) % 16) else { continue }
            tree.position = CGPoint(x: w * x, y: h * y)
            tree.zPosition = propLayer(for: tree.position.y, in: h)
            tree.forEachDescendantSprite { sprite in
                sprite.color = SKColor(red: 0.32, green: 0.14, blue: 0.44, alpha: 1)
                sprite.colorBlendFactor = 0.28
            }
            addGroundShadow(under: tree, width: canopyHeight * 0.30 * s,
                            height: canopyHeight * 0.08 * s)
            add(tree, to: scene)
            registerFootprint(of: tree, widthRatio: 0.62, depthRatio: 0.5, maxDepth: 34)
        }

        // ── ARBRES MORTS près des zones de danger (teinte Aether) ──
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
            registerFootprint(of: tree, widthRatio: 0.62, depthRatio: 0.5, maxDepth: 34)
        }

        // Les combats de la forêt sont désormais portés par des monstres
        // baladeurs (GameManager.spawnForestRoamers) : plus de halos de danger
        // ni de crânes statiques marquant les zones de combat.

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

        let pathLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        pathLabel.text = String(localized: "world.deepPath")
        pathLabel.fontSize = 14
        pathLabel.fontColor = SKColor(red: 0.60, green: 0.40, blue: 0.85, alpha: 0.8)
        pathLabel.position = CGPoint(x: w * 0.55, y: h * 0.925)
        pathLabel.zPosition = -1
        add(pathLabel, to: scene)

        scatterForestProps(in: scene, w: w, h: h)

        let forestAmbiance = SKNode()
        forestAmbiance.addChild(ParticleFactory.forestFog(in: CGSize(width: w, height: h)))
        forestAmbiance.addChild(LightingEngine.godRays(in: CGSize(width: w, height: h)))
        forestAmbiance.addChild(LightingEngine.fireflies(in: CGSize(width: w, height: h)))
        forestAmbiance.addChild(AmbientLife.birds(in: CGSize(width: w, height: h), flocks: 1))
        addAtmosphere(forestAmbiance, to: scene)
        setZoneVignette(in: scene, alpha: 0.50)
        // Sous la canopée le grade froid reste ; la pluie s'ajoute parfois
        _ = rollWeatherRain(in: scene, chance: 18)
        LightingEngine.applyGrade(.forest, in: scene)
        AudioEngine.shared.setAmbience(.forest)
        debugDrawObstacles(in: scene)
    }

    /// Sous-bois : champignons, rochers, souches, pousses et os dispersés
    /// de façon déterministe, hors sentier et clairières.
    func scatterForestProps(in scene: SKScene, w: CGFloat, h: CGFloat) {
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
            // Rochers, souches et ossements bloquent ; le reste se marche.
            if !Self.walkablePropPrefixes.contains(where: name.hasPrefix) {
                registerFootprint(of: node, widthRatio: 0.6, maxDepth: 16)
            }
            placed += 1
        }
    }

    /// Scale dynamique des arbres pixel art de la forêt selon la largeur.
    /// Cible ~70 pt iPhone, ~110 pt iPad pour les arbres de bordure.
    func forestTreeScale(for sceneWidth: CGFloat) -> CGFloat {
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
        // Objet posé au sol : trié comme le reste du monde, sinon Kael
        // passe derrière un jouet qui est devant lui.
        toy.zPosition = depthLayer(for: toy.position.y)

        // Petit ours en bois — grille pixel (charte : zéro coin arrondi/glow)
        let bear = PixelIcons.custom(map: [
            ".OO....OO.",
            ".Oo....oO.",
            "..OOOOOO..",
            ".OoooooooO",
            ".OoDooDooO",
            ".OooooooO.",
            "..OonnOO..",
            "..OOOOOO..",
            ".OOooooOO.",
            "OOooooooOO",
            "OoOooooOoO",
            ".OOooooOO.",
            ".Oo....oO.",
            ".OO....OO."
        ], palette: [
            "O": SKColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1),
            "o": SKColor(red: 0.68, green: 0.45, blue: 0.20, alpha: 1),
            "D": SKColor(red: 0.20, green: 0.12, blue: 0.06, alpha: 1),
            "n": SKColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 1)
        ], pixel: 1.6)
        toy.addChild(bear)

        // Losange pixel doré flottant au-dessus du jouet
        let sparkle = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
        sparkle.fillColor = Palette.goldWorld
        sparkle.strokeColor = SKColor(red: 1, green: 0.95, blue: 0.6, alpha: 0.9)
        sparkle.lineWidth = 1
        sparkle.zRotation = .pi / 4
        sparkle.position = CGPoint(x: 0, y: 24)
        toy.addChild(sparkle)
        JuiceEngine.float(sparkle, distance: 4)

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
}
