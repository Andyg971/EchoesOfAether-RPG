import SpriteKit

// Forêt d'Ébène : interactions, combats de progression et chasses.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {

    // MARK: - Forest Interactions

    func tryForestInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        // Trek scrollable : les POI vivent en coordonnées MONDE
        // (fractions de worldHeight, synchronisées avec buildForest).
        let w = scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height

        // Les combats de la forêt (bosquet, clairière, chasses) ne se
        // déclenchent plus au tap : des monstres baladeurs chargent Kael
        // (cf. spawnForestRoamers).

        // Zone 3 : Seuil du sanctuaire (nord)
        if player.forestProgress >= 2 {
            let deepPath = CGPoint(x: w * 0.55, y: h * 0.90)
            if point.distance(to: deepPath) < 70 {
                enterShrine()
                return true
            }
        }

        // Jouet perdu (fourrés à l'est du campement)
        if player.questChildToy == .active {
            let toySpot = CGPoint(x: w * 0.80, y: h * 0.45)
            if point.distance(to: toySpot) < 60 {
                pickupToy()
                return true
            }
        }

        // Talisman perdu (quête de la villageoise, sentier ouest)
        if player.questMedallion == .active {
            let crossSpot = CGPoint(x: w * 0.28, y: h * 0.72)
            if point.distance(to: crossSpot) < 60 {
                pickupMedallion()
                return true
            }
        }

        // Fer corrompu (quête de Bram, sentier ouest sous la clairière)
        if player.questBramOre == .active {
            let oreSpot = CGPoint(x: w * 0.40, y: h * 0.63)
            if point.distance(to: oreSpot) < 60 {
                pickupOre()
                return true
            }
        }

        // Herbe lunaire (quête de Sage, ouest du sentier)
        if player.questSageHerb == .active {
            let herbSpot = CGPoint(x: w * 0.12, y: h * 0.40)
            if point.distance(to: herbSpot) < 60 {
                pickupHerb()
                return true
            }
        }

        // Insigne de l'éclaireur (quête de Garen, sente est)
        if player.questGarenScout == .active {
            let badgeSpot = CGPoint(x: w * 0.68, y: h * 0.18)
            if point.distance(to: badgeSpot) < 60 {
                pickupScoutBadge()
                return true
            }
        }

        // Entrée des mines de Cendreval (flanc est)
        let mineEntrance = CGPoint(x: w * 0.88, y: h * 0.30)
        if point.distance(to: mineEntrance) < 65 {
            enterMines()
            return true
        }

        // Entrée de la Caverne aux Échos (donjon optionnel, flanc ouest)
        let caveEntrance = CGPoint(x: w * 0.12, y: h * 0.80)
        if point.distance(to: caveEntrance) < 65 {
            enterCave()
            return true
        }

        return false
    }

    /// Chasse optionnelle : nid de goules (2 ennemis coriaces).
    func startGhoulCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startGhoulCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let name = String(localized: "combat.enemy.ghoul")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                          hp: 200, kind: .ghoul, baseDamage: 34),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                          hp: 200, kind: .ghoul, baseDamage: 34)
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
            // Chasse vaincue : ne recharge plus Kael avant la prochaine visite.
            forestHuntsCleared.insert("ghoul")
            spawnForestRoamers()
            transition(to: .exploration)
        }
    }

    /// Chasse optionnelle : squelette errant escorté d'une goule.
    func startBoneCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startBoneCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.bonewalker"),
                          hp: 320, kind: .boneWalker, baseDamage: 42),
                EnemySpec(name: String(localized: "combat.enemy.ghoul"),
                          hp: 180, kind: .ghoul, baseDamage: 32)
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
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            forestHuntsCleared.insert("bone")
            spawnForestRoamers()
            transition(to: .exploration)
        }
    }

    /// Ramasser le jouet perdu de l'enfant
    func pickupToy() {
        guard let scene else { return }
        player.questChildToy = .complete
        player.gold += 25
        syncGold()
        AudioEngine.shared.playQuestComplete()

        // Remove toy visual from world
        world.removeToyMarker()

        // Sparkle pickup effect (coordonnées monde — la forêt scrolle)
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let toySpot = CGPoint(x: scene.size.width * 0.80, y: wh * 0.45)
        world.worldNode.addChild(ParticleFactory.impactSparks(at: toySpot, color: SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), count: 12))

        transition(to: .dialogue)
        hud.questText = ""
        dialogue.start(PrototypeContent.toyFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

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

    /// Transition vers sanctuaire
    func enterShrine() {
        guard scene != nil else { return }
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.forestExitDialogue) { [weak self] in
            guard let self, let scene = self.scene else { return }
            transition(to: .transition)
            TransitionManager.fade(in: scene) { [weak self] in
                guard let self else { return }
                phase = .shrine
                hud.objectiveText = String(localized: "hud.objective.shrine")
                world.switchToShrine(in: scene)
            } completion: { [weak self] in
                self?.transition(to: .exploration)
            }
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

            let bossConfig = BossConfig(
                enrageThreshold: 0.45,
                enrageSpeedMult: 1.6,
                enrageDamageMult: 2,
                specialAttackInterval: 3,
                specialDamage: 68,
                specialName: String(localized: "combat.boss.specialName")
            )

            let levelBefore = player.level
            combat.attach(
                to: scene,
                enemyName: String(localized: "combat.enemy.guardian"),
                enemyHP: 620,
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
