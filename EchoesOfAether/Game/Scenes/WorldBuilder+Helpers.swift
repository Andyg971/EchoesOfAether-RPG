import SpriteKit

// Utilitaires : props pixel, ombres, couches, hachage déterministe.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Helpers

    func add(_ node: SKNode, to scene: SKScene) {
        worldNode.addChild(node)
        backdropNodes.append(node)
    }

    func availableTiles(_ preferred: [String], fallback: [String]) -> [String] {
    let available = preferred.filter { PixelArtSprites.exists($0) }
    return available.isEmpty ? fallback : available
    }

    func addTiledFloor(in scene: SKScene, tileNames: [String], fallbackColor: SKColor,
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

    /// Props plats/franchissables : fleurs, champignons, décorations murales.
    /// Tout le reste (arbres, statues, tonneaux, bancs…) bloque le passage.
    static let walkablePropPrefixes = [
    "me_flower", "me_mushrooms", "me_hanging", "me_apples",
    "me_big_sprout", "forest_mushroom", "mushroom"
    ]

    /// SUBSTITUTIONS D'UNIVERS — le décor sortait en grande partie du pack
    /// « Modern Exteriors » (préfixe `me_`) : le village de départ d'un RPG
    /// médiéval-fantasy alignait réverbères, bancs publics, boîtes aux lettres,
    /// barrières de chantier et stand de limonade.
    ///
    /// Les noms d'assets mentent en prime, et le code les croyait sur parole :
    /// `me_sign_1` est une barrière de travaux rouge et blanche, pas un panneau ;
    /// `village_lantern_1` est une borne à incendie, pas une lanterne.
    ///
    /// La substitution se fait ICI, au seul point où un décor est posé, plutôt
    /// qu'aux quarante points d'appel : un asset banni devient son équivalent
    /// médiéval, ou disparaît quand il n'en a pas. Ajouter une entrée suffit à
    /// purger toutes les zones d'un coup.
    ///
    /// `nil` = l'objet n'a pas d'équivalent, on ne le pose pas.
    static let modernSubstitutions: [String: String?] = [
    // Éclairage public : un village médiéval n'en a pas. Les lanternes
    // portées restent (`village_lantern_2` est une vraie lanterne rouge).
    "me_lamp_1": nil, "me_lamp_2": nil, "me_lamp_3": nil,
    "village_lantern_1": "village_lantern_2",       // borne incendie → lanterne
    // Mobilier urbain.
    "me_bench_1": "village_bench", "me_bench_2": "village_bench",
    "me_bench_3": "village_bench", "me_garden_bench": "village_bench",
    "me_mailbox_1": nil, "me_mailbox_2": nil,
    "me_birdhouse_big": nil, "me_birdhouse_blue": nil, "me_birdhouse_brown": nil,
    // « Panneaux » qui sont des barrières de chantier.
    "me_sign_1": nil, "me_sign_2": nil, "me_sign_3": nil,
    // Jardinières et suspensions de balcon → paniers et cageots.
    "me_vase_red": "me_basket", "me_vase_yellow": "me_basket",
    "me_vase_pink": "me_basket_2", "me_vase_sunflower": "village_crate_1",
    "me_hanging_flowers": nil, "me_hanging_pot": nil,
    // Commerce contemporain : `me_lemonade_stand` est un stand de limonade,
    // `interior_market` une devanture de supérette avec « MARKET » écrit
    // dessus — du texte anglais cuit dans une image, dans un jeu localisé.
    "me_lemonade_stand": "village_crate_2",
    "interior_market": "me_wood_storage",           // grenier à grain en bois
    // Bidons de plastique bleus et verts empilés le long des façades : ce
    // sont des jerricans. Un village stocke son eau et sa bière en fûts.
    "me_barrel_1": "village_barrel_1", "me_barrel_2": "village_barrel_2",
    "me_barrel_3": "village_barrel_1", "me_barrel_4": "village_barrel_2",
    // Bacs à fleurs de balcon → planches de potager.
    "me_flower_bush_1": "mv_garden_bed", "me_flower_bush_2": "mv_garden_bed",
    "me_flower_bush_3": "mv_garden_bed", "me_flower_bush_4": "mv_garden_bed",
    "me_flower_bush_5": "mv_garden_bed",
    // Carrés de pelouse cerclés d'aluminium : du mobilier de parc urbain.
    "me_landscape_grass": nil, "me_landscape_stone": nil,
    "me_landscape_water": nil
    ]

    /// Nom réellement posé pour un asset demandé — `nil` si l'univers le refuse.
    func clearBackdrop() {
        obstacles.removeAll()
        propRects.removeAll()
        worldWidth = 0               // seule la carte du monde scrolle en X
        villagePlanActive = false    // chaque zone replace Kael elle-même
        snapCameraNextFrame = true   // nouvelle zone : recadrage instantané
        backdropNodes.forEach { $0.removeFromParent() }
        backdropNodes.removeAll()
        atmosphereNode?.removeFromParent()
        atmosphereNode = nil
        // Le halo du héros n'existe que dans les zones noires (mines) ;
        // chaque zone le ré-attache explicitement si besoin.
        LightingEngine.removeHeroLight(from: kael)
        // La pluie est en espace écran : sans ce retrait central, elle
        // suivrait le joueur jusque dans les mines et les intérieurs.
        worldNode.scene?.childNode(withName: "weatherRain")?.removeFromParent()
    }

    /// Décide la météo à l'entrée d'une zone extérieure : `--weather-rain`
    /// force la pluie, sinon ~1 entrée sur 5. Pose l'emitter en espace
    /// écran (z 95, sous le HUD) et dit à l'appelant d'assombrir le grade.
    func rollWeatherRain(in scene: SKScene, chance: Int = 20) -> Bool {
        let raining = CommandLine.arguments.contains("--weather-rain")
            || Int.random(in: 0..<100) < chance
        guard raining else { return false }
        let rain = ParticleFactory.rain(in: scene.size)
        rain.name = "weatherRain"
        scene.addChild(rain)
        return true
    }

    func addAtmosphere(_ node: SKNode, to scene: SKScene) {
        atmosphereNode?.removeFromParent()
        atmosphereNode = node
        worldNode.addChild(node)
    }
}
