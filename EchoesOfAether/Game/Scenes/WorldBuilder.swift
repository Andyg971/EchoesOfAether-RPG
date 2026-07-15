import SpriteKit

@MainActor
final class WorldBuilder {
    // Personnages principaux
    let kael: SKNode
    let lyra: SKNode
    let dorin: SKNode
    // PNJ village
    let bram: SKNode
    let mara: SKNode
    let garen: SKNode
    let sage: SKNode
    let child: SKNode
    let villager: SKNode

    let worldNode = SKNode()
    private(set) var worldHeight: CGFloat = 0
    /// Empreintes au sol infranchissables (maisons, arbres, props solides).
    /// En coordonnées monde ; vidées à chaque changement de zone.
    private(set) var obstacles: [CGRect] = []
    private var backdropNodes: [SKNode] = []
    private var atmosphereNode: SKNode?
    private var toyMarker: SKNode?
    private var medallionMarker: SKNode?
    private var oreMarker: SKNode?
    private var herbMarker: SKNode?
    private var badgeMarker: SKNode?
    private var activeInterior: HouseInteriorKind?
    /// Vrai pendant la veille du réveil : Lyra reste au chevet de Kael
    /// même si `layout()` est rejoué (rotation, resize, premier layout).
    private var lyraKeepsVigil = false

    init() {
        kael    = WorldNode.kael()
        lyra    = WorldNode.lyra()
        dorin   = WorldNode.dorin()
        bram    = WorldNode.bram()
        mara    = WorldNode.mara()
        garen   = WorldNode.garen()
        sage    = WorldNode.sage()
        child   = WorldNode.child()
        villager = WorldNode.scaredVillager()
    }

    func build(in scene: SKScene) {
        worldNode.name = "worldNode"
        scene.addChild(worldNode)
        buildVillage(in: scene)
        for node in [kael, lyra, dorin, bram, mara, garen, sage, child, villager] {
            worldNode.addChild(node)
        }
        layout(in: scene.size)
    }

    // MARK: - Collisions

    /// Le point (pieds de Kael) est-il dans une empreinte solide ?
    func isBlocked(_ p: CGPoint) -> Bool {
        obstacles.contains { $0.contains(p) }
    }

    /// Avance de `a` vers `b` et s'arrête juste avant le premier obstacle
    /// (échantillonnage tous les 6 pt). Retourne la destination atteignable.
    func clampDestination(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let dist = a.distance(to: b)
        guard dist > 1 else { return b }
        let steps = max(1, Int(dist / 6))
        var last = a
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: a.x + (b.x - a.x) * t,
                            y: a.y + (b.y - a.y) * t)
            if isBlocked(p) { return last }
            last = p
        }
        return b
    }

    private func registerObstacle(_ rect: CGRect) {
        obstacles.append(rect)
    }

    /// Audit visuel : --show-obstacles dessine les empreintes en rouge.
    func debugDrawObstacles(in scene: SKScene) {
        guard CommandLine.arguments.contains("--show-obstacles") else { return }
        for rect in obstacles {
            let box = SKShapeNode(rect: rect)
            box.fillColor = SKColor(red: 1, green: 0, blue: 0, alpha: 0.30)
            box.strokeColor = SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.9)
            box.lineWidth = 1
            box.zPosition = 500
            add(box, to: scene)
        }
    }

    /// Empreinte au sol d'un node ancré aux pieds (anchor 0.5/0) : bande
    /// horizontale à la base — on peut passer « derrière » (au nord),
    /// jamais au travers.
    private func registerFootprint(of node: SKNode,
                                   widthRatio: CGFloat = 0.78,
                                   depthRatio: CGFloat = 0.45,
                                   maxDepth: CGFloat = 34) {
        let f = node.calculateAccumulatedFrame()
        let w = f.width * widthRatio
        guard w > 4 else { return }
        let d = min(f.height * depthRatio, maxDepth)
        registerObstacle(CGRect(x: node.position.x - w / 2,
                                y: node.position.y - 4,
                                width: w, height: max(10, d)))
    }

    func layout(in size: CGSize) {
        let w = size.width
        let wh = worldHeight > 0 ? worldHeight : size.height

        // NPC sur chemin/devant leur lieu de vie selon le plan du village.
        if lyraKeepsVigil {
            placeLyraBesideKael(in: size)                      // réveil : au chevet
        } else {
            lyra.position = CGPoint(x: w * 0.40, y: wh * 0.43) // place, côté marché
        }
        dorin.position   = CGPoint(x: w * 0.56, y: wh * 0.88)  // approche porte nord
        bram.position    = CGPoint(x: w * 0.46, y: wh * 0.60)  // devant l'armurerie
        mara.position    = CGPoint(x: w * 0.27, y: wh * 0.555) // devant l'herboriste
        sage.position    = CGPoint(x: w * 0.73, y: wh * 0.555) // devant l'auberge
        garen.position   = CGPoint(x: w * 0.50, y: wh * 0.925) // porte nord (sentinelle)
        child.position   = CGPoint(x: w * 0.45, y: wh * 0.375) // joue près de la fontaine
        villager.position = CGPoint(x: w * 0.57, y: wh * 0.415) // place centrale
        kael.position    = CGPoint(x: w * 0.485, y: wh * 0.10) // spawn devant sa maison

        [lyra, dorin, bram, mara, sage, garen, child, villager, kael].forEach {
            $0.zPosition = actorLayer(for: $0.position.y)
        }
    }

    /// Réveil (phase wake) : Lyra veille au chevet de Kael devant sa
    /// maison, au lieu d'attendre à son poste de la place centrale.
    func placeLyraBesideKael(in size: CGSize) {
        lyraKeepsVigil = true
        let wh = worldHeight > 0 ? worldHeight : size.height
        lyra.position = CGPoint(x: size.width * 0.44, y: wh * 0.105)
        lyra.zPosition = actorLayer(for: lyra.position.y)
    }

    /// Fin de la veille : Lyra reprend son poste au prochain `layout()`.
    func endLyraVigil() {
        lyraKeepsVigil = false
    }

    // MARK: - Lyra compagne (forêt, sanctuaire, ruines)

    /// Fait apparaître Lyra aux côtés de Kael (elle l'accompagne dans
    /// les zones du pacte — le scénario la met à ses côtés).
    func showLyraCompanion() {
        lyra.isHidden = false
        lyra.position = CGPoint(x: kael.position.x - 46, y: kael.position.y - 8)
        lyra.zPosition = actorLayer(for: lyra.position.y)
    }

    /// Suivi doux : Lyra marche derrière Kael quand il s'éloigne.
    func updateLyraFollow(deltaTime: TimeInterval) {
        guard !lyra.isHidden, deltaTime > 0 else { return }
        let target = CGPoint(x: kael.position.x - 40, y: kael.position.y - 6)
        let dx = target.x - lyra.position.x
        let dy = target.y - lyra.position.y
        let dist = (dx * dx + dy * dy).squareRoot()
        guard dist > 54 else { return }
        let step = min(CGFloat(deltaTime) * 240, dist - 44)
        lyra.position.x += dx / dist * step
        lyra.position.y += dy / dist * step
        lyra.zPosition = actorLayer(for: lyra.position.y)
    }

    /// Recalcule la profondeur de Kael (déplacement continu au pad).
    func refreshKaelDepth() {
        kael.zPosition = actorLayer(for: kael.position.y)
    }

    // MARK: - PNJ errants (village)

    /// Vrai si on est à l'intérieur d'une maison.
    var isInsideInterior: Bool { activeInterior != nil }

    /// Lance la promenade libre des PNJ du village : chacun flâne autour
    /// de son poste (large rayon), en évitant maisons et obstacles.
    /// Garen (sentinelle) fait les cent pas près de la porte nord.
    /// Idempotent : ne relance pas un PNJ déjà en promenade.
    func startVillageWander(in size: CGSize) {
        var walkers: [(SKNode, CGFloat)] = [
            (dorin, 220), (bram, 200), (mara, 200), (sage, 200),
            (child, 240), (villager, 240), (garen, 46)
        ]
        if !lyraKeepsVigil { walkers.append((lyra, 220)) }
        for (npc, radius) in walkers where npc.action(forKey: "wander") == nil {
            scheduleWander(npc, home: npc.position, radius: radius, sceneWidth: size.width)
        }
    }

    /// Stoppe toute promenade (dialogue, combat, intérieur, cinématique).
    func stopVillageWander() {
        for npc in [lyra, dorin, bram, mara, sage, garen, child, villager] {
            npc.removeAction(forKey: "wander")
        }
    }

    /// Un pas de promenade : pause aléatoire, puis marche lente vers un
    /// point libre autour du poste d'origine — et on recommence.
    private func scheduleWander(_ npc: SKNode, home: CGPoint,
                                radius: CGFloat, sceneWidth: CGFloat) {
        let wh = worldHeight > 0 ? worldHeight : 402
        let target = CGPoint(
            x: min(max(home.x + .random(in: -radius...radius), 40), sceneWidth - 40),
            y: min(max(home.y + .random(in: -radius...radius), 72), wh - 52))
        let dest = clampDestination(from: npc.position, to: target)
        let dist = npc.position.distance(to: dest)

        var steps: [SKAction] = [.wait(forDuration: .random(in: 0.8...3.6))]
        if dist > 14, !isBlocked(dest) {
            let facing: CGFloat = dest.x < npc.position.x ? -1 : 1
            steps.append(.run { [weak npc] in
                npc?.forEachDescendantSprite { $0.xScale = facing * abs($0.xScale) }
            })
            let duration = TimeInterval(dist / 46)   // flânerie lente
            steps.append(.group([
                .move(to: dest, duration: duration),
                .customAction(withDuration: duration) { [weak self] node, _ in
                    guard let self else { return }
                    node.zPosition = self.actorLayer(for: node.position.y)
                }
            ]))
        }
        steps.append(.run { [weak self, weak npc] in
            guard let self, let npc, !npc.isHidden else { return }
            self.scheduleWander(npc, home: home, radius: radius, sceneWidth: sceneWidth)
        })
        npc.run(.sequence(steps), withKey: "wander")
    }

    // MARK: - Camera

    /// Vrai jusqu'au premier `updateCamera` d'une zone : la caméra se cale
    /// d'un coup sur Kael (pas de glissement disgracieux au spawn).
    private var snapCameraNextFrame = true

    /// Demande un recadrage instantané (changement de zone / téléportation).
    func snapCamera() { snapCameraNextFrame = true }

    func updateCamera(in sceneSize: CGSize) {
        guard worldHeight > sceneSize.height else { return }
        let targetY = kael.position.y
        let maxY = worldHeight - sceneSize.height
        let clamped = min(max(targetY - sceneSize.height / 2, 0), maxY)
        let goal = -clamped
        if snapCameraNextFrame {
            worldNode.position.y = goal
            snapCameraNextFrame = false
        } else {
            // Suivi lissé : la caméra rattrape Kael en douceur (cinématique),
            // au lieu de coller image par image.
            worldNode.position.y += (goal - worldNode.position.y) * 0.18
        }
    }

    // MARK: - Zone Backgrounds

    func switchToForest(in scene: SKScene) {
        clearBackdrop()
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.06, blue: 0.04, alpha: 1)
        buildForest(in: scene)   // définit worldHeight (trek scrollable)
    }

    func switchToShrine(in scene: SKScene) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.02, blue: 0.07, alpha: 1)
        buildShrine(in: scene)
    }

    func switchToVillage(in scene: SKScene) {
        clearBackdrop()
        worldNode.position = .zero
        scene.backgroundColor = SKColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1)
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = false }
        buildVillage(in: scene)
    }

    func switchToRuins(in scene: SKScene) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.04, green: 0.02, blue: 0.03, alpha: 1)
        buildRuins(in: scene)
    }

    /// Acte III — Le Seuil. Royaume du Vide où Kael franchit la frontière.
    /// Décor 100% assets existants (statues, piliers, escalier, arbres morts).
    func switchToThreshold(in scene: SKScene,
                           echoJoined: Bool = false,
                           spiritsCalmed: Set<String> = [],
                           shadesDefeated: Bool = false) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.02, blue: 0.08, alpha: 1)
        buildThreshold(in: scene, echoJoined: echoJoined,
                       spiritsCalmed: spiritsCalmed,
                       shadesDefeated: shadesDefeated)
        if echoJoined { showLyraEcho(in: scene) }
    }

    /// Acte IV — Le Cœur du Vide. Au-delà du Seuil : la source des échos.
    /// Décor 100% assets existants (mêmes règles que le Seuil).
    func switchToVoidHeart(in scene: SKScene,
                           echoJoined: Bool = false,
                           reflectionsFreed: Set<String> = [],
                           devourersDefeated: Bool = false,
                           bossDefeated: Bool = false) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.04, green: 0.01, blue: 0.07, alpha: 1)
        buildVoidHeart(in: scene, reflectionsFreed: reflectionsFreed,
                       devourersDefeated: devourersDefeated,
                       bossDefeated: bossDefeated)
        if echoJoined { showLyraEcho(in: scene) }
    }

    /// L'Écho de Lyra accompagne Kael au Seuil : le node Lyra existant,
    /// teinté cyan spectral et translucide (le follow est réutilisé).
    func showLyraEcho(in scene: SKScene) {
        lyra.isHidden = false
        lyra.alpha = 0.72
        lyra.position = CGPoint(x: kael.position.x - 44, y: kael.position.y)
        lyra.forEachDescendantSprite { s in
            s.color = SKColor(red: 0.45, green: 0.90, blue: 0.95, alpha: 1)
            s.colorBlendFactor = 0.45
        }
    }

    // MARK: - Village Solis

    /// VILLAGE SOLIS — vrai plan de village (assets Modern Exteriors).
    /// Monde vertical scrollable (worldHeight = 4.2× écran paysage),
    /// maisons à l'échelle des personnages, chemins de terre autotilés
    /// (transitions herbe/terre), étang avec berges, cours clôturées.
    ///   y=0-7%    ENTRÉE SUD (portail, panneau, allée)
    ///   y=7-25%   RÉSIDENTIEL (maison de Kael + 2 maisons + ferme est)
    ///   y=32-48%  PLACE CENTRALE (fontaine, marché, bancs) + ÉTANG ouest
    ///   y=52-77%  COMMERCES (herboriste, armurerie, auberge)
    ///   y=77-92%  QUARTIER HAUT (chalet du maire, villas)
    ///   y=92-100% PORTE NORD (sortie forêt)
    private func buildVillage(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height * 4.2
        worldHeight = h

        // ── SOL : variantes d'herbe ME (palette assortie aux transitions).
        // Les variantes "détail" sont dupliquées avec parcimonie pour un
        // sol vivant mais pas chargé.
        addTiledFloor(in: scene,
                      tileNames: ["me_grassvar_1", "me_grassvar_1", "me_grassvar_1",
                                  "me_grassvar_5", "me_grassvar_5",
                                  "me_grassvar_2", "me_grassvar_3", "me_grassvar_4"],
                      fallbackColor: SKColor(red: 0.36, green: 0.58, blue: 0.30, alpha: 1),
                      tileScale: 0.5,
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // ── RÉSEAU DE CHEMINS : terre battue autotilée ──
        var paths = VillageTileMap(width: w, height: h, tile: 24)
        // Allée principale sud → porte nord
        paths.stamp(rect: CGRect(x: w * 0.5 - 24, y: 0, width: 48, height: h * 0.945))
        // Place centrale en terre battue (ovale autour de la fontaine)
        paths.stampEllipse(center: CGPoint(x: w * 0.50, y: h * 0.40),
                           radiusX: w * 0.17, radiusY: h * 0.050)
        // Parvis du portail sud (évasement de l'allée à l'entrée)
        paths.stamp(rect: CGRect(x: w * 0.5 - 60, y: 0, width: 120, height: h * 0.035))
        // Branches : un sentier par porte de maison
        for branch in Self.villageBranches {
            let bx = w * branch.x
            let by = h * branch.y
            let x0 = min(bx, w * 0.5 - 12)
            let x1 = max(bx, w * 0.5 + 12)
            paths.stamp(rect: CGRect(x: x0, y: by - 4, width: x1 - x0, height: 30))
        }
        renderTileMap(paths, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -9.6)

        // ── ÉTANG OUEST : eau + berges autotilées ──
        var pond = VillageTileMap(width: w, height: h, tile: 24)
        pond.stampEllipse(center: CGPoint(x: w * 0.085, y: h * 0.46),
                          radiusX: w * 0.058, radiusY: h * 0.027)
        renderTileMap(pond, fullTile: "me_water_full", edgePrefix: "me_shore_",
                      in: scene, z: -9.5)
        // L'eau ne se marche pas.
        registerObstacle(CGRect(x: w * 0.085 - w * 0.052, y: h * 0.46 - h * 0.024,
                                width: w * 0.104, height: h * 0.048))
        // Eau vivante : scintillements + nappe qui respire
        add(LightingEngine.waterShimmer(center: CGPoint(x: w * 0.085, y: h * 0.46),
                                        radiusX: w * 0.058, radiusY: h * 0.027),
            to: scene)

        decorateVillage(in: scene)

        // ═══════════ MAISONS (échelle perso : porte ≈ taille de Kael) ═══════════
        buildNorthGate(at: CGPoint(x: w * 0.50, y: h * 0.96), width: 90, in: scene)

        // Résidentiel sud — la maison de Kael en premier plan
        addVillageBuilding(asset: "village_house_onestory", scale: 0.28,
                            fallbackW: 62, fallbackH: 50,
                            wallColor: SKColor(red: 0.18, green: 0.16, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.35, green: 0.28, blue: 0.18, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.32, y: h * 0.075), in: scene)
        addVillageBuilding(asset: "village_house_country", scale: 0.30,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.14, y: h * 0.16), in: scene)
        addVillageBuilding(asset: "village_house_modern", scale: 0.26,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1),
                            roofColor: SKColor(red: 0.30, green: 0.30, blue: 0.40, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.80, y: h * 0.16), in: scene)

        // Commerces — portes alignées sur houseDoorPosition (NE PAS déplacer)
        addVillageBuilding(asset: "village_house_japanese", scale: 0.30,
                            fallbackW: 62, fallbackH: 50,
                            wallColor: SKColor(red: 0.14, green: 0.22, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.22, green: 0.40, blue: 0.22, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.22, y: h * 0.58), in: scene)
        addVillageBuilding(asset: "village_house_armory", scale: 0.32,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.50, y: h * 0.63), in: scene)
        addVillageBuilding(asset: "village_house_inn", scale: 0.32,
                            fallbackW: 88, fallbackH: 62,
                            wallColor: SKColor(red: 0.20, green: 0.14, blue: 0.10, alpha: 1),
                            roofColor: SKColor(red: 0.45, green: 0.25, blue: 0.12, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.78, y: h * 0.58), in: scene)

        // Quartier haut — villas autour d'un parc civique
        addVillageBuilding(asset: "village_house_victorian", scale: 0.24,
                            fallbackW: 70, fallbackH: 55,
                            wallColor: SKColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1),
                            roofColor: SKColor(red: 0.30, green: 0.50, blue: 0.35, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.17, y: h * 0.78), in: scene)
        addVillageBuilding(asset: "village_house_country", scale: 0.26,
                            fallbackW: 76, fallbackH: 58,
                            wallColor: SKColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1),
                            roofColor: SKColor(red: 0.40, green: 0.32, blue: 0.15, alpha: 1),
                            label: nil, at: CGPoint(x: w * 0.82, y: h * 0.78), in: scene)

        // Crystal save proche auberge (UX : safe spot évident)
        addSaveCrystal(at: CGPoint(x: w * 0.88, y: h * 0.52), in: scene)

        // Village vivant : fumées de cheminée sur les maisons habitées
        for (x, y, dy) in [(0.78, 0.58, 84.0), (0.50, 0.63, 82.0),
                           (0.22, 0.58, 74.0), (0.17, 0.78, 64.0)] {
            let smoke = ParticleFactory.chimneySmoke()
            smoke.position = CGPoint(x: w * CGFloat(x) + 14, y: h * CGFloat(y) + CGFloat(dy))
            add(smoke, to: scene)
        }

        // Village vivant : les PNJ « ambiance » respirent, jettent des
        // coups d'œil et font quelques pas. On épargne Lyra (scripts de
        // veille), Dorin et Garen (sentinelles + zones de tap sensibles).
        AmbientLife.enliven(bram)
        AmbientLife.enliven(mara)
        AmbientLife.enliven(sage)
        AmbientLife.enliven(villager)
        AmbientLife.enliven(child, wanderRadius: 22)   // l'enfant gambade

        // Poussière ambiante + papillons + oiseaux qui traversent le ciel
        let ambiance = SKNode()
        ambiance.addChild(ParticleFactory.ambientDust(in: CGSize(width: w, height: h)))
        ambiance.addChild(ParticleFactory.butterflies(in: CGSize(width: w, height: h)))
        ambiance.addChild(AmbientLife.birds(in: CGSize(width: w, height: h)))
        let raining = rollWeatherRain(in: scene)
        if !raining {   // ciel dégagé : les nuages projettent leur ombre
            ambiance.addChild(LightingEngine.cloudShadows(in: CGSize(width: w, height: h)))
        }
        addAtmosphere(ambiance, to: scene)
        setZoneVignette(in: scene, alpha: 0)
        if raining {
            LightingEngine.applyGrade(.rainy, in: scene)
        } else {
            LightingEngine.applyGrade(.villageDay, in: scene)
            LightingEngine.startDayCycle(in: scene, day: .villageDay)
        }
        AudioEngine.shared.setAmbience(.village)
        debugDrawObstacles(in: scene)
    }

    /// Portes desservies par un sentier branché sur l'allée centrale
    /// (fractions de w/h — alignées sur les pieds de maisons).
    private static let villageBranches: [(x: CGFloat, y: CGFloat)] = [
        (0.32, 0.075),   // maison de Kael
        (0.14, 0.16),    // maison country sud
        (0.80, 0.16),    // maison moderne
        (0.22, 0.58),    // herboriste
        (0.78, 0.58),    // auberge
        (0.88, 0.52),    // crystal de sauvegarde
        (0.17, 0.78),    // villa victorienne
        (0.82, 0.78)     // maison haute est
    ]

    // MARK: - Forêt d'Ébène

    /// FORÊT D'ÉBÈNE — trek vertical sud→nord (worldHeight = 2.8× écran).
    /// Sentier sinueux autotilé reliant 4 clairières :
    ///   y≈0.31  BOSQUET CORROMPU (combat 1, ouest)
    ///   y≈0.52  CAMPEMENT (feu + cristal de sauvegarde, centre)
    ///   y≈0.66  CLAIRIÈRE SOMBRE (combat 2, est)
    ///   y≈0.90  SEUIL DU SANCTUAIRE (sortie nord)
    /// POI synchronisés avec GameManager.tryForestInteraction (worldHeight).
    private func buildForest(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height * 2.8
        worldHeight = h

        // ── SOL : herbe ME noyée d'ombre (palette assortie aux transitions) ──
        let forestShade = SKColor(red: 0.05, green: 0.13, blue: 0.08, alpha: 1)
        let forestBase = SKShapeNode(rectOf: CGSize(width: w + 96, height: h + 96))
        forestBase.fillColor = SKColor(red: 0.05, green: 0.12, blue: 0.07, alpha: 1)
        forestBase.strokeColor = .clear
        forestBase.position = CGPoint(x: (w + 96) / 2 - 48, y: (h + 96) / 2 - 48)
        forestBase.zPosition = -11
        add(forestBase, to: scene)

        addTiledFloor(in: scene,
                      tileNames: ["me_grassvar_1", "me_grassvar_1", "me_grassvar_5",
                                  "me_grassvar_2", "me_grassvar_3", "me_grassvar_4"],
                      fallbackColor: SKColor(red: 0.05, green: 0.12, blue: 0.07, alpha: 1),
                      tileScale: 0.5,
                      tint: forestShade,
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // ── SENTIER SINUEUX + CLAIRIÈRES (autotile assombri) ──
        var trail = VillageTileMap(width: w, height: h, tile: 24)
        // Entrée sud → premier virage
        trail.stamp(rect: CGRect(x: w * 0.50 - 24, y: 0, width: 48, height: h * 0.155))
        // Virage ouest vers le bosquet
        trail.stamp(rect: CGRect(x: w * 0.27, y: h * 0.12, width: w * 0.26, height: 44))
        trail.stamp(rect: CGRect(x: w * 0.27, y: h * 0.12, width: 48, height: h * 0.30))
        trail.stampEllipse(center: CGPoint(x: w * 0.30, y: h * 0.31),
                           radiusX: w * 0.13, radiusY: h * 0.045)
        // Vers le campement central
        trail.stamp(rect: CGRect(x: w * 0.27, y: h * 0.40, width: w * 0.25, height: 44))
        trail.stamp(rect: CGRect(x: w * 0.49, y: h * 0.40, width: 48, height: h * 0.13))
        trail.stampEllipse(center: CGPoint(x: w * 0.52, y: h * 0.52),
                           radiusX: w * 0.11, radiusY: h * 0.040)
        // Vers la clairière sombre (est)
        trail.stamp(rect: CGRect(x: w * 0.49, y: h * 0.52, width: 48, height: h * 0.12))
        trail.stamp(rect: CGRect(x: w * 0.49, y: h * 0.62, width: w * 0.24, height: 44))
        trail.stampEllipse(center: CGPoint(x: w * 0.70, y: h * 0.66),
                           radiusX: w * 0.12, radiusY: h * 0.045)
        // Remontée finale vers le seuil nord
        trail.stamp(rect: CGRect(x: w * 0.67, y: h * 0.66, width: 48, height: h * 0.13))
        trail.stamp(rect: CGRect(x: w * 0.52, y: h * 0.76, width: w * 0.20, height: 44))
        trail.stamp(rect: CGRect(x: w * 0.52, y: h * 0.76, width: 48, height: h * 0.16))
        trail.stampEllipse(center: CGPoint(x: w * 0.55, y: h * 0.90),
                           radiusX: w * 0.09, radiusY: h * 0.035)
        renderTileMap(trail, fullTile: "me_dirt_full", edgePrefix: "me_edge_",
                      in: scene, z: -9.6,
                      tint: SKColor(red: 0.16, green: 0.10, blue: 0.07, alpha: 1))

        // ── CANOPÉE : double mur d'arbres ouest/est + lisières sud/nord ──
        // me_tree_1..6 UNIQUEMENT : arbres ME naturels complets.
        // (me_tree_7..10 = arbres en jardinière urbaine — réservés au
        // village ; mv_forest_* = tuiles de canopée non homogènes.)
        let treeScale = max(0.45, min(0.68, w / 760))
        let borderTrees = ["me_tree_1", "me_tree_5", "me_tree_2",
                           "me_tree_3", "me_tree_6", "me_tree_4"]
        var treeIdx = 0
        func plantTree(_ x: CGFloat, _ y: CGFloat, scaleMult: CGFloat = 1.0, dim: CGFloat = 1.0) {
            let name = borderTrees[treeIdx % borderTrees.count]
            treeIdx += 1
            let tree = PixelArtSprites.still(name: name, scale: treeScale * scaleMult,
                                              anchor: CGPoint(x: 0.5, y: 0.0))
                ?? makeTree(height: 60)
            tree.position = CGPoint(x: x, y: y)
            tree.zPosition = propLayer(for: y, in: h)
            tree.alpha = dim
            addGroundShadow(under: tree, width: 18 * scaleMult, height: 6)
            add(tree, to: scene)
            // Tronc infranchissable (la canopée reste traversable derrière)
            registerFootprint(of: tree, widthRatio: 0.45, maxDepth: 22)
        }
        var yCursor = h * 0.03
        var side = 0
        while yCursor < h * 0.97 {
            // jitter déterministe pour casser l'alignement
            let jitter = CGFloat((side * 7) % 13) / 13.0
            plantTree(w * (0.040 + 0.020 * jitter), yCursor, scaleMult: 1.0)
            plantTree(w * (0.125 + 0.025 * jitter), yCursor + h * 0.022, scaleMult: 0.85)
            plantTree(w * (0.960 - 0.020 * jitter), yCursor + h * 0.012, scaleMult: 1.0)
            plantTree(w * (0.875 - 0.025 * jitter), yCursor + h * 0.034, scaleMult: 0.85)
            yCursor += h * 0.052
            side += 1
        }
        // Lisière sud (entrée) et nord (seuil) : encadre sans bloquer le sentier
        for x in [0.22, 0.34, 0.64, 0.76] {
            plantTree(w * CGFloat(x), h * 0.015, scaleMult: 0.9)
        }
        for x in [0.24, 0.38, 0.70, 0.82] {
            plantTree(w * CGFloat(x), h * 0.965, scaleMult: 0.9)
        }
        // Arbres intérieurs épars (hors sentier)
        let innerTrees: [(CGFloat, CGFloat)] = [
            (0.62, 0.10), (0.78, 0.18), (0.22, 0.22), (0.58, 0.26),
            (0.80, 0.33), (0.24, 0.46), (0.70, 0.46), (0.30, 0.58),
            (0.78, 0.56), (0.24, 0.68), (0.40, 0.72), (0.80, 0.78),
            (0.30, 0.84), (0.74, 0.92)
        ]
        for (x, y) in innerTrees {
            plantTree(w * x, h * y, scaleMult: 0.82)
        }

        // ── ARBRES MORTS CORROMPUS près des zones de danger (teinte Aether) ──
        let corrupted: [(CGFloat, CGFloat, CGFloat)] = [
            (0.20, 0.295, 0.80), (0.40, 0.33, 0.74),
            (0.61, 0.645, 0.80), (0.79, 0.695, 0.74)
        ]
        for (x, y, s) in corrupted {
            // gy_tree = arbre mort ME complet (mv_dead_tree était une
            // spritesheet entière → « troncs coupés à moitié » à l'écran)
            guard let tree = PixelArtSprites.still(name: "gy_tree", scale: treeScale * s * 0.75,
                                                   anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            tree.position = CGPoint(x: w * x, y: h * y)
            tree.zPosition = propLayer(for: tree.position.y, in: h)
            tree.forEachDescendantSprite { sprite in
                sprite.color = SKColor(red: 0.28, green: 0.12, blue: 0.42, alpha: 1)
                sprite.colorBlendFactor = 0.50
            }
            addGroundShadow(under: tree, width: 46 * treeScale, height: 13 * treeScale)
            add(tree, to: scene)
            registerFootprint(of: tree, widthRatio: 0.45, maxDepth: 22)
        }

        // Les combats de la forêt sont désormais portés par des monstres
        // baladeurs (GameManager.spawnForestRoamers) : plus de halos de danger
        // ni de crânes statiques marquant les zones de combat.

        // Campement : feu, bois, banc — havre au milieu du trek
        addPixelProp("me_campfire", in: scene, at: CGPoint(x: w * 0.52, y: h * 0.515), scale: 0.50)
        addPixelProp("me_cut_wood", in: scene, at: CGPoint(x: w * 0.575, y: h * 0.505), scale: 0.42)
        addPixelProp("me_cut_wood_bench", in: scene, at: CGPoint(x: w * 0.465, y: h * 0.500), scale: 0.42)
        addSaveCrystal(at: CGPoint(x: w * 0.46, y: h * 0.540), in: scene)

        // Statues gardiennes oubliées le long du sentier
        addPixelProp("me_angel_statue_1", in: scene, at: CGPoint(x: w * 0.36, y: h * 0.355), scale: 0.26)
        addPixelProp("me_statue_grey", in: scene, at: CGPoint(x: w * 0.49, y: h * 0.875), scale: 0.26)

        // Seuil du sanctuaire (sortie nord)
        let deepPath = SKShapeNode(rectOf: CGSize(width: 64, height: 32), cornerRadius: 8)
        deepPath.fillColor = SKColor(red: 0.12, green: 0.05, blue: 0.18, alpha: 0.18)
        deepPath.strokeColor = SKColor(red: 0.50, green: 0.25, blue: 0.75, alpha: 0.35)
        deepPath.lineWidth = 1.5
        deepPath.position = CGPoint(x: w * 0.55, y: h * 0.90)
        deepPath.zPosition = -2
        add(deepPath, to: scene)
        JuiceEngine.pulse(deepPath, scale: 1.15)

        let pathLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        pathLabel.text = String(localized: "world.deepPath")
        pathLabel.fontSize = 14
        pathLabel.fontColor = SKColor(red: 0.60, green: 0.40, blue: 0.85, alpha: 0.8)
        pathLabel.position = CGPoint(x: w * 0.55, y: h * 0.925)
        pathLabel.zPosition = -1
        add(pathLabel, to: scene)

        scatterForestProps(in: scene, w: w, h: h)

        let forestAmbiance = SKNode()
        forestAmbiance.addChild(ParticleFactory.forestFog(in: CGSize(width: w, height: h)))
        forestAmbiance.addChild(LightingEngine.godRays(in: CGSize(width: w, height: h)))
        forestAmbiance.addChild(LightingEngine.fireflies(in: CGSize(width: w, height: h)))
        forestAmbiance.addChild(AmbientLife.birds(in: CGSize(width: w, height: h), flocks: 1))
        addAtmosphere(forestAmbiance, to: scene)
        setZoneVignette(in: scene, alpha: 0.50)
        // Sous la canopée le grade froid reste ; la pluie s'ajoute parfois
        _ = rollWeatherRain(in: scene, chance: 18)
        LightingEngine.applyGrade(.forest, in: scene)
        AudioEngine.shared.setAmbience(.forest)
        debugDrawObstacles(in: scene)
    }

    /// Sous-bois : champignons, rochers, souches, pousses et os dispersés
    /// de façon déterministe, hors sentier et clairières.
    private func scatterForestProps(in scene: SKScene, w: CGFloat, h: CGFloat) {
        let reserved: [CGRect] = [
            CGRect(x: w * 0.44, y: 0, width: w * 0.12, height: h * 0.17),
            CGRect(x: w * 0.15, y: h * 0.25, width: w * 0.30, height: h * 0.13),  // bosquet
            CGRect(x: w * 0.39, y: h * 0.47, width: w * 0.26, height: h * 0.10),  // campement
            CGRect(x: w * 0.56, y: h * 0.60, width: w * 0.28, height: h * 0.12),  // clairière
            CGRect(x: w * 0.44, y: h * 0.85, width: w * 0.22, height: h * 0.10)   // seuil
        ]
        let props = ["me_mushrooms_1", "me_mushrooms_2", "forest_mushroom_1",
                     "forest_mushroom_2", "mushroom_1", "mushroom_3",
                     "rock_1", "rock_3", "rock_5", "village_rock_1",
                     "stump_1", "stump_2", "forest_stump_1",
                     "me_big_sprout_1", "me_big_sprout_2", "me_big_sprout_3",
                     "bones_1"]
        var seed: UInt64 = 0xF0E5_57_2026
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        var placed = 0
        var attempts = 0
        while placed < 52 && attempts < 420 {
            attempts += 1
            let p = CGPoint(x: w * 0.16 + next() * w * 0.68,
                            y: h * 0.02 + next() * h * 0.94)
            if reserved.contains(where: { $0.contains(p) }) { continue }
            let name = props[Int(next() * CGFloat(props.count)) % props.count]
            guard let node = PixelArtSprites.still(name: name, scale: 0.42,
                                                    anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            node.position = p
            node.zPosition = -8.8
            add(node, to: scene)
            // Rochers, souches et ossements bloquent ; le reste se marche.
            if !Self.walkablePropPrefixes.contains(where: name.hasPrefix) {
                registerFootprint(of: node, widthRatio: 0.6, maxDepth: 16)
            }
            placed += 1
        }
    }

    /// Scale dynamique des arbres pixel art de la forêt selon la largeur.
    /// Cible ~70 pt iPhone, ~110 pt iPad pour les arbres de bordure.
    private func forestTreeScale(for sceneWidth: CGFloat) -> CGFloat {
        let s = sceneWidth / 2400
        return max(0.22, min(0.45, s))
    }

    /// Place le jouet visible en forêt (si quête active)
    func addToyMarker(in scene: SKScene) {
        guard toyMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let toy = SKNode()
        toy.position = CGPoint(x: w * 0.80, y: h * 0.45)
        toy.zPosition = 3

        // Petit ours en bois — grille pixel (charte : zéro coin arrondi/glow)
        let bear = PixelIcons.custom(map: [
            ".OO....OO.",
            ".Oo....oO.",
            "..OOOOOO..",
            ".OoooooooO",
            ".OoDooDooO",
            ".OooooooO.",
            "..OonnOO..",
            "..OOOOOO..",
            ".OOooooOO.",
            "OOooooooOO",
            "OoOooooOoO",
            ".OOooooOO.",
            ".Oo....oO.",
            ".OO....OO."
        ], palette: [
            "O": SKColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1),
            "o": SKColor(red: 0.68, green: 0.45, blue: 0.20, alpha: 1),
            "D": SKColor(red: 0.20, green: 0.12, blue: 0.06, alpha: 1),
            "n": SKColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 1)
        ], pixel: 1.6)
        toy.addChild(bear)

        // Losange pixel doré flottant au-dessus du jouet
        let sparkle = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
        sparkle.fillColor = SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        sparkle.strokeColor = SKColor(red: 1, green: 0.95, blue: 0.6, alpha: 0.9)
        sparkle.lineWidth = 1
        sparkle.zRotation = .pi / 4
        sparkle.position = CGPoint(x: 0, y: 24)
        toy.addChild(sparkle)
        JuiceEngine.float(sparkle, distance: 4)

        worldNode.addChild(toy)
        backdropNodes.append(toy)
        toyMarker = toy
    }

    func removeToyMarker() {
        toyMarker?.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
        if let t = toyMarker, let idx = backdropNodes.firstIndex(where: { $0 === t }) {
            backdropNodes.remove(at: idx)
        }
        toyMarker = nil
    }

    // MARK: - Talisman perdu (quête de la villageoise)

    /// La croix de bois du fils, à moitié enterrée sur le sentier ouest.
    func addMedallionMarker(in scene: SKScene) {
        guard medallionMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.28, y: h * 0.72)
        marker.zPosition = 3
        if let cross = PixelArtSprites.still(name: "gy_cross_wood", scale: 0.30,
                                             anchor: CGPoint(x: 0.5, y: 0.0)) {
            marker.addChild(cross)
        }
        let glow = SKSpriteNode(color: SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 0.30),
                                size: CGSize(width: 30, height: 30))
        glow.zRotation = .pi / 4
        glow.position = CGPoint(x: 0, y: 10)
        glow.zPosition = -0.5
        marker.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        medallionMarker = marker
    }

    func removeMedallionMarker() {
        medallionMarker?.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
        if let m = medallionMarker, let idx = backdropNodes.firstIndex(where: { $0 === m }) {
            backdropNodes.remove(at: idx)
        }
        medallionMarker = nil
    }

    // MARK: - Fer corrompu (quête de Bram)

    /// Veine de fer noirci qui affleure à l'est du bosquet.
    func addOreMarker(in scene: SKScene) {
        guard oreMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        // ATTENTION : loin du campement+cristal (0.52, 0.52) — le tap du
        // cristal de save est prioritaire et volerait le ramassage.
        marker.position = CGPoint(x: w * 0.40, y: h * 0.63)
        marker.zPosition = 3

        // Bloc de minerai sombre (placeholder pixel)
        // Bloc de fer corrompu — grille pixel, filons violets (zéro glow)
        let rock = PixelIcons.custom(map: [
            "....RRRR....",
            "..RRrrrrRR..",
            ".RrvRrrRvrR.",
            "RrrvvrrrvvrR",
            "RrrrvrrrrvrR",
            "RrvrrrRvrrrR",
            "RrvvrrrvvrrR",
            ".RrrrRrrrrR.",
            "..RRRRRRRR.."
        ], palette: [
            "R": SKColor(red: 0.10, green: 0.09, blue: 0.14, alpha: 1),
            "r": SKColor(red: 0.20, green: 0.18, blue: 0.26, alpha: 1),
            "v": SKColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1)
        ], pixel: 1.8)
        marker.addChild(rock)

        // Étincelle pixel violette (repère œil, cohérent charte)
        let sparkle = SKSpriteNode(color: SKColor(red: 0.65, green: 0.40, blue: 0.95, alpha: 1),
                                   size: CGSize(width: 7, height: 7))
        sparkle.zRotation = .pi / 4
        sparkle.position = CGPoint(x: 0, y: 18)
        marker.addChild(sparkle)
        JuiceEngine.float(sparkle, distance: 4)

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        oreMarker = marker
    }

    func removeOreMarker() {
        removeCollectMarker(&oreMarker)
    }

    // MARK: - Herbe lunaire (quête de Sage)

    /// Herbe pâle qui luit entre les racines, à l'ouest du sentier.
    func addHerbMarker(in scene: SKScene) {
        guard herbMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.12, y: h * 0.40)
        marker.zPosition = 3

        // Brins luminescents
        for (dx, height) in [(-4, 10), (0, 14), (4, 9)] {
            let blade = SKShapeNode(rectOf: CGSize(width: 2, height: CGFloat(height)), cornerRadius: 1)
            blade.fillColor = SKColor(red: 0.70, green: 0.95, blue: 0.85, alpha: 0.95)
            blade.strokeColor = .clear
            blade.position = CGPoint(x: CGFloat(dx), y: CGFloat(height) / 2)
            blade.zRotation = CGFloat(dx) * 0.03
            marker.addChild(blade)
        }

        let glow = SKShapeNode(circleOfRadius: 16)
        glow.fillColor = SKColor(red: 0.70, green: 0.95, blue: 0.85, alpha: 0.10)
        glow.strokeColor = SKColor(red: 0.70, green: 0.95, blue: 0.85, alpha: 0.25)
        glow.lineWidth = 1
        glow.position = CGPoint(x: 0, y: 6)
        marker.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.5)

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        herbMarker = marker
    }

    func removeHerbMarker() {
        removeCollectMarker(&herbMarker)
    }

    // MARK: - Insigne de l'éclaireur (quête de Garen)

    /// L'insigne de Tomm, à moitié enfoui sur la sente est.
    func addBadgeMarker(in scene: SKScene) {
        guard badgeMarker == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let marker = SKNode()
        marker.position = CGPoint(x: w * 0.68, y: h * 0.18)
        marker.zPosition = 3

        // Écusson métallique terni
        let shield = SKShapeNode(rectOf: CGSize(width: 10, height: 12), cornerRadius: 4)
        shield.fillColor = SKColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1)
        shield.strokeColor = SKColor(red: 0.75, green: 0.75, blue: 0.80, alpha: 0.8)
        shield.lineWidth = 1
        shield.zRotation = 0.5   // à moitié planté dans le sol
        marker.addChild(shield)

        // Reflet froid
        let glow = SKShapeNode(circleOfRadius: 15)
        glow.fillColor = SKColor(red: 0.60, green: 0.70, blue: 0.90, alpha: 0.08)
        glow.strokeColor = SKColor(red: 0.60, green: 0.70, blue: 0.90, alpha: 0.20)
        glow.lineWidth = 1
        marker.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.4)

        worldNode.addChild(marker)
        backdropNodes.append(marker)
        badgeMarker = marker
    }

    func removeBadgeMarker() {
        removeCollectMarker(&badgeMarker)
    }

    /// Fade + retrait d'un marqueur de collecte (factorisation commune).
    private func removeCollectMarker(_ marker: inout SKNode?) {
        marker?.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
        if let m = marker, let idx = backdropNodes.firstIndex(where: { $0 === m }) {
            backdropNodes.remove(at: idx)
        }
        marker = nil
    }

    // MARK: - Marqueurs de quête « ! » sur les PNJ

    /// Point d'exclamation doré pulsant au-dessus d'un PNJ qui a une
    /// quête à proposer. `visible: false` le retire.
    func setQuestMarker(on npc: SKNode, visible: Bool) {
        let markName = "questMark"
        if !visible {
            npc.childNode(withName: markName)?.removeFromParent()
            return
        }
        guard npc.childNode(withName: markName) == nil else { return }
        let mark = SKLabelNode(fontNamed: PixelUI.uiFont)
        mark.name = markName
        mark.text = "!"
        mark.fontSize = 20
        mark.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1)
        mark.position = CGPoint(x: 0, y: 40)
        mark.zPosition = 5
        npc.addChild(mark)
        mark.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 5, duration: 0.4),
            .moveBy(x: 0, y: -5, duration: 0.4)
        ])))
    }

private func decorateVillage(in scene: SKScene) {
    let w = scene.size.width
    let h = worldHeight > 0 ? worldHeight : scene.size.height

    // Pose un groupe de props serrés autour d'un point (cohérence : on
    // regroupe ce qui va ensemble plutôt que d'éparpiller sur la pelouse).
    func group(_ items: [(String, CGFloat, CGFloat, CGFloat)], at c: CGPoint) {
        for (name, dx, dy, s) in items {
            addPixelProp(name, in: scene,
                         at: CGPoint(x: c.x + w * dx, y: c.y + h * dy), scale: s)
        }
    }

    // ═══ ENTRÉE SUD — portail d'accueil sur le parvis ═══
    group([("me_sign_1", -0.085, 0.0, 0.55), ("me_lamp_1", -0.085, 0.018, 0.40),
           ("me_lamp_1", 0.085, 0.018, 0.40), ("me_sign_2", 0.085, 0.0, 0.55),
           ("me_flower_red", -0.115, 0.008, 0.45), ("me_flower_yellow", 0.115, 0.008, 0.45)],
          at: CGPoint(x: w * 0.50, y: h * 0.012))

    // ═══ MAISON DE KAEL (onestory, 0.32/0.075) — cour familiale ═══
    addFenceRect(in: scene, at: CGPoint(x: w * 0.235, y: h * 0.085),
                 size: CGSize(width: w * 0.075, height: h * 0.026))
    group([("mv_garden_bed", 0.0, -0.002, 0.40)],
          at: CGPoint(x: w * 0.235, y: h * 0.085))
    group([("me_mailbox_1", 0.075, 0.002, 0.42), ("me_birdhouse_blue", 0.055, 0.022, 0.40),
           ("me_flower_white", -0.065, 0.002, 0.42)],
          at: CGPoint(x: w * 0.32, y: h * 0.075))

    // ═══ COUR COUNTRY SUD (0.14/0.16) ═══
    group([("me_mailbox_1", 0.075, 0.002, 0.42), ("me_hanging_flowers", -0.055, -0.004, 0.42),
           ("me_flower_pink", -0.075, 0.004, 0.42), ("me_birdhouse_brown", 0.10, 0.018, 0.40)],
          at: CGPoint(x: w * 0.14, y: h * 0.16))

    // ═══ COUR MODERNE (0.80/0.16) ═══
    group([("me_mailbox_1", -0.085, 0.002, 0.42), ("me_garden_bench", 0.085, 0.006, 0.42),
           ("me_flower_blue", 0.10, 0.0, 0.42), ("me_vase_yellow", -0.10, 0.004, 0.40)],
          at: CGPoint(x: w * 0.80, y: h * 0.16))

    // ═══ FERME EST (bas droite) — potager clôturé dense + remise ═══
    addFenceRect(in: scene, at: CGPoint(x: w * 0.62, y: h * 0.068),
                 size: CGSize(width: w * 0.115, height: h * 0.020))
    group([("mv_garden_bed", -0.032, -0.003, 0.52), ("mv_garden_bed", 0.012, -0.003, 0.52),
           ("me_sunflower", 0.042, -0.004, 0.45), ("me_big_sprout_5", -0.052, 0.002, 0.42),
           ("me_big_sprout_6", 0.030, 0.004, 0.42)],
          at: CGPoint(x: w * 0.62, y: h * 0.068))
    addPixelProp("me_wood_storage", in: scene, at: CGPoint(x: w * 0.73, y: h * 0.092), scale: 0.55)
    addPixelProp("me_cart_empty", in: scene, at: CGPoint(x: w * 0.71, y: h * 0.052), scale: 0.48)
    addPixelProp("me_basket_2", in: scene, at: CGPoint(x: w * 0.675, y: h * 0.058), scale: 0.45)

    // ═══ PLACE CENTRALE (0.50/0.40) — fontaine, bancs, lampes en anneau ═══
    addPixelProp("village_fountain", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.392), scale: 0.85)
    group([("me_bench_1", -0.075, -0.022, 0.45), ("me_bench_2", 0.075, -0.022, 0.45),
           ("me_garden_bench", -0.075, 0.022, 0.45), ("me_bench_3", 0.075, 0.022, 0.45),
           ("me_lamp_2", -0.135, -0.030, 0.40), ("me_lamp_2", 0.135, -0.030, 0.40),
           ("me_lamp_2", -0.135, 0.030, 0.40), ("me_lamp_2", 0.135, 0.030, 0.40),
           ("me_vase_red", -0.045, -0.030, 0.42), ("me_vase_sunflower", 0.045, -0.030, 0.42)],
          at: CGPoint(x: w * 0.50, y: h * 0.40))

    // ═══ MARCHÉ — étal groupé côté ouest de la place ═══
    group([("me_wood_cart", -0.01, 0.006, 0.50), ("me_lemonade_stand", 0.045, 0.014, 0.50),
           ("village_crate_1", -0.045, 0.0, 0.45), ("village_crate_2", -0.045, 0.012, 0.45),
           ("me_barrel_1", 0.0, -0.012, 0.45), ("me_basket", 0.035, -0.008, 0.42),
           ("me_apples", 0.02, -0.014, 0.40)],
          at: CGPoint(x: w * 0.385, y: h * 0.405))

    // ═══ ÉTANG OUEST (0.085/0.46) — roseaux et berge vivante ═══
    group([("me_big_sprout_1", 0.055, 0.012, 0.45), ("me_big_sprout_2", 0.065, -0.010, 0.42),
           ("me_big_sprout_3", -0.005, 0.030, 0.42), ("me_mushrooms_1", 0.075, 0.018, 0.40),
           ("me_flower_white", 0.02, -0.032, 0.42)],
          at: CGPoint(x: w * 0.085, y: h * 0.46))

    // ═══ HERBORISTE (Mara, 0.22/0.58) — potager clôturé devant ═══
    addFenceRect(in: scene, at: CGPoint(x: w * 0.155, y: h * 0.535),
                 size: CGSize(width: w * 0.10, height: h * 0.030))
    group([("me_vase_red", -0.02, -0.006, 0.42), ("me_vase_yellow", 0.02, -0.006, 0.42),
           ("me_mushrooms_1", -0.02, 0.006, 0.40), ("me_big_sprout_4", 0.02, 0.006, 0.42),
           ("me_sunflower", 0.0, 0.0, 0.42)],
          at: CGPoint(x: w * 0.155, y: h * 0.535))
    addPixelProp("me_sign_2", in: scene, at: CGPoint(x: w * 0.27, y: h * 0.575), scale: 0.50)

    // ═══ ARMURERIE (Bram, 0.50/0.63) — bois + tonneaux contre le mur ═══
    group([("me_cut_wood", -0.085, 0.004, 0.45), ("me_cut_wood_2", -0.105, -0.006, 0.45),
           ("me_barrel_1", 0.085, 0.0, 0.45), ("me_barrel_2", 0.105, 0.008, 0.45),
           ("me_cut_wood_bench", -0.095, 0.016, 0.45)],
          at: CGPoint(x: w * 0.50, y: h * 0.625))
    addPixelProp("me_sign_3", in: scene, at: CGPoint(x: w * 0.455, y: h * 0.622), scale: 0.50)

    // ═══ AUBERGE (Sage, 0.78/0.58) — tonneaux, lanterne, repos ═══
    group([("me_barrel_3", -0.085, 0.0, 0.45), ("me_barrel_4", -0.105, 0.008, 0.45),
           ("me_hanging_pot", 0.085, 0.002, 0.45), ("village_lantern_1", 0.10, 0.012, 0.48),
           ("me_bench_2", 0.0, -0.016, 0.45)],
          at: CGPoint(x: w * 0.78, y: h * 0.58))
    addPixelProp("me_sign_1", in: scene, at: CGPoint(x: w * 0.73, y: h * 0.575), scale: 0.50)

    // ═══ QUARTIER HAUT — parc civique entre les villas ═══
    addPixelProp("me_statue_putto", in: scene, at: CGPoint(x: w * 0.43, y: h * 0.790), scale: 0.42)
    addPixelProp("me_statue_putto", in: scene, at: CGPoint(x: w * 0.57, y: h * 0.790), scale: 0.42)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.43, y: h * 0.765), scale: 0.40)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.57, y: h * 0.765), scale: 0.40)
    addPixelProp("me_garden_bench", in: scene, at: CGPoint(x: w * 0.40, y: h * 0.775), scale: 0.45)
    addPixelProp("me_bench_1", in: scene, at: CGPoint(x: w * 0.60, y: h * 0.775), scale: 0.45)
    addPixelProp("me_vase_sunflower", in: scene, at: CGPoint(x: w * 0.46, y: h * 0.800), scale: 0.42)
    addPixelProp("me_vase_red", in: scene, at: CGPoint(x: w * 0.54, y: h * 0.800), scale: 0.42)
    group([("me_mailbox_1", 0.075, 0.002, 0.42), ("me_hanging_flowers", -0.055, -0.004, 0.42),
           ("me_flower_red", -0.075, 0.006, 0.42)],
          at: CGPoint(x: w * 0.17, y: h * 0.78))
    group([("me_mailbox_1", -0.075, 0.002, 0.42), ("me_hanging_flowers", 0.055, -0.004, 0.42),
           ("me_flower_blue", 0.075, 0.006, 0.42)],
          at: CGPoint(x: w * 0.82, y: h * 0.78))

    // ═══ SORTIE NORD — porte gardée : statues + lampes + panneau ═══
    addPixelProp("me_statue_angel", in: scene, at: CGPoint(x: w * 0.43, y: h * 0.945), scale: 0.20)
    addPixelProp("me_statue_grey", in: scene, at: CGPoint(x: w * 0.57, y: h * 0.945), scale: 0.20)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.44, y: h * 0.922), scale: 0.40)
    addPixelProp("me_lamp_3", in: scene, at: CGPoint(x: w * 0.56, y: h * 0.922), scale: 0.40)
    addPixelProp("me_sign_3", in: scene, at: CGPoint(x: w * 0.565, y: h * 0.952), scale: 0.42)

    // ═══ ARBRES — bordures forestières + arbres ME dans le village ═══
    // Bordure forestière : me_tree_1..6 naturels uniquement (7..10 = arbres
    // en jardinière urbaine, réservés à l'intérieur du village).
    let borderTrees: [(String, CGFloat, CGFloat, CGFloat)] = [
        // (asset, x, y, scale) — colonnes ouest/est, espèces variées
        ("me_tree_1", 0.035, 0.055, 0.60), ("me_tree_5", 0.030, 0.13, 0.62),
        ("me_tree_2", 0.040, 0.22, 0.58), ("me_tree_6", 0.030, 0.30, 0.62),
        ("me_tree_3", 0.035, 0.38, 0.58), ("me_tree_6", 0.030, 0.56, 0.62),
        ("me_tree_4", 0.040, 0.64, 0.60), ("me_tree_4", 0.030, 0.72, 0.58),
        ("me_tree_5", 0.035, 0.83, 0.62), ("me_tree_1", 0.030, 0.92, 0.58),
        ("me_tree_3", 0.965, 0.05, 0.60), ("me_tree_2", 0.970, 0.13, 0.58),
        ("me_tree_5", 0.960, 0.24, 0.62), ("me_tree_1", 0.965, 0.33, 0.58),
        ("me_tree_6", 0.970, 0.42, 0.62), ("me_tree_3", 0.965, 0.50, 0.58),
        ("me_tree_6", 0.960, 0.64, 0.62), ("me_tree_2", 0.970, 0.72, 0.60),
        ("me_tree_4", 0.965, 0.82, 0.58), ("me_tree_5", 0.960, 0.92, 0.62)
    ]
    for (asset, x, y, s) in borderTrees {
        addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
    }
    // Quelques arbres à l'intérieur du village (respiration entre zones)
    let innerTrees: [(String, CGFloat, CGFloat)] = [
        ("me_tree_5", 0.42, 0.115), ("me_tree_2", 0.60, 0.135),
        ("me_tree_9", 0.16, 0.31), ("me_tree_3", 0.86, 0.33),
        ("me_tree_1", 0.30, 0.49), ("me_tree_6", 0.68, 0.475),
        ("me_tree_10", 0.13, 0.66), ("me_tree_5", 0.88, 0.665),
        ("me_tree_2", 0.30, 0.86), ("me_tree_8", 0.70, 0.855)
    ]
    for (asset, x, y) in innerTrees {
        addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: 0.58)
    }

    // ═══ FIGURANTS — villageois qui peuplent les rues ═══
    let extras: [(String, CGFloat, CGFloat)] = [
        ("npc_extra", 0.60, 0.305),     // badaud près du verger
        ("npc_garen", 0.385, 0.505),    // promeneur vers la place
        ("npc_sage",  0.57, 0.115)      // paysanne près de la ferme
    ]
    for (asset, x, y) in extras {
        guard let figurant = PixelArtSprites.animated(
            name: asset, frames: 6, scale: 0.5,
            timePerFrame: 0.18, anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
        figurant.position = CGPoint(x: w * x, y: h * y)
        figurant.zPosition = propLayer(for: figurant.position.y, in: scene.size.height)
        add(figurant, to: scene)
    }

    // ═══ FLEURS ÉPARSES (positions seedées, hors chemins/maisons) ═══
    scatterVillageFlowers(in: scene, w: w, h: h)
}

/// Fleurs et buissons dispersés de façon déterministe (LCG seedé) sur
/// l'herbe libre — jamais sur les chemins, maisons, place ou étang.
private func scatterVillageFlowers(in scene: SKScene, w: CGFloat, h: CGFloat) {
    let reserved: [CGRect] = [
        CGRect(x: w * 0.5 - 36, y: 0, width: 72, height: h),            // allée centrale
        CGRect(x: w * 0.30, y: h * 0.33, width: w * 0.40, height: h * 0.14), // place
        CGRect(x: 0, y: h * 0.42, width: w * 0.16, height: h * 0.08),   // étang
        CGRect(x: w * 0.02, y: h * 0.03, width: w * 0.42, height: h * 0.16), // maisons sud-ouest
        CGRect(x: w * 0.62, y: h * 0.10, width: w * 0.36, height: h * 0.10), // maison moderne
        CGRect(x: w * 0.54, y: h * 0.04, width: w * 0.26, height: h * 0.06), // ferme est
        CGRect(x: w * 0.08, y: h * 0.51, width: w * 0.28, height: h * 0.14), // herboriste
        CGRect(x: w * 0.36, y: h * 0.56, width: w * 0.28, height: h * 0.14), // armurerie
        CGRect(x: w * 0.64, y: h * 0.51, width: w * 0.28, height: h * 0.14), // auberge
        CGRect(x: w * 0.06, y: h * 0.72, width: w * 0.30, height: h * 0.14), // victorienne
        CGRect(x: w * 0.66, y: h * 0.72, width: w * 0.30, height: h * 0.14), // maison est
        CGRect(x: w * 0.38, y: h * 0.74, width: w * 0.24, height: h * 0.12)  // chalet maire
    ]
    let flowers = ["me_flower_red", "me_flower_yellow", "me_flower_blue",
                   "me_flower_pink", "me_flower_white", "me_sunflower",
                   "me_flower_bush_1", "me_flower_bush_2", "me_flower_bush_3"]
    var seed: UInt64 = 0x5EED_0501_15
    func next() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(seed >> 40) / CGFloat(1 << 24)
    }
    var placed = 0
    var attempts = 0
    while placed < 48 && attempts < 400 {
        attempts += 1
        let p = CGPoint(x: w * 0.06 + next() * w * 0.88,
                        y: h * 0.02 + next() * h * 0.94)
        if reserved.contains(where: { $0.contains(p) }) { continue }
        let name = flowers[Int(next() * CGFloat(flowers.count)) % flowers.count]
        guard let node = PixelArtSprites.still(name: name, scale: 0.45,
                                                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
        node.position = p
        node.zPosition = -8.8
        add(node, to: scene)
        // Les buissons touffus bloquent le passage (on les contourne) ;
        // les fleurs plates restent franchissables.
        if name.contains("bush") {
            registerFootprint(of: node, widthRatio: 0.7, depthRatio: 0.5, maxDepth: 22)
        }
        placed += 1
    }
}

    // MARK: - Forest Building Blocks

    private func makeDangerZone(at pos: CGPoint, radius: CGFloat, color: SKColor) -> SKNode {
        let zone = SKNode()
        zone.position = pos
        zone.zPosition = -2

        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = color.withAlphaComponent(0.06)
        circle.strokeColor = color.withAlphaComponent(0.18)
        circle.lineWidth = 1.5
        zone.addChild(circle)
        JuiceEngine.pulse(circle, scale: 1.2)

        // Crâne pixel art (zone de chasse)
        let icon = PixelIcons.node(.skull, pixel: 2.2)
        icon.position = CGPoint(x: 0, y: 2)
        zone.addChild(icon)
        JuiceEngine.float(icon, distance: 4)

        return zone
    }

    // MARK: - Mines de Cendreval (excursion optionnelle, forêt)

    /// Bouche de mine effondrée dans le flanc est de la forêt : ouverture
    /// sombre, poutres de bois, lanterne éteinte. Tap → entrer.
    func addMineEntrance(in scene: SKScene) {
        guard worldNode.childNode(withName: "mineEntrance") == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let entrance = SKNode()
        entrance.name = "mineEntrance"
        entrance.position = CGPoint(x: w * 0.88, y: h * 0.30)
        entrance.zPosition = 2

        // Ouverture sombre (bouche de galerie)
        let mouth = SKShapeNode(rect: CGRect(x: -26, y: 0, width: 52, height: 40),
                                cornerRadius: 14)
        mouth.fillColor = SKColor(red: 0.03, green: 0.02, blue: 0.04, alpha: 1)
        mouth.strokeColor = SKColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 1)
        mouth.lineWidth = 3
        entrance.addChild(mouth)

        // Poutres de soutènement en bois
        for (x, rot) in [(-24, 0.06), (24, -0.06)] {
            let beam = SKShapeNode(rectOf: CGSize(width: 7, height: 46), cornerRadius: 2)
            beam.fillColor = SKColor(red: 0.38, green: 0.26, blue: 0.14, alpha: 1)
            beam.strokeColor = SKColor(red: 0.22, green: 0.14, blue: 0.08, alpha: 1)
            beam.lineWidth = 1
            beam.position = CGPoint(x: CGFloat(x), y: 22)
            beam.zRotation = CGFloat(rot)
            entrance.addChild(beam)
        }
        let lintel = SKShapeNode(rectOf: CGSize(width: 62, height: 8), cornerRadius: 2)
        lintel.fillColor = SKColor(red: 0.34, green: 0.23, blue: 0.12, alpha: 1)
        lintel.strokeColor = SKColor(red: 0.20, green: 0.13, blue: 0.07, alpha: 1)
        lintel.lineWidth = 1
        lintel.position = CGPoint(x: 0, y: 44)
        entrance.addChild(lintel)

        // Lueur de lanterne faible pour attirer l'oeil
        let glow = SKShapeNode(circleOfRadius: 8)
        glow.fillColor = SKColor(red: 1.0, green: 0.72, blue: 0.30, alpha: 0.35)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 30, y: 40)
        entrance.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.4)

        // Panneau : nom de la galerie
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "world.mines.entrance")
        label.fontSize = 12
        label.fontColor = SKColor(white: 0.75, alpha: 0.75)
        label.position = CGPoint(x: 0, y: 54)
        entrance.addChild(label)

        worldNode.addChild(entrance)
        backdropNodes.append(entrance)
    }

    /// Entrée de la Caverne aux Échos : faille naturelle sombre bordée de
    /// rochers, dans la forêt (flanc ouest). Pixels nets, aucun arrondi.
    func addCaveEntrance(in scene: SKScene) {
        guard worldNode.childNode(withName: "caveEntrance") == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let entrance = SKNode()
        entrance.name = "caveEntrance"
        entrance.position = CGPoint(x: w * 0.12, y: h * 0.80)
        entrance.zPosition = 2

        // Bouche de caverne : trapèze sombre (rect net empilé)
        for (wdt, yy) in [(58, 6), (46, 26), (32, 42)] {
            let slab = SKSpriteNode(color: SKColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1),
                                    size: CGSize(width: CGFloat(wdt), height: 22))
            slab.position = CGPoint(x: 0, y: CGFloat(yy))
            entrance.addChild(slab)
        }
        worldNode.addChild(entrance)
        backdropNodes.append(entrance)

        // Rochers encadrant l'ouverture (assets pixel)
        addPixelProp("rock_1", in: scene, at: CGPoint(x: w * 0.12 - 40, y: h * 0.80), scale: 1.3)
        addPixelProp("rock_5", in: scene, at: CGPoint(x: w * 0.12 + 40, y: h * 0.80), scale: 1.2)

        // Champignon luisant (sa lueur froide signale l'entrée)
        addPixelProp("mushroom_1", in: scene, at: CGPoint(x: w * 0.12 + 22, y: h * 0.80 + 6),
                     scale: 0.7)

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "world.cave.entrance")
        label.fontSize = 12
        label.fontColor = SKColor(white: 0.72, alpha: 0.75)
        label.position = CGPoint(x: w * 0.12, y: h * 0.80 + 66)
        label.zPosition = 2
        add(label, to: scene)
    }

    func switchToMines(in scene: SKScene, progress: Int = 0, goldTaken: Bool = false) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        buildMines(in: scene, progress: progress, goldTaken: goldTaken)
    }

    /// Galeries mortes de Cendreval : voûte de pierre, rails et chariots,
    /// étais de bois, lanternes, champignons luisants, monstres visibles
    /// aux zones de danger. Une seule hauteur d'écran (pas de scroll).
    private func buildMines(in scene: SKScene, progress: Int, goldTaken: Bool) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : pierre gris cendre, plus sombre qu'avant
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Voûte : deux rangées de pierre taillée en haut de la galerie
        let wallTile: CGFloat = 24
        let wallCols = Int(ceil(w / wallTile)) + 1
        for c in 0..<wallCols {
            for r in 0..<2 {
                guard let t = PixelArtSprites.still(
                    name: ["me_wall_1", "me_wall_2", "me_wall_3", "me_wall_5"][(c + r) % 4],
                    scale: 0.5, anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
                t.position = CGPoint(x: CGFloat(c) * wallTile + wallTile / 2,
                                     y: h - CGFloat(r) * wallTile - wallTile / 2)
                t.zPosition = -6
                t.forEachDescendantSprite { s in
                    s.color = SKColor(red: 0.16, green: 0.16, blue: 0.20, alpha: 1)
                    s.colorBlendFactor = 0.55
                }
                add(t, to: scene)
            }
        }

        // Titre de zone
        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.mines.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.60, green: 0.58, blue: 0.52, alpha: 0.7)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.90)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // Rails : de la sortie (sud) vers le fond de la galerie
        addMineRails(in: scene, from: CGPoint(x: w * 0.50, y: h * 0.10),
                     to: CGPoint(x: w * 0.50, y: h * 0.62))
        addMineRails(in: scene, from: CGPoint(x: w * 0.50, y: h * 0.62),
                     to: CGPoint(x: w * 0.86, y: h * 0.62), horizontal: true)

        // Chariots de mine sur les rails
        addPixelProp("me_cart_empty", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.40), scale: 0.55)
        addPixelProp("me_cart_empty", in: scene, at: CGPoint(x: w * 0.74, y: h * 0.60), scale: 0.55)

        // Piliers naturels + colonnes brisées : la voûte fatiguée
        addPixelProp("pillar_grey_1", in: scene, at: CGPoint(x: w * 0.10, y: h * 0.72), scale: 1.8)
        addPixelProp("pillar_grey_2", in: scene, at: CGPoint(x: w * 0.90, y: h * 0.76), scale: 1.8)
        addPixelProp("column_broken_1", in: scene, at: CGPoint(x: w * 0.30, y: h * 0.80), scale: 2.0)
        addPixelProp("column_broken_1", in: scene, at: CGPoint(x: w * 0.70, y: h * 0.84), scale: 1.8)

        // Étais de bois : montants + traverse, style charpente de mine
        for x in [0.07, 0.93] {
            for y in [0.32, 0.54] {
                addMineStrut(in: scene, at: CGPoint(x: w * CGFloat(x), y: h * CGFloat(y)))
            }
        }

        // Éboulis et rochers
        let rocks: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("rock_7", 0.20, 0.40, 0.60), ("rock_3", 0.48, 0.28, 0.55),
            ("rock_9", 0.76, 0.48, 0.60), ("rock_1", 0.58, 0.76, 0.50),
            ("rock_5", 0.14, 0.24, 0.50), ("gy_stone_1", 0.36, 0.68, 0.50),
            ("gy_stone_3", 0.88, 0.34, 0.50), ("ext_pebbles", 0.42, 0.50, 0.8),
            ("ext_pebbles", 0.68, 0.24, 0.8), ("ext_pebbles", 0.24, 0.80, 0.8)
        ]
        for (asset, x, y, s) in rocks {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
        }

        // Ossements des équipes disparues
        for p in [(0.38, 0.40), (0.66, 0.32), (0.26, 0.60), (0.82, 0.72)] {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: 2.0,
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            bones.position = CGPoint(x: w * p.0, y: h * p.1)
            bones.zPosition = -2
            bones.alpha = 0.85
            add(bones, to: scene)
        }

        // Lanternes des mineurs : points de lumière chaude dans le noir
        for (x, y) in [(0.14, 0.66), (0.44, 0.14), (0.56, 0.14), (0.86, 0.52)] {
            addMineLantern(in: scene, at: CGPoint(x: w * CGFloat(x), y: h * CGFloat(y)))
        }
        // Bougies fondues près de la plaque
        addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * 0.14, y: h * 0.62), scale: 0.5)
        addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * 0.23, y: h * 0.64), scale: 0.45)

        // Champignons luisants : la seule vie qui reste ici
        for (x, y, s) in [(0.34, 0.24, 0.9), (0.60, 0.44, 0.8), (0.18, 0.50, 0.85),
                          (0.78, 0.80, 0.9), (0.52, 0.66, 0.75)] {
            guard let shroom = PixelArtSprites.still(
                name: Bool.random() ? "mushroom_1" : "mushroom_3",
                scale: CGFloat(s), anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            shroom.position = CGPoint(x: w * CGFloat(x), y: h * CGFloat(y))
            shroom.zPosition = -3
            shroom.forEachDescendantSprite { sp in
                sp.color = SKColor(red: 0.35, green: 0.85, blue: 0.75, alpha: 1)
                sp.colorBlendFactor = 0.35
            }
            add(shroom, to: scene)
            JuiceEngine.pulse(shroom, scale: 1.05)
        }

        // Les monstres ne sont plus des props statiques : le GameManager
        // fait patrouiller des RoamingMonster (spawnMineRoamers) qui chargent
        // Kael. Fini les halos de danger + crânes + bouton « A · Combattre ».

        // Plaque des mineurs (bas-gauche) : le lore de Cendreval
        let plaque = makeMinersPlaque(at: CGPoint(x: w * 0.18, y: h * 0.68))
        add(plaque, to: scene)

        // Veine d'or : reflets dorés dans la paroi (déjà ramassée = absente)
        if !goldTaken {
            let vein = makeGoldVein(at: CGPoint(x: w * 0.80, y: h * 0.40))
            vein.name = "minesGoldVein"
            add(vein, to: scene)
        }

        // Sortie au sud : halo de lumière du jour
        let exitGlow = SKShapeNode(circleOfRadius: 34)
        exitGlow.fillColor = SKColor(red: 0.55, green: 0.65, blue: 0.75, alpha: 0.10)
        exitGlow.strokeColor = SKColor(red: 0.70, green: 0.80, blue: 0.90, alpha: 0.25)
        exitGlow.lineWidth = 1.5
        exitGlow.position = CGPoint(x: w * 0.50, y: h * 0.08)
        add(exitGlow, to: scene)
        JuiceEngine.pulse(exitGlow, scale: 1.15)
        let exitLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        exitLabel.text = String(localized: "world.mines.exit")
        exitLabel.fontSize = 12
        exitLabel.fontColor = SKColor(white: 0.70, alpha: 0.7)
        exitLabel.position = CGPoint(x: w * 0.50, y: h * 0.08 + 42)
        add(exitLabel, to: scene)

        // Cendre en suspension : même atmosphère que les ruines
        addAtmosphere(ParticleFactory.ruinsAsh(in: scene.size), to: scene)
        setZoneVignette(in: scene, alpha: 0.68)   // mines : galeries noires
        LightingEngine.applyGrade(.mines, in: scene)
        LightingEngine.attachHeroLight(to: kael)  // seul point chaud mobile
        AudioEngine.shared.setAmbience(.mines)
    }

    /// Rails de mine : deux longerons métalliques + traverses de bois.
    /// 100 % SKSpriteNode — carrés nets, zéro shape lissée.
    private func addMineRails(in scene: SKScene, from: CGPoint, to: CGPoint,
                              horizontal: Bool = false) {
        let rails = SKNode()
        rails.zPosition = -7
        let railColor = SKColor(red: 0.28, green: 0.28, blue: 0.33, alpha: 1)
        let tieColor = SKColor(red: 0.24, green: 0.16, blue: 0.09, alpha: 1)
        let length = horizontal ? abs(to.x - from.x) : abs(to.y - from.y)
        let gauge: CGFloat = 14

        for offset in [-gauge / 2, gauge / 2] {
            let rail = SKSpriteNode(color: railColor,
                                    size: horizontal
                                        ? CGSize(width: length, height: 3)
                                        : CGSize(width: 3, height: length))
            rail.position = horizontal
                ? CGPoint(x: (from.x + to.x) / 2, y: from.y + offset)
                : CGPoint(x: from.x + offset, y: (from.y + to.y) / 2)
            rails.addChild(rail)
        }
        let tieCount = Int(length / 26)
        for i in 0...tieCount {
            let d = CGFloat(i) * 26
            let tie = SKSpriteNode(color: tieColor,
                                   size: horizontal
                                       ? CGSize(width: 5, height: gauge + 8)
                                       : CGSize(width: gauge + 8, height: 5))
            tie.position = horizontal
                ? CGPoint(x: min(from.x, to.x) + d, y: from.y)
                : CGPoint(x: from.x, y: min(from.y, to.y) + d)
            tie.zPosition = -0.1
            rails.addChild(tie)
        }
        add(rails, to: scene)
    }

    /// Étai de mine : deux montants + traverse, brun sombre, pixel net.
    private func addMineStrut(in scene: SKScene, at pos: CGPoint) {
        let strut = SKNode()
        strut.zPosition = -2
        let wood = SKColor(red: 0.30, green: 0.21, blue: 0.11, alpha: 1)
        let dark = SKColor(red: 0.16, green: 0.11, blue: 0.06, alpha: 1)
        for dx: CGFloat in [-14, 14] {
            let post = SKSpriteNode(color: wood, size: CGSize(width: 7, height: 54))
            post.position = CGPoint(x: dx, y: 0)
            strut.addChild(post)
            let edge = SKSpriteNode(color: dark, size: CGSize(width: 2, height: 54))
            edge.position = CGPoint(x: dx + 3, y: 0)
            strut.addChild(edge)
        }
        let beam = SKSpriteNode(color: wood, size: CGSize(width: 42, height: 7))
        beam.position = CGPoint(x: 0, y: 28)
        strut.addChild(beam)
        let beamEdge = SKSpriteNode(color: dark, size: CGSize(width: 42, height: 2))
        beamEdge.position = CGPoint(x: 0, y: 25)
        strut.addChild(beamEdge)
        strut.position = pos
        add(strut, to: scene)
    }

    /// Lanterne de mineur : sprite + nappe de lumière chaude au sol.
    private func addMineLantern(in scene: SKScene, at pos: CGPoint) {
        let pool = SKShapeNode(ellipseOf: CGSize(width: 110, height: 54))
        pool.fillColor = SKColor(red: 0.95, green: 0.70, blue: 0.30, alpha: 0.07)
        pool.strokeColor = .clear
        pool.position = CGPoint(x: pos.x, y: pos.y + 4)
        pool.zPosition = -5
        add(pool, to: scene)
        JuiceEngine.pulse(pool, scale: 1.08)
        addPixelProp("village_lantern_1", in: scene, at: pos, scale: 0.5)
    }

    /// Crée un sprite de monstre baladeur (ennemi idle animé, teinté cendre,
    /// ancré aux pieds + ombre) SANS le placer — le GameManager le pilote via
    /// `RoamingMonster`. Renvoie nil si l'asset manque.
    func makeRoamingMonster(asset: String) -> SKNode? {
        guard let monster = PixelArtSprites.animated(
            name: asset, frames: 6, scale: 0.55,
            timePerFrame: 0.18, anchor: CGPoint(x: 0.5, y: 0.0)) else { return nil }
        monster.forEachDescendantSprite { s in
            s.color = SKColor(red: 0.48, green: 0.44, blue: 0.42, alpha: 1)
            s.colorBlendFactor = 0.22
        }
        addGroundShadow(under: monster, width: 26, height: 7)
        return monster
    }

    /// Monstre visible dans la galerie : sprite ennemi idle, teinté cendre.
    /// Plaque de bois gravée par les équipes de mineurs.
    private func makeMinersPlaque(at pos: CGPoint) -> SKNode {
        let node = SKNode()
        node.position = pos
        node.zPosition = 1

        let board = SKShapeNode(rectOf: CGSize(width: 64, height: 42), cornerRadius: 4)
        board.fillColor = SKColor(red: 0.24, green: 0.17, blue: 0.09, alpha: 1)
        board.strokeColor = SKColor(red: 0.45, green: 0.33, blue: 0.18, alpha: 0.9)
        board.lineWidth = 2
        node.addChild(board)

        for (y, width) in [(10, 40), (0, 46), (-10, 34)] {
            let line = SKShapeNode(rectOf: CGSize(width: CGFloat(width), height: 2), cornerRadius: 1)
            line.fillColor = SKColor(red: 0.60, green: 0.48, blue: 0.28, alpha: 0.7)
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: CGFloat(y))
            node.addChild(line)
        }

        let glow = SKShapeNode(rectOf: CGSize(width: 72, height: 50), cornerRadius: 6)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.85, green: 0.65, blue: 0.30, alpha: 0.15)
        glow.lineWidth = 4
        node.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.08)

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "world.mines.inscription")
        label.fontSize = 12
        label.fontColor = SKColor(white: 0.65, alpha: 0.8)
        label.position = CGPoint(x: 0, y: -36)
        node.addChild(label)
        return node
    }

    /// Veine d'or scintillante dans la paroi.
    private func makeGoldVein(at pos: CGPoint) -> SKNode {
        let node = SKNode()
        node.position = pos
        node.zPosition = 1

        let rock = SKShapeNode(rectOf: CGSize(width: 40, height: 26), cornerRadius: 6)
        rock.fillColor = SKColor(red: 0.14, green: 0.14, blue: 0.17, alpha: 1)
        rock.strokeColor = SKColor(red: 0.30, green: 0.30, blue: 0.35, alpha: 0.8)
        rock.lineWidth = 1.5
        node.addChild(rock)

        for (dx, dy) in [(-11, 4), (-2, -5), (7, 3), (13, -2)] {
            let fleck = SKSpriteNode(color: SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 1),
                                     size: CGSize(width: 4, height: 4))
            fleck.position = CGPoint(x: CGFloat(dx), y: CGFloat(dy))
            fleck.zRotation = .pi / 4
            node.addChild(fleck)
        }

        let glow = SKShapeNode(circleOfRadius: 24)
        glow.fillColor = SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 0.06)
        glow.strokeColor = SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 0.18)
        glow.lineWidth = 1
        node.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)
        return node
    }

    /// Retire la veine d'or (après ramassage).
    func removeGoldVein() {
        guard let vein = worldNode.childNode(withName: "minesGoldVein") else { return }
        vein.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Caverne aux Échos (donjon optionnel, entrée depuis la forêt)

    func switchToCave(in scene: SKScene, cleared: Bool, chestTaken: Bool) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)
        buildCave(in: scene, cleared: cleared, chestTaken: chestTaken)
        LightingEngine.applyGrade(.mines, in: scene)
        LightingEngine.attachHeroLight(to: kael)
        setZoneVignette(in: scene, alpha: 0.50)
        AudioEngine.shared.setAmbience(.mines)
    }

    /// Caverne aux Échos : cavité oubliée sous la forêt où les voix des
    /// anciens résonnent encore. Plein écran (pas de scroll). Une statue
    /// d'ange veille au fond, un gardien d'ossements barre l'accès au
    /// coffre. 100 % assets existants + coffre pixel dessiné en code.
    private func buildCave(in scene: SKScene, cleared: Bool, chestTaken: Bool) {
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
    private func addCaveChest(in scene: SKScene, at pos: CGPoint) {
        let chest = SKNode()
        chest.name = "caveChest"
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

    // MARK: - Désert d'Ossara (voyage depuis la carte du monde)

    func switchToDesert(in scene: SKScene, progress: Int = 0, chestTaken: Bool = false) {
        clearBackdrop()
        worldHeight = scene.size.height
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.42, green: 0.32, blue: 0.16, alpha: 1)
        buildDesert(in: scene, progress: progress, chestTaken: chestTaken)
    }

    /// Dunes brûlées d'Ossara : sable ocre, roches érodées, carcasses
    /// de caravanes, oasis au nord-est. Une hauteur d'écran, pas de scroll.
    private func buildDesert(in scene: SKScene, progress: Int, chestTaken: Bool) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : terre teintée sable chaud
        addTiledFloor(in: scene,
                      tileNames: ["a2_dirt"],
                      fallbackColor: SKColor(red: 0.72, green: 0.56, blue: 0.30, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.82, green: 0.66, blue: 0.36, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Titre de zone
        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.desert.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.45, green: 0.32, blue: 0.14, alpha: 0.8)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.90)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // Crêtes de dunes : bandes de sable clair qui ondulent
        for (y, alpha) in [(0.26, 0.35), (0.46, 0.28), (0.66, 0.32), (0.82, 0.25)] {
            let dune = SKShapeNode(rectOf: CGSize(width: w * 0.7, height: 5))
            dune.fillColor = SKColor(red: 0.92, green: 0.80, blue: 0.52, alpha: CGFloat(alpha))
            dune.strokeColor = .clear
            dune.position = CGPoint(x: w * CGFloat.random(in: 0.35...0.65),
                                    y: h * CGFloat(y))
            dune.zPosition = -8
            add(dune, to: scene)
        }

        // Roches érodées et pierres — le squelette du désert
        let rocks: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("rock_7", 0.10, 0.30, 0.70), ("rock_3", 0.34, 0.22, 0.60),
            ("rock_9", 0.64, 0.34, 0.65), ("rock_1", 0.90, 0.70, 0.60),
            ("rock_5", 0.22, 0.84, 0.55), ("gy_stone_1", 0.46, 0.44, 0.55),
            ("gy_stone_3", 0.70, 0.82, 0.55), ("ext_pebbles", 0.30, 0.62, 0.8),
            ("ext_pebbles", 0.58, 0.18, 0.8), ("ext_pebbles", 0.78, 0.42, 0.8)
        ]
        for (asset, x, y, s) in rocks {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
        }

        // Arbres morts calcinés par le soleil — gy_tree (mv_dead_tree est
        // une spritesheet entière, cf. forêt), petits et loin du HUD
        for (x, y, s) in [(0.07, 0.32, 0.55), (0.40, 0.32, 0.5), (0.70, 0.26, 0.5)] {
            guard let tree = PixelArtSprites.still(
                name: "gy_tree", scale: CGFloat(s),
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            tree.position = CGPoint(x: w * CGFloat(x), y: h * CGFloat(y))
            tree.zPosition = actorLayer(for: tree.position.y)
            tree.forEachDescendantSprite { sp in
                sp.color = SKColor(red: 0.62, green: 0.46, blue: 0.22, alpha: 1)
                sp.colorBlendFactor = 0.55
            }
            add(tree, to: scene)
        }

        // Ossements des caravanes perdues
        for p in [(0.36, 0.50), (0.62, 0.60), (0.20, 0.44), (0.74, 0.26)] {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: 2.0,
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            bones.position = CGPoint(x: w * p.0, y: h * p.1)
            bones.zPosition = -2
            bones.alpha = 0.85
            add(bones, to: scene)
        }

        // ── Oasis (nord-est) : bassin pixel + halo de fraîcheur ──
        addOasis(in: scene, at: CGPoint(x: w * 0.85, y: h * 0.20))

        // ── Monstres visibles aux zones de danger restantes ──
        if progress < 1 {
            let zone1 = makeDangerZone(
                at: CGPoint(x: w * 0.28, y: h * 0.55),
                radius: 38,
                color: SKColor(red: 0.70, green: 0.45, blue: 0.20, alpha: 1))
            zone1.name = "desertZone1"
            add(zone1, to: scene)
            addDesertMonster("enemy_ghoul", in: scene, at: CGPoint(x: w * 0.25, y: h * 0.57))
            addDesertMonster("enemy_ghoul", in: scene, at: CGPoint(x: w * 0.32, y: h * 0.52), flipped: true)
        }
        if progress == 1 {
            let zone2 = makeDangerZone(
                at: CGPoint(x: w * 0.55, y: h * 0.68),
                radius: 38,
                color: SKColor(red: 0.55, green: 0.40, blue: 0.25, alpha: 1))
            zone2.name = "desertZone2"
            add(zone2, to: scene)
            addDesertMonster("enemy_bone", in: scene, at: CGPoint(x: w * 0.52, y: h * 0.70))
            addDesertMonster("enemy_bone", in: scene, at: CGPoint(x: w * 0.59, y: h * 0.65), flipped: true)
            addDesertMonster("enemy_ghoul", in: scene, at: CGPoint(x: w * 0.55, y: h * 0.74))
        }
        if progress == 2 {
            let bossZone = makeDangerZone(
                at: CGPoint(x: w * 0.80, y: h * 0.55),
                radius: 40,
                color: SKColor(red: 0.85, green: 0.45, blue: 0.10, alpha: 1))
            bossZone.name = "desertZone3"
            add(bossZone, to: scene)
            addSandColossusSilhouette(in: scene, at: CGPoint(x: w * 0.80, y: h * 0.57))
        }

        // Coffre enfoui (flanc ouest) : les pillards ne l'ont jamais trouvé
        if !chestTaken {
            let chest = makeBuriedChest(at: CGPoint(x: w * 0.12, y: h * 0.56))
            chest.name = "desertChest"
            add(chest, to: scene)
        }

        // Sortie au sud : halo — retour vers la zone d'origine
        let exitGlow = SKShapeNode(circleOfRadius: 34)
        exitGlow.fillColor = SKColor(red: 0.55, green: 0.75, blue: 0.55, alpha: 0.10)
        exitGlow.strokeColor = SKColor(red: 0.70, green: 0.90, blue: 0.70, alpha: 0.25)
        exitGlow.lineWidth = 1.5
        exitGlow.position = CGPoint(x: w * 0.50, y: h * 0.08)
        add(exitGlow, to: scene)
        JuiceEngine.pulse(exitGlow, scale: 1.15)
        let exitLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        exitLabel.text = String(localized: "world.desert.exit")
        exitLabel.fontSize = 12
        exitLabel.fontColor = SKColor(red: 0.40, green: 0.28, blue: 0.12, alpha: 0.85)
        exitLabel.position = CGPoint(x: w * 0.50, y: h * 0.08 + 42)
        add(exitLabel, to: scene)

        // Poussière en suspension : chaleur d'Ossara + rares ombres de nuages
        let desertAmbiance = SKNode()
        desertAmbiance.addChild(ParticleFactory.ruinsAsh(in: scene.size))
        desertAmbiance.addChild(LightingEngine.cloudShadows(in: scene.size, count: 2))
        addAtmosphere(desertAmbiance, to: scene)
        setZoneVignette(in: scene, alpha: 0.30)   // plein soleil, vignette légère
        LightingEngine.applyGrade(.desert, in: scene)
        LightingEngine.startDayCycle(in: scene, day: .desert, phaseSeconds: 90)
        AudioEngine.shared.setAmbience(.desert)
    }

    /// Bassin d'oasis : eau pixel bordée de pierre, éclats de lumière.
    private func addOasis(in scene: SKScene, at pos: CGPoint) {
        let oasis = SKNode()
        oasis.name = "desertOasis"
        oasis.position = pos
        oasis.zPosition = -4

        let rim = SKShapeNode(rectOf: CGSize(width: 92, height: 62))
        rim.fillColor = SKColor(red: 0.52, green: 0.42, blue: 0.24, alpha: 1)
        rim.strokeColor = .clear
        oasis.addChild(rim)

        let water = SKShapeNode(rectOf: CGSize(width: 80, height: 50))
        water.fillColor = SKColor(red: 0.24, green: 0.62, blue: 0.72, alpha: 1)
        water.strokeColor = SKColor(red: 0.55, green: 0.85, blue: 0.90, alpha: 0.8)
        water.lineWidth = 1.5
        oasis.addChild(water)

        for (dx, dy) in [(-22, 10), (6, -8), (24, 6), (-8, 14)] {
            let sparkle = SKSpriteNode(color: SKColor(red: 0.80, green: 0.95, blue: 1.0, alpha: 0.9),
                                       size: CGSize(width: 3, height: 3))
            sparkle.position = CGPoint(x: CGFloat(dx), y: CGFloat(dy))
            oasis.addChild(sparkle)
            JuiceEngine.pulse(sparkle, scale: 1.5)
        }

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "world.desert.oasis")
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.30, green: 0.50, blue: 0.55, alpha: 0.9)
        label.position = CGPoint(x: 0, y: 40)
        oasis.addChild(label)

        add(oasis, to: scene)
    }

    /// Monstre visible dans les dunes : sprite ennemi idle, teinté sable.
    private func addDesertMonster(_ asset: String, in scene: SKScene,
                                  at pos: CGPoint, flipped: Bool = false) {
        guard let monster = PixelArtSprites.animated(
            name: asset, frames: 6, scale: 0.55,
            timePerFrame: 0.18, anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        monster.position = pos
        monster.zPosition = actorLayer(for: pos.y)
        if flipped { monster.xScale = -abs(monster.xScale) }
        monster.forEachDescendantSprite { s in
            s.color = SKColor(red: 0.85, green: 0.66, blue: 0.32, alpha: 1)
            s.colorBlendFactor = 0.50
        }
        addGroundShadow(under: monster, width: 26, height: 7)
        add(monster, to: scene)
    }

    /// Silhouette du colosse des sables endormi : masse de grès,
    /// deux yeux d'ambre qui couvent sous la croûte.
    private func addSandColossusSilhouette(in scene: SKScene, at pos: CGPoint) {
        let colossus = SKNode()
        colossus.zPosition = actorLayer(for: pos.y)
        let body = SKColor(red: 0.55, green: 0.42, blue: 0.22, alpha: 1)
        for (dx, dy, sw, sh) in [(0.0, 20.0, 52.0, 42.0), (-24.0, 5.0, 24.0, 24.0),
                                 (24.0, 5.0, 24.0, 24.0), (0.0, 50.0, 34.0, 24.0)] {
            let block = SKSpriteNode(color: body, size: CGSize(width: sw, height: sh))
            block.position = CGPoint(x: dx, y: dy)
            colossus.addChild(block)
        }
        for dx: CGFloat in [-8, 8] {
            let eye = SKSpriteNode(color: SKColor(red: 1.0, green: 0.70, blue: 0.20, alpha: 1),
                                   size: CGSize(width: 5, height: 5))
            eye.position = CGPoint(x: dx, y: 52)
            colossus.addChild(eye)
            JuiceEngine.pulse(eye, scale: 1.3)
        }
        colossus.position = pos
        addGroundShadow(under: colossus, width: 58, height: 13)
        add(colossus, to: scene)
    }

    /// Coffre à demi enfoui dans le sable, cerclé de fer.
    private func makeBuriedChest(at pos: CGPoint) -> SKNode {
        let node = SKNode()
        node.position = pos
        node.zPosition = 1

        // Monticule de sable
        let mound = SKShapeNode(rectOf: CGSize(width: 52, height: 12))
        mound.fillColor = SKColor(red: 0.88, green: 0.74, blue: 0.44, alpha: 1)
        mound.strokeColor = .clear
        mound.position = CGPoint(x: 0, y: -8)
        node.addChild(mound)

        // Couvercle visible du coffre
        let lid = SKShapeNode(rectOf: CGSize(width: 34, height: 16))
        lid.fillColor = SKColor(red: 0.36, green: 0.22, blue: 0.10, alpha: 1)
        lid.strokeColor = SKColor(red: 0.20, green: 0.12, blue: 0.05, alpha: 1)
        lid.lineWidth = 1.5
        lid.position = CGPoint(x: 0, y: 2)
        node.addChild(lid)

        for dx: CGFloat in [-10, 10] {
            let band = SKSpriteNode(color: SKColor(red: 0.62, green: 0.58, blue: 0.50, alpha: 1),
                                    size: CGSize(width: 3, height: 16))
            band.position = CGPoint(x: dx, y: 2)
            node.addChild(band)
        }

        let glow = SKShapeNode(circleOfRadius: 26)
        glow.fillColor = SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 0.06)
        glow.strokeColor = SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 0.18)
        glow.lineWidth = 1
        node.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)
        return node
    }

    /// Retire le coffre enfoui (après ramassage).
    func removeBuriedChest() {
        guard let chest = worldNode.childNode(withName: "desertChest") else { return }
        chest.run(.sequence([
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.1, duration: 0.3)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Ruines de la Source (Acte II)

    private func buildRuins(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : dalles de pierre teintées rouge-brun (la Source corrompue)
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.07, green: 0.04, blue: 0.04, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.30, green: 0.14, blue: 0.10, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Fissures d'Aether rouge dans le sol
        let crackPositions: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.20, 0.25, 0.38, 0.32), (0.45, 0.18, 0.58, 0.30),
            (0.62, 0.42, 0.78, 0.50), (0.15, 0.55, 0.32, 0.63),
            (0.50, 0.65, 0.68, 0.72)
        ]
        for (x1, y1, x2, y2) in crackPositions {
            let crack = makeCrack(from: CGPoint(x: w * x1, y: h * y1),
                                  to:   CGPoint(x: w * x2, y: h * y2))
            add(crack, to: scene)
        }

        // ── VESTIGES : chapelle effondrée, maison en ruine, portail brisé ──
        addPixelProp("house_ruins_1", in: scene, at: CGPoint(x: w * 0.50, y: h * 0.78), scale: 0.62)
        addPixelProp("gy_gate_high", in: scene, at: CGPoint(x: w * 0.08, y: h * 0.76), scale: 0.48)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.90, y: h * 0.74), scale: 0.52, flipped: true)

        // Colonnes brisées cadrant les zones de combat (échelle pixel : ×2
        // sur du 16×32 natif → 32×64 pt, net, plus d'étirement flou)
        for (px, py) in [(0.10, 0.42), (0.38, 0.50), (0.72, 0.52), (0.90, 0.40)] {
            addPixelProp("column_broken_1", in: scene,
                         at: CGPoint(x: w * CGFloat(px), y: h * CGFloat(py)), scale: 2.0)
        }
        addPixelProp("pillar_grey_1", in: scene, at: CGPoint(x: w * 0.24, y: h * 0.30), scale: 1.8)
        addPixelProp("pillar_grey_2", in: scene, at: CGPoint(x: w * 0.66, y: h * 0.26), scale: 1.8)

        // ── CIMETIÈRE PROFANÉ : tombes de bois, croix, chandeliers éteints ──
        let relics: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("gy_grave_wood", 0.20, 0.36, 0.55), ("gy_cross_wood", 0.34, 0.28, 0.55),
            ("gy_tomb_brown", 0.48, 0.34, 0.55), ("gy_grave_wood", 0.58, 0.26, 0.50),
            ("gy_cross_wood", 0.76, 0.34, 0.55), ("gy_tomb_brown", 0.86, 0.28, 0.55),
            ("gy_candle_off", 0.30, 0.58, 0.50), ("gy_candle_off", 0.56, 0.54, 0.50),
            ("gy_stone_1", 0.42, 0.42, 0.50), ("gy_stone_3", 0.68, 0.44, 0.50),
            ("gy_stone_2", 0.16, 0.30, 0.50)
        ]
        for (asset, x, y, s) in relics {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
        }

        // Ossements nets à l'échelle pixel (16×32 natif → ×2)
        for p in [(0.30, 0.44), (0.65, 0.38), (0.45, 0.62)] {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: 2.0,
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            bones.position = CGPoint(x: w * p.0, y: h * p.1)
            bones.zPosition = -2
            bones.alpha = 0.9
            add(bones, to: scene)
        }

        // Titre de zone
        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.ruins.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.70, green: 0.25, blue: 0.25, alpha: 0.60)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.90)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // Zone combat 1 : Gardiens (centre-gauche)
        let zone1 = makeDangerZone(
            at: CGPoint(x: w * 0.28, y: h * 0.50),
            radius: 38,
            color: SKColor(red: 0.70, green: 0.15, blue: 0.10, alpha: 1)
        )
        add(zone1, to: scene)

        // Zone combat 2 : Âmes piégées (centre-droite)
        let zone2 = makeDangerZone(
            at: CGPoint(x: w * 0.62, y: h * 0.60),
            radius: 38,
            color: SKColor(red: 0.55, green: 0.10, blue: 0.35, alpha: 1)
        )
        add(zone2, to: scene)

        // Inscription secondaire d'Eran (coins bas-gauche)
        let eranInscription = makeEranInscription(at: CGPoint(x: w * 0.15, y: h * 0.65))
        add(eranInscription, to: scene)

        // Mur d'inscription (discovery) — haut-droite
        let inscriptionWall = makeInscriptionWall(
            at: CGPoint(x: w * 0.70, y: h * 0.65)
        )
        add(inscriptionWall, to: scene)

        // Mares d'Aether rouge (ambiance)
        for (px, py) in [(0.15, 0.38), (0.55, 0.35), (0.82, 0.42)] {
            let pool = makeRedAetherPool(at: CGPoint(x: w * px, y: h * py))
            add(pool, to: scene)
        }

        // Cristal de sauvegarde (entrée des ruines, bas droite)
        addSaveCrystal(at: CGPoint(x: w * 0.88, y: h * 0.22), in: scene)

        addAtmosphere(ParticleFactory.ruinsAsh(in: scene.size), to: scene)
        setZoneVignette(in: scene, alpha: 0.45)
        LightingEngine.applyGrade(.ruins, in: scene)
        AudioEngine.shared.setAmbience(.none)   // la musique porte l'ambiance
    }

    /// LE SEUIL (Acte III) — arène finale. Uniquement des assets existants :
    /// sol pierre teinté vide, escalier central (le Seuil), statues d'anges
    /// gardiens, piliers, arbres morts et ossements. Aucune forme custom.
    private func buildThreshold(in scene: SKScene,
                                echoJoined: Bool = false,
                                spiritsCalmed: Set<String> = [],
                                shadesDefeated: Bool = false) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : pierre a2 teintée bleu-vide très sombre
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.06, green: 0.05, blue: 0.12, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.16, green: 0.13, blue: 0.30, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Titre de zone
        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.threshold.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.55, green: 0.45, blue: 0.85, alpha: 0.65)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.93)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // ── LE SEUIL : portail à orbe rouge au sommet de l'escalier ──
        addPixelProp("me_stairs", in: scene,
                     at: CGPoint(x: w * 0.50, y: h * 0.70), scale: 0.60)
        addPixelProp("gy_gate_big", in: scene,
                     at: CGPoint(x: w * 0.50, y: h * 0.84), scale: 0.55)
        let voidGlow = SKShapeNode(circleOfRadius: 52)
        voidGlow.fillColor = SKColor(red: 0.30, green: 0.08, blue: 0.45, alpha: 0.10)
        voidGlow.strokeColor = SKColor(red: 0.55, green: 0.20, blue: 0.85, alpha: 0.30)
        voidGlow.lineWidth = 1.5
        voidGlow.glowWidth = 8
        voidGlow.position = CGPoint(x: w * 0.50, y: h * 0.90)
        voidGlow.zPosition = -2
        add(voidGlow, to: scene)
        JuiceEngine.pulse(voidGlow, scale: 1.2)

        // Statues d'anges gardiens flanquant le Seuil (échelle pixel nette)
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.36, y: h * 0.80), scale: 0.24)
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.64, y: h * 0.80), scale: 0.24, flipped: true)

        // Allée de chandeliers spectraux + colonnes cadrant l'arène
        for (i, py) in [CGFloat(0.40), 0.55, 0.70].enumerated() {
            if i % 2 == 0 {
                addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * 0.14, y: h * py), scale: 0.55)
                addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * 0.86, y: h * py), scale: 0.55)
            } else {
                addPixelProp("column_broken_1", in: scene, at: CGPoint(x: w * 0.14, y: h * py), scale: 2.0)
                addPixelProp("column_broken_1", in: scene, at: CGPoint(x: w * 0.86, y: h * py), scale: 2.0)
            }
        }

        // Arches brisées + arbres morts (le Vide consume la vie)
        addPixelProp("gy_gate_high", in: scene, at: CGPoint(x: w * 0.10, y: h * 0.26), scale: 0.45)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.90, y: h * 0.26), scale: 0.50, flipped: true)

        // Tombes des âmes absorbées + ossements nets
        for (asset, px, py) in [("gy_tomb_black", 0.24, 0.34), ("gy_cross_black", 0.42, 0.26),
                                ("gy_tomb_grey_2", 0.60, 0.32), ("gy_tomb_black", 0.76, 0.28)] {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * CGFloat(px), y: h * CGFloat(py)), scale: 0.55)
        }
        for p in [(0.30, 0.45), (0.66, 0.42), (0.48, 0.30)] {
            guard let bones = PixelArtSprites.still(
                name: "bones_1", scale: 2.0,
                anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
            bones.position = CGPoint(x: w * p.0, y: h * p.1)
            bones.zPosition = -2
            bones.alpha = 0.85
            add(bones, to: scene)
        }

        // Marqueur de rencontre Eran (centre) — réutilise makeDangerZone (bleu)
        let eranMark = makeDangerZone(
            at: CGPoint(x: w * 0.50, y: h * 0.62), radius: 34,
            color: SKColor(red: 0.40, green: 0.55, blue: 0.95, alpha: 1))
        add(eranMark, to: scene)

        // ── L'Écho de Lyra attend à l'entrée tant qu'il n'a pas rejoint ──
        if !echoJoined {
            addThresholdEcho(in: scene, at: CGPoint(x: w * 0.30, y: h * 0.20))
        }

        // ── Esprits errants (quête « Les échos égarés ») ──
        // Ils déambulent seuls ; apaisés, ils disparaissent du Seuil.
        let spiritDefs: [(id: String, asset: String, x: CGFloat, y: CGFloat)] = [
            ("miner",  "npc_villager", 0.20, 0.48),
            ("mother", "npc_mara",     0.72, 0.50),
            ("guard",  "npc_garen",    0.55, 0.38)
        ]
        for def in spiritDefs where !spiritsCalmed.contains(def.id) {
            addWanderingSpirit(id: def.id, asset: def.asset, in: scene,
                               at: CGPoint(x: w * def.x, y: h * def.y))
        }

        // ── Ombres hostiles : échos corrompus qui refusent l'apaisement ──
        if !shadesDefeated {
            let shadeZone = makeDangerZone(
                at: CGPoint(x: w * 0.22, y: h * 0.64), radius: 36,
                color: SKColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 1))
            add(shadeZone, to: scene)
            for (dx, flip) in [(-0.03, false), (0.04, true)] {
                guard let shade = PixelArtSprites.animated(
                    name: "enemy_bone", frames: 6, scale: 0.5,
                    timePerFrame: 0.2, anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
                shade.position = CGPoint(x: w * (0.22 + dx), y: h * 0.66)
                shade.zPosition = actorLayer(for: shade.position.y)
                if flip { shade.xScale = -abs(shade.xScale) }
                shade.alpha = 0.65
                shade.forEachDescendantSprite { sp in
                    sp.color = SKColor(red: 0.35, green: 0.15, blue: 0.55, alpha: 1)
                    sp.colorBlendFactor = 0.55
                }
                add(shade, to: scene)
            }
        }

        // Cristal de sauvegarde (entrée du Seuil, bas droite)
        addSaveCrystal(at: CGPoint(x: w * 0.85, y: h * 0.20), in: scene)

        addAtmosphere(ParticleFactory.ruinsAsh(in: scene.size), to: scene)
        setZoneVignette(in: scene, alpha: 0.45)
        LightingEngine.applyGrade(.threshold, in: scene)
        AudioEngine.shared.setAmbience(.none)
    }

    /// LE CŒUR DU VIDE (Acte IV) — sanctuaire intérieur. Sol pierre teinté
    /// pourpre profond, Cœur central (orbe pulsé au sommet de l'escalier),
    /// fragments de mémoire, reflets absorbés, dévoreurs d'échos.
    private func buildVoidHeart(in scene: SKScene,
                                reflectionsFreed: Set<String> = [],
                                devourersDefeated: Bool = false,
                                bossDefeated: Bool = false) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : pierre a2 teintée pourpre — plus profond que le Seuil
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.05, green: 0.02, blue: 0.09, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.22, green: 0.10, blue: 0.32, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Titre de zone
        let zoneLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        zoneLabel.text = String(localized: "world.voidheart.title")
        zoneLabel.fontSize = 14
        zoneLabel.fontColor = SKColor(red: 0.75, green: 0.45, blue: 0.90, alpha: 0.65)
        zoneLabel.position = CGPoint(x: w * 0.50, y: h * 0.93)
        zoneLabel.zPosition = -1
        add(zoneLabel, to: scene)

        // ── LE CŒUR : orbe géant au sommet de l'escalier central ──
        addPixelProp("me_stairs", in: scene,
                     at: CGPoint(x: w * 0.50, y: h * 0.70), scale: 0.60)
        let heart = SKShapeNode(circleOfRadius: bossDefeated ? 34 : 46)
        let heartColor: SKColor = bossDefeated
            ? SKColor(red: 0.40, green: 0.85, blue: 0.95, alpha: 1)   // apaisé : cyan
            : SKColor(red: 0.85, green: 0.25, blue: 0.95, alpha: 1)   // actif : pourpre
        heart.fillColor = heartColor.withAlphaComponent(0.16)
        heart.strokeColor = heartColor.withAlphaComponent(0.55)
        heart.lineWidth = 2
        heart.glowWidth = 10
        heart.name = "voidHeartCore"
        heart.position = CGPoint(x: w * 0.50, y: h * 0.86)
        heart.zPosition = -2
        add(heart, to: scene)
        JuiceEngine.pulse(heart, scale: bossDefeated ? 1.06 : 1.25)

        // Anneau de colonnes brisées autour du Cœur
        for (px, py, flip) in [(0.30, 0.78, false), (0.70, 0.78, true),
                               (0.22, 0.60, false), (0.78, 0.60, true)] {
            addPixelProp("column_broken_1", in: scene,
                         at: CGPoint(x: w * CGFloat(px), y: h * CGFloat(py)),
                         scale: 2.0, flipped: flip)
        }

        // Statues d'anges renversées — les gardiens sont tombés ici
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.40, y: h * 0.52), scale: 0.24)
        addPixelProp("me_statue_angel", in: scene,
                     at: CGPoint(x: w * 0.60, y: h * 0.52), scale: 0.24, flipped: true)

        // Fissures d'énergie convergeant vers le Cœur + mares d'Aether
        for (px, py) in [(0.18, 0.40), (0.82, 0.44), (0.50, 0.28)] {
            add(makeCrack(from: CGPoint(x: w * px, y: h * py),
                          to: CGPoint(x: w * 0.50, y: h * 0.74)), to: scene)
        }
        for (px, py) in [(0.14, 0.30), (0.86, 0.34)] {
            add(makeRedAetherPool(at: CGPoint(x: w * px, y: h * py)), to: scene)
        }

        // ── Fragments de mémoire (quête « Les souvenirs de Kael ») ──
        // Chandelles spectrales aux trois points d'examen — toujours
        // visibles ; l'état "vu" ne gate que l'interaction.
        for (px, py) in [(0.20, 0.46), (0.62, 0.30), (0.80, 0.52)] {
            addPixelProp("gy_candle", in: scene,
                         at: CGPoint(x: w * px, y: h * py), scale: 0.55)
            let mGlow = SKShapeNode(circleOfRadius: 16)
            mGlow.fillColor = SKColor(red: 0.45, green: 0.90, blue: 0.95, alpha: 0.08)
            mGlow.strokeColor = SKColor(red: 0.45, green: 0.90, blue: 0.95, alpha: 0.30)
            mGlow.lineWidth = 1
            mGlow.glowWidth = 4
            mGlow.position = CGPoint(x: w * px, y: h * py)
            mGlow.zPosition = -3
            add(mGlow, to: scene)
            JuiceEngine.pulse(mGlow, scale: 1.15)
        }

        // ── Reflets absorbés (quête « Les visages du Vide ») ──
        let reflectionDefs: [(id: String, asset: String, x: CGFloat, y: CGFloat)] = [
            ("elder", "npc_dorin", 0.28, 0.36),
            ("smith", "npc_bram",  0.68, 0.44),
            ("lost",  "npc_child", 0.46, 0.24)
        ]
        for def in reflectionDefs where !reflectionsFreed.contains(def.id) {
            addWanderingSpirit(id: def.id, asset: def.asset, in: scene,
                               at: CGPoint(x: w * def.x, y: h * def.y))
        }

        // ── Dévoreurs d'échos : combat annexe ──
        if !devourersDefeated {
            let devourZone = makeDangerZone(
                at: CGPoint(x: w * 0.80, y: h * 0.66), radius: 36,
                color: SKColor(red: 0.85, green: 0.25, blue: 0.60, alpha: 1))
            add(devourZone, to: scene)
            for (dx, flip) in [(-0.03, false), (0.04, true)] {
                guard let devourer = PixelArtSprites.animated(
                    name: "enemy_bone", frames: 6, scale: 0.5,
                    timePerFrame: 0.18, anchor: CGPoint(x: 0.5, y: 0.0)) else { continue }
                devourer.position = CGPoint(x: w * (0.80 + dx), y: h * 0.68)
                devourer.zPosition = actorLayer(for: devourer.position.y)
                if flip { devourer.xScale = -abs(devourer.xScale) }
                devourer.alpha = 0.70
                devourer.forEachDescendantSprite { sp in
                    sp.color = SKColor(red: 0.55, green: 0.12, blue: 0.40, alpha: 1)
                    sp.colorBlendFactor = 0.60
                }
                add(devourer, to: scene)
            }
        }

        // Marqueur de confrontation de la Voix (devant l'escalier)
        if !bossDefeated {
            let voiceMark = makeDangerZone(
                at: CGPoint(x: w * 0.50, y: h * 0.58), radius: 34,
                color: SKColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 1))
            add(voiceMark, to: scene)
        }

        // Cristal de sauvegarde (entrée, bas gauche)
        addSaveCrystal(at: CGPoint(x: w * 0.14, y: h * 0.18), in: scene)

        addAtmosphere(ParticleFactory.ruinsAsh(in: scene.size), to: scene)
        setZoneVignette(in: scene, alpha: 0.50)
        LightingEngine.applyGrade(.voidheart, in: scene)
        AudioEngine.shared.setAmbience(.none)
    }

    /// L'Écho de Lyra, immobile et scintillant, attend Kael à l'entrée.
    private func addThresholdEcho(in scene: SKScene, at pos: CGPoint) {
        guard let echo = PixelArtSprites.animated(
            name: "npc_lyra", frames: 6, scale: 0.5,
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
    private func addWanderingSpirit(id: String, asset: String,
                                    in scene: SKScene, at anchor: CGPoint) {
        guard let spirit = PixelArtSprites.animated(
            name: asset, frames: 6, scale: 0.5,
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

    private func makeCrack(from start: CGPoint, to end: CGPoint) -> SKNode {
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

    private func makeInscriptionWall(at pos: CGPoint) -> SKNode {
        let wall = SKNode()
        wall.position = pos
        wall.zPosition = 1

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

    private func makeEranInscription(at pos: CGPoint) -> SKNode {
        let wall = SKNode()
        wall.position = pos
        wall.zPosition = 1

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

    private func makeRedAetherPool(at pos: CGPoint) -> SKNode {
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

    // MARK: - Sanctuaire

    /// SANCTUAIRE DE LA SOURCE (Acte I) — parvis de dalles violettes,
    /// allée de chandeliers vers la chapelle gothique à l'est, portail à
    /// orbe rouge = seuil du boss (trigger gameplay : x > 0.55w).
    private func buildShrine(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : dalles de pierre teintées violet nuit
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.20, green: 0.12, blue: 0.34, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Allée processionnelle ouest→est (dalles plus claires vers le boss)
        let tile: CGFloat = 24
        for c in 0..<Int(ceil(w * 0.70 / tile)) {
            for r in 0..<3 {
                guard let t = PixelArtSprites.still(name: "a2_stone", scale: 0.5,
                                                     anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
                t.position = CGPoint(x: (CGFloat(c) + 0.5) * tile,
                                      y: h * 0.44 + (CGFloat(r) + 0.5) * tile)
                t.zPosition = -9.5
                t.forEachDescendantSprite { sprite in
                    sprite.color = SKColor(red: 0.42, green: 0.34, blue: 0.58, alpha: 1)
                    sprite.colorBlendFactor = 0.35
                }
                add(t, to: scene)
            }
        }

        // ── CHAPELLE DE LA SOURCE (fond est) + portail à orbe rouge ──
        addPixelProp("gy_chapel", in: scene, at: CGPoint(x: w * 0.84, y: h * 0.42), scale: 0.55)
        addPixelProp("gy_gate_big", in: scene, at: CGPoint(x: w * 0.66, y: h * 0.42), scale: 0.50)
        // Halo rouge menaçant sur le portail (le Gardien attend derrière)
        let menace = SKShapeNode(circleOfRadius: 46)
        menace.fillColor = SKColor(red: 0.65, green: 0.10, blue: 0.12, alpha: 0.10)
        menace.strokeColor = SKColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 0.30)
        menace.lineWidth = 1.5
        menace.glowWidth = 6
        menace.position = CGPoint(x: w * 0.66, y: h * 0.53)
        menace.zPosition = -2
        add(menace, to: scene)
        JuiceEngine.pulse(menace, scale: 1.25)

        // Statues anges gardant le portail
        addPixelProp("me_statue_angel", in: scene, at: CGPoint(x: w * 0.58, y: h * 0.30), scale: 0.22)
        addPixelProp("me_statue_angel", in: scene, at: CGPoint(x: w * 0.58, y: h * 0.58), scale: 0.22, flipped: true)

        // ── ALLÉE DE CHANDELIERS (guident vers l'est) ──
        for x in [0.16, 0.32, 0.48] {
            addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * CGFloat(x), y: h * 0.56), scale: 0.55)
            addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * CGFloat(x), y: h * 0.32), scale: 0.55)
        }

        // ── CIMETIÈRE ANCIEN (sud + nord du parvis) ──
        let graves: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("gy_cross_grey", 0.10, 0.72, 0.55), ("gy_tomb_grey_1", 0.20, 0.78, 0.55),
            ("gy_tomb_black", 0.30, 0.70, 0.55), ("gy_tomb_grey_2", 0.42, 0.76, 0.55),
            ("gy_cross_black", 0.54, 0.72, 0.55), ("gy_tomb_grey_1", 0.66, 0.78, 0.55),
            ("gy_tomb_grey_2", 0.12, 0.14, 0.55), ("gy_cross_grey", 0.26, 0.10, 0.55),
            ("gy_tomb_black", 0.40, 0.14, 0.55), ("gy_tomb_grey_1", 0.52, 0.10, 0.55),
            ("gy_stone_1", 0.35, 0.24, 0.50), ("gy_stone_2", 0.60, 0.68, 0.50),
            ("gy_stone_3", 0.08, 0.40, 0.50)
        ]
        for (asset, x, y, s) in graves {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
        }

        // Arbres morts tordus (la Source se meurt)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.06, y: h * 0.80), scale: 0.55)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.30, y: h * 0.86), scale: 0.48, flipped: true)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.10, y: h * 0.04), scale: 0.50)

        // Cristal de sauvegarde (entrée ouest — safe spot avant le boss)
        addSaveCrystal(at: CGPoint(x: w * 0.18, y: h * 0.20), in: scene)

        addAtmosphere(ParticleFactory.shrineAura(in: scene.size), to: scene)
        setZoneVignette(in: scene, alpha: 0.40)
        LightingEngine.applyGrade(.shrine, in: scene)
        AudioEngine.shared.setAmbience(.none)
    }

    // MARK: - Building Blocks

    private func makeBuilding(w: CGFloat, h: CGFloat, wallColor: SKColor, roofColor: SKColor, label: String?) -> SKNode {
        let bld = SKNode()

        let wall = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 4)
        wall.fillColor = wallColor
        wall.strokeColor = SKColor(white: 0.22, alpha: 0.5)
        wall.lineWidth = 1
        bld.addChild(wall)

        let roof = SKShapeNode(rectOf: CGSize(width: w + 12, height: 14), cornerRadius: 3)
        roof.fillColor = roofColor
        roof.strokeColor = .clear
        roof.position = CGPoint(x: 0, y: h / 2 + 5)
        bld.addChild(roof)

        let door = SKShapeNode(rectOf: CGSize(width: 12, height: 18), cornerRadius: 2)
        door.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1)
        door.strokeColor = SKColor(white: 0.18, alpha: 0.5)
        door.lineWidth = 1
        door.position = CGPoint(x: 0, y: -h / 2 + 9)
        bld.addChild(door)

        let winL = SKShapeNode(rectOf: CGSize(width: 10, height: 8), cornerRadius: 2)
        winL.fillColor = SKColor(red: 0.60, green: 0.50, blue: 0.25, alpha: 0.2)
        winL.strokeColor = SKColor(white: 0.30, alpha: 0.4)
        winL.position = CGPoint(x: -w * 0.28, y: 4)
        bld.addChild(winL)

        let winR = SKShapeNode(rectOf: CGSize(width: 10, height: 8), cornerRadius: 2)
        winR.fillColor = winL.fillColor
        winR.strokeColor = winL.strokeColor
        winR.position = CGPoint(x: w * 0.28, y: 4)
        bld.addChild(winR)

        if let lbl = label {
            let sign = SKLabelNode(text: lbl)
            sign.fontSize = 16
            sign.position = CGPoint(x: 0, y: h / 2 + 20)
            bld.addChild(sign)
        }

        return bld
    }

    private func buildNorthGate(at pos: CGPoint, width: CGFloat, in scene: SKScene) {
        let gate = SKNode()
        gate.position = pos
        gate.zPosition = propLayer(for: pos.y, in: scene.size.height)
        addGroundShadow(under: gate, width: width + 32, height: 14)

        // Portail en pierre du pack (fini les piliers programmatiques)
        if let arch = PixelArtSprites.still(name: "gy_gate_big", scale: 0.55,
                                            anchor: CGPoint(x: 0.5, y: 0.0)) {
            arch.position = CGPoint(x: 0, y: -18)
            gate.addChild(arch)
        }

        let northSign = SKLabelNode(fontNamed: PixelUI.uiFont)
        northSign.text = String(localized: "world.northGate")
        northSign.fontSize = 13
        northSign.fontColor = SKColor(red: 0.86, green: 0.80, blue: 0.62, alpha: 1)
        northSign.position = CGPoint(x: 0, y: 118)
        gate.addChild(northSign)

        add(gate, to: scene)
    }

    private func buildWell(at pos: CGPoint, in scene: SKScene) {
        let well = SKNode()
        well.position = pos
        well.zPosition = propLayer(for: pos.y, in: scene.size.height)
        addGroundShadow(under: well, width: 42, height: 16)

        let base = SKShapeNode(circleOfRadius: 14)
        base.fillColor = SKColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1)
        base.strokeColor = SKColor(white: 0.28, alpha: 0.5)
        base.lineWidth = 2
        well.addChild(base)

        let water = SKShapeNode(circleOfRadius: 10)
        water.fillColor = SKColor(red: 0.10, green: 0.25, blue: 0.40, alpha: 0.8)
        water.strokeColor = .clear
        well.addChild(water)

        let glow = SKShapeNode(circleOfRadius: 10)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.30, green: 0.55, blue: 0.80, alpha: 0.15)
        glow.lineWidth = 2
        well.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)

        add(well, to: scene)
        registerObstacle(CGRect(x: pos.x - 15, y: pos.y - 15, width: 30, height: 30))
    }

    private func makeTorch() -> SKNode {
        let torch = SKNode()
        torch.zPosition = -3

        let pole = SKShapeNode(rectOf: CGSize(width: 3, height: 28), cornerRadius: 1)
        pole.fillColor = SKColor(red: 0.30, green: 0.20, blue: 0.10, alpha: 1)
        pole.strokeColor = .clear
        torch.addChild(pole)

        let flame = SKShapeNode(circleOfRadius: 5)
        flame.fillColor = SKColor(red: 0.90, green: 0.55, blue: 0.15, alpha: 0.9)
        flame.strokeColor = .clear
        flame.glowWidth = 6
        flame.position = CGPoint(x: 0, y: 18)
        torch.addChild(flame)
        JuiceEngine.pulse(flame, scale: 1.4)

        let glow = SKShapeNode(circleOfRadius: 30)
        glow.fillColor = SKColor(red: 0.80, green: 0.50, blue: 0.15, alpha: 0.04)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: 18)
        torch.addChild(glow)

        return torch
    }

    private func makeTree(height: CGFloat) -> SKNode {
        let tree = SKNode()
        tree.zPosition = -4

        let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: height * 0.4), cornerRadius: 2)
        trunk.fillColor = SKColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 1)
        trunk.strokeColor = .clear
        tree.addChild(trunk)

        let colors: [SKColor] = [
            SKColor(red: 0.08, green: 0.20, blue: 0.10, alpha: 1),
            SKColor(red: 0.06, green: 0.18, blue: 0.08, alpha: 1),
            SKColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 1)
        ]
        for i in 0..<3 {
            let leaf = SKShapeNode(circleOfRadius: CGFloat(18 - i * 4))
            leaf.fillColor = colors[i]
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: 0, y: height * 0.2 + CGFloat(i) * 14)
            tree.addChild(leaf)
        }

        return tree
    }

    private func addGroundShadow(under node: SKNode, width: CGFloat, height: CGFloat) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        shadow.fillColor = SKColor.black.withAlphaComponent(0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 3)
        shadow.zPosition = -0.5
        node.addChild(shadow)
    }

    /// Profondeur acteurs : plage [20, 40], normalisée par la hauteur du
    /// MONDE (pas de l'écran) — sinon tout y > ~1,3 écran passe sous le sol.
    private func actorLayer(for y: CGFloat) -> CGFloat {
        let span = worldHeight > 0 ? worldHeight : 402
        return 40 - (y / span) * 20
    }

    /// Profondeur props : plage [-2, -8], même normalisation monde.
    private func propLayer(for y: CGFloat, in sceneHeight: CGFloat) -> CGFloat {
        let span = worldHeight > 0 ? worldHeight : max(sceneHeight, 1)
        return -2 - (y / span) * 6
    }

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
        setZoneVignette(in: scene, alpha: 0.38)   // pièce éclairée au feu
        LightingEngine.applyGrade(.interior, in: scene)
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

    private func buildInterior(_ kind: HouseInteriorKind, in scene: SKScene) {
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
    private func interiorPlankPalette(for kind: HouseInteriorKind) -> [UIColor] {
        switch kind {
        case .armory:
            // Noyer sombre de forge
            return [UIColor(red: 0.34, green: 0.24, blue: 0.16, alpha: 1),
                    UIColor(red: 0.30, green: 0.21, blue: 0.14, alpha: 1),
                    UIColor(red: 0.26, green: 0.18, blue: 0.12, alpha: 1),
                    UIColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 1)]
        case .apothecary:
            // Bois patiné aux reflets verdis (herboristerie)
            return [UIColor(red: 0.30, green: 0.26, blue: 0.16, alpha: 1),
                    UIColor(red: 0.26, green: 0.23, blue: 0.14, alpha: 1),
                    UIColor(red: 0.22, green: 0.20, blue: 0.12, alpha: 1),
                    UIColor(red: 0.10, green: 0.09, blue: 0.05, alpha: 1)]
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
    private func addInteriorWalls(in scene: SKScene, room: CGRect, kind: HouseInteriorKind) {
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

    private func addInteriorExitDoor(in scene: SKScene, room: CGRect) {
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

    private func addInteriorTitle(_ kind: HouseInteriorKind, in scene: SKScene, room: CGRect) {
        let title = SKLabelNode(fontNamed: PixelUI.uiFont)
        switch kind {
        case .armory: title.text = String(localized: "interior.armory.title")
        case .apothecary: title.text = String(localized: "interior.apothecary.title")
        case .inn: title.text = String(localized: "interior.inn.title")
        }
        title.fontSize = 15
        title.fontColor = SKColor(red: 0.88, green: 0.78, blue: 0.58, alpha: 0.95)
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: room.midX, y: room.maxY - 36)
        title.zPosition = 4
        add(title, to: scene)
    }


    private func addInteriorSprite(_ name: String, in scene: SKScene, at position: CGPoint,
                                   scale: CGFloat, flipped: Bool = false) {
        guard let node = PixelArtSprites.still(name: name, scale: scale,
                                               anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        node.position = position
        if flipped { node.xScale = -abs(node.xScale == 0 ? 1 : node.xScale) }
        node.zPosition = propLayer(for: position.y, in: scene.size.height)
        addGroundShadow(under: node, width: 32 * scale, height: 8 * scale)
        add(node, to: scene)
    }

    /// Le marchand se tient derrière son comptoir (sprite animé).
    private func addShopkeeper(_ asset: String, in scene: SKScene, at position: CGPoint) {
        guard let keeper = PixelArtSprites.animated(
            name: asset, frames: 6, scale: 0.5,
            timePerFrame: 0.18, anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        keeper.position = position
        keeper.zPosition = propLayer(for: position.y, in: scene.size.height) + 0.5
        add(keeper, to: scene)
    }

    private func buildArmoryInterior(in scene: SKScene, room: CGRect) {
        // ── FOND : long comptoir + Bram derrière ──
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX - 44, y: room.maxY - 66), scale: 0.30)
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.midX + 44, y: room.maxY - 66), scale: 0.30)
        addShopkeeper("npc_bram", in: scene, at: CGPoint(x: room.midX, y: room.maxY - 52))

        // ── FORGE (droite) : feu vivant + marmite + soufflet de bois ──
        addInteriorSprite("me_campfire", in: scene, at: CGPoint(x: room.maxX - 52, y: room.maxY - 78), scale: 0.42)
        addInteriorSprite("me_hanging_pot", in: scene, at: CGPoint(x: room.maxX - 84, y: room.maxY - 70), scale: 0.40)
        addInteriorSprite("me_cut_wood_bench", in: scene, at: CGPoint(x: room.maxX - 56, y: room.maxY - 116), scale: 0.42)

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

        // ── ÉTABLI sur le tapis central ──
        addInteriorSprite("interior_bench_table", in: scene, at: CGPoint(x: room.midX, y: room.midY - 34), scale: 0.60)
        addInteriorSprite("me_basket_2", in: scene, at: CGPoint(x: room.midX + 52, y: room.midY - 40), scale: 0.38)

        addServiceMarker(in: scene, at: CGPoint(x: room.midX, y: room.maxY - 96), text: String(localized: "interior.armory.forge"))
    }

    private func buildApothecaryInterior(in scene: SKScene, room: CGRect) {
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

        addServiceMarker(in: scene, at: CGPoint(x: room.midX, y: room.maxY - 96), text: String(localized: "interior.apothecary.potions"))
    }

    private func buildInnInterior(in scene: SKScene, room: CGRect) {
        // ── BAR (fond droit) : comptoir en L + tonneaux ──
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.maxX - 70, y: room.maxY - 66), scale: 0.30)
        addInteriorSprite("interior_counter", in: scene, at: CGPoint(x: room.maxX - 150, y: room.maxY - 66), scale: 0.30)
        addShopkeeper("npc_sage", in: scene, at: CGPoint(x: room.maxX - 110, y: room.maxY - 52))
        addInteriorSprite("me_barrel_1", in: scene, at: CGPoint(x: room.maxX - 44, y: room.maxY - 96), scale: 0.40)
        addInteriorSprite("me_barrel_2", in: scene, at: CGPoint(x: room.maxX - 44, y: room.maxY - 126), scale: 0.40)
        addInteriorSprite("me_barrel_3", in: scene, at: CGPoint(x: room.maxX - 76, y: room.maxY - 100), scale: 0.38)

        // ── CHEMINÉE (fond gauche) : feu + réserve de bois + marmite ──
        addInteriorSprite("me_campfire", in: scene, at: CGPoint(x: room.minX + 48, y: room.maxY - 76), scale: 0.42)
        addInteriorSprite("me_hanging_pot", in: scene, at: CGPoint(x: room.minX + 80, y: room.maxY - 70), scale: 0.42)
        addInteriorSprite("me_cut_wood_2", in: scene, at: CGPoint(x: room.minX + 46, y: room.maxY - 112), scale: 0.38)

        // ── SALLE : deux tables dressées avec chaises ──
        addInteriorSprite("interior_table", in: scene, at: CGPoint(x: room.midX - 36, y: room.midY - 20), scale: 0.62)
        addInteriorSprite("interior_chair", in: scene, at: CGPoint(x: room.midX - 66, y: room.midY - 26), scale: 0.44)
        addInteriorSprite("interior_chair", in: scene, at: CGPoint(x: room.midX - 6, y: room.midY - 26), scale: 0.44, flipped: true)
        addInteriorSprite("interior_table", in: scene, at: CGPoint(x: room.midX + 74, y: room.midY + 10), scale: 0.62)
        addInteriorSprite("interior_chair", in: scene, at: CGPoint(x: room.midX + 44, y: room.midY + 4), scale: 0.44)
        addInteriorSprite("interior_chair", in: scene, at: CGPoint(x: room.midX + 104, y: room.midY + 4), scale: 0.44, flipped: true)
        addInteriorSprite("me_basket", in: scene, at: CGPoint(x: room.midX - 36, y: room.midY + 16), scale: 0.36)

        // ── COIN NUIT (gauche) : deux lits et banc de voyageur ──
        addInteriorSprite("interior_bed", in: scene, at: CGPoint(x: room.minX + 46, y: room.midY - 4), scale: 0.32)
        addInteriorSprite("interior_bed", in: scene, at: CGPoint(x: room.minX + 46, y: room.midY - 44), scale: 0.32)
        addInteriorSprite("interior_wood_bench", in: scene, at: CGPoint(x: room.minX + 50, y: room.midY - 80), scale: 0.44)

        addServiceMarker(in: scene, at: CGPoint(x: room.maxX - 110, y: room.maxY - 96), text: String(localized: "interior.inn.rest"))
    }

    private func addServiceMarker(in scene: SKScene, at position: CGPoint, text: String) {
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = text
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.96, green: 0.84, blue: 0.52, alpha: 0.9)
        label.horizontalAlignmentMode = .center
        label.position = position
        label.zPosition = 3
        add(label, to: scene)
        JuiceEngine.float(label, distance: 3)
    }

    // MARK: - Save Crystal

    /// Ajoute un cristal de sauvegarde dans la scène courante.
    /// Retourne la position du cristal pour que GameManager puisse détecter le tap.
    @discardableResult
    func addSaveCrystal(at position: CGPoint, in scene: SKScene) -> CGPoint {
        let crystal = SKNode()
        crystal.position = position
        crystal.zPosition = 2
        crystal.name = "saveCrystal"

        // Corps du cristal (losange)
        let gem = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 18))
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -10))
        path.addLine(to: CGPoint(x: -10, y: 0))
        path.closeSubpath()
        gem.path = path
        gem.fillColor = SKColor(red: 0.50, green: 0.80, blue: 1.0, alpha: 0.85)
        gem.strokeColor = SKColor(red: 0.70, green: 0.90, blue: 1.0, alpha: 1.0)
        gem.lineWidth = 1.5
        gem.glowWidth = 0
        crystal.addChild(gem)
        JuiceEngine.pulse(gem, scale: 1.12)

        // Aura externe
        let aura = SKShapeNode(circleOfRadius: 22)
        aura.fillColor = SKColor(red: 0.40, green: 0.70, blue: 1.0, alpha: 0.06)
        aura.strokeColor = SKColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 0.18)
        aura.lineWidth = 1.5
        crystal.addChild(aura)
        JuiceEngine.pulse(aura, scale: 1.25)

        // Label
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "world.saveCrystal.label")
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.65, green: 0.88, blue: 1.0, alpha: 0.80)
        label.position = CGPoint(x: 0, y: -26)
        crystal.addChild(label)
        JuiceEngine.float(label, distance: 3)

        scene.addChild(crystal)
        backdropNodes.append(crystal)
        return position
    }

    // MARK: - Kael Corruption (Acte II)

    /// Applique visuellement la corruption de Kael (niveau 1-3).
    /// Supprime les noeuds précédents avant d'ajouter le nouveau niveau.
    func applyKaelCorruption(level: Int) {
        // Supprimer l'ancienne corruption
        kael.children
            .filter { $0.name == "kaelCorruption" }
            .forEach { $0.removeFromParent() }

        guard level > 0 else { return }

        // Niveau 1 : aura sombre violette élargie
        let aura = SKShapeNode(circleOfRadius: CGFloat(34 + level * 8))
        aura.fillColor = SKColor(red: 0.20, green: 0.04, blue: 0.32, alpha: CGFloat(level) * 0.05)
        aura.strokeColor = SKColor(red: 0.45, green: 0.10, blue: 0.70, alpha: CGFloat(level) * 0.14)
        aura.lineWidth = 1.5
        aura.glowWidth = CGFloat(level) * 2
        aura.name = "kaelCorruption"
        aura.zPosition = -1
        kael.addChild(aura)
        JuiceEngine.pulse(aura, scale: 1.0 + CGFloat(level) * 0.08)

        // Niveau 2+ : vrilles sombres (4 tentacules)
        if level >= 2 {
            for i in 0..<4 {
                let angle = CGFloat(i) * (.pi / 2)
                let tendril = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: .zero)
                let ex = cos(angle) * 28
                let ey = sin(angle) * 28
                path.addQuadCurve(
                    to: CGPoint(x: ex, y: ey),
                    control: CGPoint(x: cos(angle + 0.5) * 18, y: sin(angle + 0.5) * 18)
                )
                tendril.path = path
                tendril.strokeColor = SKColor(red: 0.25, green: 0.04, blue: 0.40, alpha: 0.55)
                tendril.lineWidth = 1.5
                tendril.glowWidth = 2
                tendril.name = "kaelCorruption"
                tendril.zPosition = -1
                kael.addChild(tendril)
                JuiceEngine.pulse(tendril, scale: 1.06)
            }
        }

        // Niveau 3 : yeux rouges par-dessus les yeux violets
        if level >= 3 {
            for dx: CGFloat in [-5, 5] {
                let redEye = SKShapeNode(circleOfRadius: 3)
                redEye.fillColor = SKColor(red: 0.95, green: 0.12, blue: 0.08, alpha: 1)
                redEye.strokeColor = .clear
                redEye.glowWidth = 5
                redEye.position = CGPoint(x: dx, y: 35)
                redEye.name = "kaelCorruption"
                redEye.zPosition = 3
                kael.addChild(redEye)
                JuiceEngine.pulse(redEye, scale: 1.4)
            }
        }
    }

    /// Acte II : Dorin garde personnellement la porte nord ; Garen relevé du poste.
    /// Évite le conflit de tap (Dorin/Garen étaient à <8% width l'un de l'autre).
    func repositionDorinToGate(in scene: SKScene) {
        dorin.position = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.72)
        garen.isHidden = true
    }

    // MARK: - Helpers

    private func add(_ node: SKNode, to scene: SKScene) {
        worldNode.addChild(node)
        backdropNodes.append(node)
    }

private func availableTiles(_ preferred: [String], fallback: [String]) -> [String] {
    let available = preferred.filter { PixelArtSprites.exists($0) }
    return available.isEmpty ? fallback : available
}

private func addTiledFloor(in scene: SKScene, tileNames: [String], fallbackColor: SKColor,
                           tileScale: CGFloat, tint: SKColor? = nil, z: CGFloat,
                           overrideSize: CGSize? = nil) {
    let available = availableTiles(tileNames, fallback: ["tile_grass", "tile_grass_dark"])
    let floorSize = overrideSize ?? CGSize(width: scene.size.width + 96,
                                            height: scene.size.height + 96)
    if let floor = PixelArtSprites.tiledFloor(tileNames: available,
                                              in: floorSize,
                                              tileScale: tileScale,
                                              tint: tint) {
        floor.position = CGPoint(x: -48, y: -48)
        floor.zPosition = z
        add(floor, to: scene)
    } else {
        let ground = SKShapeNode(rectOf: floorSize)
        ground.fillColor = fallbackColor
        ground.strokeColor = .clear
        ground.position = CGPoint(x: floorSize.width / 2, y: floorSize.height / 2)
        ground.zPosition = z
        add(ground, to: scene)
    }
}

/// Props plats/franchissables : fleurs, champignons, décorations murales.
/// Tout le reste (arbres, statues, tonneaux, bancs…) bloque le passage.
private static let walkablePropPrefixes = [
    "me_flower", "me_mushrooms", "me_hanging", "me_apples",
    "me_big_sprout", "forest_mushroom", "mushroom"
]

private func addPixelProp(_ name: String, in scene: SKScene, at position: CGPoint,
                          scale: CGFloat, flipped: Bool = false) {
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

/// Les sources lumineuses naturelles s'éclairent toutes seules :
/// lanterne/torche/feu → flamme vacillante, champignon → lueur froide,
/// cristal → éclat violet. Lumière posée en espace monde (backdrop),
/// nettoyée au changement de zone comme le reste.
private func attachPropLight(for name: String, on node: SKNode, in scene: SKScene) {
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

private func addDirtPath(in scene: SKScene, from a: CGPoint, to b: CGPoint,
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
    private func addVillageBuilding(asset: String, scale: CGFloat,
                                     fallbackW: CGFloat, fallbackH: CGFloat,
                                     wallColor: SKColor, roofColor: SKColor,
                                     label: String?,
                                     at position: CGPoint, in scene: SKScene) {
        let node: SKNode
        if let sprite = PixelArtSprites.still(name: asset, scale: scale,
                                               anchor: CGPoint(x: 0.5, y: 0.0)) {
            node = sprite
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

    private func addGroundShadow(to node: SKNode, width: CGFloat, height: CGFloat, y: CGFloat) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        shadow.fillColor = SKColor(white: 0.0, alpha: 0.24)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: y)
        shadow.zPosition = -2
        node.addChild(shadow)
    }

private func addDirtPatch(at center: CGPoint, size: CGSize, in scene: SKScene) {
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

    private func clearBackdrop() {
        obstacles.removeAll()
        snapCameraNextFrame = true   // nouvelle zone : recadrage instantané
        backdropNodes.forEach { $0.removeFromParent() }
        backdropNodes.removeAll()
        atmosphereNode?.removeFromParent()
        atmosphereNode = nil
        // Le halo du héros n'existe que dans les zones noires (mines) ;
        // chaque zone le ré-attache explicitement si besoin.
        LightingEngine.removeHeroLight(from: kael)
        // La pluie est en espace écran : sans ce retrait central, elle
        // suivrait le joueur jusque dans les mines et les intérieurs.
        worldNode.scene?.childNode(withName: "weatherRain")?.removeFromParent()
    }

    /// Décide la météo à l'entrée d'une zone extérieure : `--weather-rain`
    /// force la pluie, sinon ~1 entrée sur 5. Pose l'emitter en espace
    /// écran (z 95, sous le HUD) et dit à l'appelant d'assombrir le grade.
    private func rollWeatherRain(in scene: SKScene, chance: Int = 20) -> Bool {
        let raining = CommandLine.arguments.contains("--weather-rain")
            || Int.random(in: 0..<100) < chance
        guard raining else { return false }
        let rain = ParticleFactory.rain(in: scene.size)
        rain.name = "weatherRain"
        scene.addChild(rain)
        return true
    }

    private func addAtmosphere(_ node: SKNode, to scene: SKScene) {
        atmosphereNode?.removeFromParent()
        atmosphereNode = node
        worldNode.addChild(node)
    }

    // MARK: - Vignette de zone (écran, ne scrolle pas)

    /// Assombrit les bords de l'écran — ambiance grotte/forêt profonde.
    /// Texture radiale rendue en basse résolution puis upscalée en
    /// .nearest : le dégradé reste en gros pixels, cohérent pixel art.
    /// alpha 0 = retire la vignette (village, zones claires).
    func setZoneVignette(in scene: SKScene, alpha: CGFloat) {
        scene.childNode(withName: "zoneVignette")?.removeFromParent()
        guard alpha > 0.01 else { return }

        let cols = 44, rows = 20
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: cols, height: rows), format: format
        ).image { ctx in
            let c = ctx.cgContext
            for y in 0..<rows {
                for x in 0..<cols {
                    let nx = (CGFloat(x) + 0.5) / CGFloat(cols) * 2 - 1
                    let ny = (CGFloat(y) + 0.5) / CGFloat(rows) * 2 - 1
                    let d = min(1, sqrt(nx * nx + ny * ny * 0.85))
                    let a = pow(max(0, d - 0.45) / 0.55, 2) * alpha
                    guard a > 0.01 else { continue }
                    c.setFillColor(SKColor(red: 0.01, green: 0.01, blue: 0.02,
                                           alpha: a).cgColor)
                    c.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        let vignette = SKSpriteNode(texture: texture)
        vignette.name = "zoneVignette"
        vignette.size = CGSize(width: scene.size.width + 4, height: scene.size.height + 4)
        vignette.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        vignette.zPosition = 480   // au-dessus du monde, sous HUD/overlays
        scene.addChild(vignette)
    }

    // MARK: - Sol plat (fond uni, sans tiles répétitives)

    private func addFlatGroundVillage(in scene: SKScene, size: CGSize) {
        let base = SKShapeNode(rectOf: size)
        base.fillColor = SKColor(red: 0.32, green: 0.55, blue: 0.28, alpha: 1)
        base.strokeColor = .clear
        base.position = CGPoint(x: size.width / 2 - 48, y: size.height / 2 - 48)
        base.zPosition = -10
        add(base, to: scene)
    }

    private func addFlatGroundForest(in scene: SKScene, size: CGSize) {
        let base = SKShapeNode(rectOf: size)
        base.fillColor = SKColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 1)
        base.strokeColor = .clear
        base.position = CGPoint(x: size.width / 2 - 48, y: size.height / 2 - 48)
        base.zPosition = -10
        add(base, to: scene)
    }

    // MARK: - Clôture (rectangle d'assets fence ME)
    private func addFenceRect(in scene: SKScene, at center: CGPoint, size: CGSize) {
        let tile: CGFloat = 16  // 48px × 0.33
        let scale: CGFloat = 0.33
        let halfW = size.width / 2
        let halfH = size.height / 2

        // Périmètre infranchissable (4 bandes fines sur les côtés)
        registerObstacle(CGRect(x: center.x - halfW - 5, y: center.y + halfH - 5,
                                width: size.width + 10, height: 10))
        registerObstacle(CGRect(x: center.x - halfW - 5, y: center.y - halfH - 5,
                                width: size.width + 10, height: 10))
        registerObstacle(CGRect(x: center.x - halfW - 5, y: center.y - halfH,
                                width: 10, height: size.height))
        registerObstacle(CGRect(x: center.x + halfW - 5, y: center.y - halfH,
                                width: 10, height: size.height))
        let cols = max(2, Int(size.width / tile))
        let rows = max(2, Int(size.height / tile))

        // Top + bottom
        for c in 0..<cols {
            let x = center.x - halfW + (CGFloat(c) + 0.5) * tile
            let name = c == 0 ? "me_fence_top_left" : (c == cols - 1 ? "me_fence_top_right" : "me_fence_top_mid")
            if let t = PixelArtSprites.still(name: name, scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: x, y: center.y + halfH)
                t.zPosition = -3
                add(t, to: scene)
            }
            let nb = c == 0 ? "me_fence_bot_left" : (c == cols - 1 ? "me_fence_bot_right" : "me_fence_bot_mid")
            if let t = PixelArtSprites.still(name: nb, scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: x, y: center.y - halfH)
                t.zPosition = -3
                add(t, to: scene)
            }
        }
        // Sides (middle row only — skip corners already placed)
        for r in 1..<(rows - 1) {
            let y = center.y - halfH + (CGFloat(r) + 0.5) * tile
            if let t = PixelArtSprites.still(name: "me_fence_mid_left", scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: center.x - halfW, y: y)
                t.zPosition = -3
                add(t, to: scene)
            }
            if let t = PixelArtSprites.still(name: "me_fence_mid_right", scale: scale, anchor: CGPoint(x: 0.5, y: 0.5)) {
                t.position = CGPoint(x: center.x + halfW, y: y)
                t.zPosition = -3
                add(t, to: scene)
            }
        }
    }

    // MARK: - Rendu autotile (chemins de terre, étang du village)

    /// Pose les tuiles d'une `VillageTileMap` : tuiles pleines sur les
    /// cellules marquées, transitions nommées sur l'herbe adjacente
    /// (ex. `me_edge_n` = matière au nord de la cellule d'herbe).
    /// `tint` assombrit/teinte les tuiles (forêt sombre, etc.) pour
    /// rester assorti au sol teinté.
    private func renderTileMap(_ map: VillageTileMap, fullTile: String,
                               edgePrefix: String, in scene: SKScene, z: CGFloat,
                               tint: SKColor? = nil) {
        for piece in map.pieces() {
            let name = piece.suffix.map { edgePrefix + $0 } ?? fullTile
            guard let t = PixelArtSprites.still(name: name, scale: 0.5,
                                                 anchor: .zero) else { continue }
            t.position = CGPoint(x: CGFloat(piece.col) * map.tile,
                                  y: CGFloat(piece.row) * map.tile)
            t.zPosition = piece.suffix == nil ? z : z + 0.05
            if let tint {
                t.forEachDescendantSprite { sprite in
                    sprite.color = tint
                    sprite.colorBlendFactor = 0.45
                }
            }
            add(t, to: scene)
        }
    }
}

// MARK: - VillageTileMap (autotiler)

/// Grille binaire pour l'autotiling du village : on marque les cellules
/// "matière" (terre battue, eau), puis `pieces()` renvoie les tuiles
/// pleines + les transitions à poser sur les cellules d'herbe voisines,
/// nommées par la position de la matière (n, ne, e, se, s, sw, w, nw,
/// et cnw/cne/cse/csw pour les coins diagonaux isolés).
struct VillageTileMap {
    let tile: CGFloat
    let cols: Int
    let rows: Int
    private var cells: [Bool]

    init(width: CGFloat, height: CGFloat, tile: CGFloat) {
        self.tile = tile
        self.cols = Int(ceil(width / tile)) + 1
        self.rows = Int(ceil(height / tile)) + 1
        self.cells = Array(repeating: false, count: cols * rows)
    }

    private func isSet(_ c: Int, _ r: Int) -> Bool {
        guard c >= 0, c < cols, r >= 0, r < rows else { return false }
        return cells[r * cols + c]
    }

    /// Marque toutes les cellules intersectant le rectangle (points).
    mutating func stamp(rect: CGRect) {
        let c0 = max(0, Int(rect.minX / tile))
        let c1 = min(cols - 1, Int((rect.maxX - 0.5) / tile))
        let r0 = max(0, Int(rect.minY / tile))
        let r1 = min(rows - 1, Int((rect.maxY - 0.5) / tile))
        guard c0 <= c1, r0 <= r1 else { return }
        for r in r0...r1 {
            for c in c0...c1 { cells[r * cols + c] = true }
        }
    }

    /// Marque les cellules dont le centre est dans l'ellipse.
    mutating func stampEllipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) {
        guard radiusX > 0, radiusY > 0 else { return }
        for r in 0..<rows {
            for c in 0..<cols {
                let x = (CGFloat(c) + 0.5) * tile
                let y = (CGFloat(r) + 0.5) * tile
                let dx = (x - center.x) / radiusX
                let dy = (y - center.y) / radiusY
                if dx * dx + dy * dy <= 1 { cells[r * cols + c] = true }
            }
        }
    }

    /// Tuiles à poser : `suffix == nil` → tuile pleine, sinon suffixe de
    /// transition pour la cellule d'herbe (rangée = y vers le haut).
    func pieces() -> [(suffix: String?, col: Int, row: Int)] {
        var out: [(String?, Int, Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                if isSet(c, r) {
                    out.append((nil, c, r))
                    continue
                }
                let n = isSet(c, r + 1), s = isSet(c, r - 1)
                let e = isSet(c + 1, r), w = isSet(c - 1, r)
                let suffix: String?
                switch (n, s, e, w) {
                case (true, _, true, _):  suffix = "ne"
                case (true, _, _, true):  suffix = "nw"
                case (_, true, true, _):  suffix = "se"
                case (_, true, _, true):  suffix = "sw"
                case (true, _, _, _):     suffix = "n"
                case (_, true, _, _):     suffix = "s"
                case (_, _, true, _):     suffix = "e"
                case (_, _, _, true):     suffix = "w"
                default:
                    if isSet(c + 1, r + 1)      { suffix = "cne" }
                    else if isSet(c - 1, r + 1) { suffix = "cnw" }
                    else if isSet(c + 1, r - 1) { suffix = "cse" }
                    else if isSet(c - 1, r - 1) { suffix = "csw" }
                    else { suffix = nil }
                }
                if let suffix { out.append((suffix, c, r)) }
            }
        }
        return out
    }
}
