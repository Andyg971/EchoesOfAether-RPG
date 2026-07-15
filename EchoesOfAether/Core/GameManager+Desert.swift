import SpriteKit

// Désert d'Ossara : zone optionnelle atteinte via la carte du monde.
// Extrait de GameManager.swift pour alléger le monolithe.
@MainActor
extension GameManager {

    // MARK: - Désert d'Ossara

    /// Voyage vers les dunes : Kael quitte sa zone, le désert se charge.
    func enterDesert() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inDesert = true
            hud.objectiveText = String(localized: "hud.objective.desert")
            AudioEngine.shared.setMood(.tense)
            world.switchToDesert(in: scene, progress: player.desertProgress,
                                 chestTaken: player.desertChestTaken)
            world.kael.position = CGPoint(x: scene.size.width * 0.50,
                                          y: scene.size.height * 0.14)
        } completion: { [weak self] in
            guard let self else { return }
            if player.questDesert == .inactive {
                player.questDesert = .active
                hud.questText = String(localized: "quest.desert.hud")
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.desertEnterDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            } else if player.desertProgress >= 1, player.questDesert == .active,
                      Int.random(in: 0..<100) < 30 {
                // Rencontre aléatoire en chemin : les dunes ne pardonnent pas.
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.desertAmbushDialogue) { [weak self] in
                    self?.startDesertAmbush()
                }
            } else {
                transition(to: .exploration)
            }
        }
    }

    /// Retour vers la zone d'origine (la phase n'a pas changé).
    func exitDesert() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inDesert = false
            AudioEngine.shared.setMood(.forPhase(phase))
            switch phase {
            case .forest:
                hud.objectiveText = String(localized: "hud.objective.forest")
                showForest(in: scene)
            case .act2:
                hud.objectiveText = String(localized: "hud.objective.act2")
                world.switchToVillage(in: scene)
                world.repositionDorinToGate(in: scene)
                world.applyKaelCorruption(level: player.kaelCorruptionLevel)
            default:
                hud.objectiveText = String(localized: "hud.objective.complete")
                world.switchToVillage(in: scene)
            }
        } completion: { [weak self] in
            guard let self, let scene = self.scene else { return }
            let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            if phase == .forest {
                if player.questChildToy == .active { world.addToyMarker(in: scene) }
                if player.questMedallion == .active { world.addMedallionMarker(in: scene) }
                addSideQuestMarkers(in: scene)
                world.kael.position = CGPoint(x: scene.size.width * 0.5, y: wh * 0.05)
            } else {
                world.kael.position = CGPoint(x: scene.size.width * 0.5, y: wh * 0.12)
            }
            transition(to: .exploration)
        }
    }

    func tryDesertInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width
        let h = scene.size.height

        // Sortie (halo sud) : retour vers la zone d'origine
        if point.distance(to: CGPoint(x: w * 0.50, y: h * 0.08)) < 60 {
            exitDesert()
            return true
        }

        // Zone 1 : pillards des dunes
        if player.desertProgress < 1,
           point.distance(to: CGPoint(x: w * 0.28, y: h * 0.55)) < 75 {
            startDesertCombat1()
            return true
        }

        // Zone 2 : charognards (après les pillards)
        if player.desertProgress == 1,
           point.distance(to: CGPoint(x: w * 0.55, y: h * 0.68)) < 75 {
            startDesertCombat2()
            return true
        }

        // Zone 3 : le colosse des sables
        if player.desertProgress == 2, player.questDesert != .complete,
           point.distance(to: CGPoint(x: w * 0.80, y: h * 0.55)) < 75 {
            startDesertBossSequence()
            return true
        }

        // Coffre enfoui (une seule fois)
        if !player.desertChestTaken,
           point.distance(to: CGPoint(x: w * 0.12, y: h * 0.56)) < 60 {
            pickupBuriedChest()
            return true
        }

        // Oasis : restaure tous les PV, une fois par visite
        if !player.desertOasisUsed,
           point.distance(to: CGPoint(x: w * 0.85, y: h * 0.20)) < 60 {
            drinkAtOasis()
            return true
        }

        return false
    }

    /// Combat 1 : deux pillards des dunes — les détrousseurs de caravanes.
    func startDesertCombat1() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertCombat1() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let name = String(localized: "combat.enemy.dunePillager")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                          hp: 260, kind: .ghoul, baseDamage: 40),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                          hp: 260, kind: .ghoul, baseDamage: 40)
            ],
            goldReward: 60,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.desertProgress = 1
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.desert")
            refreshDesertBackdrop()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.desertCombat1PostDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Combat 2 : les charognards d'Ossara — ceux qui suivent les pillards.
    func startDesertCombat2() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertCombat2() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let scavenger = String(localized: "combat.enemy.scavenger")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(scavenger) \(1)"),
                          hp: 240, kind: .boneWalker, baseDamage: 38),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(scavenger) \(2)"),
                          hp: 240, kind: .boneWalker, baseDamage: 38),
                EnemySpec(name: String(localized: "combat.enemy.dunePillager"),
                          hp: 220, kind: .ghoul, baseDamage: 36)
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
            player.desertProgress = 2
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.desert")
            refreshDesertBackdrop()
            transition(to: .exploration)
        }
    }

    /// Boss du désert : dialogue d'approche puis le colosse des sables.
    func startDesertBossSequence() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.desertBossPreDialogue) { [weak self] in
            self?.startDesertBossCombat()
        }
    }

    func startDesertBossCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertBossCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.sandColossus"),
                          hp: 640, kind: .ruinsGuardian, baseDamage: 52)
            ],
            goldReward: 180,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.desertProgress = 3
            player.questDesert = .complete
            syncGold()
            hud.questText = ""
            AudioEngine.shared.playQuestComplete()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.desert")
            refreshDesertBackdrop()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.desertBossPostDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Embuscade de voyage : deux pillards surgissent des dunes.
    func startDesertAmbush() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertAmbush() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let name = String(localized: "combat.enemy.dunePillager")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                          hp: 220, kind: .ghoul, baseDamage: 36),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                          hp: 220, kind: .ghoul, baseDamage: 36)
            ],
            goldReward: 40,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.desert")
            transition(to: .exploration)
        }
    }

    /// Reconstruit le décor du désert après un combat (les monstres
    /// vaincus disparaissent, la zone suivante s'allume).
    func refreshDesertBackdrop() {
        guard let scene, inDesert else { return }
        let kaelPos = world.kael.position
        world.switchToDesert(in: scene, progress: player.desertProgress,
                             chestTaken: player.desertChestTaken)
        world.kael.position = kaelPos
    }

    /// Coffre enfoui : +120 or, une seule fois.
    func pickupBuriedChest() {
        guard let scene else { return }
        player.desertChestTaken = true
        player.gold += 120
        syncGold()
        AudioEngine.shared.playGoldGain()
        world.removeBuriedChest()
        let spot = CGPoint(x: scene.size.width * 0.12, y: scene.size.height * 0.56)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 1), count: 14))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.desertChestDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Oasis : restaure tous les PV, une fois par visite.
    func drinkAtOasis() {
        guard let scene else { return }
        player.desertOasisUsed = true
        player.currentHP = player.currentMaxHP
        HapticsEngine.medium()
        JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                 color: SKColor(red: 0.30, green: 0.75, blue: 0.85, alpha: 1),
                                 duration: 0.25)
        let spot = CGPoint(x: scene.size.width * 0.85, y: scene.size.height * 0.20)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.55, green: 0.90, blue: 1.0, alpha: 1), count: 12))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.desertOasisDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }
}
