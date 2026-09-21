import SpriteKit

// Acte IV — les fins : détruire le Cœur, ou fusionner avec lui.
extension GameManager {
    /// Fin de l'Acte IV — branchée selon le choix devant la Voix :
    /// - 0 (ou non choisi) : Kael DÉTRUIT le Cœur (libère les échos).
    /// - 1 : Kael FUSIONNE avec le Cœur (devient le nouveau gardien).
    func showAct4Ending() {
        guard scene != nil else { return }
        AudioEngine.shared.setMood(.finale)
        transition(to: .dialogue)
        if player.act4EndingChoice == 1 {
            showAct4MergeEnding()
        } else {
            showAct4DestroyEnding()
        }
    }

    /// Fin « Détruire le Cœur » — les échos sont libérés, Lyra part en paix.
    /// Le choix de corruption de l'Acte II y résonne : s'il avait saisi le
    /// pouvoir, briser le Cœur est son expiation ; s'il l'avait subi, c'est
    /// enfin un acte à lui — reprendre la main que le Vide lui avait volée.
    func showAct4DestroyEnding() {
        let reflection = player.kaelChoseCorruption
            ? PrototypeContent.act4DestroyChoseDialogue
            : PrototypeContent.act4DestroyResistedDialogue
        dialogue.start(reflection) { [weak self] in
            guard let self else { return }
            dialogue.start(PrototypeContent.act4DestroyEndingDialogue) { [weak self] in
                guard let self else { return }
                dialogue.start(PrototypeContent.act4DestroyEndScreen) { [weak self] in
                    self?.rollCreditsToMenu()
                }
            }
        }
    }

    /// Fin « Fusionner avec le Cœur » — Kael devient le nouveau gardien.
    /// Le choix de corruption de l'Acte II y résonne : s'il a saisi le pouvoir
    /// sciemment, fusionner est l'aboutissement d'une chute assumée ; s'il l'a
    /// refusé, c'est une reddition lucide — sa toute première vraie décision.
    func showAct4MergeEnding() {
        let reflection = player.kaelChoseCorruption
            ? PrototypeContent.act4MergeChoseDialogue
            : PrototypeContent.act4MergeResistedDialogue
        dialogue.start(reflection) { [weak self] in
            guard let self else { return }
            dialogue.start(PrototypeContent.act4MergeEndingDialogue) { [weak self] in
                guard let self else { return }
                dialogue.start(PrototypeContent.act4MergeEndScreen) { [weak self] in
                    self?.rollCreditsToMenu()
                }
            }
        }
    }
}
