import SpriteKit

// Le Seuil (Acte III) : arène finale, Écho de Lyra, esprits errants.
extension WorldBuilder {
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
}
