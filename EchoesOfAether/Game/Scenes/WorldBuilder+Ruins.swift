import SpriteKit

// Ruines de la Source (Acte II).
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

    /// LE SEUIL (Acte III) — arène finale. Uniquement des assets existants :
    /// sol pierre teinté vide, escalier central (le Seuil), statues d'anges
    /// gardiens, piliers, arbres morts et ossements. Aucune forme custom.
    func buildThreshold(in scene: SKScene,
                                echoJoined: Bool = false,
                                spiritsCalmed: Set<String> = [],
                                shadesDefeated: Bool = false,
                                eranMet: Bool = false) {
        // Plan unique de la zone (décor, hit-tests, bulles, spawns le partagent).
        let plan = ThresholdLayout(sceneSize: scene.size)
        let w = plan.width
        let h = plan.height
        worldHeight = h   // couloir vertical : la caméra scrolle (cf. updateCamera)

        // Sol : pierre a2 teintée bleu-vide très sombre, sur tout le couloir
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.06, green: 0.05, blue: 0.12, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.16, green: 0.13, blue: 0.30, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Chemin dallé : le fil conducteur sud → nord. Il dit où aller sans
        // jamais l'écrire — les stèles, elles, sont hors du chemin.
        addPathStrip(in: scene,
                     rect: CGRect(x: w * 0.42, y: h * 0.02,
                                  width: w * 0.16, height: h * 0.90))
        // Embranchements vers les alcôves : l'allée bifurque vers chaque stèle.
        for stele in plan.steles {
            let onLeft = stele.pos.x < w * 0.5
            let x0 = onLeft ? stele.pos.x : w * 0.50
            let x1 = onLeft ? w * 0.50 : stele.pos.x
            addPathStrip(in: scene,
                         rect: CGRect(x: x0, y: stele.pos.y - h * 0.010,
                                      width: x1 - x0, height: h * 0.020))
        }

        // Titre de zone (à l'entrée, là où le joueur arrive)
        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.threshold.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.55, green: 0.45, blue: 0.85, alpha: 0.65)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.012)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // ── PAROIS : le couloir est creusé dans la roche ──
        // Tout ce qui n'est pas marchable est plein. Chaque bloc porte UNE
        // empreinte continue : aucun interstice, on ne traverse pas.
        for band in plan.corridorBands {
            let y = h * band.y0
            let height = h * (band.y1 - band.y0)
            addWall(in: scene, rect: CGRect(x: 0, y: y,
                                            width: w * band.left, height: height))
            addWall(in: scene, rect: CGRect(x: w * band.right, y: y,
                                            width: w * (1 - band.right), height: height))
        }

        // ── LE SEUIL : escalier + portail au bout du couloir ──
        addPixelProp("me_stairs", in: scene, at: plan.stairsBase, scale: 0.60)
        addPixelProp("gy_gate_big", in: scene, at: plan.portal, scale: 0.55)
        let voidGlow = SKShapeNode(circleOfRadius: 52)
        voidGlow.fillColor = SKColor(red: 0.30, green: 0.08, blue: 0.45, alpha: 0.10)
        voidGlow.strokeColor = SKColor(red: 0.55, green: 0.20, blue: 0.85, alpha: 0.30)
        voidGlow.lineWidth = 1.5
        voidGlow.glowWidth = 8
        voidGlow.position = CGPoint(x: plan.portal.x, y: plan.portal.y + h * 0.025)
        voidGlow.zPosition = -2
        add(voidGlow, to: scene)
        JuiceEngine.pulse(voidGlow, scale: 1.2)

        // Statues d'anges gardiens flanquant la dernière montée
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.36, y: h * 0.845), scale: 0.24)
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.64, y: h * 0.845), scale: 0.24, flipped: true)

        // Chandeliers : posés le long des parois, au bord du marchable. Ils
        // rythment la montée et rendent le couloir lisible dans le noir.
        // Leur x suit la bande — sinon ils finiraient noyés dans la roche.
        for fy in [CGFloat(0.09), 0.20, 0.30, 0.40, 0.55, 0.63, 0.80] {
            guard let band = plan.corridorBands.first(where: { fy >= $0.y0 && fy < $0.y1 })
            else { continue }
            let inset = (band.right - band.left) * 0.12
            addPixelProp("gy_candle", in: scene,
                         at: CGPoint(x: w * (band.left + inset), y: h * fy), scale: 0.55)
            addPixelProp("gy_candle", in: scene,
                         at: CGPoint(x: w * (band.right - inset), y: h * fy), scale: 0.55)
        }

        // Arche brisée juste avant le goulot : on voit le piège avant d'y entrer.
        addPixelProp("gy_gate_high", in: scene,
                     at: CGPoint(x: w * 0.50, y: h * 0.295), scale: 0.45)

        // Tombe adossée à chaque stèle (décalée : son empreinte ne doit pas
        // barrer l'accès à la stèle elle-même) + ossements au goulot.
        for (i, stele) in plan.steles.enumerated() {
            let asset = i == 1 ? "gy_tomb_grey_2" : "gy_tomb_black"
            let side: CGFloat = stele.pos.x < w * 0.5 ? 1 : -1
            addPixelProp(asset, in: scene,
                         at: CGPoint(x: stele.pos.x + side * 44, y: stele.pos.y + h * 0.018),
                         scale: 0.55)
        }
        for p in [(0.46, 0.345), (0.55, 0.325), (0.50, 0.36)] {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: 2.0,
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            bones.position = CGPoint(x: w * p.0, y: h * p.1)
            bones.zPosition = -2
            bones.alpha = 0.85
            add(bones, to: scene)
        }
        addPixelProp("gy_tree", in: scene,
                     at: CGPoint(x: w * 0.86, y: h * 0.135), scale: 0.50, flipped: true)

        // Eran Solace sur son palier — le Premier Gardien attend Kael.
        // Une fois recruté (eranMet), il vit comme compagnon (cf.
        // showEranCompanion) : re-poser son décor ici à chaque reconstruction
        // créait un second Eran, jamais masqué par showEranCompanion (déjà
        // passée, donc idempotente-silencieuse sur les appels suivants).
        if !eranMet {
            addEran(in: scene, at: plan.eran)
        }

        // ── L'Écho de Lyra attend juste après l'entrée ──
        if !echoJoined {
            addThresholdEcho(in: scene, at: plan.echoMeet)
        }

        // ── Esprits errants (quête « Les échos égarés ») ──
        // Ils déambulent seuls ; apaisés, ils disparaissent du Seuil.
        for def in plan.spirits where !spiritsCalmed.contains(def.id) {
            addWanderingSpirit(id: def.id, asset: def.asset, in: scene, at: def.pos)
        }

        // ── Ombres hostiles : échos corrompus qui refusent l'apaisement ──
        // Portées par des monstres baladeurs (cf. GameManager.spawnAct3Roamers),
        // embusquées au goulot : elles patrouillent et chargent Kael.

        // Cristal de sauvegarde, à l'entrée — dernier répit avant la montée.
        addSaveCrystal(at: plan.saveCrystal, in: scene)

        debugDrawObstacles(in: scene)   // --show-obstacles : audit des parois

        addAtmosphere(ParticleFactory.ruinsAsh(in: scene.size), to: scene)
        setZoneVignette(in: scene, alpha: 0.45)
        LightingEngine.applyGrade(.threshold, in: scene)
        AudioEngine.shared.setAmbience(.none)
    }

    /// LE CŒUR DU VIDE (Acte IV) — sanctuaire intérieur. Sol pierre teinté
    /// pourpre profond, Cœur central (orbe pulsé au sommet de l'escalier),
    /// fragments de mémoire, reflets absorbés, dévoreurs d'échos.
    func buildVoidHeart(in scene: SKScene,
                                reflectionsFreed: Set<String> = [],
                                devourersDefeated: Bool = false,
                                bossDefeated: Bool = false) {
        // Plan unique de la zone (décor, hit-tests, bulles, spawns).
        let plan = VoidHeartLayout(sceneSize: scene.size)
        let w = plan.width
        let h = plan.height
        worldHeight = h   // serpentin vertical : la caméra scrolle

        // Sol : pierre a2 teintée pourpre — plus profond que le Seuil
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.05, green: 0.02, blue: 0.09, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.22, green: 0.10, blue: 0.32, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Allée : la même pierre, éclaircie. Elle serpente de bande en bande.
        for band in plan.corridorBands {
            addPathStrip(in: scene, rect: CGRect(
                x: w * (band.left + (band.right - band.left) * 0.30),
                y: h * band.y0,
                width: w * (band.right - band.left) * 0.40,
                height: h * (band.y1 - band.y0)))
        }

        // ── PAROIS : le serpentin est creusé dans la roche ──
        for band in plan.corridorBands {
            let y = h * band.y0
            let height = h * (band.y1 - band.y0)
            addWall(in: scene, rect: CGRect(x: 0, y: y,
                                            width: w * band.left, height: height))
            addWall(in: scene, rect: CGRect(x: w * band.right, y: y,
                                            width: w * (1 - band.right), height: height))
        }

        // Titre de zone, à l'entrée
        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.voidheart.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.75, green: 0.45, blue: 0.90, alpha: 0.65)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.012)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // ── LE CŒUR : orbe géant au sommet de l'escalier final ──
        addPixelProp("me_stairs", in: scene, at: plan.stairsBase, scale: 0.60)
        let heart = SKShapeNode(circleOfRadius: bossDefeated ? 34 : 46)
        let heartColor: SKColor = bossDefeated
            ? SKColor(red: 0.40, green: 0.85, blue: 0.95, alpha: 1)   // apaisé : cyan
            : SKColor(red: 0.85, green: 0.25, blue: 0.95, alpha: 1)   // actif : pourpre
        heart.fillColor = heartColor.withAlphaComponent(0.16)
        heart.strokeColor = heartColor.withAlphaComponent(0.55)
        heart.lineWidth = 2
        heart.glowWidth = 10
        heart.name = "voidHeartCore"
        heart.position = plan.heart
        heart.zPosition = -2
        add(heart, to: scene)
        JuiceEngine.pulse(heart, scale: bossDefeated ? 1.06 : 1.25)

        // Statues d'anges renversées flanquant la descente finale
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.36, y: h * 0.815), scale: 0.24)
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.64, y: h * 0.815), scale: 0.24, flipped: true)

        // Fissures d'énergie remontant le serpentin vers le Cœur
        for fy in [CGFloat(0.30), 0.50, 0.68] {
            guard let band = plan.corridorBands.first(where: { fy >= $0.y0 && fy < $0.y1 })
            else { continue }
            add(makeCrack(from: CGPoint(x: w * (band.left + band.right) / 2, y: h * fy),
                          to: CGPoint(x: plan.heart.x, y: h * 0.76)), to: scene)
        }
        for m in plan.memories.prefix(2) {
            add(makeRedAetherPool(at: CGPoint(x: m.pos.x, y: m.pos.y - h * 0.03)), to: scene)
        }

        // ── Fragments de mémoire (quête « Les souvenirs de Kael ») ──
        // Une chandelle marque chaque recoin : toujours visible, l'état
        // « vu » ne gate que l'interaction.
        for m in plan.memories {
            addPixelProp("gy_candle", in: scene, at: m.pos, scale: 0.55)
        }

        // ── Reflets absorbés (quête « Les visages du Vide ») ──
        for def in plan.reflections where !reflectionsFreed.contains(def.id) {
            addWanderingSpirit(id: def.id, asset: def.asset, in: scene, at: def.pos)
        }

        // ── Dévoreurs d'échos : combat annexe ──
        // Monstres baladeurs (cf. GameManager.spawnAct4Roamers).

        // La confrontation de la Voix n'a pas de marqueur au sol : la Voix
        // n'a pas de corps. La bulle « A · Examiner » suffit à la signaler
        // quand Kael approche de l'escalier.

        // Cristal de sauvegarde au vestibule — dernier répit.
        addSaveCrystal(at: plan.saveCrystal, in: scene)

        addAtmosphere(ParticleFactory.ruinsAsh(in: scene.size), to: scene)
        setZoneVignette(in: scene, alpha: 0.50)
        LightingEngine.applyGrade(.voidheart, in: scene)
        AudioEngine.shared.setAmbience(.none)
        debugDrawObstacles(in: scene)   // --show-obstacles : audit des parois
    }

    /// L'Écho de Lyra, immobile et scintillant, attend Kael à l'entrée.
    func addThresholdEcho(in scene: SKScene, at pos: CGPoint) {
        guard let echo = PixelArtSprites.animated(
            name: "npc_lyra", frames: 6,
            scale: PixelArtSprites.scale(name: "npc_lyra_idle_1",
                                         height: PixelArtSprites.npcHeight),
            timePerFrame: 0.16, anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        echo.name = "thresholdEcho"
        echo.position = pos
        echo.zPosition = actorLayer(for: pos.y)
        echo.alpha = 0.72
        echo.forEachDescendantSprite { s in
            s.color = SKColor(red: 0.45, green: 0.90, blue: 0.95, alpha: 1)
            s.colorBlendFactor = 0.45
        }
        addGroundShadow(under: echo, width: 24, height: 7)
        add(echo, to: scene)
        JuiceEngine.float(echo, distance: 4)
    }

    /// Esprit errant : PNJ spectral translucide qui déambule seul
    /// (petites marches aléatoires autour de son point d'ancrage).
    func addWanderingSpirit(id: String, asset: String,
                                    in scene: SKScene, at anchor: CGPoint) {
        guard let spirit = PixelArtSprites.animated(
            name: asset, frames: 6,
            scale: PixelArtSprites.scale(name: "\(asset)_idle_1",
                                         height: PixelArtSprites.npcHeight),
            timePerFrame: 0.18, anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        spirit.name = "spirit_" + id
        spirit.position = anchor
        spirit.zPosition = actorLayer(for: anchor.y)
        spirit.alpha = 0.62
        spirit.forEachDescendantSprite { s in
            s.color = SKColor(red: 0.55, green: 0.70, blue: 0.95, alpha: 1)
            s.colorBlendFactor = 0.50
        }
        add(spirit, to: scene)

        // Déambulation : dérive lente vers un point proche, pause, retour.
        let wander = SKAction.repeatForever(.sequence([
            .run { [weak spirit] in
                guard let spirit else { return }
                let dest = CGPoint(x: anchor.x + .random(in: -46...46),
                                   y: anchor.y + .random(in: -26...26))
                let move = SKAction.move(to: dest, duration: .random(in: 2.4...4.0))
                move.timingMode = .easeInEaseOut
                spirit.run(move)
            },
            .wait(forDuration: 4.4)
        ]))
        spirit.run(wander)
        JuiceEngine.pulse(spirit, scale: 1.03)
    }

    /// Position monde d'un esprit errant encore présent (nil sinon).
    func spiritPosition(id: String) -> CGPoint? {
        worldNode.childNode(withName: "spirit_" + id)?.position
    }

    /// Retire un esprit apaisé avec une dissolution douce.
    func calmSpirit(id: String) {
        guard let spirit = worldNode.childNode(withName: "spirit_" + id) else { return }
        spirit.run(.sequence([
            .group([.fadeOut(withDuration: 0.8),
                    .moveBy(x: 0, y: 26, duration: 0.8)]),
            .removeFromParent()
        ]))
    }

    /// Position de l'Écho de Lyra à l'entrée (nil si déjà rejoint).
    var thresholdEchoPosition: CGPoint? {
        worldNode.childNode(withName: "thresholdEcho")?.position
    }

    /// L'écho de l'entrée disparaît (il rejoint le groupe).
    func removeThresholdEcho() {
        worldNode.childNode(withName: "thresholdEcho")?.run(.sequence([
            .fadeOut(withDuration: 0.6), .removeFromParent()
        ]))
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
