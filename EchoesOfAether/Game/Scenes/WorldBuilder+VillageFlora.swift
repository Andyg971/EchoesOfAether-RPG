import SpriteKit

// Village de Solis — forêt animée, jardins, habitants et fleurs.
extension WorldBuilder {
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
