import SpriteKit

// Monstres baladeurs : aggro au contact, chasses de la forêt.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Monstres baladeurs (aggro au contact)

    /// Retire tous les monstres baladeurs (changement de zone, contact).
    func clearRoamers() {
        roamers.forEach { $0.node.removeFromParent() }
        roamers.removeAll()
    }

    /// Fait patrouiller/charger les monstres ; au contact, lance le combat.
    func updateRoamers(deltaTime: TimeInterval) {
        guard state == .exploration, !roamers.isEmpty else { return }
        let heroPos = world.kael.position
        for roamer in roamers {
            if roamer.update(deltaTime: deltaTime, heroPos: heroPos) {
                clearRoamers()   // le combat prend le relais
                return
            }
        }
    }

    /// Peuple les mines de monstres baladeurs selon la progression.
    func spawnMineRoamers() {
        guard let scene else { return }
        clearRoamers()
        let w = scene.size.width
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        // Un rôdeur par tronçon de la descente : corridor aux rails,
        // salle effondrée, fond nord (le golem garde les morts).
        switch player.minesProgress {
        case 0:
            addRoamer("enemy_ghoul", at: CGPoint(x: w * 0.42, y: wh * 0.30),
                      wh: wh) { [weak self] in self?.startMinesCombat1() }
        case 1:
            addRoamer("enemy_bone", at: CGPoint(x: w * 0.55, y: wh * 0.56),
                      wh: wh) { [weak self] in self?.startMinesCombat2() }
        case 2 where player.questMines != .complete:
            // Le golem est un boss : plus lent, patrouille plus large.
            addRoamer("enemy_bone", at: CGPoint(x: w * 0.55, y: wh * 0.88),
                      wh: wh, patrolRadius: 40, chaseSpeed: 74) { [weak self] in
                self?.startMinesBossSequence()
            }
        default:
            break
        }
    }

    /// Affiche la forêt ET (re)peuple ses monstres baladeurs. Remplace les
    /// appels directs à `world.switchToForest` pour garantir le spawn.
    func showForest(in scene: SKScene) {
        world.switchToForest(in: scene)
        forestHuntsCleared.removeAll()
        spawnForestRoamers()
    }

    /// Peuple la forêt : combat de progression courant + chasses optionnelles
    /// non encore vaincues cette visite. Coords MONDE (trek scrollable).
    func spawnForestRoamers() {
        guard let scene, !inMines, !inCave, phase == .forest || inForest else { clearRoamers(); return }
        clearRoamers()
        let w = scene.size.width
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        // Combat de progression : bête (bosquet) puis loups (clairière).
        if player.forestProgress < 1 {
            addRoamer("enemy_ghoul", at: CGPoint(x: w * 0.30, y: wh * 0.31),
                      wh: wh) { [weak self] in self?.startGroveCombat() }
        } else if player.forestProgress < 2 {
            addRoamer("enemy_shadewolf", at: CGPoint(x: w * 0.70, y: wh * 0.66),
                      wh: wh) { [weak self] in self?.startClearingCombat() }
        }
        // Chasses optionnelles répétables (tant que non vaincues cette visite).
        if !forestHuntsCleared.contains("ghoul") {
            addRoamer("enemy_ghoul", at: CGPoint(x: w * 0.20, y: wh * 0.585),
                      wh: wh) { [weak self] in self?.startGhoulCombat() }
        }
        if !forestHuntsCleared.contains("bone") {
            addRoamer("enemy_bone", at: CGPoint(x: w * 0.82, y: wh * 0.74),
                      wh: wh) { [weak self] in self?.startBoneCombat() }
        }
    }

    /// Affiche les Ruines ET (re)peuple leurs baladeurs. À utiliser partout
    /// plutôt que `world.switchToRuins` seul, sinon la zone reste vide.
    func showRuins(in scene: SKScene, placeKael: Bool = true) {
        world.switchToRuins(in: scene)
        if placeKael {
            world.kael.position = RuinsLayout(sceneSize: scene.size).entrance
            world.snapCamera()
        }
        spawnRuinsRoamers()
    }

    /// Affiche le Seuil ET (re)peuple ses Ombres. `placeKael: false` préserve
    /// la position courante (reconstruction du décor après un combat).
    func showThreshold(in scene: SKScene, placeKael: Bool = true) {
        world.switchToThreshold(in: scene,
                                echoJoined: player.act3EchoJoined,
                                spiritsCalmed: player.act3SpiritsCalmed,
                                shadesDefeated: player.act3ShadesDefeated,
                                eranMet: player.act3EranMet)
        if placeKael {
            // Le couloir se parcourt du sud au nord : Kael entre par le bas.
            world.kael.position = ThresholdLayout(sceneSize: scene.size).entrance
            world.snapCamera()
        }
        spawnAct3Roamers()
    }

    /// Affiche le Cœur du Vide ET (re)peuple ses Dévoreurs. `placeKael: false`
    /// préserve la position (reconstruction du décor après un combat).
    func showVoidHeart(in scene: SKScene, placeKael: Bool = true) {
        world.switchToVoidHeart(in: scene,
                                echoJoined: player.act3EchoJoined,
                                reflectionsFreed: player.act4ReflectionsFreed,
                                devourersDefeated: player.act4DevourersDefeated,
                                bossDefeated: player.act4BossDefeated)
        if placeKael {
            world.kael.position = VoidHeartLayout(sceneSize: scene.size).entrance
            world.snapCamera()
        }
        spawnAct4Roamers()
    }

    /// Ruines (Acte II) : gardiens puis archiviste, selon la progression.
    func spawnRuinsRoamers() {
        guard let scene, phase == .ruins || phase == .fallen else { clearRoamers(); return }
        clearRoamers()
        let plan = RuinsLayout(sceneSize: scene.size)
        let ruinsTint = SKColor(red: 0.62, green: 0.30, blue: 0.28, alpha: 1)
        if player.ruinsProgress < 1 {
            // Les Gardiens tiennent le goulot : on ne passe pas sans eux.
            for dx in [CGFloat(-0.04), 0.04] {
                addRoamer("enemy_bone",
                          at: CGPoint(x: plan.guardiansAmbush.x + plan.width * dx,
                                      y: plan.guardiansAmbush.y),
                          wh: plan.height, patrolRadius: 44,
                          tint: ruinsTint, blend: 0.35) { [weak self] in
                    self?.startRuinsCombat1()
                }
            }
        } else if player.ruinsProgress == 1 {
            // L'Archiviste est un mini-boss : patrouille serrée, charge lente.
            // Sa planche est déjà bleue — aucune teinte par-dessus, sinon on
            // perd la couleur qui EST son état (cf. CombatSprites).
            addRoamer("enemy_archivist_blue", at: plan.archivistAmbush,
                      wh: plan.height, frames: 8, height: 72,
                      patrolRadius: 52, chaseSpeed: 78, blend: 0) { [weak self] in
                self?.startRuinsCombat2()
            }
        }
    }

    /// Le Seuil (Acte III) : les Ombres du Vide chargent en meute.
    /// Elles n'apparaissent qu'une fois l'Écho de Lyra rallié (comme avant).
    func spawnAct3Roamers() {
        guard let scene, phase == .act3,
              !player.act3ShadesDefeated, player.act3EchoJoined else {
            clearRoamers(); return
        }
        clearRoamers()
        // Embusquées au goulot : impossible de monter sans les affronter.
        let plan = ThresholdLayout(sceneSize: scene.size)
        let shadeTint = SKColor(red: 0.35, green: 0.15, blue: 0.55, alpha: 1)
        for (i, dx) in [CGFloat(-0.06), 0.06].enumerated() {
            addRoamer("enemy_bone",
                      at: CGPoint(x: plan.shadeAmbush.x + plan.width * dx,
                                  y: plan.shadeAmbush.y + plan.height * CGFloat(i) * 0.012),
                      wh: plan.height, patrolRadius: 54,
                      tint: shadeTint, blend: 0.55, alpha: 0.72) { [weak self] in
                self?.startVoidShadesCombat()
            }
        }
    }

    /// Cœur du Vide (Acte IV) : les Dévoreurs d'échos.
    func spawnAct4Roamers() {
        guard let scene, phase == .act4, !player.act4DevourersDefeated else {
            clearRoamers(); return
        }
        clearRoamers()
        // Embusqués au premier virage du serpentin.
        let plan = VoidHeartLayout(sceneSize: scene.size)
        let devourTint = SKColor(red: 0.55, green: 0.12, blue: 0.40, alpha: 1)
        for (i, dx) in [CGFloat(-0.05), 0.05].enumerated() {
            addRoamer("enemy_bone",
                      at: CGPoint(x: plan.devourerAmbush.x + plan.width * dx,
                                  y: plan.devourerAmbush.y + plan.height * CGFloat(i) * 0.012),
                      wh: plan.height, patrolRadius: 60,
                      tint: devourTint, blend: 0.60, alpha: 0.76) { [weak self] in
                self?.startDevourersCombat()
            }
        }
    }

    /// Peuple la caverne du gardien baladeur (si pas encore vaincu).
    func spawnCaveRoamer() {
        guard let scene, !player.caveCleared else { clearRoamers(); return }
        clearRoamers()
        let w = scene.size.width, h = scene.size.height
        addRoamer("enemy_bone", at: CGPoint(x: w * 0.50, y: h * 0.55),
                  wh: h, patrolRadius: 80) { [weak self] in self?.startCaveCombat() }
    }

    /// Crée un monstre baladeur (sprite animé) et l'enregistre.
    func addRoamer(_ asset: String, at pos: CGPoint, wh: CGFloat,
                           frames: Int = 6, height: CGFloat? = nil,
                           patrolRadius: CGFloat = 70, chaseSpeed: CGFloat = 104,
                           tint: SKColor = SKColor(red: 0.48, green: 0.44, blue: 0.42, alpha: 1),
                           blend: CGFloat = 0.22, alpha: CGFloat = 1,
                           graceTime: TimeInterval = 0,
                           sanctuary: CGRect? = nil,
                           startCombat: @escaping () -> Void) {
        guard let node = world.makeRoamingMonster(asset: asset, frames: frames,
                                                  height: height, tint: tint,
                                                  blend: blend, alpha: alpha) else { return }
        world.worldNode.addChild(node)
        roamers.append(RoamingMonster(
            node: node, home: pos, worldHeight: wh,
            patrolRadius: patrolRadius, chaseSpeed: chaseSpeed,
            graceTime: graceTime, sanctuary: sanctuary,
            startCombat: startCombat))
    }
}
