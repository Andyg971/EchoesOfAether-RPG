import SpriteKit

// Désert d'Ossara : les combats (pillards, scorpions, boss, embuscade).
extension GameManager {
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
                          hp: EncounterBalance.SideBoss.sandColossus,
                          kind: .ruinsGuardian, baseDamage: 52)
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
}
