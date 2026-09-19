import Foundation

// Acte IV — le Cœur du Vide.
// Extrait de PrototypeContent.swift (découpage du monolithe).
extension PrototypeContent {
    // MARK: - Acte IV — Le Cœur du Vide

    /// Prologue : Kael, l'Écho et Eran émergent au-delà du Seuil.
    static let act4PrologueDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.voice1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.kael1")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act4.echo1")),
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act4.eran1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.voice2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.kael2"))
    ]

    /// Fragments de mémoire : trois souvenirs de Kael (index 1...3).
    static func act4MemoryDialogue(_ index: Int) -> [DialogueStep] {
        let key = "dialogue.act4.memory.\(index)"
        return [
            .line(speaker: String(localized: "dialogue.act4.memoryName"),
                  text: String(localized: String.LocalizationValue(key))),
            .line(speaker: "Kael",
                  text: String(localized: String.LocalizationValue(key + "Kael")))
        ]
    }

    /// Les trois souvenirs revus.
    static let act4MemoriesDoneDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act4.memoriesDone1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.memoriesDone2"))
    ]

    /// Reflets absorbés : le doyen, le forgeron, l'enfant perdu.
    static func act4ReflectionDialogue(id: String) -> [DialogueStep] {
        let base = "dialogue.act4.reflection.\(id)"
        return [
            .line(speaker: String(localized: String.LocalizationValue(base + "Name")),
                  text: String(localized: String.LocalizationValue(base + "1"))),
            .line(speaker: "Kael",
                  text: String(localized: String.LocalizationValue(base + "Kael"))),
            .line(speaker: String(localized: String.LocalizationValue(base + "Name")),
                  text: String(localized: String.LocalizationValue(base + "2")))
        ]
    }

    /// Les trois reflets libérés — récompense.
    static let act4ReflectionsDoneDialogue: [DialogueStep] = [
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act4.reflectionsDone1")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act4.reflectionsDone2"))
    ]

    /// Avant le combat annexe contre les dévoreurs d'échos.
    static let act4DevourersPreDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act4.devourers1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.devourers2"))
    ]

    /// Confrontation de la Voix — le choix final est capturé ici.
    static let act4VoiceConfrontDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.confront1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.confront2")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.confront3")),
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act4.confront4")),
        .choice(
            prompt: String(localized: "dialogue.act4.choicePrompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.act4.choice1"),
                    responseSpeaker: String(localized: "dialogue.echo.name"),
                    response: String(localized: "dialogue.act4.choiceResponse1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.act4.choice2"),
                    responseSpeaker: String(localized: "dialogue.act3.voiceName"),
                    response: String(localized: "dialogue.act4.choiceResponse2")
                )
            ]
        ),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.confront5"))
    ]

    /// Pré-combat : l'Avatar du Vide prend forme.
    static let act4AvatarPreDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.avatarPre1")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act4.avatarPre2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.avatarPre3"))
    ]

    /// Post-combat : l'Avatar se dissout, le Cœur est à nu.
    static let act4AvatarPostDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.avatarPost1")),
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act4.avatarPost2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.avatarPost3"))
    ]

    /// Réflexion avant la fin Détruire, si Kael avait SCIEMMENT saisi le
    /// pouvoir (`kaelChoseCorruption`) : briser le Cœur est son expiation —
    /// défaire de sa main ce qu'il avait choisi de prendre.
    static let act4DestroyChoseDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.act4.destroy.chose.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act4.destroy.chose.kael2"))
    ]

    /// Variante s'il avait REFUSÉ le pouvoir mais en fut dépassé : détruire le
    /// Cœur est enfin un acte à lui — reprendre la main que le Vide lui avait
    /// arrachée aux Ruines.
    static let act4DestroyResistedDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.act4.destroy.resisted.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act4.destroy.resisted.kael2"))
    ]

    /// Fin « Détruire le Cœur » — les échos sont libérés (choix : 0).
    static let act4DestroyEndingDialogue: [DialogueStep] = [
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.destroy1")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act4.destroy2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.destroy3")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act4.destroy4")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.destroy5"))
    ]

    /// Écran de fin de la branche « détruire » — chute sombre : parmi les
    /// échos libérés, Kael découvre le sien. Il est mort au sanctuaire,
    /// à l'instant du pacte.
    static let act4DestroyEndScreen: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.destroyEnd1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.destroyEnd2")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.destroyEnd3"))
    ]

    /// Réflexion jouée AVANT la fin Fusionner quand Kael a SCIEMMENT saisi le
    /// pouvoir à l'Acte II (`kaelChoseCorruption`) : fusionner n'est pas une
    /// chute mais l'aboutissement d'un choix assumé. Cf. showAct4MergeEnding.
    static let act4MergeChoseDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.act4.merge.chose.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act4.merge.chose.kael2"))
    ]

    /// Variante quand Kael avait REFUSÉ le pouvoir à l'Acte II mais fut dépassé
    /// (Lyra morte malgré lui) : accepter le Cœur devient son premier vrai
    /// choix — une reddition lucide plutôt qu'un triomphe.
    static let act4MergeResistedDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.act4.merge.resisted.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act4.merge.resisted.kael2"))
    ]

    /// Fin « Fusionner avec le Cœur » — Kael devient le nouveau gardien (choix : 1).
    static let act4MergeEndingDialogue: [DialogueStep] = [
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.merge1")),
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act4.merge2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.merge3")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act4.merge4")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act4.merge5"))
    ]

    /// Écran de fin de la branche « fusionner » — chute sombre : la Voix
    /// qui a tenté Kael au sanctuaire a toujours été la sienne. Boucle.
    static let act4MergeEndScreen: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.mergeEnd1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.mergeEnd2")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.mergeEnd3"))
    ]
}
