import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Ce qui casse une PARTIE sans casser le build : les verrous de la carte du
/// monde (anti-saut de scénario), la reprise d'une sauvegarde dans la bonne
/// zone, le mur d'achat qui reprend l'action interrompue, la potion.
///
/// Logique d'état pure, ou presque : les tests qui reconstruisent une zone
/// posent une vraie `SKScene` (non présentée — aucune `SKAction` ne tourne).
/// Les sauvegardes passent par le slot 3 du bac à sable de test, effacé après.
@MainActor
final class GameManagerFlowTests: XCTestCase {

    private var gm: GameManager!
    /// `GameManager.scene` est `weak` : la scène doit vivre ici le temps du test.
    private var heldScene: SKScene?
    /// Slot scratch : `transition(to: .exploration)` sauvegarde à chaque fois.
    private let scratchSlot = 3



    /// Un GameManager avec monde et HUD posés sur une scène : le minimum pour
    /// reconstruire une zone (`restoreFrom`, `showForest`…).
    private func makeSceneBackedManager() -> SKScene {
        let scene = SKScene(size: CGSize(width: 844, height: 390))
        gm.scene = scene
        gm.world.build(in: scene)
        gm.hud.attach(to: scene)
        gm.bubble.attach(to: scene)
        heldScene = scene
        return scene
    }

    // XCTest déclare setUp/tearDown non isolés et interdit de les isoler : l'état
    // @MainActor se prépare donc au début de chaque test (`prepare()` + `defer`).
    private func prepare() {
        gm = GameManager()
        gm.activeSlot = scratchSlot
    }

    private func cleanup() {
        SaveManager.delete(slot: scratchSlot)
        gm = nil
        heldScene = nil
    }

    // MARK: - Verrous de la carte du monde (anti-saut de scénario)

    func test_placeDiscovered_atWake_onlyVillageIsOpen() {
        prepare()
        defer { cleanup() }
        gm.phase = .wake
        XCTAssertTrue(gm.placeDiscovered("village"))
        for id in ["forest", "shrine", "mines", "desert", "ruins", "threshold"] {
            XCTAssertFalse(gm.placeDiscovered(id), "\(id) doit rester fermé au réveil")
        }
    }

    func test_placeDiscovered_atForest_opensExcursionsButNotShrine() {
        prepare()
        defer { cleanup() }
        gm.phase = .forest
        XCTAssertTrue(gm.placeDiscovered("forest"))
        XCTAssertTrue(gm.placeDiscovered("mines"), "excursion optionnelle dès la forêt")
        XCTAssertTrue(gm.placeDiscovered("desert"), "voyage optionnel dès la forêt")
        XCTAssertFalse(gm.placeDiscovered("shrine"), "le Sanctuaire se gagne")
        XCTAssertFalse(gm.placeDiscovered("ruins"))
        XCTAssertFalse(gm.placeDiscovered("threshold"))
    }

    /// Les loups de la clairière vaincus (`forestProgress == 2`) ouvrent le
    /// Sanctuaire même si la phase n'a pas encore basculé.
    func test_placeDiscovered_shrineOpensOnceForestIsCleared() {
        prepare()
        defer { cleanup() }
        gm.phase = .forest
        gm.player.forestProgress = 2
        XCTAssertTrue(gm.placeDiscovered("shrine"))
    }

    func test_placeDiscovered_followsStoryPhases() {
        prepare()
        defer { cleanup() }
        gm.phase = .ruins
        XCTAssertTrue(gm.placeDiscovered("ruins"))
        XCTAssertFalse(gm.placeDiscovered("threshold"))
        gm.phase = .act3
        XCTAssertTrue(gm.placeDiscovered("threshold"))
        XCTAssertTrue(gm.placeDiscovered("shrine"), "tout ce qui précède reste ouvert")
    }

    func test_placeDiscovered_visitedPlaceStaysOpen() {
        prepare()
        defer { cleanup() }
        gm.phase = .wake
        gm.discoveredPlaces.insert("desert")
        XCTAssertTrue(gm.placeDiscovered("desert"), "déjà visité = toujours voyageable")
    }

    func test_placeDiscovered_unknownIdIsClosed() {
        prepare()
        defer { cleanup() }
        gm.phase = .act4
        XCTAssertFalse(gm.placeDiscovered("voidheart"), "le Cœur du Vide n'est pas un lieu de carte")
        XCTAssertFalse(gm.placeDiscovered("atlantide"))
    }

    // MARK: - Entrer dans un lieu depuis la carte

    /// La partie SYNCHRONE d'`enterZoneFromMap` : le verrou d'histoire, puis
    /// la sortie de la carte et l'inscription du lieu visité. Le changement
    /// de zone lui-même vit dans le fondu (SKAction) — hors de portée ici.
    func test_enterZoneFromMap_lockedPlace_changesNothing() {
        prepare()
        defer { cleanup() }
        _ = makeSceneBackedManager()
        gm.phase = .forest
        gm.inOverworld = true
        gm.state = .exploration

        gm.enterZoneFromMap("threshold")

        XCTAssertTrue(gm.inOverworld, "Kael reste sur la carte")
        XCTAssertEqual(gm.state, .exploration, "aucun fondu lancé")
        XCTAssertFalse(gm.discoveredPlaces.contains("threshold"))
        XCTAssertEqual(gm.phase, .forest)
    }

    func test_enterZoneFromMap_openPlace_leavesMapAndRemembersVisit() {
        prepare()
        defer { cleanup() }
        _ = makeSceneBackedManager()
        gm.phase = .forest
        gm.inOverworld = true

        gm.enterZoneFromMap("mines")

        XCTAssertFalse(gm.inOverworld)
        XCTAssertTrue(gm.discoveredPlaces.contains("mines"), "visité → voyage rapide déverrouillé")
        XCTAssertEqual(gm.state, .transition, "le fondu vers la zone est engagé")
    }

    // MARK: - Coffres de la carte du monde

    func test_openOverworldChest_rewardsOnceOnly() {
        prepare()
        defer { cleanup() }
        _ = makeSceneBackedManager()
        let chest = try! XCTUnwrap(WorldBuilder.overworldChests.first { $0.id == "summit" })
        let gold = gm.player.gold, shards = gm.player.aetherShards

        gm.openOverworldChest("summit")
        XCTAssertEqual(gm.player.gold, gold + chest.gold)
        XCTAssertEqual(gm.player.aetherShards, shards + chest.shards)
        XCTAssertTrue(gm.player.overworldChestsTaken.contains("summit"))

        gm.openOverworldChest("summit")
        XCTAssertEqual(gm.player.gold, gold + chest.gold, "un coffre ne se rouvre pas")
    }

    func test_openOverworldChest_unknownIdIsIgnored() {
        prepare()
        defer { cleanup() }
        _ = makeSceneBackedManager()
        let gold = gm.player.gold
        gm.openOverworldChest("eldorado")
        XCTAssertEqual(gm.player.gold, gold)
        XCTAssertTrue(gm.player.overworldChestsTaken.isEmpty)
    }

    // MARK: - Disponibilité de la carte

    func test_worldMapAvailable_onlyInFreePhases() {
        prepare()
        defer { cleanup() }
        gm.phase = .village
        XCTAssertFalse(gm.worldMapAvailable, "Acte I au village : pas de carte")
        gm.phase = .forest
        XCTAssertTrue(gm.worldMapAvailable)
        gm.phase = .act2
        XCTAssertTrue(gm.worldMapAvailable)
        gm.phase = .act3
        XCTAssertFalse(gm.worldMapAvailable, "le Seuil ne se quitte pas")
    }

    func test_worldMapAvailable_neverFromMinesOrInterior() {
        prepare()
        defer { cleanup() }
        gm.phase = .forest
        gm.inMines = true
        XCTAssertFalse(gm.worldMapAvailable)
        gm.inMines = false
        gm.activeInterior = .inn
        XCTAssertFalse(gm.worldMapAvailable)
    }

    func test_worldMapAvailable_alwaysFromOverworldAndDesert() {
        prepare()
        defer { cleanup() }
        gm.phase = .village
        gm.inOverworld = true
        XCTAssertTrue(gm.worldMapAvailable, "sur la carte : bouton = voyage rapide")
        gm.inOverworld = false
        gm.inDesert = true
        XCTAssertTrue(gm.worldMapAvailable, "le désert se quitte par la carte")
    }

    func test_currentPlaceID_excursionsWinOverPhase() {
        prepare()
        defer { cleanup() }
        gm.phase = .act2
        XCTAssertEqual(gm.currentPlaceID, "village")
        gm.inForest = true
        XCTAssertEqual(gm.currentPlaceID, "forest")
        gm.inMines = true
        XCTAssertEqual(gm.currentPlaceID, "mines", "les mines priment sur la forêt")
        gm.inDesert = true
        XCTAssertEqual(gm.currentPlaceID, "desert", "le désert prime sur tout")
    }

    func test_currentPlaceID_mapsEveryPhase() {
        prepare()
        defer { cleanup() }
        let expected: [GamePhase: String] = [
            .wake: "village", .village: "village", .forest: "forest", .shrine: "shrine",
            .complete: "village", .act2: "village", .ruins: "ruins", .fallen: "village",
            .act3: "threshold", .act4: "voidheart"
        ]
        for (phase, id) in expected {
            gm.phase = phase
            XCTAssertEqual(gm.currentPlaceID, id, "phase \(phase)")
        }
    }

    // MARK: - Potion en exploration

    func test_useHealthPotion_healsFortyPercentAndConsumes() {
        prepare()
        defer { cleanup() }
        gm.player.potions = 1
        gm.player.currentHP = 100
        let expected = min(gm.player.currentMaxHP,
                           100 + Int(CGFloat(gm.player.currentMaxHP) * 0.40))
        XCTAssertTrue(gm.useHealthPotion())
        XCTAssertEqual(gm.player.currentHP, expected)
        XCTAssertEqual(gm.player.potions, 0)
    }

    func test_useHealthPotion_refusesWithoutStockOrAtFullHP() {
        prepare()
        defer { cleanup() }
        gm.player.potions = 0
        gm.player.currentHP = 10
        XCTAssertFalse(gm.useHealthPotion(), "pas de fiole")
        gm.player.potions = 1
        gm.player.currentHP = gm.player.currentMaxHP
        XCTAssertFalse(gm.useHealthPotion(), "PV pleins : la fiole n'est pas gaspillée")
        XCTAssertEqual(gm.player.potions, 1)
    }

    // MARK: - Mur d'achat : reprendre l'action interrompue

    /// Sans scène, `openPaywall` ne fait rien : on observe juste que l'action
    /// est mise en attente puis rejouée EXACTEMENT une fois au déverrouillage.
    func test_requireFullGame_deferredActionResumesOnUnlock() {
        prepare()
        defer { cleanup() }
        let wasUnlocked = StoreManager.shared.isUnlocked
        StoreManager.shared.setUnlockedForTesting(false)   // mur d'achat actif
        defer { StoreManager.shared.setUnlockedForTesting(wasUnlocked) }
        var calls = 0
        gm.requireFullGame { calls += 1 }
        XCTAssertEqual(calls, 0, "verrouillé : l'action attend")
        XCTAssertNotNil(gm.pendingUnlockAction)

        gm.completeUnlock()
        XCTAssertEqual(calls, 1, "déverrouillé : l'action reprend")
        XCTAssertNil(gm.pendingUnlockAction, "et n'est pas rejouable")

        gm.completeUnlock()
        XCTAssertEqual(calls, 1)
    }

    func test_dismissPaywall_dropsTheDeferredAction() {
        prepare()
        defer { cleanup() }
        let wasUnlocked = StoreManager.shared.isUnlocked
        StoreManager.shared.setUnlockedForTesting(false)   // mur d'achat actif
        defer { StoreManager.shared.setUnlockedForTesting(wasUnlocked) }
        var calls = 0
        gm.requireFullGame { calls += 1 }
        gm.dismissPaywall()
        XCTAssertNil(gm.pendingUnlockAction)
        gm.completeUnlock()
        XCTAssertEqual(calls, 0, "« Plus tard » abandonne l'action, elle ne ressurgit pas")
    }

    // MARK: - Reprise d'une sauvegarde : la bonne zone, l'état propre

    private func save(phase: GamePhase, resonance: Int = 0,
                      _ tweak: (PlayerState) -> Void = { _ in }) -> SaveData {
        let p = PlayerState()
        tweak(p)
        return p.toSaveData(phase: phase, resonance: resonance)
    }

    func test_restore_village_restoresPlayerAndExplores() {
        prepare()
        defer { cleanup() }
        let scene = makeSceneBackedManager()
        let data = save(phase: .village, resonance: 7) { $0.gold = 123; $0.potions = 2 }

        gm.restoreFrom(save: data, scene: scene)

        XCTAssertEqual(gm.phase, .village)
        XCTAssertEqual(gm.state, .exploration)
        XCTAssertEqual(gm.player.gold, 123)
        XCTAssertEqual(gm.player.potions, 2)
        XCTAssertEqual(gm.resonanceTotal, 7)
        XCTAssertEqual(gm.hud.goldValue, 123, "le HUD lit la save, pas l'état neuf")
        XCTAssertEqual(gm.hud.resonanceValue, 7)
        XCTAssertFalse(gm.hud.objectiveText.isEmpty)
    }

    /// Une save faite aux mines ou au désert reprend en zone d'ORIGINE : ces
    /// excursions ne sont jamais stockées.
    func test_restore_clearsExcursionFlags() {
        prepare()
        defer { cleanup() }
        let scene = makeSceneBackedManager()
        gm.inMines = true
        gm.inDesert = true

        gm.restoreFrom(save: save(phase: .village), scene: scene)

        XCTAssertFalse(gm.inMines)
        XCTAssertFalse(gm.inDesert)
    }

    func test_restore_forest_placesKaelAtSouthEdgeAndSpawnsRoamers() {
        prepare()
        defer { cleanup() }
        let scene = makeSceneBackedManager()

        gm.restoreFrom(save: save(phase: .forest), scene: scene)

        XCTAssertEqual(gm.phase, .forest)
        XCTAssertEqual(gm.state, .exploration)
        XCTAssertGreaterThan(gm.world.worldHeight, scene.size.height, "la forêt est un trek qui scrolle")
        XCTAssertEqual(gm.world.kael.position.x, scene.size.width * 0.5, accuracy: 0.5)
        XCTAssertEqual(gm.world.kael.position.y, gm.world.worldHeight * 0.05, accuracy: 0.5,
                       "Kael reprend à l'orée sud")
        XCTAssertFalse(gm.roamers.isEmpty, "les monstres baladeurs sont repeuplés")
    }

    func test_restore_ruins_objectiveFollowsProgress() {
        prepare()
        defer { cleanup() }
        let scene = makeSceneBackedManager()

        gm.restoreFrom(save: save(phase: .ruins) { $0.ruinsProgress = 0 }, scene: scene)
        let before = gm.hud.objectiveText
        gm.restoreFrom(save: save(phase: .ruins) { $0.ruinsProgress = 2 }, scene: scene)

        XCTAssertEqual(gm.phase, .ruins)
        XCTAssertNotEqual(gm.hud.objectiveText, before,
                          "après l'Archiviste, l'objectif devient la Découverte")
    }

    func test_restore_act3_marksCorruptionCinematicAsSeen() {
        prepare()
        defer { cleanup() }
        let scene = makeSceneBackedManager()

        gm.restoreFrom(save: save(phase: .act3) { $0.kaelCorruptionLevel = 3 }, scene: scene)

        XCTAssertEqual(gm.phase, .act3)
        XCTAssertTrue(gm.corruptionCinematicShown, "on ne rejoue pas la cinématique à chaque chargement")
        XCTAssertEqual(gm.state, .exploration)
    }

    func test_restore_act4_explores() {
        prepare()
        defer { cleanup() }
        let scene = makeSceneBackedManager()

        gm.restoreFrom(save: save(phase: .act4), scene: scene)

        XCTAssertEqual(gm.phase, .act4)
        XCTAssertEqual(gm.state, .exploration)
        XCTAssertTrue(gm.corruptionCinematicShown)
    }

    /// Save interrompue entre les Actes : la suite doit se relancer (cul-de-sac
    /// historique). Verrouillé : la reprise passe par le mur d'achat.
    func test_restore_complete_requeuesAct2BehindPaywall() {
        prepare()
        defer { cleanup() }
        let wasUnlocked = StoreManager.shared.isUnlocked
        StoreManager.shared.setUnlockedForTesting(false)   // mur d'achat actif
        defer { StoreManager.shared.setUnlockedForTesting(wasUnlocked) }
        let scene = makeSceneBackedManager()

        gm.restoreFrom(save: save(phase: .complete), scene: scene)

        XCTAssertEqual(gm.state, .shop, "le mur d'achat est ouvert")
        XCTAssertNotNil(gm.pendingUnlockAction, "l'Acte II attend le déverrouillage")
    }
}
