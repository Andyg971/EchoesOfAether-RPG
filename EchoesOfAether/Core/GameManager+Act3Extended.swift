import SpriteKit

// Acte III étendu : écho de Lyra, esprits, stèles du Vide, Ombres.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {

    // MARK: - Acte III étendu (écho, esprits, stèles, ombres)

    /// L'Écho de Lyra rejoint Kael — première scène du Seuil.
    func openAct3EchoMeet() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act3EchoMeetDialogue) { [weak self] in
            guard let self, let scene else { return }
            player.act3EchoJoined = true
            world.removeThresholdEcho()
            world.showLyraEcho(in: scene)
            AudioEngine.shared.playQuestComplete()
            hud.questText = String(localized: "hud.quest.spirits \(player.act3SpiritsCalmed.count)")
            saveGame()
            transition(to: .exploration)
        }
    }

    /// Apaise un esprit errant ; les trois apaisés = récompense.
    func openSpiritDialogue(id: String) {
        transition(to: .dialogue)
        let steps: [DialogueStep]
        switch id {
        case "miner": steps = PrototypeContent.spiritMinerDialogue
        case "mother": steps = PrototypeContent.spiritMotherDialogue
        default: steps = PrototypeContent.spiritGuardDialogue
        }
        dialogue.start(steps) { [weak self] in
            guard let self else { return }
            player.act3SpiritsCalmed.insert(id)
            world.calmSpirit(id: id)
            AudioEngine.shared.playQuestComplete()
            hud.questText = String(localized: "hud.quest.spirits \(player.act3SpiritsCalmed.count)")
            if player.act3SpiritsCalmed.count >= 3 {
                player.gold += 90
                syncGold()
                AudioEngine.shared.playGoldGain()
                hud.questText = String(localized: "quest.spirits.rewardMsg")
                player.loreDiscovered.insert("lostEchoes")
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.spiritsDoneDialogue) { [weak self] in
                    self?.saveGame()
                    self?.transition(to: .exploration)
                }
            } else {
                saveGame()
                transition(to: .exploration)
            }
        }
    }

    /// Lit une stèle du Vide ; les trois lues = lore + or.
    func openSteleDialogue(id: String) {
        transition(to: .dialogue)
        guard let index = Int(id) else { transition(to: .exploration); return }
        dialogue.start(PrototypeContent.steleDialogue(index)) { [weak self] in
            guard let self else { return }
            player.act3StelesRead.insert(id)
            hud.questText = String(localized: "hud.quest.steles \(player.act3StelesRead.count)")
            if player.act3StelesRead.count >= 3 {
                player.gold += 60
                syncGold()
                AudioEngine.shared.playGoldGain()
                hud.questText = String(localized: "quest.steles.rewardMsg")
                player.loreDiscovered.insert("eranPast")
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.stelesDoneDialogue) { [weak self] in
                    self?.saveGame()
                    self?.transition(to: .exploration)
                }
            } else {
                saveGame()
                transition(to: .exploration)
            }
        }
    }

    /// Combat annexe : les Ombres du Vide (trio requis : l'Écho a rejoint).
    func startVoidShadesCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startVoidShadesCombat() }
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.shadesPreDialogue) { [weak self] in
            guard let self, let scene2 = self.scene else { return }
            _ = scene
            transition(to: .combat)
            let name = String(localized: "combat.enemy.voidShade")
            let levelBefore = player.level
            combat.attach(
                to: scene2,
                enemySpecs: [
                    EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                              hp: 300, kind: .boneWalker, baseDamage: 44),
                    EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                              hp: 300, kind: .boneWalker, baseDamage: 44),
                    EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(3)"),
                              hp: 260, kind: .wolf, baseDamage: 40)
                ],
                goldReward: 110,
                player: player,
                allyKinds: act3Party
            ) { [weak self] resonance, gold in
                guard let self else { return }
                if resonance < 0 { showDeathScreen(); return }
                grantLevelUpDisplay(from: levelBefore)
                resonanceTotal += resonance
                player.gold += gold
                player.act3ShadesDefeated = true
                syncGold()
                AudioEngine.shared.playGoldGain()
                hud.resonanceValue = resonanceTotal
                refreshThresholdBackdrop()
                saveGame()
                transition(to: .exploration)
            }
        }
    }

    /// Reconstruit le décor du Seuil selon la progression.
    func refreshThresholdBackdrop() {
        guard let scene, phase == .act3 else { return }
        let kaelPos = world.kael.position
        world.switchToThreshold(in: scene,
                                echoJoined: player.act3EchoJoined,
                                spiritsCalmed: player.act3SpiritsCalmed,
                                shadesDefeated: player.act3ShadesDefeated)
        world.kael.position = kaelPos
    }

    func beginAct3() {
        guard let scene else { return }
        GameCenterManager.shared.report(.act3Reached)
        // Lore collector — 4/4 entries
        if player.loreDiscovered.count >= 4 {
            GameCenterManager.shared.report(.loreCollector)
        }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            phase = .act3
            hud.objectiveText = String(localized: "hud.objective.act3")
            world.switchToThreshold(in: scene,
                                    echoJoined: player.act3EchoJoined,
                                    spiritsCalmed: player.act3SpiritsCalmed,
                                    shadesDefeated: player.act3ShadesDefeated)
            world.applyKaelCorruption(level: 3)
        } completion: { [weak self] in
            guard let self else { return }
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act3PrologueDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Rencontre Eran au Seuil. Débloque ensuite le combat contre le Gardien.
    func openAct3EranMeet() {
        transition(to: .dialogue)
        // Le choix d'Eran détermine la fin : 0 = franchir le Seuil (hubris),
        // 1 = résister / refuser le Vide (lucidité). Capturé ici, appliqué à
        // la toute fin (showAct3Ending), et persisté dans la sauvegarde.
        dialogue.onChoiceSelected = { [weak self] index in
            guard let self else { return }
            player.act3EndingChoice = index
            saveGame()
        }
        dialogue.start(PrototypeContent.act3EranMeetDialogue) { [weak self] in
            guard let self else { return }
            dialogue.onChoiceSelected = nil
            player.act3EranMet = true
            player.loreDiscovered.insert("threshold")
            hud.objectiveText = String(localized: "hud.objective.act3Boss")
            // Eran rejoint le trio pour la suite du Seuil.
            dialogue.start(PrototypeContent.act3EranJoinDialogue) { [weak self] in
                guard let self else { return }
                AudioEngine.shared.playQuestComplete()
                saveGame()
                transition(to: .exploration)
            }
        }
    }

    /// Boss final — le Gardien du Seuil. Réutilise le sprite `.guardian`.
    func startThresholdBoss() {
        guard scene != nil else { return }
        lastCombatStarter = { [weak self] in self?.startThresholdBoss() }
        transition(to: .dialogue)
        hud.objectiveText = String(localized: "hud.objective.act3Boss")
        dialogue.start(PrototypeContent.act3GuardianPreDialogue) { [weak self] in
            guard let self, let scene = self.scene else { return }
            transition(to: .combat)

            // Boss FINAL : le mur du jeu. Enrage tôt, spéciale fréquente
            // et brutale — le joueur doit maîtriser break/boost/soin.
            let bossConfig = BossConfig(
                enrageThreshold: 0.60,
                enrageSpeedMult: 1.8,
                enrageDamageMult: 3,
                specialAttackInterval: 2,
                specialDamage: 92,
                specialName: String(localized: "combat.thresholdGuardian.specialName")
            )

            let levelBefore = player.level
            combat.attach(
                to: scene,
                enemyName: String(localized: "combat.enemy.thresholdGuardian"),
                enemyHP: 1400,
                goldReward: 0,
                player: player,
                enemyKind: .guardian,
                boss: bossConfig,
                allyKinds: act3Party
            ) { [weak self] resonance, gold in
                guard let self else { return }
                if resonance < 0 { showDeathScreen(); return }
                grantLevelUpDisplay(from: levelBefore)
                resonanceTotal += resonance
                player.gold += gold
                player.act3BossDefeated = true
                syncGold()
                hud.resonanceValue = resonanceTotal
                hud.objectiveText = String(localized: "hud.objective.act3End")
                AudioEngine.shared.playQuestComplete()
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.act3GuardianPostDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            }
        }
    }

    /// Fin de l'Acte III — branchée selon le choix d'Eran :
    /// - 0 (ou non choisi) : Kael FRANCHIT le Seuil (embrasse le Vide).
    /// - 1 : Kael RÉSISTE / refuse le Vide.
    /// Chaque fin enchaîne ses dialogues → crédits → menu.
    func showAct3TrueEnding() {
        guard scene != nil else { return }
        AudioEngine.shared.setMood(.finale)   // « New Sunrise » (CC0)
        transition(to: .dialogue)
        // Par défaut (aucun choix capturé), on retombe sur la fin "franchir".
        if player.act3EndingChoice == 1 {
            showAct3ResistEnding()
        } else {
            showAct3CrossEnding()
        }
    }

    /// Fin "Franchir le Seuil" — Kael embrasse le Vide. Ce n'est plus une
    /// fin : le Seuil s'ouvre sur l'Acte IV, le Cœur du Vide.
    ///
    /// Point de non-retour façon FF/Persona : avant de franchir, Kael reçoit
    /// une dernière mise en garde. « Rester » le renvoie explorer et préparer
    /// le Seuil (le gate reste franchissable) ; « Franchir » est irréversible.
    func showAct3CrossEnding() {
        guard scene != nil else { return }
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act4ThresholdWarningDialogue) { [weak self] in
            guard let self else { return }
            if dialogue.lastChoiceIndex == 1 {
                // Demi-tour : on quitte l'ambiance finale, retour exploration.
                AudioEngine.shared.setMood(.forPhase(phase))
                transition(to: .exploration)
            } else {
                performAct3Crossing()
            }
        }
    }

    /// Franchissement effectif du Seuil : narration de fin d'Acte III puis
    /// bascule vers l'Acte IV. Appelé uniquement après confirmation « Franchir ».
    private func performAct3Crossing() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act3TrueEndingDialogue) { [weak self] in
            guard let self else { return }
            // « Ce n'était que le début » — la Voix annonce l'Acte IV.
            dialogue.start(PrototypeContent.act3EndPlaceholder) { [weak self] in
                self?.beginAct4()
            }
        }
    }

    /// Fin "Résister / refuser le Vide" — Kael tourne le dos au Seuil.
    func showAct3ResistEnding() {
        dialogue.start(PrototypeContent.act3ResistEndingDialogue) { [weak self] in
            guard let self else { return }
            AudioEngine.shared.setMood(.finale)
            dialogue.start(PrototypeContent.act3ResistEpilogueDialogue) { [weak self] in
                self?.rollCreditsToMenu()
            }
        }
    }

    func rollCreditsToMenu() {
        guard let scene else { return }
        transition(to: .exploration)
        TransitionManager.showCredits(in: scene) { [weak self] in
            self?.onReturnToMenu?()
        }
    }
}
