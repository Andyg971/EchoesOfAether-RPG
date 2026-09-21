import SpriteKit

// Dialogues du village — Sage, enfant, villageoise (l'auberge et ses abords).
extension GameManager {

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
}
