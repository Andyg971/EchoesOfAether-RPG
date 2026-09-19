import Foundation

// Acte I — Solis : réveil, Lyra, Dorin, Bram, Mara, Garen, Sage, quête des éclats, enfant.
// Extrait de PrototypeContent.swift (découpage du monolithe).
extension PrototypeContent {
    // MARK: - Wake (scène ACT1_SC1 du scénario — réveil chez Lyra)

    static let wakeDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.real.lyra1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.real.lyra2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.wake.real.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.wake.real.kael2")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.real.lyra3")),
        .line(speaker: "Kael", text: String(localized: "dialogue.wake.real.kael3")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.real.lyra4")),
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
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.lyra5")),
        // Monologue intérieur — Kael observe la marque (ACT1_SC1_MARK)
        .line(speaker: "Kael", text: String(localized: "dialogue.mark.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.mark.kael2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.mark.kael3"))
    ]

    // MARK: - Lyra (village, parle à Kael)

    /// Le pacte (scène ACT1_SC3 du scénario) : Lyra et Kael s'associent,
    /// chacun pour ses raisons.
    static let lyraVillageDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.pact.2")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.3")),
        .line(speaker: "Kael", text: String(localized: "dialogue.pact.4")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.5")),
        .line(speaker: "Kael", text: String(localized: "dialogue.pact.6")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.7")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.8")),
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
        .line(speaker: "Kael", text: String(localized: "dialogue.pact.9")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.10"))
    ]

    // MARK: - Dorin (méfiance + départ vers le nord)

    /// Rencontre avec Dorin (scène ACT1_SC2 du scénario) : le nord, les
    /// mines de Cendreval, la marque des Gardiens.
    static let dorinDialogue: [DialogueStep] = [
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.real.1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.dorin.real.2")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.real.3")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.real.4")),
        .line(speaker: "Kael", text: String(localized: "dialogue.dorin.real.5")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.real.6")),
        .line(speaker: "Kael", text: String(localized: "dialogue.dorin.real.7")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.real.8")),
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
        .line(speaker: "Garen", text: String(localized: "dialogue.garen.real.1")),
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

    // MARK: - Lyra — quête Éclats d'Aether

    static let lyraQuestGiveDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.lyra.quest.give1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.lyra.quest.give2")),
        .choice(
            prompt: String(localized: "dialogue.lyra.quest.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.lyra.quest.choice1"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.lyra.quest.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.lyra.quest.choice2"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.lyra.quest.response2")
                )
            ]
        )
    ]

    static let lyraQuestActiveDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.lyra.quest.active1"))
    ]

    static let lyraQuestCompleteDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.lyra.quest.complete1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.lyra.quest.complete2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.lyra.quest.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.lyra.quest.kael2"))
    ]

    /// Découverte du cristal-mère en forêt — le beat qui porte la quête.
    /// Kael parle, comme pour l'insigne de Tomm ou la croix de bois : ces
    /// trouvailles sont toujours vues à travers lui.
    static let lyraCrystalFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.lyra.crystal.found1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.lyra.crystal.found2"))
    ]

    static let lyraQuestDoneDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.lyra.quest.done1"))
    ]

    // MARK: - Enfant — quête jouet perdu

    static let childQuestDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.quest1")),
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.quest2")),
        .choice(
            prompt: String(localized: "dialogue.child.quest.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.child.quest.choice1"),
                    responseSpeaker: String(localized: "dialogue.child.name"),
                    response: String(localized: "dialogue.child.quest.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.child.quest.choice2"),
                    responseSpeaker: String(localized: "dialogue.child.name"),
                    response: String(localized: "dialogue.child.quest.response2")
                )
            ]
        )
    ]

    static let childQuestActiveDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.quest.active1"))
    ]

    static let childQuestDoneDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.quest.done1"))
    ]
}
