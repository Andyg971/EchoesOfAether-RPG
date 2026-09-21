import SpriteKit

// Forêt d'Ébène — les combats de l'histoire : bosquet, clairière, Sanctuaire, boss.
extension GameManager {
    // MARK: - Forest Combat

    /// Combat 1 : Bête corrompue dans le bosquet
    func startGroveCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startGroveCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        combat.attach(
            to: scene,
            enemyName: String(localized: "combat.enemy.beast"),
            enemyHP: 240,
            goldReward: 35,
            player: player,
            enemyKind: .beast,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.forestProgress = 1
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.clearing")
            GameCenterManager.shared.report(.firstBlood)
            spawnForestRoamers()   // fait apparaître les loups de la clairière
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.forestGroveDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Combat 2 : Loups d'ombre dans la clairière
    func startClearingCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startClearingCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        // La clairière sombre : une MEUTE de deux loups d'ombre.
        let wolfName = String(localized: "combat.enemy.wolf")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(wolfName) \(1)"),
                          hp: 175, kind: .wolf, baseDamage: 26),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(wolfName) \(2)"),
                          hp: 175, kind: .wolf, baseDamage: 26)
            ],
            goldReward: 50,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.forestProgress = 2
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.deepPath")
            spawnForestRoamers()   // plus de combat de progression, chasses restent
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.blackAetherDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Fin de la forêt : la scène du départ se joue, puis Kael SORT SUR LA
    /// CARTE DU MONDE. Le Sanctuaire y devient un lieu qu'il rejoint à pied
    /// (bouton A) pour l'affronter — au lieu d'y basculer directement.
    func enterShrine() {
        guard scene != nil else { return }
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.forestExitDialogue) { [weak self] in
            guard let self else { return }
            phase = .shrine
            discoveredPlaces.insert("shrine")   // le Sanctuaire s'ouvre sur la carte
            enterOverworld(spawnNear: "forest")
        }
    }

    /// Quitte le sanctuaire pour retourner à la forêt (le joueur peut se
    /// renforcer avant d'affronter le Gardien).
    func exitShrine() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            phase = .forest
            hud.objectiveText = String(localized: "hud.objective.deepPath")
            showForest(in: scene)
        } completion: { [weak self] in
            guard let self, let scene = self.scene else { return }
            addSideQuestMarkers(in: scene)
            let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            world.kael.position = CGPoint(x: scene.size.width * 0.55, y: wh * 0.86)
            transition(to: .exploration)
        }
    }

    func startBossFight() {
        guard scene != nil else { return }
        guard !player.bossDefeated else {
            // Boss déjà vaincu (ex. save d'une session interrompue après la
            // victoire) → fin de sanctuaire PUIS suite vers l'Acte II, comme
            // le chemin de victoire. Sans onContinue, l'écran de fin n'a pas
            // de bouton Continuer → jeu figé, Actes II–IV inatteignables.
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.shrineEnding) { [weak self] in
                guard let self, let scene = self.scene else { return }
                phase = .complete
                hud.objectiveText = String(localized: "hud.objective.complete")
                transition(to: .exploration)
                TransitionManager.showEndScreen(in: scene, resonance: resonanceTotal) { [weak self] in
                    // Fin de l'Acte I : la suite est derrière l'achat.
                    self?.requireFullGame { [weak self] in self?.beginAct2() }
                }
            }
            return
        }

        // Pre-combat dialogue
        lastCombatStarter = { [weak self] in self?.startBossFight() }
        transition(to: .dialogue)
        hud.objectiveText = String(localized: "hud.objective.boss")
        dialogue.start(PrototypeContent.bossPreDialogue) { [weak self] in
            guard let self, let scene = self.scene else { return }
            transition(to: .combat)

            // Le Gardien tombait trop vite pour un boss de fin d'acte.
            //
            // Le durcissement passe surtout par les PV, pas par les dégâts :
            // gonfler les dégâts transforme le combat en loterie de premier
            // tour, gonfler les PV laisse au joueur le temps de jouer le
            // système (cf. la même règle dans `Difficulty`). Le BREAK rend
            // 1,8× de dégâts : qui exploite ses faiblesses (GLACE, AETHER)
            // garde un rythme correct, qui tape au hasard sent le mur.
            //
            // La rage se déclenche aussi plus tôt (55 % au lieu de 45 %) :
            // la phase dangereuse dure plus longtemps qu'un baroud final.
            let bossConfig = BossConfig(
                enrageThreshold: EncounterBalance.Guardian.enrageThreshold,
                enrageSpeedMult: 1.6,
                enrageDamageMult: 2,
                specialAttackInterval: 3,
                specialDamage: EncounterBalance.Guardian.specialDamage,
                specialName: String(localized: "combat.boss.specialName")
            )

            let levelBefore = player.level
            combat.attach(
                to: scene,
                enemyName: String(localized: "combat.enemy.guardian"),
                enemyHP: EncounterBalance.Guardian.hp,
                goldReward: 120,
                player: player,
                enemyKind: .guardian,
                boss: bossConfig,
                withLyra: lyraInParty
            ) { [weak self] resonance, gold in
                guard let self else { return }

                if resonance < 0 {
                    showDeathScreen()
                    return
                }

                // Victory
                grantLevelUpDisplay(from: levelBefore)
                resonanceTotal += resonance
                player.gold += gold
                player.bossDefeated = true
                syncGold()
                AudioEngine.shared.playGoldGain()
                AudioEngine.shared.playQuestComplete()
                hud.resonanceValue = resonanceTotal
                GameCenterManager.shared.report(.bossDefeated)

                // Post-combat dialogue → shrine ending → Acte II
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.bossPostDialogue) { [weak self] in
                    guard let self else { return }
                    transition(to: .dialogue)
                    dialogue.start(PrototypeContent.shrineEnding) { [weak self] in
                        guard let self, let scene = self.scene else { return }
                        phase = .complete
                        hud.objectiveText = String(localized: "hud.objective.complete")
                        transition(to: .exploration)
                        TransitionManager.showEndScreen(in: scene, resonance: resonanceTotal) { [weak self] in
                            // Fin de l'Acte I : la suite est derrière l'achat.
                            self?.requireFullGame { [weak self] in self?.beginAct2() }
                        }
                    }
                }
            }
        }
    }
}
