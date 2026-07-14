import SpriteKit

@MainActor
final class GameManager {
    private(set) var state: GameState = .exploration
    private(set) var phase: GamePhase = .wake {
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

    private weak var scene: SKScene?
    private var resonanceTotal = 0
    private var lastCombatStarter: (() -> Void)?   // pour le bouton Réessayer

    /// Lyra combat aux côtés de Kael dans les zones du pacte (tant qu'elle vit).
    private var lyraInParty: Bool {
        [.forest, .shrine, .ruins].contains(phase) && !player.lyraDeceased
    }

    /// Trio de l'Acte III : l'Écho de Lyra puis Eran rejoignent Kael.
    private var act3Party: [CombatAllyKind] {
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
    private var padActive = false
    private var padOrigin = CGPoint.zero
    private var padVector = CGVector.zero
    private var hintUpdateTimer: TimeInterval = 0
    private var minimapTimer: TimeInterval = 0
    private var corruptionCinematicShown = false
    private var activeInterior: HouseInteriorKind?
    /// Vrai quand Kael est dans les mines de Cendreval (excursion depuis
    /// la forêt — pas une GamePhase : la save garde phase = .forest).
    private var inMines = false
    /// Vrai quand Kael est dans le désert d'Ossara (voyage via la carte
    /// du monde — pas une GamePhase : la save garde la phase d'origine).
    private var inDesert = false

    // MARK: - Setup

    func setup(scene: SKScene, slot: Int = 1) {
        self.scene = scene
        self.activeSlot = slot
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
                self.world.switchToForest(in: scene)
                self.startGroveCombat()
            }
            return
        }
        if CommandLine.arguments.contains("--combat-multi") {
            hud.goldValue = player.gold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.phase = .forest
                self.world.switchToForest(in: scene)
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
            world.switchToForest(in: scene)
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
    private func grantLevelUpDisplay(from levelBefore: Int) {
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

    /// Bouton pixel fixe en bas à droite. Actif (doré, pulsé) quand une
    /// interaction est à portée ; estompé sinon.
    private func setupActionButton(in scene: SKScene) {
        PixelUI.stylePanel(actionButton, size: CGSize(width: 54, height: 54),
                           fill: SKColor(red: 0.10, green: 0.07, blue: 0.14, alpha: 0.88),
                           accent: PixelUI.gold)
        actionButton.position = CGPoint(x: scene.size.width - 58, y: 66)
        actionButton.zPosition = 1_950   // au-dessus des panneaux (dialogue 1000+)
        actionButton.isHidden = true
        scene.addChild(actionButton)

        actionButtonLabel.text = "A"
        actionButtonLabel.fontSize = 32
        actionButtonLabel.fontColor = PixelUI.gold
        actionButtonLabel.verticalAlignmentMode = .center
        actionButtonLabel.horizontalAlignmentMode = .center
        actionButtonLabel.position = CGPoint(x: 0, y: -1)
        actionButtonLabel.zPosition = 951
        actionButton.addChild(actionButtonLabel)

        // Bouton B : en dessous-gauche de A, accent cuivré (annuler/passer)
        let bAccent = SKColor(red: 0.80, green: 0.42, blue: 0.30, alpha: 1)
        PixelUI.stylePanel(bButton, size: CGSize(width: 46, height: 46),
                           fill: SKColor(red: 0.13, green: 0.07, blue: 0.08, alpha: 0.88),
                           accent: bAccent)
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
                world.switchToForest(in: scene)
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

    private func openBramShop() {
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

    private func openMaraInteraction(scene: SKScene) {
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
    private func pickupMedallion() {
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
    private func pickupOre() {
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
    private func pickupHerb() {
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
    private func pickupScoutBadge() {
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

    // MARK: - Forest Interactions

    private func tryForestInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        // Trek scrollable : les POI vivent en coordonnées MONDE
        // (fractions de worldHeight, synchronisées avec buildForest).
        let w = scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height

        // Zone 1 : Bosquet corrompu (ouest) — combat bête
        if player.forestProgress < 1 {
            let groveCenter = CGPoint(x: w * 0.30, y: h * 0.31)
            if point.distance(to: groveCenter) < 80 {
                startGroveCombat()
                return true
            }
        }

        // Zone 2 : Clairière sombre (est) — combat loups
        if player.forestProgress >= 1 && player.forestProgress < 2 {
            let clearingCenter = CGPoint(x: w * 0.70, y: h * 0.66)
            if point.distance(to: clearingCenter) < 80 {
                startClearingCombat()
                return true
            }
        }

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

        // Chasses optionnelles (répétables — XP/or, ennemis coriaces)
        let ghoulDen = CGPoint(x: w * 0.20, y: h * 0.585)
        if point.distance(to: ghoulDen) < 75 {
            startGhoulCombat()
            return true
        }
        let boneTrail = CGPoint(x: w * 0.82, y: h * 0.74)
        if point.distance(to: boneTrail) < 75 {
            startBoneCombat()
            return true
        }

        return false
    }

    /// Chasse optionnelle : nid de goules (2 ennemis coriaces).
    private func startGhoulCombat() {
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
            transition(to: .exploration)
        }
    }

    /// Chasse optionnelle : squelette errant escorté d'une goule.
    private func startBoneCombat() {
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
            transition(to: .exploration)
        }
    }

    /// Ramasser le jouet perdu de l'enfant
    private func pickupToy() {
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
    private func startGroveCombat() {
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
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.forestGroveDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Combat 2 : Loups d'ombre dans la clairière
    private func startClearingCombat() {
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
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.blackAetherDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Transition vers sanctuaire
    private func enterShrine() {
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

    private func startBossFight() {
        guard scene != nil else { return }
        guard !player.bossDefeated else {
            // Boss already dead → go straight to shrine ending
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.shrineEnding) { [weak self] in
                guard let self, let scene = self.scene else { return }
                phase = .complete
                hud.objectiveText = String(localized: "hud.objective.complete")
                transition(to: .exploration)
                TransitionManager.showEndScreen(in: scene, resonance: resonanceTotal)
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
                            self?.beginAct2()
                        }
                    }
                }
            }
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

    private func innItems() -> [ShopItem] {
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

    // MARK: - Act 2 Flow

    private func beginAct2() {
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

    private func tryAct2VillageInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
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

    private func openAct2LyraDialogue() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act2LyraAnalysisDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// L'enfant a peur de Kael maintenant — la corruption se voit.
    private func openAct2ChildDialogue() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.childAct2Dialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// La villageoise avertit Kael : ne pas écouter la Voix.
    private func openAct2VillagerDialogue() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.villagerAct2Dialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Dorin garde la porte nord (Garen retiré Acte II) :
    /// 1) bloque si !act2DorinPassed
    /// 2) ouvre les ruines si Sage consulté
    /// 3) sinon doute (Dorin attend que Kael consulte le Sage)
    private func handleAct2Dorin(scene: SKScene) {
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
    private func handleAct2Sage(scene: SKScene) {
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

    private func openNightmareSequence(scene: SKScene) {
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

    private func openDorinBlock(scene: SKScene) {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act2DorinBlockDialogue) { [weak self] in
            guard let self else { return }
            player.act2DorinPassed = true
            transition(to: .exploration)
        }
    }

    private func enterRuins() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            phase = .ruins
            hud.objectiveText = String(localized: "hud.objective.ruins")
            world.switchToRuins(in: scene)
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

    private func tryRuinsInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width
        let h = scene.size.height

        // Zone 1 : Gardiens des Ruines (centre-gauche)
        if player.ruinsProgress < 1 {
            if point.distance(to: CGPoint(x: w * 0.28, y: h * 0.50)) < 75 {
                startRuinsCombat1()
                return true
            }
        }

        // Zone 2 : Archiviste mini-boss (centre-droite)
        if player.ruinsProgress == 1 {
            if point.distance(to: CGPoint(x: w * 0.62, y: h * 0.60)) < 75 {
                startRuinsCombat2()
                return true
            }
        }

        // Inscription d'Eran (bas-gauche) — accessible dès l'entrée
        if !player.act2EranFound {
            if point.distance(to: CGPoint(x: w * 0.15, y: h * 0.65)) < 60 {
                openEranInscription()
                return true
            }
        }

        // Inscription principale (discovery) — débloquée après les 2 combats
        if player.ruinsProgress >= 2 {
            if point.distance(to: CGPoint(x: w * 0.70, y: h * 0.65)) < 70 {
                openDiscovery()
                return true
            }
        }

        return false
    }

    private func openEranInscription() {
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

    private func startRuinsCombat1() {
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
                self?.transition(to: .exploration)
            }
        }
    }

    private func startRuinsCombat2() {
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

    private func openDiscovery() {
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

    private func triggerLyraDeath() {
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
                        TransitionManager.showAct2EndScreen(in: scene)
                        // Propose credits then Act III prologue
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
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

    private func showDeathScreen() {
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
    private func nearestInteraction(from origin: CGPoint,
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

    // MARK: - Acte III étendu (écho, esprits, stèles, ombres)

    /// L'Écho de Lyra rejoint Kael — première scène du Seuil.
    private func openAct3EchoMeet() {
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
    private func openSpiritDialogue(id: String) {
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
    private func openSteleDialogue(id: String) {
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
    private func startVoidShadesCombat() {
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
    private func refreshThresholdBackdrop() {
        guard let scene, phase == .act3 else { return }
        let kaelPos = world.kael.position
        world.switchToThreshold(in: scene,
                                echoJoined: player.act3EchoJoined,
                                spiritsCalmed: player.act3SpiritsCalmed,
                                shadesDefeated: player.act3ShadesDefeated)
        world.kael.position = kaelPos
    }

    private func beginAct3() {
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
    private func openAct3EranMeet() {
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
    private func startThresholdBoss() {
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
    private func showAct3TrueEnding() {
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
    private func showAct3CrossEnding() {
        dialogue.start(PrototypeContent.act3TrueEndingDialogue) { [weak self] in
            guard let self else { return }
            // « Ce n'était que le début » — la Voix annonce l'Acte IV.
            dialogue.start(PrototypeContent.act3EndPlaceholder) { [weak self] in
                self?.beginAct4()
            }
        }
    }

    /// Fin "Résister / refuser le Vide" — Kael tourne le dos au Seuil.
    private func showAct3ResistEnding() {
        dialogue.start(PrototypeContent.act3ResistEndingDialogue) { [weak self] in
            guard let self else { return }
            dialogue.start(PrototypeContent.act3ResistEndPlaceholder) { [weak self] in
                self?.rollCreditsToMenu()
            }
        }
    }

    private func rollCreditsToMenu() {
        guard let scene else { return }
        transition(to: .exploration)
        TransitionManager.showCredits(in: scene) { [weak self] in
            self?.onReturnToMenu?()
        }
    }

    // MARK: - Act IV — Le Cœur du Vide

    /// Kael, l'Écho et Eran franchissent le Seuil : entrée dans l'Acte IV.
    private func beginAct4() {
        guard let scene else { return }
        GameCenterManager.shared.report(.act4Reached)
        AudioEngine.shared.setMood(.voidThreshold)
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            phase = .act4
            player.loreDiscovered.insert("voidheart")
            hud.objectiveText = String(localized: "hud.objective.act4")
            world.switchToVoidHeart(in: scene,
                                    echoJoined: player.act3EchoJoined,
                                    reflectionsFreed: player.act4ReflectionsFreed,
                                    devourersDefeated: player.act4DevourersDefeated,
                                    bossDefeated: player.act4BossDefeated)
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
    private func tryAct4Interaction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width, h = scene.size.height
        let heart = CGPoint(x: w * 0.50, y: h * 0.80)

        // Fragments de mémoire (quête « Les souvenirs de Kael »)
        let memories: [(id: String, x: CGFloat, y: CGFloat)] = [
            ("1", 0.20, 0.46), ("2", 0.62, 0.30), ("3", 0.80, 0.52)
        ]
        for memory in memories where !player.act4MemoriesSeen.contains(memory.id) {
            if point.distance(to: CGPoint(x: w * memory.x, y: h * memory.y)) < 55 {
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

        // Dévoreurs d'échos — combat annexe du trio
        if !player.act4DevourersDefeated,
           point.distance(to: CGPoint(x: w * 0.80, y: h * 0.66)) < 75 {
            startDevourersCombat()
            return true
        }

        // 1) Confrontation de la Voix (le choix final est capturé ici)
        if !player.act4VoiceConfronted {
            if point.distance(to: CGPoint(x: w * 0.50, y: h * 0.58)) < 80 {
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
    private func openAct4Memory(id: String) {
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
    private func openAct4Reflection(id: String) {
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
    private func startDevourersCombat() {
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
    private func refreshVoidHeartBackdrop() {
        guard let scene, phase == .act4 else { return }
        let kaelPos = world.kael.position
        world.switchToVoidHeart(in: scene,
                                echoJoined: player.act3EchoJoined,
                                reflectionsFreed: player.act4ReflectionsFreed,
                                devourersDefeated: player.act4DevourersDefeated,
                                bossDefeated: player.act4BossDefeated)
        world.kael.position = kaelPos
    }

    /// Confrontation de la Voix — capture le choix final de Kael :
    /// 0 = détruire le Cœur, 1 = fusionner avec le Cœur.
    private func openAct4VoiceConfront() {
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
    private func startVoidAvatarBoss() {
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
    private func showAct4Ending() {
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
    private func showAct4DestroyEnding() {
        dialogue.start(PrototypeContent.act4DestroyEndingDialogue) { [weak self] in
            guard let self else { return }
            dialogue.start(PrototypeContent.act4DestroyEndScreen) { [weak self] in
                self?.rollCreditsToMenu()
            }
        }
    }

    /// Fin « Fusionner avec le Cœur » — Kael devient le nouveau gardien.
    private func showAct4MergeEnding() {
        dialogue.start(PrototypeContent.act4MergeEndingDialogue) { [weak self] in
            guard let self else { return }
            dialogue.start(PrototypeContent.act4MergeEndScreen) { [weak self] in
                self?.rollCreditsToMenu()
            }
        }
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

    private func transition(to newState: GameState) {
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
    private func addSideQuestMarkers(in scene: SKScene) {
        if player.questBramOre == .active    { world.addOreMarker(in: scene) }
        if player.questSageHerb == .active   { world.addHerbMarker(in: scene) }
        if player.questGarenScout == .active { world.addBadgeMarker(in: scene) }
        world.addMineEntrance(in: scene)
    }

    // MARK: - Mines de Cendreval

    /// Descente dans les mines : zone plein écran, Lyra reste à l'entrée.
    private func enterMines() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inMines = true
            hud.objectiveText = String(localized: "hud.objective.mines")
            AudioEngine.shared.setMood(.mines)
            world.switchToMines(in: scene, progress: player.minesProgress,
                                goldTaken: player.minesGoldTaken)
            world.kael.position = CGPoint(x: scene.size.width * 0.50,
                                          y: scene.size.height * 0.14)
        } completion: { [weak self] in
            guard let self else { return }
            if player.questMines == .inactive {
                player.questMines = .active
                hud.questText = String(localized: "quest.mines.hud")
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.minesEnterDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            } else {
                transition(to: .exploration)
            }
        }
    }

    /// Remonte à la forêt, respawn devant la galerie.
    private func exitMines() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inMines = false
            hud.objectiveText = String(localized: "hud.objective.forest")
            AudioEngine.shared.setMood(.forPhase(phase))
            world.switchToForest(in: scene)
        } completion: { [weak self] in
            guard let self, let scene = self.scene else { return }
            if player.questChildToy == .active { world.addToyMarker(in: scene) }
            if player.questMedallion == .active { world.addMedallionMarker(in: scene) }
            addSideQuestMarkers(in: scene)
            let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            world.kael.position = CGPoint(x: scene.size.width * 0.80, y: wh * 0.28)
            transition(to: .exploration)
        }
    }

    private func tryMinesInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width
        let h = scene.size.height

        // Sortie (halo sud)
        if point.distance(to: CGPoint(x: w * 0.50, y: h * 0.08)) < 60 {
            exitMines()
            return true
        }

        // Zone 1 : mineurs cendreux
        if player.minesProgress < 1,
           point.distance(to: CGPoint(x: w * 0.30, y: h * 0.48)) < 75 {
            startMinesCombat1()
            return true
        }

        // Zone 2 : spectres des galeries (après les mineurs)
        if player.minesProgress == 1,
           point.distance(to: CGPoint(x: w * 0.46, y: h * 0.64)) < 75 {
            startMinesCombat2()
            return true
        }

        // Zone 3 : golem de cendre (fond de galerie).
        // Garde questMines : les anciennes sauvegardes avaient progress==2
        // pour « golem vaincu » — pas de re-fight.
        if player.minesProgress == 2, player.questMines != .complete,
           point.distance(to: CGPoint(x: w * 0.62, y: h * 0.68)) < 75 {
            startMinesBossSequence()
            return true
        }

        // Plaque des mineurs : lore de Cendreval
        if point.distance(to: CGPoint(x: w * 0.18, y: h * 0.68)) < 60 {
            openMinesInscription()
            return true
        }

        // Veine d'or (une seule fois)
        if !player.minesGoldTaken,
           point.distance(to: CGPoint(x: w * 0.80, y: h * 0.40)) < 60 {
            pickupGoldVein()
            return true
        }

        return false
    }

    /// Combat 1 : deux mineurs cendreux (goules recouvertes de cendre).
    private func startMinesCombat1() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startMinesCombat1() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let name = String(localized: "combat.enemy.ashMiner")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                          hp: 230, kind: .ghoul, baseDamage: 36),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                          hp: 230, kind: .ghoul, baseDamage: 36)
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
            player.minesProgress = 1
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.mines")
            refreshMinesBackdrop()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.minesCombat1PostDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Combat 2 : les spectres des galeries — trois morts qui creusent encore.
    private func startMinesCombat2() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startMinesCombat2() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let wraith = String(localized: "combat.enemy.ashWraith")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(wraith) \(1)"),
                          hp: 250, kind: .boneWalker, baseDamage: 38),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(wraith) \(2)"),
                          hp: 250, kind: .boneWalker, baseDamage: 38),
                EnemySpec(name: String(localized: "combat.enemy.ashMiner"),
                          hp: 210, kind: .ghoul, baseDamage: 34)
            ],
            goldReward: 70,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.minesProgress = 2
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.mines")
            refreshMinesBackdrop()
            transition(to: .exploration)
        }
    }

    /// Reconstruit le décor des mines après un combat (les monstres
    /// vaincus disparaissent, la zone suivante s'allume).
    private func refreshMinesBackdrop() {
        guard let scene, inMines else { return }
        let kaelPos = world.kael.position
        world.switchToMines(in: scene, progress: player.minesProgress,
                            goldTaken: player.minesGoldTaken)
        world.kael.position = kaelPos
    }

    /// Boss des mines : dialogue d'approche puis golem de cendre.
    private func startMinesBossSequence() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.minesBossPreDialogue) { [weak self] in
            self?.startMinesBossCombat()
        }
    }

    private func startMinesBossCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startMinesBossCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.ashGolem"),
                          hp: 560, kind: .ruinsGuardian, baseDamage: 48)
            ],
            goldReward: 150,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.minesProgress = 3
            player.questMines = .complete
            syncGold()
            hud.questText = ""
            AudioEngine.shared.playQuestComplete()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.mines")
            refreshMinesBackdrop()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.minesBossPostDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Plaque des mineurs : débloque l'entrée de lore « cendreval ».
    private func openMinesInscription() {
        guard let scene else { return }
        transition(to: .dialogue)
        JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                 color: SKColor(red: 0.55, green: 0.42, blue: 0.20, alpha: 1),
                                 duration: 0.3)
        player.loreDiscovered.insert("cendreval")
        dialogue.start(PrototypeContent.minesInscriptionDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Veine d'or : +80 or, une seule fois.
    private func pickupGoldVein() {
        guard let scene else { return }
        player.minesGoldTaken = true
        player.gold += 80
        syncGold()
        AudioEngine.shared.playGoldGain()
        world.removeGoldVein()
        let spot = CGPoint(x: scene.size.width * 0.80, y: scene.size.height * 0.40)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 1), count: 14))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.minesGoldDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    private func syncGold() {
        hud.goldValue = player.gold
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

    // MARK: - Désert d'Ossara

    /// Voyage vers les dunes : Kael quitte sa zone, le désert se charge.
    private func enterDesert() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inDesert = true
            hud.objectiveText = String(localized: "hud.objective.desert")
            AudioEngine.shared.setMood(.tense)
            world.switchToDesert(in: scene, progress: player.desertProgress,
                                 chestTaken: player.desertChestTaken)
            world.kael.position = CGPoint(x: scene.size.width * 0.50,
                                          y: scene.size.height * 0.14)
        } completion: { [weak self] in
            guard let self else { return }
            if player.questDesert == .inactive {
                player.questDesert = .active
                hud.questText = String(localized: "quest.desert.hud")
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.desertEnterDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            } else if player.desertProgress >= 1, player.questDesert == .active,
                      Int.random(in: 0..<100) < 30 {
                // Rencontre aléatoire en chemin : les dunes ne pardonnent pas.
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.desertAmbushDialogue) { [weak self] in
                    self?.startDesertAmbush()
                }
            } else {
                transition(to: .exploration)
            }
        }
    }

    /// Retour vers la zone d'origine (la phase n'a pas changé).
    private func exitDesert() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inDesert = false
            AudioEngine.shared.setMood(.forPhase(phase))
            switch phase {
            case .forest:
                hud.objectiveText = String(localized: "hud.objective.forest")
                world.switchToForest(in: scene)
            case .act2:
                hud.objectiveText = String(localized: "hud.objective.act2")
                world.switchToVillage(in: scene)
                world.repositionDorinToGate(in: scene)
                world.applyKaelCorruption(level: player.kaelCorruptionLevel)
            default:
                hud.objectiveText = String(localized: "hud.objective.complete")
                world.switchToVillage(in: scene)
            }
        } completion: { [weak self] in
            guard let self, let scene = self.scene else { return }
            let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            if phase == .forest {
                if player.questChildToy == .active { world.addToyMarker(in: scene) }
                if player.questMedallion == .active { world.addMedallionMarker(in: scene) }
                addSideQuestMarkers(in: scene)
                world.kael.position = CGPoint(x: scene.size.width * 0.5, y: wh * 0.05)
            } else {
                world.kael.position = CGPoint(x: scene.size.width * 0.5, y: wh * 0.12)
            }
            transition(to: .exploration)
        }
    }

    private func tryDesertInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width
        let h = scene.size.height

        // Sortie (halo sud) : retour vers la zone d'origine
        if point.distance(to: CGPoint(x: w * 0.50, y: h * 0.08)) < 60 {
            exitDesert()
            return true
        }

        // Zone 1 : pillards des dunes
        if player.desertProgress < 1,
           point.distance(to: CGPoint(x: w * 0.28, y: h * 0.55)) < 75 {
            startDesertCombat1()
            return true
        }

        // Zone 2 : charognards (après les pillards)
        if player.desertProgress == 1,
           point.distance(to: CGPoint(x: w * 0.55, y: h * 0.68)) < 75 {
            startDesertCombat2()
            return true
        }

        // Zone 3 : le colosse des sables
        if player.desertProgress == 2, player.questDesert != .complete,
           point.distance(to: CGPoint(x: w * 0.80, y: h * 0.55)) < 75 {
            startDesertBossSequence()
            return true
        }

        // Coffre enfoui (une seule fois)
        if !player.desertChestTaken,
           point.distance(to: CGPoint(x: w * 0.12, y: h * 0.56)) < 60 {
            pickupBuriedChest()
            return true
        }

        // Oasis : restaure tous les PV, une fois par visite
        if !player.desertOasisUsed,
           point.distance(to: CGPoint(x: w * 0.85, y: h * 0.20)) < 60 {
            drinkAtOasis()
            return true
        }

        return false
    }

    /// Combat 1 : deux pillards des dunes — les détrousseurs de caravanes.
    private func startDesertCombat1() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertCombat1() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let name = String(localized: "combat.enemy.dunePillager")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                          hp: 260, kind: .ghoul, baseDamage: 40),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                          hp: 260, kind: .ghoul, baseDamage: 40)
            ],
            goldReward: 60,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.desertProgress = 1
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.desert")
            refreshDesertBackdrop()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.desertCombat1PostDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Combat 2 : les charognards d'Ossara — ceux qui suivent les pillards.
    private func startDesertCombat2() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertCombat2() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let scavenger = String(localized: "combat.enemy.scavenger")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(scavenger) \(1)"),
                          hp: 240, kind: .boneWalker, baseDamage: 38),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(scavenger) \(2)"),
                          hp: 240, kind: .boneWalker, baseDamage: 38),
                EnemySpec(name: String(localized: "combat.enemy.dunePillager"),
                          hp: 220, kind: .ghoul, baseDamage: 36)
            ],
            goldReward: 80,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.desertProgress = 2
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.desert")
            refreshDesertBackdrop()
            transition(to: .exploration)
        }
    }

    /// Boss du désert : dialogue d'approche puis le colosse des sables.
    private func startDesertBossSequence() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.desertBossPreDialogue) { [weak self] in
            self?.startDesertBossCombat()
        }
    }

    private func startDesertBossCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertBossCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.sandColossus"),
                          hp: 640, kind: .ruinsGuardian, baseDamage: 52)
            ],
            goldReward: 180,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.desertProgress = 3
            player.questDesert = .complete
            syncGold()
            hud.questText = ""
            AudioEngine.shared.playQuestComplete()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.desert")
            refreshDesertBackdrop()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.desertBossPostDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Embuscade de voyage : deux pillards surgissent des dunes.
    private func startDesertAmbush() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertAmbush() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let name = String(localized: "combat.enemy.dunePillager")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                          hp: 220, kind: .ghoul, baseDamage: 36),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                          hp: 220, kind: .ghoul, baseDamage: 36)
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
            hud.objectiveText = String(localized: "hud.objective.desert")
            transition(to: .exploration)
        }
    }

    /// Reconstruit le décor du désert après un combat (les monstres
    /// vaincus disparaissent, la zone suivante s'allume).
    private func refreshDesertBackdrop() {
        guard let scene, inDesert else { return }
        let kaelPos = world.kael.position
        world.switchToDesert(in: scene, progress: player.desertProgress,
                             chestTaken: player.desertChestTaken)
        world.kael.position = kaelPos
    }

    /// Coffre enfoui : +120 or, une seule fois.
    private func pickupBuriedChest() {
        guard let scene else { return }
        player.desertChestTaken = true
        player.gold += 120
        syncGold()
        AudioEngine.shared.playGoldGain()
        world.removeBuriedChest()
        let spot = CGPoint(x: scene.size.width * 0.12, y: scene.size.height * 0.56)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 1), count: 14))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.desertChestDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Oasis : restaure tous les PV, une fois par visite.
    private func drinkAtOasis() {
        guard let scene else { return }
        player.desertOasisUsed = true
        player.currentHP = player.currentMaxHP
        HapticsEngine.medium()
        JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                 color: SKColor(red: 0.30, green: 0.75, blue: 0.85, alpha: 1),
                                 duration: 0.25)
        let spot = CGPoint(x: scene.size.width * 0.85, y: scene.size.height * 0.20)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.55, green: 0.90, blue: 1.0, alpha: 1), count: 12))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.desertOasisDialogue) { [weak self] in
            self?.transition(to: .exploration)
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
            world.switchToForest(in: scene)
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
            hud.objectiveText = String(localized: "hud.objective.complete")
            transition(to: .exploration)

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
            TransitionManager.showAct2EndScreen(in: scene)

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
