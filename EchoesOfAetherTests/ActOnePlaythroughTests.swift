import XCTest
import SpriteKit
@testable import EchoesOfAether

/// L'ACTE I JOUÉ DE BOUT EN BOUT, par le même chemin qu'un joueur :
/// `setup` sans sauvegarde → prologue → réveil chez Lyra → village → forêt →
/// Bête du bosquet → loups de la clairière → sortie sur la carte → Sanctuaire
/// → Gardien → fin d'acte → mur d'achat → Acte II → retour à Solis.
///
/// Les combats passent par la VRAIE boucle de tours (tour de Kael, tour de
/// Lyra, riposte ennemie, victoire différée, récompenses) ; seuls les PV
/// ennemis sont abaissés à 1 au tour du joueur — le but est de vérifier que
/// chaque maillon rend la main au suivant, pas l'équilibrage (verrouillé par
/// `EncounterBalanceTests`).
///
/// Lent (~40 s réelles). Un timeout = un maillon qui ne rappelle jamais sa
/// completion : un cul-de-sac que le joueur vivrait.
@MainActor
final class ActOnePlaythroughTests: XCTestCase {

    private var live: LiveScene!
    private var gm: GameManager!
    private var tutorialSeenBefore: Any?

    private func prepare() {
        tutorialSeenBefore = UserDefaults.standard.object(forKey: TutorialOverlay.seenKey)
        UserDefaults.standard.set(true, forKey: TutorialOverlay.seenKey)
        SaveManager.delete(slot: 3)
        live = LiveScene()
        gm = GameManager()
        gm.launchArguments = ["EchoesOfAether"]   // aucun drapeau d'audit
    }

    private func cleanup() {
        if let v = tutorialSeenBefore { UserDefaults.standard.set(v, forKey: TutorialOverlay.seenKey) }
        else { UserDefaults.standard.removeObject(forKey: TutorialOverlay.seenKey) }
        SaveManager.delete(slot: 3)
        live.tearDown()
        gm = nil; live = nil
    }

    // MARK: - Pilotage

    private var dialogue: DialogueSystem { gm.dialogue }

    private func waitFor(_ what: String, timeout: TimeInterval = 8,
                         file: StaticString = #filePath, line: UInt = #line,
                         _ condition: @escaping () -> Bool) {
        XCTAssertTrue(live.wait(until: condition, timeout: timeout),
                      "cul-de-sac : \(what) n'arrive jamais", file: file, line: line)
    }

    /// Passe tous les dialogues qui s'enchaînent jusqu'à rendre la main.
    private func playThroughDialogues(until state: GameState = .exploration,
                                      file: StaticString = #filePath, line: UInt = #line) {
        var guardCount = 0
        while gm.state != state, guardCount < 60 {
            guardCount += 1
            if dialogue.isActive { finishDialogue(dialogue) } else { live.wait(0.1) }
        }
        XCTAssertEqual(gm.state, state, "les dialogues ne rendent pas la main", file: file, line: line)
    }

    /// Gagne le combat en cours par la vraie boucle de tours.
    private func winCombat(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(gm.state, .combat, "pas de combat en cours", file: file, line: line)
        let deadline = Date(timeIntervalSinceNow: 30)
        var actions = 0
        while gm.state == .combat, Date() < deadline {
            if gm.combat.phase == .playerTurn {
                for foe in gm.combat.enemies where foe.combatant.isAlive { foe.combatant.hp = 1 }
                gm.combat.perform(.attack)
                actions += 1
            }
            live.wait(0.1)
        }
        XCTAssertNotEqual(gm.state, .combat, "le combat ne se termine jamais (\(actions) actions)",
                          file: file, line: line)
        XCTAssertFalse(gm.death.isActive, "Kael est mort", file: file, line: line)
    }

    private func tapEndScreenContinue(file: StaticString = #filePath, line: UInt = #line) {
        var found: SKNode?
        live.wait(until: {
            found = self.live.scene.childNode(withName: "//continueBtn")
            return (found?.xScale ?? 0) > 0.99
        }, timeout: 6)
        guard let node = found, let parent = node.parent else {
            XCTFail("écran de fin sans bouton Continuer", file: file, line: line); return
        }
        XCTAssertTrue(TransitionManager.handleEndScreenTap(
            at: live.scene.convert(node.position, from: parent), in: live.scene), file: file, line: line)
    }

    // MARK: - La partie

    func test_actOne_fromNewGameToActTwo() {
        prepare(); defer { cleanup() }

        // ── Nouvelle partie : prologue, réveil chez Lyra ──
        gm.setup(scene: live.scene, slot: 3)
        XCTAssertEqual(gm.phase, .wake)
        waitFor("le prologue") { self.gm.prologueNode != nil }
        gm.endPrologue()
        waitFor("le dialogue du réveil") { self.dialogue.isActive }
        playThroughDialogues()
        XCTAssertEqual(gm.phase, .village, "réveillé, Kael est au village")

        // ── Dorin ouvre la porte nord : sortie sur la carte ──
        XCTAssertFalse(gm.placeDiscovered("forest"), "la forêt attend l'accord de Dorin")
        XCTAssertTrue(gm.tryVillageInteraction(gm.world.dorin.position, in: live.scene))
        playThroughDialogues(until: .transition)
        waitFor("la carte du monde") { self.gm.inOverworld && self.gm.state == .exploration }
        XCTAssertEqual(gm.phase, .forest)

        // ── À pied jusqu'à la forêt ──
        gm.enterZoneFromMap("forest")
        waitFor("l'arrivée en forêt") { self.gm.state == .exploration && self.gm.phase == .forest }
        XCTAssertFalse(gm.roamers.isEmpty, "la Bête du bosquet rôde")

        // ── Combat 1 : la Bête du bosquet (au contact d'un rôdeur) ──
        let goldStart = gm.player.gold
        gm.startGroveCombat()
        winCombat()
        XCTAssertEqual(gm.player.forestProgress, 1)
        XCTAssertGreaterThan(gm.player.gold, goldStart, "l'or du combat est versé")
        playThroughDialogues()

        // ── Combat 2 : la meute de la clairière ──
        gm.startClearingCombat()
        winCombat()
        XCTAssertEqual(gm.player.forestProgress, 2)
        playThroughDialogues()
        XCTAssertTrue(gm.placeDiscovered("shrine"), "la forêt faite, le Sanctuaire s'ouvre")

        // ── Le sentier profond : adieu à la forêt, sortie sur la carte ──
        gm.enterShrine()
        playThroughDialogues(until: .transition)
        waitFor("la carte du monde") { self.gm.inOverworld && self.gm.state == .exploration }
        XCTAssertEqual(gm.phase, .shrine)

        // ── Le Sanctuaire, puis le Gardien ──
        gm.enterZoneFromMap("shrine")
        waitFor("l'arrivée au Sanctuaire") { !self.gm.inOverworld && self.gm.state == .exploration }
        gm.startBossFight()
        waitFor("la provocation du Gardien") { self.dialogue.isActive }
        playThroughDialogues(until: .combat)
        winCombat()
        XCTAssertTrue(gm.player.bossDefeated)

        // ── Fin de l'Acte I ──
        playThroughDialogues()
        XCTAssertEqual(gm.phase, .complete)
        tapEndScreenContinue()

        // ── Mur d'achat (verrouillé sur le simulateur) → Acte II ──
        if gm.isFullGameUnlocked {
            waitFor("l'Acte II") { self.gm.phase == .act2 }
        } else {
            XCTAssertEqual(gm.state, .shop, "la suite est derrière l'achat")
            XCTAssertNotNil(gm.pendingUnlockAction)
            gm.completeUnlock()   // simule un achat réussi
        }
        waitFor("la carte de l'Acte II") { self.gm.phase == .act2 && self.gm.inOverworld
                                             && self.gm.state == .exploration }

        // ── Retour à pied à Solis : retrouvailles, révélation ──
        gm.enterZoneFromMap("village")
        waitFor("les retrouvailles") { self.dialogue.isActive }
        playThroughDialogues()
        XCTAssertTrue(gm.player.act2Returned)
        XCTAssertEqual(gm.hud.objectiveText, String(localized: "hud.objective.ruins"),
                       "cap sur les Ruines : l'Acte II est lancé")
    }
}
