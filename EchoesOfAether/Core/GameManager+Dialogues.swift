import SpriteKit

// Ouverture des dialogues de PNJ et des boutiques.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - NPC Dialogue / Shop Openers


    func openLyraDialogue() {
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
            // Lyra relance tant que le cristal n'est pas ramassé. La quête ne
            // se termine plus à son comptoir contre cinq éclats achetés chez
            // Mara : elle se termine dans la forêt, en trouvant le cristal —
            // voir `pickupMotherCrystal`.
            dialogue.start(PrototypeContent.lyraQuestActiveDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }

        case .found:
            player.questLyraShards = .complete
            player.gold += 50
            syncGold()
            AudioEngine.shared.playQuestComplete()
            GameCenterManager.shared.report(.lyraQuest)
            dialogue.start(PrototypeContent.lyraQuestCompleteDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }

        case .complete:
            dialogue.start(PrototypeContent.lyraQuestDoneDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    func openDorinDialogue(scene: SKScene) {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.dorinDialogue) { [weak self] in
            guard let self else { return }
            // Dorin ouvre la porte nord : au lieu de téléporter Kael droit
            // dans la forêt, il SORT sur la carte du monde et rejoint la forêt
            // (ou tout autre lieu ouvert) à pied — cohérent avec la sortie de
            // forêt qui mène déjà à l'overworld (cf. enterShrine).
            phase = .forest
            world.endLyraVigil()
            discoveredPlaces.insert("village")
            discoveredPlaces.insert("forest")
            enterOverworld(spawnNear: "village",
                           objective: String(localized: "hud.objective.forest"))
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
    func bramGreetingContent() -> [DialogueStep] {
        if phase == .act2 {
            return player.questBramOre == .complete
                ? PrototypeContent.bramOreDoneDialogue
                : PrototypeContent.bramAct2Dialogue
        }
        switch player.questBramOre {
        case .inactive: return PrototypeContent.bramGreeting
                             + PrototypeContent.bramOreOfferDialogue
        // `.found` n'existe que pour la quête de Lyra ; ailleurs, non rendu = en cours.
        case .active, .found: return PrototypeContent.bramOreActiveDialogue
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

    func openGarenDialogue() {
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
            case .active, .found:
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

    func openSageDialogue() {
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
    func sageGreetingContent() -> [DialogueStep] {
        let base = player.innRested
            ? PrototypeContent.sageAfterRestDialogue
            : PrototypeContent.sageFirstDialogue
        // La quête ne s'offre qu'à partir de la 2e visite (et en Acte I) —
        // la première rencontre garde son rythme d'origine.
        guard player.talkedToSage, phase == .village else { return base }
        switch player.questSageHerb {
        case .inactive: return base + PrototypeContent.sageHerbOfferDialogue
        case .active, .found: return PrototypeContent.sageHerbActiveDialogue
        case .complete: return PrototypeContent.sageHerbDoneDialogue
        }
    }

    func openChildDialogue() {
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

        case .active, .found:
            dialogue.start(PrototypeContent.childQuestActiveDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }

        case .complete:
            dialogue.start(PrototypeContent.childQuestDoneDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    func openVillagerDialogue() {
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
        case .active, .found:
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
            at: spot, color: Palette.goldWorld, count: 12))
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

    /// Découverte du cristal-mère (quête de Lyra), au cœur mort de la forêt.
    ///
    /// Ne clôt pas la quête : le cristal part dans les mains de Kael, et c'est
    /// Lyra qui en tirera la chute. D'où `.found` et non `.complete`.
    func pickupMotherCrystal() {
        guard let scene else { return }
        player.questLyraShards = .found
        hud.questText = ""
        AudioEngine.shared.playQuestComplete()
        world.removeCrystalMarker()
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spot = CGPoint(x: scene.size.width * 0.78, y: wh * 0.70)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.68, green: 0.45, blue: 1.00, alpha: 1), count: 14))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.lyraCrystalFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }
}
