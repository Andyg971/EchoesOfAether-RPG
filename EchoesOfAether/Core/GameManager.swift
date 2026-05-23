import SpriteKit

@MainActor
final class GameManager {
    private(set) var state: GameState = .exploration
    private(set) var phase: GamePhase = .wake

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
    let minimap   = MinimapOverlay()
    let player    = PlayerState()

    var onReturnToMenu: (() -> Void)?

    private weak var scene: SKScene?
    private var resonanceTotal = 0
    private var lastCombatStarter: (() -> Void)?   // pour le bouton Réessayer
    private var hintUpdateTimer: TimeInterval = 0
    private var minimapTimer: TimeInterval = 0
    private var corruptionCinematicShown = false

    // MARK: - Setup

    func setup(scene: SKScene) {
        self.scene = scene
        world.build(in: scene)
        hud.attach(to: scene)
        dialogue.attach(to: scene)
        shop.attach(to: scene)
        inventory.attach(to: scene)
        pause.attach(to: scene)
        death.attach(to: scene)
        options.attach(to: scene)
        lore.attach(to: scene)
        minimap.attach(to: scene)

        hud.onInventoryTap = { [weak self] in self?.openInventory() }
        hud.onPauseTap     = { [weak self] in self?.openPause() }

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
            SaveManager.deleteSave()
            self?.closeOptions()
            self?.onReturnToMenu?()
        }
        options.onVolumeChange = { volume in
            AudioEngine.shared.masterVolume = volume
        }

        death.onRetry           = { [weak self] in self?.retryLastCombat() }
        death.onReturnToCrystal = { [weak self] in
            self?.death.hide()
            self?.player.currentHP = self?.player.currentMaxHP ?? 280
            self?.onReturnToMenu?()
        }

        if let save = SaveManager.load() {
            restoreFrom(save: save, scene: scene)
        } else {
            hud.goldValue = player.gold
            startWakeSequence()
        }
    }

    func layout(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat = 0) {
        world.layout(in: size)
        hud.layout(in: size, safeTop: safeTop)
        dialogue.layout(in: size, safeBottom: safeBottom)
        shop.layout(in: size, safeBottom: safeBottom)
        inventory.layout(in: size, safeBottom: safeBottom)
        lore.layout(in: size)
        minimap.layout(in: size, safeBottom: safeBottom)
    }

    func update(deltaTime: TimeInterval) {
        combat.update(deltaTime: deltaTime)

        // HP display
        hud.hpValue = "\u{2665} \(player.currentHP)/\(player.currentMaxHP)"

        // Interaction hint — check every 0.15s
        hintUpdateTimer += deltaTime
        if hintUpdateTimer >= 0.15, state == .exploration {
            hintUpdateTimer = 0
            updateInteractionHint()
        }

        // Minimap update every 0.1s during exploration
        minimapTimer += deltaTime
        if minimapTimer >= 0.10, state == .exploration {
            minimapTimer = 0
            updateMinimap()
        }
    }

    func handleTap(at point: CGPoint, in scene: SKScene) {
        if death.handleTap(at: point, in: scene) { return }
        if options.handleTap(at: point, in: scene) { return }
        if lore.handleTap(at: point, in: scene) { return }
        if pause.handleTap(at: point, in: scene) { return }
        if TransitionManager.handleEndScreenTap(at: point, in: scene) { return }
        if TransitionManager.handleCreditsTap(at: point, in: scene) { return }
        if state == .inventory, inventory.handleTap(at: point, in: scene) { return }
        if state == .shop,      shop.handleTap(at: point, in: scene) { syncGold(); return }
        if state == .dialogue,   dialogue.handleTap(at: point, in: scene) { return }
        if state == .combat,     combat.handleTap(at: point, in: scene) { return }
        guard state == .exploration else { return }
        if hud.handleTap(at: point, in: scene) { return }
        handleExplorationTap(point, in: scene)
    }

    // MARK: - Story Flow

    private func startWakeSequence() {
        transition(to: .dialogue)
        phase = .wake
        hud.objectiveText = String(localized: "hud.objective.lyra")
        dialogue.start(PrototypeContent.wakeDialogue) { [weak self] in
            guard let self else { return }
            phase = .village
            hud.objectiveText = String(localized: "hud.objective.village")
            transition(to: .exploration)
        }
    }

    // MARK: - Exploration Tap Routing

    private func handleExplorationTap(_ point: CGPoint, in scene: SKScene) {
        // Cristal de sauvegarde — disponible dans toutes les zones jouables
        if trySaveCrystalTap(point, in: scene) { return }

        switch phase {
        case .wake:
            return

        case .village:
            if tryVillageInteraction(point, in: scene) { return }
            tapAndMove(point, in: scene)

        case .forest:
            if tryForestInteraction(point, in: scene) { return }
            tapAndMove(point, in: scene)

        case .shrine:
            if point.x > scene.size.width * 0.55 && !player.bossDefeated {
                startBossFight()
            } else {
                tapAndMove(point, in: scene)
            }

        case .complete:
            tapAndMove(point, in: scene)

        case .act2:
            if tryAct2VillageInteraction(point, in: scene) { return }
            tapAndMove(point, in: scene)

        case .ruins:
            if tryRuinsInteraction(point, in: scene) { return }
            tapAndMove(point, in: scene)

        case .fallen:
            break  // Pas d'interaction — écran de fin Act 2

        case .act3:
            if tryAct3Interaction(point, in: scene) { return }
            tapAndMove(point, in: scene)
        }
    }

    private func trySaveCrystalTap(_ point: CGPoint, in scene: SKScene) -> Bool {
        guard let crystal = scene.childNode(withName: "saveCrystal") else { return false }
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
        let radius: CGFloat = 90

        if point.distance(to: world.dorin.position) < radius {
            openDorinDialogue(scene: scene)
            return true
        }
        if point.distance(to: world.lyra.position) < radius {
            openLyraDialogue()
            return true
        }
        if point.distance(to: world.bram.position) < radius {
            openBramShop()
            return true
        }
        if point.distance(to: world.mara.position) < radius {
            openMaraInteraction(scene: scene)
            return true
        }
        if point.distance(to: world.garen.position) < radius {
            openGarenDialogue()
            return true
        }
        if point.distance(to: world.sage.position) < radius {
            openSageDialogue()
            return true
        }
        if point.distance(to: world.child.position) < radius {
            openChildDialogue()
            return true
        }
        if point.distance(to: world.villager.position) < radius {
            openVillagerDialogue()
            return true
        }
        return false
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
                world.switchToForest(in: scene)
            } completion: { [weak self] in
                guard let self else { return }
                if player.questChildToy == .active {
                    world.addToyMarker(in: scene)
                }
                transition(to: .exploration)
                movement.move(world.kael, to: CGPoint(
                    x: scene.size.width * 0.5,
                    y: scene.size.height * 0.45
                ), in: scene.size)
            }
        }
    }

    private func openBramShop() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.bramGreeting) { [weak self] in
            guard let self else { return }
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

    private func openMaraInteraction(scene: SKScene) {
        transition(to: .dialogue)
        if player.questDelivery == .complete {
            // Give colis to Garen — shouldn't reach Mara again but safe fallback
            dialogue.start(PrototypeContent.maraShopGreeting) { [weak self] in
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
            dialogue.start(PrototypeContent.garenQuestDoneDialogue) { [weak self] in
                self?.transition(to: .exploration)
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
        let content = player.innRested
            ? PrototypeContent.sageAfterRestDialogue
            : PrototypeContent.sageFirstDialogue
        dialogue.start(content) { [weak self] in
            guard let self else { return }
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
        dialogue.start(PrototypeContent.villagerDialogue) { [weak self] in
            self?.player.talkedToVillager = true
            self?.transition(to: .exploration)
        }
    }

    // MARK: - Forest Interactions

    private func tryForestInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width
        let h = scene.size.height

        // Zone 1 : Bosquet corrompu (gauche) — combat bête
        if player.forestProgress < 1 {
            let groveCenter = CGPoint(x: w * 0.30, y: h * 0.45)
            if point.distance(to: groveCenter) < 80 {
                startGroveCombat()
                return true
            }
        }

        // Zone 2 : Clairière sombre (droite) — combat loups
        if player.forestProgress >= 1 && player.forestProgress < 2 {
            let clearingCenter = CGPoint(x: w * 0.65, y: h * 0.55)
            if point.distance(to: clearingCenter) < 80 {
                startClearingCombat()
                return true
            }
        }

        // Zone 3 : Sentier profond (nord) → sanctuaire
        if player.forestProgress >= 2 {
            let deepPath = CGPoint(x: w * 0.60, y: h * 0.82)
            if point.distance(to: deepPath) < 70 {
                enterShrine()
                return true
            }
        }

        // Jouet perdu (bas-droite de la forêt)
        if player.questChildToy == .active {
            let toySpot = CGPoint(x: w * 0.80, y: h * 0.28)
            if point.distance(to: toySpot) < 60 {
                pickupToy()
                return true
            }
        }

        return false
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

        // Sparkle pickup effect
        let toySpot = CGPoint(x: scene.size.width * 0.80, y: scene.size.height * 0.28)
        scene.addChild(ParticleFactory.impactSparks(at: toySpot, color: SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), count: 12))

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
        combat.attach(
            to: scene,
            enemyName: String(localized: "combat.enemy.beast"),
            enemyHP: 150,
            goldReward: 35,
            player: player,
            enemyKind: .beast
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
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
        combat.attach(
            to: scene,
            enemyName: String(localized: "combat.enemy.wolf"),
            enemyHP: 200,
            goldReward: 50,
            player: player,
            enemyKind: .wolf
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
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
                enrageThreshold: 0.40,
                enrageSpeedMult: 1.6,
                enrageDamageMult: 2,
                specialAttackInterval: 3,
                specialDamage: 38,
                specialName: String(localized: "combat.boss.specialName")
            )

            combat.attach(
                to: scene,
                enemyName: String(localized: "combat.enemy.guardian"),
                enemyHP: 380,
                goldReward: 120,
                player: player,
                enemyKind: .guardian,
                boss: bossConfig
            ) { [weak self] resonance, gold in
                guard let self else { return }

                if resonance < 0 {
                    showDeathScreen()
                    return
                }

                // Victory
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

    private func bramItems() -> [ShopItem] {
        [
            ShopItem(
                nameKey: "shop.bram.ironBlade.name",
                descKey: "shop.bram.ironBlade.desc",
                price: 80,
                canBuy: { [weak self] _ in (self?.player.weaponLevel ?? 0) < 1 },
                onBuy: { [weak self] _ in self?.player.weaponLevel = 1 }
            ),
            ShopItem(
                nameKey: "shop.bram.runicBlade.name",
                descKey: "shop.bram.runicBlade.desc",
                price: 180,
                canBuy: { [weak self] _ in (self?.player.weaponLevel ?? 0) < 2 },
                onBuy: { [weak self] _ in self?.player.weaponLevel = 2 }
            ),
            ShopItem(
                nameKey: "shop.bram.chainMail.name",
                descKey: "shop.bram.chainMail.desc",
                price: 60,
                canBuy: { [weak self] _ in (self?.player.armorLevel ?? 0) < 1 },
                onBuy: { [weak self] _ in self?.player.armorLevel = 1 }
            ),
            ShopItem(
                nameKey: "shop.bram.reinforced.name",
                descKey: "shop.bram.reinforced.desc",
                price: 150,
                canBuy: { [weak self] _ in (self?.player.armorLevel ?? 0) < 2 },
                onBuy: { [weak self] _ in self?.player.armorLevel = 2 }
            )
        ]
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
        let radius: CGFloat = 90

        if point.distance(to: world.lyra.position) < radius {
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act2LyraAnalysisDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
            return true
        }
        // Dorin garde la porte nord (Garen retiré Acte II) :
        // 1) bloque si !act2DorinPassed
        // 2) ouvre les ruines si Sage consulté
        // 3) sinon doute (Dorin attend que Kael consulte le Sage)
        if point.distance(to: world.dorin.position) < radius {
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
            return true
        }
        // Sage / auberge : cauchemar d'abord si pas encore vu
        if point.distance(to: world.sage.position) < radius {
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
            return true
        }
        if point.distance(to: world.bram.position) < radius {
            openBramShop()
            return true
        }
        if point.distance(to: world.mara.position) < radius {
            openMaraInteraction(scene: scene)
            return true
        }
        return false
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
        combat.attach(
            to: scene,
            enemyName: String(localized: "combat.enemy.ruinsGuardian"),
            enemyHP: 220,
            goldReward: 30,
            player: player,
            enemyKind: .ruinsGuardian
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
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
                specialDamage: 40,
                specialName: String(localized: "combat.archivist.specialName")
            )

            combat.attach(
                to: scene,
                enemyName: String(localized: "combat.enemy.archivist"),
                enemyHP: 320,
                goldReward: 55,
                player: player,
                enemyKind: .archivist,
                boss: bossConfig
            ) { [weak self] resonance, gold in
                guard let self, let scene = self.scene else { return }
                if resonance < 0 { showDeathScreen(); return }
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
        let entries = PrototypeContent.buildLoreEntries(for: player)
        lore.open(entries: entries) { [weak self] in
            self?.transition(to: .exploration)
        }
        state = .inventory  // reuse inventory state to block exploration taps
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
            return
        }
        let kaelPos = world.kael.position
        let radius: CGFloat = 90
        var hint = ""

        switch phase {
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
            for (npc, key) in npcs where !npc.isHidden {
                if kaelPos.distance(to: npc.position) < radius {
                    hint = localizedHint(key)
                    break
                }
            }
        case .ruins:
            let w = scene.size.width, h = scene.size.height
            let checkpoints: [(CGPoint, String)] = [
                (CGPoint(x: w*0.28, y: h*0.50), "hint.fight"),
                (CGPoint(x: w*0.62, y: h*0.60), "hint.fight"),
                (CGPoint(x: w*0.15, y: h*0.65), "hint.examine"),
                (CGPoint(x: w*0.70, y: h*0.65), "hint.examine")
            ]
            for (pt, key) in checkpoints where kaelPos.distance(to: pt) < radius {
                hint = localizedHint(key)
                break
            }
        case .forest:
            let w = scene.size.width, h = scene.size.height
            let checkpoints: [(CGPoint, String)] = [
                (CGPoint(x: w*0.30, y: h*0.45), "hint.fight"),
                (CGPoint(x: w*0.65, y: h*0.55), "hint.fight"),
                (CGPoint(x: w*0.60, y: h*0.82), "hint.enter")
            ]
            for (pt, key) in checkpoints where kaelPos.distance(to: pt) < radius {
                hint = localizedHint(key)
                break
            }
        default:
            break
        }

        // Save crystal
        if hint.isEmpty, let crystal = scene.childNode(withName: "saveCrystal"),
           kaelPos.distance(to: crystal.position) < radius {
            hint = String(localized: "hint.saveCrystal")
        }

        hud.interactionHint = hint
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
        minimap.update(kaelPosition: world.kael.position,
                       sceneSize: scene.size,
                       npcs: npcs)
    }

    // MARK: - Act III

    private func tryAct3Interaction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width, h = scene.size.height
        // Eran encounter in act3 (placeholder position)
        if point.distance(to: CGPoint(x: w * 0.50, y: h * 0.65)) < 80 {
            openAct3EranMeet()
            return true
        }
        return false
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
            world.switchToRuins(in: scene)  // Reuse ruins backdrop for threshold
            world.applyKaelCorruption(level: 3)
        } completion: { [weak self] in
            guard let self else { return }
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.act3PrologueDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    private func openAct3EranMeet() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act3EranMeetDialogue) { [weak self] in
            guard let self, let scene = self.scene else { return }
            player.loreDiscovered.insert("threshold")
            transition(to: .exploration)
            // Act 3 ends in placeholder screen for now
            TransitionManager.showCredits(in: scene) { [weak self] in
                self?.onReturnToMenu?()
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

    private func tapAndMove(_ point: CGPoint, in scene: SKScene) {
        movement.move(world.kael, to: point, in: scene.size)
        scene.addChild(ParticleFactory.tapMarker(at: point))
    }

    private func transition(to newState: GameState) {
        state = newState
        if newState == .exploration { saveGame() }
    }

    private func syncGold() {
        hud.goldValue = player.gold
    }

    // MARK: - Save / Load

    func saveGame() {
        let data = player.toSaveData(phase: phase, resonance: resonanceTotal)
        SaveManager.save(data)
    }

    private func restoreFrom(save: SaveData, scene: SKScene) {
        player.load(from: save)
        resonanceTotal = save.resonanceTotal
        phase = save.phase

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
            hud.objectiveText = String(localized: "hud.objective.act3")
            world.switchToRuins(in: scene)
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
        default:             return key
        }
    }
}
