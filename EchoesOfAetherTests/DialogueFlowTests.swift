import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Tests anti-régression des soft-locks de dialogue (cf. commits 9a8be17,
/// 3110ebd, c5ade62) : la completion d'un dialogue enchaîné ne doit JAMAIS
/// être écrasée, et chaque fin de dialogue doit rendre la main.
private func line(_ text: String) -> DialogueStep {
    .line(speaker: "Test", text: text)
}

@MainActor
final class DialogueFlowTests: XCTestCase {

    private func makeScene() -> SKScene {
        SKScene(size: CGSize(width: 800, height: 400))
    }

    // MARK: - Régression 9a8be17 — completion écrasée sur start enchaîné

    func test_chainedStart_inCompletion_preservesSecondCompletion() {
        let scene = makeScene()
        let dialogue = DialogueSystem()
        dialogue.attach(to: scene)

        var bCompleted = false
        dialogue.start([line("a1"), line("a2")]) {
            dialogue.start([line("b1")]) { bCompleted = true }
        }

        dialogue.advance()   // a1 → a2
        dialogue.advance()   // fin de A → la completion démarre B
        XCTAssertTrue(dialogue.isActive, "B doit être affiché après la fin de A")
        XCTAssertFalse(bCompleted)

        dialogue.advance()   // fin de B
        XCTAssertTrue(bCompleted, "La completion de B a été écrasée (régression 9a8be17)")
        XCTAssertFalse(dialogue.isActive)
    }

    func test_tripleChain_allCompletionsFire() {
        let scene = makeScene()
        let dialogue = DialogueSystem()
        dialogue.attach(to: scene)

        var order: [String] = []
        dialogue.start([line("a")]) {
            order.append("A")
            dialogue.start([line("b")]) {
                order.append("B")
                dialogue.start([line("c")]) { order.append("C") }
            }
        }
        dialogue.advance()
        dialogue.advance()
        dialogue.advance()
        XCTAssertEqual(order, ["A", "B", "C"])
    }

    // MARK: - Fin de dialogue

    func test_emptySteps_completesImmediately() {
        let scene = makeScene()
        let dialogue = DialogueSystem()
        dialogue.attach(to: scene)

        var completed = false
        dialogue.start([]) { completed = true }
        XCTAssertTrue(completed)
        XCTAssertFalse(dialogue.isActive)
    }

    func test_singleLine_advanceCompletes() {
        let scene = makeScene()
        let dialogue = DialogueSystem()
        dialogue.attach(to: scene)

        var completed = false
        dialogue.start([line("seule")]) { completed = true }
        XCTAssertTrue(dialogue.isActive)
        dialogue.advance()
        XCTAssertTrue(completed)
    }

    // MARK: - Choix

    func test_choice_confirm_setsLastChoiceIndex_andNotifies() {
        let scene = makeScene()
        let dialogue = DialogueSystem()
        dialogue.attach(to: scene)

        var notified: Int?
        dialogue.onChoiceSelected = { notified = $0 }
        dialogue.start([
            .choice(prompt: "Choix ?", options: [
                DialogueChoice(title: "Un", responseSpeaker: "PNJ", response: "r1"),
                DialogueChoice(title: "Deux", responseSpeaker: "PNJ", response: "r2")
            ]),
            line("après")
        ])

        XCTAssertTrue(dialogue.hasChoicesOnScreen)
        dialogue.moveChoiceSelection(-1)   // descend sur l'option 2
        dialogue.confirmChoice()
        XCTAssertEqual(dialogue.lastChoiceIndex, 1)
        XCTAssertEqual(notified, 1)

        var completed = false
        // Le flux continue : titre du choix → réponse PNJ → ligne suivante.
        dialogue.advance()   // réponse PNJ
        dialogue.advance()   // ligne "après"
        dialogue.start([]) { completed = true }  // sanity : système réutilisable
        XCTAssertTrue(completed)
    }

    func test_skipToEnd_stopsAtChoice() {
        let scene = makeScene()
        let dialogue = DialogueSystem()
        dialogue.attach(to: scene)

        dialogue.start([
            line("1"), line("2"), line("3"),
            .choice(prompt: "Stop ?", options: [
                DialogueChoice(title: "Oui", responseSpeaker: "P", response: "r")
            ]),
            line("après le choix")
        ])
        dialogue.skipToEnd()
        XCTAssertTrue(dialogue.isActive)
        XCTAssertTrue(dialogue.hasChoicesOnScreen,
                      "B (skip) doit s'arrêter sur le choix, pas le sauter")
    }

    func test_skipToEnd_noChoice_completes() {
        let scene = makeScene()
        let dialogue = DialogueSystem()
        dialogue.attach(to: scene)

        var completed = false
        dialogue.start([line("1"), line("2"), line("3")]) { completed = true }
        dialogue.skipToEnd()
        XCTAssertTrue(completed)
        XCTAssertFalse(dialogue.isActive)
    }
}
