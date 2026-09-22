import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Le FLUX NARRATIF des Actes II à IV, joué de bout en bout dans une scène
/// vivante : les dialogues sont passés au bouton B, les choix pris au
/// bouton A, les cinématiques et fondus s'écoulent en temps réel. Ce que
/// ces tests verrouillent, c'est l'enchaînement — quel dialogue, quel
/// drapeau, quelle phase — et surtout les EMBRANCHEMENTS : complice ou
/// dépassé (Acte II), franchir ou résister (Acte III), détruire ou
/// fusionner (Acte IV). Un `if` inversé et une fin devient l'autre.
///
/// Lents (secondes réelles). Si un test échoue par timeout, c'est presque
/// toujours qu'une completion n'a pas été appelée : un cul-de-sac.
@MainActor
final class StoryActsFlowTests: XCTestCase {

    private var live: LiveScene!
    private var gm: GameManager!
    private var returnedToMenu = 0

    override func setUp() {
        super.setUp()
        live = LiveScene()
        gm = GameManager()
        gm.activeSlot = 3
        gm.scene = live.scene
        gm.attachOverlays(to: live.scene)   // construit aussi le monde
        gm.wireOverlayCallbacks()
        gm.onReturnToMenu = { [weak self] in self?.returnedToMenu += 1 }
        gm.state = .exploration
    }

    override func tearDown() {
        SaveManager.delete(slot: 3)
        live.tearDown()
        gm = nil; live = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var dialogue: DialogueSystem { gm.dialogue }

    /// Première réplique d'une table : sert à reconnaître QUEL dialogue est ouvert.
    private func firstLine(of steps: [DialogueStep]) -> String {
        for step in steps { if case let .line(_, text) = step { return text } }
        return ""
    }

    private func assertDialogueOpen(_ steps: [DialogueStep], _ what: String,
                                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(dialogue.isActive, "\(what) : aucun dialogue ouvert", file: file, line: line)
        XCTAssertEqual(dialogue.bodyLabel.text, firstLine(of: steps), what, file: file, line: line)
    }

    /// Attend qu'un dialogue s'ouvre (cinématique ou fondu en cours).
    private func waitForDialogue(_ timeout: TimeInterval = 8,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(live.wait(until: { self.dialogue.isActive }, timeout: timeout),
                      "aucun dialogue après \(timeout)s — cul-de-sac ?", file: file, line: line)
    }

    /// Tape le bouton d'un écran de fin / des crédits (après son apparition).
    private func tap(_ nodeName: String, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        // Les boutons apparaissent en popIn décalé (jusqu'à ~2 s sur l'écran
        // de fin d'acte) : on attend qu'il soit là ET à sa taille.
        var found: SKNode?
        live.wait(until: {
            found = self.live.scene.childNode(withName: "//\(nodeName)")
            return (found?.xScale ?? 0) > 0.99
        }, timeout: 6)
        guard let node = found, let parent = node.parent else {
            XCTFail("bouton \(nodeName) introuvable", file: file, line: line); return false
        }
        let point = live.scene.convert(node.position, from: parent)
        if nodeName == "creditsClose" {
            return TransitionManager.handleCreditsTap(at: point, in: live.scene)
        }
        return TransitionManager.handleEndScreenTap(at: point, in: live.scene)
    }

    // MARK: - Acte II : retour à Solis, Dorin, le Sage

    func test_act2_villageReturn_setsFlagsAndObjective() {
        gm.phase = .act2
        gm.playAct2VillageReturn()
        assertDialogueOpen(PrototypeContent.act2ReturnVillageDialogue, "retrouvailles")
        finishDialogue(dialogue)
        assertDialogueOpen(PrototypeContent.act2SageRevelationDialogue, "révélation du Sage enchaînée")
        finishDialogue(dialogue)

        XCTAssertTrue(gm.player.act2Returned)
        XCTAssertTrue(gm.player.act2SageConsulted)
        XCTAssertEqual(gm.state, .exploration)
        XCTAssertEqual(gm.hud.objectiveText, String(localized: "hud.objective.ruins"))
    }

    func test_act2_dorinGate_blocksThenDoubtsThenOpensRuins() {
        gm.phase = .act2
        gm.player.act2DorinPassed = false
        gm.handleAct2Dorin(scene: live.scene)
        assertDialogueOpen(PrototypeContent.act2DorinBlockDialogue, "Dorin bloque")
        finishDialogue(dialogue)
        XCTAssertTrue(gm.player.act2DorinPassed)
        XCTAssertEqual(gm.state, .exploration)

        gm.player.act2SageConsulted = false
        gm.handleAct2Dorin(scene: live.scene)
        assertDialogueOpen(PrototypeContent.act2DorinDoubtDialogue, "Dorin doute : voir le Sage d'abord")
        finishDialogue(dialogue)

        gm.player.act2SageConsulted = true
        gm.handleAct2Dorin(scene: live.scene)
        XCTAssertEqual(gm.state, .transition, "la porte nord s'ouvre")
        waitForDialogue()
        XCTAssertEqual(gm.phase, .ruins)
        assertDialogueOpen(PrototypeContent.act2RuinsEnterDialogue, "entrée des Ruines")
        finishDialogue(dialogue)
        XCTAssertTrue(gm.player.act2Vision1Seen, "la vision 1 suit automatiquement")
        XCTAssertGreaterThanOrEqual(gm.player.kaelCorruptionLevel, 1)
        assertDialogueOpen(PrototypeContent.act2Vision1Dialogue, "vision 1")
        finishDialogue(dialogue)
        XCTAssertEqual(gm.state, .exploration)
    }

    func test_act2_sage_nightmareThenInnThenRevelation() {
        gm.phase = .act2
        gm.player.act2NightmareSeen = false
        gm.handleAct2Sage(scene: live.scene)
        assertDialogueOpen(PrototypeContent.act2NightmareDialogue, "cauchemar")
        finishDialogue(dialogue)

        XCTAssertTrue(gm.player.act2NightmareSeen)
        XCTAssertEqual(gm.state, .shop, "au réveil, l'auberge")
        XCTAssertTrue(gm.shop.isActive)
        gm.shop.dismiss()

        assertDialogueOpen(PrototypeContent.act2SageRevelationDialogue, "révélation")
        finishDialogue(dialogue)
        XCTAssertTrue(gm.player.act2SageConsulted)
        XCTAssertEqual(gm.state, .exploration)
    }

    // MARK: - Acte II : la Découverte et la mort de Lyra (deux branches)

    /// Joue la Découverte jusqu'au dialogue « Kael seul » et rend celui-ci.
    private func playDiscovery(corruptionChoice: Int) {
        gm.phase = .ruins
        gm.player.ruinsProgress = 2
        gm.showRuins(in: live.scene)
        gm.corruptionCinematicShown = false

        gm.openDiscovery()
        assertDialogueOpen(PrototypeContent.act2LyraGiftDialogue, "le cadeau de Lyra")
        finishDialogue(dialogue)
        XCTAssertEqual(gm.player.kaelCorruptionLevel, 3)
        XCTAssertTrue(gm.player.loreDiscovered.contains("void"))
        XCTAssertTrue(gm.corruptionCinematicShown)

        waitForDialogue()   // cinématique de corruption (~3 s)
        assertDialogueOpen(PrototypeContent.act2DiscoveryDialogue, "la Découverte")
        finishDialogue(dialogue)
        assertDialogueOpen(PrototypeContent.act2CorruptionChoiceDialogue, "le choix")
        finishDialogue(dialogue, choosing: [corruptionChoice])

        XCTAssertTrue(gm.player.lyraDeceased, "la Tempête éclate quoi qu'il arrive")
        XCTAssertEqual(gm.state, .transition, "la scène de la frappe se joue")
        waitForDialogue()   // élan, frappe, chute (~2,5 s)
        assertDialogueOpen(PrototypeContent.act2LyraDeathDialogue, "derniers mots")
        finishDialogue(dialogue)
        waitForDialogue()   // dissolution (~1,5 s)
    }

    func test_act2_discovery_complice_endsActAndChainsToAct3() {
        playDiscovery(corruptionChoice: 0)
        XCTAssertTrue(gm.player.kaelChoseCorruption, "« Oui » = complice")
        assertDialogueOpen(PrototypeContent.act2KaelAloneDialogue, "Kael seul, complice")
        finishDialogue(dialogue)

        XCTAssertEqual(gm.phase, .fallen)
        XCTAssertEqual(gm.state, .exploration)
        XCTAssertTrue(tap("continueBtn"), "écran de fin d'Acte II → Continuer")
        XCTAssertTrue(tap("creditsClose"), "crédits → fermer")

        waitForDialogue()   // fondu vers le Seuil
        XCTAssertEqual(gm.phase, .act3, "l'Acte III s'ouvre")
        assertDialogueOpen(PrototypeContent.act3PrologueDialogue, "prologue de l'Acte III")
        finishDialogue(dialogue)
        XCTAssertEqual(gm.state, .exploration)
    }

    func test_act2_discovery_overwhelmed_playsResistedAftermath() {
        playDiscovery(corruptionChoice: 1)
        XCTAssertFalse(gm.player.kaelChoseCorruption, "« … » = dépassé par son pouvoir")
        assertDialogueOpen(PrototypeContent.act2KaelAloneResistedDialogue, "Kael seul, brisé")
        finishDialogue(dialogue)
        XCTAssertEqual(gm.phase, .fallen)
    }

    func test_act2_lastWords_mentionEranWhenFound() {
        gm.player.act2EranFound = true
        gm.phase = .ruins
        gm.player.ruinsProgress = 2
        gm.showRuins(in: live.scene)
        gm.corruptionCinematicShown = true   // flash seulement, pas de cinématique

        gm.openDiscovery()
        finishDialogue(dialogue)                       // cadeau
        assertDialogueOpen(PrototypeContent.act2DiscoveryDialogue, "Découverte (sans cinématique)")
        finishDialogue(dialogue)
        finishDialogue(dialogue, choosing: [0])        // choix
        waitForDialogue()
        assertDialogueOpen(PrototypeContent.act2LyraEranLastWordDialogue, "un mot pour Eran d'abord")
        finishDialogue(dialogue)
        assertDialogueOpen(PrototypeContent.act2LyraDeathDialogue, "puis les derniers mots")
    }

    // MARK: - Acte III : Eran, le choix, les deux fins

    private func enterAct3() {
        gm.phase = .act3
        gm.showThreshold(in: live.scene)
    }

    func test_act3_eranMeet_capturesResistChoice_andWarningCanReconsider() {
        enterAct3()
        gm.openAct3EranMeet()
        assertDialogueOpen(PrototypeContent.act3EranMeetDialogue, "Eran")
        finishDialogue(dialogue, choosing: [1])        // « L'Aether me contrôle »
        XCTAssertEqual(gm.player.act3EndingChoice, 1)
        XCTAssertTrue(gm.player.act3EranMet)
        XCTAssertTrue(gm.player.loreDiscovered.isSuperset(of: ["threshold", "price"]))
        assertDialogueOpen(PrototypeContent.act3ResistWarningDialogue, "garde-fou : résister saute l'Acte IV")
        finishDialogue(dialogue, choosing: [1])        // reconsidère
        XCTAssertEqual(gm.player.act3EndingChoice, 0, "reconsidéré : franchir")
        assertDialogueOpen(PrototypeContent.act3EranJoinDialogue, "Eran rejoint")
        finishDialogue(dialogue)
        XCTAssertEqual(gm.state, .exploration)
    }

    func test_act3_eranMeet_crossChoice_skipsWarning() {
        enterAct3()
        gm.openAct3EranMeet()
        finishDialogue(dialogue, choosing: [0])
        XCTAssertEqual(gm.player.act3EndingChoice, 0)
        assertDialogueOpen(PrototypeContent.act3EranJoinDialogue, "pas de garde-fou pour « franchir »")
    }

    func test_act3_resistEnding_rollsCreditsToMenu() {
        enterAct3()
        gm.player.act3EndingChoice = 1
        gm.showAct3TrueEnding()
        assertDialogueOpen(PrototypeContent.act3ResistEndingDialogue, "résister")
        finishDialogue(dialogue)
        assertDialogueOpen(PrototypeContent.act3ResistEpilogueDialogue, "épilogue")
        finishDialogue(dialogue)
        XCTAssertTrue(tap("creditsClose"))
        XCTAssertEqual(returnedToMenu, 1, "la fin Résister rend au menu")
    }

    func test_act3_crossEnding_warningCanStay_orOpensAct4() {
        enterAct3()
        gm.player.act3EndingChoice = 0
        gm.showAct3TrueEnding()
        assertDialogueOpen(PrototypeContent.act4ThresholdWarningDialogue, "point de non-retour")
        finishDialogue(dialogue, choosing: [1])        // « Rester »
        XCTAssertEqual(gm.state, .exploration, "demi-tour : on explore encore")
        XCTAssertEqual(gm.phase, .act3)

        gm.showAct3TrueEnding()
        finishDialogue(dialogue, choosing: [0])        // « Franchir »
        assertDialogueOpen(PrototypeContent.act3TrueEndingDialogue, "franchir")
        finishDialogue(dialogue)
        assertDialogueOpen(PrototypeContent.act3EndingTransitionDialogue, "la Voix annonce la suite")
        finishDialogue(dialogue)
        waitForDialogue()   // fondu vers le Cœur
        XCTAssertEqual(gm.phase, .act4)
        XCTAssertTrue(gm.player.loreDiscovered.contains("voidheart"))
        assertDialogueOpen(PrototypeContent.act4PrologueDialogue, "prologue de l'Acte IV")
        finishDialogue(dialogue)
        XCTAssertEqual(gm.state, .exploration)
    }

    // MARK: - Acte IV : la Voix, les deux fins × les deux passés

    private func enterAct4() {
        gm.phase = .act4
        gm.showVoidHeart(in: live.scene)
    }

    func test_act4_voiceConfront_capturesChoice() {
        enterAct4()
        gm.openAct4VoiceConfront()
        assertDialogueOpen(PrototypeContent.act4VoiceConfrontDialogue, "la Voix")
        finishDialogue(dialogue, choosing: [1])
        XCTAssertEqual(gm.player.act4EndingChoice, 1, "fusionner")
        XCTAssertTrue(gm.player.act4VoiceConfronted)
        XCTAssertEqual(gm.state, .exploration)
        XCTAssertNil(dialogue.onChoiceSelected, "le capteur de choix est débranché")
    }

    private func playAct4Ending(choice: Int, choseCorruption: Bool,
                                expectReflection: [DialogueStep], expectEnding: [DialogueStep],
                                expectScreen: [DialogueStep]) {
        enterAct4()
        gm.player.act4EndingChoice = choice
        gm.player.kaelChoseCorruption = choseCorruption
        gm.showAct4Ending()
        assertDialogueOpen(expectReflection, "réflexion (écho du choix de l'Acte II)")
        finishDialogue(dialogue)
        assertDialogueOpen(expectEnding, "la fin")
        finishDialogue(dialogue)
        assertDialogueOpen(expectScreen, "écran de fin")
        finishDialogue(dialogue)
        XCTAssertTrue(tap("creditsClose"))
        XCTAssertEqual(returnedToMenu, 1, "retour au menu")
    }

    func test_act4_destroyEnding_asComplice() {
        playAct4Ending(choice: 0, choseCorruption: true,
                       expectReflection: PrototypeContent.act4DestroyChoseDialogue,
                       expectEnding: PrototypeContent.act4DestroyEndingDialogue,
                       expectScreen: PrototypeContent.act4DestroyEndScreen)
    }

    func test_act4_destroyEnding_asResisted() {
        playAct4Ending(choice: 0, choseCorruption: false,
                       expectReflection: PrototypeContent.act4DestroyResistedDialogue,
                       expectEnding: PrototypeContent.act4DestroyEndingDialogue,
                       expectScreen: PrototypeContent.act4DestroyEndScreen)
    }

    func test_act4_mergeEnding_asComplice() {
        playAct4Ending(choice: 1, choseCorruption: true,
                       expectReflection: PrototypeContent.act4MergeChoseDialogue,
                       expectEnding: PrototypeContent.act4MergeEndingDialogue,
                       expectScreen: PrototypeContent.act4MergeEndScreen)
    }

    func test_act4_mergeEnding_asResisted() {
        playAct4Ending(choice: 1, choseCorruption: false,
                       expectReflection: PrototypeContent.act4MergeResistedDialogue,
                       expectEnding: PrototypeContent.act4MergeEndingDialogue,
                       expectScreen: PrototypeContent.act4MergeEndScreen)
    }
}
