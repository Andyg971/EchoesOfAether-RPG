import SpriteKit

// Carte du monde — ce qui fait de chaque lieu un LIEU : bornes du
// Sanctuaire, blocs de Cendreval et carreau de la mine, fûts des Ruines,
// garde du Seuil et troncs morts de la faille.
@MainActor
extension WorldBuilder {
    /// Pose un objet de décor à sa hauteur d'écran, pied au sol, sous les
    /// acteurs. `tint` ramène l'objet à la matière du lieu : sortis de leur
    /// pack d'origine, les props gardaient chacun leur couleur (gris bleu,
    /// rouge vif, gris de cimetière) au milieu d'un sol qui disait autre chose.
    func placeOverworldProp(_ asset: String, at p: CGPoint, height: CGFloat,
                            tint: SKColor? = nil, blend: CGFloat = 0.55,
                            in scene: SKScene) {
        guard let texH = PixelArtSprites.pixelHeight(of: asset), texH > 0,
              let node = PixelArtSprites.still(name: asset, scale: height / texH,
                                               anchor: CGPoint(x: 0.5, y: 0.0))
        else { return }
        if let tint {
            node.forEachDescendantSprite { sprite in
                sprite.color = tint
                sprite.colorBlendFactor = blend
            }
        }
        node.position = p
        node.zPosition = actorLayer(for: p.y) - 0.2
        add(node, to: scene)
    }

    // MARK: - Sanctuaire

    /// SANCTUAIRE : ce qui fait un lieu consacré.
    /// Un cercle de bornes de pierre autour du parvis, posé à l'ANGLE —
    /// sept pierres régulières, parce qu'une main les a dressées. Un semis
    /// aléatoire aurait dit « cailloux », pas « sanctuaire ».
    func dressOverworldShrine(_ geo: OverworldGeometry, in scene: SKScene) {
        let pShrine = geo.shrine
        let shrineRX = geo.shrineRX, shrineRY = geo.shrineRY
        /// Pièce de mobilier sacré ramenée à la pierre de l'ange. Sans la
        /// teinte, chaque borne gardait le gris bleu de son pack d'origine :
        /// sept objets dépareillés autour d'une statue.
        func placeShrinePiece(_ asset: String, at p: CGPoint, height: CGFloat,
                              tinted: Bool = true) {
            placeOverworldProp(asset, at: p, height: height,
                               tint: tinted ? geo.shrineStone : nil, in: scene)
        }

        // Six petites statues d'orants, alternées, dans la même pierre pâle que
        // l'ange. Le premier essai dressait des `gy_stone_*` et des
        // `pillar_grey_*` : ce sont des PIERRES TOMBALES, elles transformaient
        // le sanctuaire en cimetière — un contresens à trois zones du Seuil.
        let shrineStones = ["me_statue_putto", "angel_statue_2", "me_statue_putto",
                            "angel_statue_2", "me_statue_putto", "angel_statue_2"]
        for (i, asset) in shrineStones.enumerated() {
            let a = CGFloat(i) / CGFloat(shrineStones.count) * .pi * 2 - .pi / 2
            placeShrinePiece(asset,
                             at: CGPoint(x: pShrine.x + cos(a) * shrineRX * 0.76,
                                         y: pShrine.y + sin(a) * shrineRY * 0.78),
                             height: 40, tinted: false)
        }
        // Cierges au pied du parvis, bancs de pèlerins face à l'ange, vasques
        // en fond : ce sont les traces d'un lieu FRÉQUENTÉ, pas un monument.
        placeShrinePiece("gy_candle", at: CGPoint(x: pShrine.x - 66, y: pShrine.y + 2),
                         height: 38)
        placeShrinePiece("gy_candle", at: CGPoint(x: pShrine.x + 66, y: pShrine.y + 2),
                         height: 38)
        placeShrinePiece("me_bench_1", at: CGPoint(x: pShrine.x - 52, y: pShrine.y - 60),
                         height: 22, tinted: false)
        placeShrinePiece("me_bench_1", at: CGPoint(x: pShrine.x + 52, y: pShrine.y - 60),
                         height: 22, tinted: false)
        placeShrinePiece("me_statue_grey",
                         at: CGPoint(x: pShrine.x - 122, y: pShrine.y - 46), height: 54)
        placeShrinePiece("me_fountain",
                         at: CGPoint(x: pShrine.x + 122, y: pShrine.y - 46), height: 50)
        // Fleurs blanches sur le pourtour entretenu : l'anneau d'offrandes qui
        // sépare le parvis de la prairie sauvage.
        plantMass([Flora(asset: "me_flower_white", height: 13, weight: 4),
                   Flora(asset: "me_flower_blue",  height: 13, weight: 3),
                   Flora(asset: "me_flower_pink",  height: 12, weight: 2),
                   Flora(asset: "me_grass_clean_2", height: 11, weight: 2)],
                  center: pShrine, radiusX: shrineRX * 0.94, radiusY: shrineRY * 0.94,
                  step: 30, coreDensity: 0.06, edgeDensity: 0.46,
                  avoiding: [CGRect(x: pShrine.x - 62, y: pShrine.y - 46,
                                    width: 124, height: 92)],
                  in: scene)
    }

    // MARK: - Montagnes de Cendreval

    /// MONTAGNES DE CENDREVAL : les blocs, sur leur dalle — puis le carreau
    /// de la mine. Une entrée de mine, c'est un CHANTIER : le POI n'était
    /// qu'une falaise couchée sur la terre battue — rien ne disait qu'on y
    /// descendait chercher du minerai.
    func dressOverworldMountains(_ geo: OverworldGeometry, in scene: SKScene) {
        let pMines = geo.mines
        let minesClearing = CGRect(x: pMines.x - 78, y: pMines.y - 52,
                                   width: 156, height: 104)
        let thresholdClearing = CGRect(x: geo.threshold.x - geo.thresholdRX * 0.80,
                                       y: geo.threshold.y - geo.thresholdRY * 0.80,
                                       width: geo.thresholdRX * 1.60,
                                       height: geo.thresholdRY * 1.60)
        plantMass([Flora(asset: "ds_rock_spire", height: 62, weight: 4),
                   Flora(asset: "ds_rock_big",   height: 44, weight: 3),
                   Flora(asset: "ds_boulder",    height: 34, weight: 3),
                   Flora(asset: "ds_boulder2",   height: 30, weight: 2),
                   Flora(asset: "rock_1",        height: 26, weight: 2),
                   Flora(asset: "rock_3",        height: 22, weight: 2)],
                  center: geo.mountCenter, radiusX: geo.mountRX, radiusY: geo.mountRY,
                  step: 42, coreDensity: 0.80, edgeDensity: 0.20,
                  avoiding: [minesClearing, thresholdClearing],
                  in: scene)

        // Passés au brun de suie : sortis du pack village, la charrette
        // rouge vif et les tonneaux bleus donnaient au carreau de mine un
        // air de kermesse. Le charbon salit tout ce qu'on descend dedans.
        let soot = SKColor(red: 0.34, green: 0.26, blue: 0.20, alpha: 1)
        for (asset, dx, dy, hgt) in [("me_wood_cart", -86.0, -30.0, 30.0),
                                     ("me_cart_empty", 84.0, -34.0, 28.0),
                                     ("ext_cut_wood", -52.0, -50.0, 14.0),
                                     ("me_cut_wood", 56.0, -54.0, 16.0),
                                     ("village_lantern_1", -70.0, 20.0, 34.0),
                                     ("village_lantern_1", 70.0, 20.0, 34.0),
                                     ("ds_ladder", 104.0, 6.0, 26.0),
                                     ("me_barrel_1", -104.0, 4.0, 20.0),
                                     ("me_barrel_2", -92.0, -8.0, 20.0),
                                     ("ds_rock_pile", 40.0, -68.0, 20.0),
                                     ("ds_rock_pile", -34.0, -72.0, 18.0)] {
            placeOverworldProp(asset,
                               at: CGPoint(x: pMines.x + CGFloat(dx), y: pMines.y + CGFloat(dy)),
                               height: CGFloat(hgt), tint: soot, in: scene)
        }
    }

    // MARK: - Ruines de la Source

    /// RUINES DE LA SOURCE : ce qui reste d'un sanctuaire plus vieux que
    /// le Sanctuaire. Colonnes couchées, fûts brisés, dalles descellées —
    /// et pas une fleur : la Source est tarie.
    func dressOverworldRuins(_ geo: OverworldGeometry, in scene: SKScene) {
        let pRuins = geo.ruins
        let ruinsRX = geo.ruinsRX, ruinsRY = geo.ruinsRY
        var ruinSeed: UInt64 = 0x5057_3E11
        func ruinNext() -> CGFloat {
            ruinSeed = ruinSeed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(ruinSeed >> 40) / CGFloat(1 << 24)
        }
        // Uniquement des fûts et des blocs : `pillar_grey_*` sont des
        // stèles funéraires, elles peuplaient les ruines de tombes.
        let assets = ["ds_ruin_column", "column_broken_1", "ds_ruin_stone",
                      "ds_ruin_column", "column_broken_1", "ds_ruin_stone"]
        for i in 0..<14 {
            let a = CGFloat(i) / 14 * .pi * 2 + 0.35
            let ray = 0.62 + ruinNext() * 0.34
            // Deux tirages par fût, dans cet ordre (rayon, puis hauteur) :
            // la suite est déterministe, l'ordre fait la disposition.
            let height = 32 + ruinNext() * 22
            placeOverworldProp(assets[i % assets.count],
                               at: CGPoint(x: pRuins.x + cos(a) * ruinsRX * ray,
                                           y: pRuins.y + sin(a) * ruinsRY * ray),
                               height: height, in: scene)
        }
        plantMass([Flora(asset: "ds_grass_dry", height: 12, weight: 4),
                   Flora(asset: "rock_5", height: 10, weight: 3),
                   Flora(asset: "rock_9", height: 10, weight: 3),
                   Flora(asset: "gy_tree", height: 46, weight: 1)],
                  center: pRuins, radiusX: ruinsRX, radiusY: ruinsRY,
                  step: 44, coreDensity: 0.18, edgeDensity: 0.34,
                  avoiding: [CGRect(x: pRuins.x - 60, y: pRuins.y - 42,
                                    width: 120, height: 84)],
                  in: scene)
    }

    // MARK: - Le Seuil et la faille

    /// LE SEUIL : la garde du portail. Arbres morts en cercle, stèles et
    /// cierges éteints — la frontière est TENUE, elle n'est pas qu'un décor.
    /// Puis LA FAILLE DU CŒUR DU VIDE : hors d'atteinte, mais visible depuis
    /// le Seuil. Des troncs morts et rien d'autre — c'est le bout du monde.
    func dressOverworldThreshold(_ geo: OverworldGeometry, in scene: SKScene) {
        let pThreshold = geo.threshold
        let thrRX = geo.thresholdRX, thrRY = geo.thresholdRY
        let assets = ["gy_tree", "gy_tomb_grey_1", "gy_tree",
                      "gy_cross_grey", "gy_tomb_black", "gy_candle_off"]
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * .pi * 2 + 0.25
            if abs(sin(a)) > 0.86 { continue }        // on laisse passer au sud
            let asset = assets[i % assets.count]
            // Teintés du violet du Vide : sortis de leur pack, ils gardaient le
            // gris d'un cimetière ordinaire au milieu d'un sol corrompu.
            placeOverworldProp(asset,
                               at: CGPoint(x: pThreshold.x + cos(a) * thrRX * 0.74,
                                           y: pThreshold.y + sin(a) * thrRY * 0.76),
                               height: asset == "gy_tree" ? 52 : 30,
                               tint: geo.voidShade, blend: 0.45, in: scene)
        }
        // À 0,5 d'échelle ces troncs faisaient deux fois la hauteur du
        // portail et volaient la vedette au Seuil. Ils sont le FOND.
        let pVoid = geo.voidheart
        let riftShade = SKColor(red: 0.30, green: 0.12, blue: 0.46, alpha: 1)
        for i in 0..<8 {
            let a = CGFloat(i) / 8 * .pi * 2 + 0.5
            placeOverworldProp("gy_tree",
                               at: CGPoint(x: pVoid.x + cos(a) * 150, y: pVoid.y + sin(a) * 104),
                               height: 44, tint: riftShade, blend: 0.80, in: scene)
        }
    }
}
