import SpriteKit

// Désert d'Ossara — première moitié : terrain et décor.
// Extrait de WorldBuilder.swift (découpage du monolithe).
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

        // ── Terrains : terre craquelée au sud, roche vers le canyon nord ──
        //
        // Par l'autotiler, comme les chemins du village et de la forêt. Ils
        // étaient posés en plaques rectangulaires de tuiles pleines : sans
        // transition, la terre craquelée s'arrêtait net sur le sable et se
        // lisait comme un bloc en escalier. Les tuiles `ds_edge_*` sont
        // générées (sable + bordure dentelée) faute d'en trouver dans le pack.
        let cell: CGFloat = 96 * WorldBuilder.desertScale
        var cracked = VillageTileMap(width: w, height: h, tile: cell)
        cracked.stampEllipse(center: CGPoint(x: w * 0.22, y: h * 0.30),
                             radiusX: w * 0.26, radiusY: h * 0.075)
        cracked.stampEllipse(center: CGPoint(x: w * 0.74, y: h * 0.33),
                             radiusX: w * 0.22, radiusY: h * 0.065)
        cracked.stampEllipse(center: CGPoint(x: w * 0.14, y: h * 0.88),
                             radiusX: w * 0.20, radiusY: h * 0.06)
        // La place de la cité : de la terre battue sous le souk et le puits.
        // Trois ellipses qui se chevauchent, pas un rectangle mou — le sol
        // suit la vie (camp à l'ouest, place au centre, cour des maisons).
        cracked.stampEllipse(center: CGPoint(x: w * 0.35, y: h * 0.455),
                             radiusX: w * 0.20, radiusY: h * 0.042)
        cracked.stampEllipse(center: CGPoint(x: w * 0.55, y: h * 0.485),
                             radiusX: w * 0.24, radiusY: h * 0.048)
        cracked.stampEllipse(center: CGPoint(x: w * 0.68, y: h * 0.545),
                             radiusX: w * 0.16, radiusY: h * 0.038)
        // L'allée : de la porte sud à la porte nord, à travers la place.
        cracked.stamp(rect: CGRect(x: w * 0.46, y: h * 0.372, width: w * 0.08,
                                   height: h * 0.265))
        renderTileMap(cracked, fullTile: "ds_cracked", edgePrefix: "ds_edge_",
                      in: scene, z: -9.6)

        var rock = VillageTileMap(width: w, height: h, tile: cell)
        // Îlots, pas une dalle : les deux plaques du canyon couvraient un
        // demi-écran chacune — en masse, la tuile rocheuse se lit comme un
        // mur. Réduites pour laisser le sable respirer entre les affleure-
        // ments.
        rock.stampEllipse(center: CGPoint(x: w * 0.78, y: h * 0.73),
                          radiusX: w * 0.14, radiusY: h * 0.050)
        rock.stampEllipse(center: CGPoint(x: w * 0.26, y: h * 0.70),
                          radiusX: w * 0.12, radiusY: h * 0.042)
        // Parois du canyon : des BANDES de plateau continues sur les deux
        // flancs, le fond et les épaules de l'entrée — pas des mesas
        // flottantes posées sur le sable (Andy : « la roche, tu l'as mal
        // faite »). Le bord déchiré vient de l'autotiler ; des bosses
        // seedées le font onduler vers l'intérieur.
        var rockSeed: UInt64 = 0x0C11_FF5E
        func rockNext() -> CGFloat {
            rockSeed = rockSeed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(rockSeed >> 40) / CGFloat(1 << 24)
        }
        rock.stamp(rect: CGRect(x: 0, y: 0, width: w * 0.062, height: h))
        rock.stamp(rect: CGRect(x: w * 0.938, y: 0, width: w * 0.062, height: h))
        rock.stamp(rect: CGRect(x: 0, y: h * 0.955, width: w, height: h * 0.045))
        rock.stamp(rect: CGRect(x: 0, y: 0, width: w * 0.32, height: h * 0.014))
        rock.stamp(rect: CGRect(x: w * 0.68, y: 0, width: w * 0.32, height: h * 0.014))
        for _ in 0..<8 {
            rock.stampEllipse(center: CGPoint(x: w * 0.062, y: h * (0.06 + rockNext() * 0.85)),
                              radiusX: w * (0.018 + rockNext() * 0.030),
                              radiusY: h * (0.015 + rockNext() * 0.028))
            rock.stampEllipse(center: CGPoint(x: w * 0.938, y: h * (0.06 + rockNext() * 0.85)),
                              radiusX: w * (0.018 + rockNext() * 0.030),
                              radiusY: h * (0.015 + rockNext() * 0.028))
        }
        for _ in 0..<4 {
            rock.stampEllipse(center: CGPoint(x: w * (0.10 + rockNext() * 0.80), y: h * 0.955),
                              radiusX: w * (0.03 + rockNext() * 0.04),
                              radiusY: h * (0.012 + rockNext() * 0.016))
        }
        // Dessus de paroi : la terre craquelée SOMBRE du pack (celle des
        // murs du canyon dans la carte de référence), pas le gravier
        // ds_rock — en nappe, il se lisait comme une moquette grise.
        renderTileMap(rock, fullTile: "ds_cracked_dark", edgePrefix: "ds_rockedge_",
                      in: scene, z: -9.5)
        // La HAUTEUR : chaque bord sud de paroi reçoit sa face de pierres
        // empilées — c'est elle qui fait lire la roche comme un relief.
        addCliffFaces(for: rock, cell: cell, in: scene)

        // ── Ceinture de falaises : Ossara est un canyon, pas une nappe ──
        addDesertCliffs(in: scene, w: w, h: h)

        // ── Sud : les dunes d'entrée, semées de cactus et d'ossements ──
        // Densité alignée sur la forêt (~11 props par écran) : le sable plat
        // pardonne moins le vide que l'herbe.
        for (asset, x, y) in [("ds_cactus_tall", 0.14, 0.16),
                              ("ds_cactus_med", 0.86, 0.12),
                              ("ds_bush_dead", 0.30, 0.10),
                              ("ds_cactus_barrel", 0.70, 0.20),
                              ("ds_tumbleweed", 0.585, 0.245),
                              ("ds_skull_cow", 0.135, 0.315),
                              ("ds_bush_dead2", 0.62, 0.28),
                              ("ds_cactus_tall2", 0.90, 0.26),
                              ("ds_cactus_small", 0.52, 0.13),
                              ("ds_rock_pile", 0.08, 0.205),
                              ("ds_bush_dead3", 0.78, 0.155),
                              ("ds_cactus_flower", 0.36, 0.185),
                              ("ds_rock_pile", 0.60, 0.095),
                              ("ds_tumbleweed2", 0.20, 0.33),
                              ("ds_cactus_med2", 0.80, 0.315),
                              ("ds_bones", 0.60, 0.345)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }

        // ── Cité des caravanes (centre) : le cœur de la zone ──
        addDesertTown(in: scene, w: w, h: h)

        // ── Nord : le canyon, ses éboulis et ses caravanes perdues ──
        for (asset, x, y) in [("ds_boulder", 0.14, 0.62),
                              ("ds_rock_big", 0.88, 0.66),
                              ("ds_boulder2", 0.34, 0.74),
                              ("ds_rock_spire", 0.70, 0.78),
                              ("ds_bones", 0.24, 0.70),
                              ("ds_skull_cow2", 0.56, 0.72),
                              ("ds_bone", 0.44, 0.80),
                              ("ds_ruin_column", 0.78, 0.86),
                              ("ds_ruin_stone", 0.30, 0.88),
                              ("ds_cactus_tall3", 0.10, 0.78),
                              ("ds_agave", 0.64, 0.64),
                              ("ds_tumbleweed2", 0.50, 0.84),
                              ("ds_skull", 0.16, 0.84),
                              ("ds_rock_pile", 0.60, 0.685),
                              ("ds_bush_dead", 0.40, 0.66),
                              ("ds_cactus_med2", 0.90, 0.80)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }

        // ── Éboulis des flancs : le canyon a des PIEDS de paroi ──
        // Les parois tombaient à pic sur le sable nu. Une frange d'aiguilles
        // et de blocs les raccorde au sol, des deux côtés, comme le massif de
        // Cendreval sur la carte du monde. Toujours via `addDesertProp` :
        // même densité de pixels que le reste de la zone.
        for (asset, x, y) in [("ds_rock_spire", 0.06, 0.58),
                              ("ds_boulder",    0.11, 0.545),
                              ("ds_rock_spire", 0.05, 0.70),
                              ("ds_boulder2",   0.09, 0.755),
                              ("ds_rock_big",   0.07, 0.86),
                              ("ds_rock_pile",  0.13, 0.905),
                              ("ds_rock_spire", 0.95, 0.575),
                              ("ds_boulder2",   0.91, 0.615),
                              ("ds_rock_big",   0.96, 0.71),
                              ("ds_rock_spire", 0.93, 0.815),
                              ("ds_boulder",    0.89, 0.875),
                              ("ds_rock_pile",  0.955, 0.925),
                              // Deux éboulis isolés au milieu du défilé.
                              ("ds_boulder2",   0.36, 0.925),
                              ("ds_rock_pile",  0.68, 0.905)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }

        // ── L'allée pavée : de l'entrée à la porte sud, crochet compris ──
        addDesertPathTiles(in: scene, w: w, h: h)

        // ── Oasis : la halte sur la route, palmeraie et campement autour du
        // bassin. Palmiers et fleurs sont posés PAR `addOasis` — ils étaient
        // semés ici à la main, trois de-ci de-là, et l'oasis se lisait comme
        // une flaque avec des plantes autour au lieu d'une halte.
        addOasis(in: scene, at: DesertPOI.oasis.scaled(w: w, h: h), w: w, h: h)
        // Le nord garde une trace de vert : un palmier esseulé au canyon.
        addDesertProp("ds_palm_tall2", in: scene, at: CGPoint(x: w * 0.905, y: h * 0.900))
        addDesertProp("ds_flowers_red", in: scene, at: CGPoint(x: w * 0.885, y: h * 0.885))
        // Et un petit près de la cité, côté est.
        addDesertProp("ds_palm_small", in: scene, at: CGPoint(x: w * 0.68, y: h * 0.330))

        // ── LES TROIS TERRAINS DE COMBAT ──
        // Ils sont calés sur les points d'apparition des rôdeurs
        // (`GameManager.spawnDesertRoamers`) : dunes du sud, gorge du canyon,
        // et l'arène du boss tout au nord. Les monstres surgissaient jusqu'ici
        // sur du sable nu, indiscernable du reste de la traversée.
        addDesertBattleground(in: scene, at: CGPoint(x: w * 0.62, y: h * 0.25),
                              radiusX: w * 0.15, radiusY: h * 0.048,
                              ring: ["ds_rock_pile", "ds_boulder2", "ds_bush_dead",
                                     "ds_boulder", "ds_cactus_barrel"],
                              litter: ["ds_skull_cow", "ds_bones", "ds_bone",
                                       "ds_tumbleweed"],
                              cell: cell)
        addDesertBattleground(in: scene, at: CGPoint(x: w * 0.60, y: h * 0.66),
                              radiusX: w * 0.16, radiusY: h * 0.050,
                              ring: ["ds_boulder", "ds_rock_big", "ds_boulder2",
                                     "ds_rock_spire", "ds_rock_pile"],
                              litter: ["ds_bones", "ds_skull", "ds_bone",
                                       "ds_skull_cow2", "ds_carpet_rolls"],
                              cell: cell)
        // L'arène du boss : la plus large, cerclée de colonnes en ruine — un
        // ancien caravansérail dont il ne reste que le cercle.
        addDesertBattleground(in: scene, at: CGPoint(x: w * 0.40, y: h * 0.86),
                              radiusX: w * 0.20, radiusY: h * 0.058,
                              ring: ["ds_ruin_column", "ds_rock_spire",
                                     "ds_ruin_stone", "ds_boulder", "ds_ruin_column"],
                              litter: ["ds_skull_cow", "ds_bones", "ds_campfire",
                                       "ds_bone", "ds_skull", "ds_sacks"],
                              cell: cell)

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

    /// Emprise au sol d'un décor : sur quelle surface il arrête Kael.
    struct Footprint {
        let widthRatio: CGFloat
        let depthRatio: CGFloat
        let maxDepth: CGFloat
    }

    /// Ce qui arrête Kael à Ossara, décidé d'après l'ASSET.
    ///
    /// La solidité se décidait au point d'appel : chaque pose passait un
    /// `solid:` calculé sur un préfixe de nom. Trois s'étaient trompées — la
    /// porte des remparts se traversait de part en part, les palissades aussi,
    /// et un cactus du nord passait au travers parce que son groupe testait
    /// « ds_boulder ». Une table : un seul endroit à tenir quand un pack
    /// arrive, et l'oubli devient visible au lieu d'être silencieux.
    ///
    /// Absent de la table = on marche dessus (ossements, empreintes, fleurs,
    /// tapis, échelle couchée, broussailles sèches). Tout ce qui a un volume
    /// y figure.
    static let desertFootprints: [String: Footprint] = [
        // Bâti : l'empreinte couvre la façade, pas le toit — on passe derrière.
        "ds_house_red":     Footprint(widthRatio: 0.92, depthRatio: 0.34, maxDepth: 48),
        "ds_house_sand":    Footprint(widthRatio: 0.92, depthRatio: 0.34, maxDepth: 48),
        "ds_house_large":   Footprint(widthRatio: 0.92, depthRatio: 0.34, maxDepth: 48),
        // Toile tendue : on la contourne.
        "ds_tent_big":      Footprint(widthRatio: 0.62, depthRatio: 0.45, maxDepth: 30),
        "ds_tent_canvas":   Footprint(widthRatio: 0.62, depthRatio: 0.45, maxDepth: 30),
        "ds_tent_round":    Footprint(widthRatio: 0.62, depthRatio: 0.45, maxDepth: 30),
        "ds_tent_small":    Footprint(widthRatio: 0.62, depthRatio: 0.45, maxDepth: 30),
        // Épines.
        "ds_cactus_tall":   Footprint(widthRatio: 0.42, depthRatio: 0.35, maxDepth: 20),
        "ds_cactus_tall2":  Footprint(widthRatio: 0.42, depthRatio: 0.35, maxDepth: 20),
        "ds_cactus_tall3":  Footprint(widthRatio: 0.42, depthRatio: 0.35, maxDepth: 20),
        "ds_cactus_med":    Footprint(widthRatio: 0.42, depthRatio: 0.35, maxDepth: 20),
        "ds_cactus_med2":   Footprint(widthRatio: 0.42, depthRatio: 0.35, maxDepth: 20),
        "ds_cactus_small":  Footprint(widthRatio: 0.40, depthRatio: 0.35, maxDepth: 16),
        "ds_cactus_barrel": Footprint(widthRatio: 0.55, depthRatio: 0.45, maxDepth: 16),
        "ds_cactus_barrel2": Footprint(widthRatio: 0.55, depthRatio: 0.45, maxDepth: 16),
        "ds_cactus_flower": Footprint(widthRatio: 0.55, depthRatio: 0.45, maxDepth: 16),
        "ds_agave":         Footprint(widthRatio: 0.50, depthRatio: 0.40, maxDepth: 16),
        // Pierre.
        "ds_boulder":       Footprint(widthRatio: 0.72, depthRatio: 0.45, maxDepth: 26),
        "ds_boulder2":      Footprint(widthRatio: 0.72, depthRatio: 0.45, maxDepth: 26),
        "ds_rock_big":      Footprint(widthRatio: 0.72, depthRatio: 0.45, maxDepth: 30),
        "ds_rock_pile":     Footprint(widthRatio: 0.72, depthRatio: 0.45, maxDepth: 22),
        "ds_rock_spire":    Footprint(widthRatio: 0.60, depthRatio: 0.45, maxDepth: 26),
        "ds_ruin_column":   Footprint(widthRatio: 0.60, depthRatio: 0.45, maxDepth: 22),
        "ds_ruin_stone":    Footprint(widthRatio: 0.70, depthRatio: 0.45, maxDepth: 22),
        // Mobilier de la place.
        "ds_well":          Footprint(widthRatio: 0.70, depthRatio: 0.50, maxDepth: 22),
        "ds_market":        Footprint(widthRatio: 0.85, depthRatio: 0.40, maxDepth: 24),
        "ds_campfire":      Footprint(widthRatio: 0.50, depthRatio: 0.50, maxDepth: 16),
        "ds_fence":         Footprint(widthRatio: 0.95, depthRatio: 0.28, maxDepth: 14),
        "ds_pot":           Footprint(widthRatio: 0.55, depthRatio: 0.50, maxDepth: 12),
        "ds_pot2":          Footprint(widthRatio: 0.55, depthRatio: 0.50, maxDepth: 12),
        // Palmeraie : seul le tronc arrête Kael, on passe sous les palmes.
        "ds_palm_tall1":    Footprint(widthRatio: 0.30, depthRatio: 0.30, maxDepth: 12),
        "ds_palm_tall2":    Footprint(widthRatio: 0.30, depthRatio: 0.30, maxDepth: 12),
        "ds_palm_small":    Footprint(widthRatio: 0.35, depthRatio: 0.35, maxDepth: 12),
        // Bêtes du camp : on les contourne.
        "ds_camel_1":       Footprint(widthRatio: 0.70, depthRatio: 0.45, maxDepth: 14),
        "ds_camel_2":       Footprint(widthRatio: 0.70, depthRatio: 0.45, maxDepth: 14),
        // Les falaises et l'enceinte ont des obstacles explicites
        // (bandes continues) — pas d'entrée ici.
    ]

    /// Prop du désert : posé aux pieds, ombre au sol, profondeur selon y.
    /// Son emprise vient de `desertFootprints`, pas de l'appelant.
    @discardableResult
    func addDesertProp(_ name: String, in scene: SKScene, at pos: CGPoint,
                               scale: CGFloat? = nil, flipped: Bool = false) -> SKNode? {
        let scale = scale ?? Self.desertDisplayScale(for: name)
        guard let node = PixelArtSprites.still(name: name, scale: scale,
                                               anchor: CGPoint(x: 0.5, y: 0.0)) else { return nil }
        if flipped { node.xScale = -abs(node.xScale == 0 ? 1 : node.xScale) }
        node.position = pos
        node.zPosition = depthLayer(for: pos.y, sceneHeight: scene.size.height)
        addGroundShadow(under: node, width: 26 * scale, height: 8 * scale)
        add(node, to: scene)
        if let f = Self.desertFootprints[name] {
            registerFootprint(of: node, widthRatio: f.widthRatio,
                              depthRatio: f.depthRatio, maxDepth: f.maxDepth)
        }
        return node
    }

    /// La cité des caravanes : maisons d'adobe, tentes, souk et puits.
    ///
    /// C'est le contenu qui manquait à Ossara. La zone n'avait qu'un coffre,
    /// une oasis et trois rôdeurs — le scénario parle pourtant d'une route de
    /// caravanes, et le joueur ne croisait jamais personne qui l'ait empruntée.
    func addDesertTown(in scene: SKScene, w: CGFloat, h: CGFloat) {
        // ── L'enceinte : la cité est FERMÉE — courtines d'adobe sur les
        // quatre côtés, porte au sud (l'arrivée) et porte au nord (vers le
        // canyon et l'oasis). Avant, une arche flottait seule dans le sable
        // avec quatre bouts de palissade — ça ne protégeait de rien.
        addDesertRamparts(in: scene, w: w, h: h)

        // ── LA GRAND-RUE, PAVÉE : de la porte sud à la porte nord, élargie en
        // place devant le puits. C'est elle qui fait la CITÉ.
        //
        // Les maisons dessinaient jusqu'ici un croissant lâche autour d'un
        // grand vide de terre craquelée : cinq bâtisses posées sur un arc,
        // aucune rue, aucun alignement, et le joueur traversait un terrain
        // vague meublé. Une ville se lit à ses axes — on pave l'axe, on range
        // les façades dessus, et le vide devient une place.
        let street = 0.50, southY = 0.375, northY = 0.635
        let cell: CGFloat = 96 * WorldBuilder.desertScale
        var paving = VillageTileMap(width: w, height: h, tile: cell)
        paving.stamp(rect: CGRect(x: w * (street - 0.052), y: h * (southY + 0.004),
                                  width: w * 0.104, height: h * (northY - southY - 0.008)))
        // La place : un renflement de la rue, pas une pièce à part.
        paving.stampEllipse(center: CGPoint(x: w * street, y: h * 0.468),
                            radiusX: w * 0.155, radiusY: h * 0.038)
        // Rue transversale, devant la seconde rangée.
        paving.stamp(rect: CGRect(x: w * 0.20, y: h * 0.552,
                                  width: w * 0.60, height: h * 0.018))
        renderTileMap(paving, fullTile: "ds_rock", edgePrefix: nil,
                      in: scene, z: -9.52)

        // ── Les façades, en RANGÉES le long des axes. Toutes tournées au sud
        // (le pack les dessine ainsi) : les rangées se lisent donc depuis la
        // rue qu'elles bordent, et la grande bâtisse ferme la perspective au
        // fond de la grand-rue.
        for (asset, x, y) in [("ds_house_large", 0.50, 0.618),   // fond de rue
                              // Rangée du fond, de part et d'autre.
                              ("ds_house_sand", 0.265, 0.590),
                              ("ds_house_red",  0.375, 0.590),
                              ("ds_house_red",  0.625, 0.590),
                              ("ds_house_sand", 0.735, 0.590),
                              // Rangée de la rue transversale.
                              ("ds_house_red",  0.185, 0.505),
                              ("ds_house_sand", 0.305, 0.505),
                              ("ds_house_sand", 0.695, 0.505),
                              ("ds_house_red",  0.815, 0.505)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }

        // ── Le caravansérail, à l'ouest de la place : c'est là qu'on dételle
        // en arrivant par la porte sud. Tentes serrées, enclos, bêtes.
        for (asset, x, y) in [("ds_tent_canvas", 0.235, 0.432),
                              ("ds_tent_round", 0.155, 0.408),
                              ("ds_tent_small", 0.305, 0.412)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }
        addDesertProp("ds_fence", in: scene, at: CGPoint(x: w * 0.185, y: h * 0.452))
        addDesertProp("ds_fence", in: scene, at: CGPoint(x: w * 0.245, y: h * 0.452))
        addDesertProp("ds_camel_1", in: scene, at: CGPoint(x: w * 0.215, y: h * 0.462))
        addDesertProp("ds_camel_2", in: scene, at: CGPoint(x: w * 0.285, y: h * 0.455),
                      flipped: true)

        // ── Le souk, à l'est de la place : l'étal, les tapis, les sacs.
        for (asset, x, y) in [("ds_tent_big", 0.755, 0.428),
                              ("ds_tent_small", 0.845, 0.412),
                              ("ds_carpet_rolls", 0.665, 0.440),
                              ("ds_sacks", 0.700, 0.425),
                              ("ds_rug", 0.630, 0.428),
                              ("ds_scroll", 0.598, 0.443)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }

        // ── La place : puits au centre, étal et feu de part et d'autre.
        addDesertProp("ds_market", in: scene, at: CGPoint(x: w * 0.395, y: h * 0.470))
        addDesertProp("ds_well", in: scene, at: DesertPOI.town.scaled(w: w, h: h))
        addDesertProp("ds_campfire", in: scene, at: CGPoint(x: w * 0.605, y: h * 0.472))

        // ── Palmiers intra-muros : la cité vit sur sa nappe d'eau. Alignés
        // aux angles des blocs, comme des arbres de rue.
        for (x, y) in [(0.125, 0.500), (0.875, 0.500),
                       (0.125, 0.585), (0.875, 0.585)] {
            addDesertProp("ds_palm_tall1", in: scene, at: CGPoint(x: w * x, y: h * y))
        }
        addDesertProp("ds_palm_small", in: scene, at: CGPoint(x: w * 0.435, y: h * 0.612))
        addDesertProp("ds_palm_small", in: scene, at: CGPoint(x: w * 0.565, y: h * 0.612))

        // ── Le petit bazar du quotidien : jarres aux portes, échelle contre
        // un mur, verdure au pied des façades. Ce qui fait qu'on y habite.
        for (asset, x, y) in [("ds_pot", 0.335, 0.578), ("ds_pot2", 0.665, 0.578),
                              ("ds_pot", 0.345, 0.494), ("ds_pot2", 0.655, 0.494),
                              ("ds_ladder", 0.225, 0.578),
                              ("ds_cactus_barrel2", 0.865, 0.545),
                              ("ds_grass_dry", 0.155, 0.545),
                              ("ds_grass_dry", 0.845, 0.545),
                              ("ds_oasis_flower", 0.415, 0.578),
                              ("ds_oasis_flower", 0.585, 0.578),
                              ("ds_flowers", 0.455, 0.500),
                              ("ds_agave", 0.545, 0.500),
                              ("ds_skull_cow2", 0.355, 0.408)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }

        // ── Les habitants : trois silhouettes terrées derrière les remparts.
        // Ils ne vagabondent pas comme au village — on ne flâne pas quand
        // des goules rôdent aux portes. Le dialogue est dans
        // `GameManager.tryDesertInteraction`, aux mêmes repères.
        addDesertVillager("npc_villager", in: scene,
                          at: DesertPOI.npcCaravanier.scaled(w: w, h: h))
        addDesertVillager("npc_extra", in: scene,
                          at: DesertPOI.npcMerchant.scaled(w: w, h: h))
        addDesertVillager("npc_child", in: scene,
                          at: DesertPOI.npcChild.scaled(w: w, h: h))
    }

    /// Figurant de la cité : animation d'idle, pas d'errance (ils ont peur).
}
