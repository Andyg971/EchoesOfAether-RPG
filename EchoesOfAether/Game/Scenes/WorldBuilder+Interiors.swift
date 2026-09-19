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

    func buildArmoryInterior(in scene: SKScene, room: CGRect) {
        // ── FOND : long comptoir + Bram derrière ──
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX - 44, y: room.maxY - 66), scale: 0.30)
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX + 44, y: room.maxY - 66), scale: 0.30)
        addShopkeeper("npc_bram", in: scene, at: CGPoint(x: room.midX, y: room.maxY - 52))

        // ── FORGE (droite) : un vrai âtre de brique adossé au mur, pas un
        // feu de camp posé sur le plancher d'une maison. Marmite et billot
        // restent, ils font le poste de travail.
        addCozyPiece("cz_hearth_brick_lit", in: scene,
                     at: CGPoint(x: room.maxX - 56, y: room.maxY - 96), height: 58)
        addInteriorSprite("me_hanging_pot", in: scene, at: CGPoint(x: room.maxX - 96, y: room.maxY - 70), scale: 0.40)
        addInteriorSprite("me_cut_wood_bench", in: scene, at: CGPoint(x: room.maxX - 56, y: room.maxY - 128), scale: 0.42)

        // ── RÂTELIER À BOIS (gauche) : réserve de la forge ──
        addInteriorSprite("me_cut_wood", in: scene, at: CGPoint(x: room.minX + 46, y: room.maxY - 72), scale: 0.44)
        addInteriorSprite("me_cut_wood_2", in: scene, at: CGPoint(x: room.minX + 78, y: room.maxY - 76), scale: 0.44)
        addInteriorSprite("me_cut_wood", in: scene, at: CGPoint(x: room.minX + 46, y: room.maxY - 104), scale: 0.40)

        // ── STOCK : tonneaux et caisses alignés sur les murs ──
        addInteriorSprite("me_barrel_1", in: scene, at: CGPoint(x: room.minX + 40, y: room.midY + 6), scale: 0.42)
        addInteriorSprite("me_barrel_2", in: scene, at: CGPoint(x: room.minX + 40, y: room.midY - 28), scale: 0.42)
        addInteriorSprite("village_crate_1", in: scene, at: CGPoint(x: room.minX + 42, y: room.midY - 62), scale: 0.40)
        addInteriorSprite("me_barrel_3", in: scene, at: CGPoint(x: room.maxX - 40, y: room.midY - 4), scale: 0.42)
        addInteriorSprite("me_barrel_4", in: scene, at: CGPoint(x: room.maxX - 40, y: room.midY - 38), scale: 0.42)
        addInteriorSprite("village_crate_2", in: scene, at: CGPoint(x: room.maxX - 42, y: room.midY - 70), scale: 0.40)

        // ── ÉTABLI sur le tapis central, avec de quoi s'asseoir pour ferrer ──
        addInteriorSprite("interior_bench_table", in: scene, at: CGPoint(x: room.midX, y: room.midY - 34), scale: 0.60)
        addInteriorSprite("me_basket_2", in: scene, at: CGPoint(x: room.midX + 52, y: room.midY - 40), scale: 0.38)
        addCozyPiece("cz_stool", in: scene,
                     at: CGPoint(x: room.midX - 46, y: room.midY - 44), height: 16)
        // Armoire à outils contre le mur du fond, entre le râtelier et le comptoir
        addCozyPiece("cz_cupboard", in: scene,
                     at: CGPoint(x: room.minX + 116, y: room.maxY - 96), height: 48)

        addServiceMarker(in: scene, at: CGPoint(x: room.midX, y: room.maxY - 96), text: String(localized: "interior.armory.forge"))
    }

    func buildApothecaryInterior(in scene: SKScene, room: CGRect) {
        // ── FOND : comptoir + étagère de fioles (rangée de vases) ──
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX - 30, y: room.maxY - 66), scale: 0.28)
        addShopkeeper("npc_mara", in: scene, at: CGPoint(x: room.midX - 30, y: room.maxY - 52))
        addInteriorSprite("me_vase_red", in: scene, at: CGPoint(x: room.midX + 44, y: room.maxY - 62), scale: 0.40)
        addInteriorSprite("me_vase_yellow", in: scene, at: CGPoint(x: room.midX + 70, y: room.maxY - 64), scale: 0.40)
        addInteriorSprite("me_vase_pink", in: scene, at: CGPoint(x: room.midX + 96, y: room.maxY - 62), scale: 0.40)
        addInteriorSprite("me_vase_sunflower", in: scene, at: CGPoint(x: room.midX + 122, y: room.maxY - 64), scale: 0.40)

        // ── SERRE (gauche) : plantes en pots et pousses ──
        addInteriorSprite("interior_plant", in: scene, at: CGPoint(x: room.minX + 42, y: room.maxY - 72), scale: 0.44)
        addInteriorSprite("me_big_sprout_4", in: scene, at: CGPoint(x: room.minX + 74, y: room.maxY - 78), scale: 0.42)
        addInteriorSprite("me_big_sprout_5", in: scene, at: CGPoint(x: room.minX + 44, y: room.maxY - 108), scale: 0.42)
        addInteriorSprite("me_big_sprout_6", in: scene, at: CGPoint(x: room.minX + 76, y: room.maxY - 112), scale: 0.40)
        addInteriorSprite("me_vase_sunflower", in: scene, at: CGPoint(x: room.minX + 42, y: room.midY - 6), scale: 0.42)

        // ── CULTURE : champignons et paniers le long du mur droit ──
        addInteriorSprite("me_mushrooms_1", in: scene, at: CGPoint(x: room.maxX - 44, y: room.midY + 8), scale: 0.42)
        addInteriorSprite("me_mushrooms_2", in: scene, at: CGPoint(x: room.maxX - 44, y: room.midY - 24), scale: 0.42)
        addInteriorSprite("me_basket", in: scene, at: CGPoint(x: room.maxX - 46, y: room.midY - 56), scale: 0.42)
        addInteriorSprite("me_apples", in: scene, at: CGPoint(x: room.maxX - 44, y: room.midY - 84), scale: 0.38)

        // ── TABLE D'ALCHIMIE sur le tapis ──
        addInteriorSprite("interior_potion_table", in: scene, at: CGPoint(x: room.midX, y: room.midY - 30), scale: 0.48)
        addInteriorSprite("interior_plant", in: scene, at: CGPoint(x: room.midX - 58, y: room.midY - 40), scale: 0.40, flipped: true)

        // ── COIN DE CONSULTATION : on vient chez Mara pour être soigné, il
        // faut donc un endroit où s'asseoir. Âtre éteint : elle fait sécher
        // ses simples au-dessus, pas de flambée en plein cabinet d'herbes.
        addCozyPiece("cz_hearth_stone", in: scene,
                     at: CGPoint(x: room.minX + 118, y: room.maxY - 96), height: 54)
        addCozyPiece("cz_settle_blanket", in: scene,
                     at: CGPoint(x: room.midX + 74, y: room.midY - 44), height: 32)
        addCozyPiece("cz_table_round", in: scene,
                     at: CGPoint(x: room.midX + 118, y: room.midY - 40), height: 28)
        addCozyPiece("cz_chair_3", in: scene,
                     at: CGPoint(x: room.midX + 150, y: room.midY - 46), height: 30, flipped: true)
        // Armoire à simples, alignée sur la serre
        addCozyPiece("cz_dresser", in: scene,
                     at: CGPoint(x: room.minX + 42, y: room.midY - 72), height: 46)

        addServiceMarker(in: scene, at: CGPoint(x: room.midX, y: room.maxY - 96), text: String(localized: "interior.apothecary.potions"))
    }

    func buildInnInterior(in scene: SKScene, room: CGRect) {
        // ── BAR (fond droit) : comptoir en L + tonneaux ──
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.maxX - 70, y: room.maxY - 66), scale: 0.30)
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.maxX - 150, y: room.maxY - 66), scale: 0.30)
        addShopkeeper("npc_sage", in: scene, at: CGPoint(x: room.maxX - 110, y: room.maxY - 52))
        addInteriorSprite("me_barrel_1", in: scene, at: CGPoint(x: room.maxX - 44, y: room.maxY - 96), scale: 0.40)
        addInteriorSprite("me_barrel_2", in: scene, at: CGPoint(x: room.maxX - 44, y: room.maxY - 126), scale: 0.40)
        addInteriorSprite("me_barrel_3", in: scene, at: CGPoint(x: room.maxX - 76, y: room.maxY - 100), scale: 0.38)

        // ── ÂTRE (fond gauche) : la grande cheminée de la salle commune,
        // et devant elle deux fauteuils autour d'une table basse. C'est ce
        // coin-là qui fait une auberge plutôt qu'une salle à manger — un feu
        // de camp posé sur un plancher n'y suffisait pas.
        addCozyPiece("cz_hearth_stone_lit", in: scene,
                     at: CGPoint(x: room.minX + 54, y: room.maxY - 96), height: 60)
        addInteriorSprite("me_hanging_pot", in: scene, at: CGPoint(x: room.minX + 92, y: room.maxY - 72), scale: 0.42)
        addCozyPiece("cz_armchair_linen", in: scene,
                     at: CGPoint(x: room.minX + 32, y: room.maxY - 150), height: 40)
        addCozyPiece("cz_armchair_ash", in: scene,
                     at: CGPoint(x: room.minX + 104, y: room.maxY - 150), height: 40, flipped: true)
        addCozyPiece("cz_table_low", in: scene,
                     at: CGPoint(x: room.minX + 68, y: room.maxY - 156), height: 16)
        addInteriorSprite("me_cut_wood_2", in: scene, at: CGPoint(x: room.minX + 128, y: room.maxY - 104), scale: 0.38)

        // ── SALLE : deux tablées dressées, chaises dépareillées (une auberge
        // n'achète pas son mobilier en série) ──
        addCozyPiece("cz_table_long", in: scene,
                     at: CGPoint(x: room.midX - 30, y: room.midY - 20), height: 32)
        addCozyPiece("cz_chair_1", in: scene,
                     at: CGPoint(x: room.midX - 74, y: room.midY - 26), height: 30)
        addCozyPiece("cz_chair_2", in: scene,
                     at: CGPoint(x: room.midX + 14, y: room.midY - 26), height: 30, flipped: true)
        addCozyPiece("cz_table_long", in: scene,
                     at: CGPoint(x: room.midX + 84, y: room.midY + 10), height: 32)
        addCozyPiece("cz_chair_4", in: scene,
                     at: CGPoint(x: room.midX + 40, y: room.midY + 4), height: 30)
        addCozyPiece("cz_chair_6", in: scene,
                     at: CGPoint(x: room.midX + 128, y: room.midY + 4), height: 30, flipped: true)
        addInteriorSprite("me_basket", in: scene, at: CGPoint(x: room.midX - 30, y: room.midY + 16), scale: 0.36)

        // ── COIN NUIT (bas gauche) : les lits DESCENDENT sous le coin du feu.
        // Ils partageaient sa hauteur et les fauteuils leur poussaient dessus.
        // Le banc de voyageur disparaît : les fauteuils le remplacent.
        addInteriorSprite("interior_bed", in: scene, at: CGPoint(x: room.minX + 46, y: room.minY + 96), scale: 0.32)
        addInteriorSprite("interior_bed", in: scene, at: CGPoint(x: room.minX + 46, y: room.minY + 52), scale: 0.32)

        // ── BUFFET derrière le bar : vaisselle et réserve du jour ──
        addCozyPiece("cz_sideboard", in: scene,
                     at: CGPoint(x: room.maxX - 172, y: room.maxY - 100), height: 32)

        // ── CUVE DE BAIN, au coin nuit : on se lave avant de dormir. Seul
        // morceau retenu du lot salle de bain, et repeint en bois — la
        // baignoire acrylique à mitigeur chromé n'avait rien à faire ici.
        addCozyPiece("cz_bathtub_wood", in: scene,
                     at: CGPoint(x: room.minX + 132, y: room.minY + 60), height: 30)

        addServiceMarker(in: scene, at: CGPoint(x: room.maxX - 110, y: room.maxY - 96), text: String(localized: "interior.inn.rest"))
    }

    func addServiceMarker(in scene: SKScene, at position: CGPoint, text: String) {
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = text
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.96, green: 0.84, blue: 0.52, alpha: 0.9)
        label.horizontalAlignmentMode = .center
        label.position = position
        label.zPosition = 60   // libellé flottant : lisible au-dessus du monde
        add(label, to: scene)
        JuiceEngine.float(label, distance: 3)
    }
}
