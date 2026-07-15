import SpriteKit

// Mines de Cendreval : descente, combats de galerie, veine d'or.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {

    // MARK: - Mines de Cendreval

    /// Descente dans les mines : zone plein écran, Lyra reste à l'entrée.
    func enterMines() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inMines = true
            hud.objectiveText = String(localized: "hud.objective.mines")
            AudioEngine.shared.setMood(.mines)
            world.switchToMines(in: scene, progress: player.minesProgress,
                                goldTaken: player.minesGoldTaken)
            world.kael.position = CGPoint(x: scene.size.width * 0.50,
                                          y: scene.size.height * 0.14)
        } completion: { [weak self] in
            guard let self else { return }
            spawnMineRoamers()
            if player.questMines == .inactive {
                player.questMines = .active
                hud.questText = String(localized: "quest.mines.hud")
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.minesEnterDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            } else {
                transition(to: .exploration)
            }
        }
    }

    /// Remonte à la forêt, respawn devant la galerie.
    func exitMines() {
        guard let scene else { return }
        clearRoamers()
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inMines = false
            hud.objectiveText = String(localized: "hud.objective.forest")
            AudioEngine.shared.setMood(.forPhase(phase))
            showForest(in: scene)
        } completion: { [weak self] in
            guard let self, let scene = self.scene else { return }
            if player.questChildToy == .active { world.addToyMarker(in: scene) }
            if player.questMedallion == .active { world.addMedallionMarker(in: scene) }
            addSideQuestMarkers(in: scene)
            let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            world.kael.position = CGPoint(x: scene.size.width * 0.80, y: wh * 0.28)
            transition(to: .exploration)
        }
    }

    func tryMinesInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width
        let h = scene.size.height

        // Sortie (halo sud)
        if point.distance(to: CGPoint(x: w * 0.50, y: h * 0.08)) < 60 {
            exitMines()
            return true
        }

        // Les combats ne se déclenchent plus au tap : les monstres
        // baladeurs chargent Kael et le contact ouvre le combat
        // (cf. spawnMineRoamers / RoamingMonster).

        // Plaque des mineurs : lore de Cendreval
        if point.distance(to: CGPoint(x: w * 0.18, y: h * 0.68)) < 60 {
            openMinesInscription()
            return true
        }

        // Veine d'or (une seule fois)
        if !player.minesGoldTaken,
           point.distance(to: CGPoint(x: w * 0.80, y: h * 0.40)) < 60 {
            pickupGoldVein()
            return true
        }

        return false
    }

    /// Combat 1 : deux mineurs cendreux (goules recouvertes de cendre).
    func startMinesCombat1() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startMinesCombat1() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let name = String(localized: "combat.enemy.ashMiner")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                          hp: 230, kind: .ghoul, baseDamage: 36),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                          hp: 230, kind: .ghoul, baseDamage: 36)
            ],
            goldReward: 55,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.minesProgress = 1
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.mines")
            refreshMinesBackdrop()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.minesCombat1PostDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Combat 2 : les spectres des galeries — trois morts qui creusent encore.
    func startMinesCombat2() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startMinesCombat2() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let wraith = String(localized: "combat.enemy.ashWraith")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(wraith) \(1)"),
                          hp: 250, kind: .boneWalker, baseDamage: 38),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(wraith) \(2)"),
                          hp: 250, kind: .boneWalker, baseDamage: 38),
                EnemySpec(name: String(localized: "combat.enemy.ashMiner"),
                          hp: 210, kind: .ghoul, baseDamage: 34)
            ],
            goldReward: 70,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.minesProgress = 2
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.mines")
            refreshMinesBackdrop()
            transition(to: .exploration)
        }
    }

    /// Reconstruit le décor des mines après un combat (les monstres
    /// vaincus disparaissent, la zone suivante s'allume).
    func refreshMinesBackdrop() {
        guard let scene, inMines else { return }
        let kaelPos = world.kael.position
        world.switchToMines(in: scene, progress: player.minesProgress,
                            goldTaken: player.minesGoldTaken)
        world.kael.position = kaelPos
        spawnMineRoamers()
    }
}
