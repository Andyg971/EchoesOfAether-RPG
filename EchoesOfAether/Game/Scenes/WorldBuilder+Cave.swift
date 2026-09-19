import SpriteKit

// Caverne aux Échos (donjon optionnel).
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Caverne aux Échos (donjon optionnel, entrée depuis la forêt)

    func switchToCave(in scene: SKScene, cleared: Bool, chestTaken: Bool) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)
        buildCave(in: scene, cleared: cleared, chestTaken: chestTaken)
        // Cristal près de l'entrée de la caverne.
        addSaveCrystal(at: CGPoint(x: scene.size.width * 0.20,
                                   y: scene.size.height * 0.18), in: scene)
        LightingEngine.applyGrade(.mines, in: scene)
        LightingEngine.attachHeroLight(to: kael)
        setZoneVignette(in: scene, alpha: 0.50)
        AudioEngine.shared.setAmbience(.mines)
    }

    /// Caverne aux Échos : cavité oubliée sous la forêt où les voix des
    /// anciens résonnent encore. Plein écran (pas de scroll). Une statue
    /// d'ange veille au fond, un gardien d'ossements barre l'accès au
    /// coffre. 100 % assets existants + coffre pixel dessiné en code.
    func buildCave(in scene: SKScene, cleared: Bool, chestTaken: Bool) {
        let w = scene.size.width
        let h = scene.size.height

        addTiledFloor(in: scene, tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.12, green: 0.13, blue: 0.18, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Voûte de pierre (deux rangées en haut)
        let wallTile: CGFloat = 24
        for c in 0..<(Int(ceil(w / wallTile)) + 1) {
            for r in 0..<2 {
                guard let t = PixelArtSprites.still(
                    name: ["me_wall_1", "me_wall_2", "me_wall_3", "me_wall_5"][(c + r) % 4],
                    scale: 0.5, anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
                t.position = CGPoint(x: CGFloat(c) * wallTile + wallTile / 2,
                                     y: h - CGFloat(r) * wallTile - wallTile / 2)
                t.zPosition = -6
                t.forEachDescendantSprite { s in
                    s.color = SKColor(red: 0.14, green: 0.15, blue: 0.22, alpha: 1)
                    s.colorBlendFactor = 0.55
                }
                add(t, to: scene)
            }
        }

        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.cave.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.58, green: 0.60, blue: 0.72, alpha: 0.7)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.90)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // Nappes de lumière froide (échos de l'Aether) : rendent visibles
        // les points d'intérêt dans le noir sans casser l'ambiance.
        for (x, y, rad) in [(0.50, 0.80, 130.0), (0.50, 0.55, 100.0), (0.50, 0.68, 90.0)] {
            let pool = SKShapeNode(ellipseOf: CGSize(width: rad, height: rad * 0.55))
            pool.fillColor = SKColor(red: 0.40, green: 0.70, blue: 0.85, alpha: 0.06)
            pool.strokeColor = .clear
            pool.position = CGPoint(x: w * CGFloat(x), y: h * CGFloat(y))
            pool.zPosition = -5
            add(pool, to: scene)
            JuiceEngine.pulse(pool, scale: 1.08)
        }

        // Statue d'ange veillant au fond : source des échos
        addPixelProp("angel_statue_1", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.80), scale: 1.6)

        // Piliers, colonnes brisées, rochers : la cavité fatiguée
        addPixelProp("pillar_grey_1", in: scene, at: CGPoint(x: w * 0.14, y: h * 0.70), scale: 1.8)
        addPixelProp("pillar_grey_2", in: scene, at: CGPoint(x: w * 0.86, y: h * 0.72), scale: 1.8)
        addPixelProp("column_broken_1", in: scene, at: CGPoint(x: w * 0.26, y: h * 0.82), scale: 1.9)
        addPixelProp("rock_3", in: scene, at: CGPoint(x: w * 0.70, y: h * 0.30), scale: 1.2)
        addPixelProp("rock_7", in: scene, at: CGPoint(x: w * 0.22, y: h * 0.34), scale: 1.1)
        addPixelProp("bones_1", in: scene, at: CGPoint(x: w * 0.38, y: h * 0.24), scale: 0.9)

        // Champignons luisants (leur halo froid est géré par attachPropLight)
        for (x, y) in [(0.16, 0.52), (0.84, 0.48), (0.60, 0.72), (0.34, 0.62)] {
            addPixelProp("mushroom_3", in: scene, at: CGPoint(x: w * CGFloat(x), y: h * CGFloat(y)),
                         scale: 0.8)
        }

        // Le gardien d'ossements est un RoamingMonster piloté par le
        // GameManager (spawnCaveRoamer) : il patrouille et charge Kael.

        // Coffre au trésor (visible une fois le gardien vaincu, si non pris)
        if cleared && !chestTaken {
            addCaveChest(in: scene, at: CGPoint(x: w * 0.50, y: h * 0.68))
        }

        // Halo de sortie (sud) — retour à la forêt
        let exit = SKShapeNode(circleOfRadius: 30)
        exit.fillColor = SKColor(red: 0.55, green: 0.70, blue: 0.95, alpha: 0.10)
        exit.strokeColor = SKColor(red: 0.55, green: 0.70, blue: 0.95, alpha: 0.22)
        exit.lineWidth = 1
        exit.position = CGPoint(x: w * 0.50, y: h * 0.08)
        exit.zPosition = -1
        add(exit, to: scene)
        JuiceEngine.pulse(exit, scale: 1.25)
        let exitLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        exitLabel.text = String(localized: "world.cave.exit")
        exitLabel.fontSize = 11
        exitLabel.fontColor = SKColor(white: 0.72, alpha: 0.7)
        exitLabel.position = CGPoint(x: w * 0.50, y: h * 0.02)
        exitLabel.zPosition = -1
        add(exitLabel, to: scene)

        addAtmosphere(ParticleFactory.ruinsAsh(in: scene.size), to: scene)
    }

    /// Coffre au trésor en pixels nets (grille dessinée, zéro coin arrondi) :
    /// caisse de bois, cerclages sombres, serrure d'or, faible lueur.
    func addCaveChest(in scene: SKScene, at pos: CGPoint) {
        addTreasureChest(named: "caveChest", at: pos, in: scene)
    }

    /// Coffre au trésor générique (caverne, carte du monde) : caisse de bois,
    /// cerclages sombres, serrure d'or, faible lueur d'appel.
    func addTreasureChest(named name: String, at pos: CGPoint,
                                  in scene: SKScene) {
        let chest = SKNode()
        chest.name = name
        chest.zPosition = actorLayer(for: pos.y)
        let wood = SKColor(red: 0.42, green: 0.28, blue: 0.14, alpha: 1)
        let dark = SKColor(red: 0.24, green: 0.15, blue: 0.07, alpha: 1)
        let gold = SKColor(red: 0.95, green: 0.78, blue: 0.30, alpha: 1)
        // Corps
        let body = SKSpriteNode(color: wood, size: CGSize(width: 40, height: 26))
        body.position = CGPoint(x: 0, y: 13)
        chest.addChild(body)
        // Couvercle
        let lid = SKSpriteNode(color: dark, size: CGSize(width: 44, height: 12))
        lid.position = CGPoint(x: 0, y: 30)
        chest.addChild(lid)
        // Cerclages verticaux
        for dx: CGFloat in [-13, 13] {
            let band = SKSpriteNode(color: dark, size: CGSize(width: 4, height: 26))
            band.position = CGPoint(x: dx, y: 13)
            chest.addChild(band)
        }
        // Serrure dorée
        let lock = SKSpriteNode(color: gold, size: CGSize(width: 8, height: 8))
        lock.position = CGPoint(x: 0, y: 20)
        chest.addChild(lock)
        addGroundShadow(under: chest, width: 40, height: 9)
        chest.position = pos
        add(chest, to: scene)
        // Faible lueur d'appel
        let light = LightingEngine.pointLight(radius: 40,
                                              color: LightingEngine.LightColor.flame)
        light.alpha = 0.3
        light.position = CGPoint(x: pos.x, y: pos.y + 18)
        add(light, to: scene)
    }

    /// Retire le coffre après ramassage.
    func removeCaveChest() {
        guard let chest = worldNode.childNode(withName: "caveChest") else { return }
        chest.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
    }
}
