import Foundation

// Quêtes annexes : jouet, talisman, fer de la forge, herbe lunaire, éclaireur.
// Extrait de PrototypeContent.swift (découpage du monolithe).
extension PrototypeContent {
    // MARK: - Forêt — jouet trouvé

    static let toyFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.forest.toy.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.forest.toy.lyra1"))
    ]

    // MARK: - Enfant (dialogue original)

    static let childDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.real.1")),
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.real.2")),
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.line2")),
        .choice(
            prompt: String(localized: "dialogue.child.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.child.choice1"),
                    responseSpeaker: String(localized: "dialogue.child.name"),
                    response: String(localized: "dialogue.child.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.child.choice2"),
                    responseSpeaker: String(localized: "dialogue.child.name"),
                    response: String(localized: "dialogue.child.response2")
                )
            ]
        )
    ]

    // MARK: - Villageois apeuré

    // MARK: - Quête secondaire : le talisman du fils (villageoise)

    static let villagerQuestOfferDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.villager.name"), text: String(localized: "dialogue.oldwoman.1")),
        .line(speaker: String(localized: "dialogue.villager.name"), text: String(localized: "quest.medallion.offer1")),
        .choice(
            prompt: String(localized: "quest.medallion.offer2"),
            options: [
                DialogueChoice(
                    title: String(localized: "quest.medallion.accept"),
                    responseSpeaker: String(localized: "dialogue.villager.name"),
                    response: String(localized: "dialogue.oldwoman.2")
                ),
                DialogueChoice(
                    title: String(localized: "quest.medallion.decline"),
                    responseSpeaker: String(localized: "dialogue.villager.name"),
                    response: String(localized: "quest.medallion.offer2")
                )
            ]
        )
    ]

    static let villagerQuestActiveDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.villager.name"),
              text: String(localized: "quest.medallion.active"))
    ]

    static let villagerQuestDoneDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.villager.name"),
              text: String(localized: "quest.medallion.done1")),
        .line(speaker: String(localized: "dialogue.villager.name"),
              text: String(localized: "quest.medallion.done2"))
    ]

    static let medallionFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "quest.medallion.found"))
    ]

    // MARK: - Quête secondaire : le fer de la forge (Bram)

    static let bramOreOfferDialogue: [DialogueStep] = [
        .line(speaker: "Bram", text: String(localized: "quest.bramOre.offer1")),
        .choice(
            prompt: String(localized: "quest.bramOre.offer2"),
            options: [
                DialogueChoice(
                    title: String(localized: "quest.bramOre.accept"),
                    responseSpeaker: "Bram",
                    response: String(localized: "quest.bramOre.acceptResponse")
                ),
                DialogueChoice(
                    title: String(localized: "quest.bramOre.decline"),
                    responseSpeaker: "Bram",
                    response: String(localized: "quest.bramOre.declineResponse")
                )
            ]
        )
    ]

    static let bramOreActiveDialogue: [DialogueStep] = [
        .line(speaker: "Bram", text: String(localized: "quest.bramOre.active"))
    ]

    static let bramOreDoneDialogue: [DialogueStep] = [
        .line(speaker: "Bram", text: String(localized: "quest.bramOre.done1")),
        .line(speaker: "Bram", text: String(localized: "quest.bramOre.done2"))
    ]

    static let oreFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "quest.bramOre.found"))
    ]

    // MARK: - Quête secondaire : l'herbe lunaire (Sage)

    static let sageHerbOfferDialogue: [DialogueStep] = [
        .line(speaker: "Sage", text: String(localized: "quest.sageHerb.offer1")),
        .choice(
            prompt: String(localized: "quest.sageHerb.offer2"),
            options: [
                DialogueChoice(
                    title: String(localized: "quest.sageHerb.accept"),
                    responseSpeaker: "Sage",
                    response: String(localized: "quest.sageHerb.acceptResponse")
                ),
                DialogueChoice(
                    title: String(localized: "quest.sageHerb.decline"),
                    responseSpeaker: "Sage",
                    response: String(localized: "quest.sageHerb.declineResponse")
                )
            ]
        )
    ]

    static let sageHerbActiveDialogue: [DialogueStep] = [
        .line(speaker: "Sage", text: String(localized: "quest.sageHerb.active"))
    ]

    static let sageHerbDoneDialogue: [DialogueStep] = [
        .line(speaker: "Sage", text: String(localized: "quest.sageHerb.done1")),
        .line(speaker: "Sage", text: String(localized: "quest.sageHerb.done2"))
    ]

    static let herbFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "quest.sageHerb.found"))
    ]

    // MARK: - Quête secondaire : l'éclaireur disparu (Garen)

    static let garenScoutOfferDialogue: [DialogueStep] = [
        .line(speaker: "Garen", text: String(localized: "quest.garenScout.offer1")),
        .choice(
            prompt: String(localized: "quest.garenScout.offer2"),
            options: [
                DialogueChoice(
                    title: String(localized: "quest.garenScout.accept"),
                    responseSpeaker: "Garen",
                    response: String(localized: "quest.garenScout.acceptResponse")
                ),
                DialogueChoice(
                    title: String(localized: "quest.garenScout.decline"),
                    responseSpeaker: "Garen",
                    response: String(localized: "quest.garenScout.declineResponse")
                )
            ]
        )
    ]

    static let garenScoutActiveDialogue: [DialogueStep] = [
        .line(speaker: "Garen", text: String(localized: "quest.garenScout.active"))
    ]

    static let garenScoutDoneDialogue: [DialogueStep] = [
        .line(speaker: "Garen", text: String(localized: "quest.garenScout.done1")),
        .line(speaker: "Garen", text: String(localized: "quest.garenScout.done2"))
    ]

    static let scoutBadgeFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "quest.garenScout.found"))
    ]
}
