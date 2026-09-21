import SpriteKit

// Intérieurs de maisons.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - House Interiors

    func houseDoorPosition(for kind: HouseInteriorKind, in size: CGSize) -> CGPoint {
        let wh = worldHeight > 0 ? worldHeight : size.height
        switch kind {
        case .armory:
            return CGPoint(x: size.width * 0.50, y: wh * 0.63 + 12)
        case .apothecary:
            return CGPoint(x: size.width * 0.22, y: wh * 0.58 + 12)
        case .inn:
            return CGPoint(x: size.width * 0.78, y: wh * 0.58 + 12)
        }
    }

    func interiorExitPosition(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.50, y: size.height * 0.16)
    }

    func switchToInterior(_ kind: HouseInteriorKind, in scene: SKScene) {
        activeInterior = kind
        stopVillageWander()
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.035, green: 0.027, blue: 0.025, alpha: 1)
        buildInterior(kind, in: scene)
        // Vignette allégée : à 0,38 elle mangeait les murs et les angles de la
        // pièce, là où sont justement rangés l'établi, les fûts et le lit. Une
        // salle éclairée au feu est chaude et contrastée, pas aveugle.
        setZoneVignette(in: scene, alpha: 0.26)
        LightingEngine.applyGrade(.interior, in: scene)
        debugDrawObstacles(in: scene)   // --show-obstacles : audit (interior)
        AudioEngine.shared.setAmbience(.interior)
        kael.position = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.23)
        kael.zPosition = 20
    }

    func returnToVillageFromInterior(in scene: SKScene) {
        let previous = activeInterior
        activeInterior = nil
        clearBackdrop()
        scene.backgroundColor = SKColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1)
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = false }
        buildVillage(in: scene)
        layout(in: scene.size)
        if let previous {
            let door = houseDoorPosition(for: previous, in: scene.size)
            kael.position = CGPoint(x: door.x, y: max(58, door.y - 58))
            kael.zPosition = actorLayer(for: kael.position.y)
        }
        // De retour dehors : les villageois reprennent leur promenade.
        startVillageWander(in: scene.size)
    }

    func buildInterior(_ kind: HouseInteriorKind, in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height
        let room = CGRect(x: w * 0.15, y: h * 0.16, width: w * 0.70, height: h * 0.66)

        // Plancher : vraies planches de bois pixel art générées
        // (fini les tuiles de terre extérieures qui juraient en intérieur).
        let boards = PixelArtSprites.plankFloor(
            size: room.size,
            palette: interiorPlankPalette(for: kind),
            seed: UInt64(kind.rawValue.unicodeScalars.reduce(7) { $0 + Int($1.value) }))
        boards.position = CGPoint(x: room.minX, y: room.minY)
        boards.zPosition = -9
        add(boards, to: scene)

        // Tapis tissé central (accent par échoppe)
        let rugTint: SKColor
        switch kind {
        case .armory:     rugTint = SKColor(red: 0.38, green: 0.14, blue: 0.10, alpha: 1)
        case .apothecary: rugTint = SKColor(red: 0.14, green: 0.32, blue: 0.18, alpha: 1)
        case .inn:        rugTint = SKColor(red: 0.42, green: 0.24, blue: 0.10, alpha: 1)
        }
        let rug = PixelArtSprites.wovenRug(
            size: CGSize(width: 150, height: 96), accent: rugTint)
        rug.position = CGPoint(x: room.midX - 75, y: room.midY - 64)
        rug.zPosition = -8.4
        add(rug, to: scene)

        addInteriorWalls(in: scene, room: room, kind: kind)
        addInteriorExitDoor(in: scene, room: room)
        addInteriorTitle(kind, in: scene, room: room)

        // Lanternes aux quatre coins de la pièce
        for (dx, dy) in [(36.0, 40.0), (-36.0, 40.0)] {
            addInteriorSprite("village_lantern_1", in: scene,
                              at: CGPoint(x: dx > 0 ? room.minX + dx : room.maxX + dx,
                                          y: room.maxY - dy), scale: 0.42)
        }
        for (dx, dy) in [(36.0, 26.0), (-36.0, 26.0)] {
            addInteriorSprite("village_lantern_2", in: scene,
                              at: CGPoint(x: dx > 0 ? room.minX + dx : room.maxX + dx,
                                          y: room.minY + dy), scale: 0.42)
        }

        switch kind {
        case .armory:
            buildArmoryInterior(in: scene, room: room)
        case .apothecary:
            buildApothecaryInterior(in: scene, room: room)
        case .inn:
            buildInnInterior(in: scene, room: room)
        }
    }

    /// Palette de planches par échoppe : 3 bruns + joint sombre.
    func interiorPlankPalette(for kind: HouseInteriorKind) -> [UIColor] {
        switch kind {
        case .armory:
            // Noyer de forge. Il descendait à 0,26 sur le ton le plus sombre,
            // et sous la vignette d'intérieur la pièce virait au noir : on ne
            // distinguait plus l'établi du plancher. Relevé d'un cran — c'est
            // une forge, il y fait chaud, pas nuit noire.
            return [UIColor(red: 0.44, green: 0.32, blue: 0.21, alpha: 1),
                    UIColor(red: 0.39, green: 0.28, blue: 0.18, alpha: 1),
                    UIColor(red: 0.34, green: 0.24, blue: 0.16, alpha: 1),
                    UIColor(red: 0.17, green: 0.11, blue: 0.07, alpha: 1)]
        case .apothecary:
            // Bois patiné aux reflets verdis (herboristerie)
            return [UIColor(red: 0.38, green: 0.33, blue: 0.21, alpha: 1),
                    UIColor(red: 0.33, green: 0.29, blue: 0.18, alpha: 1),
                    UIColor(red: 0.28, green: 0.25, blue: 0.15, alpha: 1),
                    UIColor(red: 0.13, green: 0.12, blue: 0.07, alpha: 1)]
        case .inn:
            // Chêne chaleureux d'auberge
            return [UIColor(red: 0.42, green: 0.29, blue: 0.17, alpha: 1),
                    UIColor(red: 0.37, green: 0.25, blue: 0.14, alpha: 1),
                    UIColor(red: 0.32, green: 0.21, blue: 0.12, alpha: 1),
                    UIColor(red: 0.15, green: 0.09, blue: 0.05, alpha: 1)]
        }
    }

    /// Murs de pierre sur TOUT le pourtour : 2 rangées au fond (relief),
    /// 1 rangée sur les côtés et le bas — une vraie pièce fermée.
    func addInteriorWalls(in scene: SKScene, room: CGRect, kind: HouseInteriorKind) {
        let wallTint: SKColor
        switch kind {
        case .armory:
            wallTint = SKColor(red: 0.30, green: 0.24, blue: 0.20, alpha: 1)
        case .apothecary:
            wallTint = SKColor(red: 0.18, green: 0.28, blue: 0.20, alpha: 1)
        case .inn:
            wallTint = SKColor(red: 0.32, green: 0.22, blue: 0.14, alpha: 1)
        }
        let tile: CGFloat = 24
        let cols = Int(ceil(room.width / tile))
        let rows = Int(ceil(room.height / tile))
        let wallNames = ["me_wall_1", "me_wall_2", "me_wall_3", "me_wall_5"]

        func wallTile(_ idx: Int, at p: CGPoint) {
            guard let t = PixelArtSprites.still(name: wallNames[idx % wallNames.count],
                                                scale: 0.5,
                                                anchor: CGPoint(x: 0.5, y: 0.5)) else { return }
            t.position = p
            t.zPosition = -7
            t.forEachDescendantSprite { sprite in
                sprite.color = wallTint
                sprite.colorBlendFactor = 0.40
            }
            add(t, to: scene)
        }

        // Fond (2 rangées) + bas (1 rangée)
        for c in 0..<cols {
            let x = room.minX + (CGFloat(c) + 0.5) * tile
            wallTile(c, at: CGPoint(x: x, y: room.maxY - tile * 0.5))
            wallTile(c + 1, at: CGPoint(x: x, y: room.maxY - tile * 1.5))
            wallTile(c + 2, at: CGPoint(x: x, y: room.minY + tile * 0.5))
        }
        // Côtés
        for r in 1..<(rows - 1) {
            let y = room.minY + (CGFloat(r) + 0.5) * tile
            wallTile(r, at: CGPoint(x: room.minX + tile * 0.5, y: y))
            wallTile(r + 3, at: CGPoint(x: room.maxX - tile * 0.5, y: y))
        }
    }

    func addInteriorExitDoor(in scene: SKScene, room: CGRect) {
        let exit = SKNode()
        exit.position = interiorExitPosition(in: scene.size)
        exit.name = "interiorExit"
        exit.zPosition = -1

        let mat = SKShapeNode()
        PixelUI.stylePanel(mat, size: CGSize(width: 66, height: 20),
                           fill: SKColor(red: 0.11, green: 0.075, blue: 0.045, alpha: 0.90),
                           accent: SKColor(red: 0.60, green: 0.46, blue: 0.26, alpha: 0.9))
        exit.addChild(mat)

        let icon = SKLabelNode(fontNamed: PixelUI.uiFont)
        icon.text = String(localized: "interior.exit")
        icon.fontSize = 12
        icon.fontColor = SKColor(red: 0.92, green: 0.78, blue: 0.48, alpha: 0.9)
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = CGPoint(x: 0, y: -1)
        exit.addChild(icon)
        JuiceEngine.pulse(mat, scale: 1.06)

        add(exit, to: scene)
    }

    func addInteriorTitle(_ kind: HouseInteriorKind, in scene: SKScene, room: CGRect) {
        let title = SKLabelNode(fontNamed: PixelUI.uiFont)
        switch kind {
        case .armory: title.text = String(localized: "interior.armory.title")
        case .apothecary: title.text = String(localized: "interior.apothecary.title")
        case .inn: title.text = String(localized: "interior.inn.title")
        }
        title.fontSize = 15
        title.fontColor = SKColor(red: 0.88, green: 0.78, blue: 0.58, alpha: 0.95)
        title.horizontalAlignmentMode = .center
        // Au-DESSUS de la pièce : posée à l'intérieur, l'enseigne tombait
        // derrière le comptoir du fond et derrière le marchand — on lisait
        // « Ar…rerie de …am ».
        title.position = CGPoint(x: room.midX, y: room.maxY + 12)
        title.zPosition = 4
        add(title, to: scene)
    }


    func addInteriorSprite(_ name: String, in scene: SKScene, at position: CGPoint,
                                   scale: CGFloat, flipped: Bool = false) {
        // Les intérieurs passent par ici et NON par `addPixelProp` : ils
        // échappaient donc à la table de substitution, et l'auberge alignait
        // ses jerricans de plastique bleus pendant que le village dehors avait
        // ses fûts. Un seul filtre, deux portes d'entrée.
        guard let name = Self.substituted(name) else { return }
        guard let node = PixelArtSprites.still(name: name, scale: scale,
                                               anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        node.position = position
        if flipped { node.xScale = -abs(node.xScale == 0 ? 1 : node.xScale) }
        node.zPosition = propLayer(for: position.y, in: scene.size.height)
        addGroundShadow(under: node, width: 32 * scale, height: 8 * scale)
        add(node, to: scene)
    }

    /// Meuble « cozy » (planche 16 px) posé à une HAUTEUR visée à l'écran.
    ///
    /// Les meubles font 16 à 48 px de haut sur leur planche là où le décor ME
    /// des intérieurs en fait plusieurs centaines : passer par `scale:` comme
    /// les autres donnerait un âtre de la taille d'un tabouret. On vise donc
    /// des points, et l'échelle se déduit.
    func addCozyPiece(_ name: String, in scene: SKScene, at position: CGPoint,
                              height: CGFloat, flipped: Bool = false) {
        addInteriorSprite(name, in: scene, at: position,
                          scale: scaleFor(name, height: height), flipped: flipped)
    }

    /// Le marchand se tient derrière son comptoir (sprite animé).
    func addShopkeeper(_ asset: String, in scene: SKScene, at position: CGPoint) {
        guard let keeper = PixelArtSprites.animated(
            name: asset, frames: 6,
            scale: PixelArtSprites.scale(name: "\(asset)_idle_1",
                                         height: PixelArtSprites.npcHeight),
            timePerFrame: 0.18, anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        keeper.position = position
        keeper.zPosition = propLayer(for: position.y, in: scene.size.height) + 0.5
        add(keeper, to: scene)
    }

}
