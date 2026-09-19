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
    static func substituted(_ name: String) -> String? {
    guard let mapped = modernSubstitutions[name] else { return name }
    return mapped
    }

    func addPixelProp(_ name: String, in scene: SKScene, at position: CGPoint,
                          scale: CGFloat, flipped: Bool = false) {
    guard let name = Self.substituted(name) else { return }
    // Anti-empilement : un décor dont le PIED tombe dans un décor déjà
    // posé n'est pas placé. C'est ce qui mettait des vasques debout sur les
    // bancs de la place — deux groupes réglés séparément, chacun correct de
    // son côté, superposés à l'arrivée.
    guard !isCluttered(position) else { return }
    guard let node = PixelArtSprites.still(name: name, scale: scale,
                                           anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
    node.position = position
    if flipped { node.xScale = -abs(node.xScale == 0 ? 1 : node.xScale) }
    node.zPosition = propLayer(for: position.y, in: scene.size.height)
    addGroundShadow(under: node, width: 34 * scale, height: 9 * scale)
    add(node, to: scene)
    if !Self.walkablePropPrefixes.contains(where: name.hasPrefix) {
        registerFootprint(of: node)
    }
    attachPropLight(for: name, on: node, in: scene)
    }

    /// Pose un décor ANIMÉ ancré aux pieds : canopée qui respire, villageois
    /// qui piétinent, aventuriers en faction. Deux réglages font tout :
    /// - `height` : hauteur visée À L'ÉCRAN, en points. Les planches importées
    ///   vont de 45 px (villageois) à 120 px (pin) ; à échelle commune, un
    ///   villageois dépasserait le toit de sa maison.
    /// - `phase` : frame de départ. Deux voisins qui démarrent sur la même
    ///   frame respirent à l'unisson — l'œil lit la boucle, pas la vie.
    @discardableResult
    func addAnimatedProp(_ name: String, frames: Int, in scene: SKScene,
                             at position: CGPoint, height: CGFloat,
                             phase: Int = 0,
                             timePerFrame: TimeInterval = 0.16,
                             flipped: Bool = false,
                             blocking: Bool = true) -> SKNode? {
    // Même règle anti-empilement que `addPixelProp` — mais seulement pour
    // le décor : un figurant (`blocking: false`) a le droit de se tenir
    // devant un banc ou sous un arbre, c'est même ce qu'on veut.
    guard !blocking || !isCluttered(position) else { return nil }
    guard let node = PixelArtSprites.animated(
        name: name, frames: frames,
        scale: scaleFor("\(name)_idle_1", height: height),
        timePerFrame: timePerFrame,
        anchor: CGPoint(x: 0.5, y: 0.0),
        startFrame: phase) else { return nil }
    node.position = position
    // Miroir sur les SPRITES, pas sur le node racine : la promenade
    // (`scheduleWander`) oriente les figurants en écrivant `xScale` sur ces
    // mêmes sprites. Un flip posé sur la racine se serait combiné au sien,
    // et le villageois aurait marché à reculons une fois sur deux.
    if flipped { node.forEachDescendantSprite { $0.xScale = -abs($0.xScale) } }
    node.zPosition = propLayer(for: position.y, in: scene.size.height)
    addGroundShadow(under: node, width: height * 0.40, height: height * 0.11)
    add(node, to: scene)
    if blocking {
        registerFootprint(of: node, widthRatio: 0.58, depthRatio: 0.4, maxDepth: 22)
    }
    return node
    }

    /// Les sources lumineuses naturelles s'éclairent toutes seules :
    /// lanterne/torche/feu → flamme vacillante, champignon → lueur froide,
    /// cristal → éclat violet. Lumière posée en espace monde (backdrop),
    /// nettoyée au changement de zone comme le reste.
    func attachPropLight(for name: String, on node: SKNode, in scene: SKScene) {
    let light: SKSpriteNode
    if name.contains("lantern") || name.contains("torch") || name.contains("campfire")
        || name.contains("lamp") || (name.contains("candle") && !name.contains("_off")) {
        light = LightingEngine.pointLight(radius: 48,
                                          color: LightingEngine.LightColor.flame,
                                          flicker: true)
    } else if name.contains("shroom") || name.contains("mushroom") {
        light = LightingEngine.pointLight(radius: 28,
                                          color: LightingEngine.LightColor.fungal)
        light.alpha = 0.35
    } else if name.contains("crystal") {
        light = LightingEngine.pointLight(radius: 36,
                                          color: LightingEngine.LightColor.crystal)
        light.alpha = 0.42
    } else {
        return
    }
    let frame = node.calculateAccumulatedFrame()
    light.position = CGPoint(x: node.position.x,
                             y: node.position.y + frame.height * 0.60)
    add(light, to: scene)
    }

    func addDirtPath(in scene: SKScene, from a: CGPoint, to b: CGPoint,
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
    /// `tint` : le village entier est bâti sur un seul corps de ferme
    /// (`mv_chalet`). Ce qui distingue deux maisons d'un hameau, ce sont ses
    /// bois et ses enduits, pas huit architectures différentes — la teinte
    /// fait ce travail, le miroir achève de casser la répétition.
    func addVillageBuilding(asset: String, scale: CGFloat,
                                     fallbackW: CGFloat, fallbackH: CGFloat,
                                     wallColor: SKColor, roofColor: SKColor,
                                     label: String?,
                                     at position: CGPoint, in scene: SKScene,
                                     tint: SKColor? = nil, flipped: Bool = false) {
        let node: SKNode
        if let sprite = PixelArtSprites.still(name: asset, scale: scale,
                                               anchor: CGPoint(x: 0.5, y: 0.0)) {
            node = sprite
            if let tint {
                sprite.forEachDescendantSprite { s in
                    s.color = tint
                    s.colorBlendFactor = 0.30
                }
            }
            if flipped { sprite.xScale = -abs(sprite.xScale == 0 ? 1 : sprite.xScale) }
            addGroundShadow(to: node, width: 160 * scale, height: 20 * scale, y: 4 * scale)
            // Enseigne au-dessus du sprite (offset adapté au scale)
            if let label {
                let sign = SKLabelNode(fontNamed: PixelUI.uiFont)
                sign.text = label
                sign.fontSize = max(11, 18 * scale)
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
        // Bâtiment ENTIÈREMENT infranchissable. Les acteurs (z 20-40)
        // sont toujours dessinés au-dessus des props (z -2/-8) : si on
        // laissait passer « derrière », Kael apparaissait SUR le toit.
        registerFootprint(of: node, widthRatio: 0.86,
                          depthRatio: 0.96, maxDepth: 400)
    }

    func addGroundShadow(to node: SKNode, width: CGFloat, height: CGFloat, y: CGFloat) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        shadow.fillColor = SKColor(white: 0.0, alpha: 0.24)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: y)
        shadow.zPosition = -2
        node.addChild(shadow)
    }

    func addDirtPatch(at center: CGPoint, size: CGSize, in scene: SKScene) {
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
