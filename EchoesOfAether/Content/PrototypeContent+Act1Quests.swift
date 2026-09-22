import Foundation

// Acte I — les quêtes annexes du village : Éclats d'Aether (Lyra), jouet perdu (enfant).
extension PrototypeContent {
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
