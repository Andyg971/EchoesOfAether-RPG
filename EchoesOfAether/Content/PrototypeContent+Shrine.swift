import Foundation

// Cristal de sauvegarde et Sanctuaire (fin de l'Acte I).
// Extrait de PrototypeContent.swift (découpage du monolithe).
extension PrototypeContent {
    // MARK: - Cristal de Sauvegarde

    static let saveCrystalDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.save.speakerName"),
              text: String(localized: "dialogue.save.line1"))
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
