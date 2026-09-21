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
}
