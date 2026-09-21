import SpriteKit

// Ruines de la Source (Acte II) + fabricants de props partagés (fissures, inscriptions, mares).
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Ruines de la Source (Acte II)

    func buildRuins(in scene: SKScene) {
        // Plan unique de la zone (décor, hit-tests, bulles, spawns).
        let plan = RuinsLayout(sceneSize: scene.size)
        let w = plan.width
        let h = plan.height
        worldHeight = h   // enfilade de salles : la caméra scrolle

        // Sol : dalles de pierre teintées rouge-brun (la Source corrompue)
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.07, green: 0.04, blue: 0.04, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.30, green: 0.14, blue: 0.10, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Allée centrale : la même pierre, éclaircie — l'axe des salles.
        addPathStrip(in: scene, rect: CGRect(x: w * 0.44, y: h * 0.02,
                                             width: w * 0.12, height: h * 0.92))

        // ── PAROIS : les salles sont creusées dans la ruine ──
        for band in plan.corridorBands {
            let y = h * band.y0
            let height = h * (band.y1 - band.y0)
            addWall(in: scene, rect: CGRect(x: 0, y: y,
                                            width: w * band.left, height: height))
            addWall(in: scene, rect: CGRect(x: w * band.right, y: y,
                                            width: w * (1 - band.right), height: height))
        }

        // Fissures d'Aether rouge : elles rampent le long des salles.
        for (fy, fy2) in [(CGFloat(0.10), CGFloat(0.18)), (0.42, 0.52), (0.66, 0.74)] {
            guard let b = plan.corridorBands.first(where: { fy >= $0.y0 && fy < $0.y1 })
            else { continue }
            add(makeCrack(from: CGPoint(x: w * (b.left + 0.06), y: h * fy),
                          to: CGPoint(x: w * 0.50, y: h * fy2)), to: scene)
        }

        // ── VESTIGES : la chapelle effondrée ferme le fond des archives ──
        addPixelProp("house_ruins_1", in: scene,
                     at: CGPoint(x: w * 0.50, y: h * 0.955), scale: 0.62)
        addPixelProp("gy_gate_high", in: scene,
                     at: CGPoint(x: w * 0.50, y: h * 0.335), scale: 0.48)   // le goulot gardé
        addPixelProp("gy_tree", in: scene,
                     at: CGPoint(x: w * 0.80, y: h * 0.145), scale: 0.52, flipped: true)

        // ── CIMETIÈRE PROFANÉ : tombes et croix, contre les parois des salles ──
        // Chaque relique se cale sur sa bande : posées en dur, elles
        // finissaient dans la roche.
        let relics: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("gy_grave_wood", 0.16, 0.10, 0.55), ("gy_cross_wood", 0.82, 0.13, 0.55),
            ("gy_tomb_brown", 0.20, 0.44, 0.55), ("gy_grave_wood", 0.80, 0.48, 0.50),
            ("gy_cross_wood", 0.24, 0.54, 0.55), ("gy_tomb_brown", 0.78, 0.70, 0.55),
            ("gy_candle_off", 0.22, 0.66, 0.50), ("gy_candle_off", 0.78, 0.66, 0.50),
            ("gy_stone_1", 0.30, 0.42, 0.50), ("gy_stone_3", 0.70, 0.44, 0.50)
        ]
        for (asset, x, y, s) in relics {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
        }

        // Ossements au goulot — c'est là que les Gardiens ont fait le ménage.
        for p in [(0.46, 0.325), (0.54, 0.345), (0.50, 0.36)] {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: 2.0,
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            bones.position = CGPoint(x: w * p.0, y: h * p.1)
            bones.zPosition = -2
            bones.alpha = 0.9
            add(bones, to: scene)
        }

        // Titre de zone, à l'entrée
        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.ruins.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.70, green: 0.25, blue: 0.25, alpha: 0.60)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.015)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // Les combats des Ruines sont portés par des monstres baladeurs
        // (cf. GameManager.spawnRuinsRoamers) : ils patrouillent et chargent
        // Kael. Plus de halo ni de crâne flottant à taper.

        // Inscription d'Eran : dans le renfoncement, hors du trajet.
        add(makeEranInscription(at: plan.eranInscription), to: scene)

        // Mur d'inscription (discovery) : au fond des archives.
        add(makeInscriptionWall(at: plan.discoveryWall), to: scene)

        // Mares d'Aether rouge (ambiance), au centre des salles.
        for fy in [CGFloat(0.12), 0.48, 0.70] {
            guard let b = plan.corridorBands.first(where: { fy >= $0.y0 && fy < $0.y1 })
            else { continue }
            add(makeRedAetherPool(at: CGPoint(x: w * (b.left + b.right) / 2 + 40,
                                              y: h * fy)), to: scene)
        }

        // Cristal de sauvegarde, dans le hall d'entrée.
        addSaveCrystal(at: plan.saveCrystal, in: scene)

        addAtmosphere(ParticleFactory.ruinsAsh(in: scene.size), to: scene)
        setZoneVignette(in: scene, alpha: 0.45)
        LightingEngine.applyGrade(.ruins, in: scene)
        AudioEngine.shared.setAmbience(.none)   // la musique porte l'ambiance
        debugDrawObstacles(in: scene)   // --show-obstacles : audit des parois
    }


    func makeCrack(from start: CGPoint, to end: CGPoint) -> SKNode {
        let crack = SKNode()
        crack.zPosition = -8

        let path = CGMutablePath()
        path.move(to: start)
        let midX = (start.x + end.x) / 2 + CGFloat.random(in: -10...10)
        let midY = (start.y + end.y) / 2 + CGFloat.random(in: -8...8)
        path.addLine(to: CGPoint(x: midX, y: midY))
        path.addLine(to: end)

        let line = SKShapeNode(path: path)
        line.strokeColor = SKColor(red: 0.70, green: 0.15, blue: 0.10, alpha: 0.45)
        line.lineWidth = 1.5
        line.glowWidth = 2
        crack.addChild(line)

        let glowLine = SKShapeNode(path: path)
        glowLine.strokeColor = SKColor(red: 0.90, green: 0.25, blue: 0.15, alpha: 0.08)
        glowLine.lineWidth = 5
        crack.addChild(glowLine)

        return crack
    }

    func makeInscriptionWall(at pos: CGPoint) -> SKNode {
        let wall = SKNode()
        wall.position = pos
        wall.zPosition = depthLayer(for: pos.y)

        let stone = SKShapeNode(rectOf: CGSize(width: 72, height: 55), cornerRadius: 5)
        stone.fillColor = SKColor(red: 0.14, green: 0.08, blue: 0.10, alpha: 1)
        stone.strokeColor = SKColor(red: 0.60, green: 0.20, blue: 0.18, alpha: 0.7)
        stone.lineWidth = 2
        wall.addChild(stone)

        let glow = SKShapeNode(rectOf: CGSize(width: 80, height: 63), cornerRadius: 8)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.80, green: 0.25, blue: 0.15, alpha: 0.12)
        glow.lineWidth = 4
        wall.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.08)

        let runeLines: [(CGFloat, CGFloat, CGFloat)] = [(-16, 14, 32), (0, 2, 40), (0, -10, 28), (0, -22, 36)]
        for (x, y, width) in runeLines {
            let rune = SKShapeNode(rectOf: CGSize(width: width, height: 2), cornerRadius: 1)
            rune.fillColor = SKColor(red: 0.70, green: 0.20, blue: 0.15, alpha: 0.6)
            rune.strokeColor = .clear
            rune.position = CGPoint(x: x, y: y)
            wall.addChild(rune)
        }

        let labelNode = SKLabelNode(fontNamed: PixelUI.uiFont)
        labelNode.text = String(localized: "world.ruins.inscription")
        labelNode.fontSize = 12
        labelNode.fontColor = SKColor(red: 0.70, green: 0.30, blue: 0.25, alpha: 0.70)
        labelNode.position = CGPoint(x: 0, y: -38)
        wall.addChild(labelNode)
        JuiceEngine.float(labelNode, distance: 3)

        return wall
    }

    func makeEranInscription(at pos: CGPoint) -> SKNode {
        let wall = SKNode()
        wall.position = pos
        wall.zPosition = depthLayer(for: pos.y)

        // Pierre plus petite, style griffonné
        let stone = SKShapeNode(rectOf: CGSize(width: 44, height: 34), cornerRadius: 3)
        stone.fillColor = SKColor(red: 0.10, green: 0.06, blue: 0.08, alpha: 1)
        stone.strokeColor = SKColor(red: 0.35, green: 0.55, blue: 0.80, alpha: 0.5)
        stone.lineWidth = 1.5
        wall.addChild(stone)

        let glow = SKShapeNode(rectOf: CGSize(width: 52, height: 42), cornerRadius: 6)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.40, green: 0.60, blue: 0.90, alpha: 0.08)
        glow.lineWidth = 3
        wall.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.12)

        // Lignes griffonnées (style main, irrégulières)
        let lineData: [(CGFloat, CGFloat, CGFloat)] = [(-8, 10, 22), (0, 2, 30), (0, -6, 18)]
        for (x, y, w2) in lineData {
            let line = SKShapeNode(rectOf: CGSize(width: w2, height: 1.5), cornerRadius: 0.5)
            line.fillColor = SKColor(red: 0.45, green: 0.65, blue: 0.90, alpha: 0.5)
            line.strokeColor = .clear
            line.position = CGPoint(x: x, y: y)
            wall.addChild(line)
        }

        let labelNode = SKLabelNode(fontNamed: PixelUI.uiFont)
        labelNode.text = String(localized: "world.ruins.eranInscription")
        labelNode.fontSize = 11
        labelNode.fontColor = SKColor(red: 0.50, green: 0.68, blue: 0.90, alpha: 0.70)
        labelNode.position = CGPoint(x: 0, y: -26)
        wall.addChild(labelNode)
        JuiceEngine.float(labelNode, distance: 2)

        return wall
    }

    func makeRedAetherPool(at pos: CGPoint) -> SKNode {
        let pool = SKNode()
        pool.position = pos
        pool.zPosition = -6

        let water = SKShapeNode(circleOfRadius: 10)
        water.fillColor = SKColor(red: 0.15, green: 0.02, blue: 0.05, alpha: 0.9)
        water.strokeColor = SKColor(red: 0.60, green: 0.15, blue: 0.10, alpha: 0.4)
        water.lineWidth = 1
        pool.addChild(water)

        let glow = SKShapeNode(circleOfRadius: 16)
        glow.fillColor = SKColor(red: 0.50, green: 0.08, blue: 0.05, alpha: 0.06)
        glow.strokeColor = .clear
        pool.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.5)

        return pool
    }
}
