import Foundation

enum PrototypeContent {

    // MARK: - Wake (Lyra trouve Kael inconscient)

    static let wakeDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.lyra1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.lyra2")),
        .choice(
            prompt: String(localized: "dialogue.wake.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.wake.choice1"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.wake.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.wake.choice2"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.wake.response2")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.wake.choice3"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.wake.response3")
                )
            ]
        ),
        .line(speaker: "Kael", text: String(localized: "dialogue.wake.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.lyra3")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.lyra4")),
        .line(speaker: "Kael", text: String(localized: "dialogue.wake.kael2")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.lyra5"))
    ]

    // MARK: - Lyra (village, parle à Kael)

    static let lyraVillageDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.lyra.village1")),
        .choice(
            prompt: String(localized: "dialogue.lyra.village.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.lyra.village.choice1"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.lyra.village.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.lyra.village.choice2"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.lyra.village.response2")
                )
            ]
        ),
        .line(speaker: "Lyra", text: String(localized: "dialogue.lyra.village2"))
    ]

    // MARK: - Dorin (méfiance + départ vers le nord)

    static let dorinDialogue: [DialogueStep] = [
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.dorin1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.dorin.lyra1")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.dorin2")),
        .choice(
            prompt: String(localized: "dialogue.dorin.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.dorin.choice1"),
                    responseSpeaker: "Dorin",
                    response: String(localized: "dialogue.dorin.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.dorin.choice2"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.dorin.response2")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.dorin.choice3"),
                    responseSpeaker: "Dorin",
                    response: String(localized: "dialogue.dorin.response3")
                )
            ]
        ),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.dorin3")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.dorin.lyra2"))
    ]

    // MARK: - Bram (forgeron)

    static let bramGreeting: [DialogueStep] = [
        .line(speaker: "Bram", text: String(localized: "dialogue.bram.bram1")),
        .line(speaker: "Bram", text: String(localized: "dialogue.bram.bram2")),
        .choice(
            prompt: String(localized: "dialogue.bram.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.bram.choice1"),
                    responseSpeaker: "Bram",
                    response: String(localized: "dialogue.bram.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.bram.choice2"),
                    responseSpeaker: "Bram",
                    response: String(localized: "dialogue.bram.response2")
                )
            ]
        )
    ]

    // MARK: - Mara (herboriste) — première rencontre

    static let maraFirstMeetDialogue: [DialogueStep] = [
        .line(speaker: "Mara", text: String(localized: "dialogue.mara.first1")),
        .line(speaker: "Mara", text: String(localized: "dialogue.mara.first2")),
        .choice(
            prompt: String(localized: "dialogue.mara.first.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.mara.first.choice1"),
                    responseSpeaker: "Mara",
                    response: String(localized: "dialogue.mara.first.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.mara.first.choice2"),
                    responseSpeaker: "Mara",
                    response: String(localized: "dialogue.mara.first.response2")
                )
            ]
        ),
        .line(speaker: "Mara", text: String(localized: "dialogue.mara.first3"))
    ]

    static let maraQuestActiveDialogue: [DialogueStep] = [
        .line(speaker: "Mara", text: String(localized: "dialogue.mara.quest1")),
        .line(speaker: "Mara", text: String(localized: "dialogue.mara.quest2"))
    ]

    static let maraShopGreeting: [DialogueStep] = [
        .line(speaker: "Mara", text: String(localized: "dialogue.mara.shop1"))
    ]

    // MARK: - Garen (garde de la porte)

    static let garenFirstDialogue: [DialogueStep] = [
        .line(speaker: "Garen", text: String(localized: "dialogue.garen.first1")),
        .line(speaker: "Garen", text: String(localized: "dialogue.garen.first2")),
        .choice(
            prompt: String(localized: "dialogue.garen.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.garen.choice1"),
                    responseSpeaker: "Garen",
                    response: String(localized: "dialogue.garen.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.garen.choice2"),
                    responseSpeaker: "Garen",
                    response: String(localized: "dialogue.garen.response2")
                )
            ]
        )
    ]

    static let garenDeliveryDialogue: [DialogueStep] = [
        .line(speaker: "Garen", text: String(localized: "dialogue.garen.delivery1")),
        .line(speaker: "Garen", text: String(localized: "dialogue.garen.delivery2"))
    ]

    static let garenQuestDoneDialogue: [DialogueStep] = [
        .line(speaker: "Garen", text: String(localized: "dialogue.garen.done1"))
    ]

    // MARK: - Sage (aubergiste)

    static let sageFirstDialogue: [DialogueStep] = [
        .line(speaker: "Sage", text: String(localized: "dialogue.sage.first1")),
        .line(speaker: "Sage", text: String(localized: "dialogue.sage.first2")),
        .choice(
            prompt: String(localized: "dialogue.sage.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.sage.choice1"),
                    responseSpeaker: "Sage",
                    response: String(localized: "dialogue.sage.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.sage.choice2"),
                    responseSpeaker: "Sage",
                    response: String(localized: "dialogue.sage.response2")
                )
            ]
        )
    ]

    static let sageAfterRestDialogue: [DialogueStep] = [
        .line(speaker: "Sage", text: String(localized: "dialogue.sage.rest1")),
        .line(speaker: "Sage", text: String(localized: "dialogue.sage.rest2"))
    ]

    // MARK: - Enfant

    static let childDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.line1")),
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

    static let villagerDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.villager.name"), text: String(localized: "dialogue.villager.line1")),
        .choice(
            prompt: String(localized: "dialogue.villager.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.villager.choice1"),
                    responseSpeaker: String(localized: "dialogue.villager.name"),
                    response: String(localized: "dialogue.villager.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.villager.choice2"),
                    responseSpeaker: String(localized: "dialogue.villager.name"),
                    response: String(localized: "dialogue.villager.response2")
                )
            ]
        ),
        .line(speaker: String(localized: "dialogue.villager.name"), text: String(localized: "dialogue.villager.line2"))
    ]

    // MARK: - Forêt — après combat bosquet

    static let forestGroveDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.forest.grove.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.forest.grove.kael1")),
        .choice(
            prompt: String(localized: "dialogue.forest.grove.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.forest.grove.choice1"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.forest.grove.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.forest.grove.choice2"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.forest.grove.response2")
                )
            ]
        ),
        .line(speaker: "Lyra", text: String(localized: "dialogue.forest.grove.lyra2"))
    ]

    // MARK: - Forêt — avant sanctuaire

    static let forestExitDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.forest.exit.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.forest.exit.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.forest.exit.lyra2"))
    ]

    // MARK: - Post-combat forêt (découverte de l'Aether noir)

    static let blackAetherDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.aether.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.aether.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.aether.lyra2")),
        .choice(
            prompt: String(localized: "dialogue.aether.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.aether.choice1"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.aether.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.aether.choice2"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.aether.response2")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.aether.choice3"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.aether.response3")
                )
            ]
        ),
        .line(speaker: "Lyra", text: String(localized: "dialogue.aether.lyra3")),
        .line(speaker: "Kael", text: String(localized: "dialogue.aether.kael2"))
    ]

    // MARK: - Sanctuaire (Voix de l'Aether noir + fin V1)

    static let shrineEnding: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.shrine.voice1")),
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.shrine.voice2")),
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.shrine.voice3")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.shrine.lyra1")),
        .choice(
            prompt: String(localized: "dialogue.shrine.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.shrine.choice1"),
                    responseSpeaker: String(localized: "dialogue.shrine.voiceName"),
                    response: String(localized: "dialogue.shrine.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.shrine.choice2"),
                    responseSpeaker: String(localized: "dialogue.shrine.voiceName"),
                    response: String(localized: "dialogue.shrine.response2")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.shrine.choice3"),
                    responseSpeaker: String(localized: "dialogue.shrine.voiceName"),
                    response: String(localized: "dialogue.shrine.response3")
                )
            ]
        ),
        .line(speaker: "Lyra", text: String(localized: "dialogue.shrine.lyra2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.shrine.kael1"))
    ]
}
