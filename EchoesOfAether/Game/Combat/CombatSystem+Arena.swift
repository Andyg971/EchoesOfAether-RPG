import SpriteKit

// Décor d'arène : ciel, sol, palettes par zone, plates des combattants.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Arena visuals

    func setupArenaFloor(scene: SKScene, enemyKind: CombatSpriteKind, isBoss: Bool) {
        let floor = SKNode()
        floor.zPosition = -5

        let size = scene.size
        let palette = arenaPalette(for: enemyKind, isBoss: isBoss)
        let floorY = size.height * 0.40

        // Ciel/voûte : bande pleine en haut, teinte de zone. Elle reste
        // SOUS le décor en couches et lui sert de fond — sans elle, un trou
        // noir apparaîtrait au-dessus des montagnes sur les écrans hauts.
        let sky = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.55))
        sky.fillColor = palette.skyColor
        sky.strokeColor = .clear
        sky.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        // Derrière TOUT le reste : sans zPosition explicite elle vaut 0 et
        // recouvrait les couches de décor, qui sont en négatif.
        sky.zPosition = -20
        floor.addChild(sky)

        addArenaBackdrop(to: floor, size: size, kind: enemyKind,
                         palette: palette, floorY: floorY)

        // Halo central — concentre le regard sur les combattants
        let halo = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.4, height: 360))
        halo.fillColor = palette.haloColor
        halo.strokeColor = .clear
        halo.position = CGPoint(x: size.width / 2, y: floorY + 20)
        halo.alpha = 0.55
        floor.addChild(halo)

        // Décor d'arrière-plan : silhouettes selon la zone, dans une
        // couche qui dérive lentement (parallaxe subtile).
        let decorLayer = SKNode()
        floor.addChild(decorLayer)
        addBackgroundDecor(to: decorLayer, size: size, kind: enemyKind, palette: palette)
        let drift = SKAction.sequence([
            .moveBy(x: 6, y: 0, duration: 7.0),
            .moveBy(x: -6, y: 0, duration: 7.0)
        ])
        drift.timingMode = .easeInEaseOut
        decorLayer.run(.repeatForever(drift))

        // Nappe de brume au-dessus du décor, dérive en sens inverse
        let mist = SKSpriteNode(color: palette.haloColor.withAlphaComponent(0.16),
                                size: CGSize(width: size.width * 1.3, height: 46))
        mist.position = CGPoint(x: size.width / 2, y: size.height * 0.50)
        floor.addChild(mist)
        let mistDrift = SKAction.sequence([
            .moveBy(x: -18, y: 0, duration: 9.0),
            .moveBy(x: 18, y: 0, duration: 9.0)
        ])
        mistDrift.timingMode = .easeInEaseOut
        mist.run(.repeatForever(mistDrift))

        // Ligne d'horizon : trait fin lumineux
        let horizon = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
        horizon.fillColor = palette.horizonColor
        horizon.strokeColor = .clear
        horizon.position = CGPoint(x: size.width / 2, y: floorY + 30)
        floor.addChild(horizon)

        // Plateforme circulaire : ombre principale + bord lumineux
        let stageOuter = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.15, height: 150))
        stageOuter.fillColor = palette.stageEdgeColor
        stageOuter.strokeColor = .clear
        stageOuter.position = CGPoint(x: size.width / 2, y: floorY - 32)
        floor.addChild(stageOuter)

        let stage = SKShapeNode(ellipseOf: CGSize(width: size.width * 1.05, height: 130))
        stage.fillColor = palette.stageColor
        stage.strokeColor = palette.stageStrokeColor
        stage.lineWidth = 2
        stage.position = CGPoint(x: size.width / 2, y: floorY - 28)
        floor.addChild(stage)

        // Runes subtiles au sol (boss only) — losanges pixel, zéro glow.
        if isBoss {
            for dx: CGFloat in [-90, 0, 90] {
                let rune = SKSpriteNode(
                    color: SKColor(red: 0.85, green: 0.50, blue: 1, alpha: 0.7),
                    size: CGSize(width: 6, height: 6))
                rune.zRotation = .pi / 4
                rune.position = CGPoint(x: size.width / 2 + dx, y: floorY - 48)
                floor.addChild(rune)
                JuiceEngine.pulse(rune, scale: 1.4)
            }
        }

        root.addChild(floor)
        arenaFloor = floor
    }

    struct ArenaPalette {
        let skyColor: SKColor
        let haloColor: SKColor
        let horizonColor: SKColor
        let stageColor: SKColor
        let stageEdgeColor: SKColor
        let stageStrokeColor: SKColor
        let decorColor: SKColor
    }

    /// DÉCOR D'ARÈNE EN COUCHES — ciel, montagnes, deux lignes d'arbres,
    /// pinède au premier plan (planches `arena_<saison>_1..5`, 1024×346).
    ///
    /// L'arène n'avait qu'un aplat de couleur en guise de fond, et cet aplat
    /// était si sombre (ciel à 0,08/0,04/0,05) que tous les combats se
    /// ressemblaient : du noir. Cinq plans à des profondeurs différentes
    /// donnent un horizon, et la saison change avec la zone — la forêt en
    /// vert, les Ruines en automne, le Sanctuaire en hiver violacé.
    ///
    /// Les couches DÉRIVENT à des vitesses croissantes vers l'avant : c'est
    /// ce décalage, et non le dessin, qui fait lire la profondeur.
    func addArenaBackdrop(to parent: SKNode, size: CGSize,
                                  kind: CombatSpriteKind,
                                  palette: ArenaPalette, floorY: CGFloat) {
        let season: String
        let tint: SKColor?
        switch kind {
        case .beast, .wolf, .ghoul, .boneWalker:
            season = "normal"; tint = nil
        case .ruinsGuardian, .archivist:
            season = "autumn"; tint = nil
        case .guardian:
            // Hiver teinté violet : le Sanctuaire n'est pas un lieu du monde.
            season = "winter"; tint = SKColor(red: 0.45, green: 0.20, blue: 0.75, alpha: 1)
        }

        // 5 = le plus lointain. On les pose du fond vers l'avant, la
        // luminosité montant avec la distance pour creuser l'image.
        for depth in stride(from: 5, through: 1, by: -1) {
            let name = "arena_\(season)_\(depth)"
            guard UIImage(named: name) != nil else { continue }
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .nearest
            let layer = SKSpriteNode(texture: texture)
            let scale = size.width / texture.size().width
            layer.setScale(scale)
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            layer.position = CGPoint(x: size.width / 2, y: floorY - 12)
            // Entre le ciel (−20) et le halo/estrade (≥ 0).
            layer.zPosition = -10 - CGFloat(depth)
            // Les plans lointains s'effacent : c'est la perspective aérienne,
            // et ça garde les combattants lisibles au premier plan.
            layer.alpha = 0.55 + 0.10 * CGFloat(5 - depth)
            if let tint {
                layer.color = tint
                layer.colorBlendFactor = 0.55
            }
            parent.addChild(layer)

            // Dérive : imperceptible au fond, nette devant.
            let amplitude = 2.0 + Double(5 - depth) * 3.0
            let period = 11.0 - Double(5 - depth) * 1.2
            let drift = SKAction.sequence([
                .moveBy(x: amplitude, y: 0, duration: period),
                .moveBy(x: -amplitude, y: 0, duration: period)
            ])
            drift.timingMode = .easeInEaseOut
            layer.run(.repeatForever(drift))
        }

        // Le château, entre le ciel et les arbres : il donne une échelle au
        // lointain et dit qu'il y a un monde derrière le combat.
        let castleName = "arena_\(season)_castle"
        if UIImage(named: castleName) != nil {
            let texture = SKTexture(imageNamed: castleName)
            texture.filteringMode = .nearest
            let castle = SKSpriteNode(texture: texture)
            castle.setScale(size.width / texture.size().width)
            castle.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            castle.position = CGPoint(x: size.width * 0.5, y: floorY - 12)
            castle.zPosition = -14.5   // entre les montagnes (−14) et les arbres (−13)
            castle.alpha = 0.6
            if let tint {
                castle.color = tint
                castle.colorBlendFactor = 0.55
            }
            parent.addChild(castle)
        }
    }

    func arenaPalette(for kind: CombatSpriteKind, isBoss: Bool) -> ArenaPalette {
        switch kind {
        // ⚠️ Ces teintes servent de FOND aux couches de décor
        // (`addArenaBackdrop`). Descendues trop bas, le décor ne se détache
        // plus et l'arène redevient le trou noir qu'elle était : le ciel
        // était à 0,05/0,09/0,07, soit du noir à 7 %.
        case .beast, .wolf, .ghoul, .boneWalker:
            // Forêt d'Ébène : verts profonds, mais un ciel qui existe
            return ArenaPalette(
                skyColor: SKColor(red: 0.11, green: 0.20, blue: 0.16, alpha: 1),
                haloColor: SKColor(red: 0.18, green: 0.30, blue: 0.22, alpha: 0.35),
                horizonColor: SKColor(red: 0.30, green: 0.55, blue: 0.38, alpha: 0.4),
                stageColor: SKColor(red: 0.13, green: 0.19, blue: 0.15, alpha: 1),
                stageEdgeColor: SKColor(red: 0.06, green: 0.10, blue: 0.08, alpha: 1),
                stageStrokeColor: SKColor(red: 0.25, green: 0.45, blue: 0.30, alpha: 0.5),
                decorColor: SKColor(red: 0.04, green: 0.08, blue: 0.05, alpha: 1)
            )
        case .guardian:
            // Sanctuaire de l'Aether : violets profonds
            return ArenaPalette(
                skyColor: SKColor(red: 0.14, green: 0.09, blue: 0.26, alpha: 1),
                haloColor: SKColor(red: 0.40, green: 0.18, blue: 0.65, alpha: 0.45),
                horizonColor: SKColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 0.55),
                stageColor: SKColor(red: 0.18, green: 0.12, blue: 0.28, alpha: 1),
                stageEdgeColor: SKColor(red: 0.08, green: 0.05, blue: 0.13, alpha: 1),
                stageStrokeColor: SKColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 0.6),
                decorColor: SKColor(red: 0.08, green: 0.05, blue: 0.14, alpha: 1)
            )
        case .ruinsGuardian, .archivist:
            // Ruines de la Source : marron-rouge délavé
            let bossBoost: CGFloat = isBoss ? 1.2 : 1.0
            return ArenaPalette(
                skyColor: SKColor(red: 0.20 * bossBoost, green: 0.11, blue: 0.12, alpha: 1),
                haloColor: SKColor(red: 0.45, green: 0.18, blue: 0.15, alpha: 0.4),
                horizonColor: SKColor(red: 0.80, green: 0.35, blue: 0.20, alpha: 0.45),
                stageColor: SKColor(red: 0.20, green: 0.13, blue: 0.11, alpha: 1),
                stageEdgeColor: SKColor(red: 0.09, green: 0.05, blue: 0.05, alpha: 1),
                stageStrokeColor: SKColor(red: 0.60, green: 0.28, blue: 0.18, alpha: 0.55),
                decorColor: SKColor(red: 0.10, green: 0.06, blue: 0.05, alpha: 1)
            )
        }
    }

    /// Silhouettes d'arrière-plan adaptées à la zone. Tente d'abord les
    /// sprites pixel art importés depuis `Assets.xcassets` (Modern Exteriors) ;
    /// fallback automatique sur les shapes programmatiques si l'asset manque.
    func addBackgroundDecor(to floor: SKNode, size: CGSize,
                                     kind: CombatSpriteKind, palette: ArenaPalette) {
        let baseY = size.height * 0.48
        let decorColor = palette.decorColor
        let edgeColor = palette.stageStrokeColor.withAlphaComponent(0.25)

        switch kind {
        case .beast, .wolf, .ghoul, .boneWalker:
            // Forêt : 6 arbres répartis en profondeur (mix tree_medium_1/2/3/big)
            let treeAssets = ["tree_medium_1", "tree_medium_2", "tree_medium_3",
                               "tree_big", "tree_medium_1", "tree_medium_2"]
            let positions: [(x: CGFloat, h: CGFloat, scale: CGFloat)] = [
                (0.08, 130, 0.9), (0.22, 95, 0.7), (0.40, 150, 1.0),
                (0.60, 105, 0.8), (0.78, 140, 0.95), (0.92, 100, 0.75)
            ]
            for (i, p) in positions.enumerated() {
                let pos = CGPoint(x: size.width * p.x, y: baseY)
                let node = decorSprite(name: treeAssets[i], pixelScale: p.scale * 3.5)
                    ?? makeTreeSilhouette(height: p.h, color: decorColor, edge: edgeColor)
                node.position = pos
                if PixelArtSprites.exists(treeAssets[i]) == false {
                    node.setScale(p.scale)
                }
                node.alpha = 0.85
                floor.addChild(node)
            }
        case .guardian:
            // Sanctuaire : 4 piliers (marble tombstone → pilier pierre)
            let assets = ["pillar_grey_1", "pillar_grey_2", "pillar_grey_1", "pillar_grey_2"]
            for (i, x) in [CGFloat(0.12), 0.32, 0.68, 0.88].enumerated() {
                let pos = CGPoint(x: size.width * x, y: baseY - 30)
                let node = decorSprite(name: assets[i], pixelScale: 4.0)
                    ?? makePillarSilhouette(height: 200, color: decorColor, edge: edgeColor)
                node.position = pos
                node.alpha = 0.9
                floor.addChild(node)
            }
        case .ruinsGuardian, .archivist:
            // Ruines : colonnes brisées + ossements épars
            let columnSpecs: [(x: CGFloat, h: CGFloat)] = [(0.12, 130), (0.50, 90), (0.86, 160)]
            for c in columnSpecs {
                let pos = CGPoint(x: size.width * c.x, y: baseY - 20)
                let node = decorSprite(name: "column_broken_1", pixelScale: 4.0)
                    ?? makeBrokenColumn(height: c.h, color: decorColor, edge: edgeColor)
                node.position = pos
                node.alpha = 0.9
                floor.addChild(node)
            }
            if let bones = decorSprite(name: "bones_1", pixelScale: 2.5) {
                bones.position = CGPoint(x: size.width * 0.30, y: baseY - 70)
                bones.alpha = 0.85
                floor.addChild(bones)
            }
        }
    }

    /// Charge un sprite pixel art comme décor avec ancre centrée bas.
    /// Le facteur `pixelScale` upscale les pixels 16×16 vers une taille
    /// lisible à l'écran (×3.5 = ~56pt, équivalent silhouette précédente).
    func decorSprite(name: String, pixelScale: CGFloat) -> SKNode? {
        PixelArtSprites.still(name: name, scale: pixelScale,
                              anchor: CGPoint(x: 0.5, y: 0))
    }

    func makeTreeSilhouette(height: CGFloat, color: SKColor, edge: SKColor) -> SKNode {
        let node = SKNode()
        // Tronc
        let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: height * 0.4), cornerRadius: 2)
        trunk.fillColor = color
        trunk.strokeColor = edge
        trunk.lineWidth = 1
        trunk.position = CGPoint(x: 0, y: height * 0.2)
        node.addChild(trunk)
        // Couronne triangulaire
        let crown = SKShapeNode()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -28, y: 0))
        p.addLine(to: CGPoint(x: 28, y: 0))
        p.addLine(to: CGPoint(x: 0, y: height * 0.85))
        p.closeSubpath()
        crown.path = p
        crown.fillColor = color
        crown.strokeColor = edge
        crown.lineWidth = 1
        crown.position = CGPoint(x: 0, y: height * 0.25)
        node.addChild(crown)
        return node
    }

    func makePillarSilhouette(height: CGFloat, color: SKColor, edge: SKColor) -> SKNode {
        let node = SKNode()
        let shaft = SKShapeNode(rectOf: CGSize(width: 22, height: height), cornerRadius: 2)
        shaft.fillColor = color
        shaft.strokeColor = edge
        shaft.lineWidth = 1
        node.addChild(shaft)
        // Chapiteau
        let cap = SKShapeNode(rectOf: CGSize(width: 32, height: 10), cornerRadius: 1)
        cap.fillColor = color
        cap.strokeColor = edge
        cap.position = CGPoint(x: 0, y: height / 2 + 4)
        node.addChild(cap)
        // Base
        let base = SKShapeNode(rectOf: CGSize(width: 30, height: 8), cornerRadius: 1)
        base.fillColor = color
        base.strokeColor = edge
        base.position = CGPoint(x: 0, y: -height / 2 - 2)
        node.addChild(base)
        return node
    }

    func makeBrokenColumn(height: CGFloat, color: SKColor, edge: SKColor) -> SKNode {
        let node = SKNode()
        let shaft = SKShapeNode(rectOf: CGSize(width: 26, height: height), cornerRadius: 1)
        shaft.fillColor = color
        shaft.strokeColor = edge
        shaft.lineWidth = 1
        node.addChild(shaft)
        // Sommet brisé : triangle inversé
        let top = SKShapeNode()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -13, y: height / 2))
        p.addLine(to: CGPoint(x: 13, y: height / 2))
        p.addLine(to: CGPoint(x: -5, y: height / 2 + 12))
        p.closeSubpath()
        top.path = p
        top.fillColor = color
        top.strokeColor = edge
        node.addChild(top)
        // Base trapézoïdale
        let base = SKShapeNode(rectOf: CGSize(width: 34, height: 10), cornerRadius: 1)
        base.fillColor = color
        base.strokeColor = edge
        base.position = CGPoint(x: 0, y: -height / 2 - 4)
        node.addChild(base)
        return node
    }

    func setupCombatants(scene: SKScene) {
        // Perspective 3/4 à la Octopath : Kael au premier plan, ennemis
        // étagés à droite.
        //
        // La formation s'étalait en diagonale serrée (Kael 0.34/0.50, alliés
        // 0.22/0.58 et 0.19/0.67). Deux défauts, mesurés sur 874×402 :
        //
        // - Les deux alliés n'étaient qu'à 45 pt l'un de l'autre pour des
        //   corps de ~45 pt de large : ils se marchaient dessus.
        // - Leurs sprites montaient jusqu'à 269 et 305, alors que la rangée
        //   de plates descend à 265 : le porteur du dernier créneau passait
        //   devant sa propre barre de Magie.
        //
        // La diagonale est donc plus plate et plus large : elle garde la
        // profondeur (Kael devant, alliés en retrait) mais chaque corps a sa
        // place, et le groupe reste sous les plates.
        let k = CombatSprites.kael()
        k.position = CGPoint(x: scene.size.width * 0.33, y: scene.size.height * 0.46)
        k.setScale(1.10)
        k.zPosition = 6
        root.addChild(k)
        kaelSprite = k
        kaelHomePosition = k.position

        // Alliés en retrait derrière Kael (profondeur 3/4, diagonale)
        let allySlots: [(x: CGFloat, y: CGFloat)] = [(0.21, 0.49), (0.10, 0.52)]
        for (i, ally) in allies.enumerated() {
            let node = CombatSprites.ally(kind: ally.kind)
            node.position = CGPoint(x: scene.size.width * allySlots[i].x,
                                    y: scene.size.height * allySlots[i].y)
            node.setScale(0.95)
            node.zPosition = 5.4 - CGFloat(i) * 0.1
            root.addChild(node)
            ally.sprite = node
            ally.home = node.position
        }

        let formations: [[(x: CGFloat, y: CGFloat)]] = [
            [(0.74, 0.46)],
            [(0.68, 0.40), (0.81, 0.52)],
            [(0.65, 0.36), (0.76, 0.46), (0.86, 0.56)]
        ]
        let slots = formations[min(enemies.count, 3) - 1]
        let scale: CGFloat = enemies.count == 1 ? 0.90 : 0.78

        for (i, e) in enemies.enumerated() {
            let node = CombatSprites.enemy(kind: e.kind)
            // xScale négatif : l'ennemi regarde Kael.
            node.xScale = -scale
            node.yScale = scale
            node.position = CGPoint(x: scene.size.width * slots[i].x,
                                    y: scene.size.height * slots[i].y)
            // Plus bas à l'écran = plus proche = devant
            node.zPosition = 5 - CGFloat(i) * 0.1 + (0.5 - slots[i].y)
            root.addChild(node)
            e.sprite = node
            e.homePosition = node.position

            e.statusIcons.position = CGPoint(x: node.position.x,
                                             y: node.position.y + 46)
            e.statusIcons.zPosition = 860
            root.addChild(e.statusIcons)

            // Sceaux du grand coup, au-dessus des pictos de statut.
            e.lockIcons.position = CGPoint(x: node.position.x,
                                           y: node.position.y + 74)
            e.lockIcons.zPosition = 870
            root.addChild(e.lockIcons)
        }
    }

    func playEntranceAnimation() {
        guard let k = kaelSprite else { return }
        k.alpha = 0
        k.position = CGPoint(x: kaelHomePosition.x - 80, y: kaelHomePosition.y)
        k.run(.group([
            .fadeIn(withDuration: 0.35),
            .move(to: kaelHomePosition, duration: 0.45)
        ]))
        for (i, ally) in allies.enumerated() {
            guard let node = ally.sprite else { continue }
            node.alpha = 0
            node.position = CGPoint(x: ally.home.x - 70, y: ally.home.y)
            node.run(.sequence([
                .wait(forDuration: 0.12 + Double(i) * 0.10),
                .group([
                    .fadeIn(withDuration: 0.35),
                    .move(to: ally.home, duration: 0.45)
                ])
            ]))
        }
        for (i, e) in enemies.enumerated() {
            guard let node = e.sprite else { continue }
            node.alpha = 0
            node.position = CGPoint(x: e.homePosition.x + 80, y: e.homePosition.y)
            node.run(.sequence([
                .wait(forDuration: 0.1 + Double(i) * 0.12),
                .group([
                    .fadeIn(withDuration: 0.35),
                    .move(to: e.homePosition, duration: 0.45)
                ])
            ]))
        }
    }
}
