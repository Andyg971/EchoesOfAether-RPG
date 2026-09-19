import SpriteKit

// Mise en place : câblage des overlays, hooks debug — première moitié.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Setup

    func setup(scene: SKScene, slot: Int = 1, newGamePlusSeed: NewGamePlusSeed? = nil) {
        self.scene = scene
        self.activeSlot = slot
        self.pendingNewGamePlusSeed = newGamePlusSeed
        world.build(in: scene)
        hud.attach(to: scene)
        dialogue.attach(to: scene)
        shop.attach(to: scene)
        inventory.attach(to: scene)
        pause.attach(to: scene)
        death.attach(to: scene)
        options.attach(to: scene)
        lore.attach(to: scene)
        questLog.attach(to: scene)
        minimap.attach(to: scene)
        worldMap.attach(to: scene)
        levelUp.attach(to: scene)
        skills.attach(to: scene)
        bubble.attach(to: scene)
        setupActionButton(in: scene)
        tutorial.attach(to: scene)
        paywall.attach(to: scene)
        syncLevelHUD()

        // Droits d'achat : chargés en tâche de fond, le jeu ne l'attend pas.
        Task { [weak self] in
            await StoreManager.shared.start()
            self?.paywall.refreshTexts()
        }

        paywall.onBuy     = { [weak self] in self?.buyFullGame() }
        paywall.onRestore = { [weak self] in self?.restorePurchases() }
        paywall.onLater   = { [weak self] in self?.dismissPaywall() }

        hud.onInventoryTap = { [weak self] in self?.openInventory() }
        hud.onPauseTap     = { [weak self] in self?.openPause() }
        hud.onLoreTap      = { [weak self] in self?.openLore() }
        hud.onQuestLogTap  = { [weak self] in self?.openQuestLog() }
        hud.onMapTap       = { [weak self] in self?.openWorldMap() }
        hud.mapButton.isHidden = true

        // Voyage rapide : saut DIRECT dans le lieu découvert choisi.
        worldMap.onTravel = { [weak self] id in self?.enterZoneFromMap(id) }

        pause.onResume    = { [weak self] in self?.closePause() }
        pause.onSave      = { [weak self] in
            guard let self, let scene = self.scene else { return }
            self.saveGame()
            JuiceEngine.flashOverlay(in: scene, size: scene.size,
                color: SKColor(red: 0.40, green: 0.70, blue: 1.0, alpha: 1), duration: 0.2)
            // Le flash seul était trop discret : le joueur ne savait pas si
            // sa partie avait bien été enregistrée.
            HapticsEngine.success()
            AudioEngine.shared.playQuestComplete()
            AccessibilitySettings.announce(String(localized: "dialogue.save.line1"))
        }
        pause.onOptions   = { [weak self] in self?.openOptions() }
        pause.onSkills    = { [weak self] in self?.openSkillTree() }
        pause.onMainMenu  = { [weak self] in
            self?.pause.hide()
            self?.onReturnToMenu?()
        }
        pause.onUnlock    = { [weak self] in
            self?.pause.hide()
            self?.openPaywall()
        }

        options.onClose       = { [weak self] in self?.closeOptions() }
        options.onDeleteSave  = { [weak self] in
            guard let self else { return }
            SaveManager.delete(slot: activeSlot)
            closeOptions()
            onReturnToMenu?()
        }
        options.onVolumeChange = { volume in
            AudioEngine.shared.masterVolume = volume
        }
        options.onMusicVolumeChange = { volume in
            AudioEngine.shared.musicVolume = volume
        }
        options.onLargeTextChange = { [weak self] in self?.relayoutForAccessibility() }
        options.onShowTutorial = { [weak self] in self?.replayTutorial() }

        death.onRetry           = { [weak self] in self?.retryLastCombat() }
        death.onReturnToCrystal = { [weak self] in
            self?.death.hide()
            self?.player.currentHP = self?.player.currentMaxHP ?? 280
            self?.onReturnToMenu?()
        }

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
            return
        }
        if CommandLine.arguments.contains("--combat-multi") {
            hud.goldValue = player.gold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.phase = .forest
                self.showForest(in: scene)
                self.startClearingCombat()
            }
            return
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
            return
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
            return
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

        // `--cam-y <frac>` : fraction de hauteur MONDE où poser Kael pour
        // l'audit d'une zone qui scrolle (la caméra le suit). Chaque zone
        // relisait les arguments à sa façon — le désert et les mines
        // l'ignoraient tout court : tout ce qui vivait au nord de l'écran
        // d'entrée était invisible à l'inspection.
        func camYFraction(default def: Double) -> Double {
            if let idx = CommandLine.arguments.firstIndex(of: "--cam-y"),
               CommandLine.arguments.indices.contains(idx + 1),
               let f = Double(CommandLine.arguments[idx + 1]) {
                return f
            }
            return def
        }

        // Visualisation pure d'une zone (sans combat), pour audit UI.
        if CommandLine.arguments.contains("--zone-forest") {
            hud.goldValue = player.gold
            phase = .forest
            showForest(in: scene)
            addSideQuestMarkers(in: scene)
            transition(to: .exploration)
            world.kael.position = CGPoint(
                x: scene.size.width * 0.5,
                y: world.worldHeight * camYFraction(default: 0.05))
            world.refreshKaelDepth()
            return
        }
        if CommandLine.arguments.contains("--zone-mines") {
            hud.goldValue = player.gold
            phase = .forest
            inMines = true
            hud.objectiveText = String(localized: "hud.objective.mines")
            AudioEngine.shared.setMood(.mines)
            world.switchToMines(in: scene, progress: player.minesProgress,
                                goldTaken: player.minesGoldTaken)
            world.kael.position = CGPoint(
                x: scene.size.width * 0.50,
                y: world.worldHeight * camYFraction(default: 0.05))
            world.refreshKaelDepth()
            spawnMineRoamers()
            transition(to: .exploration)
            return
        }
        if CommandLine.arguments.contains("--zone-cave") {
            hud.goldValue = player.gold
            phase = .forest
            inCave = true
            // --cave-cleared : affiche l'état post-combat (coffre visible)
            if CommandLine.arguments.contains("--cave-cleared") {
                player.caveCleared = true
            }
            hud.objectiveText = String(localized: "hud.objective.cave")
            world.switchToCave(in: scene, cleared: player.caveCleared,
                               chestTaken: player.caveChestTaken)
            world.kael.position = CGPoint(x: scene.size.width * 0.50,
                                          y: scene.size.height * 0.14)
            spawnCaveRoamer()
            transition(to: .exploration)
            return
        }
        if CommandLine.arguments.contains("--zone-desert") {
            hud.goldValue = player.gold
            phase = .forest
            inDesert = true
            hud.objectiveText = String(localized: "hud.objective.desert")
            AudioEngine.shared.setMood(.tense)
            world.switchToDesert(in: scene, progress: player.desertProgress,
                                 chestTaken: player.desertChestTaken)
            world.kael.position = CGPoint(
                x: scene.size.width * 0.50,
                y: world.worldHeight * camYFraction(default: 0.05))
            world.refreshKaelDepth()
            spawnDesertRoamers()
            transition(to: .exploration)
            return
        }
        if CommandLine.arguments.contains("--zone-overworld") {
            hud.goldValue = player.gold
            inOverworld = true
            world.switchToOverworld(in: scene)
            // `--overworld-at <lieu>` : apparaître sur un lieu canonique
            // (desert, mines, ruins…) au lieu de la plaine de départ. La carte
            // fait 2,7 écrans de large — sans ça, auditer le désert demandait
            // de traverser le continent au joystick.
            var spawn = CGPoint(x: world.worldWidth * 0.20,
                                y: world.worldHeight * 0.24)
            if let idx = CommandLine.arguments.firstIndex(of: "--overworld-at"),
               CommandLine.arguments.indices.contains(idx + 1) {
                spawn = WorldBuilder.overworldPoint(CommandLine.arguments[idx + 1],
                                                    w: world.worldWidth,
                                                    h: world.worldHeight)
            }
            world.kael.position = spawn
            world.kael.isHidden = false
            world.refreshKaelDepth()
            world.snapCamera()
            spawnOverworldRoamers()
            world.addOverworldChests(taken: player.overworldChestsTaken, in: scene)
            transition(to: .exploration)
            return
        }
        if CommandLine.arguments.contains("--zone-shrine") {
            hud.goldValue = player.gold
            phase = .shrine
            world.switchToShrine(in: scene)
            transition(to: .exploration)
            return
        }
        // Audit de la cinématique de la mort de Lyra : ruines + compagne,
        // la scène se déclenche seule après une seconde.
        if CommandLine.arguments.contains("--lyra-death") {
            hud.goldValue = player.gold
            phase = .ruins
            showRuins(in: scene)
            world.showLyraCompanion()
            transition(to: .exploration)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.triggerLyraDeath()
            }
            return
        }
        if CommandLine.arguments.contains("--zone-ruins") {
            hud.goldValue = player.gold
            phase = .ruins
            showRuins(in: scene)
            transition(to: .exploration)
            return
        }
        // Audit visuel des intérieurs : --interior armory|apothecary|inn
        if let idx = CommandLine.arguments.firstIndex(of: "--interior"),
           CommandLine.arguments.indices.contains(idx + 1) {
            let kind: HouseInteriorKind? = switch CommandLine.arguments[idx + 1] {
            case "armory": .armory
            case "apothecary": .apothecary
            case "inn": .inn
            default: nil
            }
            if let kind {
                hud.goldValue = player.gold
                phase = .village
                enterHouse(kind, in: scene)
                return
            }
        }
        if CommandLine.arguments.contains("--combat-trio") {
            hud.goldValue = player.gold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, let scene = self.scene else { return }
                self.phase = .act3
                self.player.act3EchoJoined = true
                self.player.act3EranMet = true
                self.showThreshold(in: scene)
                self.startVoidShadesCombat()
            }
            return
        }
        if CommandLine.arguments.contains("--zone-voidheart") {
            hud.goldValue = player.gold
            phase = .act4
            showVoidHeart(in: scene)
            transition(to: .exploration)
            return
        }
        if CommandLine.arguments.contains("--zone-threshold") {
            hud.goldValue = player.gold
            phase = .act3
            showThreshold(in: scene)
            transition(to: .exploration)
            return
        }
        // Audit visuel du village : --zone-village [--cam-y 0.5] place Kael
        // à la fraction de hauteur demandée (la caméra le suit).
        if CommandLine.arguments.contains("--zone-village") {
            hud.goldValue = player.gold
            phase = .village
            transition(to: .exploration)
            if CommandLine.arguments.contains("--cam-y") {
                // Différé : le `layout()` initial (GameScene.didMove) replace
                // Kael sur le plan du village juste après ce handler — le
                // placement d'audit doit passer en dernier.
                let frac = camYFraction(default: 0.05)
                DispatchQueue.main.async { [weak self] in
                    guard let self, let scene = self.scene else { return }
                    world.kael.position = CGPoint(
                        x: scene.size.width * 0.5,
                        y: world.worldHeight * CGFloat(frac))
                    world.refreshKaelDepth()
                }
            }
            return
        }
        // Debug : place Kael près de Lyra dans le village pour audit
        // immédiat de la bulle d'interaction.
        if CommandLine.arguments.contains("--bubble-test") {
            hud.goldValue = player.gold
            phase = .village
            transition(to: .exploration)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                // Lyra est à (w*0.20, h*0.58) — placer Kael 50pt en dessous
                let target = CGPoint(x: self.world.lyra.position.x,
                                      y: self.world.lyra.position.y - 50)
                self.world.kael.position = target
            }
            return
        }

        // New Game+ : graine du menu (partie terminée) ou --ngplus N (test).
        // Elle prime sur toute sauvegarde : on repart de l'intro, acquis
        // conservés, difficulté relevée.
        var ngSeed = pendingNewGamePlusSeed
        if ngSeed == nil,
           let idx = CommandLine.arguments.firstIndex(of: "--ngplus"),
           CommandLine.arguments.indices.contains(idx + 1),
           let tier = Int(CommandLine.arguments[idx + 1]) {
            ngSeed = NewGamePlusSeed(testTier: tier)
        }
        if let seed = ngSeed {
            pendingNewGamePlusSeed = nil
            SaveManager.delete(slot: activeSlot)
            player.applyNewGamePlusSeed(seed)
            hud.goldValue = player.gold
            syncLevelHUD()
            startWakeSequence()
            saveGame()
            return
        }

        if let save = SaveManager.load(slot: activeSlot) {
            restoreFrom(save: save, scene: scene)
        } else {
            hud.goldValue = player.gold
            startWakeSequence()
        }
    }

}
