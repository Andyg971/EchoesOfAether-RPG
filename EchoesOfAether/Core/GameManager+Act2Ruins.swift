import SpriteKit

// Acte II — les Ruines de la Source : interactions, inscription d'Eran, les deux combats.
extension GameManager {
    // MARK: - Ruins Interactions

    func tryRuinsInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let plan = RuinsLayout(sceneSize: scene.size)

        // Les combats ne se déclenchent plus au tap : les gardiens et
        // l'Archiviste chargent Kael, le contact ouvre le combat
        // (cf. spawnRuinsRoamers / RoamingMonster).

        // Inscription d'Eran, dans le renfoncement — dès l'entrée
        if !player.act2EranFound {
            if point.distance(to: plan.eranInscription) < 60 {
                openEranInscription()
                return true
            }
        }

        // Inscription principale (discovery) — débloquée après les 2 combats
        if player.ruinsProgress >= 2 {
            if point.distance(to: plan.discoveryWall) < 70 {
                openDiscovery()
                return true
            }
        }

        return false
    }

    func openEranInscription() {
        guard let scene else { return }
        transition(to: .dialogue)
        JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                 color: SKColor(red: 0.30, green: 0.45, blue: 0.80, alpha: 1),
                                 duration: 0.3)
        dialogue.start(PrototypeContent.act2EranInscriptionDialogue) { [weak self] in
            guard let self else { return }
            player.act2EranFound = true
            player.loreDiscovered.insert("eran")
            transition(to: .exploration)
        }
    }

    func startRuinsCombat1() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startRuinsCombat1() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        combat.attach(
            to: scene,
            enemyName: String(localized: "combat.enemy.ruinsGuardian"),
            enemyHP: EncounterBalance.SideBoss.ruinsSentinel,
            goldReward: 30,
            player: player,
            enemyKind: .ruinsGuardian,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.ruinsProgress = 1
            syncGold()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.ruins")
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act2RuinsCombat1Dialogue) { [weak self] in
                // Gardiens vaincus → l'Archiviste prend le relais.
                self?.spawnRuinsRoamers()
                self?.transition(to: .exploration)
            }
        }
    }

    func startRuinsCombat2() {
        guard scene != nil else { return }
        // Dialogue pré-combat Archiviste
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act2ArchivistPreDialogue) { [weak self] in
            guard let self, let scene = self.scene else { return }
            transition(to: .combat)
            hud.objectiveText = String(localized: "hud.objective.combat")

            // L'Archiviste a catalogué chaque âme que Kael a prise : tant que
            // son registre est intact (bouclier debout), il se RECOMPOSE à
            // chaque tour. On ne le bat pas en frappant fort, mais en le
            // brisant sur ses faiblesses — son combat est une énigme.
            // Il était le boss le PLUS FAIBLE du jeu (520 PV) alors qu'il
            // clôt l'Acte II, après un Gardien à 860. Sa rage se déclenchait
            // aussi très tard (35 %), ce qui la réduisait à un baroud final.
            let bossConfig = BossConfig(
                enrageThreshold: EncounterBalance.Archivist.enrageThreshold,
                enrageSpeedMult: 1.5,
                enrageDamageMult: 2,
                specialAttackInterval: 3,
                specialDamage: EncounterBalance.Archivist.specialDamage,
                specialName: String(localized: "combat.archivist.specialName"),
                regenPercent: 0.07,
                regenName: String(localized: "combat.archivist.regen"),
                music: .boss
            )

            let levelBefore = player.level
            combat.attach(
                to: scene,
                enemyName: String(localized: "combat.enemy.archivist"),
                enemyHP: EncounterBalance.Archivist.hp,
                goldReward: 55,
                player: player,
                enemyKind: .archivist,
                boss: bossConfig,
                withLyra: lyraInParty
            ) { [weak self] resonance, gold in
                guard let self, let scene = self.scene else { return }
                if resonance < 0 { showDeathScreen(); return }
                grantLevelUpDisplay(from: levelBefore)
                resonanceTotal += resonance
                player.gold += gold
                player.ruinsProgress = 2
                player.kaelCorruptionLevel = max(player.kaelCorruptionLevel, 2)
                player.loreDiscovered.insert("archivist")
                clearRoamers()   // Archiviste vaincu : les Ruines sont calmes.
                syncGold()
                hud.resonanceValue = resonanceTotal
                hud.objectiveText = String(localized: "hud.objective.discovery")

                // Vision 2 : flash rouge + corruption niveau 2
                JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                         color: SKColor(red: 0.70, green: 0.08, blue: 0.05, alpha: 1),
                                         duration: 0.5)
                JuiceEngine.screenShake(scene, intensity: 5)
                world.applyKaelCorruption(level: player.kaelCorruptionLevel)

                transition(to: .dialogue)
                dialogue.start(PrototypeContent.act2ArchivistPostDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            }
        }
    }
}
