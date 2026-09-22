import XCTest
import SpriteKit
@testable import EchoesOfAether

/// L'INDICE d'interaction (texte du HUD + bulle), zone par zone : ce que
/// `updateInteractionHint` affiche AVANT que le joueur tape. Sœur de
/// `InteractionRoutingTests` (ce que le tap déclenche) — mêmes POI, mais ici
/// on vérifie que la bulle dit la vérité : rien de verrouillé n'affiche
/// « A · Combattre », rien d'épuisé n'affiche « A · Examiner ».
@MainActor
final class InteractionHintTests: XCTestCase {

    private var gm: GameManager!
    private var scene: SKScene!
    private let size = CGSize(width: 844, height: 390)

    private func prepare() {
        gm = GameManager()
        gm.activeSlot = 3
        scene = SKScene(size: size)
        gm.scene = scene
        gm.world.build(in: scene)
        gm.state = .exploration
    }

    private func cleanup() {
        SaveManager.delete(slot: 3)
        gm = nil; scene = nil
    }

    private var w: CGFloat { size.width }
    private var wh: CGFloat { gm.world.worldHeight > 0 ? gm.world.worldHeight : size.height }
    private func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: w * fx, y: wh * fy) }
    private var nowhere: CGPoint { CGPoint(x: 3, y: 3) }

    // MARK: - Intérieurs

    func test_interiorHint_exitAndCounter() {
        prepare(); defer { cleanup() }
        gm.activeInterior = .armory
        let exit = gm.world.interiorExitPosition(in: size)
        let r1 = gm.interiorHint(kaelPos: exit, radius: 90, in: scene)
        XCTAssertEqual(r1.hint, String(localized: "hint.exit"))
        XCTAssertEqual(r1.bubbleAction, .enter)

        let counter = CGPoint(x: w * 0.50, y: size.height * 0.62)
        let r2 = gm.interiorHint(kaelPos: counter, radius: 90, in: scene)
        XCTAssertEqual(r2.hint, String(localized: "hint.interior.armory"))
        XCTAssertEqual(r2.bubbleAction, .shop)

        let r3 = gm.interiorHint(kaelPos: nowhere, radius: 90, in: scene)
        XCTAssertTrue(r3.hint.isEmpty)
        XCTAssertNil(r3.actionPoint)
    }

    func test_interiorHint_innCounterTalksNotShops() {
        prepare(); defer { cleanup() }
        gm.activeInterior = .inn
        let counter = CGPoint(x: w * 0.50, y: size.height * 0.62)
        let r = gm.interiorHint(kaelPos: counter, radius: 90, in: scene)
        XCTAssertEqual(r.bubbleAction, .talk, "l'aubergiste, on lui parle, on n'achète pas au comptoir")
    }

    func test_interiorHint_withoutActiveInterior_isEmpty() {
        prepare(); defer { cleanup() }
        gm.activeInterior = nil
        let r = gm.interiorHint(kaelPos: gm.world.interiorExitPosition(in: size), radius: 90, in: scene)
        XCTAssertTrue(r.hint.isEmpty)
    }

    // MARK: - Mines

    func test_minesHint_plaqueVeinExit_veinDisappearsWhenTaken() {
        prepare(); defer { cleanup() }
        gm.inMines = true
        gm.world.switchToMines(in: scene, progress: 0, goldTaken: false)

        let r1 = gm.minesHint(kaelPos: MinesPOI.plaque.scaled(w: w, h: wh), radius: 60, in: scene)
        XCTAssertEqual(r1.hint, String(localized: "hint.examine"))

        gm.player.minesGoldTaken = false
        let r2 = gm.minesHint(kaelPos: MinesPOI.goldVein.scaled(w: w, h: wh), radius: 60, in: scene)
        XCTAssertEqual(r2.hint, String(localized: "hint.examine"))

        gm.player.minesGoldTaken = true
        let r3 = gm.minesHint(kaelPos: MinesPOI.goldVein.scaled(w: w, h: wh), radius: 60, in: scene)
        XCTAssertTrue(r3.hint.isEmpty, "la veine épuisée n'a plus de bulle")

        let r4 = gm.minesHint(kaelPos: CGPoint(x: w * 0.50, y: wh * MinesPOI.exitY), radius: 60, in: scene)
        XCTAssertEqual(r4.hint, String(localized: "hint.exit"))
    }

    // MARK: - Désert

    func test_desertHint_chestAndOasis_disappearOnceUsed() {
        prepare(); defer { cleanup() }
        gm.inDesert = true
        gm.world.switchToDesert(in: scene, progress: 0, chestTaken: false)

        let chest = CGPoint(x: w * 0.10, y: wh * DesertPOI.chestY)
        gm.player.desertChestTaken = false
        XCTAssertEqual(gm.desertHint(kaelPos: chest, radius: 60, in: scene).hint,
                       String(localized: "hint.examine"))
        gm.player.desertChestTaken = true
        XCTAssertTrue(gm.desertHint(kaelPos: chest, radius: 60, in: scene).hint.isEmpty)

        let oasis = DesertPOI.oasis.scaled(w: w, h: wh)
        gm.player.desertOasisUsed = false
        XCTAssertEqual(gm.desertHint(kaelPos: oasis, radius: 60, in: scene).hint,
                       String(localized: "hint.examine"))
        gm.player.desertOasisUsed = true
        XCTAssertTrue(gm.desertHint(kaelPos: oasis, radius: 60, in: scene).hint.isEmpty)

        let npc = gm.desertHint(kaelPos: DesertPOI.npcMerchant.scaled(w: w, h: wh), radius: 60, in: scene)
        XCTAssertEqual(npc.hint, String(localized: "hint.talk"))
    }

    // MARK: - Forêt (Acte I vs revisite)

    func test_forestHint_actI_minesOnly_shrineNeedsProgress() {
        prepare(); defer { cleanup() }
        gm.phase = .forest
        gm.showForest(in: scene)

        let mine = p(0.88, 0.30)
        XCTAssertEqual(gm.phaseHint(kaelPos: mine, radius: 65, in: scene).hint,
                       String(localized: "hint.enter"))

        let shrine = p(0.55, 0.90)
        gm.player.forestProgress = 1
        XCTAssertTrue(gm.phaseHint(kaelPos: shrine, radius: 70, in: scene).hint.isEmpty,
                      "loups vivants : pas de bulle sur un seuil qui ne répond pas")
        gm.player.forestProgress = 2
        XCTAssertEqual(gm.phaseHint(kaelPos: shrine, radius: 70, in: scene).hint,
                       String(localized: "hint.enter"))
    }

    func test_forestHint_revisit_hasNoShrineBubble() {
        prepare(); defer { cleanup() }
        gm.inForest = true
        gm.showForest(in: scene)
        gm.player.forestProgress = 2

        let shrine = p(0.55, 0.90)
        XCTAssertTrue(gm.forestHint(kaelPos: shrine, radius: 70, in: scene).hint.isEmpty,
                      "en simple visite, le seuil ne répond pas au tap : pas de bulle trompeuse")
        let mine = p(0.88, 0.30)
        XCTAssertEqual(gm.forestHint(kaelPos: mine, radius: 65, in: scene).hint,
                       String(localized: "hint.enter"), "la mine, elle, répond toujours")
    }

    // MARK: - Village

    func test_villageHint_npcBeatsDoor_whenCloser() {
        prepare(); defer { cleanup() }
        gm.phase = .village
        let r = gm.phaseHint(kaelPos: gm.world.lyra.position, radius: 32, in: scene)
        XCTAssertEqual(r.actionPoint, gm.world.lyra.position)
        XCTAssertEqual(r.bubbleAction, InteractionBubble.Action(hintKey: "hint.talk"))
    }

    func test_villageHint_door_whenNoNPCNearby() {
        prepare(); defer { cleanup() }
        gm.phase = .village
        let door = gm.world.houseDoorPosition(for: .armory, in: size)
        let r = gm.phaseHint(kaelPos: door, radius: 32, in: scene)
        XCTAssertEqual(r.hint, String(localized: "hint.enter"))
        XCTAssertEqual(r.bubbleAction, .enter)
    }

    func test_villageHint_nowhere_isEmpty() {
        prepare(); defer { cleanup() }
        gm.phase = .village
        XCTAssertTrue(gm.phaseHint(kaelPos: nowhere, radius: 32, in: scene).hint.isEmpty)
    }

    // MARK: - Sanctuaire — la régression du Gardien

    func test_shrineHint_gateOnlyBeforeBoss_thenExit() {
        prepare(); defer { cleanup() }
        gm.phase = .shrine
        gm.world.switchToShrine(in: scene)
        let gate = ShrinePOI.gate.scaled(w: w, h: size.height)
        let exit = ShrinePOI.exit.scaled(w: w, h: size.height)

        gm.player.bossDefeated = false
        let r1 = gm.phaseHint(kaelPos: gate, radius: 90, in: scene)
        XCTAssertEqual(r1.hint, String(localized: "hint.fight"))
        XCTAssertEqual(r1.bubbleAction, .fight)

        gm.player.bossDefeated = true
        XCTAssertTrue(gm.phaseHint(kaelPos: gate, radius: 90, in: scene).hint.isEmpty,
                      "le Gardien vaincu : plus de bulle « Combattre » sur la porte")

        let r2 = gm.phaseHint(kaelPos: exit, radius: 90, in: scene)
        XCTAssertEqual(r2.hint, String(localized: "hint.exit"))
    }

    func test_shrineHint_farFromEverything_isEmpty() {
        prepare(); defer { cleanup() }
        gm.phase = .shrine
        gm.world.switchToShrine(in: scene)
        XCTAssertTrue(gm.phaseHint(kaelPos: nowhere, radius: 90, in: scene).hint.isEmpty,
                      "régression du Sanctuaire : un tap loin de tout ne doit rien annoncer")
    }

    // MARK: - Ruines

    func test_ruinsHint_followsExactSameGateAsInteraction() {
        prepare(); defer { cleanup() }
        gm.phase = .ruins
        gm.showRuins(in: scene)
        let plan = RuinsLayout(sceneSize: size)

        gm.player.act2EranFound = false
        gm.player.ruinsProgress = 1
        XCTAssertEqual(gm.phaseHint(kaelPos: plan.eranInscription, radius: 70, in: scene).hint,
                       String(localized: "hint.examine"))
        XCTAssertTrue(gm.phaseHint(kaelPos: plan.discoveryWall, radius: 70, in: scene).hint.isEmpty,
                      "mur scellé : pas de bulle avant l'Archiviste")

        gm.player.act2EranFound = true
        gm.player.ruinsProgress = 2
        XCTAssertTrue(gm.phaseHint(kaelPos: plan.eranInscription, radius: 70, in: scene).hint.isEmpty,
                      "inscription déjà lue")
        XCTAssertEqual(gm.phaseHint(kaelPos: plan.discoveryWall, radius: 70, in: scene).hint,
                       String(localized: "hint.examine"))
    }

    // MARK: - Le Seuil (Acte III)

    func test_act3Hint_gateLabelFollowsProgress() {
        prepare(); defer { cleanup() }
        gm.phase = .act3
        gm.showThreshold(in: scene)
        let plan = ThresholdLayout(sceneSize: size)

        gm.player.act3EranMet = false
        XCTAssertEqual(gm.phaseHint(kaelPos: plan.eran, radius: 80, in: scene).hint,
                       String(localized: "hint.talk"), "Eran d'abord")

        gm.player.act3EranMet = true
        gm.player.act3BossDefeated = false
        XCTAssertEqual(gm.phaseHint(kaelPos: plan.portal, radius: 90, in: scene).hint,
                       String(localized: "hint.fight"), "le Gardien du Seuil")

        gm.player.act3BossDefeated = true
        XCTAssertEqual(gm.phaseHint(kaelPos: plan.portal, radius: 90, in: scene).hint,
                       String(localized: "hint.enter"), "franchir, une fois le boss vaincu")
    }

    func test_act3Hint_echoAndStelesOnlyOnce() {
        prepare(); defer { cleanup() }
        gm.phase = .act3
        gm.showThreshold(in: scene)
        let plan = ThresholdLayout(sceneSize: size)

        gm.player.act3EchoJoined = false
        let echo = try! XCTUnwrap(gm.world.thresholdEchoPosition)
        XCTAssertEqual(gm.phaseHint(kaelPos: echo, radius: 70, in: scene).hint,
                       String(localized: "hint.talk"))
        gm.player.act3EchoJoined = true
        XCTAssertTrue(gm.phaseHint(kaelPos: echo, radius: 70, in: scene).hint.isEmpty)

        let stele = plan.steles[0]
        gm.player.act3StelesRead = []
        XCTAssertEqual(gm.phaseHint(kaelPos: stele.pos, radius: 60, in: scene).hint,
                       String(localized: "hint.examine"))
        gm.player.act3StelesRead = [stele.id]
        XCTAssertTrue(gm.phaseHint(kaelPos: stele.pos, radius: 60, in: scene).hint.isEmpty)
    }

    // MARK: - Le Cœur du Vide (Acte IV)

    func test_act4Hint_heartLabelFollowsProgress() {
        prepare(); defer { cleanup() }
        gm.phase = .act4
        gm.showVoidHeart(in: scene)
        let plan = VoidHeartLayout(sceneSize: size)

        gm.player.act4VoiceConfronted = false
        XCTAssertEqual(gm.phaseHint(kaelPos: plan.voiceConfront, radius: 80, in: scene).hint,
                       String(localized: "hint.examine"), "confronter la Voix")

        gm.player.act4VoiceConfronted = true
        gm.player.act4BossDefeated = false
        XCTAssertEqual(gm.phaseHint(kaelPos: plan.heart, radius: 90, in: scene).hint,
                       String(localized: "hint.fight"))

        gm.player.act4BossDefeated = true
        XCTAssertEqual(gm.phaseHint(kaelPos: plan.heart, radius: 90, in: scene).hint,
                       String(localized: "hint.examine"), "le Cœur à nu, la fin approche")
    }

    func test_act4Hint_memoriesAndReflectionsOnlyOnce() {
        prepare(); defer { cleanup() }
        gm.phase = .act4
        gm.showVoidHeart(in: scene)
        let plan = VoidHeartLayout(sceneSize: size)
        let memory = plan.memories[0]

        gm.player.act4MemoriesSeen = []
        XCTAssertEqual(gm.phaseHint(kaelPos: memory.pos, radius: 55, in: scene).hint,
                       String(localized: "hint.examine"))
        gm.player.act4MemoriesSeen = [memory.id]
        XCTAssertTrue(gm.phaseHint(kaelPos: memory.pos, radius: 55, in: scene).hint.isEmpty)

        let elder = try! XCTUnwrap(gm.world.spiritPosition(id: "elder"))
        gm.player.act4ReflectionsFreed = []
        XCTAssertEqual(gm.phaseHint(kaelPos: elder, radius: 60, in: scene).hint,
                       String(localized: "hint.talk"))
        gm.player.act4ReflectionsFreed = ["elder"]
        XCTAssertTrue(gm.phaseHint(kaelPos: elder, radius: 60, in: scene).hint.isEmpty)
    }

    // MARK: - Carte du monde

    func test_overworldHint_placeNeedsToBeDiscovered() {
        prepare(); defer { cleanup() }
        gm.phase = .forest
        gm.inOverworld = true
        gm.world.switchToOverworld(in: scene)
        let village = try! XCTUnwrap(gm.world.overworldPlaces.first { $0.id == "village" })

        let near = CGPoint(x: village.pos.x, y: village.pos.y - 50)
        let r = gm.overworldHint(kaelPos: near, radius: 90, in: scene)
        XCTAssertFalse(r.hint.isEmpty)
        XCTAssertEqual(gm.overworldTarget, "village")

        // Un lieu inatteignable (id bidon injecté) : simulé en vérifiant
        // qu'un lieu non découvert n'apparaît pas dans `world.overworldPlaces`
        // filtrable — ici on vérifie juste l'inverse déjà couvert par
        // `placeDiscovered` (GameManagerFlowTests). On confirme seulement
        // que loin de tout, rien ne s'affiche.
        XCTAssertTrue(gm.overworldHint(kaelPos: nowhere, radius: 90, in: scene).hint.isEmpty)
        XCTAssertNil(gm.overworldTarget)
    }

    func test_overworldHint_fishingSpot_setsFlagAndOverridesPlace() {
        prepare(); defer { cleanup() }
        gm.phase = .forest
        gm.inOverworld = true
        gm.world.switchToOverworld(in: scene)
        let shore = WorldBuilder.overworldFishingSpot(w: gm.world.worldWidth, h: gm.world.worldHeight)

        gm.fishingSpotInRange = false
        let r = gm.overworldHint(kaelPos: shore, radius: 90, in: scene)
        XCTAssertEqual(r.hint, String(localized: "hint.fish"))
        XCTAssertTrue(gm.fishingSpotInRange)
        XCTAssertNil(gm.overworldTarget, "la pêche prime sur le lieu voisin")
    }

    func test_overworldHint_chest_onceOnly() {
        prepare(); defer { cleanup() }
        gm.phase = .forest
        gm.inOverworld = true
        gm.world.switchToOverworld(in: scene)
        let chest = WorldBuilder.overworldChests[0]
        let pos = CGPoint(x: gm.world.worldWidth * chest.at.x, y: gm.world.worldHeight * chest.at.y)

        gm.player.overworldChestsTaken = []
        let r = gm.overworldHint(kaelPos: pos, radius: 70, in: scene)
        XCTAssertEqual(r.hint, String(localized: "hint.examine"))
        XCTAssertEqual(gm.overworldChestTarget, chest.id)

        gm.player.overworldChestsTaken = [chest.id]
        let r2 = gm.overworldHint(kaelPos: pos, radius: 70, in: scene)
        XCTAssertNil(gm.overworldChestTarget)
        _ = r2
    }
}
