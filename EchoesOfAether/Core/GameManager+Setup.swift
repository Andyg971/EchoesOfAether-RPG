import SpriteKit

// Mise en place : câblage des overlays, arguments de debug, New Game+,
// reprise de sauvegarde. Les hooks de debug vivent dans
// `+SetupDebugCombat` et `+SetupDebugZones`.
@MainActor
extension GameManager {
    // MARK: - Setup

    func setup(scene: SKScene, slot: Int = 1, newGamePlusSeed: NewGamePlusSeed? = nil) {
        self.scene = scene
        self.activeSlot = slot
        self.pendingNewGamePlusSeed = newGamePlusSeed
        attachOverlays(to: scene)
        wireOverlayCallbacks()

        if applyDebugCombatArguments(scene: scene) { return }
        if applyDebugZoneArguments(scene: scene) { return }

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

    /// Pose chaque overlay sur la scène, dans l'ordre d'empilement.
    func attachOverlays(to scene: SKScene) {
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
    }

    /// Branche les callbacks des overlays sur le GameManager.
    func wireOverlayCallbacks() {
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
    }
}
