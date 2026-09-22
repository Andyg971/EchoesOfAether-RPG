import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Le routage TAP → ACTION de chaque zone (`try*Interaction`) : un tap au
/// bon endroit, dans le bon état d'histoire, déclenche la bonne chose — et
/// rien ailleurs. C'est exactement ce qui avait cassé au Sanctuaire (tout
/// tap à droite lançait le Gardien).
///
/// Chaque zone est reconstruite sur une vraie `SKScene` non présentée : les
/// POI sont calculés comme en production (fractions de `worldHeight` pour
/// les zones qui scrollent, layouts pour les autres). Les changements de
/// zone vivent dans un fondu (`SKAction`) : on observe l'état `.transition`.
@MainActor
final class InteractionRoutingTests: XCTestCase {

    private var gm: GameManager!
    private var scene: SKScene!
    private let size = CGSize(width: 844, height: 390)

    override func setUp() {
        super.setUp()
        gm = GameManager()
        gm.activeSlot = 3
        scene = SKScene(size: size)
        gm.scene = scene
        gm.world.build(in: scene)
        gm.hud.attach(to: scene)
        gm.bubble.attach(to: scene)
        gm.dialogue.attach(to: scene)
        gm.state = .exploration
    }

    override func tearDown() {
        SaveManager.delete(slot: 3)
        gm = nil; scene = nil
        super.tearDown()
    }

    private var w: CGFloat { size.width }
    /// Hauteur MONDE de la zone courante (les treks scrollent).
    private var wh: CGFloat { gm.world.worldHeight > 0 ? gm.world.worldHeight : size.height }
    private func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: w * fx, y: wh * fy) }
    /// Un point loin de tout POI.
    private var nowhere: CGPoint { CGPoint(x: 3, y: 3) }

    // MARK: - Forêt d'Ébène

    private func enterForest() {
        gm.phase = .forest
        gm.showForest(in: scene)
    }

    func test_forest_tapNowhere_doesNothing() {
        enterForest()
        XCTAssertFalse(gm.tryForestInteraction(nowhere, in: scene))
        XCTAssertEqual(gm.state, .exploration)
    }

    func test_forest_toy_onlyWhileQuestIsActive() {
        enterForest()
        let spot = p(0.80, 0.45)
        gm.player.questChildToy = .inactive
        XCTAssertFalse(gm.tryForestInteraction(spot, in: scene), "sans quête, le fourré est muet")

        gm.player.questChildToy = .active
        let gold = gm.player.gold
        XCTAssertTrue(gm.tryForestInteraction(spot, in: scene))
        XCTAssertEqual(gm.player.questChildToy, .complete)
        XCTAssertEqual(gm.player.gold, gold + 25)
    }

    func test_forest_sideQuestPickups_rewardAndComplete() {
        enterForest()
        gm.player.questMedallion = .active
        gm.player.questBramOre = .active
        gm.player.questSageHerb = .active
        gm.player.currentHP = 5
        let gold = gm.player.gold

        XCTAssertTrue(gm.tryForestInteraction(p(0.28, 0.72), in: scene), "talisman")
        XCTAssertEqual(gm.player.questMedallion, .complete)
        XCTAssertEqual(gm.state, .dialogue, "le ramassage se raconte")
        gm.state = .exploration

        XCTAssertTrue(gm.tryForestInteraction(p(0.40, 0.63), in: scene), "fer corrompu")
        XCTAssertEqual(gm.player.questBramOre, .complete)
        gm.state = .exploration

        XCTAssertTrue(gm.tryForestInteraction(p(0.12, 0.40), in: scene), "herbe lunaire")
        XCTAssertEqual(gm.player.questSageHerb, .complete)
        XCTAssertEqual(gm.player.currentHP, gm.player.currentMaxHP, "son parfum soigne")
        XCTAssertEqual(gm.player.gold, gold + 60 + 90 + 50)
    }

    func test_forest_completedPickup_isInert() {
        enterForest()
        gm.player.questMedallion = .complete
        XCTAssertFalse(gm.tryForestInteraction(p(0.28, 0.72), in: scene), "déjà ramassé")
    }

    func test_forest_shrineThreshold_needsClearedForestAndStoryVisit() {
        enterForest()
        let threshold = p(0.55, 0.90)
        gm.player.forestProgress = 1
        XCTAssertFalse(gm.tryForestInteraction(threshold, in: scene), "loups encore vivants")

        gm.player.forestProgress = 2
        gm.inForest = true
        XCTAssertFalse(gm.tryForestInteraction(threshold, in: scene),
                       "simple visite (Acte II+) : le seuil n'écrase pas l'acte en cours")

        gm.inForest = false
        XCTAssertTrue(gm.tryForestInteraction(threshold, in: scene))
        XCTAssertEqual(gm.state, .dialogue, "l'adieu à la forêt se joue avant le Sanctuaire")
    }

    func test_forest_mineAndCaveEntrances_startATransition() {
        enterForest()
        XCTAssertTrue(gm.tryForestInteraction(p(0.88, 0.30), in: scene), "bouche de mine")
        XCTAssertEqual(gm.state, .transition)
        gm.state = .exploration
        XCTAssertTrue(gm.tryForestInteraction(p(0.12, 0.80), in: scene), "caverne")
        XCTAssertEqual(gm.state, .transition)
    }

    // MARK: - Village de Solis

    func test_village_tapOnNPC_opensDialogue_andNowhereDoesNothing() {
        gm.phase = .village
        XCTAssertFalse(gm.tryVillageInteraction(nowhere, in: scene))
        XCTAssertTrue(gm.tryVillageInteraction(gm.world.lyra.position, in: scene))
        XCTAssertEqual(gm.state, .dialogue)
    }

    func test_village_tapOnHouseDoor_entersInterior() {
        gm.phase = .village
        let door = gm.world.houseDoorPosition(for: .armory, in: size)
        XCTAssertTrue(gm.tryVillageInteraction(door, in: scene))
        XCTAssertEqual(gm.activeInterior, .armory)
        XCTAssertEqual(gm.state, .transition)
    }

    func test_interior_exitAndCounter() {
        gm.phase = .village
        gm.activeInterior = .inn
        XCTAssertFalse(gm.tryInteriorInteraction(nowhere, in: scene))

        let counter = CGPoint(x: w * 0.50, y: size.height * 0.62)
        XCTAssertTrue(gm.tryInteriorInteraction(counter, in: scene))
        XCTAssertEqual(gm.state, .dialogue, "l'aubergiste parle")
        gm.state = .exploration

        XCTAssertTrue(gm.tryInteriorInteraction(gm.world.interiorExitPosition(in: size), in: scene))
        XCTAssertEqual(gm.state, .transition, "on ressort")
    }

    func test_interior_withoutActiveInterior_isInert() {
        gm.activeInterior = nil
        XCTAssertFalse(gm.tryInteriorInteraction(gm.world.interiorExitPosition(in: size), in: scene))
    }

    // MARK: - Ruines de la Source (Acte II)

    func test_ruins_inscriptionsGateOnProgress() {
        gm.phase = .ruins
        gm.showRuins(in: scene)
        let plan = RuinsLayout(sceneSize: size)

        gm.player.ruinsProgress = 1
        XCTAssertFalse(gm.tryRuinsInteraction(plan.discoveryWall, in: scene),
                       "la Découverte attend l'Archiviste")
        XCTAssertFalse(gm.tryRuinsInteraction(nowhere, in: scene))

        gm.player.act2EranFound = false
        XCTAssertTrue(gm.tryRuinsInteraction(plan.eranInscription, in: scene), "inscription d'Eran")
        XCTAssertEqual(gm.state, .dialogue)
        gm.state = .exploration
        gm.player.act2EranFound = true
        XCTAssertFalse(gm.tryRuinsInteraction(plan.eranInscription, in: scene), "déjà lue")

        gm.player.ruinsProgress = 2
        XCTAssertTrue(gm.tryRuinsInteraction(plan.discoveryWall, in: scene))
        XCTAssertNotEqual(gm.state, .exploration)
    }

    // MARK: - Le Seuil (Acte III)

    private func enterThreshold() {
        gm.phase = .act3
        gm.showThreshold(in: scene)
    }

    func test_act3_echoWaitsAtTheEntrance_untilJoined() throws {
        enterThreshold()
        let echo = try XCTUnwrap(gm.world.thresholdEchoPosition, "l'Écho est posé à l'entrée")
        gm.player.act3EchoJoined = false
        XCTAssertTrue(gm.tryAct3Interaction(echo, in: scene))
        XCTAssertEqual(gm.state, .dialogue)
    }

    func test_act3_stelesAndSpirits_onlyOnce() throws {
        enterThreshold()
        let plan = ThresholdLayout(sceneSize: size)
        gm.player.act3EchoJoined = true
        let stele = plan.steles[0]

        XCTAssertTrue(gm.tryAct3Interaction(stele.pos, in: scene))
        XCTAssertEqual(gm.state, .dialogue)
        gm.state = .exploration
        gm.player.act3StelesRead.insert(stele.id)
        XCTAssertFalse(gm.tryAct3Interaction(stele.pos, in: scene), "stèle déjà lue")

        let miner = try XCTUnwrap(gm.world.spiritPosition(id: "miner"), "le mineur erre au Seuil")
        XCTAssertTrue(gm.tryAct3Interaction(miner, in: scene), "esprit errant")
        gm.state = .exploration
        gm.player.act3SpiritsCalmed.insert("miner")
        XCTAssertFalse(gm.tryAct3Interaction(miner, in: scene), "esprit apaisé")
    }

    func test_act3_gateProgression_eranThenBossThenEnding() {
        enterThreshold()
        let plan = ThresholdLayout(sceneSize: size)
        gm.player.act3EchoJoined = true
        gm.player.act3StelesRead = ["1", "2", "3"]
        gm.player.act3SpiritsCalmed = ["miner", "mother", "guard"]

        gm.player.act3EranMet = false
        XCTAssertFalse(gm.tryAct3Interaction(plan.portal, in: scene), "le Seuil attend Eran")
        XCTAssertTrue(gm.tryAct3Interaction(plan.eran, in: scene))
        XCTAssertEqual(gm.state, .dialogue)
        gm.state = .exploration

        gm.player.act3EranMet = true
        gm.player.act3BossDefeated = false
        XCTAssertTrue(gm.tryAct3Interaction(plan.portal, in: scene), "le Gardien")
        XCTAssertNotEqual(gm.state, .exploration)
        gm.state = .exploration

        gm.player.act3BossDefeated = true
        XCTAssertTrue(gm.tryAct3Interaction(plan.portal, in: scene), "franchir le Seuil")
        XCTAssertNotEqual(gm.state, .exploration)
    }

    // MARK: - Le Cœur du Vide (Acte IV)

    private func enterVoidHeart() {
        gm.phase = .act4
        gm.showVoidHeart(in: scene)
    }

    func test_act4_memoriesAndReflections_onlyOnce() throws {
        enterVoidHeart()
        let plan = VoidHeartLayout(sceneSize: size)
        let memory = plan.memories[0]
        XCTAssertTrue(gm.tryAct4Interaction(memory.pos, in: scene))
        XCTAssertEqual(gm.state, .dialogue)
        gm.state = .exploration
        gm.player.act4MemoriesSeen.insert(memory.id)
        XCTAssertFalse(gm.tryAct4Interaction(memory.pos, in: scene), "souvenir déjà revu")

        let elder = try XCTUnwrap(gm.world.spiritPosition(id: "elder"), "l'Ancien est un reflet du Cœur")
        XCTAssertTrue(gm.tryAct4Interaction(elder, in: scene), "reflet absorbé")
        gm.state = .exploration
        gm.player.act4ReflectionsFreed.insert("elder")
        XCTAssertFalse(gm.tryAct4Interaction(elder, in: scene), "reflet libéré")
    }

    func test_act4_heartProgression_voiceThenAvatarThenEnding() {
        enterVoidHeart()
        let plan = VoidHeartLayout(sceneSize: size)
        gm.player.act4MemoriesSeen = ["1", "2", "3"]
        gm.player.act4ReflectionsFreed = ["elder", "smith", "lost"]

        gm.player.act4VoiceConfronted = false
        XCTAssertFalse(gm.tryAct4Interaction(plan.heart, in: scene), "le Cœur attend la Voix")
        XCTAssertTrue(gm.tryAct4Interaction(plan.voiceConfront, in: scene))
        XCTAssertEqual(gm.state, .dialogue)
        gm.state = .exploration

        gm.player.act4VoiceConfronted = true
        gm.player.act4BossDefeated = false
        XCTAssertTrue(gm.tryAct4Interaction(plan.heart, in: scene), "l'Avatar du Vide")
        XCTAssertNotEqual(gm.state, .exploration)
        gm.state = .exploration

        gm.player.act4BossDefeated = true
        XCTAssertTrue(gm.tryAct4Interaction(plan.heart, in: scene), "la fin")
        XCTAssertNotEqual(gm.state, .exploration)
    }

    // MARK: - Désert d'Ossara

    private func enterDesert() {
        gm.phase = .forest
        gm.inDesert = true
        gm.world.switchToDesert(in: scene, progress: gm.player.desertProgress,
                                chestTaken: gm.player.desertChestTaken)
    }

    func test_desert_npcChestOasisExit() {
        enterDesert()
        XCTAssertFalse(gm.tryDesertInteraction(nowhere, in: scene))

        XCTAssertTrue(gm.tryDesertInteraction(DesertPOI.npcMerchant.scaled(w: w, h: wh), in: scene))
        XCTAssertEqual(gm.state, .dialogue)
        gm.state = .exploration

        let gold = gm.player.gold
        let chest = CGPoint(x: w * 0.10, y: wh * DesertPOI.chestY)
        XCTAssertTrue(gm.tryDesertInteraction(chest, in: scene))
        XCTAssertTrue(gm.player.desertChestTaken)
        XCTAssertEqual(gm.player.gold, gold + 120)
        gm.state = .exploration
        XCTAssertFalse(gm.tryDesertInteraction(chest, in: scene), "coffre déjà pris")

        gm.player.currentHP = 1
        XCTAssertTrue(gm.tryDesertInteraction(DesertPOI.oasis.scaled(w: w, h: wh), in: scene))
        XCTAssertEqual(gm.player.currentHP, gm.player.currentMaxHP, "l'oasis restaure tout")
        XCTAssertTrue(gm.player.desertOasisUsed)
        gm.state = .exploration
        XCTAssertFalse(gm.tryDesertInteraction(DesertPOI.oasis.scaled(w: w, h: wh), in: scene),
                       "une fois par visite")

        XCTAssertTrue(gm.tryDesertInteraction(CGPoint(x: w * 0.50, y: wh * DesertPOI.exitY), in: scene))
        XCTAssertEqual(gm.state, .transition, "retour par le halo sud")
    }

    // MARK: - Mines de Cendreval

    func test_mines_plaqueVeinExit() {
        gm.phase = .forest
        gm.inMines = true
        gm.world.switchToMines(in: scene, progress: 0, goldTaken: false)

        XCTAssertFalse(gm.tryMinesInteraction(nowhere, in: scene))
        XCTAssertTrue(gm.tryMinesInteraction(MinesPOI.plaque.scaled(w: w, h: wh), in: scene))
        XCTAssertEqual(gm.state, .dialogue, "la plaque des mineurs se lit")
        gm.state = .exploration

        let gold = gm.player.gold
        XCTAssertTrue(gm.tryMinesInteraction(MinesPOI.goldVein.scaled(w: w, h: wh), in: scene))
        XCTAssertTrue(gm.player.minesGoldTaken)
        XCTAssertGreaterThan(gm.player.gold, gold)
        gm.state = .exploration
        XCTAssertFalse(gm.tryMinesInteraction(MinesPOI.goldVein.scaled(w: w, h: wh), in: scene),
                       "la veine est épuisée")

        XCTAssertTrue(gm.tryMinesInteraction(CGPoint(x: w * 0.50, y: wh * MinesPOI.exitY), in: scene))
        XCTAssertEqual(gm.state, .transition)
    }

    // MARK: - Caverne aux Échos

    func test_cave_chestOnlyAfterGuardian() {
        gm.phase = .forest
        gm.inCave = true
        gm.world.switchToCave(in: scene, cleared: false, chestTaken: false)
        let chest = CGPoint(x: w * 0.50, y: size.height * 0.68)

        gm.player.caveCleared = false
        XCTAssertFalse(gm.tryCaveInteraction(chest, in: scene), "le gardien veille encore")

        gm.player.caveCleared = true
        XCTAssertTrue(gm.tryCaveInteraction(chest, in: scene))
        XCTAssertTrue(gm.player.caveChestTaken)
        gm.state = .exploration
        XCTAssertFalse(gm.tryCaveInteraction(chest, in: scene), "coffre déjà pris")

        XCTAssertTrue(gm.tryCaveInteraction(CGPoint(x: w * 0.50, y: size.height * 0.08), in: scene))
        XCTAssertEqual(gm.state, .transition)
    }
}
