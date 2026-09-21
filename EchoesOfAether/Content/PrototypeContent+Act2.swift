import Foundation

// Acte II — retour à Solis, ruines de la Source, Découverte, le choix. La suite (mort de Lyra…) est dans `+Act2Lyra`.
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

}
