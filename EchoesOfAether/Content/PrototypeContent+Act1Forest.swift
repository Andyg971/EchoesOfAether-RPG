import Foundation

// Acte I — forêt d'Ébène et Gardien fêlé.
// Extrait de PrototypeContent.swift (découpage du monolithe).
extension PrototypeContent {
    // MARK: - Forêt — après combat bosquet

    static let forestGroveDialogue: [DialogueStep] = [
        // Les murmures éteints (scène ACT2_SC4 du scénario)
        .line(speaker: "Lyra", text: String(localized: "dialogue.forest.real.1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.forest.real.2")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.forest.real.3")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.forest.real.4")),
        .line(speaker: "Kael", text: String(localized: "dialogue.forest.real.5")),
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

    // MARK: - Boss — Gardien de l'Aether (pré-combat)

    static let bossPreDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.boss.guardianName"),
              text: String(localized: "dialogue.boss.pre1")),
        .line(speaker: String(localized: "dialogue.boss.guardianName"),
              text: String(localized: "dialogue.boss.pre2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.boss.kael1")),
        .choice(
            prompt: String(localized: "dialogue.boss.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.boss.choice1"),
                    responseSpeaker: String(localized: "dialogue.boss.guardianName"),
                    response: String(localized: "dialogue.boss.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.boss.choice2"),
                    responseSpeaker: String(localized: "dialogue.boss.guardianName"),
                    response: String(localized: "dialogue.boss.response2")
                )
            ]
        )
    ]

    // MARK: - Boss — Post-combat (victoire)

    static let bossPostDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.boss.post.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.boss.post.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.boss.post.lyra2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.boss.post.kael2"))
    ]
}
