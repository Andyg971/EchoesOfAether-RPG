import SpriteKit

// Village Solis : maisons, place, figurants.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
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
    func buildVillage(in scene: SKScene) {
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
        // L'eau ne se marche pas.
        registerObstacle(CGRect(x: w * 0.085 - w * 0.052, y: h * 0.46 - h * 0.024,
                                width: w * 0.104, height: h * 0.048))
        // Eau vivante : scintillements + nappe qui respire
        add(LightingEngine.waterShimmer(center: CGPoint(x: w * 0.085, y: h * 0.46),
                                        radiusX: w * 0.058, radiusY: h * 0.027),
            to: scene)

        decorateVillage(in: scene)

        // ═══════════ MAISONS (échelle perso : porte ≈ taille de Kael) ═══════════
        buildNorthGate(at: CGPoint(x: w * 0.50, y: h * 0.96), width: 90, in: scene)

        // ── LE BÂTI ──────────────────────────────────────────────────────
        //
        // Les huit maisons sortaient du pack contemporain, et leurs NOMS
        // mentaient : `village_house_armory` est un pavillon de banlieue avec
        // porte de garage, `village_house_inn` une maison à terrasse bois et
        // climatiseur, `village_house_country` un chalet alpin à fenêtres PVC.
        // Le village de départ d'un RPG médiéval comptait donc un garage, une
        // villa de verre, une maison japonaise et un immeuble haussmannien.
        //
        // `mv_chalet` est le seul vrai corps de ferme en bois du catalogue :
        // il porte le village entier, décliné en TEINTES — un hameau se
        // distingue par ses bois et ses enduits, pas par huit architectures.
        // Deux exceptions qui font les repères : le manoir gothique du chef et
        // la chapelle.
        //
        // Les positions ne bougent PAS : `houseDoorPosition` cale les entrées
        // d'intérieur dessus.
        let plaster = SKColor(red: 0.92, green: 0.86, blue: 0.72, alpha: 1)
        let oldWood = SKColor(red: 0.56, green: 0.38, blue: 0.24, alpha: 1)
        let mossRoof = SKColor(red: 0.52, green: 0.58, blue: 0.44, alpha: 1)
        let ochre = SKColor(red: 0.84, green: 0.64, blue: 0.38, alpha: 1)

        // Résidentiel sud — la maison de Kael en premier plan
        addVillageBuilding(asset: "mv_chalet", scale: 0.44,
                            fallbackW: 62, fallbackH: 50,
                            wallColor: SKColor(red: 0.18, green: 0.16, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.35, green: 0.28, blue: 0.18, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.32, y: h * 0.075), in: scene,
                            tint: oldWood)
        addVillageBuilding(asset: "mv_chalet", scale: 0.40,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: Palette.wood,
                            roofColor: Palette.woodGold,
                            label: nil, at: CGPoint(x: w * 0.14, y: h * 0.16), in: scene,
                            tint: plaster, flipped: true)
        addVillageBuilding(asset: "mv_chalet", scale: 0.42,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1),
                            roofColor: SKColor(red: 0.30, green: 0.30, blue: 0.40, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.80, y: h * 0.16), in: scene,
                            tint: ochre)

        // Commerces — portes alignées sur houseDoorPosition (NE PAS déplacer)
        addVillageBuilding(asset: "mv_chalet", scale: 0.42,
                            fallbackW: 62, fallbackH: 50,
                            wallColor: SKColor(red: 0.14, green: 0.22, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.22, green: 0.40, blue: 0.22, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.22, y: h * 0.58), in: scene,
                            tint: mossRoof)          // l'herboriste, sous la mousse
        addVillageBuilding(asset: "mv_chalet", scale: 0.50,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: Palette.wood,
                            roofColor: Palette.woodGold,
                            label: nil, at: CGPoint(x: w * 0.50, y: h * 0.63), in: scene,
                            tint: SKColor(red: 0.50, green: 0.44, blue: 0.42, alpha: 1))
        addVillageBuilding(asset: "mv_chalet", scale: 0.52,
                            fallbackW: 88, fallbackH: 62,
                            wallColor: SKColor(red: 0.20, green: 0.14, blue: 0.10, alpha: 1),
                            roofColor: SKColor(red: 0.45, green: 0.25, blue: 0.12, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.78, y: h * 0.58), in: scene,
                            tint: ochre, flipped: true)   // l'auberge, la plus grande

        // Quartier haut — le manoir du chef et la chapelle ferment le village
        addVillageBuilding(asset: "village_house_haunted", scale: 0.19,
                            fallbackW: 70, fallbackH: 55,
                            wallColor: SKColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.30, green: 0.50, blue: 0.35, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.17, y: h * 0.78), in: scene)
        addVillageBuilding(asset: "gy_chapel", scale: 0.44,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: Palette.wood,
                            roofColor: Palette.woodGold,
                            label: nil, at: CGPoint(x: w * 0.82, y: h * 0.78), in: scene)

        // Crystal save proche auberge (UX : safe spot évident)
        addSaveCrystal(at: CGPoint(x: w * 0.88, y: h * 0.52), in: scene)

        // Village vivant : fumées de cheminée sur les maisons habitées
        for (x, y, dy) in [(0.78, 0.58, 84.0), (0.50, 0.63, 82.0),
                           (0.22, 0.58, 74.0), (0.17, 0.78, 64.0)] {
            let smoke = ParticleFactory.chimneySmoke()
            smoke.position = CGPoint(x: w * CGFloat(x) + 14, y: h * CGFloat(y) + CGFloat(dy))
            add(smoke, to: scene)
        }

        // Village vivant : les PNJ « ambiance » respirent, jettent des
        // coups d'œil et font quelques pas. On épargne Lyra (scripts de
        // veille), Dorin et Garen (sentinelles + zones de tap sensibles).
        AmbientLife.enliven(bram)
        AmbientLife.enliven(mara)
        AmbientLife.enliven(sage)
        AmbientLife.enliven(villager)
        AmbientLife.enliven(child, wanderRadius: 22)   // l'enfant gambade

        // Poussière ambiante + papillons + oiseaux qui traversent le ciel
        let ambiance = SKNode()
        ambiance.addChild(ParticleFactory.ambientDust(in: CGSize(width: w, height: h)))
        ambiance.addChild(ParticleFactory.butterflies(in: CGSize(width: w, height: h)))
        ambiance.addChild(AmbientLife.birds(in: CGSize(width: w, height: h)))
        let raining = rollWeatherRain(in: scene)
        if !raining {   // ciel dégagé : les nuages projettent leur ombre
            ambiance.addChild(LightingEngine.cloudShadows(in: CGSize(width: w, height: h)))
        }
        addAtmosphere(ambiance, to: scene)
        setZoneVignette(in: scene, alpha: 0)
        if raining {
            LightingEngine.applyGrade(.rainy, in: scene)
        } else {
            LightingEngine.applyGrade(.villageDay, in: scene)
            LightingEngine.startDayCycle(in: scene, day: .villageDay)
        }
        AudioEngine.shared.setAmbience(.village)
        debugDrawObstacles(in: scene)
    }

    /// Portes desservies par un sentier branché sur l'allée centrale
    /// (fractions de w/h — alignées sur les pieds de maisons).
    static let villageBranches: [(x: CGFloat, y: CGFloat)] = [
        (0.32, 0.075),   // maison de Kael
        (0.14, 0.16),    // maison country sud
        (0.80, 0.16),    // maison moderne
        (0.22, 0.58),    // herboriste
        (0.78, 0.58),    // auberge
        (0.88, 0.52),    // crystal de sauvegarde
        (0.17, 0.78),    // villa victorienne
        (0.82, 0.78)     // maison haute est
    ]
}
