import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Tests anti-régression des culs-de-sac de progression (cf. 3110ebd,
/// c5ade62) : chaque écran de fin doit avoir une continuation déclenchable,
/// et les dialogues pivots de l'histoire doivent être présents et localisés.
@MainActor
final class StoryFlowTests: XCTestCase {

    // MARK: - Écrans de fin : la continuation doit se déclencher

    /// Sans SKView, les SKActions ne tournent pas : JuiceEngine.popIn laisse
    /// les nœuds à scale 0 (frame nulle). On restaure pour le hit-test.
    private func settleAnimations(in scene: SKScene) {
        func restore(_ node: SKNode) {
            node.setScale(1)
            node.alpha = 1
            node.children.forEach(restore)
        }
        scene.children.forEach(restore)
    }

    func test_act1EndScreen_continueTap_firesContinuation() {
        let scene = SKScene(size: CGSize(width: 800, height: 400))
        var continued = false
        TransitionManager.showEndScreen(in: scene, resonance: 3) { continued = true }
        settleAnimations(in: scene)

        // Bouton Continuer : overlay centré, bouton à (0, -100).
        let tap = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2 - 100)
        XCTAssertTrue(TransitionManager.handleEndScreenTap(at: tap, in: scene))
        XCTAssertTrue(continued, "Le bouton Continuer de l'Acte I doit lancer la suite")
    }

    func test_act2EndScreen_continueTap_firesContinuation() {
        let scene = SKScene(size: CGSize(width: 800, height: 400))
        var continued = false
        TransitionManager.showAct2EndScreen(in: scene) { continued = true }
        settleAnimations(in: scene)

        // Bouton Continuer de l'Acte II à (0, -126).
        let tap = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2 - 126)
        XCTAssertTrue(TransitionManager.handleEndScreenTap(at: tap, in: scene))
        XCTAssertTrue(continued, "Le bouton Continuer de l'Acte II doit lancer la suite (régression c5ade62)")
    }

    func test_endScreenTap_outsideButton_doesNothing() {
        let scene = SKScene(size: CGSize(width: 800, height: 400))
        var continued = false
        TransitionManager.showEndScreen(in: scene, resonance: 0) { continued = true }

        XCTAssertFalse(TransitionManager.handleEndScreenTap(at: .zero, in: scene))
        XCTAssertFalse(continued)
        // Nettoyage : consomme l'overlay pour ne pas polluer les autres tests.
        let tap = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2 - 100)
        _ = TransitionManager.handleEndScreenTap(at: tap, in: scene)
    }

    // MARK: - Dialogues pivots : présents, non vides, localisés

    /// Les dialogues sans lesquels la progression d'acte casse.
    private var pivotalDialogues: [(String, [DialogueStep])] {
        [
            ("wakeDialogue", PrototypeContent.wakeDialogue),
            ("lyraVillageDialogue", PrototypeContent.lyraVillageDialogue),
            ("lyraQuestGiveDialogue", PrototypeContent.lyraQuestGiveDialogue),
            ("bossPreDialogue", PrototypeContent.bossPreDialogue),
            ("bossPostDialogue", PrototypeContent.bossPostDialogue),
            ("shrineEnding", PrototypeContent.shrineEnding),
            ("act2ReturnVillageDialogue", PrototypeContent.act2ReturnVillageDialogue),
            ("act2LyraDeathDialogue", PrototypeContent.act2LyraDeathDialogue),
            ("act2KaelAloneDialogue", PrototypeContent.act2KaelAloneDialogue),
            ("act3PrologueDialogue", PrototypeContent.act3PrologueDialogue),
            ("act3EranMeetDialogue", PrototypeContent.act3EranMeetDialogue),
            ("act3TrueEndingDialogue", PrototypeContent.act3TrueEndingDialogue),
            ("act3ResistEndingDialogue", PrototypeContent.act3ResistEndingDialogue),
            ("act3ResistEpilogueDialogue", PrototypeContent.act3ResistEpilogueDialogue),
            ("act4PrologueDialogue", PrototypeContent.act4PrologueDialogue),
            ("act4DestroyEndingDialogue", PrototypeContent.act4DestroyEndingDialogue),
            ("act4MergeEndingDialogue", PrototypeContent.act4MergeEndingDialogue)
        ]
    }

    private func texts(of steps: [DialogueStep]) -> [String] {
        steps.flatMap { step -> [String] in
            switch step {
            case let .line(speaker, text):
                return [speaker, text]
            case let .choice(prompt, options):
                return [prompt] + options.flatMap { [$0.title, $0.responseSpeaker, $0.response] }
            }
        }
    }

    func test_pivotalDialogues_nonEmpty() {
        for (name, steps) in pivotalDialogues {
            XCTAssertFalse(steps.isEmpty, "\(name) est vide — la progression casserait")
        }
    }

    func test_pivotalDialogues_allTextsLocalized() {
        for (name, steps) in pivotalDialogues {
            for text in texts(of: steps) {
                XCTAssertFalse(text.isEmpty, "\(name) : texte vide")
                XCTAssertFalse(text.hasPrefix("dialogue."),
                               "\(name) : clé non traduite « \(text) »")
            }
        }
    }

    func test_resistEpilogue_isRealContent() {
        // La fin « Résister » n'est plus un placeholder de 2 lignes.
        XCTAssertGreaterThanOrEqual(PrototypeContent.act3ResistEpilogueDialogue.count, 10,
                                    "L'épilogue Résister doit rester une vraie fin")
    }

    func test_choices_haveAtLeastTwoOptions() {
        for (name, steps) in pivotalDialogues {
            for step in steps {
                if case let .choice(_, options) = step {
                    XCTAssertGreaterThanOrEqual(options.count, 2,
                                                "\(name) : un choix à moins de 2 options")
                }
            }
        }
    }
}
