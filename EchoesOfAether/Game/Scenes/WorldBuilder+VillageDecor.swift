import SpriteKit

// Village de Solis — mobilier, enseignes, puits, clôtures : le décor bâti.
extension WorldBuilder {
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
}
