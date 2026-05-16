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
                    response: String(localized: "dialogue.wake.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.wake.choice2"),
                    response: String(localized: "dialogue.wake.response2")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.wake.choice3"),
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
                    response: String(localized: "dialogue.dorin.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.dorin.choice2"),
                    response: String(localized: "dialogue.dorin.response2")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.dorin.choice3"),
                    response: String(localized: "dialogue.dorin.response3")
                )
            ]
        ),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.dorin3")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.dorin.lyra2"))
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
                    response: String(localized: "dialogue.aether.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.aether.choice2"),
                    response: String(localized: "dialogue.aether.response2")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.aether.choice3"),
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
                    response: String(localized: "dialogue.shrine.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.shrine.choice2"),
                    response: String(localized: "dialogue.shrine.response2")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.shrine.choice3"),
                    response: String(localized: "dialogue.shrine.response3")
                )
            ]
        ),
        .line(speaker: "Lyra", text: String(localized: "dialogue.shrine.lyra2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.shrine.kael1"))
    ]
}
