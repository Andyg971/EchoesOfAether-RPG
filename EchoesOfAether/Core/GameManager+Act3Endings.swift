import SpriteKit

// Acte III — les trois fins (franchir, résister, croisée) et les crédits vers le menu.
extension GameManager {
    /// Fin de l'Acte III — branchée selon le choix d'Eran :
    /// - 0 (ou non choisi) : Kael FRANCHIT le Seuil (embrasse le Vide).
    /// - 1 : Kael RÉSISTE / refuse le Vide.
    /// Chaque fin enchaîne ses dialogues → crédits → menu.
    func showAct3TrueEnding() {
        guard scene != nil else { return }
        AudioEngine.shared.setMood(.finale)   // « New Sunrise » (CC0)
        transition(to: .dialogue)
        // Par défaut (aucun choix capturé), on retombe sur la fin "franchir".
        if player.act3EndingChoice == 1 {
            showAct3ResistEnding()
        } else {
            showAct3CrossEnding()
        }
    }

    /// Fin "Franchir le Seuil" — Kael embrasse le Vide. Ce n'est plus une
    /// fin : le Seuil s'ouvre sur l'Acte IV, le Cœur du Vide.
    ///
    /// Point de non-retour façon FF/Persona : avant de franchir, Kael reçoit
    /// une dernière mise en garde. « Rester » le renvoie explorer et préparer
    /// le Seuil (le gate reste franchissable) ; « Franchir » est irréversible.
    func showAct3CrossEnding() {
        guard scene != nil else { return }
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act4ThresholdWarningDialogue) { [weak self] in
            guard let self else { return }
            if dialogue.lastChoiceIndex == 1 {
                // Demi-tour : on quitte l'ambiance finale, retour exploration.
                AudioEngine.shared.setMood(.forPhase(phase))
                transition(to: .exploration)
            } else {
                performAct3Crossing()
            }
        }
    }

    /// Franchissement effectif du Seuil : narration de fin d'Acte III puis
    /// bascule vers l'Acte IV. Appelé uniquement après confirmation « Franchir ».
    func performAct3Crossing() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.act3TrueEndingDialogue) { [weak self] in
            guard let self else { return }
            // « Ce n'était que le début » — la Voix annonce l'Acte IV.
            dialogue.start(PrototypeContent.act3EndingTransitionDialogue) { [weak self] in
                self?.beginAct4()
            }
        }
    }

    /// Fin "Résister / refuser le Vide" — Kael tourne le dos au Seuil.
    func showAct3ResistEnding() {
        dialogue.start(PrototypeContent.act3ResistEndingDialogue) { [weak self] in
            guard let self else { return }
            AudioEngine.shared.setMood(.finale)
            dialogue.start(PrototypeContent.act3ResistEpilogueDialogue) { [weak self] in
                self?.rollCreditsToMenu()
            }
        }
    }

    func rollCreditsToMenu() {
        guard let scene else { return }
        transition(to: .exploration)
        TransitionManager.showCredits(in: scene) { [weak self] in
            self?.onReturnToMenu?()
        }
    }
}
