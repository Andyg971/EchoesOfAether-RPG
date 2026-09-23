import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Une scène PRÉSENTÉE dans une vraie `SKView`, posée dans la fenêtre de
/// l'hôte de test : les `SKAction` (fondus, cinématiques, tours de combat
/// différés) s'exécutent en temps réel. `wait(_:)` fait tourner la boucle
/// principale — donc le rendu — le temps demandé.
///
/// À réserver aux flux qui vivent DANS des actions (mort de Lyra, fins
/// d'acte) : c'est lent (secondes réelles). Tout ce qui est synchrone se
/// teste sans (cf. `GameManagerFlowTests`).
@MainActor
final class LiveScene {
    let view: SKView
    let scene: SKScene

    init(size: CGSize = CGSize(width: 844, height: 390)) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        view = SKView(frame: CGRect(origin: .zero, size: size))
        view.isHidden = false
        window?.addSubview(view)
        scene = SKScene(size: size)
        scene.scaleMode = .aspectFill
        view.presentScene(scene)
    }

    /// Laisse le temps réel s'écouler (boucle principale + rendu).
    func wait(_ seconds: TimeInterval) {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
        }
    }

    /// Attend qu'une condition devienne vraie, au plus `timeout` secondes.
    @discardableResult
    func wait(until condition: () -> Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
        }
        return condition()
    }

    func tearDown() {
        view.presentScene(nil)
        view.removeFromSuperview()
    }
}

/// Pilote un `DialogueSystem` jusqu'à la fin de la table COURANTE, de façon
/// synchrone : passe les répliques (B), répond aux choix avec `choices` dans
/// l'ordre (A). S'arrête dès que la table change — une completion qui
/// enchaîne un autre dialogue le laisse ouvert, à sa première réplique.
@MainActor
func finishDialogue(_ dialogue: DialogueSystem, choosing choices: [Int] = []) {
    var remaining = choices
    let table = dialogue.steps.count
    let firstText: String? = {
        for step in dialogue.steps { if case let .line(_, text) = step { return text } }
        return nil
    }()
    func sameTable() -> Bool {
        guard dialogue.steps.count == table else { return false }
        for step in dialogue.steps { if case let .line(_, text) = step { return text == firstText } }
        return true
    }
    var guardCount = 0
    while dialogue.isActive, sameTable(), guardCount < 200 {
        guardCount += 1
        if dialogue.hasChoicesOnScreen {
            let pick = remaining.isEmpty ? 0 : remaining.removeFirst()
            dialogue.moveChoiceSelection(dialogue.choiceSelection - pick)   // dy : « bas » = -1
            dialogue.confirmChoice()   // affiche le titre choisi…
            dialogue.advance()         // …puis la réaction du PNJ
            dialogue.advance()         // …puis l'étape suivante
        } else {
            dialogue.skipToEnd()
        }
    }
}
