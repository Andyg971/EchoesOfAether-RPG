import SpriteKit

// Mise en place — arguments de lancement de debug, première moitié : overlays,
// arbre plein, combats directs, quêtes actives. Chaque bloc qui prend la main
// renvoie `true` ; `setup` s'arrête alors là.
@MainActor
extension GameManager {
    /// Renvoie `true` si un argument a démarré le jeu directement (combat).
    func applyDebugCombatArguments(scene: SKScene) -> Bool {
        // Debug : --overlay-test <nom> ouvre l'overlay demandé après le
        // chargement (à combiner avec --zone-*) pour audit visuel de l'UI.
        // Noms : pause, options, skills, inventory, questlog, lore, tutorial,
        // levelup, death, shop, credits, act2end, bestiary, paywall.
        if let idx = CommandLine.arguments.firstIndex(of: "--overlay-test"),
           CommandLine.arguments.indices.contains(idx + 1) {
            let name = CommandLine.arguments[idx + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.debugShowOverlay(named: name)
            }
        }

        // Debug : --skills-maxed remplit l'Arbre de l'Aether pour auditer les
        // trois capstones en combat réel. Les rangs sont posés directement,
        // sans passer par `unlockSkill` : 39 points, donc plus que les 29
        // gagnables en jeu — c'est le seul moyen de voir les trois d'un coup.
        if CommandLine.arguments.contains("--skills-maxed") {
            player.level = PlayerState.maxLevel
            player.skillRanks = [
                "blade.attack": 3, "blade.crit": 3, "blade.slash": 2, "blade.capstone": 1,
                "aether.mp": 3, "aether.power": 3, "aether.regen": 2, "aether.capstone": 1,
                "breath.hp": 3, "breath.dodge": 3, "breath.ward": 2, "breath.capstone": 1
            ]
            player.currentHP = player.currentMaxHP
            syncLevelHUD()
        }

        // Debug : --combat-test / --combat-multi / --archivist-test /
        // --boss-test démarrent directement un combat pour capturer le rendu
        // de l'arène (skip wake/save).
        if CommandLine.arguments.contains("--combat-test") {
            hud.goldValue = player.gold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.phase = .forest
                self.showForest(in: scene)
                self.startGroveCombat()
                self.scheduleDebugMenuScript()
            }
            return true
        }
        if CommandLine.arguments.contains("--combat-multi") {
            hud.goldValue = player.gold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.phase = .forest
                self.showForest(in: scene)
                self.startClearingCombat()
            }
            return true
        }
        // `--archivist-test` : le mini-boss de l'Acte II, qui change de teinte
        // à chaque assaut. Sans ce raccourci il fallait finir l'Acte I puis
        // traverser les Ruines pour voir une seule de ses trois couleurs.
        if CommandLine.arguments.contains("--archivist-test") {
            hud.goldValue = player.gold
            player.ruinsProgress = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, let scene = self.scene else { return }
                self.phase = .ruins
                self.showRuins(in: scene)
                self.startRuinsCombat2()
            }
            return true
        }
        if CommandLine.arguments.contains("--boss-test") {
            hud.goldValue = player.gold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.phase = .shrine
                self.world.switchToShrine(in: scene)
                self.startBossFight()
                self.scheduleDebugMenuScript()
            }
            return true
        }
        // `--quests-active` : arme les quêtes annexes pour que leurs marqueurs
        // de collecte apparaissent en audit. Sans ça `addSideQuestMarkers` ne
        // pose rien — une partie neuve n'a aucune quête en cours — et les
        // points de ramassage de la forêt sont invisibles à l'inspection.
        if CommandLine.arguments.contains("--quests-active") {
            player.questLyraShards = .active
            player.questBramOre    = .active
            player.questSageHerb   = .active
            player.questGarenScout = .active
            player.questMedallion  = .active
            player.questChildToy   = .active
        }
        return false
    }
}
