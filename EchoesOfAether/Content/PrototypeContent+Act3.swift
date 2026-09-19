import Foundation

// Acte III — le Seuil.
// Extrait de PrototypeContent.swift (découpage du monolithe).
extension PrototypeContent {
    // MARK: - Acte III — Le Seuil (Squelette)

    /// Prologue : Kael entre dans le Seuil. La Voix parle.
    static let act3PrologueDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.voice1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.voice2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.kael1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.voice3")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.kael2")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.voice4")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.kael2b"))
    ]

    /// Eran Solace — première rencontre au Seuil
    static let act3EranMeetDialogue: [DialogueStep] = [
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act3.eran1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.kael3")),
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act3.eran2")),
        .choice(
            prompt: String(localized: "dialogue.act3.eranChoicePrompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.act3.eranChoice1"),
                    responseSpeaker: "Eran",
                    response: String(localized: "dialogue.act3.eranResponse1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.act3.eranChoice2"),
                    responseSpeaker: "Kael",
                    response: String(localized: "dialogue.act3.eranResponse2")
                )
            ]
        ),
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act3.eran3")),
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act3.eran4")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.kael4")),
        // LE PRIX — la réponse au trou du récit : pourquoi Kael s'est-il
        // réveillé sans passé. Eran a payé son nom ; Kael a payé sa mémoire.
        // Dit ici par le seul personnage qui pouvait le savoir.
        .line(speaker: "Kael",  text: String(localized: "dialogue.act3.price.kael1")),
        .line(speaker: "Eran",  text: String(localized: "dialogue.act3.price.eran1")),
        .line(speaker: "Eran",  text: String(localized: "dialogue.act3.price.eran2")),
        .line(speaker: "Kael",  text: String(localized: "dialogue.act3.price.kael2")),
        .line(speaker: "Eran",  text: String(localized: "dialogue.act3.price.eran3")),
        .line(speaker: "Kael",  text: String(localized: "dialogue.act3.price.kael3"))
    ]

    /// Transition de fin d'Acte III : la Voix annonce l'Acte IV juste avant
    /// `beginAct4()`. Deux répliques, contenu définitif.
    static let act3EndingTransitionDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.end1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.end2"))
    ]

    /// Point de non-retour (façon Final Fantasy / Persona) : dernière mise en
    /// garde avant de franchir le Seuil vers le Cœur du Vide. Le choix est lu
    /// via `dialogue.lastChoiceIndex` (0 = franchir, 1 = rester / préparer).
    static let act4ThresholdWarningDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.warning1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act4.warning2")),
        .choice(
            prompt: String(localized: "dialogue.act4.warningPrompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.act4.warningCross"),
                    responseSpeaker: "Kael",
                    response: String(localized: "dialogue.act4.warningCrossResponse")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.act4.warningStay"),
                    responseSpeaker: "Kael",
                    response: String(localized: "dialogue.act4.warningStayResponse")
                )
            ]
        )
    ]

    /// Même garde-fou que act4ThresholdWarningDialogue, côté « résister » :
    /// ce choix mettait fin au jeu sans prévenir (crédits directs, Acte IV
    /// sauté), alors que sa réplique (« L'Aether me contrôle ») se lisait
    /// comme la réponse la plus lucide. Jouée juste après le choix fait à
    /// Eran, avant qu'il ne rejoigne officiellement. Choix lu via
    /// `dialogue.lastChoiceIndex` (0 = confirmer, 1 = reconsidérer).
    static let act3ResistWarningDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.resistWarning1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.resistWarning2")),
        .choice(
            prompt: String(localized: "dialogue.act3.resistWarningPrompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.act3.resistWarningConfirm"),
                    responseSpeaker: "Kael",
                    response: String(localized: "dialogue.act3.resistWarningConfirmResponse")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.act3.resistWarningReconsider"),
                    responseSpeaker: "Kael",
                    response: String(localized: "dialogue.act3.resistWarningReconsiderResponse")
                )
            ]
        )
    ]

    /// Pré-combat : le Gardien du Seuil se dresse devant Kael.
    // ── Acte III étendu : l'Écho de Lyra, les esprits, les stèles ──

    /// L'Écho de Lyra attend Kael à l'entrée du Seuil — elle rejoint le trio.
    static let act3EchoMeetDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act3.echo1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.echoKael1")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act3.echo2")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act3.echo3")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.echoKael2")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act3.echo4"))
    ]

    /// Esprit du mineur de Cendreval (quête « Les échos égarés »).
    static let spiritMinerDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.spirit.minerName"),
              text: String(localized: "dialogue.spirit.miner1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.spirit.minerKael")),
        .line(speaker: String(localized: "dialogue.spirit.minerName"),
              text: String(localized: "dialogue.spirit.miner2"))
    ]

    /// Esprit de la mère de Solis.
    static let spiritMotherDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.spirit.motherName"),
              text: String(localized: "dialogue.spirit.mother1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.spirit.motherKael")),
        .line(speaker: String(localized: "dialogue.spirit.motherName"),
              text: String(localized: "dialogue.spirit.mother2"))
    ]

    /// Esprit du garde du sanctuaire.
    static let spiritGuardDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.spirit.guardName"),
              text: String(localized: "dialogue.spirit.guard1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.spirit.guardKael")),
        .line(speaker: String(localized: "dialogue.spirit.guardName"),
              text: String(localized: "dialogue.spirit.guard2"))
    ]

    /// Les trois esprits apaisés — récompense.
    static let spiritsDoneDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.spirit.done1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.spirit.done2"))
    ]

    /// Stèles du Vide : trois fragments de la chute d'Eran.
    static func steleDialogue(_ index: Int) -> [DialogueStep] {
        let key = "dialogue.stele.\(index)"
        return [.line(speaker: String(localized: "dialogue.stele.name"),
                      text: String(localized: String.LocalizationValue(key)))]
    }

    /// Les trois stèles lues.
    static let stelesDoneDialogue: [DialogueStep] = [
        .line(speaker: "Kael",
              text: String(localized: "dialogue.stele.done"))
    ]

    /// Avant le combat annexe contre les ombres.
    static let shadesPreDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.shades.pre1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.shades.pre2"))
    ]

    /// Eran rejoint le trio après la rencontre.
    static let act3EranJoinDialogue: [DialogueStep] = [
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act3.eranJoin1")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act3.eranJoin2"))
    ]

    /// Le Gardien du Seuil EST Eran — ou plutôt ce qu'il a laissé derrière en
    /// tenant le sceau seul vingt ans : son Ombre. Eran (déjà libre, dans le
    /// groupe depuis act3EranMeetDialogue) affronte cette part de lui-même à
    /// nos côtés. Ne rejoue PAS « premières retrouvailles » ni l'origine de
    /// l'amnésie de Kael (déjà racontées, en détail et sans contradiction,
    /// dans act3EranMeetDialogue) — les deux faisaient doublon avec cette
    /// scène-là et se contredisaient en plus sur qui avait scellé quoi.
    static let act3GuardianPreDialogue: [DialogueStep] = [
        .line(speaker: "Eran", text: String(localized: "dialogue.act3.shadowPre1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act3.shadowPre2")),
        .line(speaker: "Eran", text: String(localized: "dialogue.act3.shadowPre3")),
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act3.guardianEran2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.guardianKael1"))
    ]

    /// Post-combat : le Seuil cède.
    static let act3GuardianPostDialogue: [DialogueStep] = [
        // Les aveux d'Eran (scène ACT4_SC12 du scénario, adaptée)
        .line(speaker: "Eran", text: String(localized: "dialogue.finale.eran.4")),
        .line(speaker: "Kael", text: String(localized: "dialogue.finale.kael.3")),
        .line(speaker: "Eran", text: String(localized: "dialogue.finale.eran.5")),
        .line(speaker: "Eran", text: String(localized: "dialogue.finale.eran.6")),
        .line(speaker: "Eran", text: String(localized: "dialogue.finale.eran.7")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.guardianPost1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.guardianPost2"))
    ]

    /// Fin "Franchir le Seuil" — Kael embrasse le Vide (choix d'Eran : 0).
    static let act3TrueEndingDialogue: [DialogueStep] = [
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.trueEnd1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.trueEnd2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.trueEnd3")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.trueEnd4"))
    ]

    /// Fin "Résister / refuser le Vide" — Kael tourne le dos au Seuil
    /// (choix d'Eran : 1). Conclusion alternative à `act3TrueEndingDialogue`.
    static let act3ResistEndingDialogue: [DialogueStep] = [
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.resist1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.resist2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.resist3")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.resist4"))
    ]

    /// Épilogue complet de la fin « Résister » (ACT3_RESIST) : adieux de
    /// l'Écho de Lyra, Eran gardien du Seuil, retour de Kael, narration.
    static let act3ResistEpilogueDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act3.resistEp.lyra1")),
        .line(speaker: String(localized: "dialogue.echo.name"),
              text: String(localized: "dialogue.act3.resistEp.lyra2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.resistEp.kael1")),
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act3.resistEp.eran1")),
        .line(speaker: "Eran",
              text: String(localized: "dialogue.act3.resistEp.eran2")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.act3.resistEp.kael2")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.resistEnd1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.resistEp.narr1")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.resistEp.narr2")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.resistEp.narr3")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.resistEnd2")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.act3.resistEp.end"))
    ]
}
