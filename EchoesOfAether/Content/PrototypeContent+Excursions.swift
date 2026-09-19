import Foundation

// Excursions optionnelles : mines de Cendreval, désert d'Ossara.
// Extrait de PrototypeContent.swift (découpage du monolithe).
extension PrototypeContent {
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

    // Habitants d'Ossara : la cité vit terrée depuis que les monstres
    // rôdent. Trois voix, une même peur — le locuteur est un rôle localisé
    // (pas un prénom) : le portrait générique s'y accroche par mot-clé.

    /// Le caravanier, près des tentes : ses bêtes ne repartiront pas.
    static let desertCaravanierDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "npc.desert.caravanier.name"),
              text: String(localized: "dialogue.desert.npc.caravanier1")),
        .line(speaker: String(localized: "npc.desert.caravanier.name"),
              text: String(localized: "dialogue.desert.npc.caravanier2"))
    ]

    /// Même caravanier, une fois le colosse abattu : la route est libre.
    static let desertCaravanierResolvedDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "npc.desert.caravanier.name"),
              text: String(localized: "dialogue.desert.npc.caravanierPost1")),
        .line(speaker: String(localized: "npc.desert.caravanier.name"),
              text: String(localized: "dialogue.desert.npc.caravanierPost2"))
    ]

    /// La marchande, au souk : plus rien à vendre, plus personne à qui.
    static let desertMerchantDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "npc.desert.merchant.name"),
              text: String(localized: "dialogue.desert.npc.merchant1")),
        .line(speaker: String(localized: "npc.desert.merchant.name"),
              text: String(localized: "dialogue.desert.npc.merchant2"))
    ]

    /// Même marchande, après le colosse : elle rouvre l'étal.
    static let desertMerchantResolvedDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "npc.desert.merchant.name"),
              text: String(localized: "dialogue.desert.npc.merchantPost1")),
        .line(speaker: String(localized: "npc.desert.merchant.name"),
              text: String(localized: "dialogue.desert.npc.merchantPost2"))
    ]

    /// L'enfant, près du puits : il répète ce que les grands murmurent.
    static let desertChildDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "npc.desert.child.name"),
              text: String(localized: "dialogue.desert.npc.child1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.desert.npc.child.kael1"))
    ]

    /// Même enfant, après le colosse : la promesse de Kael tenue.
    static let desertChildResolvedDialogue: [DialogueStep] = [
        .line(speaker: String(localized: "npc.desert.child.name"),
              text: String(localized: "dialogue.desert.npc.childPost1")),
        .line(speaker: "Kael",
              text: String(localized: "dialogue.desert.npc.childKaelPost1"))
    ]
}
