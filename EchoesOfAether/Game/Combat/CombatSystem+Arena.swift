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
