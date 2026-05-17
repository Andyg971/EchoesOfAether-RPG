import SpriteKit

@MainActor
final class GameManager {
    private(set) var state: GameState = .exploration
    private(set) var phase: GamePhase = .wake

    let world    = WorldBuilder()
    let hud      = HUDOverlay()
    let dialogue = DialogueSystem()
    let combat   = CombatSystem()
    let movement = MovementController()
    let shop     = ShopOverlay()
    let player   = PlayerState()

    private weak var scene: SKScene?
    private var resonanceTotal = 0

    // MARK: - Setup

    func setup(scene: SKScene) {
        self.scene = scene
        world.build(in: scene)
        hud.attach(to: scene)
        dialogue.attach(to: scene)
        shop.attach(to: scene)

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
    }

    func update(deltaTime: TimeInterval) {
        combat.update(deltaTime: deltaTime)
    }

    func handleTap(at point: CGPoint, in scene: SKScene) {
        if state == .shop,    shop.handleTap(at: point, in: scene) { syncGold(); return }
        if state == .dialogue, dialogue.handleTap(at: point, in: scene) { return }
        if state == .combat,   combat.handleTap(at: point, in: scene) { return }
        guard state == .exploration else { return }
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
        dialogue.start(PrototypeContent.lyraVillageDialogue) { [weak self] in
            self?.transition(to: .exploration)
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
        dialogue.start(PrototypeContent.childDialogue) { [weak self] in
            self?.player.talkedToChild = true
            self?.transition(to: .exploration)
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

        return false
    }

    // MARK: - Forest Combat

    /// Combat 1 : Bête corrompue dans le bosquet
    private func startGroveCombat() {
        guard let scene else { return }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        combat.attach(
            to: scene,
            enemyName: String(localized: "combat.enemy.beast"),
            enemyHP: 150,
            goldReward: 35,
            player: player
        ) { [weak self] resonance, gold in
            guard let self else { return }
            resonanceTotal += resonance
            player.gold += gold
            player.forestProgress = 1
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.clearing")
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.forestGroveDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Combat 2 : Loups d'ombre dans la clairière
    private func startClearingCombat() {
        guard let scene else { return }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        combat.attach(
            to: scene,
            enemyName: String(localized: "combat.enemy.wolf"),
            enemyHP: 200,
            goldReward: 50,
            player: player
        ) { [weak self] resonance, gold in
            guard let self else { return }
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
        guard let scene else { return }
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
        guard let scene else { return }
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
                boss: bossConfig
            ) { [weak self] resonance, gold in
                guard let self else { return }

                if resonance == 0 && gold == 0 {
                    // Defeat — return to exploration, let player retry
                    hud.objectiveText = String(localized: "hud.objective.boss")
                    transition(to: .exploration)
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

                // Post-combat dialogue → shrine ending
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.bossPostDialogue) { [weak self] in
                    guard let self else { return }
                    transition(to: .dialogue)
                    dialogue.start(PrototypeContent.shrineEnding) { [weak self] in
                        guard let self, let scene = self.scene else { return }
                        phase = .complete
                        hud.objectiveText = String(localized: "hud.objective.complete")
                        transition(to: .exploration)
                        TransitionManager.showEndScreen(in: scene, resonance: resonanceTotal)
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
            transition(to: .exploration)
        case .shrine:
            hud.objectiveText = String(localized: "hud.objective.shrine")
            world.switchToShrine(in: scene)
            transition(to: .exploration)
        case .complete:
            hud.objectiveText = String(localized: "hud.objective.complete")
            transition(to: .exploration)
        }
    }
}
