import Foundation

enum PrototypeContent {
    static let wakeDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: "Tu sais comment tu t'appelles au moins ?"),
        .choice(
            prompt: "Répondre en Kael",
            options: [
                DialogueChoice(title: "...", response: "Lyra: Alors on commencera par le silence."),
                DialogueChoice(title: "Si je le savais, je ne serais pas ici.", response: "Lyra: Charmant. Tu es vivant, au moins."),
                DialogueChoice(title: "Kael. C'est le seul nom qui revient.", response: "Lyra: Kael, alors.")
            ]
        ),
        .line(speaker: "Kael", text: "Où suis-je ?"),
        .line(speaker: "Lyra", text: "Solis. Et tout le village sait déjà que ta main brille quand tu dors.")
    ]

    static let dorinDialogue: [DialogueStep] = [
        .line(speaker: "Dorin", text: "Des gens disparaissent au nord. Si ta marque touche cette corruption, tu peux peut-être les sauver."),
        .choice(
            prompt: "Répondre à Dorin",
            options: [
                DialogueChoice(title: "Regarder la marque sans répondre.", response: "Dorin: Je vois. Même ton silence a peur de toi."),
                DialogueChoice(title: "Vos morts ne me regardent pas.", response: "Lyra: Non. Mais tes réponses sont au nord."),
                DialogueChoice(title: "Si le nord a mes réponses, j'irai au nord.", response: "Dorin: Alors nos routes se croisent.")
            ]
        ),
        .line(speaker: "Lyra", text: "Je viens avec toi. Pas pour te protéger. Pour t'empêcher de faire pire.")
    ]

    static let blackAetherDialogue: [DialogueStep] = [
        .line(speaker: "Lyra", text: "Kael... qu'est-ce que tu viens de faire ?"),
        .line(speaker: "Kael", text: "Ce qui marchait."),
        .line(speaker: "Lyra", text: "Tu aurais pu t'arrêter."),
        .line(speaker: "Kael", text: "Mais ce serait encore vivant.")
    ]

    static let shrineEnding: [DialogueStep] = [
        .line(speaker: "Voix", text: "Ils te retiendront."),
        .line(speaker: "Voix", text: "Moi, je peux te rendre ce qu'ils ne comprendront jamais."),
        .line(speaker: "Lyra", text: "Kael ?"),
        .line(speaker: "Kael", text: "On rentre.")
    ]
}

