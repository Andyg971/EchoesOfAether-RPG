import Foundation

// Acte II — retour à Solis, ruines de la Source, Archiviste, choix, Lyra.
// Extrait de PrototypeContent.swift (découpage du monolithe).
extension PrototypeContent {
    // MARK: - Acte II — Retour à Solis

    static let act2ReturnVillageDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.return.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.return.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.return.lyra2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.return.kael2"))
    ]

    static let act2LyraAnalysisDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.lyra.analysis1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.lyra.analysis2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.lyra.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.lyra.analysis3"))
    ]

    static let act2SageRevelationDialogue: [DialogueStep] = [
        .line(speaker: "Sage", text: String(localized: "dialogue.act2.sage.reveal1")),
        .line(speaker: "Sage", text: String(localized: "dialogue.act2.sage.reveal2")),
        .choice(
            prompt: String(localized: "dialogue.act2.sage.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.act2.sage.choice1"),
                    responseSpeaker: "Sage",
                    response: String(localized: "dialogue.act2.sage.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.act2.sage.choice2"),
                    responseSpeaker: "Sage",
                    response: String(localized: "dialogue.act2.sage.response2")
                )
            ]
        ),
        .line(speaker: "Sage", text: String(localized: "dialogue.act2.sage.reveal3"))
    ]

    // MARK: - Acte II — Dialogues ambiants du village (corruption visible)

    /// Bram, mal à l'aise face au héros aux yeux étranges.
    static let bramAct2Dialogue: [DialogueStep] = [
        .line(speaker: "Bram", text: String(localized: "dialogue.act2.bram.1")),
        .line(speaker: "Bram", text: String(localized: "dialogue.act2.bram.2"))
    ]

    /// Mara sent l'Aether noir sur Kael.
    static let maraAct2Dialogue: [DialogueStep] = [
        .line(speaker: "Mara", text: String(localized: "dialogue.act2.mara.1")),
        .line(speaker: "Mara", text: String(localized: "dialogue.act2.mara.2"))
    ]

    /// L'enfant a peur de Kael maintenant — un des beats les plus durs de l'Acte II.
    static let childAct2Dialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.child.name"),
              text: String(localized: "dialogue.act2.child.1")),
        .line(speaker: String(localized: "dialogue.child.name"),
              text: String(localized: "dialogue.act2.child.2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.child.kael1"))
    ]

    /// La villageoise, entre gratitude et méfiance. Avertit Kael de la Voix.
    static let villagerAct2Dialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.villager.name"),
              text: String(localized: "dialogue.act2.villager.1")),
        .line(speaker: String(localized: "dialogue.villager.name"),
              text: String(localized: "dialogue.act2.villager.2"))
    ]

    static let act2DorinDoubtDialogue: [DialogueStep] = [
        .line(speaker: "Dorin", text: String(localized: "dialogue.act2.dorin.doubt1")),
        .line(speaker: "Kael",  text: String(localized: "dialogue.act2.dorin.kael1")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.act2.dorin.doubt2"))
    ]

    // MARK: - Acte II — Ruines de la Source

    static let act2RuinsEnterDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.ruins.enter.lyra1")),
        // Les cristaux vidés (scène ACT2_SC6 du scénario)
        .line(speaker: "Lyra", text: String(localized: "dialogue.ruins.real.1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.ruins.enter.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.ruins.enter.lyra2"))
    ]

    static let act2RuinsCombat1Dialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.ruins.combat1.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.ruins.combat1.kael1"))
    ]

    // MARK: - Acte II — Découverte & Confrontation

    static let act2DiscoveryDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.discovery.lyra1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.discovery.lyra2")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.discovery.lyra3")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.discovery.kael1")),
        .choice(
            prompt: String(localized: "dialogue.act2.discovery.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.act2.discovery.choice1"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.act2.discovery.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.act2.discovery.choice2"),
                    responseSpeaker: "Lyra",
                    response: String(localized: "dialogue.act2.discovery.response2")
                )
            ]
        ),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.discovery.lyra4")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.discovery.kael2"))
    ]

    // MARK: - Acte II — Le choix : saisir le pouvoir ou le refuser

    /// La Voix offre à Kael le dernier pas, juste avant que Lyra ne parte
    /// prévenir Solis. Les DEUX options mènent à sa mort (la Tempête éclate
    /// quoi qu'il arrive) — mais l'index 0 rend Kael COMPLICE, l'index 1 le
    /// laisse dépassé par son propre pouvoir. Cf. playCorruptionChoiceThenDeath.
    static let act2CorruptionChoiceDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.act2.corruptChoice.voice1")),
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.act2.corruptChoice.voice2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.corruptChoice.kael1")),
        .line(speaker: String(localized: "dialogue.shrine.voiceName"),
              text: String(localized: "dialogue.act2.corruptChoice.voice3")),
        .choice(
            prompt: String(localized: "dialogue.act2.corruptChoice.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.act2.corruptChoice.take"),
                    responseSpeaker: "Kael",
                    response: String(localized: "dialogue.act2.corruptChoice.takeResponse")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.act2.corruptChoice.refuse"),
                    responseSpeaker: "Kael",
                    response: String(localized: "dialogue.act2.corruptChoice.refuseResponse")
                )
            ]
        )
    ]

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
