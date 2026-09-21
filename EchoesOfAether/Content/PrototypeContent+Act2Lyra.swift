import Foundation

// Acte II — après la Découverte : mort de Lyra, La Voix, Dorin, cauchemar, visions, Archiviste, cadeau, derniers mots.
extension PrototypeContent {
    // MARK: - Acte II — Mort de Lyra

    static let act2LyraDeathDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.death.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.death.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.death.lyra2"))
    ]

    // MARK: - Acte II — Kael seul (La Voix)

    static let act2KaelAloneDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.fallen.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.fallen.kael2")),
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.act2.fallen.voice1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.fallen.kael3"))
    ]

    /// Variante jouée quand Kael a REFUSÉ le pouvoir mais a tué Lyra malgré
    /// lui (la Tempête l'a dépassé). Il ne consent pas — il finit brisé, sans
    /// le « Oui » complice de la version où il a choisi.
    static let act2KaelAloneResistedDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.fallen.resisted.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.fallen.resisted.kael2")),
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.act2.fallen.resisted.voice1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.fallen.resisted.kael3"))
    ]

    // MARK: - Acte II — Dorin bloque la porte nord

    static let act2DorinBlockDialogue: [DialogueStep] = [
        .line(speaker: "Dorin", text: String(localized: "dialogue.act2.dorin.block1")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.act2.dorin.block2")),
        .choice(
            prompt: String(localized: "dialogue.act2.dorin.block.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.act2.dorin.block.choice1"),
                    responseSpeaker: "Dorin",
                    response: String(localized: "dialogue.act2.dorin.block.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.act2.dorin.block.choice2"),
                    responseSpeaker: "Dorin",
                    response: String(localized: "dialogue.act2.dorin.block.response2")
                )
            ]
        ),
        .line(speaker: "Dorin", text: String(localized: "dialogue.act2.dorin.block3"))
    ]

    // MARK: - Acte II — Cauchemar à l'auberge

    static let act2NightmareDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.act2.nightmare.voice1")),
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.act2.nightmare.voice2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.nightmare.kael1")),
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.act2.nightmare.voice3")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.nightmare.kael2")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.nightmare.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.nightmare.kael3"))
    ]

    // MARK: - Acte II — Vision 1 (entrée ruines, flash rouge)

    static let act2Vision1Dialogue: [DialogueStep] = [
        // Fragment de mémoire : la voix qui a scellé (ACT2_SC6_FLASH)
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.vision.eran.1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.vision.eran.2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.vision1.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.vision1.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.vision1.kael2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.vision1.kael3"))
    ]

    // MARK: - Acte II — Inscription d'Eran (secondaire, coins des ruines)

    static let act2EranInscriptionDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.eran.lyra1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.eran.lyra2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.eran.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.eran.lyra3")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.eran.kael2"))
    ]

    // MARK: - Acte II — Archiviste (pré-combat mini-boss)

    static let act2ArchivistPreDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act2.archivist.name"),
              text: String(localized: "dialogue.act2.archivist.pre1")),
        .line(speaker: String(localized: "dialogue.act2.archivist.name"),
              text: String(localized: "dialogue.act2.archivist.pre2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.archivist.kael1")),
        .line(speaker: String(localized: "dialogue.act2.archivist.name"),
              text: String(localized: "dialogue.act2.archivist.pre3"))
    ]

    // MARK: - Acte II — Archiviste (post-combat + vision 2 intégrée)

    static let act2ArchivistPostDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.archivist.post1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.archivist.post2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.archivist.post.vision")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.archivist.post3")),
        // Le lore des Gardiens (scène ACT3_SC8 du scénario, adaptée) :
        // Eran, le Premier Gardien, l'ancrage — la clé de l'acte III.
        .line(speaker: String(localized: "dialogue.act2.archivist.name"),
              text: String(localized: "dialogue.lore.arch.1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.lore.kael.1")),
        .line(speaker: String(localized: "dialogue.act2.archivist.name"),
              text: String(localized: "dialogue.lore.arch.2")),
        .line(speaker: String(localized: "dialogue.act2.archivist.name"),
              text: String(localized: "dialogue.lore.arch.3")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.lore.lyra.1")),
        .line(speaker: String(localized: "dialogue.act2.archivist.name"),
              text: String(localized: "dialogue.lore.arch.4")),
        .line(speaker: "Kael", text: String(localized: "dialogue.lore.kael.2")),
        .line(speaker: String(localized: "dialogue.act2.archivist.name"),
              text: String(localized: "dialogue.lore.arch.5")),
        .line(speaker: "Kael", text: String(localized: "dialogue.lore.kael.3"))
    ]

    // MARK: - Acte II — Cadeau de Lyra (avant l'inscription principale)

    static let act2LyraGiftDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.gift.lyra1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.gift.lyra2")),
        .choice(
            prompt: String(localized: "dialogue.act2.gift.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.act2.gift.choice1"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.act2.gift.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.act2.gift.choice2"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.act2.gift.response2")
                )
            ]
        ),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.gift.lyra3")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.gift.kael1"))
    ]

    // MARK: - Acte II — Derniers mots de Lyra (conditionnel si Eran trouvé)

    static let act2LyraEranLastWordDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.death.eran.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.death.eran.kael1"))
    ]
}
