import SpriteKit

// Désert d'Ossara — entrée dans la zone, orchestration de la construction,
// échelles du pack. Les phases vivent dans `+DesertTerrain`, `+DesertProps`,
// `+DesertTown`, `+DesertPOI`.
@MainActor
extension WorldBuilder {
    // MARK: - Désert d'Ossara (voyage depuis la carte du monde)

    func switchToDesert(in scene: SKScene, progress: Int = 0, chestTaken: Bool = false) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.42, green: 0.32, blue: 0.16, alpha: 1)
        buildDesert(in: scene, progress: progress, chestTaken: chestTaken)
    }

    /// Dunes brûlées d'Ossara : sable ocre, roches érodées, carcasses
    /// de caravanes, oasis au nord-est. Une hauteur d'écran, pas de scroll.
    func buildDesert(in scene: SKScene, progress: Int, chestTaken: Bool) {
        let w = scene.size.width
        // Ossara devient un trek, comme la forêt. Elle tenait sur un écran —
        // `worldHeight` valait `scene.size.height`, la caméra ne bougeait pas —
        // pendant que le village en fait 4,2 et la forêt 2,8 : trois POI collés
        // les uns aux autres, et le désert le plus petit de la carte.
        //
        // Trois hauteurs d'écran, et une traversée qui raconte quelque chose :
        // on entre par le sud, on franchit les dunes, on trouve la cité des
        // caravanes, on longe le canyon, on atteint l'oasis au nord.
        let h = scene.size.height * 3.0
        worldHeight = h

        // Sol : le sable du pack désert, pas de la terre de forêt reteintée.
        //
        // Un seul sable en fond. Mélanger les quatre variantes donnait un
        // damier : `ds_sand` est lisse, `ds_dune` est strié — côte à côte au
        // hasard, on voit la grille au lieu du désert. Les variantes servent
        // de plaques posées exprès (voir plus bas), pas de bruit de fond.
        addTiledFloor(in: scene,
                      tileNames: ["ds_sand"],
                      fallbackColor: SKColor(red: 0.72, green: 0.56, blue: 0.30, alpha: 1),
                      tileScale: WorldBuilder.desertScale,
                      tint: nil,
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Titre de zone
        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.desert.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.45, green: 0.32, blue: 0.14, alpha: 0.8)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.045)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        let cell: CGFloat = 96 * WorldBuilder.desertScale
        addDesertTerrain(in: scene, w: w, h: h, cell: cell)

        // ── Ceinture de falaises : Ossara est un canyon, pas une nappe ──
        addDesertCliffs(in: scene, w: w, h: h)

        // ── Sud : les dunes d'entrée ──
        addDesertSouthProps(in: scene, w: w, h: h)

        // ── Cité des caravanes (centre) : le cœur de la zone ──
        addDesertTown(in: scene, w: w, h: h)

        // ── Nord : le canyon, ses éboulis, les flancs ──
        addDesertNorthProps(in: scene, w: w, h: h)

        // ── L'allée pavée : de l'entrée à la porte sud, crochet compris ──
        addDesertPathTiles(in: scene, w: w, h: h)

        // ── Oasis et palmiers isolés ──
        addDesertOasisAndPalms(in: scene, w: w, h: h)

        // ── LES TROIS TERRAINS DE COMBAT ──
        addDesertBattlegrounds(in: scene, w: w, h: h, cell: cell)

        // ── Détails semés sur le sable libre (hors cité/oasis/bords) ──
        scatterDesertDetails(in: scene, w: w, h: h)

        // Coffre enfoui (flanc ouest, à l'ombre du canyon) : les pillards ne
        // l'ont jamais trouvé.
        if !chestTaken {
            let chest = makeBuriedChest(at: CGPoint(x: w * 0.10, y: DesertPOI.chestY * h))
            chest.name = "desertChest"
            add(chest, to: scene)
        }

        // Sortie au sud : halo — retour vers la zone d'origine
        let exitGlow = SKShapeNode(circleOfRadius: 34)
        exitGlow.fillColor = SKColor(red: 0.55, green: 0.75, blue: 0.55, alpha: 0.10)
        exitGlow.strokeColor = SKColor(red: 0.70, green: 0.90, blue: 0.70, alpha: 0.25)
        exitGlow.lineWidth = 1.5
        exitGlow.position = CGPoint(x: w * 0.50, y: h * DesertPOI.exitY)
        add(exitGlow, to: scene)
        JuiceEngine.pulse(exitGlow, scale: 1.15)
        let exitLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        exitLabel.text = String(localized: "world.desert.exit")
        exitLabel.fontSize = 12
        exitLabel.fontColor = SKColor(red: 0.40, green: 0.28, blue: 0.12, alpha: 0.85)
        exitLabel.position = CGPoint(x: w * 0.50, y: h * DesertPOI.exitY + 42)
        add(exitLabel, to: scene)

        // Cristal de sauvegarde, à l'entrée de la cité.
        addSaveCrystal(at: CGPoint(x: w * 0.62, y: h * 0.40), in: scene)

        // Poussière en suspension : chaleur d'Ossara + rares ombres de nuages
        let desertAmbiance = SKNode()
        desertAmbiance.addChild(ParticleFactory.ruinsAsh(in: scene.size))
        desertAmbiance.addChild(LightingEngine.cloudShadows(in: scene.size, count: 2))
        addAtmosphere(desertAmbiance, to: scene)
        setZoneVignette(in: scene, alpha: 0.30)   // plein soleil, vignette légère
        LightingEngine.applyGrade(.desert, in: scene)
        debugDrawObstacles(in: scene)   // --show-obstacles : audit (desert)
        LightingEngine.startDayCycle(in: scene, day: .desert, phaseSeconds: 90)
        AudioEngine.shared.setAmbience(.desert)
    }

    /// Échelle d'affichage du pack désert.
    ///
    /// Le pack est dessiné plus gros que le reste du jeu : posé à 1.0, une
    /// maison faisait 226 pt — CINQ fois Kael (43 pt), quand le village pose
    /// les siennes à 1,9× et son chalet à 2,9×. Le désert écrasait tout.
    ///
    /// À 0,5 les proportions retombent dans la fourchette du village (maison
    /// 1,7×, chalet 2,6×, cactus 1,1×) et la densité de pixels devient exacte-
    /// ment la sienne : 0,50 pt par pixel source, comme `me_grass` (48 px
    /// affiché en 24 pt). C'est ce qui rend un tileset cohérent avec le
    /// voisin — pas la taille du sprite, la taille du PIXEL.
    static let desertScale: CGFloat = 0.5

    /// Échelles dérogatoires, par asset.
    ///
    /// La densité de pixels vaut pour le sol et la végétation ; sur le bâti
    /// elle donnait des maisons à peine plus hautes que Kael (72 pt contre
    /// 43) et un puits qui lui arrivait au genou. Andy : « c'était mieux
    /// légèrement plus gros ». Le bâti monte donc d'un cran — assez pour
    /// dominer Kael, loin du ×1,0 d'origine qui écrasait la zone.
    static let desertScales: [String: CGFloat] = [
        "ds_house_red":   0.65,
        "ds_house_sand":  0.65,
        "ds_house_large": 0.65,
        "ds_gate":        0.65,
        "ds_tent_big":    0.58,
        "ds_tent_canvas": 0.58,
        "ds_tent_round":  0.58,
        "ds_tent_small":  0.58,
        "ds_market":      0.85,
        "ds_well":        0.85,
        "ds_campfire":    0.70,
        // Enceinte, palmeraie et bêtes : sur l'échelle du bâti.
        "ds_wall_h":      0.65,
        "ds_wall_v":      0.65,
        "ds_wall_cnr":    0.65,
        "ds_wall_end":    0.65,
        "ds_gate2":       0.65,
        "ds_palisade_gate": 0.65,
        "ds_palm_tall1":  0.65,
        "ds_palm_tall2":  0.65,
        "ds_palm_small":  0.65,
        "ds_camel_1":     0.65,
        "ds_camel_2":     0.65,
        "ds_oasis_flower": 0.55
    ]

    /// Échelle d'affichage d'un asset du désert (table, sinon densité).
    static func desertDisplayScale(for name: String) -> CGFloat {
        desertScales[name] ?? desertScale
    }

}
