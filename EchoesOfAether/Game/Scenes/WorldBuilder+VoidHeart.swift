import SpriteKit

// Le Cœur du Vide (Acte IV) : sanctuaire intérieur, reflets, dévoreurs d'échos.
extension WorldBuilder {
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
}
