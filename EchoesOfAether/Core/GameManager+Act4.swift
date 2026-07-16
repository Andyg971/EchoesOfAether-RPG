import SpriteKit

// Acte IV — Le Cœur du Vide : mémoires, reflets, dévoreurs, fins.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {

    // MARK: - Act IV — Le Cœur du Vide

    /// Kael, l'Écho et Eran franchissent le Seuil : entrée dans l'Acte IV.
    func beginAct4() {
        guard let scene else { return }
        GameCenterManager.shared.report(.act4Reached)
        AudioEngine.shared.setMood(.voidThreshold)
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            phase = .act4
            player.loreDiscovered.insert("voidheart")
            hud.objectiveText = String(localized: "hud.objective.act4")
            showVoidHeart(in: scene)
            world.applyKaelCorruption(level: 3)
        } completion: { [weak self] in
            guard let self else { return }
            saveGame()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act4PrologueDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Dispatch des interactions du Cœur du Vide.
    func tryAct4Interaction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let plan = VoidHeartLayout(sceneSize: scene.size)
        let heart = plan.heart

        // Fragments de mémoire (quête « Les souvenirs de Kael »)
        for memory in plan.memories where !player.act4MemoriesSeen.contains(memory.id) {
            if point.distance(to: memory.pos) < 55 {
                openAct4Memory(id: memory.id)
                return true
            }
        }

        // Reflets absorbés (quête « Les visages du Vide »)
        for id in ["elder", "smith", "lost"]
        where !player.act4ReflectionsFreed.contains(id) {
            if let pos = world.spiritPosition(id: id),
               point.distance(to: pos) < 60 {
                openAct4Reflection(id: id)
                return true
            }
        }

        // Les Dévoreurs chargent Kael (cf. spawnAct4Roamers) : plus de
        // combat au tap.

        // 1) Confrontation de la Voix (le choix final est capturé ici)
        if !player.act4VoiceConfronted {
            if point.distance(to: plan.voiceConfront) < 80 {
                openAct4VoiceConfront()
                return true
            }
            return false
        }
        // 2) L'Avatar du Vide — boss final de l'Acte IV
        if !player.act4BossDefeated {
            if point.distance(to: heart) < 90 {
                startVoidAvatarBoss()
                return true
            }
            return false
        }
        // 3) Le Cœur à nu → fin selon le choix
        if point.distance(to: heart) < 90 {
            showAct4Ending()
            return true
        }
        return false
    }

    /// Revoit un fragment de mémoire ; les trois vus = lore + or.
    func openAct4Memory(id: String) {
        transition(to: .dialogue)
        guard let index = Int(id) else { transition(to: .exploration); return }
        dialogue.start(PrototypeContent.act4MemoryDialogue(index)) { [weak self] in
            guard let self else { return }
            player.act4MemoriesSeen.insert(id)
            hud.questText = String(localized: "hud.quest.memories \(player.act4MemoriesSeen.count)")
            if player.act4MemoriesSeen.count >= 3 {
                player.gold += 70
                syncGold()
                AudioEngine.shared.playGoldGain()
                hud.questText = String(localized: "quest.memories.rewardMsg")
                player.loreDiscovered.insert("kaelMemories")
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.act4MemoriesDoneDialogue) { [weak self] in
                    self?.saveGame()
                    self?.transition(to: .exploration)
                }
            } else {
                saveGame()
                transition(to: .exploration)
            }
        }
    }

    /// Libère un reflet absorbé ; les trois libérés = récompense.
    func openAct4Reflection(id: String) {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act4ReflectionDialogue(id: id)) { [weak self] in
            guard let self else { return }
            player.act4ReflectionsFreed.insert(id)
            world.calmSpirit(id: id)
            AudioEngine.shared.playQuestComplete()
            hud.questText = String(localized: "hud.quest.reflections \(player.act4ReflectionsFreed.count)")
            if player.act4ReflectionsFreed.count >= 3 {
                player.gold += 100
                syncGold()
                AudioEngine.shared.playGoldGain()
                hud.questText = String(localized: "quest.reflections.rewardMsg")
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.act4ReflectionsDoneDialogue) { [weak self] in
                    self?.saveGame()
                    self?.transition(to: .exploration)
                }
            } else {
                saveGame()
                transition(to: .exploration)
            }
        }
    }

    /// Combat annexe : les Dévoreurs d'échos.
    func startDevourersCombat() {
        guard scene != nil else { return }
        lastCombatStarter = { [weak self] in self?.startDevourersCombat() }
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act4DevourersPreDialogue) { [weak self] in
            guard let self, let scene = self.scene else { return }
            transition(to: .combat)
            let name = String(localized: "combat.enemy.echoDevourer")
            let levelBefore = player.level
            combat.attach(
                to: scene,
                enemySpecs: [
                    EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                              hp: 340, kind: .boneWalker, baseDamage: 48),
                    EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                              hp: 340, kind: .boneWalker, baseDamage: 48),
                    EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(3)"),
                              hp: 300, kind: .wolf, baseDamage: 44)
                ],
                goldReward: 130,
                player: player,
                allyKinds: act3Party
            ) { [weak self] resonance, gold in
                guard let self else { return }
                if resonance < 0 { showDeathScreen(); return }
                grantLevelUpDisplay(from: levelBefore)
                resonanceTotal += resonance
                player.gold += gold
                player.act4DevourersDefeated = true
                syncGold()
                AudioEngine.shared.playGoldGain()
                hud.resonanceValue = resonanceTotal
                refreshVoidHeartBackdrop()
                saveGame()
                transition(to: .exploration)
            }
        }
    }

    /// Reconstruit le décor du Cœur selon la progression.
    func refreshVoidHeartBackdrop() {
        guard let scene, phase == .act4 else { return }
        showVoidHeart(in: scene, placeKael: false)
    }

    /// Confrontation de la Voix — capture le choix final de Kael :
    /// 0 = détruire le Cœur, 1 = fusionner avec le Cœur.
    func openAct4VoiceConfront() {
        transition(to: .dialogue)
        dialogue.onChoiceSelected = { [weak self] index in
            guard let self else { return }
            player.act4EndingChoice = index
            saveGame()
        }
        dialogue.start(PrototypeContent.act4VoiceConfrontDialogue) { [weak self] in
            guard let self else { return }
            dialogue.onChoiceSelected = nil
            player.act4VoiceConfronted = true
            hud.objectiveText = String(localized: "hud.objective.act4Boss")
            AudioEngine.shared.playQuestComplete()
            saveGame()
            transition(to: .exploration)
        }
    }

    /// Boss final de l'Acte IV — l'Avatar du Vide.
    func startVoidAvatarBoss() {
        guard scene != nil else { return }
        lastCombatStarter = { [weak self] in self?.startVoidAvatarBoss() }
        transition(to: .dialogue)
        hud.objectiveText = String(localized: "hud.objective.act4Boss")
        dialogue.start(PrototypeContent.act4AvatarPreDialogue) { [weak self] in
            guard let self, let scene = self.scene else { return }
            transition(to: .combat)

            // Au-delà du Gardien du Seuil : enrage plus tôt, frappe plus
            // fort — le trio complet et le niveau 30 sont attendus ici.
            let bossConfig = BossConfig(
                enrageThreshold: 0.55,
                enrageSpeedMult: 1.8,
                enrageDamageMult: 3,
                specialAttackInterval: 2,
                specialDamage: 98,
                specialName: String(localized: "combat.voidAvatar.specialName")
            )

            let levelBefore = player.level
            combat.attach(
                to: scene,
                enemyName: String(localized: "combat.enemy.voidAvatar"),
                enemyHP: 1600,
                goldReward: 0,
                player: player,
                enemyKind: .ruinsGuardian,
                boss: bossConfig,
                allyKinds: act3Party
            ) { [weak self] resonance, gold in
                guard let self else { return }
                if resonance < 0 { showDeathScreen(); return }
                grantLevelUpDisplay(from: levelBefore)
                resonanceTotal += resonance
                player.gold += gold
                player.act4BossDefeated = true
                syncGold()
                hud.resonanceValue = resonanceTotal
                hud.objectiveText = String(localized: "hud.objective.act4End")
                AudioEngine.shared.playQuestComplete()
                refreshVoidHeartBackdrop()
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.act4AvatarPostDialogue) { [weak self] in
                    self?.saveGame()
                    self?.transition(to: .exploration)
                }
            }
        }
    }

    /// Fin de l'Acte IV — branchée selon le choix devant la Voix :
    /// - 0 (ou non choisi) : Kael DÉTRUIT le Cœur (libère les échos).
    /// - 1 : Kael FUSIONNE avec le Cœur (devient le nouveau gardien).
    func showAct4Ending() {
        guard scene != nil else { return }
        AudioEngine.shared.setMood(.finale)
        transition(to: .dialogue)
        if player.act4EndingChoice == 1 {
            showAct4MergeEnding()
        } else {
            showAct4DestroyEnding()
        }
    }

    /// Fin « Détruire le Cœur » — les échos sont libérés, Lyra part en paix.
    func showAct4DestroyEnding() {
        dialogue.start(PrototypeContent.act4DestroyEndingDialogue) { [weak self] in
            guard let self else { return }
            dialogue.start(PrototypeContent.act4DestroyEndScreen) { [weak self] in
                self?.rollCreditsToMenu()
            }
        }
    }

    /// Fin « Fusionner avec le Cœur » — Kael devient le nouveau gardien.
    func showAct4MergeEnding() {
        dialogue.start(PrototypeContent.act4MergeEndingDialogue) { [weak self] in
            guard let self else { return }
            dialogue.start(PrototypeContent.act4MergeEndScreen) { [weak self] in
                self?.rollCreditsToMenu()
            }
        }
    }
}
