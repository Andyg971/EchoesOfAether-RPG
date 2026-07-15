import SpriteKit

@MainActor
final class GameManager {
    private(set) var state: GameState = .exploration
    var phase: GamePhase = .wake {
        didSet {
            // Chaque zone a son ambiance musicale (cross-fade automatique).
            AudioEngine.shared.setMood(.forPhase(phase))
        }
    }

    let world     = WorldBuilder()
    let hud       = HUDOverlay()
    let dialogue  = DialogueSystem()
    let combat    = CombatSystem()
    let movement  = MovementController()
    let shop      = ShopOverlay()
    let inventory = InventoryOverlay()
    let pause     = PauseOverlay()
    let death     = DeathOverlay()
    let options   = OptionsOverlay()
    let lore      = LoreOverlay()
    let questLog  = QuestLogOverlay()
    let minimap   = MinimapOverlay()
    let worldMap  = WorldMapOverlay()
    let levelUp   = LevelUpOverlay()
    let bubble    = InteractionBubble()
    let tutorial  = TutorialOverlay()
    let player    = PlayerState()

    var onReturnToMenu: (() -> Void)?

    /// Slot de sauvegarde actif (injecté au démarrage par la scène).
    private(set) var activeSlot: Int = 1
    /// Graine New Game+ en attente (fournie par le menu à `setup`).
    private var pendingNewGamePlusSeed: NewGamePlusSeed?

    // Membres accédés par les extensions de domaine (GameManager+*.swift) :
    // `internal` plutôt que `private` pour un découpage multi-fichiers.
    weak var scene: SKScene?
    var resonanceTotal = 0
    var lastCombatStarter: (() -> Void)?   // pour le bouton Réessayer

    /// Lyra combat aux côtés de Kael dans les zones du pacte (tant qu'elle vit).
    var lyraInParty: Bool {
        [.forest, .shrine, .ruins].contains(phase) && !player.lyraDeceased
    }

    /// Trio de l'Acte III : l'Écho de Lyra puis Eran rejoignent Kael.
    var act3Party: [CombatAllyKind] {
        var kinds: [CombatAllyKind] = []
        if player.act3EchoJoined { kinds.append(.lyraEcho) }
        if player.act3EranMet { kinds.append(.eran) }
        return kinds
    }
    private var prologueNode: SKNode?              // cinématique d'ouverture
    private var prologueCompletion: (() -> Void)?
    // Joystick virtuel flottant
    private let padBase = SKShapeNode(circleOfRadius: 34)
    private let padKnob = SKShapeNode(circleOfRadius: 15)
    // Bouton d'action « A » (bas-droite) : déclenche l'interaction à portée.
    // Plus fiable que taper précisément sur le PNJ/POI.
    private let actionButton = SKShapeNode()
    private let actionButtonLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    // Bouton « B » : annuler / passer / fermer (contrôles classiques).
    private let bButton = SKShapeNode()
    private let bButtonLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private var nearbyActionPoint: CGPoint?   // POI courant (coords monde)
    /// Monstres baladeurs de la zone courante (mines, caverne) : patrouillent
    /// et chargent Kael au contact pour déclencher le combat.
    private var roamers: [RoamingMonster] = []
    private var padActive = false
    private var padOrigin = CGPoint.zero
    private var padVector = CGVector.zero
    private var hintUpdateTimer: TimeInterval = 0
    private var minimapTimer: TimeInterval = 0
    var corruptionCinematicShown = false
    private var activeInterior: HouseInteriorKind?
    /// Vrai quand Kael est dans les mines de Cendreval (excursion depuis
    /// la forêt — pas une GamePhase : la save garde phase = .forest).
    var inMines = false
    /// Vrai quand Kael est dans le désert d'Ossara (voyage via la carte
    /// du monde — pas une GamePhase : la save garde la phase d'origine).
    var inDesert = false
    /// Vrai quand Kael explore la Caverne aux Échos (donjon optionnel,
    /// entrée dans la forêt — pas une GamePhase, comme les mines).
    var inCave = false

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
        bubble.attach(to: scene)
        setupActionButton(in: scene)
        tutorial.attach(to: scene)
        syncLevelHUD()

        hud.onInventoryTap = { [weak self] in self?.openInventory() }
        hud.onPauseTap     = { [weak self] in self?.openPause() }
        hud.onLoreTap      = { [weak self] in self?.openLore() }
        hud.onQuestLogTap  = { [weak self] in self?.openQuestLog() }
        hud.onMapTap       = { [weak self] in self?.openWorldMap() }
        hud.mapButton.isHidden = true

        worldMap.onTravel = { [weak self] id in self?.travel(to: id) }

        pause.onResume    = { [weak self] in self?.closePause() }
        pause.onSave      = { [weak self] in
            guard let self, let scene = self.scene else { return }
            self.saveGame()
            JuiceEngine.flashOverlay(in: scene, size: scene.size,
                color: SKColor(red: 0.40, green: 0.70, blue: 1.0, alpha: 1), duration: 0.2)
        }
        pause.onOptions   = { [weak self] in self?.openOptions() }
        pause.onMainMenu  = { [weak self] in
            self?.pause.hide()
            self?.onReturnToMenu?()
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
        // Noms : pause, options, inventory, questlog, lore, tutorial,
        // levelup, death, shop.
        if let idx = CommandLine.arguments.firstIndex(of: "--overlay-test"),
           CommandLine.arguments.indices.contains(idx + 1) {
            let name = CommandLine.arguments[idx + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.debugShowOverlay(named: name)
            }
        }

        // Debug : --combat-test / --boss-test démarre directement un combat
        // pour capturer le rendu de l'arène (skip wake/save).
        if CommandLine.arguments.contains("--combat-test") {
            hud.goldValue = player.gold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.phase = .forest
                self.showForest(in: scene)
                self.startGroveCombat()
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
        if CommandLine.arguments.contains("--boss-test") {
            hud.goldValue = player.gold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.phase = .shrine
                self.world.switchToShrine(in: scene)
                self.startBossFight()
            }
            return
        }
        // Visualisation pure d'une zone (sans combat), pour audit UI.
        if CommandLine.arguments.contains("--zone-forest") {
            hud.goldValue = player.gold
            phase = .forest
            showForest(in: scene)
            addSideQuestMarkers(in: scene)
            transition(to: .exploration)
            let frac: Double
            if let idx = CommandLine.arguments.firstIndex(of: "--cam-y"),
               CommandLine.arguments.indices.contains(idx + 1),
               let f = Double(CommandLine.arguments[idx + 1]) {
                frac = f
            } else {
                frac = 0.05
            }
            world.kael.position = CGPoint(x: scene.size.width * 0.5,
                                          y: world.worldHeight * CGFloat(frac))
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
            world.kael.position = CGPoint(x: scene.size.width * 0.50,
                                          y: scene.size.height * 0.14)
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
            world.kael.position = CGPoint(x: scene.size.width * 0.50,
                                          y: scene.size.height * 0.14)
            spawnDesertRoamers()
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
        if CommandLine.arguments.contains("--zone-ruins") {
            hud.goldValue = player.gold
            phase = .ruins
            world.switchToRuins(in: scene)
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
                self.world.switchToThreshold(in: scene, echoJoined: true)
                self.startVoidShadesCombat()
            }
            return
        }
        if CommandLine.arguments.contains("--zone-voidheart") {
            hud.goldValue = player.gold
            phase = .act4
            world.switchToVoidHeart(in: scene,
                                    echoJoined: player.act3EchoJoined,
                                    reflectionsFreed: player.act4ReflectionsFreed,
                                    devourersDefeated: player.act4DevourersDefeated,
                                    bossDefeated: player.act4BossDefeated)
            transition(to: .exploration)
            return
        }
        if CommandLine.arguments.contains("--zone-threshold") {
            hud.goldValue = player.gold
            phase = .act3
            world.switchToThreshold(in: scene,
                                    echoJoined: player.act3EchoJoined,
                                    spiritsCalmed: player.act3SpiritsCalmed,
                                    shadesDefeated: player.act3ShadesDefeated)
            transition(to: .exploration)
            return
        }
        // Audit visuel du village : --zone-village [--cam-y 0.5] place Kael
        // à la fraction de hauteur demandée (la caméra le suit).
        if CommandLine.arguments.contains("--zone-village") {
            hud.goldValue = player.gold
            phase = .village
            transition(to: .exploration)
            if let idx = CommandLine.arguments.firstIndex(of: "--cam-y"),
               CommandLine.arguments.indices.contains(idx + 1),
               let frac = Double(CommandLine.arguments[idx + 1]) {
                world.kael.position = CGPoint(x: scene.size.width * 0.5,
                                              y: world.worldHeight * CGFloat(frac))
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

    private var lastLayout: (size: CGSize, top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)?

    func layout(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat = 0, safeLeft: CGFloat = 0, safeRight: CGFloat = 0) {
        lastLayout = (size, safeTop, safeBottom, safeLeft, safeRight)
        if activeInterior == nil {
            world.layout(in: size)
        }
        hud.layout(in: size, safeTop: safeTop, safeLeft: safeLeft, safeRight: safeRight)
        dialogue.layout(in: size, safeBottom: safeBottom)
        shop.layout(in: size, safeBottom: safeBottom)
        inventory.layout(in: size, safeBottom: safeBottom)
        lore.layout(in: size)
        questLog.layout(in: size)
        minimap.layout(in: size, safeBottom: safeBottom, safeLeft: safeLeft)
        levelUp.layout(in: size)
        worldMap.layout(in: size)
    }

    /// Pousse l'état niveau/XP du joueur vers le HUD. À appeler après
    /// chargement, level-up, ou tout changement de stats.
    private func syncLevelHUD() {
        let isMax = player.level >= PlayerState.maxLevel
        hud.setLevel(player.level,
                     xp: player.xp,
                     xpToNext: isMax ? 0 : player.xpToNextLevel,
                     progress: player.xpProgress,
                     isMax: isMax)
    }

    /// Sync HUD + affiche overlay si level a augmenté. Non bloquant :
    /// l'overlay s'affiche par-dessus le dialogue post-combat ; le joueur
    /// tape pour fermer et continuer.
    func grantLevelUpDisplay(from levelBefore: Int) {
        syncLevelHUD()
        guard player.level > levelBefore else { return }
        levelUp.show(newLevel: player.level,
                     isMax: player.level >= PlayerState.maxLevel) {}
    }

    func update(deltaTime: TimeInterval) {
        combat.update(deltaTime: deltaTime)

        hud.hpValue = "\u{2665} \(player.currentHP)/\(player.currentMaxHP)"

        hintUpdateTimer += deltaTime
        if hintUpdateTimer >= 0.15, state == .exploration {
            hintUpdateTimer = 0
            updateInteractionHint()
        }

        // Bouton A : exploration (interagir), dialogue (avancer/valider),
        // combat (activer la sélection), boutique et pause (valider).
        // Bouton B : dialogue (passer) + overlays fermables.
        let showActionButton = actionButton.parent != nil
            && !worldMap.isActive
            && (state == .exploration || state == .dialogue
                || state == .combat || state == .shop || pause.isActive)
        if actionButton.isHidden == showActionButton {
            actionButton.isHidden = !showActionButton
        }
        if state != .exploration, actionButton.alpha < 0.99 {
            actionButton.alpha = 1
        }
        let showBButton = bButton.parent != nil
            && (dialogue.isActive || dismissableOverlayActive)
        if bButton.isHidden == showBButton {
            bButton.isHidden = !showBButton
        }

        minimapTimer += deltaTime
        if minimapTimer >= 0.10, state == .exploration {
            minimapTimer = 0
            updateMinimap()
        }

        // Bouton carte du monde : visible seulement là où le voyage
        // a un sens (désert accessible, ou retour depuis le désert).
        let showMap = worldMapAvailable && state == .exploration
        if hud.mapButton.isHidden == showMap {
            hud.mapButton.isHidden = !showMap
        }

        // Déplacement continu au joystick virtuel (exploration)
        if state == .exploration {
            updatePadMovement(deltaTime: deltaTime)
            updateRoamers(deltaTime: deltaTime)
        } else {
            updateMenuNavigation()
        }

        // Lyra accompagne Kael dans les zones du pacte (tant qu'elle vit) ;
        // au Seuil, c'est son Écho spectral qui suit (une fois rejoint).
        if state == .exploration || state == .dialogue {
            if [.forest, .shrine, .ruins].contains(phase), !player.lyraDeceased {
                if world.lyra.isHidden { world.showLyraCompanion() }
                world.updateLyraFollow(deltaTime: deltaTime)
            } else if phase == .act3 || phase == .act4, player.act3EchoJoined {
                world.updateLyraFollow(deltaTime: deltaTime)
            }
        }

        if state == .exploration, let s = scene {
            world.updateCamera(in: s.size)
        }
    }

    // MARK: - Bouton d'action « A »

    /// Relief pixel dur sur un bouton carré : biseau clair en haut/gauche,
    /// ombre sombre en bas/droite (look touche de manette rétro, pas badge
    /// web). Bandes de 3px, `.nearest` implicite (SKSpriteNode couleur).
    private func addPixelBevel(to node: SKShapeNode, size: CGFloat,
                               light: SKColor, dark: SKColor) {
        let h = size / 2
        let t: CGFloat = 3
        let bands: [(CGPoint, CGSize, SKColor)] = [
            (CGPoint(x: 0, y: h - t / 2), CGSize(width: size, height: t), light),   // haut
            (CGPoint(x: -h + t / 2, y: 0), CGSize(width: t, height: size), light),  // gauche
            (CGPoint(x: 0, y: -h + t / 2), CGSize(width: size, height: t), dark),    // bas
            (CGPoint(x: h - t / 2, y: 0), CGSize(width: t, height: size), dark)      // droite
        ]
        for (pos, sz, color) in bands {
            let band = SKSpriteNode(color: color, size: sz)
            band.position = pos
            band.zPosition = 0.5
            node.addChild(band)
        }
    }

    /// Bouton pixel fixe en bas à droite. Actif (doré, pulsé) quand une
    /// interaction est à portée ; estompé sinon.
    private func setupActionButton(in scene: SKScene) {
        PixelUI.stylePanel(actionButton, size: CGSize(width: 54, height: 54),
                           fill: SKColor(red: 0.16, green: 0.13, blue: 0.10, alpha: 0.95),
                           accent: PixelUI.gold)
        addPixelBevel(to: actionButton, size: 54,
                      light: SKColor(red: 0.62, green: 0.50, blue: 0.24, alpha: 0.9),
                      dark: SKColor(red: 0.05, green: 0.04, blue: 0.02, alpha: 0.95))
        actionButton.position = CGPoint(x: scene.size.width - 58, y: 66)
        actionButton.zPosition = 1_950   // au-dessus des panneaux (dialogue 1000+)
        actionButton.isHidden = true
        scene.addChild(actionButton)

        actionButtonLabel.text = "A"
        actionButtonLabel.fontSize = 30
        actionButtonLabel.fontColor = SKColor(red: 1.0, green: 0.92, blue: 0.62, alpha: 1)
        actionButtonLabel.verticalAlignmentMode = .center
        actionButtonLabel.horizontalAlignmentMode = .center
        actionButtonLabel.position = CGPoint(x: 0, y: -1)
        actionButtonLabel.zPosition = 951
        actionButton.addChild(actionButtonLabel)

        // Bouton B : en dessous-gauche de A, accent cuivré (annuler/passer)
        let bAccent = SKColor(red: 0.80, green: 0.42, blue: 0.30, alpha: 1)
        PixelUI.stylePanel(bButton, size: CGSize(width: 46, height: 46),
                           fill: SKColor(red: 0.18, green: 0.10, blue: 0.08, alpha: 0.95),
                           accent: bAccent)
        addPixelBevel(to: bButton, size: 46,
                      light: SKColor(red: 0.62, green: 0.34, blue: 0.24, alpha: 0.9),
                      dark: SKColor(red: 0.06, green: 0.02, blue: 0.02, alpha: 0.95))
        bButton.position = CGPoint(x: scene.size.width - 58, y: 128)
        bButton.zPosition = 1_950
        bButton.isHidden = true
        scene.addChild(bButton)

        bButtonLabel.text = "B"
        bButtonLabel.fontSize = 27
        bButtonLabel.fontColor = bAccent
        bButtonLabel.verticalAlignmentMode = .center
        bButtonLabel.horizontalAlignmentMode = .center
        bButtonLabel.position = CGPoint(x: 0, y: -1)
        bButtonLabel.zPosition = 951
        bButton.addChild(bButtonLabel)
    }

    /// Un overlay fermable par B est-il ouvert ?
    private var dismissableOverlayActive: Bool {
        inventory.isActive || shop.isActive || lore.isActive
            || questLog.isActive || pause.isActive || options.isActive
            || worldMap.isActive
    }

    /// Bouton B : annule / passe / ferme selon le contexte.
    private func handleBPress() {
        HapticsEngine.light()
        bButton.run(.sequence([
            .scale(to: 0.90, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ]))
        // Ordre : options au-dessus de pause ; dialogue en dernier.
        if options.isActive { options.dismiss(); return }
        if pause.isActive { pause.dismiss(); return }
        if worldMap.isActive { worldMap.dismiss(); return }
        if shop.isActive { shop.dismiss(); syncGold(); return }
        if lore.isActive { lore.dismiss(); return }
        if questLog.isActive { questLog.dismiss(); return }
        if inventory.isActive { inventory.dismiss(); return }
        if dialogue.isActive { dialogue.skipToEnd(); return }
    }

    /// Rafraîchit l'état visuel du bouton A selon le POI à portée.
    private func updateActionButtonState() {
        let enabled = nearbyActionPoint != nil
        let targetAlpha: CGFloat = enabled ? 1.0 : 0.35
        if abs(actionButton.alpha - targetAlpha) > 0.01 {
            actionButton.run(.fadeAlpha(to: targetAlpha, duration: 0.15))
            if enabled {
                actionButton.run(.sequence([
                    .scale(to: 1.12, duration: 0.10),
                    .scale(to: 1.0, duration: 0.12)
                ]))
            }
        }
    }

    /// Déclenche l'interaction du POI courant (comme un tap parfait dessus).
    private func triggerNearbyAction(in scene: SKScene) {
        guard let target = nearbyActionPoint else {
            HapticsEngine.light()
            return
        }
        HapticsEngine.medium()
        actionButton.run(.sequence([
            .scale(to: 0.90, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ]))
        let screenPoint = scene.convert(target, from: world.worldNode)
        handleExplorationTap(screenPoint, in: scene)
    }

    // MARK: - Navigation curseur (joystick → menus)

    private var menuNavLatched = false

    /// Convertit le joystick en pas discrets (haut/bas/gauche/droite)
    /// et les route vers le menu actif. Un « flick » = un pas.
    private func updateMenuNavigation() {
        let v = padVector
        let magnitude = max(abs(v.dx), abs(v.dy))
        if menuNavLatched {
            if magnitude < 0.30 { menuNavLatched = false }
            return
        }
        guard magnitude > 0.60 else { return }
        menuNavLatched = true
        let dx = abs(v.dx) > abs(v.dy) ? (v.dx > 0 ? 1 : -1) : 0
        let dy = dx == 0 ? (v.dy > 0 ? 1 : -1) : 0
        routeMenuNav(dx: dx, dy: dy)
    }

    private func routeMenuNav(dx: Int, dy: Int) {
        if options.isActive { return }              // sliders : tactile assumé
        if pause.isActive { pause.moveSelection(dy); return }
        if shop.isActive { shop.moveSelection(dy); return }
        if lore.isActive { if dx != 0 { lore.navigateTabs(dx) }; return }
        if state == .combat { combat.menuNav(dx: dx, dy: dy); return }
        if dialogue.isActive { dialogue.moveChoiceSelection(dy); return }
    }

    // MARK: - Joystick virtuel (flottant, quart bas-gauche)

    /// Le joueur pose le doigt en bas à gauche : le pad apparaît là.
    /// Retourne true si le touch est capturé par le pad.
    func padTouchBegan(at point: CGPoint, in scene: SKScene) -> Bool {
        // Exploration : déplacement. Menus (combat, dialogue, boutique,
        // pause…) : le même joystick navigue le curseur de sélection.
        guard state != .transition, !worldMap.isActive,
              point.x < scene.size.width * 0.42,
              point.y < scene.size.height * 0.60 else { return false }
        if padBase.parent == nil {
            padBase.fillColor = SKColor(white: 0.9, alpha: 0.10)
            padBase.strokeColor = PixelUI.gold.withAlphaComponent(0.55)
            padBase.lineWidth = 2
            padBase.zPosition = 950
            scene.addChild(padBase)
            padKnob.fillColor = PixelUI.gold.withAlphaComponent(0.55)
            padKnob.strokeColor = PixelUI.gold
            padKnob.lineWidth = 1.5
            padKnob.zPosition = 951
            scene.addChild(padKnob)
        }
        padActive = true
        padOrigin = point
        padVector = .zero
        padBase.position = point
        padKnob.position = point
        padBase.alpha = 1
        padKnob.alpha = 1
        return true
    }

    func padTouchMoved(to point: CGPoint) {
        guard padActive else { return }
        var dx = point.x - padOrigin.x
        var dy = point.y - padOrigin.y
        let len = (dx * dx + dy * dy).squareRoot()
        let maxR: CGFloat = 34
        if len > maxR {
            dx = dx / len * maxR
            dy = dy / len * maxR
        }
        padKnob.position = CGPoint(x: padOrigin.x + dx, y: padOrigin.y + dy)
        let strength = min(1, len / maxR)
        padVector = len > 6
            ? CGVector(dx: dx / maxR * strength, dy: dy / maxR * strength)
            : .zero
    }

    func padTouchEnded() {
        guard padActive else { return }
        padActive = false
        padVector = .zero
        padBase.run(.fadeOut(withDuration: 0.15))
        padKnob.run(.fadeOut(withDuration: 0.15))
        movement.setManualWalk(world.kael, dx: 0, active: false)
    }

    private func updatePadMovement(deltaTime: TimeInterval) {
        guard padActive, state == .exploration, deltaTime > 0,
              padVector != .zero, let scene else { return }
        let speed: CGFloat = 215
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let current = world.kael.position
        var pos = current
        pos.x += padVector.dx * speed * CGFloat(deltaTime)
        pos.y += padVector.dy * speed * CGFloat(deltaTime)
        pos.x = min(max(pos.x, 34), scene.size.width - 34)
        pos.y = min(max(pos.y, 86), wh - 44)

        // Collisions : on ne traverse ni maisons ni arbres. Glissement le
        // long des murs (axe par axe) pour un contrôle agréable.
        // Si Kael est déjà dans une empreinte (spawn/scénario), on le
        // laisse sortir librement.
        if world.isBlocked(pos), !world.isBlocked(current) {
            let xOnly = CGPoint(x: pos.x, y: current.y)
            let yOnly = CGPoint(x: current.x, y: pos.y)
            if !world.isBlocked(xOnly) {
                pos = xOnly
            } else if !world.isBlocked(yOnly) {
                pos = yOnly
            } else {
                movement.setManualWalk(world.kael, dx: padVector.dx, active: true)
                return
            }
        }
        world.kael.position = pos
        world.refreshKaelDepth()
        movement.setManualWalk(world.kael, dx: padVector.dx, active: true)
    }

    func handleTap(at point: CGPoint, in scene: SKScene) {
        // Le tutoriel est modal : il bloque toute autre interaction tant
        // qu'il est visible.
        if tutorial.handleTap(at: point, in: scene) { return }
        // Le level-up est prioritaire : il bloque toute autre interaction
        // tant qu'il est visible.
        if levelUp.handleTap(at: point, in: scene) { return }
        if death.handleTap(at: point, in: scene) { return }
        if options.handleTap(at: point, in: scene) { return }
        if lore.handleTap(at: point, in: scene) { return }
        if questLog.handleTap(at: point, in: scene) { return }
        // Prologue : n'importe quel tap le passe.
        if prologueNode != nil { endPrologue(); return }
        if pause.handleTap(at: point, in: scene) { return }
        if TransitionManager.handleEndScreenTap(at: point, in: scene) { return }
        if TransitionManager.handleCreditsTap(at: point, in: scene) { return }
        // Boutons A/B : prioritaires sur les panneaux (ils vivent au-dessus)
        if !bButton.isHidden, point.distance(to: bButton.position) < 38 {
            handleBPress()
            return
        }
        // Carte du monde : capture tous les taps tant qu'elle est ouverte
        // (fermeture par son bouton, un lieu voyageable, ou B ci-dessus).
        if worldMap.isActive, worldMap.handleTap(at: point, in: scene) { return }
        if !actionButton.isHidden, point.distance(to: actionButton.position) < 42 {
            actionButton.run(.sequence([
                .scale(to: 0.90, duration: 0.06),
                .scale(to: 1.0, duration: 0.10)
            ]))
            if pause.isActive {
                pause.confirmSelection()
            } else if shop.isActive {
                shop.confirmSelection()
                syncGold()
            } else if state == .combat {
                combat.menuConfirm()
            } else if dialogue.isActive {
                dialogue.advance()
            } else if state == .exploration {
                triggerNearbyAction(in: scene)
            }
            return
        }
        if state == .inventory, inventory.handleTap(at: point, in: scene) { return }
        if state == .shop,      shop.handleTap(at: point, in: scene) { syncGold(); return }
        if state == .dialogue,   dialogue.handleTap(at: point, in: scene) { return }
        if state == .combat,     combat.handleTap(at: point, in: scene) { return }
        guard state == .exploration else { return }
        if hud.handleTap(at: point, in: scene) { return }
        // Contrôles classiques : déplacement = joystick uniquement.
        // Mais toucher directement le PNJ/POI À PORTÉE interagit quand
        // même (équivalent du bouton A) — sinon le tap semble « cassé ».
        if let target = nearbyActionPoint {
            let wp = world.worldNode.convert(point, from: scene)
            if wp.distance(to: target) < 48 {
                triggerNearbyAction(in: scene)
                return
            }
        }
    }

    // MARK: - Story Flow

    private func startWakeSequence() {
        transition(to: .dialogue)
        phase = .wake
        hud.objectiveText = String(localized: "hud.objective.lyra")
        if let scene {
            world.placeLyraBesideKael(in: scene.size)
            showPrologue(in: scene) { [weak self] in self?.startWakeDialogue() }
        } else {
            startWakeDialogue()
        }
    }

    private func startWakeDialogue() {
        dialogue.start(PrototypeContent.wakeDialogue) { [weak self] in
            guard let self else { return }
            phase = .village
            hud.objectiveText = String(localized: "hud.objective.village")
            transition(to: .exploration)
            maybeShowTutorial()
        }
    }

    // MARK: - Prologue (cinématique d'ouverture)

    /// Écran noir + lore de la Source, ligne par ligne. Tap pour passer.
    private func showPrologue(in scene: SKScene, completion: @escaping () -> Void) {
        let overlay = SKNode()
        overlay.zPosition = 3_000

        let black = SKSpriteNode(color: .black, size: CGSize(width: scene.size.width + 4,
                                                             height: scene.size.height + 4))
        black.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        overlay.addChild(black)

        let keys = ["prologue.line1", "prologue.line2", "prologue.line3",
                    "prologue.line4", "prologue.line5"]
        var delay: TimeInterval = 0.8
        for key in keys {
            let label = SKLabelNode(fontNamed: PixelUI.uiFont)
            label.text = String(localized: String.LocalizationValue(key))
            label.fontSize = 19
            label.fontColor = SKColor(red: 0.82, green: 0.76, blue: 0.92, alpha: 1)
            label.numberOfLines = 3
            label.preferredMaxLayoutWidth = min(scene.size.width - 96, 560)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.52)
            label.alpha = 0
            overlay.addChild(label)
            label.run(.sequence([
                .wait(forDuration: delay),
                .fadeIn(withDuration: 0.8),
                .wait(forDuration: 2.3),
                .fadeOut(withDuration: 0.6)
            ]))
            delay += 3.8
        }

        let skip = SKLabelNode(fontNamed: PixelUI.uiFont)
        skip.text = String(localized: "prologue.skip")
        skip.fontSize = 12
        skip.fontColor = SKColor(white: 0.5, alpha: 0.8)
        skip.horizontalAlignmentMode = .center
        skip.position = CGPoint(x: scene.size.width / 2, y: 26)
        overlay.addChild(skip)
        JuiceEngine.pulse(skip, scale: 1.06)

        overlay.run(.sequence([
            .wait(forDuration: delay + 0.4),
            .run { [weak self] in self?.endPrologue() }
        ]))

        scene.addChild(overlay)
        prologueNode = overlay
        prologueCompletion = completion
        AudioEngine.shared.playSelect()
    }

    private func endPrologue() {
        guard let node = prologueNode else { return }
        prologueNode = nil
        let done = prologueCompletion
        prologueCompletion = nil
        node.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
        done?()
    }

    /// Affiche le tutoriel à la première partie (flag UserDefaults).
    private func maybeShowTutorial() {
        guard let scene else { return }
        guard !UserDefaults.standard.bool(forKey: TutorialOverlay.seenKey) else { return }
        tutorial.show(in: scene)
    }

    /// Relance le tutoriel (depuis les Options), quel que soit le flag.
    private func replayTutorial() {
        guard let scene else { return }
        options.hide()
        pause.hide()
        tutorial.show(in: scene)
    }

    /// Re-dispose HUD + dialogue après un changement d'accessibilité (gros texte).
    private func relayoutForAccessibility() {
        if let l = lastLayout {
            layout(size: l.size, safeTop: l.top, safeBottom: l.bottom,
                   safeLeft: l.left, safeRight: l.right)
        } else if let scene {
            if let last = lastLayout {
                hud.layout(in: last.size, safeTop: last.top,
                           safeLeft: last.left, safeRight: last.right)
            } else {
                hud.layout(in: scene.size)
            }
            dialogue.layout(in: scene.size)
        }
    }

    // MARK: - Exploration Tap Routing

    private func handleExplorationTap(_ point: CGPoint, in scene: SKScene) {
        let wp = world.worldNode.convert(point, from: scene)

        if activeInterior != nil {
            if tryInteriorInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
            return
        }

        if inMines {
            if tryMinesInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
            return
        }

        if inDesert {
            if tryDesertInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
            return
        }

        if inCave {
            if tryCaveInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
            return
        }

        if trySaveCrystalTap(wp, in: scene) { return }

        switch phase {
        case .wake:
            return

        case .village:
            if tryVillageInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)

        case .forest:
            if tryForestInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)

        case .shrine:
            if wp.x > scene.size.width * 0.55 && !player.bossDefeated {
                startBossFight()
            } else {
                tapAndMove(point, in: scene)
            }

        case .complete:
            tapAndMove(point, in: scene)

        case .act2:
            if tryAct2VillageInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)

        case .ruins:
            if tryRuinsInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)

        case .fallen:
            break

        case .act3:
            if tryAct3Interaction(wp, in: scene) { return }
            tapAndMove(point, in: scene)

        case .act4:
            if tryAct4Interaction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
        }
    }

    private func trySaveCrystalTap(_ point: CGPoint, in scene: SKScene) -> Bool {
        guard let crystal = world.worldNode.childNode(withName: "saveCrystal")
                ?? scene.childNode(withName: "saveCrystal") else { return false }
        guard point.distance(to: crystal.position) < 55 else { return false }
        triggerManualSave(crystalPosition: crystal.position, in: scene)
        return true
    }

    private func triggerManualSave(crystalPosition: CGPoint, in scene: SKScene) {
        player.currentHP = player.currentMaxHP   // Restauration complète au cristal
        saveGame()
        // Flash bleu sur le cristal
        JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                 color: SKColor(red: 0.40, green: 0.70, blue: 1.0, alpha: 1),
                                 duration: 0.25)
        JuiceEngine.screenShake(scene, intensity: 2)
        // Particules de save
        scene.addChild(ParticleFactory.impactSparks(
            at: crystalPosition,
            color: SKColor(red: 0.60, green: 0.85, blue: 1.0, alpha: 1),
            count: 14
        ))
        // Dialogue de confirmation
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.saveCrystalDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    // MARK: - Village NPC interactions

    private func tryVillageInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        if tryHouseDoorInteraction(point, in: scene) { return true }

        let radius: CGFloat = 32
        // PNJ candidats : on choisit le PLUS PROCHE dans le rayon (et non le
        // premier rencontré) pour éviter qu'un tap entre deux PNJ proches en
        // déclenche un autre que celui visé.
        let candidates: [(node: SKNode, action: () -> Void)] = [
            (world.dorin,    { [weak self] in self?.openDorinDialogue(scene: scene) }),
            (world.lyra,     { [weak self] in self?.openLyraDialogue() }),
            (world.bram,     { [weak self] in self?.openBramShop() }),
            (world.mara,     { [weak self] in self?.openMaraInteraction(scene: scene) }),
            (world.garen,    { [weak self] in self?.openGarenDialogue() }),
            (world.sage,     { [weak self] in self?.openSageDialogue() }),
            (world.child,    { [weak self] in self?.openChildDialogue() }),
            (world.villager, { [weak self] in self?.openVillagerDialogue() })
        ]
        if let action = nearestInteraction(from: point, candidates: candidates, radius: radius) {
            action()
            return true
        }
        return false
    }

    private func tryHouseDoorInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let doors: [(HouseInteriorKind, CGFloat)] = [
            (.armory, 48), (.apothecary, 44), (.inn, 44)
        ]
        for (kind, radius) in doors {
            let door = world.houseDoorPosition(for: kind, in: scene.size)
            if point.distance(to: door) < radius {
                enterHouse(kind, in: scene)
                return true
            }
        }
        return false
    }

    private func enterHouse(_ kind: HouseInteriorKind, in scene: SKScene) {
        activeInterior = kind
        AudioEngine.shared.setMood(.inn)
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            world.switchToInterior(kind, in: scene)
            hud.objectiveText = interiorObjective(for: kind)
        } completion: { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    private func leaveHouse(in scene: SKScene) {
        AudioEngine.shared.setMood(.forPhase(phase))
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            world.returnToVillageFromInterior(in: scene)
            hud.objectiveText = phase == .act2
                ? String(localized: "hud.objective.act2")
                : String(localized: "hud.objective.village")
            activeInterior = nil
        } completion: { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    private func tryInteriorInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        guard let activeInterior else { return false }
        if point.distance(to: world.interiorExitPosition(in: scene.size)) < 72 {
            leaveHouse(in: scene)
            return true
        }

        let servicePoint = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.62)
        if point.distance(to: servicePoint) < 105 {
            switch activeInterior {
            case .armory:
                openBramShop()
            case .apothecary:
                openMaraInteraction(scene: scene)
            case .inn:
                openSageDialogue()
            }
            return true
        }
        return false
    }

    private func interiorObjective(for kind: HouseInteriorKind) -> String {
        switch kind {
        case .armory:
            return String(localized: "hud.objective.interior.armory")
        case .apothecary:
            return String(localized: "hud.objective.interior.apothecary")
        case .inn:
            return String(localized: "hud.objective.interior.inn")
        }
    }

    // MARK: - NPC Dialogue / Shop Openers


    private func openLyraDialogue() {
        transition(to: .dialogue)

        switch player.questLyraShards {
        case .inactive:
            // First: normal village dialogue, then give quest
            dialogue.start(PrototypeContent.lyraVillageDialogue) { [weak self] in
                guard let self else { return }
                dialogue.start(PrototypeContent.lyraQuestGiveDialogue) { [weak self] in
                    guard let self else { return }
                    player.questLyraShards = .active
                    hud.questText = String(localized: "hud.quest.lyraShards")
                    transition(to: .exploration)
                }
            }

        case .active:
            if player.aetherShards >= 5 {
                // Turn in shards
                player.aetherShards -= 5
                player.gold += 50
                player.questLyraShards = .complete
                syncGold()
                hud.questText = ""
                AudioEngine.shared.playQuestComplete()
                GameCenterManager.shared.report(.lyraQuest)
                dialogue.start(PrototypeContent.lyraQuestCompleteDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            } else {
                dialogue.start(PrototypeContent.lyraQuestActiveDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            }

        case .complete:
            dialogue.start(PrototypeContent.lyraQuestDoneDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    private func openDorinDialogue(scene: SKScene) {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.dorinDialogue) { [weak self] in
            guard let self else { return }
            transition(to: .transition)
            TransitionManager.fade(in: scene) { [weak self] in
                guard let self else { return }
                phase = .forest
                hud.objectiveText = String(localized: "hud.objective.forest")
                world.endLyraVigil()
                showForest(in: scene)
            } completion: { [weak self] in
                guard let self else { return }
                if player.questChildToy == .active {
                    world.addToyMarker(in: scene)
                }
                if player.questMedallion == .active {
                    world.addMedallionMarker(in: scene)
                }
                addSideQuestMarkers(in: scene)
                transition(to: .exploration)
                // Spawn à l'orée sud, puis quelques pas d'entrée sur le sentier.
                let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
                world.kael.position = CGPoint(x: scene.size.width * 0.5, y: wh * 0.02)
                movement.move(world.kael, to: CGPoint(
                    x: scene.size.width * 0.5,
                    y: wh * 0.08
                ), in: CGSize(width: scene.size.width, height: wh))
            }
        }
    }

    func openBramShop() {
        transition(to: .dialogue)
        dialogue.start(bramGreetingContent()) { [weak self] in
            guard let self else { return }
            // Acceptation de la quête du fer (village, choix 0 = accepter)
            if phase == .village, player.questBramOre == .inactive,
               dialogue.lastChoiceIndex == 0 {
                player.questBramOre = .active
                hud.questText = String(localized: "quest.bramOre.hud")
                refreshQuestMarkers()
            }
            transition(to: .shop)
            shop.open(
                title: String(localized: "shop.bram.title"),
                items: bramItems(),
                player: player
            ) { [weak self] in
                self?.syncGold()
                self?.transition(to: .exploration)
            }
        }
    }

    /// Greeting de Bram selon la phase et l'état de sa quête.
    private func bramGreetingContent() -> [DialogueStep] {
        if phase == .act2 {
            return player.questBramOre == .complete
                ? PrototypeContent.bramOreDoneDialogue
                : PrototypeContent.bramAct2Dialogue
        }
        switch player.questBramOre {
        case .inactive: return PrototypeContent.bramGreeting
                             + PrototypeContent.bramOreOfferDialogue
        case .active:   return PrototypeContent.bramOreActiveDialogue
        case .complete: return PrototypeContent.bramOreDoneDialogue
        }
    }

    func openMaraInteraction(scene: SKScene) {
        transition(to: .dialogue)
        if player.questDelivery == .complete {
            // Acte II : Mara sent l'Aether noir sur Kael. Sinon greeting boutique.
            let greeting = phase == .act2
                ? PrototypeContent.maraAct2Dialogue
                : PrototypeContent.maraShopGreeting
            dialogue.start(greeting) { [weak self] in
                guard let self else { return }
                transition(to: .shop)
                shop.open(
                    title: String(localized: "shop.mara.title"),
                    items: maraItems(),
                    player: player
                ) { [weak self] in
                    self?.syncGold()
                    self?.transition(to: .exploration)
                }
            }
        } else if player.questDelivery == .active {
            // Player has the quest, offer shop
            dialogue.start(PrototypeContent.maraQuestActiveDialogue) { [weak self] in
                guard let self else { return }
                transition(to: .shop)
                shop.open(
                    title: String(localized: "shop.mara.title"),
                    items: maraItems(),
                    player: player
                ) { [weak self] in
                    self?.syncGold()
                    self?.transition(to: .exploration)
                }
            }
        } else {
            // First visit: give delivery quest
            dialogue.start(PrototypeContent.maraFirstMeetDialogue) { [weak self] in
                guard let self else { return }
                player.questDelivery = .active
                hud.questText = String(localized: "hud.quest.delivery")
                transition(to: .shop)
                shop.open(
                    title: String(localized: "shop.mara.title"),
                    items: maraItems(),
                    player: player
                ) { [weak self] in
                    self?.syncGold()
                    self?.transition(to: .exploration)
                }
            }
        }
    }

    private func openGarenDialogue() {
        transition(to: .dialogue)
        if player.questDelivery == .complete {
            // La confiance est gagnée : Garen parle de son éclaireur disparu.
            switch player.questGarenScout {
            case .inactive:
                dialogue.start(PrototypeContent.garenScoutOfferDialogue) { [weak self] in
                    guard let self else { return }
                    if dialogue.lastChoiceIndex == 0 {
                        player.questGarenScout = .active
                        hud.questText = String(localized: "quest.garenScout.hud")
                        refreshQuestMarkers()
                    }
                    transition(to: .exploration)
                }
            case .active:
                dialogue.start(PrototypeContent.garenScoutActiveDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            case .complete:
                dialogue.start(PrototypeContent.garenScoutDoneDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            }
        } else if player.questDelivery == .active {
            // Deliver the package
            player.questDelivery = .complete
            player.gold += 15
            syncGold()
            hud.questText = ""
            AudioEngine.shared.playQuestComplete()
            GameCenterManager.shared.report(.deliveryQuest)
            dialogue.start(PrototypeContent.garenDeliveryDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        } else {
            dialogue.start(PrototypeContent.garenFirstDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    private func openSageDialogue() {
        transition(to: .dialogue)
        dialogue.start(sageGreetingContent()) { [weak self] in
            guard let self else { return }
            // Acceptation de la quête de l'herbe lunaire (choix 0 = accepter)
            if phase == .village, player.questSageHerb == .inactive,
               dialogue.lastChoiceIndex == 0, player.talkedToSage {
                player.questSageHerb = .active
                hud.questText = String(localized: "quest.sageHerb.hud")
                refreshQuestMarkers()
            }
            player.talkedToSage = true
            if !player.innRested {
                // Offer inn rest for 10 gold
                transition(to: .shop)
                shop.open(
                    title: String(localized: "shop.inn.title"),
                    items: innItems(),
                    player: player
                ) { [weak self] in
                    self?.syncGold()
                    self?.transition(to: .exploration)
                }
            } else {
                transition(to: .exploration)
            }
        }
    }

    /// Greeting de Sage : première visite, puis quête de l'herbe lunaire.
    private func sageGreetingContent() -> [DialogueStep] {
        let base = player.innRested
            ? PrototypeContent.sageAfterRestDialogue
            : PrototypeContent.sageFirstDialogue
        // La quête ne s'offre qu'à partir de la 2e visite (et en Acte I) —
        // la première rencontre garde son rythme d'origine.
        guard player.talkedToSage, phase == .village else { return base }
        switch player.questSageHerb {
        case .inactive: return base + PrototypeContent.sageHerbOfferDialogue
        case .active:   return PrototypeContent.sageHerbActiveDialogue
        case .complete: return PrototypeContent.sageHerbDoneDialogue
        }
    }

    private func openChildDialogue() {
        transition(to: .dialogue)

        switch player.questChildToy {
        case .inactive:
            // First talk: original dialogue + quest give
            dialogue.start(PrototypeContent.childDialogue) { [weak self] in
                guard let self else { return }
                player.talkedToChild = true
                dialogue.start(PrototypeContent.childQuestDialogue) { [weak self] in
                    guard let self else { return }
                    player.questChildToy = .active
                    hud.questText = String(localized: "hud.quest.childToy")
                    transition(to: .exploration)
                }
            }

        case .active:
            dialogue.start(PrototypeContent.childQuestActiveDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }

        case .complete:
            dialogue.start(PrototypeContent.childQuestDoneDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    private func openVillagerDialogue() {
        transition(to: .dialogue)
        switch player.questMedallion {
        case .inactive:
            // Propose la quête du talisman (choix 0 = accepter)
            dialogue.start(PrototypeContent.villagerQuestOfferDialogue) { [weak self] in
                guard let self else { return }
                player.talkedToVillager = true
                if dialogue.lastChoiceIndex == 0 {
                    player.questMedallion = .active
                    hud.questText = String(localized: "quest.medallion.hud")
                    if phase == .forest, let scene {
                        world.addMedallionMarker(in: scene)
                    }
                    refreshQuestMarkers()
                }
                transition(to: .exploration)
            }
        case .active:
            dialogue.start(PrototypeContent.villagerQuestActiveDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        case .complete:
            dialogue.start(PrototypeContent.villagerQuestDoneDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Ramassage du talisman (quête villageoise) — récompense immédiate.
    func pickupMedallion() {
        guard let scene else { return }
        player.questMedallion = .complete
        player.gold += 60
        syncGold()
        hud.questText = ""
        AudioEngine.shared.playQuestComplete()
        world.removeMedallionMarker()
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spot = CGPoint(x: scene.size.width * 0.28, y: wh * 0.72)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), count: 12))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.medallionFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Ramassage du fer corrompu (quête de Bram) — récompense immédiate.
    func pickupOre() {
        guard let scene else { return }
        player.questBramOre = .complete
        player.gold += 90
        syncGold()
        hud.questText = ""
        AudioEngine.shared.playQuestComplete()
        world.removeOreMarker()
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spot = CGPoint(x: scene.size.width * 0.40, y: wh * 0.63)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1), count: 12))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.oreFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Cueillette de l'herbe lunaire (quête de Sage) — or + soin complet.
    func pickupHerb() {
        guard let scene else { return }
        player.questSageHerb = .complete
        player.gold += 50
        player.currentHP = player.currentMaxHP   // son parfum seul redonne des forces
        syncGold()
        hud.questText = ""
        AudioEngine.shared.playQuestComplete()
        world.removeHerbMarker()
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spot = CGPoint(x: scene.size.width * 0.12, y: wh * 0.40)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.70, green: 0.95, blue: 0.85, alpha: 1), count: 12))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.herbFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Découverte de l'insigne de Tomm (quête de Garen) — beat sombre.
    func pickupScoutBadge() {
        guard let scene else { return }
        player.questGarenScout = .complete
        player.gold += 70
        syncGold()
        hud.questText = ""
        AudioEngine.shared.playQuestComplete()
        world.removeBadgeMarker()
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spot = CGPoint(x: scene.size.width * 0.68, y: wh * 0.18)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.60, green: 0.70, blue: 0.90, alpha: 1), count: 10))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.scoutBadgeFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    // MARK: - Shop Items

    /// Forge de Bram : seul le PALIER SUIVANT de chaque catégorie est en
    /// vitrine (l'étal reste court et la progression lisible).
    /// Palier 3 (Aetherite) : gold sink de fin de partie.
    private func bramItems() -> [ShopItem] {
        let weapons: [(name: LocalizedStringResource, desc: LocalizedStringResource, price: Int)] = [
            ("shop.bram.ironBlade.name", "shop.bram.ironBlade.desc", 80),
            ("shop.bram.runicBlade.name", "shop.bram.runicBlade.desc", 180),
            ("shop.bram.aetheriteBlade.name", "shop.bram.aetheriteBlade.desc", 420)
        ]
        let armors: [(name: LocalizedStringResource, desc: LocalizedStringResource, price: Int)] = [
            ("shop.bram.chainMail.name", "shop.bram.chainMail.desc", 60),
            ("shop.bram.reinforced.name", "shop.bram.reinforced.desc", 150),
            ("shop.bram.aetheritePlate.name", "shop.bram.aetheritePlate.desc", 380)
        ]

        var items: [ShopItem] = []
        if player.weaponLevel < weapons.count {
            let next = weapons[player.weaponLevel]
            let targetLevel = player.weaponLevel + 1
            items.append(ShopItem(
                nameKey: next.name, descKey: next.desc, price: next.price,
                canBuy: { [weak self] _ in (self?.player.weaponLevel ?? 3) < targetLevel },
                onBuy: { [weak self] _ in self?.player.weaponLevel = targetLevel }
            ))
        }
        if player.armorLevel < armors.count {
            let next = armors[player.armorLevel]
            let targetLevel = player.armorLevel + 1
            items.append(ShopItem(
                nameKey: next.name, descKey: next.desc, price: next.price,
                canBuy: { [weak self] _ in (self?.player.armorLevel ?? 3) < targetLevel },
                onBuy: { [weak self] _ in self?.player.armorLevel = targetLevel }
            ))
        }
        return items
    }

    private func maraItems() -> [ShopItem] {
        [
            ShopItem(
                nameKey: "shop.mara.potion.name",
                descKey: "shop.mara.potion.desc",
                price: 15,
                canBuy: { [weak self] _ in !(self?.player.potionsFull ?? false) },
                onBuy: { [weak self] _ in
                    guard let self, player.potions < 3 else { return }
                    player.potions += 1
                }
            ),
            ShopItem(
                nameKey: "shop.mara.aetherShard.name",
                descKey: "shop.mara.aetherShard.desc",
                price: 25,
                canBuy: { [weak self] _ in (self?.player.aetherShards ?? 0) < 5 },
                onBuy: { [weak self] _ in self?.player.aetherShards += 1 }
            )
        ]
    }

    func innItems() -> [ShopItem] {
        [
            ShopItem(
                nameKey: "shop.inn.rest.name",
                descKey: "shop.inn.rest.desc",
                price: 10,
                canBuy: { [weak self] _ in !(self?.player.innRested ?? false) },
                onBuy: { [weak self] _ in self?.player.innRested = true }
            )
        ]
    }

    // MARK: - Pause / Options / Lore

    private func openPause() {
        guard state == .exploration || state == .dialogue else { return }
        guard let scene else { return }
        pause.show(in: scene)
        pause.resetSelection()
    }

    private func closePause() {
        pause.hide()
    }

    private func openOptions() {
        guard let scene else { return }
        pause.hide()
        options.show(in: scene)
    }

    private func closeOptions() {
        options.hide()
    }

    func openLore() {
        guard state == .exploration else { return }
        // reuse inventory state to block exploration taps; transition() masque
        // aussi la bulle d'interaction et le hint.
        transition(to: .inventory)
        let entries = PrototypeContent.buildLoreEntries(for: player)
        lore.open(entries: entries, bestiarySeen: player.bestiarySeen) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    func openQuestLog() {
        guard state == .exploration else { return }
        transition(to: .inventory)
        questLog.open(entries: buildQuestEntries()) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Compile les quêtes visibles (actives + terminées) pour le journal.
    private func buildQuestEntries() -> [QuestEntry] {
        let all: [(QuestState, String, String)] = [
            (player.questChildToy,   "questlog.toy.title",       "questlog.toy.desc"),
            (player.questDelivery,   "questlog.delivery.title",  "questlog.delivery.desc"),
            (player.questMushroom,   "questlog.mushroom.title",  "questlog.mushroom.desc"),
            (player.questLyraShards, "questlog.shards.title",    "questlog.shards.desc"),
            (player.questMedallion,  "questlog.medallion.title", "questlog.medallion.desc"),
            (player.questBramOre,    "questlog.bramOre.title",   "questlog.bramOre.desc"),
            (player.questSageHerb,   "questlog.sageHerb.title",  "questlog.sageHerb.desc"),
            (player.questGarenScout, "questlog.garenScout.title", "questlog.garenScout.desc"),
            (player.questMines,      "questlog.mines.title",      "questlog.mines.desc")
        ]
        let active = all.filter { $0.0 == .active }
        let done   = all.filter { $0.0 == .complete }
        return (active + done).map {
            QuestEntry(title: String(localized: String.LocalizationValue($0.1)),
                       desc: String(localized: String.LocalizationValue($0.2)),
                       state: $0.0)
        }
    }

    // MARK: - Death / Retry

    func showDeathScreen() {
        guard let scene else { return }
        death.show(in: scene)
    }

    private func retryLastCombat() {
        death.hide()
        player.currentHP = player.currentMaxHP   // full HP on retry
        lastCombatStarter?()
    }

    // MARK: - Interaction Hint

    private func updateInteractionHint() {
        guard let scene else {
            hud.interactionHint = ""
            bubble.hide()
            nearbyActionPoint = nil
            return
        }
        let kaelPos = world.kael.position
        let radius: CGFloat = 90
        var hint = ""
        var bubbleAnchor: CGPoint? = nil
        var bubbleAction: InteractionBubble.Action? = nil
        var actionPoint: CGPoint? = nil   // POI brut pour le bouton A

        if let activeInterior {
            let exit = world.interiorExitPosition(in: scene.size)
            if kaelPos.distance(to: exit) < radius {
                hint = String(localized: "hint.exit")
                bubbleAction = .enter
                bubbleAnchor = CGPoint(x: exit.x, y: exit.y + 34)
                actionPoint = exit
            } else {
                let servicePoint = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.62)
                if kaelPos.distance(to: servicePoint) < radius {
                    switch activeInterior {
                    case .armory: hint = String(localized: "hint.interior.armory")
                    case .apothecary: hint = String(localized: "hint.interior.apothecary")
                    case .inn: hint = String(localized: "hint.interior.inn")
                    }
                    bubbleAction = activeInterior == .inn ? .talk : .shop
                    bubbleAnchor = CGPoint(x: servicePoint.x, y: servicePoint.y + 42)
                    actionPoint = servicePoint
                }
            }
        } else if inMines {
            // POI des mines : combats, plaque, veine, sortie
            let w = scene.size.width, h = scene.size.height
            var checkpoints: [(CGPoint, String)] = [
                (CGPoint(x: w*0.18, y: h*0.68), "hint.examine"),
                (CGPoint(x: w*0.50, y: h*0.08), "hint.exit")
            ]
            if player.minesProgress < 1 {
                checkpoints.append((CGPoint(x: w*0.30, y: h*0.48), "hint.fight"))
            } else if player.minesProgress == 1 {
                checkpoints.append((CGPoint(x: w*0.46, y: h*0.64), "hint.fight"))
            } else if player.minesProgress == 2 {
                checkpoints.append((CGPoint(x: w*0.62, y: h*0.68), "hint.fight"))
            }
            if !player.minesGoldTaken {
                checkpoints.append((CGPoint(x: w*0.80, y: h*0.40), "hint.examine"))
            }
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        } else if inDesert {
            // POI du désert : combats, coffre, oasis, sortie
            let w = scene.size.width, h = scene.size.height
            var checkpoints: [(CGPoint, String)] = [
                (CGPoint(x: w*0.50, y: h*0.08), "hint.exit")
            ]
            if player.desertProgress < 1 {
                checkpoints.append((CGPoint(x: w*0.28, y: h*0.55), "hint.fight"))
            } else if player.desertProgress == 1 {
                checkpoints.append((CGPoint(x: w*0.55, y: h*0.68), "hint.fight"))
            } else if player.desertProgress == 2, player.questDesert != .complete {
                checkpoints.append((CGPoint(x: w*0.80, y: h*0.55), "hint.fight"))
            }
            if !player.desertChestTaken {
                checkpoints.append((CGPoint(x: w*0.12, y: h*0.56), "hint.examine"))
            }
            if !player.desertOasisUsed {
                checkpoints.append((CGPoint(x: w*0.85, y: h*0.20), "hint.examine"))
            }
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        } else {
            switch phase {
            case .shrine:
                if !player.bossDefeated {
                    let gate = CGPoint(x: scene.size.width * 0.72,
                                       y: scene.size.height * 0.50)
                    if kaelPos.distance(to: gate) < 130 {
                        hint = localizedHint("hint.fight")
                        bubbleAction = .fight
                        bubbleAnchor = CGPoint(x: gate.x, y: gate.y + 40)
                        actionPoint = gate
                    }
                }
            case .village, .act2:
            let npcs: [(SKNode, String)] = [
                (world.lyra,     "hint.talk"),
                (world.dorin,    "hint.talk"),
                (world.bram,     "hint.shop"),
                (world.mara,     "hint.shop"),
                (world.garen,    "hint.talk"),
                (world.sage,     "hint.talk"),
                (world.child,    "hint.talk"),
                (world.villager, "hint.talk")
            ]
            // Portes des maisons : le bouton A permet aussi d'entrer.
            let doors: [(CGPoint, String)] = [.armory, .apothecary, .inn].map {
                (world.houseDoorPosition(for: $0, in: scene.size), "hint.enter")
            }
            let nearestDoor = nearestCheckpoint(from: kaelPos, points: doors, radius: 70)
            if let nearest = nearestNPC(from: kaelPos, npcs: npcs, radius: radius),
               nearestDoor == nil
               || kaelPos.distance(to: nearest.node.position)
                  <= kaelPos.distance(to: nearestDoor!.point) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                // Ancrer la bulle ~50pt au-dessus de la tête du PNJ
                bubbleAnchor = CGPoint(x: nearest.node.position.x,
                                        y: nearest.node.position.y + 60)
                actionPoint = nearest.node.position
            } else if let door = nearestDoor {
                hint = localizedHint(door.key)
                bubbleAction = .enter
                bubbleAnchor = CGPoint(x: door.point.x, y: door.point.y + 40)
                actionPoint = door.point
            }
        case .ruins:
            let w = scene.size.width, h = scene.size.height
            let checkpoints: [(CGPoint, String)] = [
                (CGPoint(x: w*0.28, y: h*0.50), "hint.fight"),
                (CGPoint(x: w*0.62, y: h*0.60), "hint.fight"),
                (CGPoint(x: w*0.15, y: h*0.65), "hint.examine"),
                (CGPoint(x: w*0.70, y: h*0.65), "hint.examine")
            ]
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        case .forest:
            // POI en coordonnées MONDE (trek scrollable, cf. buildForest)
            let w = scene.size.width
            let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            let checkpoints: [(CGPoint, String)] = [
                (CGPoint(x: w*0.30, y: h*0.31), "hint.fight"),
                (CGPoint(x: w*0.70, y: h*0.66), "hint.fight"),
                (CGPoint(x: w*0.20, y: h*0.585), "hint.fight"),
                (CGPoint(x: w*0.82, y: h*0.74), "hint.fight"),
                (CGPoint(x: w*0.88, y: h*0.30), "hint.enter"),
                (CGPoint(x: w*0.55, y: h*0.90), "hint.enter")
            ]
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        case .act3:
            let w = scene.size.width, h = scene.size.height
            var checkpoints: [(CGPoint, String)] = []
            if !player.act3EchoJoined, let echoPos = world.thresholdEchoPosition {
                checkpoints.append((echoPos, "hint.talk"))
            }
            for id in ["miner", "mother", "guard"]
            where !player.act3SpiritsCalmed.contains(id) {
                if let pos = world.spiritPosition(id: id) {
                    checkpoints.append((pos, "hint.talk"))
                }
            }
            for stele in [("1", 0.24, 0.34), ("2", 0.60, 0.32), ("3", 0.76, 0.28)]
            where !player.act3StelesRead.contains(stele.0) {
                checkpoints.append((CGPoint(x: w*stele.1, y: h*stele.2), "hint.examine"))
            }
            if !player.act3ShadesDefeated, player.act3EchoJoined {
                checkpoints.append((CGPoint(x: w*0.22, y: h*0.64), "hint.fight"))
            }
            if !player.act3EranMet {
                checkpoints.append((CGPoint(x: w*0.50, y: h*0.62), "hint.examine"))
            } else if !player.act3BossDefeated {
                checkpoints.append((CGPoint(x: w*0.50, y: h*0.82), "hint.fight"))
            } else {
                checkpoints.append((CGPoint(x: w*0.50, y: h*0.82), "hint.enter"))
            }
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        case .act4:
            let w = scene.size.width, h = scene.size.height
            var checkpoints: [(CGPoint, String)] = []
            for m in [("1", 0.20, 0.46), ("2", 0.62, 0.30), ("3", 0.80, 0.52)]
            where !player.act4MemoriesSeen.contains(m.0) {
                checkpoints.append((CGPoint(x: w*m.1, y: h*m.2), "hint.examine"))
            }
            for id in ["elder", "smith", "lost"]
            where !player.act4ReflectionsFreed.contains(id) {
                if let pos = world.spiritPosition(id: id) {
                    checkpoints.append((pos, "hint.talk"))
                }
            }
            if !player.act4DevourersDefeated {
                checkpoints.append((CGPoint(x: w*0.80, y: h*0.66), "hint.fight"))
            }
            if !player.act4VoiceConfronted {
                checkpoints.append((CGPoint(x: w*0.50, y: h*0.58), "hint.examine"))
            } else if !player.act4BossDefeated {
                checkpoints.append((CGPoint(x: w*0.50, y: h*0.80), "hint.fight"))
            } else {
                checkpoints.append((CGPoint(x: w*0.50, y: h*0.80), "hint.examine"))
            }
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
            default:
                break
            }
        }

        // Save crystal — accessible via A (icône cristal déjà visible)
        if hint.isEmpty, let crystal = world.worldNode.childNode(withName: "saveCrystal")
                                        ?? scene.childNode(withName: "saveCrystal"),
           kaelPos.distance(to: crystal.position) < radius {
            hint = String(localized: "hint.saveCrystal")
            actionPoint = crystal.position
        }

        hud.interactionHint = hint

        // Bouton A : mémorise le POI courant (c'était le chaînon manquant —
        // sans cette ligne, A ne déclenchait jamais rien).
        nearbyActionPoint = actionPoint
        updateActionButtonState()

        if let anchor = bubbleAnchor, let action = bubbleAction {
            let screenAnchor = scene.convert(anchor, from: world.worldNode)
            bubble.show(at: screenAnchor, action: action)
        } else {
            bubble.hide()
        }
    }

    /// Retourne l'action du candidat (PNJ visible) le plus proche de `origin`
    /// dans `radius`. Choisir le plus proche — et non le premier — évite qu'un
    /// tap entre deux PNJ proches déclenche le mauvais.
    func nearestInteraction(from origin: CGPoint,
                                    candidates: [(node: SKNode, action: () -> Void)],
                                    radius: CGFloat) -> (() -> Void)? {
        var best: (action: () -> Void, dist: CGFloat)?
        for candidate in candidates where !candidate.node.isHidden {
            let d = origin.distance(to: candidate.node.position)
            guard d < radius else { continue }
            if best == nil || d < best!.dist {
                best = (candidate.action, d)
            }
        }
        return best?.action
    }

    /// Retourne le PNJ visible le plus proche de `origin` dans `radius`.
    private func nearestNPC(from origin: CGPoint,
                             npcs: [(SKNode, String)],
                             radius: CGFloat) -> (node: SKNode, key: String)? {
        var best: (node: SKNode, key: String, dist: CGFloat)? = nil
        for (npc, key) in npcs where !npc.isHidden {
            let d = origin.distance(to: npc.position)
            guard d < radius else { continue }
            if best == nil || d < best!.dist {
                best = (npc, key, d)
            }
        }
        return best.map { ($0.node, $0.key) }
    }

    /// Retourne le checkpoint le plus proche de `origin` dans `radius`.
    private func nearestCheckpoint(from origin: CGPoint,
                                    points: [(CGPoint, String)],
                                    radius: CGFloat) -> (point: CGPoint, key: String)? {
        var best: (point: CGPoint, key: String, dist: CGFloat)? = nil
        for (pt, key) in points {
            let d = origin.distance(to: pt)
            guard d < radius else { continue }
            if best == nil || d < best!.dist {
                best = (pt, key, d)
            }
        }
        return best.map { ($0.point, $0.key) }
    }

    // MARK: - Minimap

    private func updateMinimap() {
        guard let scene else { return }
        let npcs: [(position: CGPoint, color: SKColor)] = [
            (world.lyra.position,    SKColor(red: 0.85, green: 0.65, blue: 1.0, alpha: 1)),
            (world.dorin.position,   SKColor(red: 0.55, green: 0.85, blue: 0.55, alpha: 1)),
            (world.bram.position,    SKColor(red: 1.0,  green: 0.75, blue: 0.3,  alpha: 1)),
            (world.mara.position,    SKColor(red: 1.0,  green: 0.75, blue: 0.3,  alpha: 1)),
            (world.garen.position,   SKColor(red: 0.5,  green: 0.8,  blue: 1.0,  alpha: 1)),
            (world.sage.position,    SKColor(red: 0.5,  green: 0.8,  blue: 1.0,  alpha: 1))
        ].filter { !$0.position.equalTo(.zero) }
        let worldSize = CGSize(width: scene.size.width,
                               height: world.worldHeight > 0 ? world.worldHeight : scene.size.height)
        minimap.update(kaelPosition: world.kael.position,
                       sceneSize: worldSize,
                       npcs: npcs)
    }

    // MARK: - Act III

    private func tryAct3Interaction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width, h = scene.size.height
        let gate = CGPoint(x: w * 0.50, y: h * 0.82)   // escalier = Le Seuil

        // 0) L'Écho de Lyra attend à l'entrée — première rencontre
        if !player.act3EchoJoined,
           let echoPos = world.thresholdEchoPosition,
           point.distance(to: echoPos) < 70 {
            openAct3EchoMeet()
            return true
        }

        // Esprits errants (quête « Les échos égarés »)
        for id in ["miner", "mother", "guard"]
        where !player.act3SpiritsCalmed.contains(id) {
            if let pos = world.spiritPosition(id: id),
               point.distance(to: pos) < 60 {
                openSpiritDialogue(id: id)
                return true
            }
        }

        // Stèles du Vide (les trois tombes noires)
        let steles: [(id: String, x: CGFloat, y: CGFloat)] = [
            ("1", 0.24, 0.34), ("2", 0.60, 0.32), ("3", 0.76, 0.28)
        ]
        for stele in steles where !player.act3StelesRead.contains(stele.id) {
            if point.distance(to: CGPoint(x: w * stele.x, y: h * stele.y)) < 55 {
                openSteleDialogue(id: stele.id)
                return true
            }
        }

        // Ombres du Vide — combat annexe du trio
        if !player.act3ShadesDefeated, player.act3EchoJoined,
           point.distance(to: CGPoint(x: w * 0.22, y: h * 0.64)) < 75 {
            startVoidShadesCombat()
            return true
        }

        // 1) Rencontre Eran (centre) tant qu'elle n'a pas eu lieu
        if !player.act3EranMet {
            if point.distance(to: CGPoint(x: w * 0.50, y: h * 0.62)) < 80 {
                openAct3EranMeet()
                return true
            }
            return false
        }
        // 2) Gardien du Seuil — combat final
        if !player.act3BossDefeated {
            if point.distance(to: gate) < 90 {
                startThresholdBoss()
                return true
            }
            return false
        }
        // 3) Boss vaincu → franchir le Seuil (vraie fin)
        if point.distance(to: gate) < 90 {
            showAct3TrueEnding()
            return true
        }
        return false
    }

    // MARK: - Inventory

    func openInventory() {
        guard state == .exploration else { return }
        transition(to: .inventory)
        inventory.open(player: player) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    // MARK: - Helpers

    /// Ouvre un overlay par son nom (hook debug --overlay-test).
    private func debugShowOverlay(named name: String) {
        guard let scene else { return }
        switch name {
        case "pause":     openPause()
        case "options":   openOptions()
        case "inventory": openInventory()
        case "questlog":  openQuestLog()
        case "lore":      openLore()
        case "tutorial":  tutorial.show(in: scene)
        case "levelup":   levelUp.show(newLevel: 5, isMax: false) {}
        case "death":     death.show(in: scene)
        case "shop":
            transition(to: .shop)
            shop.open(title: String(localized: "shop.bram.title"),
                      items: bramItems(), player: player) { [weak self] in
                self?.transition(to: .exploration)
            }
        case "act2end":
            // Audit : écran de fin d'Acte II + continuation complète.
            TransitionManager.showAct2EndScreen(in: scene) { [weak self] in
                guard let self, let sc = self.scene else { return }
                TransitionManager.showCredits(in: sc) { [weak self] in
                    self?.beginAct3()
                }
            }
        case "bestiary":
            // Audit : toutes les espèces révélées, ouverture sur l'onglet
            player.bestiarySeen = Set(CombatSpriteKind.allCases.map(\.bestiaryID))
            transition(to: .inventory)
            lore.open(entries: PrototypeContent.buildLoreEntries(for: player),
                      bestiarySeen: player.bestiarySeen,
                      startOnBestiary: true) { [weak self] in
                self?.transition(to: .exploration)
            }
        case "dialogue":
            // Audit des portraits : un locuteur de chaque famille.
            transition(to: .dialogue)
            dialogue.start([
                // Réplique la plus longue du jeu : vérifie que le panneau
                // grandit avec le texte (3 lignes) sans déborder.
                .line(speaker: "Dorin",
                      text: String(localized: "dialogue.dorin.real.6")),
                .line(speaker: "Kael", text: "Audit portrait Kael."),
                .line(speaker: "Lyra", text: "Audit portrait Lyra."),
                .line(speaker: "Dorin", text: "Audit portrait Dorin."),
                .line(speaker: "Sage", text: "Audit portrait Sage."),
                .line(speaker: String(localized: "dialogue.boss.guardianName"),
                      text: "Audit portrait Gardien."),
                .line(speaker: "Eran", text: "Audit portrait Eran."),
                .line(speaker: String(localized: "dialogue.shrine.voiceName"),
                      text: "Audit sans portrait (voix).")
            ]) { [weak self] in self?.transition(to: .exploration) }
        case "dialoguechoice":
            // Audit du panneau de choix compact (hauteur dynamique).
            transition(to: .dialogue)
            dialogue.start([
                .choice(prompt: "Kael", options: [
                    DialogueChoice(title: "Je garderai l'œil ouvert.",
                                   responseSpeaker: "Villageoise",
                                   response: "Merci, voyageur."),
                    DialogueChoice(title: "La forêt est grande. Je ne promets rien.",
                                   responseSpeaker: "Villageoise",
                                   response: "Je comprends...")
                ])
            ]) { [weak self] in self?.transition(to: .exploration) }
        case "worldmap":
            // Audit de la carte du monde (états des lieux selon la phase).
            worldMap.open(places: buildMapPlaces()) {}
        default: break
        }
    }

    private func tapAndMove(_ point: CGPoint, in scene: SKScene) {
        let worldPoint = world.worldNode.convert(point, from: scene)
        let worldSize = CGSize(width: scene.size.width, height: world.worldHeight > 0 ? world.worldHeight : scene.size.height)
        // Trajet stoppé au premier obstacle (maison, arbre, eau…)
        let reachable = world.clampDestination(from: world.kael.position,
                                               to: worldPoint)
        movement.move(world.kael, to: reachable, in: worldSize)
        let marker = ParticleFactory.tapMarker(at: reachable)
        world.worldNode.addChild(marker)
    }

    func transition(to newState: GameState) {
        let wasCombat = state == .combat
        state = newState
        if newState == .exploration { saveGame() }
        // Bulle d'interaction visible uniquement en exploration ;
        // sinon elle resterait à flotter pendant dialogue/combat/pause.
        if newState != .exploration {
            bubble.hide()
            hud.interactionHint = ""
        }
        // Le combat occupe l'écran entier : HUD d'exploration masqué.
        if newState == .combat {
            hud.setVisible(false)
        } else if wasCombat {
            hud.setVisible(true)
        }
        if newState == .exploration { refreshQuestMarkers() }
        // Les PNJ flânent librement dans le village pendant l'exploration ;
        // ils s'arrêtent net dès qu'un dialogue/combat/menu s'ouvre.
        if newState == .exploration, phase == .village,
           !world.isInsideInterior, let scene {
            world.startVillageWander(in: scene.size)
        } else if newState != .exploration {
            world.stopVillageWander()
        }
    }

    /// « ! » doré au-dessus des PNJ qui ont une quête à proposer.
    private func refreshQuestMarkers() {
        world.setQuestMarker(on: world.child,
                             visible: phase == .village && player.questChildToy == .inactive)
        world.setQuestMarker(on: world.villager,
                             visible: phase == .village && player.questMedallion == .inactive)
        world.setQuestMarker(on: world.mara,
                             visible: phase == .village && player.questDelivery == .inactive)
        world.setQuestMarker(on: world.lyra,
                             visible: phase == .village && player.questLyraShards == .inactive)
        world.setQuestMarker(on: world.bram,
                             visible: phase == .village && player.questBramOre == .inactive)
        world.setQuestMarker(on: world.sage,
                             visible: phase == .village && player.questSageHerb == .inactive
                                      && player.talkedToSage)
        world.setQuestMarker(on: world.garen,
                             visible: phase == .village && player.questGarenScout == .inactive
                                      && player.questDelivery == .complete)
    }

    /// Place les marqueurs de collecte des quêtes annexes actives (forêt)
    /// et l'entrée des mines de Cendreval (toujours visible).
    func addSideQuestMarkers(in scene: SKScene) {
        if player.questBramOre == .active    { world.addOreMarker(in: scene) }
        if player.questSageHerb == .active   { world.addHerbMarker(in: scene) }
        if player.questGarenScout == .active { world.addBadgeMarker(in: scene) }
        world.addMineEntrance(in: scene)
        world.addCaveEntrance(in: scene)   // donjon optionnel (flanc ouest)
    }

    // MARK: - Monstres baladeurs (aggro au contact)

    /// Retire tous les monstres baladeurs (changement de zone, contact).
    func clearRoamers() {
        roamers.forEach { $0.node.removeFromParent() }
        roamers.removeAll()
    }

    /// Fait patrouiller/charger les monstres ; au contact, lance le combat.
    private func updateRoamers(deltaTime: TimeInterval) {
        guard state == .exploration, !roamers.isEmpty else { return }
        let heroPos = world.kael.position
        for roamer in roamers {
            if roamer.update(deltaTime: deltaTime, heroPos: heroPos) {
                clearRoamers()   // le combat prend le relais
                return
            }
        }
    }

    /// Peuple les mines de monstres baladeurs selon la progression.
    func spawnMineRoamers() {
        guard let scene else { return }
        clearRoamers()
        let w = scene.size.width, h = scene.size.height
        let wh = world.worldHeight > 0 ? world.worldHeight : h
        switch player.minesProgress {
        case 0:
            addRoamer("enemy_ghoul", at: CGPoint(x: w * 0.30, y: h * 0.48),
                      wh: wh) { [weak self] in self?.startMinesCombat1() }
        case 1:
            addRoamer("enemy_bone", at: CGPoint(x: w * 0.46, y: h * 0.62),
                      wh: wh) { [weak self] in self?.startMinesCombat2() }
        case 2 where player.questMines != .complete:
            // Le golem est un boss : plus lent, patrouille plus large.
            addRoamer("enemy_bone", at: CGPoint(x: w * 0.62, y: h * 0.66),
                      wh: wh, patrolRadius: 40, chaseSpeed: 74) { [weak self] in
                self?.startMinesBossSequence()
            }
        default:
            break
        }
    }

    /// Chasses optionnelles (ghoul/bone) vaincues durant la visite courante
    /// de la forêt : évite qu'elles rechargent Kael en boucle. Remis à zéro
    /// à chaque nouvelle entrée en forêt (`showForest`).
    var forestHuntsCleared: Set<String> = []

    /// Affiche la forêt ET (re)peuple ses monstres baladeurs. Remplace les
    /// appels directs à `world.switchToForest` pour garantir le spawn.
    func showForest(in scene: SKScene) {
        world.switchToForest(in: scene)
        forestHuntsCleared.removeAll()
        spawnForestRoamers()
    }

    /// Peuple la forêt : combat de progression courant + chasses optionnelles
    /// non encore vaincues cette visite. Coords MONDE (trek scrollable).
    func spawnForestRoamers() {
        guard let scene, !inMines, !inCave, phase == .forest else { clearRoamers(); return }
        clearRoamers()
        let w = scene.size.width
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        // Combat de progression : bête (bosquet) puis loups (clairière).
        if player.forestProgress < 1 {
            addRoamer("enemy_ghoul", at: CGPoint(x: w * 0.30, y: wh * 0.31),
                      wh: wh) { [weak self] in self?.startGroveCombat() }
        } else if player.forestProgress < 2 {
            addRoamer("enemy_shadewolf", at: CGPoint(x: w * 0.70, y: wh * 0.66),
                      wh: wh) { [weak self] in self?.startClearingCombat() }
        }
        // Chasses optionnelles répétables (tant que non vaincues cette visite).
        if !forestHuntsCleared.contains("ghoul") {
            addRoamer("enemy_ghoul", at: CGPoint(x: w * 0.20, y: wh * 0.585),
                      wh: wh) { [weak self] in self?.startGhoulCombat() }
        }
        if !forestHuntsCleared.contains("bone") {
            addRoamer("enemy_bone", at: CGPoint(x: w * 0.82, y: wh * 0.74),
                      wh: wh) { [weak self] in self?.startBoneCombat() }
        }
    }

    /// Peuple la caverne du gardien baladeur (si pas encore vaincu).
    func spawnCaveRoamer() {
        guard let scene, !player.caveCleared else { clearRoamers(); return }
        clearRoamers()
        let w = scene.size.width, h = scene.size.height
        addRoamer("enemy_bone", at: CGPoint(x: w * 0.50, y: h * 0.55),
                  wh: h, patrolRadius: 80) { [weak self] in self?.startCaveCombat() }
    }

    /// Crée un monstre baladeur (sprite animé) et l'enregistre.
    func addRoamer(_ asset: String, at pos: CGPoint, wh: CGFloat,
                           patrolRadius: CGFloat = 70, chaseSpeed: CGFloat = 104,
                           startCombat: @escaping () -> Void) {
        guard let node = world.makeRoamingMonster(asset: asset) else { return }
        world.worldNode.addChild(node)
        roamers.append(RoamingMonster(
            node: node, home: pos, worldHeight: wh,
            patrolRadius: patrolRadius, chaseSpeed: chaseSpeed,
            startCombat: startCombat))
    }

    // MARK: - Carte du monde

    /// Le voyage n'a de sens que dans les phases « libres » : la forêt et
    /// le village post-sanctuaire. Jamais depuis une excursion (mines) ni
    /// un intérieur — sauf pour revenir du désert.
    private var worldMapAvailable: Bool {
        if inDesert { return true }
        guard !inMines, activeInterior == nil else { return false }
        return [.forest, .complete, .act2].contains(phase)
    }

    /// Identifiant carte de la zone où se trouve Kael.
    private var currentPlaceID: String {
        if inDesert { return "desert" }
        if inMines { return "mines" }
        switch phase {
        case .wake, .village, .complete, .act2, .fallen: return "village"
        case .forest: return "forest"
        case .shrine: return "shrine"
        case .ruins: return "ruins"
        case .act3: return "threshold"
        case .act4: return "voidheart"
        }
    }

    private func openWorldMap() {
        guard state == .exploration, worldMapAvailable else { return }
        HapticsEngine.light()
        worldMap.open(places: buildMapPlaces()) {}
    }

    /// Construit l'état des lieux selon la progression de l'histoire.
    private func buildMapPlaces() -> [WorldMapPlace] {
        let current = currentPlaceID
        let reached = phase.rawValue
        // Retour depuis le désert : la zone d'origine redevient voyageable.
        let returnID = inDesert ? (phase == .forest ? "forest" : "village") : ""
        let desertTravel = !inDesert && worldMapAvailable

        func placeState(_ id: String, discovered: Bool,
                        travel: Bool) -> WorldMapPlace.State {
            if id == current { return .current }
            if travel { return .available }
            return discovered ? .locked : .hidden
        }

        return [
            WorldMapPlace(id: "village",
                          title: String(localized: "map.place.village"),
                          point: CGPoint(x: 0.20, y: 0.80),
                          state: placeState("village", discovered: true,
                                            travel: returnID == "village"),
                          accent: SKColor(red: 0.35, green: 0.65, blue: 0.35, alpha: 1)),
            WorldMapPlace(id: "forest",
                          title: String(localized: "map.place.forest"),
                          point: CGPoint(x: 0.45, y: 0.64),
                          state: placeState("forest",
                                            discovered: reached >= GamePhase.forest.rawValue,
                                            travel: returnID == "forest"),
                          accent: SKColor(red: 0.15, green: 0.42, blue: 0.22, alpha: 1)),
            WorldMapPlace(id: "mines",
                          title: String(localized: "map.place.mines"),
                          point: CGPoint(x: 0.28, y: 0.42),
                          state: placeState("mines",
                                            discovered: reached >= GamePhase.forest.rawValue,
                                            travel: false),
                          accent: SKColor(red: 0.40, green: 0.38, blue: 0.42, alpha: 1)),
            WorldMapPlace(id: "shrine",
                          title: String(localized: "map.place.shrine"),
                          point: CGPoint(x: 0.70, y: 0.82),
                          state: placeState("shrine",
                                            discovered: reached >= GamePhase.shrine.rawValue,
                                            travel: false),
                          accent: SKColor(red: 0.30, green: 0.55, blue: 0.85, alpha: 1)),
            WorldMapPlace(id: "desert",
                          title: String(localized: "map.place.desert"),
                          point: CGPoint(x: 0.80, y: 0.48),
                          state: placeState("desert",
                                            discovered: reached >= GamePhase.forest.rawValue,
                                            travel: desertTravel),
                          accent: SKColor(red: 0.85, green: 0.66, blue: 0.30, alpha: 1)),
            WorldMapPlace(id: "ruins",
                          title: String(localized: "map.place.ruins"),
                          point: CGPoint(x: 0.16, y: 0.22),
                          state: placeState("ruins",
                                            discovered: reached >= GamePhase.ruins.rawValue,
                                            travel: false),
                          accent: SKColor(red: 0.55, green: 0.40, blue: 0.75, alpha: 1)),
            WorldMapPlace(id: "threshold",
                          title: String(localized: "map.place.threshold"),
                          point: CGPoint(x: 0.52, y: 0.20),
                          state: placeState("threshold",
                                            discovered: reached >= GamePhase.act3.rawValue,
                                            travel: false),
                          accent: SKColor(red: 0.35, green: 0.22, blue: 0.55, alpha: 1)),
            WorldMapPlace(id: "voidheart",
                          title: String(localized: "map.place.voidheart"),
                          point: CGPoint(x: 0.82, y: 0.12),
                          state: placeState("voidheart",
                                            discovered: reached >= GamePhase.act4.rawValue,
                                            travel: false),
                          accent: SKColor(red: 0.18, green: 0.12, blue: 0.28, alpha: 1))
        ]
    }

    /// Voyage depuis la carte : seul le désert (aller) et la zone
    /// d'origine (retour) sont voyageables pour l'instant.
    private func travel(to id: String) {
        switch id {
        case "desert" where !inDesert:
            enterDesert()
        case "forest", "village":
            if inDesert { exitDesert() }
        default:
            break
        }
    }

    // MARK: - Save / Load

    func saveGame() {
        let data = player.toSaveData(phase: phase, resonance: resonanceTotal)
        SaveManager.save(data, slot: activeSlot)
    }

    private func restoreFrom(save: SaveData, scene: SKScene) {
        player.load(from: save)
        resonanceTotal = save.resonanceTotal
        phase = save.phase
        inMines = false   // la save ne stocke jamais l'excursion aux mines
        inDesert = false  // ni le voyage au désert : respawn en zone d'origine

        hud.goldValue = player.gold
        hud.resonanceValue = resonanceTotal

        switch phase {
        case .wake:
            startWakeSequence()
        case .village:
            hud.objectiveText = String(localized: "hud.objective.village")
            transition(to: .exploration)
        case .forest:
            hud.objectiveText = String(localized: "hud.objective.forest")
            showForest(in: scene)
            if player.questChildToy == .active {
                world.addToyMarker(in: scene)
            }
            if player.questMedallion == .active {
                world.addMedallionMarker(in: scene)
            }
            addSideQuestMarkers(in: scene)
            // Spawn à l'orée sud du trek (la forêt scrolle).
            world.kael.position = CGPoint(x: scene.size.width * 0.5,
                                          y: world.worldHeight * 0.05)
            transition(to: .exploration)
        case .shrine:
            hud.objectiveText = String(localized: "hud.objective.shrine")
            world.switchToShrine(in: scene)
            transition(to: .exploration)
        case .complete:
            // Save interrompue entre la fin de l'Acte I et le début de
            // l'Acte II : sans relance, aucun déclencheur de suite (cul-de-sac,
            // même famille que le boss forêt déjà vaincu). On reprend la suite.
            hud.objectiveText = String(localized: "hud.objective.complete")
            transition(to: .exploration)
            beginAct2()

        case .act2:
            hud.objectiveText = String(localized: "hud.objective.act2")
            world.switchToVillage(in: scene)
            world.repositionDorinToGate(in: scene)
            world.applyKaelCorruption(level: player.kaelCorruptionLevel)
            transition(to: .exploration)

        case .ruins:
            hud.objectiveText = player.ruinsProgress >= 2
                ? String(localized: "hud.objective.discovery")
                : String(localized: "hud.objective.ruins")
            world.switchToRuins(in: scene)
            world.applyKaelCorruption(level: player.kaelCorruptionLevel)
            transition(to: .exploration)

        case .fallen:
            hud.objectiveText = String(localized: "hud.objective.fallen")
            world.switchToRuins(in: scene)
            world.applyKaelCorruption(level: player.kaelCorruptionLevel)
            transition(to: .exploration)
            // Save interrompue à la fin de l'Acte II : re-propose la suite.
            TransitionManager.showAct2EndScreen(in: scene) { [weak self] in
                self?.beginAct3()
            }

        case .act3:
            hud.objectiveText = player.act3BossDefeated
                ? String(localized: "hud.objective.act3End")
                : (player.act3EranMet
                    ? String(localized: "hud.objective.act3Boss")
                    : String(localized: "hud.objective.act3"))
            world.switchToThreshold(in: scene,
                                    echoJoined: player.act3EchoJoined,
                                    spiritsCalmed: player.act3SpiritsCalmed,
                                    shadesDefeated: player.act3ShadesDefeated)
            world.applyKaelCorruption(level: 3)
            corruptionCinematicShown = true
            transition(to: .exploration)

        case .act4:
            hud.objectiveText = player.act4BossDefeated
                ? String(localized: "hud.objective.act4End")
                : (player.act4VoiceConfronted
                    ? String(localized: "hud.objective.act4Boss")
                    : String(localized: "hud.objective.act4"))
            world.switchToVoidHeart(in: scene,
                                    echoJoined: player.act3EchoJoined,
                                    reflectionsFreed: player.act4ReflectionsFreed,
                                    devourersDefeated: player.act4DevourersDefeated,
                                    bossDefeated: player.act4BossDefeated)
            world.applyKaelCorruption(level: 3)
            corruptionCinematicShown = true
            transition(to: .exploration)
        }
    }

    // MARK: - Localization helpers

    /// Résout les clés de hint via un switch statique
    /// pour que Xcode puisse les trouver dans le code source.
    private func localizedHint(_ key: String) -> String {
        switch key {
        case "hint.talk":    return String(localized: "hint.talk")
        case "hint.shop":    return String(localized: "hint.shop")
        case "hint.fight":   return String(localized: "hint.fight")
        case "hint.examine": return String(localized: "hint.examine")
        case "hint.enter":   return String(localized: "hint.enter")
        case "hint.exit":    return String(localized: "hint.exit")
        default:             return key
        }
    }
}
