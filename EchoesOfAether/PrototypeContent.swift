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
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.lyra5"))
    ]

    // MARK: - Lyra (village, parle à Kael)

    static let lyraVillageDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.lyra.village1")),
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
        .line(speaker: "Lyra", text: String(localized: "dialogue.lyra.village2"))
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

    static let garenQuestDoneDialogue: [DialogueStep] = [
        .line(speaker: "Garen", text: String(localized: "dialogue.garen.done1"))
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
        .line(speaker: "Kael", text: String(localized: "dialogue.lyra.quest.kael1"))
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

    // MARK: - Forêt — jouet trouvé

    static let toyFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.forest.toy.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.forest.toy.lyra1"))
    ]

    // MARK: - Enfant (dialogue original)

    static let childDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.line1")),
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.line2")),
        .choice(
            prompt: String(localized: "dialogue.child.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.child.choice1"),
                    responseSpeaker: String(localized: "dialogue.child.name"),
                    response: String(localized: "dialogue.child.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.child.choice2"),
                    responseSpeaker: String(localized: "dialogue.child.name"),
                    response: String(localized: "dialogue.child.response2")
                )
            ]
        )
    ]

    // MARK: - Villageois apeuré

    static let villagerDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.villager.name"), text: String(localized: "dialogue.villager.line1")),
        .choice(
            prompt: String(localized: "dialogue.villager.prompt"),
            options: [
                DialogueChoice(
                    title: String(localized: "dialogue.villager.choice1"),
                    responseSpeaker: String(localized: "dialogue.villager.name"),
                    response: String(localized: "dialogue.villager.response1")
                ),
                DialogueChoice(
                    title: String(localized: "dialogue.villager.choice2"),
                    responseSpeaker: String(localized: "dialogue.villager.name"),
                    response: String(localized: "dialogue.villager.response2")
                )
            ]
        ),
        .line(speaker: String(localized: "dialogue.villager.name"), text: String(localized: "dialogue.villager.line2"))
    ]

    // MARK: - Forêt — après combat bosquet

    static let forestGroveDialogue: [DialogueStep] = [
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

    static let act2DorinDoubtDialogue: [DialogueStep] = [
        .line(speaker: "Dorin", text: String(localized: "dialogue.act2.dorin.doubt1")),
        .line(speaker: "Kael",  text: String(localized: "dialogue.act2.dorin.kael1")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.act2.dorin.doubt2"))
    ]

    // MARK: - Acte II — Ruines de la Source

    static let act2RuinsEnterDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.ruins.enter.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.ruins.enter.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.ruins.enter.lyra2"))
    ]

    static let act2RuinsCombat1Dialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.ruins.combat1.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.ruins.combat1.kael1"))
    ]

    static let act2RuinsCombat2Dialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.act2.ruins.combat2.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.ruins.combat2.lyra1"))
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
        .line(speaker: "Lyra", text: String(localized: "dialogue.act2.archivist.post3"))
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
