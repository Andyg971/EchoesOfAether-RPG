import SpriteKit

// Marqueurs de quête : talisman, fer corrompu, herbe lunaire, insigne, « ! » sur les PNJ.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Talisman perdu (quête de la villageoise)

    /// La croix de bois du fils, à moitié enterrée sur le sentier ouest.
    func addMedallionMarker(in scene: SKScene) {
        guard medallionMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.28, y: h * 0.72)
        marker.zPosition = 60   // marqueur de quête : au-dessus du monde, sous le HUD
        if let cross = PixelArtSprites.still(name: "gy_cross_wood", scale: 0.30,
                                             anchor: CGPoint(x: 0.5, y: 0.0)) {
            marker.addChild(cross)
        }
        let glow = SKSpriteNode(color: SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 0.30),
                                size: CGSize(width: 30, height: 30))
        glow.zRotation = .pi / 4
        glow.position = CGPoint(x: 0, y: 10)
        glow.zPosition = -0.5
        marker.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        medallionMarker = marker
    }

    func removeMedallionMarker() {
        medallionMarker?.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
        if let m = medallionMarker, let idx = backdropNodes.firstIndex(where: { $0 === m }) {
            backdropNodes.remove(at: idx)
        }
        medallionMarker = nil
    }

    // MARK: - Fer corrompu (quête de Bram)

    /// Veine de fer noirci qui affleure à l'est du bosquet.
    func addOreMarker(in scene: SKScene) {
        guard oreMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        // ATTENTION : loin du campement+cristal (0.52, 0.52) — le tap du
        // cristal de save est prioritaire et volerait le ramassage.
        marker.position = CGPoint(x: w * 0.40, y: h * 0.63)
        marker.zPosition = 60   // marqueur de quête : au-dessus du monde, sous le HUD

        // Bloc de fer corrompu — grille pixel, filons violets (zéro glow)
        let rock = PixelIcons.custom(map: [
            "....RRRR....",
            "..RRrrrrRR..",
            ".RrvRrrRvrR.",
            "RrrvvrrrvvrR",
            "RrrrvrrrrvrR",
            "RrvrrrRvrrrR",
            "RrvvrrrvvrrR",
            ".RrrrRrrrrR.",
            "..RRRRRRRR.."
        ], palette: [
            "R": SKColor(red: 0.10, green: 0.09, blue: 0.14, alpha: 1),
            "r": SKColor(red: 0.20, green: 0.18, blue: 0.26, alpha: 1),
            "v": SKColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1)
        ], pixel: 1.8)
        marker.addChild(rock)

        // Étincelle pixel violette (repère œil, cohérent charte)
        let sparkle = SKSpriteNode(color: SKColor(red: 0.65, green: 0.40, blue: 0.95, alpha: 1),
                                   size: CGSize(width: 7, height: 7))
        sparkle.zRotation = .pi / 4
        sparkle.position = CGPoint(x: 0, y: 18)
        marker.addChild(sparkle)
        JuiceEngine.float(sparkle, distance: 4)

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        oreMarker = marker
    }

    func removeOreMarker() {
        removeCollectMarker(&oreMarker)
    }

    // MARK: - Herbe lunaire (quête de Sage)

    /// Herbe pâle qui luit entre les racines, à l'ouest du sentier.
    func addHerbMarker(in scene: SKScene) {
        guard herbMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.12, y: h * 0.40)
        marker.zPosition = 60   // marqueur de quête : au-dessus du monde, sous le HUD

        // Brins luminescents. Carrés nets : un `cornerRadius: 1` sur un brin
        // de 2 pt de large le transformait en gélule.
        for (dx, height) in [(-4, 10), (0, 14), (4, 9)] {
            let blade = SKSpriteNode(color: SKColor(red: 0.70, green: 0.95, blue: 0.85, alpha: 0.95),
                                     size: CGSize(width: 2, height: CGFloat(height)))
            blade.position = CGPoint(x: CGFloat(dx), y: CGFloat(height) / 2)
            marker.addChild(blade)
        }

        let halo = pixelHalo(color: SKColor(red: 0.70, green: 0.95, blue: 0.85, alpha: 1),
                             radius: 13)
        halo.position = CGPoint(x: 0, y: 6)
        marker.addChild(halo)

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        herbMarker = marker
    }

    func removeHerbMarker() {
        removeCollectMarker(&herbMarker)
    }

    // MARK: - Insigne de l'éclaireur (quête de Garen)

    /// L'insigne de Tomm, à moitié enfoui sur la sente est.
    func addBadgeMarker(in scene: SKScene) {
        guard badgeMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.68, y: h * 0.18)
        marker.zPosition = 60   // marqueur de quête : au-dessus du monde, sous le HUD

        // Écusson métallique terni. Coins vifs : `cornerRadius: 4` sur 10×12
        // arrondissait l'écusson jusqu'à en faire une pastille.
        let shield = SKSpriteNode(color: SKColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1),
                                  size: CGSize(width: 9, height: 12))
        shield.zRotation = 0.5   // à moitié planté dans le sol
        marker.addChild(shield)
        // Éclat de métal poli, un pixel plus clair.
        let sheen = SKSpriteNode(color: SKColor(red: 0.80, green: 0.82, blue: 0.88, alpha: 1),
                                 size: CGSize(width: 3, height: 5))
        sheen.zRotation = 0.5
        sheen.position = CGPoint(x: -1, y: 2)
        marker.addChild(sheen)

        marker.addChild(pixelHalo(color: SKColor(red: 0.60, green: 0.70, blue: 0.90, alpha: 1),
                                  radius: 12))

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        badgeMarker = marker
    }

    func removeBadgeMarker() {
        removeCollectMarker(&badgeMarker)
    }

    /// Le cristal-mère (quête de Lyra), planté au cœur mort de la forêt.
    ///
    /// Violet d'Aether, la couleur de la marque de Kael et de l'Entaille
    /// Noire : cette chose et lui sont de la même famille, et ça doit se voir
    /// avant même le dialogue.
    func addCrystalMarker(in scene: SKScene) {
        guard crystalMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.78, y: h * 0.70)
        marker.zPosition = 60

        // Éclat dressé : losange d'Aether, comme les pastilles du combat.
        let shard = SKSpriteNode(color: Palette.aetherDeep,
                                 size: CGSize(width: 11, height: 11))
        shard.zRotation = .pi / 4
        marker.addChild(shard)
        let core = SKSpriteNode(color: SKColor(red: 0.90, green: 0.80, blue: 1.00, alpha: 1),
                                size: CGSize(width: 4, height: 4))
        core.zRotation = .pi / 4
        marker.addChild(core)

        marker.addChild(pixelHalo(color: Palette.aetherDeep,
                                  radius: 13))

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        crystalMarker = marker
    }

    func removeCrystalMarker() {
        removeCollectMarker(&crystalMarker)
    }

    /// Halo de repérage, en pixel strict.
    ///
    /// Les marqueurs de collecte signalaient leur objet avec un
    /// `SKShapeNode(circleOfRadius:)` rempli d'un alpha faible et animé en
    /// échelle : un disque dégradé, à bords lissés, qui grossissait et
    /// rétrécissait. C'est exactement ce que la charte pixel exclut — et à
    /// l'écran ça se lisait comme une tache grise qui scintille, sans rapport
    /// avec le reste du jeu.
    ///
    /// Ici : quatre pastilles carrées posées en losange, qui clignotent
    /// ensemble. Les angles sont droits, donc les positions tombent sur des
    /// entiers et les carrés restent nets. Aucun dégradé, aucune échelle
    /// animée — seulement l'alpha, qui ne floute rien.
    func pixelHalo(color: SKColor, radius: CGFloat) -> SKNode {
        let halo = SKNode()
        for (dx, dy) in [(0.0, 1.0), (1.0, 0.0), (0.0, -1.0), (-1.0, 0.0)] {
            let pip = SKSpriteNode(color: color, size: CGSize(width: 3, height: 3))
            pip.position = CGPoint(x: CGFloat(dx) * radius, y: CGFloat(dy) * radius)
            halo.addChild(pip)
        }
        halo.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.30, duration: 0.55),
            .fadeAlpha(to: 1.00, duration: 0.55)
        ])))
        return halo
    }

    /// Fade + retrait d'un marqueur de collecte (factorisation commune).
    func removeCollectMarker(_ marker: inout SKNode?) {
        marker?.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
        if let m = marker, let idx = backdropNodes.firstIndex(where: { $0 === m }) {
            backdropNodes.remove(at: idx)
        }
        marker = nil
    }

    // MARK: - Marqueurs de quête « ! » sur les PNJ

    /// Point d'exclamation doré pulsant au-dessus d'un PNJ qui a une
    /// quête à proposer. `visible: false` le retire.
    func setQuestMarker(on npc: SKNode, visible: Bool) {
        let markName = "questMark"
        if !visible {
            npc.childNode(withName: markName)?.removeFromParent()
            return
        }
        guard npc.childNode(withName: markName) == nil else { return }
        let mark = SKLabelNode(fontNamed: PixelUI.uiFont)
        mark.name = markName
        mark.text = "!"
        mark.fontSize = 20
        mark.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1)
        mark.position = CGPoint(x: 0, y: 40)
        mark.zPosition = 5
        npc.addChild(mark)
        mark.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 5, duration: 0.4),
            .moveBy(x: 0, y: -5, duration: 0.4)
        ])))
    }

    func decorateVillage(in scene: SKScene) {
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
    // Un arbre sur deux RESPIRE : `atree_leaf` est un chêne d'été de
    // 22 frames qui laisse tomber ses feuilles. Alterné avec les arbres ME
    // fixes, il anime toute la lisière sans la peupler de clones — et il
    // reste vert vif, là où la forêt reçoit les variantes froides.
    for (i, (asset, x, y, s)) in borderTrees.enumerated() {
        let p = CGPoint(x: w * x, y: h * y)
        if i.isMultiple(of: 2) {
            addPixelProp(asset, in: scene, at: p, scale: s)
        } else {
            addAnimatedProp("atree_leaf", frames: 22, in: scene, at: p,
                            height: 144 * s, phase: (i * 7) % 22,
                            timePerFrame: 0.12 + Double(i % 3) * 0.02)
        }
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

    plantVillageForest(in: scene, w: w, h: h)
    decorateVillageGardens(in: scene, w: w, h: h)
    populateVillage(in: scene, w: w, h: h)

    // Les trois figurants d'ambiance qui plantaient ici un clone de Garen,
    // de Sage et d'un badaud sont remplacés par les villageois `gv_*` de
    // `populateVillage` : de vrais habitants, un par porte, et qui marchent.

    // ═══ FLEURS ÉPARSES (positions seedées, hors chemins/maisons) ═══
    scatterVillageFlowers(in: scene, w: w, h: h)
    }

    /// La FORÊT ENTRE DANS LE VILLAGE : bosquets d'arbres animés posés aux
    /// endroits où le regard s'arrête, pas semés au hasard.
    ///
    /// Trois intentions, une par essence :
    /// - `apine_cool` (pins de la Forêt d'Ébène) au NORD : la forêt commence
    ///   avant la porte. En sortant, Kael y entre déjà ;
    /// - `atree_cool` / `atree_dark` en bosquets adossés aux lisières et à
    ///   l'étang, pour épaissir les bords sans fermer les cours ;
    /// - `atree_autumn` en accents isolés — un roux au milieu des verts
    ///   accroche l'œil, une allée entière de roux ferait décor d'automne.
    ///
    /// Ils bougent tous (16 frames pour les feuillus, 8 pour les pins), avec
    /// une frame de départ et une cadence propres : synchronisés, ils
    /// ondulent d'un bloc et l'illusion de vent tombe.
    func plantVillageForest(in scene: SKScene, w: CGFloat, h: CGFloat) {
    // (asset, frames, x, y, hauteur à l'écran)
    let grove: [(String, Int, CGFloat, CGFloat, CGFloat)] = [
        // ── Bosquet de l'étang (ouest, y ≈ 0.46) : la berge sous les arbres
        ("atree_cool", 16, 0.045, 0.505, 96),
        ("atree_dark", 16, 0.145, 0.487, 86),
        ("atree_autumn", 16, 0.038, 0.425, 78),
        // ── Verger derrière la maison de Kael (sud-ouest)
        ("atree_dark", 16, 0.222, 0.118, 88),
        ("atree_cool", 16, 0.288, 0.140, 80),
        // ── Rideau de la ferme est : coupe-vent au-dessus du potager
        ("atree_cool", 16, 0.700, 0.128, 92),
        ("atree_dark", 16, 0.775, 0.108, 84),
        ("atree_autumn", 16, 0.845, 0.128, 76),
        // ── Ombrage de la place (nord-est et nord-ouest de la fontaine)
        ("atree_cool", 16, 0.352, 0.455, 92),
        ("atree_dark", 16, 0.648, 0.455, 88),
        // ── Creux entre l'herboriste et l'armurerie : respiration verte
        ("atree_dark", 16, 0.335, 0.560, 84),
        ("atree_cool", 16, 0.655, 0.680, 88),
        // ── APPROCHE DE LA FORÊT (nord) : les pins descendent sur le village
        ("apine_cool", 8, 0.115, 0.868, 128),
        ("apine_cool", 8, 0.255, 0.900, 116),
        ("apine_cool", 8, 0.330, 0.955, 132),
        ("apine_cool", 8, 0.680, 0.955, 132),
        ("apine_cool", 8, 0.760, 0.900, 116),
        ("apine_cool", 8, 0.890, 0.868, 128),
        ("atree_cool", 16, 0.415, 0.880, 92),
        ("atree_dark", 16, 0.590, 0.880, 92)
    ]
    for (i, (asset, frames, x, y, height)) in grove.enumerated() {
        addAnimatedProp(asset, frames: frames, in: scene,
                        at: CGPoint(x: w * x, y: h * y), height: height,
                        phase: (i * 5) % frames,
                        timePerFrame: 0.14 + Double(i % 4) * 0.018)
    }
    }

    /// Jardins devant les portes : potées, urnes, statues et conifères
    /// (planche « Garden Decorations »). Le village n'avait que des fleurs
    /// posées à même l'herbe — rien qui dise qu'on ENTRETIENT ces cours.
    /// Les hauteurs sont visées à l'écran : les planches vont de 13 à 102 px,
    /// une échelle commune ferait des potées de la taille d'un cyprès.
    func decorateVillageGardens(in scene: SKScene, w: CGFloat, h: CGFloat) {
    // (asset, x, y, hauteur à l'écran en points)
    let gardens: [(String, CGFloat, CGFloat, CGFloat)] = [
        // Maison de Kael — deux potées de part et d'autre du seuil
        ("gh_pot_lilac", 0.283, 0.070, 26), ("gh_pot_fern", 0.357, 0.070, 30),
        // Cour country sud
        ("gh_urn_roses", 0.185, 0.152, 40), ("gh_pot_bush", 0.098, 0.152, 26),
        // Cour moderne est
        ("gh_urn_spiky", 0.845, 0.152, 42), ("gh_pot_olive", 0.757, 0.152, 28),
        // Herboriste — l'atelier de Mara déborde de pots
        ("gh_urn_roses", 0.267, 0.572, 40), ("gh_pot_fern", 0.176, 0.572, 30),
        ("gh_pot_olive", 0.196, 0.556, 28),
        // Armurerie — urnes de trempe près de la forge
        ("gh_urn_small", 0.446, 0.618, 18), ("gh_urn_large", 0.556, 0.618, 22),
        // Auberge
        ("gh_pot_lilac", 0.735, 0.570, 26), ("gh_pot_bush", 0.828, 0.570, 26),
        // Manoir du chef — allée de cyprès et bustes sur socle
        ("gh_cypress", 0.118, 0.760, 96), ("gh_cypress", 0.222, 0.760, 96),
        ("gh_statue_bust", 0.140, 0.742, 42), ("gh_pedestal", 0.200, 0.742, 38),
        // Chapelle — cyprès de cimetière, conifère en fond
        ("gh_cypress", 0.772, 0.762, 96), ("gh_conifer", 0.872, 0.772, 98),
        ("gh_statue_bust", 0.820, 0.744, 42),
        // Porte nord — deux conifères encadrent la sortie, écartés des
        // statues d'angle (0.43 / 0.57) qui tiennent déjà le passage
        ("gh_conifer", 0.345, 0.938, 100), ("gh_conifer", 0.655, 0.938, 100),
        // Pas de vasque sur la place : la fontaine, quatre bancs, l'étal et
        // les paniers l'occupent déjà. Les deux que j'y avais posées
        // atterrissaient PILE sur les bancs.
    ]
    for (asset, x, y, height) in gardens {
        addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y),
                     scale: scaleFor(asset, height: height))
    }
    }

    /// Peuple le village de FIGURANTS animés : villageois `gv_*` composés
    /// couche par couche (peau, vêtements, cheveux, arme), un par porte. Chaque
    /// maison a enfin un habitant devant chez elle.
    ///
    /// Aucun n'est interactif : les PNJ de quête (`dorin`, `mara`, `sage`…)
    /// restent les seuls à répondre au tap. Les figurants ne posent donc PAS
    /// d'empreinte — ils flânent, et un promeneur solide finirait par coincer
    /// Kael contre un mur.
    ///
    /// Ils sont conservés dans `villageFolk` pour que `startVillageWander` les
    /// mette en marche avec les PNJ de quête : un village où seuls la moitié
    /// des habitants bougent a l'air à moitié en pause.
    func populateVillage(in scene: SKScene, w: CGFloat, h: CGFloat) {
    villageFolk.removeAll()
    // (asset, x, y, hauteur écran, miroir)
    let folk: [(String, CGFloat, CGFloat, CGFloat, Bool)] = [
        ("gv_farmer", 0.690, 0.074, 46, true),      // potager est
        ("gv_smith", 0.585, 0.628, 46, true),       // devant l'armurerie
        ("gv_maid", 0.866, 0.566, 45, true),        // seuil de l'auberge
        ("gv_herbalist", 0.132, 0.578, 45, false),  // jardin de l'herboriste
        ("gv_weaver", 0.243, 0.155, 45, false),     // cour country sud
        ("gv_elder", 0.888, 0.760, 46, true),       // parvis de la chapelle
        ("gv_guard", 0.440, 0.930, 46, false),      // faction, porte nord
        ("gv_scout", 0.560, 0.030, 45, true)        // arrivée, portail sud
    ]
    for (i, (asset, x, y, height, flipped)) in folk.enumerated() {
        guard let node = addAnimatedProp(
            asset, frames: 6, in: scene,
            at: CGPoint(x: w * x, y: h * y), height: height,
            phase: (i * 3) % 6,
            timePerFrame: 0.15 + Double(i % 4) * 0.02,
            flipped: flipped, blocking: false) else { continue }
        villageFolk.append(node)
    }
    }

    /// Fleurs et buissons dispersés de façon déterministe (LCG seedé) sur
    /// l'herbe libre — jamais sur les chemins, maisons, place ou étang.
    func scatterVillageFlowers(in scene: SKScene, w: CGFloat, h: CGFloat) {
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
        // Les buissons touffus bloquent le passage (on les contourne) ;
        // les fleurs plates restent franchissables.
        if name.contains("bush") {
            registerFootprint(of: node, widthRatio: 0.7, depthRatio: 0.5, maxDepth: 22)
        }
        placed += 1
    }
    }
}
