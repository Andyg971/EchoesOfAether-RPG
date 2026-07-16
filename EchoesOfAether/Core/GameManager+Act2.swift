import SpriteKit

// Acte II : village corrompu, ruines, découverte et mort de Lyra.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {

    // MARK: - Act 2 Flow

    func beginAct2() {
        guard let scene else { return }
        GameCenterManager.shared.report(.act2Reached)
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            phase = .act2
            hud.objectiveText = String(localized: "hud.objective.act2")
            world.switchToVillage(in: scene)
            world.repositionDorinToGate(in: scene)
        } completion: { [weak self] in
            guard let self else { return }
            // Retour au village + révélation du Sage (auto)
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act2ReturnVillageDialogue) { [weak self] in
                guard let self else { return }
                dialogue.start(PrototypeContent.act2SageRevelationDialogue) { [weak self] in
                    guard let self else { return }
                    player.act2SageConsulted = true
                    hud.objectiveText = String(localized: "hud.objective.ruins")
                    transition(to: .exploration)
                }
            }
        }
    }

    // MARK: - Act 2 Village NPC interactions

    func tryAct2VillageInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let radius: CGFloat = 32
        // Garen est masqué en Acte II (cf. repositionDorinToGate) — donc absent
        // des candidats. On choisit le PNJ le plus proche dans le rayon pour
        // éviter un conflit de tap quand Dorin (porte nord) est proche d'un autre.
        let candidates: [(node: SKNode, action: () -> Void)] = [
            (world.lyra,     { [weak self] in self?.openAct2LyraDialogue() }),
            (world.dorin,    { [weak self] in self?.handleAct2Dorin(scene: scene) }),
            (world.sage,     { [weak self] in self?.handleAct2Sage(scene: scene) }),
            (world.bram,     { [weak self] in self?.openBramShop() }),
            (world.mara,     { [weak self] in self?.openMaraInteraction(scene: scene) }),
            (world.child,    { [weak self] in self?.openAct2ChildDialogue() }),
            (world.villager, { [weak self] in self?.openAct2VillagerDialogue() })
        ]
        if let action = nearestInteraction(from: point, candidates: candidates, radius: radius) {
            action()
            return true
        }
        return false
    }

    func openAct2LyraDialogue() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act2LyraAnalysisDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// L'enfant a peur de Kael maintenant — la corruption se voit.
    func openAct2ChildDialogue() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.childAct2Dialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// La villageoise avertit Kael : ne pas écouter la Voix.
    func openAct2VillagerDialogue() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.villagerAct2Dialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Dorin garde la porte nord (Garen retiré Acte II) :
    /// 1) bloque si !act2DorinPassed
    /// 2) ouvre les ruines si Sage consulté
    /// 3) sinon doute (Dorin attend que Kael consulte le Sage)
    func handleAct2Dorin(scene: SKScene) {
        if !player.act2DorinPassed {
            openDorinBlock(scene: scene)
        } else if player.act2SageConsulted {
            enterRuins()
        } else {
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act2DorinDoubtDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Sage / auberge : cauchemar d'abord si pas encore vu.
    func handleAct2Sage(scene: SKScene) {
        if !player.act2NightmareSeen {
            openNightmareSequence(scene: scene)
        } else {
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act2SageRevelationDialogue) { [weak self] in
                guard let self else { return }
                player.act2SageConsulted = true
                transition(to: .exploration)
            }
        }
    }

    func openNightmareSequence(scene: SKScene) {
        transition(to: .dialogue)
        // Flash sombre pour simuler le rêve
        JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                 color: SKColor(red: 0.05, green: 0.02, blue: 0.10, alpha: 1),
                                 duration: 0.5)
        dialogue.start(PrototypeContent.act2NightmareDialogue) { [weak self] in
            guard let self else { return }
            player.act2NightmareSeen = true
            // Après le cauchemar : révélation du Sage
            transition(to: .shop)
            shop.open(
                title: String(localized: "shop.inn.title"),
                items: innItems(),
                player: player
            ) { [weak self] in
                guard let self else { return }
                syncGold()
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.act2SageRevelationDialogue) { [weak self] in
                    guard let self else { return }
                    player.act2SageConsulted = true
                    transition(to: .exploration)
                }
            }
        }
    }

    func openDorinBlock(scene: SKScene) {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act2DorinBlockDialogue) { [weak self] in
            guard let self else { return }
            player.act2DorinPassed = true
            transition(to: .exploration)
        }
    }

    func enterRuins() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            phase = .ruins
            hud.objectiveText = String(localized: "hud.objective.ruins")
            showRuins(in: scene)
        } completion: { [weak self] in
            guard let self else { return }
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act2RuinsEnterDialogue) { [weak self] in
                guard let self, let scene = self.scene else { return }
                // Vision 1 automatique — flash rouge + corruption niveau 1
                if !player.act2Vision1Seen {
                    player.act2Vision1Seen = true
                    player.kaelCorruptionLevel = max(player.kaelCorruptionLevel, 1)
                    world.applyKaelCorruption(level: player.kaelCorruptionLevel)
                    JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                             color: SKColor(red: 0.65, green: 0.08, blue: 0.05, alpha: 1),
                                             duration: 0.45)
                    JuiceEngine.screenShake(scene, intensity: 3)
                    dialogue.start(PrototypeContent.act2Vision1Dialogue) { [weak self] in
                        self?.transition(to: .exploration)
                    }
                } else {
                    transition(to: .exploration)
                }
            }
        }
    }

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
            enemyHP: 360,
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

            let bossConfig = BossConfig(
                enrageThreshold: 0.35,
                enrageSpeedMult: 1.5,
                enrageDamageMult: 2,
                specialAttackInterval: 3,
                specialDamage: 62,
                specialName: String(localized: "combat.archivist.specialName")
            )

            let levelBefore = player.level
            combat.attach(
                to: scene,
                enemyName: String(localized: "combat.enemy.archivist"),
                enemyHP: 520,
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

    // MARK: - Discovery → Lyra Death → Act 2 End

    func openDiscovery() {
        guard scene != nil else { return }
        transition(to: .dialogue)
        // Lyra offre le cristal — moment calme avant la tempête
        dialogue.start(PrototypeContent.act2LyraGiftDialogue) { [weak self] in
            guard let self, let scene = self.scene else { return }
            // Corruption maximale — niveau 3
            player.kaelCorruptionLevel = 3
            player.loreDiscovered.insert("void")
            world.applyKaelCorruption(level: 3)
            GameCenterManager.shared.report(.corruptedSoul)
            JuiceEngine.screenShake(scene, intensity: 4)

            // Cinématique de corruption si pas encore vue
            if !corruptionCinematicShown {
                corruptionCinematicShown = true
                TransitionManager.showCorruptionCinematic(in: scene) { [weak self] in
                    guard let self else { return }
                    dialogue.start(PrototypeContent.act2DiscoveryDialogue) { [weak self] in
                        self?.triggerLyraDeath()
                    }
                }
            } else {
                // Flash rouge si déjà vue
                JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                         color: SKColor(red: 0.7, green: 0.08, blue: 0.05, alpha: 1),
                                         duration: 0.4)
                dialogue.start(PrototypeContent.act2DiscoveryDialogue) { [weak self] in
                    self?.triggerLyraDeath()
                }
            }
        }
    }

    func triggerLyraDeath() {
        guard let scene else { return }
        // Fade total vers le noir
        let blackOut = SKShapeNode(rectOf: scene.size)
        blackOut.fillColor = .black
        blackOut.strokeColor = .clear
        blackOut.alpha = 0
        blackOut.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        blackOut.zPosition = 1999
        scene.addChild(blackOut)
        blackOut.run(.sequence([.fadeAlpha(to: 1, duration: 0.8), .wait(forDuration: 0.3)]))

        // Dialogue mort après le noir
        blackOut.run(.sequence([.wait(forDuration: 0.4)])) { [weak self] in
            guard let self else { return }
            transition(to: .dialogue)
            // Si Eran trouvé : Lyra prononce ses derniers mots en écho
            let startDeath: () -> Void = { [weak self] in
                guard let self else { return }
                dialogue.start(PrototypeContent.act2LyraDeathDialogue) { [weak self] in
                    guard let self else { return }
                    player.lyraDeceased = true
                    world.lyra.isHidden = true
                    dialogue.start(PrototypeContent.act2KaelAloneDialogue) { [weak self] in
                        guard let self, let scene = self.scene else { return }
                        blackOut.removeFromParent()
                        phase = .fallen
                        transition(to: .exploration)
                        saveGame()
                        TransitionManager.showAct2EndScreen(in: scene) { [weak self] in
                            guard let self, let sc = self.scene else { return }
                            TransitionManager.showCredits(in: sc) { [weak self] in
                                self?.beginAct3()
                            }
                        }
                    }
                }
            }
            if player.act2EranFound {
                dialogue.start(PrototypeContent.act2LyraEranLastWordDialogue) { startDeath() }
            } else {
                startDeath()
            }
        }
    }
}
