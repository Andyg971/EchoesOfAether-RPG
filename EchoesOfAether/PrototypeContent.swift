import Foundation

enum PrototypeContent {

    // MARK: - Wake (scène ACT1_SC1 du scénario — réveil chez Lyra)

    static let wakeDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.real.lyra1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.real.lyra2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.wake.real.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.wake.real.kael2")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.real.lyra3")),
        .line(speaker: "Kael", text: String(localized: "dialogue.wake.real.kael3")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.real.lyra4")),
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
        .line(speaker: "Lyra", text: String(localized: "dialogue.wake.lyra5")),
        // Monologue intérieur — Kael observe la marque (ACT1_SC1_MARK)
        .line(speaker: "Kael", text: String(localized: "dialogue.mark.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.mark.kael2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.mark.kael3"))
    ]

    // MARK: - Lyra (village, parle à Kael)

    /// Le pacte (scène ACT1_SC3 du scénario) : Lyra et Kael s'associent,
    /// chacun pour ses raisons.
    static let lyraVillageDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.pact.2")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.3")),
        .line(speaker: "Kael", text: String(localized: "dialogue.pact.4")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.5")),
        .line(speaker: "Kael", text: String(localized: "dialogue.pact.6")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.7")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.8")),
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
        .line(speaker: "Kael", text: String(localized: "dialogue.pact.9")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.pact.10"))
    ]

    // MARK: - Dorin (méfiance + départ vers le nord)

    /// Rencontre avec Dorin (scène ACT1_SC2 du scénario) : le nord, les
    /// mines de Cendreval, la marque des Gardiens.
    static let dorinDialogue: [DialogueStep] = [
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.real.1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.dorin.real.2")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.real.3")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.real.4")),
        .line(speaker: "Kael", text: String(localized: "dialogue.dorin.real.5")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.real.6")),
        .line(speaker: "Kael", text: String(localized: "dialogue.dorin.real.7")),
        .line(speaker: "Dorin", text: String(localized: "dialogue.dorin.real.8")),
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
        .line(speaker: "Garen", text: String(localized: "dialogue.garen.real.1")),
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

    // MARK: - Mines de Cendreval (excursion optionnelle)

    /// Entrée des mines : Lyra reste dehors, Kael descend seul.
    static let minesEnterDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.mines.enter.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.mines.enter.lyra1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.mines.enter.kael2"))
    ]

    /// Après le premier combat : ce qui reste des équipes.
    static let minesCombat1PostDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.mines.combat1.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.mines.combat1.kael2"))
    ]

    /// Avant le golem : le fond de la galerie tremble.
    static let minesBossPreDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.mines.boss.pre1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.mines.boss.pre2"))
    ]

    /// Après le golem : les mines se taisent pour de bon.
    static let minesBossPostDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.mines.boss.post1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.mines.boss.post2"))
    ]

    /// Plaque des mineurs : le lore de Cendreval.
    static let minesInscriptionDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.mines.plaqueName"),
              text: String(localized: "dialogue.mines.inscription.1")),
        .line(speaker: String(localized: "dialogue.mines.plaqueName"),
              text: String(localized: "dialogue.mines.inscription.2")),
        .line(speaker: "Kael", text: String(localized: "dialogue.mines.inscription.kael1"))
    ]

    /// Veine d'or intacte.
    static let minesGoldDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.mines.gold.kael1"))
    ]

    // MARK: - Désert d'Ossara (voyage via la carte du monde)

    /// Première arrivée : le soleil, le sable, les traces.
    static let desertEnterDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.desert.enter.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.desert.enter.kael2"))
    ]

    /// Caverne aux Échos — entrée (donjon optionnel). One-shot, aucun
    /// enchaînement : garde anti-soft-lock.
    static let caveEnterDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.cave.enter.kael1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.cave.enter.kael2"))
    ]

    /// Après les pillards : les caravanes respirent.
    static let desertCombat1PostDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.desert.combat1.kael1"))
    ]

    /// Avant le colosse : le sol tremble sous les dunes.
    static let desertBossPreDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.desert.boss.pre1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.desert.boss.pre2"))
    ]

    /// Après le colosse : le désert respire à nouveau.
    static let desertBossPostDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.desert.boss.post1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.desert.boss.post2"))
    ]

    /// Coffre enfoui sous le sable.
    static let desertChestDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.desert.chest.kael1"))
    ]

    /// L'oasis : eau claire, forces retrouvées.
    static let desertOasisDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.desert.oasis.kael1"))
    ]

    /// Embuscade en chemin (rencontre aléatoire de voyage).
    static let desertAmbushDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.desert.ambush.kael1"))
    ]

    // MARK: - Forêt — jouet trouvé

    static let toyFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "dialogue.forest.toy.kael1")),
        .line(speaker: "Lyra", text: String(localized: "dialogue.forest.toy.lyra1"))
    ]

    // MARK: - Enfant (dialogue original)

    static let childDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.real.1")),
        .line(speaker: String(localized: "dialogue.child.name"), text: String(localized: "dialogue.child.real.2")),
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

    // MARK: - Quête secondaire : le talisman du fils (villageoise)

    static let villagerQuestOfferDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.villager.name"), text: String(localized: "dialogue.oldwoman.1")),
        .line(speaker: String(localized: "dialogue.villager.name"), text: String(localized: "quest.medallion.offer1")),
        .choice(
            prompt: String(localized: "quest.medallion.offer2"),
            options: [
                DialogueChoice(
                    title: String(localized: "quest.medallion.accept"),
                    responseSpeaker: String(localized: "dialogue.villager.name"),
                    response: String(localized: "dialogue.oldwoman.2")
                ),
                DialogueChoice(
                    title: String(localized: "quest.medallion.decline"),
                    responseSpeaker: String(localized: "dialogue.villager.name"),
                    response: String(localized: "quest.medallion.offer2")
                )
            ]
        )
    ]

    static let villagerQuestActiveDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.villager.name"),
              text: String(localized: "quest.medallion.active"))
    ]

    static let villagerQuestDoneDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.villager.name"),
              text: String(localized: "quest.medallion.done1")),
        .line(speaker: String(localized: "dialogue.villager.name"),
              text: String(localized: "quest.medallion.done2"))
    ]

    static let medallionFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "quest.medallion.found"))
    ]

    // MARK: - Quête secondaire : le fer de la forge (Bram)

    static let bramOreOfferDialogue: [DialogueStep] = [
        .line(speaker: "Bram", text: String(localized: "quest.bramOre.offer1")),
        .choice(
            prompt: String(localized: "quest.bramOre.offer2"),
            options: [
                DialogueChoice(
                    title: String(localized: "quest.bramOre.accept"),
                    responseSpeaker: "Bram",
                    response: String(localized: "quest.bramOre.acceptResponse")
                ),
                DialogueChoice(
                    title: String(localized: "quest.bramOre.decline"),
                    responseSpeaker: "Bram",
                    response: String(localized: "quest.bramOre.declineResponse")
                )
            ]
        )
    ]

    static let bramOreActiveDialogue: [DialogueStep] = [
        .line(speaker: "Bram", text: String(localized: "quest.bramOre.active"))
    ]

    static let bramOreDoneDialogue: [DialogueStep] = [
        .line(speaker: "Bram", text: String(localized: "quest.bramOre.done1")),
        .line(speaker: "Bram", text: String(localized: "quest.bramOre.done2"))
    ]

    static let oreFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "quest.bramOre.found"))
    ]

    // MARK: - Quête secondaire : l'herbe lunaire (Sage)

    static let sageHerbOfferDialogue: [DialogueStep] = [
        .line(speaker: "Sage", text: String(localized: "quest.sageHerb.offer1")),
        .choice(
            prompt: String(localized: "quest.sageHerb.offer2"),
            options: [
                DialogueChoice(
                    title: String(localized: "quest.sageHerb.accept"),
                    responseSpeaker: "Sage",
                    response: String(localized: "quest.sageHerb.acceptResponse")
                ),
                DialogueChoice(
                    title: String(localized: "quest.sageHerb.decline"),
                    responseSpeaker: "Sage",
                    response: String(localized: "quest.sageHerb.declineResponse")
                )
            ]
        )
    ]

    static let sageHerbActiveDialogue: [DialogueStep] = [
        .line(speaker: "Sage", text: String(localized: "quest.sageHerb.active"))
    ]

    static let sageHerbDoneDialogue: [DialogueStep] = [
        .line(speaker: "Sage", text: String(localized: "quest.sageHerb.done1")),
        .line(speaker: "Sage", text: String(localized: "quest.sageHerb.done2"))
    ]

    static let herbFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "quest.sageHerb.found"))
    ]

    // MARK: - Quête secondaire : l'éclaireur disparu (Garen)

    static let garenScoutOfferDialogue: [DialogueStep] = [
        .line(speaker: "Garen", text: String(localized: "quest.garenScout.offer1")),
        .choice(
            prompt: String(localized: "quest.garenScout.offer2"),
            options: [
                DialogueChoice(
                    title: String(localized: "quest.garenScout.accept"),
                    responseSpeaker: "Garen",
                    response: String(localized: "quest.garenScout.acceptResponse")
                ),
                DialogueChoice(
                    title: String(localized: "quest.garenScout.decline"),
                    responseSpeaker: "Garen",
                    response: String(localized: "quest.garenScout.declineResponse")
                )
            ]
        )
    ]

    static let garenScoutActiveDialogue: [DialogueStep] = [
        .line(speaker: "Garen", text: String(localized: "quest.garenScout.active"))
    ]

    static let garenScoutDoneDialogue: [DialogueStep] = [
        .line(speaker: "Garen", text: String(localized: "quest.garenScout.done1")),
        .line(speaker: "Garen", text: String(localized: "quest.garenScout.done2"))
    ]

    static let scoutBadgeFoundDialogue: [DialogueStep] = [
        .line(speaker: "Kael", text: String(localized: "quest.garenScout.found"))
    ]

    static let villagerDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "dialogue.villager.name"), text: String(localized: "dialogue.oldwoman.1")),
        .line(speaker: String(localized: "dialogue.villager.name"), text: String(localized: "dialogue.oldwoman.2")),
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
              text: String(localized: "dialogue.act3.kael4"))
    ]

    /// Ecran de fin Acte III (placeholder)
    static let act3EndPlaceholder: [DialogueStep] = [
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

    static let act3GuardianPreDialogue: [DialogueStep] = [
        // La confrontation (scène ACT4_SC11 du scénario, adaptée à Eran)
        .line(speaker: "Eran", text: String(localized: "dialogue.finale.eran.1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.finale.kael.1")),
        .line(speaker: "Eran", text: String(localized: "dialogue.finale.eran.2")),
        .line(speaker: "Eran", text: String(localized: "dialogue.finale.eran.3")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.finale.voice.1")),
        .line(speaker: "Kael", text: String(localized: "dialogue.finale.kael.2")),
        .line(speaker: String(localized: "dialogue.act3.voiceName"),
              text: String(localized: "dialogue.finale.voice.2")),
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

    // MARK: - Lore entries (noms de clés xcstrings)

    @MainActor
    static func buildLoreEntries(for player: PlayerState) -> [LoreEntry] {
        var entries: [LoreEntry] = []
        if player.loreDiscovered.contains("eran") {
            entries.append(LoreEntry(
                title: String(localized: "lore.eran.title"),
                body: String(localized: "lore.eran.body")
            ))
        }
        if player.loreDiscovered.contains("archivist") {
            entries.append(LoreEntry(
                title: String(localized: "lore.archivist.title"),
                body: String(localized: "lore.archivist.body")
            ))
        }
        if player.loreDiscovered.contains("threshold") {
            entries.append(LoreEntry(
                title: String(localized: "lore.threshold.title"),
                body: String(localized: "lore.threshold.body")
            ))
        }
        if player.loreDiscovered.contains("void") {
            entries.append(LoreEntry(
                title: String(localized: "lore.void.title"),
                body: String(localized: "lore.void.body")
            ))
        }
        if player.loreDiscovered.contains("cendreval") {
            entries.append(LoreEntry(
                title: String(localized: "lore.cendreval.title"),
                body: String(localized: "lore.cendreval.body")
            ))
        }
        if player.loreDiscovered.contains("voidheart") {
            entries.append(LoreEntry(
                title: String(localized: "lore.voidheart.title"),
                body: String(localized: "lore.voidheart.body")
            ))
        }
        if player.loreDiscovered.contains("kaelMemories") {
            entries.append(LoreEntry(
                title: String(localized: "lore.kaelMemories.title"),
                body: String(localized: "lore.kaelMemories.body")
            ))
        }
        return entries
    }
}
