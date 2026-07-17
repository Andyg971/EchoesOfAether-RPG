import SpriteKit

// Caverne aux Échos : donjon optionnel (gardien baladeur + coffre).
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {

    // MARK: - Caverne aux Échos (donjon optionnel, entrée dans la forêt)

    /// Descend dans la Caverne aux Échos depuis la forêt.
    func enterCave() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inCave = true
            hud.objectiveText = String(localized: "hud.objective.cave")
            world.switchToCave(in: scene, cleared: player.caveCleared,
                               chestTaken: player.caveChestTaken)
            world.kael.position = CGPoint(x: scene.size.width * 0.50,
                                          y: scene.size.height * 0.14)
        } completion: { [weak self] in
            guard let self else { return }
            spawnCaveRoamer()
            // Dialogue d'ambiance à la première visite (gardien pas encore
            // vaincu). One-shot, jamais enchaîné.
            if !player.caveCleared {
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.caveEnterDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            } else {
                transition(to: .exploration)
            }
        }
    }

    /// Remonte vers la forêt, respawn devant l'entrée de la caverne.
    func exitCave() {
        guard let scene else { return }
        clearRoamers()
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inCave = false
            hud.objectiveText = String(localized: "hud.objective.forest")
            AudioEngine.shared.setMood(.forPhase(phase))
            showForest(in: scene)
        } completion: { [weak self] in
            guard let self, let scene = self.scene else { return }
            if player.questChildToy == .active { world.addToyMarker(in: scene) }
            if player.questMedallion == .active { world.addMedallionMarker(in: scene) }
            addSideQuestMarkers(in: scene)
            let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            world.kael.position = CGPoint(x: scene.size.width * 0.22, y: wh * 0.30)
            transition(to: .exploration)
        }
    }

    func tryCaveInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width
        let h = scene.size.height
        // Sortie (halo sud)
        if point.distance(to: CGPoint(x: w * 0.50, y: h * 0.08)) < 60 {
            exitCave()
            return true
        }
        // Le gardien charge Kael (RoamingMonster) — plus de combat au tap.
        // Coffre (révélé une fois le gardien vaincu)
        if player.caveCleared, !player.caveChestTaken,
           point.distance(to: CGPoint(x: w * 0.50, y: h * 0.68)) < 70 {
            takeCaveChest(in: scene)
            return true
        }
        return false
    }

    func startCaveCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startCaveCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.echoGuardian"),
                          hp: 320, kind: .boneWalker, baseDamage: 40)
            ],
            goldReward: 80,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.caveCleared = true
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.cave")
            refreshCaveBackdrop()
            saveGame()
            transition(to: .exploration)
        }
    }

    func refreshCaveBackdrop() {
        guard let scene, inCave else { return }
        let kaelPos = world.kael.position
        world.switchToCave(in: scene, cleared: player.caveCleared,
                           chestTaken: player.caveChestTaken)
        world.kael.position = kaelPos
        spawnCaveRoamer()   // (ne respawn rien si le gardien est vaincu)
    }

    func takeCaveChest(in scene: SKScene) {
        guard !player.caveChestTaken else { return }
        player.caveChestTaken = true
        player.gold += 150
        player.aetherShards += 3
        syncGold()
        AudioEngine.shared.playGoldGain()
        HapticsEngine.success()
        world.removeCaveChest()
        let spot = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.68)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 1),
            count: 16))
        hud.objectiveText = String(localized: "hud.objective.cave.done")
        saveGame()
    }

    /// Boss des mines : dialogue d'approche puis golem de cendre.
    func startMinesBossSequence() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.minesBossPreDialogue) { [weak self] in
            self?.startMinesBossCombat()
        }
    }

    func startMinesBossCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startMinesBossCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.ashGolem"),
                          hp: 560, kind: .ruinsGuardian, baseDamage: 48)
            ],
            goldReward: 150,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.minesProgress = 3
            player.questMines = .complete
            syncGold()
            hud.questText = ""
            AudioEngine.shared.playQuestComplete()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.mines")
            refreshMinesBackdrop()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.minesBossPostDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Plaque des mineurs : débloque l'entrée de lore « cendreval ».
    func openMinesInscription() {
        guard let scene else { return }
        transition(to: .dialogue)
        JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                 color: SKColor(red: 0.55, green: 0.42, blue: 0.20, alpha: 1),
                                 duration: 0.3)
        player.loreDiscovered.insert("cendreval")
        dialogue.start(PrototypeContent.minesInscriptionDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Veine d'or : +80 or, une seule fois.
    func pickupGoldVein() {
        guard let scene else { return }
        player.minesGoldTaken = true
        player.gold += 80
        syncGold()
        AudioEngine.shared.playGoldGain()
        world.removeGoldVein()
        let spot = MinesPOI.goldVein.scaled(w: scene.size.width, h: world.worldHeight)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 1), count: 14))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.minesGoldDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    func syncGold() {
        hud.goldValue = player.gold
    }
}
