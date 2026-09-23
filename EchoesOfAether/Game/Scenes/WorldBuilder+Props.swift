import SpriteKit

// WorldBuilder — pose de props pixel : statiques, animés, lumière attachée, bâtiments, ombres.
extension WorldBuilder {
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
        // Arbres : largeur lue dans le feuillage (cf. foliageFootprintRatio).
        let isTree = name.hasPrefix("atree") || name.hasPrefix("apine")
        registerFootprint(of: node,
                          widthRatio: isTree ? Self.foliageFootprintRatio(of: name, minimum: 0.58) : 0.58,
                          depthRatio: 0.4, maxDepth: 22)
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
}
